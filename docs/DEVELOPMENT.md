# Development

## Host preparation

Run `./scripts/check-deps.sh`. It only inspects the host and never installs packages.

On Omarchy, install `bluez-libs`; on Debian, install `libbluetooth-dev`. The no-libmdr build remains useful for deterministic state, command, and mock testing.

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

The latter clones the pinned libmdr commit into `.deps/`, verifies and applies the tracked patch under `patches/`, configures it as its own top-level project, and links the resulting static libraries into this project's binaries. It is separate because the upstream project intentionally uses top-level CMake paths.

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
./scripts/qml-lint.sh
```

The wrapper selects Qt 6 and reproduces Quickshell's special `qs.Ui`/`qs.Commons` import namespace in a temporary lint-only directory. Warnings caused by incomplete singleton property metadata are expected; unresolved imports or a nonzero exit are not. Never launch a standalone Quickshell instance for the plugin.

## Git-managed Omarchy workflow

`omarchy plugin add <git-url>` clones the repository directly to `~/.config/omarchy/plugins/<id>`. Omarchy validates and discovers QML but intentionally runs no native installer hook. Build and install the daemon explicitly from that checkout. `scripts/install-plugin.sh` detects this layout and does not copy files over the source checkout.

Run `scripts/uninstall.sh` before `omarchy plugin remove`. The script removes the user service and native binaries but preserves a git-managed checkout so Omarchy can remove it cleanly.

## AUR package workflow

The stable package under `packaging/aur/` is deliberately separate from the source installer. Pacman owns the native executables and systemd user unit under `/usr`; Omarchy owns the QML checkout under the current user's configuration directory.

The package's `source=()` contains the application release, pinned libmdr commit, and pinned fmt commit. `prepare()` applies both reviewed patches and removes upstream's forced linker stripping so makepkg owns the normal Arch strip/debug policy. `build()` configures CMake with `FETCHCONTENT_FULLY_DISCONNECTED=ON`. Do not replace this with `scripts/build.sh`, because that developer script may fetch a missing dependency before compilation.

After the upstream tag and archive checksum exist:

```sh
./scripts/check-aur.sh
cd packaging/aur
makepkg --verifysource
makepkg --clean --cleanbuild --syncdeps
```

Generate `.SRCINFO` from the final PKGBUILD and commit both whenever package metadata changes. Use a clean chroot and `namcap` before AUR submission; see `packaging/aur/README.md`.
