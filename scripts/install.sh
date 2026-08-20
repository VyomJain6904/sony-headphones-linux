#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
build_dir="$project_dir/build/native"
binary_dir="${HOME}/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

if [ ! -x "$build_dir/sony-headphonesd" ] || [ ! -x "$build_dir/sony-headphonesctl" ]; then
  printf 'Build the project first with ./scripts/build.sh\n' >&2
  exit 1
fi

mkdir -p -- "$binary_dir" "$unit_dir"
install -m 0755 "$build_dir/sony-headphonesd" "$binary_dir/sony-headphonesd"
install -m 0755 "$build_dir/sony-headphonesctl" "$binary_dir/sony-headphonesctl"
install -m 0644 "$project_dir/systemd/sony-headphones.service" \
  "$unit_dir/sony-headphones.service"

systemctl --user daemon-reload
printf '%s\n' \
  'Installed the native Sony Headphones binaries and user service.' \
  'Enable the service with:' \
  '  systemctl --user enable --now sony-headphones.service'
