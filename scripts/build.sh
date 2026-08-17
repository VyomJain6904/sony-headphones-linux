#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
build_dir="$project_dir/build/native"
with_libmdr=1
build_type="RelWithDebInfo"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --without-libmdr) with_libmdr=0 ;;
    --debug) build_type="Debug" ;;
    --help|-h)
      printf 'Usage: %s [--without-libmdr] [--debug]\n' "$0"
      exit 0
      ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

# T3 Code is distributed as an AppImage. Its loader variables can confuse a host CMake.
unset APPDIR APPIMAGE LD_LIBRARY_PATH

cmake_args=(
  -S "$project_dir"
  -B "$build_dir"
  -DCMAKE_BUILD_TYPE="$build_type"
  -DBUILD_TESTING=ON
)

if [ "$with_libmdr" -eq 1 ]; then
  "$script_dir/check-deps.sh"
  source "$script_dir/libmdr-version.sh"
  libmdr_source="${SONY_LIBMDR_SOURCE_DIR:-}"
  if [ -z "$libmdr_source" ]; then
    libmdr_source="$($script_dir/fetch-libmdr.sh | tail -n 1)"
  fi
  actual_libmdr_commit="$(git -C "$libmdr_source" rev-parse HEAD)"
  if [ "$actual_libmdr_commit" != "$LIBMDR_COMMIT" ]; then
    printf 'libmdr source is not at the reviewed commit: %s\n' "$actual_libmdr_commit" >&2
    exit 1
  fi
  libmdr_build="$project_dir/build/libmdr"
  cmake -S "$libmdr_source" -B "$libmdr_build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DMDR_BUILD_CLIENT=OFF \
    -DMDR_ENABLE_CODEGEN=OFF \
    -DMDR_ENABLE_LOG=OFF \
    -DMDR_BLE=OFF \
    -DBUILD_TESTING=OFF
  actual_fmt_commit="$(git -C "$libmdr_build/_deps/fmt-src" rev-parse HEAD)"
  if [ "$actual_fmt_commit" != "$FMT_COMMIT" ]; then
    printf 'fmt source is not at the reviewed commit: %s\n' "$actual_fmt_commit" >&2
    exit 1
  fi
  cmake --build "$libmdr_build" --target mdr mdr-bt --parallel
  cmake_args+=(
    -DSONY_WITH_LIBMDR=ON
    -DSONY_LIBMDR_SOURCE_DIR="$libmdr_source"
    -DSONY_LIBMDR_BUILD_DIR="$libmdr_build"
  )
else
  cmake_args+=(-DSONY_WITH_LIBMDR=OFF)
fi

cmake "${cmake_args[@]}"
cmake --build "$build_dir" --parallel
ctest --test-dir "$build_dir" --output-on-failure

printf '\nBuilt binaries:\n  %s\n  %s\n' \
  "$build_dir/sony-headphonesd" "$build_dir/sony-headphonesctl"
