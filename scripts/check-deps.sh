#!/usr/bin/env bash
set -u

missing=0

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'ok       %s\n' "$1"
  else
    printf 'missing  %s\n' "$1"
    missing=1
  fi
}

check_pkg_config() {
  if pkg-config --exists "$1" 2>/dev/null; then
    printf 'ok       pkg-config:%s %s\n' "$1" "$(pkg-config --modversion "$1")"
  else
    printf 'missing  pkg-config:%s\n' "$1"
    missing=1
  fi
}

check_command cmake
check_command c++
check_command git
check_command pkg-config
check_command node
check_command jq
check_pkg_config dbus-1
check_pkg_config bluez

if [ "$missing" -ne 0 ]; then
  printf '\nInstall the missing development packages listed in README.md.\n'
  exit 1
fi

printf '\nAll real-backend build dependencies are visible.\n'
