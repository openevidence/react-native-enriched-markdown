#!/usr/bin/env bash
# Builds and runs the C++ parser unit tests with the system compilers.
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${TMPDIR:-/tmp}/enriched-markdown-cpp-tests"
mkdir -p "$out"
cc -std=c99 -O1 -DMD4C_USE_UTF8=1 -c cpp/md4c/md4c.c -o "$out/md4c.o"
c++ -std=c++17 -O1 -Wall -Wextra -Wswitch -DMD4C_USE_UTF8=1 -Icpp/md4c -Icpp/parser \
  cpp/tests/dose_tags_test.cpp cpp/parser/MD4CParser.cpp "$out/md4c.o" -o "$out/dose_tags_test"
"$out/dose_tags_test"
