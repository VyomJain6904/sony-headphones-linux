#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
binary_dir="${HOME:?HOME must be set}/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sony-headphones"
receipt_path="$state_dir/source-install.receipt"
daemon_target="$binary_dir/sony-headphonesd"
control_target="$binary_dir/sony-headphonesctl"
service_target="$unit_dir/sony-headphones.service"

# Resolved from this script's runtime directory.
# shellcheck disable=SC1091
source "$script_dir/source-install-common.sh"

sony_assert_absolute_path "$binary_dir" "binary directory"
sony_assert_absolute_path "$unit_dir" "systemd user-unit directory"
sony_assert_absolute_path "$state_dir" "state directory"
sony_check_managed_directory "$binary_dir" "binary directory"
sony_check_managed_directory "$unit_dir" "systemd user-unit directory"
sony_check_managed_directory "$state_dir" "state directory"

targets=("$daemon_target" "$control_target" "$service_target")
labels=("daemon destination" "CLI destination" "user-service destination")
receipt_hash_keys=(daemon_hash control_hash service_hash)

if [ ! -e "$receipt_path" ] && [ ! -L "$receipt_path" ]; then
  unmanaged_present=0
  for target_index in "${!targets[@]}"; do
    if [ -e "${targets[$target_index]}" ] || [ -L "${targets[$target_index]}" ]; then
      unmanaged_present=1
    fi
  done
  if [ "$unmanaged_present" -eq 1 ]; then
    sony_install_fail "no ownership receipt exists; refusing to remove native paths"
  fi
  printf '%s\n' \
    'No source-installed native Sony Headphones files are recorded for this checkout.' \
    'Private state and any separately managed desktop plugin were preserved.'
  exit 0
fi

sony_load_install_receipt "$receipt_path"
checkout_id="$(sony_sha256_text "$project_dir")"
daemon_path_id="$(sony_sha256_text "$daemon_target")"
control_path_id="$(sony_sha256_text "$control_target")"
service_path_id="$(sony_sha256_text "$service_target")"
sony_validate_receipt_context \
  "$checkout_id" "$daemon_path_id" "$control_path_id" "$service_path_id"

validate_owned_targets() {
  local validation_index
  local actual_hash
  local expected_hash

  for validation_index in "${!targets[@]}"; do
    if sony_existing_regular_file "${targets[$validation_index]}" "${labels[$validation_index]}"; then
      actual_hash="$(sony_sha256_file "${targets[$validation_index]}")"
      expected_hash="${SONY_INSTALL_RECEIPT[${receipt_hash_keys[$validation_index]}]}"
      if [ "$actual_hash" != "$expected_hash" ]; then
        sony_install_fail "${labels[$validation_index]} changed since this checkout installed it: ${targets[$validation_index]}"
      fi
    fi
  done
}

validate_owned_targets
receipt_hash="$(sony_sha256_file "$receipt_path")"

if [ -e "$service_target" ]; then
  systemctl --user disable --now sony-headphones.service >/dev/null 2>&1 || true
fi

# Recheck after service shutdown and immediately before removal. A mismatch
# leaves every remaining artifact and the receipt in place for manual review.
validate_owned_targets
if [ "$(sony_sha256_file "$receipt_path")" != "$receipt_hash" ]; then
  sony_install_fail "ownership receipt changed during uninstall: $receipt_path"
fi

for target_index in "${!targets[@]}"; do
  if [ -e "${targets[$target_index]}" ]; then
    rm -f -- "${targets[$target_index]}"
  fi
done
rm -f -- "$receipt_path"

systemctl --user daemon-reload

printf '%s\n' \
  'Removed the native Sony Headphones binaries and user service.' \
  'Private state and any separately managed desktop plugin were preserved.'
