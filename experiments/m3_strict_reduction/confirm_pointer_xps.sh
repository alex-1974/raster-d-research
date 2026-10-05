#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SOURCE_EXP="$ROOT/experiments/m3_strict_reduction"
PRODUCTION_REPO="$ROOT/../raster-d"
BASELINE="1671fb2e51a7b1e7311f78f575d9457e9f279fd4"
EXPECTED_HEAD="1a5f28d2183094e339c0e7d791a67672892888f1"
CPU="${2:-0}"
OUT="${1:-/tmp/raster-m3-reduction-pointer-confirm-$(date +%Y%m%d-%H%M%S)}"

if [[ -e "$OUT" ]]; then
    echo "STOP: output exists: $OUT" >&2
    exit 1
fi
mkdir -p "$OUT"

HEAD="$(git -C "$ROOT" rev-parse HEAD)"
BASE="$(git -C "$ROOT" merge-base "$HEAD" "$EXPECTED_HEAD")"
if [[ "$BASE" != "$EXPECTED_HEAD" ]]; then
    echo "STOP: confirmation branch no longer descends from qualified M3.4 evidence" >&2
    exit 1
fi

snapshot_freq() {
    local tag="$1"
    {
        echo "tag=$tag"
        date -u +%Y-%m-%dT%H:%M:%SZ
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            [[ -d "$cpu/cpufreq" ]] || continue
            id="${cpu##*cpu}"
            gov="$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null || true)"
            cur="$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null || true)"
            min="$(cat "$cpu/cpufreq/scaling_min_freq" 2>/dev/null || true)"
            max="$(cat "$cpu/cpufreq/scaling_max_freq" 2>/dev/null || true)"
            printf 'cpu=%s governor=%s cur_khz=%s min_khz=%s max_khz=%s\n' "$id" "$gov" "$cur" "$min" "$max"
        done
        for path in /sys/class/thermal/thermal_zone*/temp; do
            [[ -r "$path" ]] || continue
            printf '%s=' "$path"
            cat "$path"
        done
    } > "$OUT/frequency-thermal-$tag.txt"
}

{
    echo "research_head=$HEAD"
    echo "qualified_base=$EXPECTED_HEAD"
    echo "branch=$(git -C "$ROOT" branch --show-current)"
    echo "cpu=$CPU"
    echo "shell_affinity=$(taskset -pc $$ 2>&1 || true)"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    uname -a
    lscpu
    dub --version
    dmd --version
    ldc2 --version
    "${CXX:-g++}" --version | head -n 1
} > "$OUT/environment.txt"

snapshot_freq before

tmp="$(mktemp -d)"
TEMP_LIBS="$tmp/libs"
TEMP_RESEARCH="$TEMP_LIBS/raster-d-research"
EXP="$TEMP_RESEARCH/experiments/m3_strict_reduction"
TEMP_PRODUCTION="$TEMP_LIBS/raster-d"

mkdir -p "$TEMP_RESEARCH/experiments"
cp -a "$SOURCE_EXP" "$EXP"

git -C "$PRODUCTION_REPO" cat-file -e "$BASELINE^{commit}"
git -C "$PRODUCTION_REPO" worktree add --detach "$TEMP_PRODUCTION" "$BASELINE"     > "$OUT/production-worktree.txt" 2>&1

cleanup() {
    git -C "$PRODUCTION_REPO" worktree remove --force "$TEMP_PRODUCTION"         >/dev/null 2>&1 || true
    rm -rf "$tmp"
}
trap cleanup EXIT

test "$(git -C "$TEMP_PRODUCTION" rev-parse HEAD)" = "$BASELINE"
test -z "$(git -C "$TEMP_PRODUCTION" status --short)"

python3 "$EXP/generate.py" > "$OUT/generation.txt"
"$EXP/build_cpp.sh" > "$OUT/cpp-build.txt" 2>&1
objdump -dr "$EXP/cpp_reference.o" > "$OUT/cpp-codegen.txt"

sha256sum "$EXP/cpp_reference.o" > "$OUT/binaries.sha256"

for compiler in dmd ldc2; do
    dub test --root="$EXP" --compiler="$compiler" --force > "$OUT/$compiler-tests.txt" 2>&1
    "$EXP/trusted_challenge.sh" "$compiler" > "$OUT/$compiler-trust.txt" 2>&1
    dub build --root="$EXP" --compiler="$compiler" --build=release --force --vverbose         > "$OUT/$compiler-build.txt" 2>&1
    cp "$EXP/raster-m3-strict-reduction" "$tmp/$compiler"
    sha256sum "$tmp/$compiler" >> "$OUT/binaries.sha256"
done

for run in 1 2 3 4 5 6; do
    snapshot_freq "pre-run-$run"
    taskset -c "$CPU" "$tmp/dmd" > "$OUT/dmd-run-$run.txt"
    taskset -c "$CPU" "$tmp/ldc2" > "$OUT/ldc-run-$run.txt"
    snapshot_freq "post-run-$run"
done

"$EXP/codegen.sh" > "$OUT/codegen.txt" 2>&1

python3 - "$OUT" <<'PY'
from pathlib import Path
import re, statistics, sys

root=Path(sys.argv[1])
cases={}
for compiler in ("dmd","ldc"):
    files=sorted(root.glob(f"{compiler}-run-*.txt"))
    if len(files)!=6:
        raise SystemExit(f"{compiler}: expected six runs")
    for file in files:
        for line in file.read_text().splitlines():
            if "public_ns=" not in line or "pointer_ns=" not in line:
                continue
            fields=dict(x.split("=",1) for x in line.split() if "=" in x)
            try:
                width=int(fields["w"])
                height=int(fields["h"])
                layout=fields["layout"]
                corpus=fields["corpus"]
                public=int(fields["public_ns"])
                pointer=int(fields["pointer_ns"])
                slice_ns=int(fields["slice_ns"])
                cpp=int(fields["cpp_ns"])
            except KeyError:
                continue
            key=(compiler,width,height,layout,corpus)
            cases.setdefault(key,[]).append((public,pointer,slice_ns,cpp))

lines=[]
for key,rows in sorted(cases.items()):
    if len(rows)!=6:
        continue
    compiler,width,height,layout,corpus=key
    ratios=[p/q for p,q,_,_ in rows if q]
    if not ratios:
        continue
    lines.append(
        f"compiler={compiler} width={width} height={height} layout={layout} corpus={corpus} "
        f"n={len(ratios)} median_public_over_pointer={statistics.median(ratios):.6f} "
        f"min={min(ratios):.6f} max={max(ratios):.6f}"
    )

Path(root/"pointer-summary.txt").write_text("\n".join(lines)+"\n")
PY

snapshot_freq after

(
    cd "$OUT"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) > "$OUT/SHA256SUMS"

ARCHIVE="$OUT.tar.gz"
tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"

echo "=== POINTER SUMMARY ==="
cat "$OUT/pointer-summary.txt"
echo
echo "=== ARCHIVE ==="
sha256sum "$ARCHIVE"
echo "archive=$ARCHIVE"
