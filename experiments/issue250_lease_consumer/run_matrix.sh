#!/usr/bin/env bash
set -euo pipefail

# Usage: bash run_matrix.sh dmd | ldc2
compiler="${1:-dmd}"
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "=== Toolchain ==="
"$compiler" --version
dub --version

echo "=== Exact DUB dependency ==="
dub describe --compiler="$compiler" --data=import-paths --data-list > /dev/null
test -f dub.selections.json
python3 - <<'PY'
import json
with open("dub.selections.json") as f:
    deps = json.load(f)["versions"]
assert deps["raster-d"] == "0.2.0", deps
print("PASS: pinned raster-d ==0.2.0")
PY

for mode in debug release; do
    echo "=== Runtime / $compiler / $mode ==="
    dub run --compiler="$compiler" --build="$mode" --force
done

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

dub describe --compiler="$compiler" --data=import-paths --data-list > "$tmp/imports"
imports=()
while IFS= read -r path; do
    [[ -n "$path" ]] && imports+=("-I=$path")
done < "$tmp/imports"
test "${#imports[@]}" -gt 0

echo "=== Compile-only controls ==="
# Same package resolution, source module and -c mode as the negatives.
"$compiler" -c "${imports[@]}" \
    -of="$tmp/positive.o" probes/positive_import.d

for probe in negative_has_backing negative_physical_bytes \
             negative_owner_count negative_callback; do
    if "$compiler" -c "${imports[@]}" \
        -of="$tmp/$probe.o" "probes/$probe.d" \
        > "$tmp/$probe.log" 2>&1; then
        echo "FAIL: $probe unexpectedly compiled"
        exit 1
    fi
    if grep -qiE 'module .* not found|unable to read module|cannot find|not found in import' \
        "$tmp/$probe.log"; then
        echo "FAIL: $probe may have failed because of an unavailable import"
        cat "$tmp/$probe.log"
        exit 1
    fi
    case "$probe" in
        negative_has_backing)
            expected='no property `hasBacking`'
            ;;
        negative_physical_bytes)
            expected='no property `tryPhysicalResourceBytes`'
            ;;
        negative_owner_count)
            expected='no property `owner_`'
            ;;
        negative_callback)
            expected='member `ResourceEntry` is not visible'
            ;;
    esac
    if ! grep -Fq "$expected" "$tmp/$probe.log"; then
        echo "FAIL: $probe rejected for an unrelated reason"
        cat "$tmp/$probe.log"
        exit 1
    fi
    echo "DIAGNOSTIC[$probe]:"
    tail -n 12 "$tmp/$probe.log"
    echo "PASS: $probe compile-negative"
done

"$compiler" -c -preview=dip1000 "${imports[@]}" \
    -of="$tmp/positive_dip.o" probes/positive_import.d

if "$compiler" -c -preview=dip1000 "${imports[@]}" \
    -of="$tmp/negative_escape.o" probes/negative_borrow_escape.d \
    > "$tmp/negative_borrow_escape.log" 2>&1; then
    echo "FAIL: local borrowed RasterView escaped under DIP1000"
    exit 1
fi
if ! grep -Fq 'escapes a reference to local variable `local`' \
    "$tmp/negative_borrow_escape.log"; then
    echo "FAIL: borrowed-view negative rejected for an unrelated reason"
    cat "$tmp/negative_borrow_escape.log"
    exit 1
fi
echo "DIAGNOSTIC[negative_borrow_escape]:"
tail -n 12 "$tmp/negative_borrow_escape.log"
echo "PASS: negative_borrow_escape / DIP1000 compile-only"
echo "PASS: external public-contract gates on $compiler"
