#!/usr/bin/env bash

# Shared, non-executable-by-itself helpers for the source installer lifecycle.
# Callers enable strict mode before sourcing this file.

sony_install_fail() {
  printf 'Source install safety check failed: %s\n' "$*" >&2
  exit 1
}

sony_sha256_file() {
  sha256sum -- "$1" | awk '{print $1}'
}

sony_sha256_text() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

sony_assert_absolute_path() {
  local target_path="$1"
  local label="$2"
  case "$target_path" in
    /*) ;;
    *) sony_install_fail "$label must be an absolute path: $target_path" ;;
  esac
}

sony_check_managed_directory() {
  local directory_path="$1"
  local label="$2"

  if [ -L "$directory_path" ]; then
    sony_install_fail "$label is a symbolic link: $directory_path"
  fi
  if [ -e "$directory_path" ] && [ ! -d "$directory_path" ]; then
    sony_install_fail "$label is not a directory: $directory_path"
  fi
  if [ -d "$directory_path" ] && [ "$(stat -c '%u' -- "$directory_path")" != "$(id -u)" ]; then
    sony_install_fail "$label is not owned by the current user: $directory_path"
  fi
}

# Returns success only when the target exists as a safe user-owned regular file.
# Absence returns 1; unsafe existing objects terminate the caller.
sony_existing_regular_file() {
  local target_path="$1"
  local label="$2"

  if [ -L "$target_path" ]; then
    sony_install_fail "$label is a symbolic link: $target_path"
  fi
  if [ ! -e "$target_path" ]; then
    return 1
  fi
  if [ ! -f "$target_path" ]; then
    sony_install_fail "$label is not a regular file: $target_path"
  fi
  if [ "$(stat -c '%u' -- "$target_path")" != "$(id -u)" ]; then
    sony_install_fail "$label is not owned by the current user: $target_path"
  fi
  if [ "$(stat -c '%h' -- "$target_path")" != "1" ]; then
    sony_install_fail "$label has multiple hard links: $target_path"
  fi
  return 0
}

declare -A SONY_INSTALL_RECEIPT=()

sony_load_install_receipt() {
  local receipt_path="$1"
  local receipt_mode
  local receipt_key
  local receipt_value
  local expected_key
  local -a expected_keys=(
    schema checkout daemon_path daemon_hash control_path control_hash
    service_path service_hash
  )

  if ! sony_existing_regular_file "$receipt_path" "ownership receipt"; then
    sony_install_fail "ownership receipt disappeared during validation: $receipt_path"
  fi
  receipt_mode="$(stat -c '%a' -- "$receipt_path")"
  if (( (8#$receipt_mode & 077) != 0 )); then
    sony_install_fail "ownership receipt must not be accessible by group or other users: $receipt_path"
  fi

  SONY_INSTALL_RECEIPT=()
  while IFS='=' read -r receipt_key receipt_value || [ -n "$receipt_key$receipt_value" ]; do
    if [ -z "$receipt_key" ] || [ -z "$receipt_value" ]; then
      sony_install_fail "ownership receipt contains an empty field: $receipt_path"
    fi
    case "$receipt_key" in
      schema|checkout|daemon_path|daemon_hash|control_path|control_hash|service_path|service_hash) ;;
      *) sony_install_fail "ownership receipt contains an unknown field '$receipt_key': $receipt_path" ;;
    esac
    if [[ -v "SONY_INSTALL_RECEIPT[$receipt_key]" ]]; then
      sony_install_fail "ownership receipt contains duplicate field '$receipt_key': $receipt_path"
    fi
    SONY_INSTALL_RECEIPT["$receipt_key"]="$receipt_value"
  done < "$receipt_path"

  for expected_key in "${expected_keys[@]}"; do
    if [[ ! -v "SONY_INSTALL_RECEIPT[$expected_key]" ]]; then
      sony_install_fail "ownership receipt is missing field '$expected_key': $receipt_path"
    fi
  done
  if [ "${SONY_INSTALL_RECEIPT[schema]}" != "1" ]; then
    sony_install_fail "unsupported ownership receipt schema: ${SONY_INSTALL_RECEIPT[schema]}"
  fi
  for expected_key in checkout daemon_path daemon_hash control_path control_hash service_path service_hash; do
    if [[ ! ${SONY_INSTALL_RECEIPT[$expected_key]} =~ ^[0-9a-f]{64}$ ]]; then
      sony_install_fail "ownership receipt field '$expected_key' is invalid: $receipt_path"
    fi
  done
}

sony_validate_receipt_context() {
  local checkout_id="$1"
  local daemon_path_id="$2"
  local control_path_id="$3"
  local service_path_id="$4"

  if [ "${SONY_INSTALL_RECEIPT[checkout]}" != "$checkout_id" ]; then
    sony_install_fail "the installed files are owned by a different source checkout"
  fi
  if [ "${SONY_INSTALL_RECEIPT[daemon_path]}" != "$daemon_path_id" ] \
    || [ "${SONY_INSTALL_RECEIPT[control_path]}" != "$control_path_id" ] \
    || [ "${SONY_INSTALL_RECEIPT[service_path]}" != "$service_path_id" ]; then
    sony_install_fail "the ownership receipt belongs to different destination paths"
  fi
}

sony_write_install_receipt() {
  local receipt_path="$1"
  local checkout_id="$2"
  local daemon_path_id="$3"
  local daemon_hash="$4"
  local control_path_id="$5"
  local control_hash="$6"
  local service_path_id="$7"
  local service_hash="$8"

  umask 077
  printf '%s\n' \
    'schema=1' \
    "checkout=$checkout_id" \
    "daemon_path=$daemon_path_id" \
    "daemon_hash=$daemon_hash" \
    "control_path=$control_path_id" \
    "control_hash=$control_hash" \
    "service_path=$service_path_id" \
    "service_hash=$service_hash" \
    > "$receipt_path"
  chmod 0600 -- "$receipt_path"
}
