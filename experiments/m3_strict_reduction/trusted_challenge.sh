#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-${DC:-dmd}}"
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
    prefix="module challenge;\n"
    suffix="\nvoid main() { float[4] a; auto result=execute(a.ptr,2,2,2); }\n"
    for safe in [False,True]:
        (tmp/f'{form}-{safe}.d').write_text(prefix+(helpers.replace('@trusted','@safe') if safe else helpers)+suffix)
PROBE
for form in pointer slice; do
    "$compiler" -c -preview=dip1000 -of="$task_tmp/control.o" "$task_tmp/$form-False.d"
    if "$compiler" -c -preview=dip1000 -of="$task_tmp/challenge.o" "$task_tmp/$form-True.d" > "$task_tmp/$form.log" 2>&1; then
        echo "FAIL redundant trust: $form"; exit 1
    fi
    if ! grep -Ei '(pointer|index|slice).*(@safe|safe function)' "$task_tmp/$form.log" >/dev/null; then
        cat "$task_tmp/$form.log"; exit 1
    fi
    echo "PASS trust challenge: $form actual source requires trust"
    cat "$task_tmp/$form.log"
done
