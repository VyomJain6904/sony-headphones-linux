#!/usr/bin/env bash
# Builds the Decky release zip: out/sony-headphones.zip (install via Decky > Developer > Install from ZIP).
set -euo pipefail
dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$dir"
[ -f dist/index.js ] || { echo "dist/index.js missing; run 'pnpm install && pnpm build' first" >&2; exit 1; }
stage="$(mktemp -d)"; trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/sony-headphones/dist" out
install -m 644 plugin.json package.json main.py LICENSE README.md "$stage/sony-headphones/"
install -m 644 dist/index.js "$stage/sony-headphones/dist/"
rm -f out/sony-headphones.zip
(cd "$stage" && zip -qr "$dir/out/sony-headphones.zip" sony-headphones)
echo "Wrote $dir/out/sony-headphones.zip"
