#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"

jq empty "$project_dir/manifest.json"
node "$project_dir/tests/model.test.js"
bash -n "$project_dir"/scripts/*.sh "$project_dir"/tests/*.sh
"$script_dir/check-aur.sh"

expected_id="io.github.vyomjain6904.sony-headphones"
actual_id="$(jq -r '.id' "$project_dir/manifest.json")"
entry="$(jq -r '.entryPoints.barWidget' "$project_dir/manifest.json")"
manifest_version="$(jq -r '.version' "$project_dir/manifest.json")"
cmake_version="$(sed -nE 's/^project\(sony-headphones-linux VERSION ([0-9]+\.[0-9]+\.[0-9]+) LANGUAGES CXX\)$/\1/p' "$project_dir/CMakeLists.txt")"
if [ "$actual_id" != "$expected_id" ]; then
  printf 'Manifest ID mismatch: %s\n' "$actual_id" >&2
  exit 1
fi
if [ ! -f "$project_dir/$entry" ]; then
  printf 'Manifest entry point not found: %s\n' "$entry" >&2
  exit 1
fi
if [ -z "$cmake_version" ] || [ "$manifest_version" != "$cmake_version" ]; then
  printf 'Manifest/CMake version mismatch: manifest=%s cmake=%s\n' "$manifest_version" "${cmake_version:-missing}" >&2
  exit 1
fi
if find "$project_dir/scripts" "$project_dir/tests" -maxdepth 1 -type f -name '*.sh' ! -perm -0100 -print -quit | grep -q .; then
  printf 'Every script under scripts/ must be executable.\n' >&2
  exit 1
fi

# Current user and maintainer documentation may only reference tracked scripts.
doc_files=(
  "$project_dir/README.md"
  "$project_dir/docs/DEVELOPMENT.md"
  "$project_dir/docs/PUBLISHING.md"
  "$project_dir/packaging/aur/README.md"
)
mapfile -t documented_scripts < <(
  grep -Eoh '(\./)?scripts/[[:alnum:]_.-]+\.sh' "${doc_files[@]}" \
    | sed 's#^\./##' \
    | sort -u
)
for script_path in "${documented_scripts[@]}"; do
  if [ ! -x "$project_dir/$script_path" ]; then
    printf 'Documentation references a missing or non-executable script: %s\n' "$script_path" >&2
    exit 1
  fi
done
if grep -En 'scripts/(deploy-native|remove-native|undeploy-native)\.sh' "${doc_files[@]}"; then
  printf 'Current documentation references an obsolete native lifecycle script.\n' >&2
  exit 1
fi

readme_lines="$(wc -l < "$project_dir/README.md")"
if [ "$readme_lines" -gt 220 ]; then
  printf 'README is too long for the concise user guide: %s lines\n' "$readme_lines" >&2
  exit 1
fi
if [ ! -f "$project_dir/preview.png" ]; then
  printf 'Marketplace root preview is missing: preview.png\n' >&2
  exit 1
fi

# Dependency source revisions must be exact commits and CMake must consume the
# verified local fmt checkout without running its mutable FetchContent recipe.
# shellcheck disable=SC1091
source "$script_dir/libmdr-version.sh"
if ! [[ "$LIBMDR_COMMIT" =~ ^[0-9a-f]{40}$ && "$FMT_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'Dependency pins must be full lowercase Git commit IDs.\n' >&2
  exit 1
fi
grep -Fq -- '-DFETCHCONTENT_FULLY_DISCONNECTED=ON' "$script_dir/build.sh"
# The single-quoted pattern intentionally matches the literal shell variable.
# shellcheck disable=SC2016
grep -Fq -- '-DFETCHCONTENT_SOURCE_DIR_FMT="$fmt_source"' "$script_dir/build.sh"
if find "$project_dir" -path "$project_dir/build" -prune -o -path "$project_dir/.deps" -prune \
  -o -path "$project_dir/packaging/aur/pkg" -prune -o -path "$project_dir/packaging/aur/src" -prune \
  -o -type l -print -quit | grep -q .; then
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
  -o -path "$project_dir/packaging/aur/pkg" -prune -o -path "$project_dir/packaging/aur/src" -prune \
  -o -type f -name '*.py' -print -quit | grep -q .; then
  printf 'Python source found; the project intentionally has no Python runtime or build scripts.\n' >&2
  exit 1
fi

printf 'check.sh: manifest, JavaScript model, paths, and source policy passed\n'
