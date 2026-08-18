#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
build_dir="$project_dir/build/sanitize"
sanitizers="-fsanitize=address,undefined -fno-omit-frame-pointer"

cmake -S "$project_dir" -B "$build_dir" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS="$sanitizers" \
  -DCMAKE_EXE_LINKER_FLAGS="$sanitizers" \
  -DSONY_WITH_LIBMDR=OFF \
  -DBUILD_TESTING=ON
cmake --build "$build_dir" --parallel
ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 \
UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
  ctest --test-dir "$build_dir" --output-on-failure
