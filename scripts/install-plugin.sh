#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
plugin_id="io.github.vyomjain6904.sony-headphones"
destination="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$plugin_id"

mkdir -p -- "$destination"
for file in manifest.json BarWidget.qml Panel.qml Service.qml Model.js LICENSE README.md; do
  install -m 0644 "$project_dir/$file" "$destination/$file"
done

printf 'Installed plugin files in %s\n' "$destination"
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins
else
  printf 'omarchy-shell is not installed on this host; discovery was not requested.\n'
fi
