#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-${DC:-dmd}}"
root="$(cd "$(dirname "$0")" && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
python3 - "$root" "$tmp_dir" <<'PY'
import sys
from pathlib import Path
root,tmp=map(Path,sys.argv[1:])
for form in ['pointer','slice']:
    source=(root/f'source/raster/research/m3_transform_executor/generated/{form}.d').read_text()
    helpers=source[source.index('// Preconditions:'):]
    prefix='''module challenge;
T identity(T)(T x) @safe pure nothrow @nogc { return x; }
T invokePointTransform(alias f,T)(T x) @safe pure nothrow @nogc { return f(x); }
'''
    suffix='''
void main() { float[4] a,b; execute!identity(a.ptr,2,2,2,b.ptr,2); }
'''
    for safe in [False,True]:
        body=helpers.replace('@trusted','@safe') if safe else helpers
        (tmp/f'{form}-{safe}.d').write_text(prefix+body+suffix)
PY
for form in pointer slice; do
    "$compiler" -c -preview=dip1000 -of="$tmp_dir/control.o" "$tmp_dir/$form-False.d"
    if "$compiler" -c -preview=dip1000 -of="$tmp_dir/challenge.o" \
        "$tmp_dir/$form-True.d" > "$tmp_dir/$form.log" 2>&1; then
        echo "FAIL redundant trust: $form"
        exit 1
    fi
    if ! grep -E '(pointer|index|slice).*(@safe|safe function)' "$tmp_dir/$form.log" >/dev/null; then
        cat "$tmp_dir/$form.log"
        exit 1
    fi
    echo "PASS trust challenge: $form requires pointer/slice construction boundary"
    cat "$tmp_dir/$form.log"
done
