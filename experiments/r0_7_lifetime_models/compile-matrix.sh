#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-dmd}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$compiler" --version | head -3
printf '%s\n' 'compiler,mode,case,result'
for mode in ordinary dip1000; do
    flags=()
    if [[ "$mode" == dip1000 ]]; then flags+=(-preview=dip1000); fi
    for case_name in borrowed_escape owned_return callback_escape callback_local; do
        if "$compiler" -c "${flags[@]}" -of="$tmp/$case_name.o" \
             "$root/probes/$case_name.d" >"$tmp/$case_name.log" 2>&1; then
            outcome=accepted
        else
            outcome=rejected
        fi
        printf '%s,%s,%s,%s\n' "$compiler" "$mode" "$case_name" "$outcome"
        if [[ "$outcome" == rejected ]]; then
            sed -n '1,5p' "$tmp/$case_name.log" | sed 's/^/  /'
        fi
    done
done
# This first step is observational. No acceptance is a safety certificate.
