# Verification Record

## 2026-08-17 — Debian development host

Environment:

- Debian testing/trixie development host
- GCC 14.2.0
- CMake 3.31.6
- Node 26.7.0
- D-Bus development library 1.16.2
- BlueZ development package 5.82-1.1 extracted into a temporary test sysroot because the host package is not installed
- libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24`
- fmt commit `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f`

Passed:

- Manifest JSON parse and repository policy check
- Pure JavaScript state/model tests
- No-libmdr Debug and RelWithDebInfo builds
- Native state schema, command parser, and mock backend tests
- Mock daemon/CLI end-to-end actions and JSON revision updates
- State directory `0700`, state file `0600`, runtime directory `0700`, and socket `0600`
- Clean daemon shutdown removes the status file and socket
- CMake installs both native executables with mode `0755` under a temporary prefix
- Mock daemon idle RSS measured at 3,764 KiB; the RelWithDebInfo binaries contained 88,541 bytes (`daemon`) and 65,206 bytes (`ctl`) of text before stripping
- Real libmdr/libmdr-bt compilation
- Real backend compilation and final native link against the temporary BlueZ sysroot
- Real-backend native tests
- QML syntax parse with Debian's Qt 6.8 `qmllint` extracted into a temporary sysroot

Not run on this host:

- Omarchy manifest validation because Omarchy is not installed
- Full QML lint with Omarchy's `qs.Ui` and `qs.Commons` imports; the local syntax-only run necessarily reported those modules as unresolved
- Live WH-1000XM5 discovery, reads, writes, reconnect, or idle release
- Real-backend RSS, wakeups, connect latency, and action latency
- systemd unit launch after installation; static verification only reports the intentionally not-yet-installed `%h/.local/bin/sony-headphonesd`

Temporary Debian package contents were used only for compilation verification and were not installed or copied into the repository.

## 2026-08-18–19 — Omarchy Quattro and WH-1000XM5

Environment:

- Omarchy 4.0.0-1, Quickshell git `0.3.0.r20.g28771c7-1`, Qt/qmllint 6.11.1
- GCC 16.2.1, CMake 4.4.2, Node 26.7.0
- D-Bus 1.16.2, BlueZ 5.87
- WH-1000XM5 firmware 2.5.1 over Classic RFCOMM/MDR v2, LDAC active
- libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24` plus the tracked v2 connection-priority validation patch
- fmt commit `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f`

Passed:

- `./scripts/check.sh`
- ShellCheck across every Bash script and YAML parsing of the two-tier GitHub Actions workflow
- `./scripts/build.sh --without-libmdr` and all three native CTest cases
- Full pinned libmdr/libmdr-bt build and all native CTest cases
- Clang-Tidy analyzer, bug-prone, performance, and portability audit of the first-party no-libmdr native targets; only intentional `#pragma once` portability notices remain
- ASan/UBSan native build and all three native CTest cases
- `omarchy plugin validate "$PWD"`
- Qt 6 QML lint with Omarchy's special `qs` import namespace; the remaining warnings are incomplete dynamic singleton/host-object type metadata, not unresolved imports
- Mock daemon and CLI end to end, including every implemented write command, status revision updates, eight concurrent clients, private permissions, and stale-socket recovery
- Installed plugin/service discovery, enablement, shell IPC summon/hide, shell restart persistence, and user-service restart
- Dark-theme visual pass and a live light-palette pass through Omarchy's `applyTheme` IPC; foreground, popup surface, border, controls, slider, scrollbar, font, padding, and spacing all updated without a second Quickshell process
- Final centered-button, icon-only bar, standard scrollbar, dark/light screenshot, arrow-key cursor, and Escape dismissal pass; transport playback controls are absent by design
- Ambient and volume slider release-order audit and fix: the panel retains the last pointer/wheel value so an external state binding cannot resend the pre-drag value
- WH-1000XM5 identity, firmware, codec, battery, capability, noise, conversation, DSEE/EQ read, playback/volume, and connection-priority reads
- Reversible ANC/ambient, ambient-level, focus-on-voice, Speak-to-Chat, DSEE, playback, volume, and connection-priority writes with restoration
- Empty equalizer writable-preset list hides the panel buttons and rejects a direct preset write
- Panel-close 15-second RFCOMM release and panel-open resynchronization
- Clean uninstall removed the service unit, binaries, plugin files, registry entry, and right-bar layout entry; a fresh reinstall restored and re-enabled the user service and plugin
- User service is enabled and active; plugin remains enabled in the right bar section

Still required before a stable multi-device release:

- Clean-account Git add/update/remove test and full mouse interaction pass
- Bluetooth power-cycle, BlueZ restart, sleep/resume, and soak testing
- MDR v1 over-ear and true-wireless hardware evidence
- Release binary/license review and reproducible packaging if binaries are distributed
