#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
aur_dir="$project_dir/packaging/aur"
pkgbuild="$aur_dir/PKGBUILD"

bash -n "$pkgbuild" "$aur_dir/sony-headphones-omarchy.install"

manifest_version="$(jq -r '.version' "$project_dir/manifest.json")"
pkgbuild_version="$(sed -nE 's/^pkgver=([^[:space:]]+)$/\1/p' "$pkgbuild")"
if [ -z "$pkgbuild_version" ] || [ "$pkgbuild_version" != "$manifest_version" ]; then
  printf 'Manifest/AUR version mismatch: manifest=%s PKGBUILD=%s\n' \
    "$manifest_version" "${pkgbuild_version:-missing}" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$script_dir/libmdr-version.sh"
pkgbuild_libmdr="$(sed -nE "s/^_libmdr_commit='([^']+)'$/\\1/p" "$pkgbuild")"
pkgbuild_fmt="$(sed -nE "s/^_fmt_commit='([^']+)'$/\\1/p" "$pkgbuild")"
if [ "$pkgbuild_libmdr" != "$LIBMDR_COMMIT" ] || [ "$pkgbuild_fmt" != "$FMT_COMMIT" ]; then
  printf 'AUR dependency pins do not match scripts/libmdr-version.sh\n' >&2
  exit 1
fi

# The single-quoted expression intentionally matches a literal "$HOME" token.
# shellcheck disable=SC2016
if grep -En '(\$HOME|/home/|~/|\.config/omarchy/plugins)' \
  "$pkgbuild" "$aur_dir/sony-headphones-omarchy.install"; then
  printf 'The native AUR package must not write into a user home or own the QML plugin checkout.\n' >&2
  exit 1
fi

if command -v makepkg >/dev/null 2>&1; then
  generated_srcinfo="$(mktemp)"
  trap 'rm -f -- "$generated_srcinfo"' EXIT
  (
    cd -- "$aur_dir"
    makepkg --printsrcinfo
  ) > "$generated_srcinfo"
  diff -u "$aur_dir/.SRCINFO" "$generated_srcinfo"
else
  printf 'warning: makepkg is unavailable; skipped generated .SRCINFO comparison\n' >&2
fi

printf 'check-aur.sh: package version, pins, paths, scripts, and .SRCINFO passed\n'
