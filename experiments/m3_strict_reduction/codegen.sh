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
    source=(root/f'source/raster/research/m3_strict_reduction/generated/{form}_dispatch.d').read_text()
    helpers=source[source.index('// Caller validates'):]
    entry="\nextern(C) double strictSum(scope const(float)* base,ptrdiff_t sr,size_t w,size_t h) @safe nothrow @nogc { return execute(base,sr,w,h); }\n"
    (tmp/f'{form}.d').write_text('module probe;\n'+helpers+entry)
PROBE
for compiler in dmd ldc2; do
    "$compiler" --version
    for form in pointer slice; do
        echo "=== $compiler $form exact strict kernel ==="
        if [[ "$compiler" == dmd ]]; then flags=(-O -release -inline); else flags=(-O3 -release); fi
        printf 'command: %s -c -preview=dip1000 ' "$compiler"
        printf '%s ' "${flags[@]}"
        echo "$form.d"
        "$compiler" -c -preview=dip1000 "${flags[@]}" -of="$task_tmp/$form.o" "$task_tmp/$form.d"
        objdump -dr "$task_tmp/$form.o"
    done
done
