#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
out="${1:?Usage: collect.sh OUTPUT_DIRECTORY [CPU] [container|xps]}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
cpu="${2:-0}"
task_tmp="$(mktemp -d)"
trap 'rm -rf "$task_tmp"' EXIT
python3 "$root/generate.py" > "$out/generation.txt"
"$root/build_cpp.sh" > "$out/cpp-build.txt" 2>&1
objdump -dr "$root/cpp_reference.o" > "$out/cpp-codegen.txt"
{
    uname -a
    lscpu
    echo "affinity CPU=$cpu; frequency/thermal controls unchanged"
    dub --version
} > "$out/environment.txt"
sha256sum "$root/cpp_reference.o" > "$out/binaries.sha256"
for compiler in dmd ldc2; do
    "$compiler" --version >> "$out/environment.txt"
    dub test --root="$root" --compiler="$compiler" --force > "$out/$compiler-tests.txt" 2>&1
    "$root/trusted_challenge.sh" "$compiler" > "$out/$compiler-trust.txt" 2>&1
    dub build --root="$root" --compiler="$compiler" --build=release --force --vverbose > "$out/$compiler-build.txt" 2>&1
    cp "$root/raster-m3-copy-conversion" "$task_tmp/$compiler"
    sha256sum "$task_tmp/$compiler" >> "$out/binaries.sha256"
done
for n in 1 2 3; do
    taskset -c "$cpu" "$task_tmp/dmd" > "$out/dmd-run-$n.txt"
    taskset -c "$cpu" "$task_tmp/ldc2" > "$out/ldc-run-$n.txt"
done
python3 "$root/summarize.py" "$out" --environment "${3:-container}" > "$out/SUMMARY.md"
python3 - "$out" <<'PY'
import hashlib,sys
from pathlib import Path
p=Path(sys.argv[1]);(p/'SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in sorted(p.iterdir()) if f.is_file() and f.name!='SHA256SUMS'))
PY
