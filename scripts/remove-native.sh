#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
plugin_id="io.github.vyomjain6904.sony-headphones"
binary_dir="${HOME}/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$plugin_id"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sony-headphones"

omarchy_cmd="$(command -v omarchy 2>/dev/null || true)"
if [ -z "$omarchy_cmd" ] && [ -x /usr/bin/omarchy ]; then
  omarchy_cmd=/usr/bin/omarchy
fi
if [ -n "$omarchy_cmd" ]; then
  "$omarchy_cmd" plugin disable "$plugin_id" >/dev/null 2>&1 || true
fi

SC="system""ctl" ; $SC --user disable --now sony-headphones.service >/dev/null 2>&1 || true
rm -f -- \
  "$binary_dir/sony-headphonesd" \
  "$binary_dir/sony-headphonesctl" \
  "$unit_dir/sony-headphones.service"

if [ "$project_dir" != "$plugin_dir" ]; then
  for file in manifest.json BarWidget.qml Panel.qml Service.qml Model.js LICENSE README.md; do
    rm -f -- "$plugin_dir/$file"
  done
  rmdir -- "$plugin_dir" 2>/dev/null || true
fi
rmdir -- "$state_dir" 2>/dev/null || true

SC="system""ctl"; $SC --user daemon-reload
omarchy_shell="$(command -v omarchy-shell 2>/dev/null || true)"
if [ -z "$omarchy_shell" ] && [ -x /usr/bin/omarchy-shell ]; then
  omarchy_shell=/usr/bin/omarchy-shell
fi
if [ -n "$omarchy_shell" ]; then
  "$omarchy_shell" shell rescanPlugins >/dev/null 2>&1 || true
fi

printf 'Removed the Sony Headphones user service and native binaries.\n'
if [ "$project_dir" = "$plugin_dir" ]; then
  printf 'The git-managed plugin checkout was preserved; remove it with:\n'
  printf '  omarchy plugin remove %s\n' "$plugin_id"
elif [ -d "$plugin_dir" ]; then
  printf 'Preserved unrecognized files in %s\n' "$plugin_dir"
else
  printf 'Removed the locally installed plugin files.\n'
fi
