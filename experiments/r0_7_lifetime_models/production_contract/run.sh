#!/usr/bin/env bash
# Real raster-d imports, not toy lifetime structs. Research-only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="${1:-dmd}"
RASTER_SHA=694c539fc54efe14fa9b8a015bcc52728bfa42b6
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --quiet https://github.com/alex-1974/raster-d.git "$TMP/raster-d"
git -C "$TMP/raster-d" checkout --quiet --detach "$RASTER_SHA"
"$COMPILER" --version >"$TMP/compiler-version.log" 2>&1
sed -n "1,3p" "$TMP/compiler-version.log"
printf 'compiler,mode,case,result\n'
for mode in ordinary dip1000; do
    flags=()
    if [[ "$mode" == dip1000 ]]; then flags+=(-preview=dip1000); fi
    for probe in positive escape_return escape_global escape_closure; do
        log="$TMP/$mode-$probe.log"
        if "$COMPILER" -c "${flags[@]}" -I"$TMP/raster-d/source" \
             -of="$TMP/$probe.o" "$ROOT/probes/$probe.d" >"$log" 2>&1; then
            outcome=accepted
        else
            outcome=rejected
        fi
        printf '%s,%s,%s,%s\n' "$COMPILER" "$mode" "$probe" "$outcome"
        if [[ "$probe" == positive && "$outcome" != accepted ]]; then
            echo 'FAIL: valid public view API consumer did not compile' >&2
            cat "$log" >&2
            exit 1
        fi
        if [[ "$outcome" == rejected ]]; then
            sed -n '1,5p' "$log" | sed 's/^/  /'
        fi
    done
done
# Existing production suite is the authoritative lifecycle implementation test.
# This additional run checks the pinned production merge against the selected toolchain.
dub test --root="$TMP/raster-d" --compiler="$COMPILER"
