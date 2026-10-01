#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
cxx="${CXX:-g++}"
"$cxx" --version
set -x
"$cxx" -std=c++17 -O3 -fno-fast-math -ffp-contract=off -fno-lto \
    -c "$root/cpp_reference.cpp" -o "$root/cpp_reference.o"
