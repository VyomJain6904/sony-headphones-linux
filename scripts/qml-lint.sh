#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
shell_root="${OMARCHY_PATH:-/usr/share/omarchy}/shell"

if [ -x /usr/lib/qt6/bin/qmllint ]; then
  qmllint_bin=/usr/lib/qt6/bin/qmllint
elif command -v qmllint >/dev/null 2>&1 && qmllint --version 2>&1 | grep -q ' 6\.'; then
  qmllint_bin="$(command -v qmllint)"
else
  printf 'Qt 6 qmllint is required; the Qt 5 tool cannot validate Omarchy QML.\n' >&2
  exit 1
fi

if [ ! -d "$shell_root/Ui" ] || [ ! -d "$shell_root/Commons" ]; then
  printf 'Omarchy shell QML was not found under %s\n' "$shell_root" >&2
  exit 1
fi

# Quickshell maps `qs.Ui` to <shell>/Ui at runtime. Standard Qt tooling does
# not know that special namespace, so reproduce it in an isolated import root.
lint_root="$(mktemp -d /tmp/sony-headphones-qmllint.XXXXXX)"
cleanup() {
  case "$lint_root" in
    /tmp/sony-headphones-qmllint.*) rm -rf -- "$lint_root" ;;
  esac
}
trap cleanup EXIT
mkdir -p -- "$lint_root/qs"
ln -s -- "$shell_root/Ui" "$lint_root/qs/Ui"
ln -s -- "$shell_root/Commons" "$lint_root/qs/Commons"

exec "$qmllint_bin" \
  -I "$shell_root" \
  -I "$lint_root" \
  "$project_dir/BarWidget.qml" \
  "$project_dir/Panel.qml" \
  "$project_dir/Service.qml"
