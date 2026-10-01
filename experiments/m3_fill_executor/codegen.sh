#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
task_tmp="$(mktemp -d)"
trap 'rm -rf "$task_tmp"' EXIT
python3 - "$root" "$task_tmp" <<'PROBE'
import sys
from pathlib import Path
root,tmp=map(Path,sys.argv[1:])
for form in ['pointer','slice']:
    source=(root/f'source/raster/research/m3_fill_executor/generated/{form}_dispatch.d').read_text()
    helpers=source[source.index('// Caller has validated'):]
    entries="""
extern(C) void fillFloat(scope float* base,ptrdiff_t stride,size_t width,size_t height,float value) @safe nothrow @nogc { execute(base,stride,width,height,value); }
extern(C) void fillByte(scope ubyte* base,ptrdiff_t stride,size_t width,size_t height,ubyte value) @safe nothrow @nogc { execute(base,stride,width,height,value); }
"""
    (tmp/f'{form}.d').write_text('module probe;\n'+helpers+entries)
PROBE
for compiler in dmd ldc2; do
    "$compiler" --version
    for form in pointer slice; do
        echo "=== $compiler $form isolated actual executor ==="
        if [[ "$compiler" == dmd ]]; then flags=(-O -release -inline); else flags=(-O3 -release); fi
        printf 'command: %s -c -preview=dip1000 ' "$compiler"
        printf '%s ' "${flags[@]}"
        echo "$form.d"
        "$compiler" -c -preview=dip1000 "${flags[@]}" -of="$task_tmp/$form.o" "$task_tmp/$form.d"
        objdump -dr "$task_tmp/$form.o"
    done
done
