#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

daemon_source="$project_dir/build/native/sony-headphonesd"
control_source="$project_dir/build/native/sony-headphonesctl"
service_source="$project_dir/systemd/sony-headphones.service"

if [ ! -x "$daemon_source" ] || [ ! -x "$control_source" ]; then
  printf 'Build the native targets before running installer tests.\n' >&2
  exit 1
fi

setup_scenario() {
  local scenario_name="$1"

  scenario_root="$test_root/$scenario_name"
  test_home="$scenario_root/home"
  test_config="$scenario_root/config"
  test_state="$scenario_root/state"
  stub_bin="$scenario_root/stub-bin"
  systemctl_log="$scenario_root/systemctl.log"
  command_stdout="$scenario_root/stdout.log"
  command_stderr="$scenario_root/stderr.log"
  daemon_target="$test_home/.local/bin/sony-headphonesd"
  control_target="$test_home/.local/bin/sony-headphonesctl"
  service_target="$test_config/systemd/user/sony-headphones.service"
  receipt_target="$test_state/sony-headphones/source-install.receipt"

  mkdir -p -- \
    "$test_home" "$test_config" "$test_state/sony-headphones" "$stub_bin" \
    "$test_config/omarchy/plugins/keep"
  printf 'preserve\n' > "$test_state/sony-headphones/status.json"
  printf 'preserve\n' > "$test_config/omarchy/plugins/keep/marker"

  # The generated stub must expand these variables when it is executed, not now.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf '\''%s\n'\'' "$*" >> "$SONY_TEST_SYSTEMCTL_LOG"' \
    > "$stub_bin/systemctl"
  chmod 0755 "$stub_bin/systemctl"

  export HOME="$test_home"
  export XDG_CONFIG_HOME="$test_config"
  export XDG_STATE_HOME="$test_state"
  export SONY_TEST_SYSTEMCTL_LOG="$systemctl_log"
  export PATH="$stub_bin:$ORIGINAL_PATH"
}

expect_failure() {
  local expected_text="$1"
  shift

  if "$@" > "$command_stdout" 2> "$command_stderr"; then
    printf 'Expected command to fail: %s\n' "$*" >&2
    exit 1
  fi
  if ! grep -Fq -- "$expected_text" "$command_stderr"; then
    printf 'Failure did not contain expected text: %s\n' "$expected_text" >&2
    sed -n '1,120p' "$command_stderr" >&2
    exit 1
  fi
}

assert_no_systemctl_actions() {
  if [ -s "$systemctl_log" ]; then
    printf 'A failed preflight unexpectedly invoked systemctl:\n' >&2
    sed -n '1,120p' "$systemctl_log" >&2
    exit 1
  fi
}

assert_preserved_user_state() {
  test -f "$test_state/sony-headphones/status.json"
  test -f "$test_config/omarchy/plugins/keep/marker"
}

ORIGINAL_PATH="$PATH"

# Fresh installation, idempotent reinstall, clean removal, and no-op removal.
setup_scenario fresh
"$project_dir/scripts/install.sh"
test -x "$daemon_target"
test -x "$control_target"
test -f "$service_target"
test -f "$receipt_target"
test "$(stat -c '%a' "$receipt_target")" = "600"
test "$(stat -c '%h' "$receipt_target")" = "1"
test "$(grep -c '^' "$receipt_target")" = "8"
grep -Eq '^checkout=[0-9a-f]{64}$' "$receipt_target"
receipt_hash_before="$(sha256sum "$receipt_target" | awk '{print $1}')"

"$project_dir/scripts/install.sh"
test "$(sha256sum "$receipt_target" | awk '{print $1}')" = "$receipt_hash_before"
"$project_dir/scripts/uninstall.sh"
test ! -e "$daemon_target"
test ! -e "$control_target"
test ! -e "$service_target"
test ! -e "$receipt_target"
assert_preserved_user_state
grep -Fxq -- '--user disable --now sony-headphones.service' "$systemctl_log"
test "$(grep -Fc -- '--user daemon-reload' "$systemctl_log")" = "3"
systemctl_lines_before="$(wc -l < "$systemctl_log")"
"$project_dir/scripts/uninstall.sh"
test "$(wc -l < "$systemctl_log")" = "$systemctl_lines_before"

# An exact legacy install can be adopted; unrelated files cannot.
setup_scenario legacy-adoption
mkdir -p -- "${daemon_target%/*}" "${service_target%/*}"
install -m 0755 "$daemon_source" "$daemon_target"
install -m 0755 "$control_source" "$control_target"
install -m 0644 "$service_source" "$service_target"
"$project_dir/scripts/install.sh"
test -f "$receipt_target"
"$project_dir/scripts/uninstall.sh"
assert_preserved_user_state

setup_scenario unrelated-file
mkdir -p -- "${control_target%/*}"
printf 'unrelated\n' > "$control_target"
expect_failure "unrelated file already exists" "$project_dir/scripts/install.sh"
grep -Fxq 'unrelated' "$control_target"
test ! -e "$daemon_target"
test ! -e "$service_target"
test ! -e "$receipt_target"
assert_no_systemctl_actions

setup_scenario partial-conflict
mkdir -p -- "${daemon_target%/*}"
install -m 0755 "$daemon_source" "$daemon_target"
printf 'unrelated\n' > "$control_target"
daemon_hash_before="$(sha256sum "$daemon_target" | awk '{print $1}')"
expect_failure "unrelated file already exists" "$project_dir/scripts/install.sh"
test "$(sha256sum "$daemon_target" | awk '{print $1}')" = "$daemon_hash_before"
grep -Fxq 'unrelated' "$control_target"
test ! -e "$service_target"
test ! -e "$receipt_target"
assert_no_systemctl_actions

# Every managed destination and the receipt reject symbolic links.
for symlink_kind in daemon control service; do
  setup_scenario "symlink-$symlink_kind"
  victim="$scenario_root/victim"
  printf 'victim\n' > "$victim"
  case "$symlink_kind" in
    daemon) symlink_target="$daemon_target" ;;
    control) symlink_target="$control_target" ;;
    service) symlink_target="$service_target" ;;
  esac
  mkdir -p -- "${symlink_target%/*}"
  ln -s -- "$victim" "$symlink_target"
  expect_failure "is a symbolic link" "$project_dir/scripts/install.sh"
  test -L "$symlink_target"
  grep -Fxq 'victim' "$victim"
  test ! -e "$receipt_target"
  assert_no_systemctl_actions
done

setup_scenario symlink-receipt
victim="$scenario_root/victim"
printf 'victim\n' > "$victim"
ln -s -- "$victim" "$receipt_target"
expect_failure "ownership receipt is a symbolic link" "$project_dir/scripts/install.sh"
test -L "$receipt_target"
grep -Fxq 'victim' "$victim"
assert_no_systemctl_actions

setup_scenario symlink-directory
real_binary_dir="$scenario_root/real-bin"
binary_directory="${daemon_target%/*}"
mkdir -p "$real_binary_dir" "${binary_directory%/*}"
ln -sT -- "$real_binary_dir" "$binary_directory"
expect_failure "binary directory is a symbolic link" "$project_dir/scripts/install.sh"
assert_no_systemctl_actions

setup_scenario hard-linked-destination
victim="$scenario_root/victim"
printf 'victim\n' > "$victim"
mkdir -p -- "${daemon_target%/*}"
ln -- "$victim" "$daemon_target"
expect_failure "has multiple hard links" "$project_dir/scripts/install.sh"
grep -Fxq 'victim' "$victim"
grep -Fxq 'victim' "$daemon_target"
assert_no_systemctl_actions

# A modified owned file blocks both update and removal before any service action.
setup_scenario modified-owned
"$project_dir/scripts/install.sh"
printf 'modified\n' >> "$service_target"
systemctl_lines_before="$(wc -l < "$systemctl_log")"
receipt_hash_before="$(sha256sum "$receipt_target" | awk '{print $1}')"
daemon_hash_before="$(sha256sum "$daemon_target" | awk '{print $1}')"
expect_failure "changed since this checkout installed it" "$project_dir/scripts/install.sh"
expect_failure "changed since this checkout installed it" "$project_dir/scripts/uninstall.sh"
test "$(wc -l < "$systemctl_log")" = "$systemctl_lines_before"
test "$(sha256sum "$receipt_target" | awk '{print $1}')" = "$receipt_hash_before"
test "$(sha256sum "$daemon_target" | awk '{print $1}')" = "$daemon_hash_before"
grep -Fq 'modified' "$service_target"
assert_preserved_user_state

# Symlink, hard-link, and receipt-mode changes after install block removal.
for changed_kind in daemon control service; do
  setup_scenario "owned-symlink-$changed_kind"
  "$project_dir/scripts/install.sh"
  case "$changed_kind" in
    daemon) changed_target="$daemon_target" ;;
    control) changed_target="$control_target" ;;
    service) changed_target="$service_target" ;;
  esac
  victim="$scenario_root/victim"
  printf 'victim\n' > "$victim"
  rm -f -- "$changed_target"
  ln -s -- "$victim" "$changed_target"
  systemctl_lines_before="$(wc -l < "$systemctl_log")"
  expect_failure "is a symbolic link" "$project_dir/scripts/uninstall.sh"
  test "$(wc -l < "$systemctl_log")" = "$systemctl_lines_before"
  test -L "$changed_target"
  grep -Fxq 'victim' "$victim"
  test -e "$receipt_target"
done

setup_scenario owned-hard-link
"$project_dir/scripts/install.sh"
ln -- "$daemon_target" "$scenario_root/second-daemon-link"
systemctl_lines_before="$(wc -l < "$systemctl_log")"
expect_failure "has multiple hard links" "$project_dir/scripts/uninstall.sh"
test "$(wc -l < "$systemctl_log")" = "$systemctl_lines_before"
test -e "$daemon_target"
test -e "$scenario_root/second-daemon-link"
test -e "$receipt_target"

setup_scenario permissive-receipt
"$project_dir/scripts/install.sh"
chmod 0644 "$receipt_target"
systemctl_lines_before="$(wc -l < "$systemctl_log")"
expect_failure "must not be accessible by group or other users" "$project_dir/scripts/install.sh"
expect_failure "must not be accessible by group or other users" "$project_dir/scripts/uninstall.sh"
test "$(wc -l < "$systemctl_log")" = "$systemctl_lines_before"
test -e "$receipt_target"

# A receipt from another checkout cannot authorize update or removal.
setup_scenario foreign-checkout
"$project_dir/scripts/install.sh"
sed -i 's/^checkout=.*/checkout=0000000000000000000000000000000000000000000000000000000000000000/' \
  "$receipt_target"
systemctl_lines_before="$(wc -l < "$systemctl_log")"
expect_failure "owned by a different source checkout" "$project_dir/scripts/install.sh"
expect_failure "owned by a different source checkout" "$project_dir/scripts/uninstall.sh"
test "$(wc -l < "$systemctl_log")" = "$systemctl_lines_before"
test -e "$daemon_target"
test -e "$control_target"
test -e "$service_target"
test -e "$receipt_target"

# Missing owned artifacts are tolerated; remaining owned artifacts are removed.
setup_scenario missing-owned
"$project_dir/scripts/install.sh"
rm -f -- "$control_target"
"$project_dir/scripts/uninstall.sh"
test ! -e "$daemon_target"
test ! -e "$service_target"
test ! -e "$receipt_target"
assert_preserved_user_state

# A missing source unit must not stop a same-named package-managed service.
setup_scenario missing-service
"$project_dir/scripts/install.sh"
rm -f -- "$service_target"
"$project_dir/scripts/uninstall.sh"
if [ -f "$systemctl_log" ]; then
  if grep -Fq -- '--user disable --now sony-headphones.service' "$systemctl_log"; then
    printf 'A missing source unit unexpectedly disabled a same-named service.\n' >&2
    exit 1
  fi
fi
test ! -e "$daemon_target"
test ! -e "$control_target"
test ! -e "$receipt_target"
assert_preserved_user_state

# Without a receipt, uninstall never removes or stops an existing path.
setup_scenario unowned-uninstall
mkdir -p -- "${service_target%/*}"
printf 'unrelated\n' > "$service_target"
expect_failure "no ownership receipt exists" "$project_dir/scripts/uninstall.sh"
grep -Fxq 'unrelated' "$service_target"
assert_no_systemctl_actions

printf 'installers.test.sh: fail-closed checkout ownership lifecycle passed\n'
