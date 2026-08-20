#!/usr/bin/env bash
set -euo pipefail

binary_dir="${HOME}/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now sony-headphones.service >/dev/null 2>&1 || true
rm -f -- \
  "$binary_dir/sony-headphonesd" \
  "$binary_dir/sony-headphonesctl" \
  "$unit_dir/sony-headphones.service"
systemctl --user daemon-reload

printf '%s\n' \
  'Removed the native Sony Headphones binaries and user service.' \
  'Private state and any separately managed desktop plugin were preserved.'
