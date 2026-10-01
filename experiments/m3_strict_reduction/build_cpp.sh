#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
compiler="${CXX:-g++}"
"$compiler" --version
set -x
"$compiler" -std=c++17 -O3 -fno-fast-math -ffp-contract=off -fno-lto -c \
    "$root/cpp_reference.cpp" -o "$root/cpp_reference.o"
