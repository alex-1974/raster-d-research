#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
EXPERIMENT="$ROOT/experiments/m3_conversion_full_public_pointer"
PRODUCTION="$ROOT/../raster-d"
PIN="10549e045bfa5a99afe6552b0fb41b76fe203fa5"
BRANCH="research/m3-conversion-full-public-pointer"

test "$(git -C "$ROOT" branch --show-current)" = "$BRANCH"
test "$(git -C "$PRODUCTION" rev-parse HEAD)" = "$PIN"

OUT="${1:-/tmp/raster-m3-full-public-pointer-xps-$(date +%Y%m%d-%H%M%S)}"
test ! -e "$OUT"
mkdir -p "$OUT"

{
    echo "research_head=$(git -C "$ROOT" rev-parse HEAD)"
    echo "research_branch=$(git -C "$ROOT" branch --show-current)"
    echo "production_head=$(git -C "$PRODUCTION" rev-parse HEAD)"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "uname=$(uname -a)"
    echo "dub=$(dub --version)"
    echo "shell_affinity=$(taskset -pc $$ 2>&1 || true)"
    echo
    lscpu
    echo
    for cpu in 0; do
        path="/sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_governor"
        if [[ -r "$path" ]]; then
            printf 'cpu%s_governor=' "$cpu"
            cat "$path"
        fi
    done
} > "$OUT/host.txt"

python3 "$EXPERIMENT/prepare.py" > "$OUT/prepare.txt"

summarize()
{
    local dir="$1"
    python3 - "$dir" <<'PY'
from pathlib import Path
import statistics
import sys

root = Path(sys.argv[1])
rows = []
fingerprints = {}
for mode in ("short", "long"):
    for path in sorted(root.glob(f"{mode}-run-*.txt")):
        for line in path.read_text().splitlines():
            if not line.startswith("m3_full_public "):
                continue
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            key = (mode, int(fields["width"]), int(fields["height"]), fields["layout"])
            ratio = float(fields["current_over_pointer"])
            fp = (fields["source_fp"], fields["target_fp"])
            fingerprints.setdefault(key, set()).add(fp)
            rows.append((key, ratio))
for mode in ("short", "long"):
    count = sum(1 for key, _ in rows if key[0] == mode)
    if count != 6 * 42:
        raise SystemExit(f"{mode}: expected 252 rows, got {count}")
if any(len(v) != 1 for v in fingerprints.values()):
    raise SystemExit("fingerprint mismatch across repeated processes")

with (root / "summary.txt").open("w") as out:
    for mode in ("short", "long"):
        out.write(f"[{mode}]\n")
        for key in sorted(k for k in fingerprints if k[0] == mode):
            values = [ratio for candidate, ratio in rows if candidate == key]
            _, width, height, layout = key
            out.write(
                f"width={width} height={height} layout={layout} n={len(values)} "
                f"median_current_over_pointer={statistics.median(values):.6f} "
                f"min={min(values):.6f} max={max(values):.6f}\n"
            )
        out.write("\n")
        unit = [
            ratio for key, ratio in rows
            if key[0] == mode and key[1] >= 64 and key[3] != "universal"
        ]
        narrow = [
            ratio for key, ratio in rows
            if key[0] == mode and key[1] < 64 and key[3] != "universal"
        ]
        universal = [
            ratio for key, ratio in rows
            if key[0] == mode and key[3] == "universal"
        ]
        out.write(
            f"{mode}_wide_unit median={statistics.median(unit):.6f} "
            f"min={min(unit):.6f} max={max(unit):.6f}\n"
        )
        out.write(
            f"{mode}_narrow_unit median={statistics.median(narrow):.6f} "
            f"min={min(narrow):.6f} max={max(narrow):.6f}\n"
        )
        out.write(
            f"{mode}_universal_control median={statistics.median(universal):.6f} "
            f"min={min(universal):.6f} max={max(universal):.6f}\n\n"
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
    python3 "$EXPERIMENT/prepare.py" > "$dir/prepare.txt"
    dub build         --root="$EXPERIMENT"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp "$EXPERIMENT/raster-m3-conversion-full-public-pointer" "$dir/binary"
    sha256sum "$dir/binary" > "$dir/binary.sha256"
    nm -n "$dir/binary"         | grep -E 'variant_full_public_pointer|convertResearchPointerRow|setResearchConversionExecutionForm'         > "$dir/symbols.txt" || true

    "$dir/binary" > "$dir/verification.txt"
    grep -q 'PASS shared-entry boundary: 36 width-63/64/65 public cases'         "$dir/verification.txt"

    for mode in short long; do
        for process in 0 1 2 3 4 5; do
            taskset -c 0 "$dir/binary" "--timing-$mode" "$process"                 > "$dir/$mode-run-$process.txt"
            test "$(grep -c '^m3_full_public ' "$dir/$mode-run-$process.txt")" -eq 42
        done
    done

    summarize "$dir"
}

run_compiler dmd dmd
run_compiler ldc2 ldc

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
