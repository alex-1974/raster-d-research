#!/usr/bin/env bash
# Production-source A/B: exact frozen raster-d v0.2 versus one internal ulong edit.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
OUT="${1:-/tmp/r07-production-checked-ab}"
mkdir -p "$OUT"
OUT="$(realpath "$OUT")"
SOURCE_SHA=cca63a9b2821cd26a98792d322207c8f07bd734f
SRC="$ROOT/experiments/r0_7_lifetime_models"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: use a clean research worktree" >&2; exit 1
fi
for program in git dub dmd ldc2 python3 sha256sum; do
  command -v "$program" >/dev/null || { echo "missing $program" >&2; exit 1; }
done
if [[ -e "$OUT/baseline" || -e "$OUT/candidate" ]]; then
  echo "ERROR: use a fresh evidence directory" >&2; exit 1
fi
for arm in baseline candidate; do
  git clone --quiet https://github.com/alex-1974/raster-d.git "$OUT/$arm"
  git -C "$OUT/$arm" checkout --quiet --detach "$SOURCE_SHA"
done
python3 "$SRC/patch_strict_sum_ulong.py" "$OUT/candidate" > "$OUT/candidate.diff.txt"
echo "baseline_sha=$(git -C "$OUT/baseline" rev-parse HEAD)" > "$OUT/metadata.txt"
echo "candidate_sha=$(git -C "$OUT/candidate" rev-parse HEAD)" >> "$OUT/metadata.txt"
echo "research_sha=$(git rev-parse HEAD)" >> "$OUT/metadata.txt"
echo "timestamp_utc=$(date -u +%FT%TZ)" >> "$OUT/metadata.txt"
echo "machine=$(uname -a)" >> "$OUT/metadata.txt"
echo "cpu=$(awk -F: '/^model name/{sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo)" >> "$OUT/metadata.txt"
for compiler in dmd ldc2; do
  "$compiler" --version | head -1 >> "$OUT/metadata.txt" || true
  for arm in baseline candidate; do
    target="$OUT/consumer-$compiler-$arm"
    mkdir -p "$target"
    cp "$SRC/real_consumer/dub.sdl" "$target/"
    cp -r "$SRC/real_consumer/source" "$target/"
    ln -s "$OUT/$arm" "$target/raster-d-local"
    dub build --root="$target" --compiler="$compiler" --build=release
    test -x "$target/build/real-raster-consumer"
    sha256sum "$target/build/real-raster-consumer" >> "$OUT/binaries.sha256"
    nm -anC "$target/build/real-raster-consumer" > "$OUT/$compiler-$arm.symbols"
    objdump -drwC "$target/build/real-raster-consumer" > "$OUT/$compiler-$arm.disasm"
  done
done
# Alternating order limits but cannot remove thermal/frequency confounding.
printf 'compiler,pair,arm,trial,ns_per_operation,checksum\n' > "$OUT/raw.csv"
for compiler in dmd ldc2; do
  for ((pair=0; pair<7; ++pair)); do
    if ((pair % 2)); then arms=(candidate baseline); else arms=(baseline candidate); fi
    for arm in "${arms[@]}"; do
      exe="$OUT/consumer-$compiler-$arm/build/real-raster-consumer"
      log="$OUT/$compiler-$arm-pair-$pair.csv"
      "$exe" > "$log"
      python3 - "$log" "$compiler" "$pair" "$arm" >> "$OUT/raw.csv" <<'PY'
import csv, sys
with open(sys.argv[1], newline="") as f:
    rows = list(csv.DictReader(f))
prod = [r for r in rows if r["case"] == "production_sum_roi"]
if len(prod) != 7:
    raise SystemExit("missing production_sum_roi trial")
for r in prod:
    print(",".join([sys.argv[2],sys.argv[3],sys.argv[4],
                    r["trial"],r["ns_per_operation"],r["checksum"]]))
PY
    done
  done
done
python3 - "$OUT/raw.csv" "$OUT/summary.csv" <<'PY'
import csv, statistics, sys
from collections import defaultdict
vals,checks = defaultdict(list),defaultdict(set)
with open(sys.argv[1],newline="") as f:
    for r in csv.DictReader(f):
        key=(r["compiler"],r["arm"])
        vals[key].append(float(r["ns_per_operation"]))
        checks[key].add(r["checksum"])
with open(sys.argv[2],"w",newline="") as f:
    w=csv.writer(f)
    w.writerow(["compiler","arm","n","median_ns","min_ns","max_ns","checksum"])
    if len(vals)!=4:
        raise SystemExit("missing compiler/arm results")
    for key,a in sorted(vals.items()):
        if len(a)!=49 or len(checks[key])!=1:
            raise SystemExit(f"invalid trials/checksum {key}")
        w.writerow([*key,len(a),statistics.median(a),min(a),max(a),next(iter(checks[key]))])
for compiler in ("dmd","ldc2"):
    if checks[compiler,"baseline"]!=checks[compiler,"candidate"]:
        raise SystemExit(f"baseline/candidate checksum mismatch: {compiler}")
print(f"Validated paired research observations: {sys.argv[2]}")
PY
