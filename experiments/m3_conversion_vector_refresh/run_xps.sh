#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SOURCE_EXP="$ROOT/experiments/m3_conversion_vector_refresh"
PRODUCTION_REPO="$ROOT/../raster-d"
PIN="24d948255df014c683d79c5508f13248806062dc"
EXPECTED_BRANCH="research/m3-conversion-vector-refresh"
CPU="${2:-0}"
OUT="${1:-/tmp/raster-m3-vector-refresh-xps-$(date +%Y%m%d-%H%M%S)}"

test "$(git -C "$ROOT" branch --show-current)" = "$EXPECTED_BRANCH"
test ! -e "$OUT"
mkdir -p "$OUT"

snapshot_freq()
{
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
            printf 'cpu=%s governor=%s cur_khz=%s min_khz=%s max_khz=%s\n'                 "$id" "$gov" "$cur" "$min" "$max"
        done
        for path in /sys/class/thermal/thermal_zone*/temp; do
            [[ -r "$path" ]] || continue
            printf '%s=' "$path"
            cat "$path"
        done
    } > "$OUT/frequency-thermal-$tag.txt"
}

{
    echo "research_head=$(git -C "$ROOT" rev-parse HEAD)"
    echo "research_branch=$(git -C "$ROOT" branch --show-current)"
    echo "production_pin=$PIN"
    echo "cpu=$CPU"
    echo "shell_affinity=$(taskset -pc $$ 2>&1 || true)"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    uname -a
    lscpu
    dub --version
    dmd --version
    ldc2 --version
} > "$OUT/environment.txt"

snapshot_freq before

tmp="$(mktemp -d)"
TEMP_LIBS="$tmp/libs"
TEMP_RESEARCH="$TEMP_LIBS/raster-d-research"
EXP="$TEMP_RESEARCH/experiments/m3_conversion_vector_refresh"
TEMP_PRODUCTION="$TEMP_LIBS/raster-d"

mkdir -p "$TEMP_RESEARCH/experiments"
cp -a "$SOURCE_EXP" "$EXP"

git -C "$PRODUCTION_REPO" fetch origin develop     > "$OUT/production-fetch.txt" 2>&1
git -C "$PRODUCTION_REPO" cat-file -e "$PIN^{commit}"
if ! git -C "$PRODUCTION_REPO" merge-base --is-ancestor "$PIN" origin/develop; then
    echo "STOP: pinned Production commit is not reachable from origin/develop" >&2
    exit 1
fi

git -C "$PRODUCTION_REPO" worktree add --detach "$TEMP_PRODUCTION" "$PIN"     > "$OUT/production-worktree.txt" 2>&1

cleanup()
{
    git -C "$PRODUCTION_REPO" worktree remove --force "$TEMP_PRODUCTION"         >/dev/null 2>&1 || true
    rm -rf "$tmp"
}
trap cleanup EXIT

test "$(git -C "$TEMP_PRODUCTION" rev-parse HEAD)" = "$PIN"
test -z "$(git -C "$TEMP_PRODUCTION" status --short)"

python3 "$EXP/prepare.py" > "$OUT/prepare.txt"

summarize()
{
    local dir="$1"
    python3 - "$dir" <<'PY'
from pathlib import Path
import statistics
import sys

root=Path(sys.argv[1])
rows=[]
fps={}
for mode in ("short","long"):
    for path in sorted(root.glob(f"{mode}-run-*.txt")):
        for line in path.read_text().splitlines():
            if not line.startswith("m3_vector_refresh "):
                continue
            f=dict(item.split("=",1) for item in line.split()[1:])
            key=(mode,int(f["width"]),int(f["height"]),f["layout"])
            ratio=float(f["production_over_vector"])
            fp=(f["source_fp"],f["target_fp"])
            fps.setdefault(key,set()).add(fp)
            rows.append((key,ratio))

for mode in ("short","long"):
    count=sum(1 for key,_ in rows if key[0]==mode)
    if count != 6*49:
        raise SystemExit(f"{mode}: expected 294 rows, got {count}")

if any(len(v)!=1 for v in fps.values()):
    raise SystemExit("fingerprint mismatch across processes")

with (root/"summary.txt").open("w") as out:
    for mode in ("short","long"):
        out.write(f"[{mode}]\n")
        for key in sorted(k for k in fps if k[0]==mode):
            values=[r for candidate,r in rows if candidate==key]
            _,w,h,layout=key
            out.write(
                f"width={w} height={h} layout={layout} n={len(values)} "
                f"median_production_over_vector={statistics.median(values):.6f} "
                f"min={min(values):.6f} max={max(values):.6f}\n"
            )

        active=[
            r for key,r in rows
            if key[0]==mode and key[1]>=64 and key[3]!="universal"
        ]
        inactive=[
            r for key,r in rows
            if key[0]==mode and (key[1]<64 or key[3]=="universal")
        ]
        out.write(
            f"{mode}_active median={statistics.median(active):.6f} "
            f"min={min(active):.6f} max={max(active):.6f}\n"
        )
        out.write(
            f"{mode}_inactive median={statistics.median(inactive):.6f} "
            f"min={min(inactive):.6f} max={max(inactive):.6f}\n\n"
        )
PY
}

run_compiler()
{
    local compiler="$1"
    local label="$2"
    local dir="$OUT/$label"
    mkdir -p "$dir"

    "$compiler" --version > "$dir/compiler.txt" 2>&1
    python3 "$EXP/prepare.py" > "$dir/prepare.txt"

    dub test         --root="$TEMP_PRODUCTION"         --compiler="$compiler"         --force         > "$dir/production-tests.txt" 2>&1

    dub build         --root="$EXP"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp "$EXP/raster-m3-conversion-vector-refresh" "$dir/binary"
    sha256sum "$dir/binary" > "$dir/binary.sha256"
    objdump -dr "$dir/binary" > "$dir/codegen.txt"
    nm -n "$dir/binary" > "$dir/symbols.txt"

    "$dir/binary" > "$dir/verification.txt"
    grep -q 'PASS public copy/conversion' "$dir/verification.txt"

    if [[ "$label" == dmd ]]; then
        grep -E 'punpck|cvtdq2ps|movdqu|movups' "$dir/codegen.txt"             > "$dir/vector-instructions.txt" || true
        test -s "$dir/vector-instructions.txt"
    fi

    for mode in short long; do
        for process in 0 1 2 3 4 5; do
            snapshot_freq "$label-pre-$mode-$process"
            taskset -c "$CPU" "$dir/binary" "--timing-$mode" "$process"                 > "$dir/$mode-run-$process.txt"
            test "$(grep -c '^m3_vector_refresh ' "$dir/$mode-run-$process.txt")" -eq 49
            snapshot_freq "$label-post-$mode-$process"
        done
    done

    summarize "$dir"
}

run_compiler dmd dmd
run_compiler ldc2 ldc

snapshot_freq after

(
    cd "$OUT"
    find . -type f ! -name SHA256SUMS -print0         | sort -z         | xargs -0 sha256sum
) > "$OUT/SHA256SUMS"

ARCHIVE="$OUT.tar.gz"
tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"

echo
echo "=== DMD SUMMARY ==="
cat "$OUT/dmd/summary.txt"
echo
echo "=== LDC SUMMARY ==="
cat "$OUT/ldc/summary.txt"
echo
echo "=== ARCHIVE ==="
sha256sum "$ARCHIVE"
echo "archive=$ARCHIVE"
echo "manifest=$OUT/SHA256SUMS"
