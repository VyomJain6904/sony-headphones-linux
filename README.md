# Sony Headphones for Omarchy

A fast, native Omarchy Quattro bar widget for Sony headphones that use the Sony | Sound Connect protocol. It is designed around the WH-1000XM5, but discovers protocol capabilities at runtime so the same code can serve compatible WH, WF, WI, LinkBuds, ULT, and INZONE families without a hard-coded UI per model.

The project is a hardware alpha. Its complete local control path has been tested on one WH-1000XM5 running firmware 2.5.1, including reversible writes and RFCOMM release/reconnect. That evidence does not imply that every Sound Connect model is tested. See [TASKS.md](TASKS.md) and the [compatibility matrix](docs/COMPATIBILITY.md).

| Omarchy dark theme | Omarchy light theme |
| --- | --- |
| ![Sony Headphones panel using an Omarchy dark theme](docs/screenshots/panel-dark.png) | ![Sony Headphones panel using an Omarchy light theme](docs/screenshots/panel-light.png) |

The compact panel follows Omarchy's live palette and control tokens, so its background, borders, text, selected states, and icons update with the active system theme.

## Current control surface

- Main, left, right, and case battery where reported
- Noise cancellation, ambient sound level, and focus on voice
- Speak-to-Chat
- DSEE and equalizer presets only when the daemon reports the writable preset list
- Headphone volume, normalized from Sony's 31 hardware levels to a `0–100` percentage
- Connection quality/stability preference

Controls are capability-gated. A device that does not report a feature does not receive a dead toggle.

Action buttons are centered in responsive rows, and the sound-control modes pair clear icons with their labels. The deliberately compact panel keeps native text and control sizing and scrolls when its lower sections exceed the available height. It follows Omarchy's keyboard model: Up/Down moves between control groups, Left/Right moves within a button row or adjusts a slider, Enter/Space activates the current control, Escape closes, and Tab/Shift+Tab switches neighboring bar panels. Transport playback buttons are intentionally not shown.

Adaptive ambient tuning, custom EQ bands/Clear Bass, multipoint management, auto-off, wearing/auto-pause, assignable controls, voice guidance, pairing, and shutdown remain planned and are tracked in [TASKS.md](TASKS.md).

## Deliberately excluded

- 360 Reality Audio
- Firmware flashing or updates
- Sony account, cloud backup, activity, location, and service integrations
- Factory reset

Those functions are either outside a local desktop controller's purpose, carry unacceptable recovery risk, or depend on proprietary online services.

## Architecture

```text
Omarchy's existing Quickshell process
  BarWidget.qml -> Panel.qml -> Service.qml
                              watches status.json
                              runs sony-headphonesctl for actions
                                         |
                                private Unix socket
                                         |
                                 sony-headphonesd
                              BlueZ D-Bus + libmdr
                                         |
                                  Sony headphones
```

The QML layer never polls a command. The daemon keeps one event loop, publishes JSON atomically after changes, and opens Sony's RFCOMM control channel only while the panel or an action needs it. This limits idle work and reduces conflict with Sony's phone app.

Read the full [architecture](docs/ARCHITECTURE.md) and [specification](SPEC.md).

## Dependencies

Runtime:

- Linux with BlueZ and D-Bus
- Omarchy Quattro/Quickshell for the plugin UI
- `sony-headphonesd` and `sony-headphonesctl` built by this repository

Build:

- CMake 3.31 or newer (required by the pinned libmdr source)
- A C++20 compiler
- Git, `pkg-config`, and `jq`
- D-Bus development headers
- BlueZ development headers and `libbluetooth`
- Node.js only for the pure JavaScript model test

No Python runtime or build step is used. The Sony protocol dependency is built from pinned C++ source. BlueZ and D-Bus remain distribution-owned because replacing security-sensitive system integration libraries with private copies would make updates and ABI management less reliable.

Debian/Ubuntu package names:

```sh
sudo apt install build-essential cmake git pkg-config jq libdbus-1-dev libbluetooth-dev nodejs
```

Omarchy/Arch package names:

```sh
sudo pacman -S --needed base-devel cmake git pkgconf jq dbus bluez bluez-libs nodejs
```

The service and plugin never invoke `sudo`.

## Build on Debian now

Check the host first:

```sh
./scripts/check-deps.sh
```

Build the native core and mock backend without Bluetooth dependencies:

```sh
./scripts/build.sh --without-libmdr
./build/native/sony-headphonesd --mock
```

In another terminal:

```sh
./build/native/sony-headphonesctl status
./build/native/sony-headphonesctl noise anc
./build/native/sony-headphonesctl ambient-level 12
```

Build the real BlueZ/libmdr backend after installing the development packages:

```sh
./scripts/build.sh
```

The build script fetches exactly the libmdr commit recorded in `scripts/libmdr-version.sh`, applies the reviewed compatibility patch in `patches/`, builds it locally, and links the service. It does not install anything globally.

## Install on Omarchy

After building on the Omarchy machine:

```sh
./scripts/install.sh
systemctl --user enable --now sony-headphones.service
omarchy plugin enable io.github.vyomjain6904.sony-headphones --section right
```

Validate the copied plugin:

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.vyomjain6904.sony-headphones"
omarchy plugin validate "$PLUGIN_DIR"
./scripts/qml-lint.sh
```

The plugin ID is `io.github.vyomjain6904.sony-headphones`. The installer copies only runtime plugin files when run from a development checkout and safely detects when the repository is already the git-managed plugin checkout.

### Install from the published Git repository

Omarchy Quattro installs third-party plugins by cloning a Git repository whose root contains `manifest.json`. The Omarchy command deliberately does not run install hooks, plugin code, `sudo`, or this project's native build, so the daemon must be built explicitly:

```sh
omarchy plugin add https://github.com/VyomJain6904/sony-headphones-omarchy.git
cd "$HOME/.config/omarchy/plugins/io.github.vyomjain6904.sony-headphones"
./scripts/build.sh
./scripts/install.sh
systemctl --user enable --now sony-headphones.service
omarchy plugin enable io.github.vyomjain6904.sony-headphones --section right
```

Review the repository before enabling it. QML plugins run unsandboxed inside the long-lived Omarchy shell, while this project's daemon runs separately as an unprivileged user service.

Update a Git-managed installation with:

```sh
omarchy plugin update io.github.vyomjain6904.sony-headphones
cd "$HOME/.config/omarchy/plugins/io.github.vyomjain6904.sony-headphones"
./scripts/build.sh
./scripts/install.sh
systemctl --user restart sony-headphones.service
```

Remove a local-copy installation with `./scripts/uninstall.sh`. For a Git-managed installation, run that script first to remove the native service and binaries, then run `omarchy plugin remove io.github.vyomjain6904.sony-headphones` from outside the checkout.

### Publication requirements

- Keep `manifest.json` at the repository root, validate it on current Omarchy, and keep the permanent namespaced ID.
- Publish a reviewable public Git repository. Current Omarchy Quattro distributes third-party plugins directly from Git; there is no separate Marketplace submission step in the current plugin workflow.
- Match the manifest version to a SemVer tag, update `CHANGELOG.md`, and attach checksums/notices to any future binary artifacts.
- Preserve immutable dependency pins, the reviewed libmdr patch, license notices, and complete runtime/build dependency documentation.
- Report compatibility only from recorded hardware evidence. A release must not broaden the WH-1000XM5 result into an all-model claim.
- Run every check in [docs/VERIFICATION.md](docs/VERIFICATION.md), test install/update/removal from a clean user account, and review all QML as unsandboxed shell code before publishing.

## Development loop

```sh
./scripts/check.sh
./scripts/qml-lint.sh
./scripts/install-plugin.sh
omarchy-shell shell rescanPlugins
```

Run the complete release gate on an Omarchy release host with:

```sh
./scripts/release-check.sh
```

Saved QML changes normally reload automatically. Never start another Quickshell process to test this plugin. Use Omarchy's current shell and inspect failures with:

```sh
qs log -p "$OMARCHY_PATH/shell" --tail 100
journalctl --user -u sony-headphones.service -f
```

## Safety and privacy

The plugin runs unprivileged with your user permissions. Its socket lives in `XDG_RUNTIME_DIR`, its state directory is private, and the public state file omits the Bluetooth MAC address. It makes no network requests and sends no telemetry. Review [SECURITY.md](SECURITY.md) before enabling real-device write commands.

## Project documents

- [SPEC.md](SPEC.md) — product and technical contract
- [ROADMAP.md](ROADMAP.md) — staged delivery plan
- [TASKS.md](TASKS.md) — working checklist
- [CHANGELOG.md](CHANGELOG.md) — user-visible changes
- [SONY_PLUGIN_RESEARCH.md](SONY_PLUGIN_RESEARCH.md) — research and source evaluation
- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) — evidence-based hardware matrix
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — build and test details
- [docs/VERIFICATION.md](docs/VERIFICATION.md) — checks actually run and remaining gaps
- [docs/PUBLISHING.md](docs/PUBLISHING.md) — current Omarchy publication and release requirements
- [THIRD_PARTY.md](THIRD_PARTY.md) — pinned sources, licenses, and system libraries

## License and affiliation

MIT licensed. This project is independent, unofficial, and not affiliated with or endorsed by Sony. Sony, Sony | Sound Connect, and product names are trademarks of their respective owners.
