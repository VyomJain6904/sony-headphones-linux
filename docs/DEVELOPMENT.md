# Development

## Host preparation

Run `./scripts/check-deps.sh`. It only inspects the host and never installs packages.

On the current Debian development machine, a no-libmdr build exercises state, IPC, mock behavior, and tests. The real backend additionally needs `libbluetooth-dev`. On Omarchy, install `bluez-libs`.

Do not work around missing system development headers by committing extracted distribution packages or private BlueZ builds. BlueZ and D-Bus are system integration/security boundaries and should receive normal distribution updates.

## Build modes

Fast deterministic build:

```sh
./scripts/build.sh --without-libmdr
```

Real backend:

```sh
./scripts/build.sh
```

The latter clones the pinned libmdr commit into `.deps/`, configures it as its own top-level project, and links the resulting static libraries into this project's binaries. It is separate because the upstream project intentionally uses top-level CMake paths.

Set `SONY_LIBMDR_SOURCE_DIR` to an already reviewed clone to avoid a network fetch:

```sh
SONY_LIBMDR_SOURCE_DIR=/path/to/SonyHeadphonesClient ./scripts/build.sh
```

## Tests

```sh
./scripts/check.sh
ctest --test-dir build/native --output-on-failure
```

`tests/model.test.js` uses Node's VM to evaluate the import-free QML JavaScript model. Native tests cover JSON escaping/defaults, command parsing, and mock mutations.

## Mock workflow

```sh
./build/native/sony-headphonesd --mock --idle-seconds 2
./build/native/sony-headphonesctl status
./build/native/sony-headphonesctl panel-open
./build/native/sony-headphonesctl noise ambient
```

Override paths for isolated tests:

```sh
export XDG_STATE_HOME="$(mktemp -d)"
export XDG_RUNTIME_DIR="$(mktemp -d)"
```

Remove those explicit temporary directories after the test; never point cleanup commands at `$HOME` or an unresolved variable.

## Real hardware workflow

1. Pair and connect the headset normally through BlueZ.
2. Stop Sony's phone app or disconnect its control session during initial tests.
3. Start the daemon in a terminal and open the panel.
4. Verify reads before writes.
5. Change one reversible setting at a time and confirm it on the device.
6. Close the panel and verify RFCOMM is released after the idle deadline.
7. Record results in `docs/COMPATIBILITY.md`.

Raw protocol logging is not enabled in normal builds. Redact addresses, unique IDs, and device names from logs attached to issues.

## QML validation

The Debian host can parse JavaScript but does not provide Omarchy's `qs.Ui` import. Final QML validation therefore runs on Omarchy:

```sh
omarchy plugin validate "$PWD"
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml
```

Never launch a standalone Quickshell instance for the plugin.
