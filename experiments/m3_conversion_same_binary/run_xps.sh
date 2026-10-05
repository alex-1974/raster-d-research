#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
EXPECTED_BRANCH="research/m3-conversion-same-binary"
BRANCH="$(git -C "$ROOT" branch --show-current)"

if [[ "$BRANCH" != "$EXPECTED_BRANCH" ]]; then
    echo "STOP: expected $EXPECTED_BRANCH, got $BRANCH" >&2
    exit 1
fi

OUT="${1:-/tmp/raster-m3-same-binary-xps-$(date +%Y%m%d-%H%M%S)}"
if [[ -e "$OUT" ]]; then
    echo "STOP: output already exists: $OUT" >&2
    exit 1
fi
mkdir -p "$OUT"

{
    echo "head=$(git -C "$ROOT" rev-parse HEAD)"
    echo "branch=$BRANCH"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "uname=$(uname -a)"
    echo "dub=$(dub --version)"
    echo "affinity=$(taskset -pc $$ 2>&1 || true)"
    echo
    lscpu
    echo
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        echo -n "cpu0_governor="
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    fi
} > "$OUT/host.txt"

summarize()
{
    local dir="$1"
    python3 - "$dir" <<'PY'
from pathlib import Path
import statistics
import sys

root = Path(sys.argv[1])
groups = {"separate": [], "shared": []}
fingerprints = {"separate": {}, "shared": {}}

for path in sorted(root.glob("run-*.txt")):
    for line in path.read_text().splitlines():
        if line.startswith("m3_same_binary "):
            group = "separate"
        elif line.startswith("m3_shared_boundary "):
            group = "shared"
        else:
            continue
        fields = dict(item.split("=", 1) for item in line.split()[1:])
        pair = int(fields["pair"])
        width = int(fields["width"])
        ratio = float(fields["hybrid_over_pointer"])
        fp = fields["fingerprint"]
        fingerprints[group].setdefault(width, set()).add(fp)
        groups[group].append((path.name, pair, width, ratio))

if len(groups["separate"]) != 6 * 4 * 8:
    raise SystemExit(f"expected 192 separate rows, got {len(groups['separate'])}")
if len(groups["shared"]) != 6 * 2 * 8:
    raise SystemExit(f"expected 96 shared rows, got {len(groups['shared'])}")
if any(len(v) != 1 for group in fingerprints.values() for v in group.values()):
    raise SystemExit(f"fingerprint mismatch: {fingerprints}")

with (root / "summary.txt").open("w") as out:
    for group in ("separate", "shared"):
        out.write(f"[{group}]\n")
        rows = groups[group]
        for width in sorted(fingerprints[group]):
            values = [r for _, _, w, r in rows if w == width]
            out.write(
                f"width={width} n={len(values)} "
                f"median_hybrid_over_pointer={statistics.median(values):.6f} "
                f"min={min(values):.6f} max={max(values):.6f}\n"
            )
        out.write("per_pair_wide:\n")
        for pair in sorted({p for _, p, _, _ in rows}):
            values = [r for _, p, w, r in rows if p == pair and w >= 64]
            out.write(
                f"pair={pair} n={len(values)} "
                f"median={statistics.median(values):.6f} "
                f"min={min(values):.6f} max={max(values):.6f}\n"
            )
        out.write("\n")
PY
}

run_compiler()
{
    local compiler="$1"
    local label="$2"
    local dir="$OUT/$label"
    local project="$ROOT/experiments/m3_conversion_same_binary"
    local built="$project/raster-m3-conversion-same-binary"
    mkdir -p "$dir"

    "$compiler" --version > "$dir/compiler.txt" 2>&1
    dub build         --root="$project"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp "$built" "$dir/binary"
    sha256sum "$dir/binary" > "$dir/binary.sha256"
    nm -n "$dir/binary"         | grep -E 'm3_(hybrid|pointer)_[0-3]$|m3_shared_[01]$'         > "$dir/symbols.txt"

    test "$(wc -l < "$dir/symbols.txt")" -eq 10

    for i in 0 1 2 3 4 5; do
        "$dir/binary" > "$dir/run-$i.txt"
        test "$(grep -c '^m3_same_binary ' "$dir/run-$i.txt")" -eq 32
        test "$(grep -c '^m3_shared_boundary ' "$dir/run-$i.txt")" -eq 16
    done

    summarize "$dir"
}

run_compiler dmd dmd
run_compiler ldc2 ldc

(
    cd "$OUT"
    find . -type f ! -name SHA256SUMS -print0         | sort -z         | xargs -0 sha256sum
) > "$OUT/SHA256SUMS"

echo
echo "=== DMD ==="
cat "$OUT/dmd/summary.txt"
echo
echo "=== LDC ==="
cat "$OUT/ldc/summary.txt"
echo
echo "output=$OUT"
echo "manifest=$OUT/SHA256SUMS"
