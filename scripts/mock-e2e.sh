#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
build_dir="$project_dir/build/native"
daemon="$build_dir/sony-headphonesd"
control="$build_dir/sony-headphonesctl"

if [ ! -x "$daemon" ] || [ ! -x "$control" ]; then
  printf 'Build the native binaries before running mock-e2e.sh.\n' >&2
  exit 1
fi

test_root="$(mktemp -d "${TMPDIR:-/tmp}/sony-headphones-e2e.XXXXXXXX")"
runtime_root="$test_root/runtime"
state_root="$test_root/state"
daemon_log="$test_root/daemon.log"
daemon_pid=""
mkdir -p -- "$runtime_root" "$state_root"
export XDG_RUNTIME_DIR="$runtime_root"
export XDG_STATE_HOME="$state_root"

stop_daemon() {
  if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
    kill -TERM "$daemon_pid"
    wait "$daemon_pid" || true
  fi
  daemon_pid=""
}

cleanup() {
  stop_daemon
  rm -f -- \
    "$runtime_root/sony-headphones/daemon.sock" \
    "$state_root/sony-headphones/status.json" \
    "$daemon_log"
  rmdir -- "$runtime_root/sony-headphones" "$state_root/sony-headphones" 2>/dev/null || true
  rmdir -- "$runtime_root" "$state_root" "$test_root" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

start_daemon() {
  : > "$daemon_log"
  "$daemon" --mock --idle-seconds 1 >"$daemon_log" 2>&1 &
  daemon_pid=$!
  for _ in {1..100}; do
    if [ -S "$runtime_root/sony-headphones/daemon.sock" ] && "$control" status >/dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "$daemon_pid" 2>/dev/null; then
      break
    fi
    sleep 0.05
  done
  printf 'Mock daemon did not become ready:\n' >&2
  sed -n '1,120p' "$daemon_log" >&2
  return 1
}

start_daemon

status_json="$($control status)"
jq -e '
  .schema_version == 1 and
  .phase == "ready" and
  .connected == true and
  .device.model == "WH-1000XM5" and
  .capabilities.noise_cancelling == true and
  .capabilities.equalizer == true
' <<<"$status_json" >/dev/null

"$control" panel-open
"$control" noise ambient
"$control" ambient-level 17
"$control" focus-on-voice on
"$control" speak-to-chat on
"$control" dsee off
"$control" eq-preset speech
"$control" playback pause
"$control" playback next
"$control" playback previous
"$control" playback play
"$control" volume 61
"$control" connection stable
"$control" refresh
"$control" panel-close

for _ in {1..100}; do
  status_json="$($control status)"
  if jq -e '
    .noise.mode == "ambient" and
    .noise.ambient_level == 17 and
    .noise.focus_on_voice == true and
    .speak_to_chat.enabled == true and
    .equalizer.dsee_enabled == false and
    .equalizer.preset == "speech" and
    .playback.status == "playing" and
    .playback.volume == 61 and
    .connection.priority == "stable"
  ' <<<"$status_json" >/dev/null; then
    break
  fi
  sleep 0.05
done
jq -e '
  .noise.mode == "ambient" and
  .noise.ambient_level == 17 and
  .noise.focus_on_voice == true and
  .speak_to_chat.enabled == true and
  .equalizer.dsee_enabled == false and
  .equalizer.preset == "speech" and
  .playback.status == "playing" and
  .playback.volume == 61 and
  .connection.priority == "stable"
' <<<"$status_json" >/dev/null

if "$control" ambient-level 0 >/dev/null 2>&1; then
  printf 'Invalid ambient level was accepted.\n' >&2
  exit 1
fi
if "$control" eq-preset rock >/dev/null 2>&1; then
  printf 'An unreported mock equalizer preset was accepted.\n' >&2
  exit 1
fi

client_pids=()
for _ in {1..8}; do
  "$control" refresh &
  client_pids+=("$!")
done
for client_pid in "${client_pids[@]}"; do
  wait "$client_pid"
done

[ "$(stat -c '%a' "$runtime_root/sony-headphones")" = "700" ]
[ "$(stat -c '%a' "$runtime_root/sony-headphones/daemon.sock")" = "600" ]
[ "$(stat -c '%a' "$state_root/sony-headphones")" = "700" ]
[ "$(stat -c '%a' "$state_root/sony-headphones/status.json")" = "600" ]

stop_daemon
mkdir -p -- "$runtime_root/sony-headphones"
: > "$runtime_root/sony-headphones/daemon.sock"
start_daemon
"$control" refresh
stop_daemon

printf 'mock-e2e.sh: command, state, concurrency, permissions, and stale-socket checks passed\n'
