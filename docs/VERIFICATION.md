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
