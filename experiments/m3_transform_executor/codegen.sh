#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
python3 "$root/codegen.py" "$tmp_dir"
dmd --version
ldc2 --version
for form in pointer slice; do
    echo "form=$form DMD=-O -release -inline -preview=dip1000 LDC=-O3 -release -enable-inlining -preview=dip1000"
    dmd -O -release -inline -preview=dip1000 -c "$tmp_dir/$form.d" -of="$tmp_dir/$form.o"
    ldc2 -O3 -release -enable-inlining -preview=dip1000 -output-ll -c \
        "$tmp_dir/$form.d" -of="$tmp_dir/$form.ll"
    # Evidence for a specific question: does safe indexing block vectorization
    # or leave a bounds-error edge in these isolated concrete row kernels?
    echo 'DMD bounds-error relocations:'
    objdump -r "$tmp_dir/$form.o" | grep '_d_arraybounds' || true
    echo 'LDC vector-load types:'
    grep -oE 'load <[0-9]+ x (float|i8)>' "$tmp_dir/$form.ll" | sort | uniq -c
    echo 'LDC bounds-error calls:'
    grep -E 'call .*_d_arraybounds' "$tmp_dir/$form.ll" || true
done
