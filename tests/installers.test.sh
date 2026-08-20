#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

test_home="$test_root/home"
test_config="$test_root/config"
test_state="$test_root/state"
stub_bin="$test_root/stub-bin"
systemctl_log="$test_root/systemctl.log"
mkdir -p -- "$test_home" "$test_config" "$test_state/sony-headphones" "$stub_bin"
printf 'preserve\n' > "$test_state/sony-headphones/status.json"

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
export PATH="$stub_bin:$PATH"

"$project_dir/scripts/install.sh"
test -x "$test_home/.local/bin/sony-headphonesd"
test -x "$test_home/.local/bin/sony-headphonesctl"
test -f "$test_config/systemd/user/sony-headphones.service"
test ! -e "$test_config/omarchy"

"$project_dir/scripts/uninstall.sh"
test ! -e "$test_home/.local/bin/sony-headphonesd"
test ! -e "$test_home/.local/bin/sony-headphonesctl"
test ! -e "$test_config/systemd/user/sony-headphones.service"
test -f "$test_state/sony-headphones/status.json"
test ! -e "$test_config/omarchy"

grep -Fxq -- '--user daemon-reload' "$systemctl_log"
grep -Fxq -- '--user disable --now sony-headphones.service' "$systemctl_log"
printf 'installers.test.sh: native ownership and state preservation passed\n'
