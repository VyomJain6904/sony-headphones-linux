#!/usr/bin/env bash
# Installs the built plugin into Decky Loader. Run with: sudo ./install.sh
set -euo pipefail
src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dest="/home/deck/homebrew/plugins/sony-headphones"
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo: sudo $0" >&2; exit 1; }
[ -f "$src/dist/index.js" ] || { echo "dist/index.js missing; build first" >&2; exit 1; }
rm -rf -- "$dest"
install -d "$dest/dist"
install -m 644 "$src/plugin.json" "$src/package.json" "$src/main.py" "$dest/"
install -m 644 "$src/dist/index.js" "$dest/dist/"
systemctl restart plugin_loader
echo "Installed to $dest and restarted Decky Loader."
