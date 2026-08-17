#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"

jq empty "$project_dir/manifest.json"
node "$project_dir/tests/model.test.js"

expected_id="io.github.vyomjain6904.sony-headphones"
actual_id="$(jq -r '.id' "$project_dir/manifest.json")"
entry="$(jq -r '.entryPoints.barWidget' "$project_dir/manifest.json")"
if [ "$actual_id" != "$expected_id" ]; then
  printf 'Manifest ID mismatch: %s\n' "$actual_id" >&2
  exit 1
fi
if [ ! -f "$project_dir/$entry" ]; then
  printf 'Manifest entry point not found: %s\n' "$entry" >&2
  exit 1
fi
if find "$project_dir" -path "$project_dir/build" -prune -o -path "$project_dir/.deps" -prune -o -type l -print -quit | grep -q .; then
  printf 'Repository contains a symlink; plugin distributions may not contain symlinks.\n' >&2
  exit 1
fi
if grep -RIn --exclude-dir=build --exclude-dir=.deps --exclude-dir=graphify-out \
  -E '(^|[^[:alpha:]])(python3?|pip3?|360 Reality Audio)' \
  "$project_dir"/*.qml "$project_dir"/native 2>/dev/null; then
  printf 'Forbidden runtime/build dependency or excluded feature found in executable sources.\n' >&2
  exit 1
fi
if find "$project_dir" -path "$project_dir/build" -prune -o -path "$project_dir/.deps" -prune \
  -o -type f -name '*.py' -print -quit | grep -q .; then
  printf 'Python source found; the project intentionally has no Python runtime or build scripts.\n' >&2
  exit 1
fi

printf 'check.sh: manifest, JavaScript model, paths, and source policy passed\n'
