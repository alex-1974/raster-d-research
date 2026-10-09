#!/usr/bin/env bash
# Local, research-only matched benchmark; does not modify production raster-d.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
SRC="experiments/r0_7_lifetime_models/strict_sum_loop_shapes.d"
OUT="${1:-/tmp/r07-checked-add-xps}"
mkdir -p "$OUT"
OUT="$(realpath "$OUT")"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is dirty; record a clean research revision" >&2
  exit 1
fi
for bin in dmd ldc2 objdump sha256sum; do command -v "$bin" >/dev/null || { echo "missing: $bin" >&2; exit 1; }; done
{
  echo "utc_timestamp=$(date -u +%FT%TZ)"
  echo "host=$(hostname)"
  echo "uname=$(uname -a)"
  echo "cpu_model=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -1)"
  echo "revision=$(git rev-parse HEAD)"
  echo "branch=$(git branch --show-current)"
  echo "source_sha256=$(sha256sum "$SRC")"
  echo "dmd_version=$(dmd --version | head -1)"
  echo "ldc_version=$(ldc2 --version | head -1)"
  echo "dmd_flags=-O -release -inline"
  echo "ldc_flags=-O3 -release"
  echo "outer_repetitions=9"
  echo "inner_trials_per_binary=7"
} > "$OUT/metadata.txt"
printf 'compiler,outer_repetition,trial,case,ns_per_operation,checksum\n' > "$OUT/raw.csv"
for compiler in dmd ldc2; do
  if [[ "$compiler" == dmd ]]; then
    "$compiler" -O -release -inline -of="$OUT/checked-add-dmd" "$SRC"
    exe="$OUT/checked-add-dmd"
    tag=dmd
  else
    "$compiler" -O3 -release -of="$OUT/checked-add-ldc" "$SRC"
    exe="$OUT/checked-add-ldc"
    tag=ldc
  fi
  objdump -drwC "$exe" > "$OUT/$tag-disassembly.txt"
  sha256sum "$exe" >> "$OUT/binary-sha256.txt"
  for ((outer=0; outer<9; ++outer)); do
    "$exe" > "$OUT/$tag-run-$outer.csv"
    awk -F, -v c="$tag" -v r="$outer" 'NR>1 {
      if(NF!=4 || $1 !~ /^[0-6]$/ || $3 !~ /^[0-9]+([.][0-9]+)?$/ || $4 !~ /^[0-9]+$/) exit 1;
      print c "," r "," $0
    }' "$OUT/$tag-run-$outer.csv" >> "$OUT/raw.csv"
  done
done
python3 - "$OUT/raw.csv" "$OUT/summary.csv" <<'PY'
import csv, statistics, sys
from collections import defaultdict
groups = defaultdict(list)
checks = defaultdict(set)
with open(sys.argv[1], newline="") as f:
    for row in csv.DictReader(f):
        key = (row["compiler"], row["case"])
        groups[key].append(float(row["ns_per_operation"]))
        checks[key].add(row["checksum"])
if len(groups) != 10:
    raise SystemExit(f"expected ten compiler/case groups, got {len(groups)}")
with open(sys.argv[2], "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["compiler","case","n","median_ns","min_ns","max_ns","checksum"])
    for key, values in sorted(groups.items()):
        if len(values) != 63 or len(checks[key]) != 1:
            raise SystemExit(f"invalid count/checksum for {key}: {len(values)}, {checks[key]}")
        w.writerow([*key,len(values),f"{statistics.median(values):.6f}",
                    f"{min(values):.6f}",f"{max(values):.6f}",next(iter(checks[key]))])
print(f"Research evidence: {sys.argv[2]}")
PY
echo "Results in: $OUT"
