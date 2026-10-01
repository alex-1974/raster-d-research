#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
out="${1:?Usage: collect.sh OUTPUT_DIRECTORY [CPU] [container|xps]}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
cpu="${2:-0}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
python3 "$root/generate.py" > "$out/generation.txt"
"$root/build_cpp.sh" > "$out/cpp-build.txt" 2>&1
objdump -dr "$root/cpp_reference.o" > "$out/cpp-codegen.txt"
{
    uname -a
    lscpu
    echo "affinity CPU=$cpu; VM/host frequency and thermal controls unchanged"
    dub --version
} > "$out/environment.txt"
sha256sum "$root/cpp_reference.o" > "$out/binaries.sha256"
for compiler in dmd ldc2; do
    "$compiler" --version >> "$out/environment.txt"
    dub test --root="$root" --compiler="$compiler" --force > "$out/$compiler-tests.txt" 2>&1
    "$root/trusted_challenge.sh" "$compiler" > "$out/$compiler-trust.txt" 2>&1
    dub build --root="$root" --compiler="$compiler" --build=release --force --vverbose \
        > "$out/$compiler-build.txt" 2>&1
    cp "$root/raster-m3-strict-reduction" "$tmp_dir/$compiler"
    sha256sum "$tmp_dir/$compiler" >> "$out/binaries.sha256"
done
for run in 1 2 3; do
    taskset -c "$cpu" "$tmp_dir/dmd" > "$out/dmd-run-$run.txt"
    taskset -c "$cpu" "$tmp_dir/ldc2" > "$out/ldc-run-$run.txt"
done
"$root/codegen.sh" > "$out/codegen.txt" 2>&1
python3 "$root/summarize.py" "$out" --environment "${3:-container}" > "$out/SUMMARY.md"

python3 - "$out" <<'CHECKSUMS'
import hashlib,sys
from pathlib import Path
out=Path(sys.argv[1])
lines=[hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name
    for p in sorted(out.iterdir()) if p.is_file() and p.name!='SHA256SUMS']
(out/'SHA256SUMS').write_text('\n'.join(lines)+'\n')
CHECKSUMS
