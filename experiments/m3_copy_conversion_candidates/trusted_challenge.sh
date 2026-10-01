#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-dmd}"
root="$(cd "$(dirname "$0")" && pwd)"
task_tmp="$(mktemp -d)"
trap 'rm -rf "$task_tmp"' EXIT
python3 - "$root" "$task_tmp" <<'PY'
from pathlib import Path
import sys
r,t=map(Path,sys.argv[1:]);s=(r/'source/raster/research/m3_copy_conversion_candidates/harness.d').read_text()
helper=s[s.index('// The caller supplies'):s.index('private enum rounds')]
externs=s[s.index('extern(C) void cppCopy'):s.index('// The caller supplies')]
prefix='module challenge;\nstruct Pod {uint a;ushort b;ubyte c;ubyte d;}\n'+externs
suffix='''
void main(){ ubyte[4] a,b;float[4] c,d;Pod[4] e,f;
 cppExecute(a.ptr,2,1,b.ptr,2,1,2,2);
 cppExecute(c.ptr,2,1,d.ptr,2,1,2,2);
 cppExecute(e.ptr,2,1,f.ptr,2,1,2,2);
 cppExecute(a.ptr,2,1,c.ptr,2,1,2,2); }
'''
for safe in [False,True]:
 (t/f'{safe}.d').write_text(prefix+(helper.replace('@trusted','@safe') if safe else helper)+suffix)
PY
"$compiler" -c -preview=dip1000 -of="$task_tmp/control.o" "$task_tmp/False.d"
if "$compiler" -c -preview=dip1000 -of="$task_tmp/challenge.o" "$task_tmp/True.d" > "$task_tmp/error.txt" 2>&1; then
    echo 'FAIL redundant C++ trust boundary'; exit 1
fi
if ! grep -Ei '(@system|pointer|cast).*(@safe|safe function)|@safe.*(@system|pointer|cast)' "$task_tmp/error.txt" >/dev/null; then
    cat "$task_tmp/error.txt"; exit 1
fi
echo 'PASS actual-source C++ wrapper requires trust'
cat "$task_tmp/error.txt"
python3 - "$root" "$task_tmp" <<'PY'
from pathlib import Path
import sys
r,t=map(Path,sys.argv[1:])
for form in ['execute','combined']:
 for op in ['copy','conversion']:
  s=(r/f'source/raster/research/m3_copy_conversion_candidates/generated/{form}_{op}_dispatch.d').read_text()
  helper=s[s.index('// Candidate kernel:'):]
  prefix='module row_challenge;\nstruct Pod{uint a;ushort b;ubyte c;ubyte d;}\n'
  suffix='''
@safe pure nothrow @nogc void positive(){
 ubyte[4] a,b;float[4] c,d;Pod[4] e,f;
 executeRows(a.ptr,2,b.ptr,2,2,2);
 executeRows(c.ptr,2,d.ptr,2,2,2);
 executeRows(e.ptr,2,f.ptr,2,2,2);
 executeRows(a.ptr,2,c.ptr,2,2,2); }
void main(){positive();}
'''
  for safe in [False,True]:
   (t/f'{form}-{op}-{safe}.d').write_text(prefix+(helper.replace('@trusted','@safe') if safe else helper)+suffix)
PY
for form in execute combined; do
    for op in copy conversion; do
        "$compiler" -c -preview=dip1000 -of="$task_tmp/row-control.o" "$task_tmp/$form-$op-False.d"
        if "$compiler" -c -preview=dip1000 -of="$task_tmp/row-challenge.o" "$task_tmp/$form-$op-True.d" > "$task_tmp/row-error.txt" 2>&1; then
            echo "FAIL redundant row trust: $form/$op"; exit 1
        fi
        if ! grep -Ei '(pointer|index|slice).*(@safe|safe function)' "$task_tmp/row-error.txt" >/dev/null; then
            cat "$task_tmp/row-error.txt"; exit 1
        fi
        echo "PASS actual-source safe row kernel requires scoped row trust: $form/$op"
        cat "$task_tmp/row-error.txt"
    done
 done
