#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
# Resolved from this script's runtime directory.
# shellcheck disable=SC1091
source "$script_dir/libmdr-version.sh"

destination="${SONY_LIBMDR_SOURCE_DIR:-$project_dir/.deps/SonyHeadphonesClient}"
mkdir -p -- "$(dirname -- "$destination")"

if [ ! -d "$destination/.git" ]; then
  if [ -e "$destination" ]; then
    printf 'Dependency target exists but is not a Git checkout: %s\n' "$destination" >&2
    exit 1
  fi
  git clone --filter=blob:none --no-checkout "$LIBMDR_REPOSITORY" "$destination"
fi

git -C "$destination" fetch --depth 1 origin "$LIBMDR_COMMIT"
git -C "$destination" checkout --detach "$LIBMDR_COMMIT"

actual="$(git -C "$destination" rev-parse HEAD)"
if [ "$actual" != "$LIBMDR_COMMIT" ]; then
  printf 'Pinned libmdr verification failed: expected %s, got %s\n' "$LIBMDR_COMMIT" "$actual" >&2
  exit 1
fi

printf '%s\n' "$destination"
