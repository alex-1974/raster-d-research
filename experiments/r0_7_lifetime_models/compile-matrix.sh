#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-dmd}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$compiler" --version >"$tmp/compiler-version.txt" 2>&1
sed -n '1,3p' "$tmp/compiler-version.txt"
printf '%s\n' 'compiler,mode,case,result'
failures=0
for mode in ordinary dip1000; do
    flags=()
    if [[ "$mode" == dip1000 ]]; then flags+=(-preview=dip1000); fi
    for case_name in borrowed_escape owned_return retained_malloc callback_escape callback_local callback_scope_positive callback_global_capture callback_closure_capture; do
        if "$compiler" -c "${flags[@]}" -of="$tmp/$case_name.o" \
             "$root/probes/$case_name.d" >"$tmp/$case_name.log" 2>&1; then
            outcome=accepted
        else
            outcome=rejected
        fi
        printf '%s,%s,%s,%s\n' "$compiler" "$mode" "$case_name" "$outcome"
        if ! python3 "$root/check_lifetime_diagnostics.py" \
            "$mode" "$case_name" "$outcome" "$tmp/$case_name.log"; then
            failures=$((failures + 1))
        fi
        if [[ "$outcome" == rejected ]]; then
            sed -n '1,5p' "$tmp/$case_name.log" | sed 's/^/  /'
        fi
    done
done
# Outcome/diagnostic expectations are gated only for the pinned baseline
# compiler versions. Unsafe ordinary-mode acceptances remain documented
# observations, NOT proof of the safety of those programs.
if (( failures != 0 )); then
    exit 1
fi

# Independently exercise the malloc-backed owning model's copy/return path.
# This is a toy functional check; the ownership proof is not yet complete.
"$compiler" -unittest -main -of="$tmp/retained_model_test" \
    "$root/probes/retained_malloc.d"
"$tmp/retained_model_test"
echo "PASS retained_malloc runtime unittest ($compiler)"
