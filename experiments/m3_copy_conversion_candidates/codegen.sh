#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
task_tmp="$(mktemp -d)"
trap 'rm -rf "$task_tmp"' EXIT
python3 - "$root" "$task_tmp" <<'PY'
from pathlib import Path
import sys
r,t=map(Path,sys.argv[1:])
s=(r/'source/raster/research/m3_copy_conversion_candidates/generated/combined_conversion_dispatch.d').read_text()
helpers=s[s.index('// Candidate kernel:'):]
prefix='module row_codegen;\nstruct Pod{uint a;ushort b;ubyte c;ubyte d;}\n'
suffix=''
for name,S,D in [('copyUbyte','ubyte','ubyte'),('copyFloat','float','float'),('copyPod','Pod','Pod'),('convertExact','ubyte','float')]:
 suffix+=f'extern(C) void {name}(scope const({S})* s,ptrdiff_t sr,scope {D}* d,ptrdiff_t dr,size_t w,size_t h) @safe pure nothrow @nogc {{executeRows(s,sr,d,dr,w,h);}}\n'
(t/'rows.d').write_text(prefix+helpers+suffix)
PY
for compiler in dmd ldc2; do
    echo "Isolated actual-source row kernels: $compiler"
    "$compiler" --version
    if [[ "$compiler" == dmd ]]; then
        flags=(-release -inline -O)
    else
        flags=(-release -enable-inlining -O3)
    fi
    set -x
    "$compiler" "${flags[@]}" -preview=dip1000 -c -of="$task_tmp/$compiler.o" "$task_tmp/rows.d"
    set +x
    objdump -dr "$task_tmp/$compiler.o"
done
