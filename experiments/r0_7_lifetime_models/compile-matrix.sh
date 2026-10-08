#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-dmd}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$compiler" --version | head -3
printf '%s\n' 'compiler,mode,case,result'
failures=0
for mode in ordinary dip1000; do
    flags=()
    if [[ "$mode" == dip1000 ]]; then flags+=(-preview=dip1000); fi
    for case_name in borrowed_escape owned_return retained_malloc callback_escape callback_local; do
        if "$compiler" -c "${flags[@]}" -of="$tmp/$case_name.o" \
             "$root/probes/$case_name.d" >"$tmp/$case_name.log" 2>&1; then
            outcome=accepted
        else
            outcome=rejected
        fi
        printf '%s,%s,%s,%s\n' "$compiler" "$mode" "$case_name" "$outcome"
        if [[ "$case_name" == callback_local && "$outcome" != accepted ]]; then
            echo "FAIL: positive callback_local must compile in $mode" >&2
            failures=$((failures + 1))
        fi
        if [[ "$outcome" == rejected ]]; then
            sed -n '1,5p' "$tmp/$case_name.log" | sed 's/^/  /'
        fi
    done
done
# Negative cases remain observational pending verified failure reasons.
# A failed positive callback case must fail the CI job.
if (( failures != 0 )); then
    exit 1
fi

# Independently exercise the malloc-backed owning model's copy/return path.
# This is a toy functional check; the ownership proof is not yet complete.
"$compiler" -unittest -main -of="$tmp/retained_model_test" \
    "$root/probes/retained_malloc.d"
"$tmp/retained_model_test"
echo "PASS retained_malloc runtime unittest ($compiler)"
