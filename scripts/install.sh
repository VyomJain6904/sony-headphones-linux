#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
build_dir="$project_dir/build/native"
binary_dir="${HOME:?HOME must be set}/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sony-headphones"
receipt_path="$state_dir/source-install.receipt"
daemon_source="$build_dir/sony-headphonesd"
control_source="$build_dir/sony-headphonesctl"
service_source="$project_dir/systemd/sony-headphones.service"
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

if [ ! -f "$daemon_source" ] || [ -L "$daemon_source" ] || [ ! -x "$daemon_source" ] \
  || [ ! -f "$control_source" ] || [ -L "$control_source" ] || [ ! -x "$control_source" ]; then
  printf 'Build the project first with ./scripts/build.sh\n' >&2
  exit 1
fi
if [ ! -f "$service_source" ] || [ -L "$service_source" ]; then
  sony_install_fail "the source user service is missing or is a symbolic link: $service_source"
fi

checkout_id="$(sony_sha256_text "$project_dir")"
daemon_path_id="$(sony_sha256_text "$daemon_target")"
control_path_id="$(sony_sha256_text "$control_target")"
service_path_id="$(sony_sha256_text "$service_target")"
daemon_source_hash="$(sony_sha256_file "$daemon_source")"
control_source_hash="$(sony_sha256_file "$control_source")"
service_source_hash="$(sony_sha256_file "$service_source")"
receipt_present=0

if [ -e "$receipt_path" ] || [ -L "$receipt_path" ]; then
  sony_load_install_receipt "$receipt_path"
  sony_validate_receipt_context \
    "$checkout_id" "$daemon_path_id" "$control_path_id" "$service_path_id"
  receipt_present=1
fi

targets=("$daemon_target" "$control_target" "$service_target")
sources=("$daemon_source" "$control_source" "$service_source")
labels=("daemon destination" "CLI destination" "user-service destination")
source_hashes=("$daemon_source_hash" "$control_source_hash" "$service_source_hash")
receipt_hash_keys=(daemon_hash control_hash service_hash)
modes=(0755 0755 0644)

preflight_targets() {
  local preflight_index
  local target_hash
  local expected_hash

  for preflight_index in "${!targets[@]}"; do
    if sony_existing_regular_file "${targets[$preflight_index]}" "${labels[$preflight_index]}"; then
      target_hash="$(sony_sha256_file "${targets[$preflight_index]}")"
      if [ "$receipt_present" -eq 1 ]; then
        expected_hash="${SONY_INSTALL_RECEIPT[${receipt_hash_keys[$preflight_index]}]}"
        if [ "$target_hash" != "$expected_hash" ]; then
          sony_install_fail "${labels[$preflight_index]} changed since this checkout installed it: ${targets[$preflight_index]}"
        fi
      elif [ "$target_hash" != "${source_hashes[$preflight_index]}" ]; then
        sony_install_fail "unrelated file already exists at ${targets[$preflight_index]}"
      fi
    fi
  done
}

preflight_targets
if [ "$receipt_present" -eq 1 ]; then
  initial_receipt_hash="$(sony_sha256_file "$receipt_path")"
else
  initial_receipt_hash=""
fi

mkdir -p -- "$binary_dir" "$unit_dir" "$state_dir"
chmod 0700 -- "$state_dir"

staged_files=()
backup_files=()
had_existing=()
receipt_stage=""
receipt_backup=""
receipt_had_existing=0
transaction_active=0

rollback_install() {
  local exit_status="$?"
  local rollback_index

  trap - EXIT
  if [ "$transaction_active" -eq 1 ]; then
    for (( rollback_index=${#targets[@]}-1; rollback_index>=0; rollback_index-- )); do
      if [ "${had_existing[$rollback_index]:-0}" -eq 1 ] \
        && [ -n "${backup_files[$rollback_index]:-}" ] \
        && [ -f "${backup_files[$rollback_index]}" ]; then
        mv -fT -- "${backup_files[$rollback_index]}" "${targets[$rollback_index]}" || true
      else
        rm -f -- "${targets[$rollback_index]}"
      fi
    done
    if [ "$receipt_had_existing" -eq 1 ] && [ -f "$receipt_backup" ]; then
      mv -fT -- "$receipt_backup" "$receipt_path" || true
    else
      rm -f -- "$receipt_path"
    fi
  fi
  for cleanup_file in "${staged_files[@]}" "${backup_files[@]}" "$receipt_stage" "$receipt_backup"; do
    if [ -n "$cleanup_file" ]; then
      rm -f -- "$cleanup_file"
    fi
  done
  exit "$exit_status"
}
trap rollback_install EXIT

for target_index in "${!targets[@]}"; do
  target_directory="${targets[$target_index]%/*}"
  target_name="${targets[$target_index]##*/}"
  staged_file="$(mktemp "$target_directory/.${target_name}.install.XXXXXX")"
  install -m "${modes[$target_index]}" "${sources[$target_index]}" "$staged_file"
  if [ "$(sony_sha256_file "$staged_file")" != "${source_hashes[$target_index]}" ]; then
    sony_install_fail "staged ${labels[$target_index]} failed its integrity check"
  fi
  staged_files[target_index]="$staged_file"
  if [ -e "${targets[$target_index]}" ]; then
    backup_file="$(mktemp "$target_directory/.${target_name}.backup.XXXXXX")"
    cp -p -- "${targets[$target_index]}" "$backup_file"
    if [ "$(sony_sha256_file "$backup_file")" != "$(sony_sha256_file "${targets[$target_index]}")" ]; then
      sony_install_fail "could not stage a verified backup of ${labels[$target_index]}"
    fi
    backup_files[target_index]="$backup_file"
    had_existing[target_index]=1
  else
    backup_files[target_index]=""
    had_existing[target_index]=0
  fi
done

receipt_stage="$(mktemp "$state_dir/.source-install.receipt.XXXXXX")"
sony_write_install_receipt \
  "$receipt_stage" "$checkout_id" \
  "$daemon_path_id" "$daemon_source_hash" \
  "$control_path_id" "$control_source_hash" \
  "$service_path_id" "$service_source_hash"

if [ "$receipt_present" -eq 1 ]; then
  receipt_backup="$(mktemp "$state_dir/.source-install.receipt.backup.XXXXXX")"
  cp -p -- "$receipt_path" "$receipt_backup"
  if [ "$(sony_sha256_file "$receipt_backup")" != "$initial_receipt_hash" ]; then
    sony_install_fail "could not stage a verified backup of the ownership receipt"
  fi
  receipt_had_existing=1
fi

# Close the preflight-to-commit window before replacing any path.
preflight_targets
if [ "$receipt_present" -eq 1 ]; then
  if [ "$(sony_sha256_file "$receipt_path")" != "$initial_receipt_hash" ]; then
    sony_install_fail "ownership receipt changed during installation: $receipt_path"
  fi
elif [ -e "$receipt_path" ] || [ -L "$receipt_path" ]; then
  sony_install_fail "an ownership receipt appeared during installation: $receipt_path"
fi

transaction_active=1
for target_index in "${!targets[@]}"; do
  mv -fT -- "${staged_files[$target_index]}" "${targets[$target_index]}"
done
mv -fT -- "$receipt_stage" "$receipt_path"
transaction_active=0

for cleanup_file in "${backup_files[@]}" "$receipt_backup"; do
  if [ -n "$cleanup_file" ]; then
    rm -f -- "$cleanup_file"
  fi
done
trap - EXIT

systemctl --user daemon-reload
printf '%s\n' \
  'Installed the native Sony Headphones binaries and user service.' \
  "Ownership receipt: $receipt_path" \
  'Enable the service with:' \
  '  systemctl --user enable --now sony-headphones.service'
