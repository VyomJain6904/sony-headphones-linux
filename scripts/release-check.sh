#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"

cd -- "$project_dir"
git diff --check
"$script_dir/check.sh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "$script_dir"/*.sh "$project_dir"/tests/*.sh
else
  printf 'warning: shellcheck is unavailable; Bash syntax was still checked by check.sh\n' >&2
fi
"$script_dir/build.sh" --without-libmdr
ctest --test-dir "$project_dir/build/native" --output-on-failure
"$project_dir/tests/installers.test.sh"
"$script_dir/mock-e2e.sh"
"$script_dir/sanitize.sh"
"$script_dir/build.sh"
"$script_dir/qml-lint.sh"

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$project_dir"
else
  printf 'warning: Omarchy is unavailable; plugin validation must run on the release host\n' >&2
fi
