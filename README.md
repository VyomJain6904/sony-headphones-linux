# Sony Headphones for Omarchy

A fast, native Omarchy Quattro bar widget for Sony headphones that use the Sony | Sound Connect protocol. It is designed around the WH-1000XM5, but discovers protocol capabilities at runtime so the same code can serve compatible WH, WF, WI, LinkBuds, ULT, and INZONE families without a hard-coded UI per model.

The project is under active development. The mock backend and schema are usable now; real-device support must still be validated on hardware before the first stable release. See [TASKS.md](TASKS.md) and [compatibility](docs/COMPATIBILITY.md).

## Planned control surface

- Main, left, right, and case battery where reported
- Noise cancellation, ambient sound level, and focus on voice
- Adaptive ambient sound where available
- Speak-to-Chat
- Equalizer presets, bands, Clear Bass, and DSEE where available
- Playback and volume
- Connection quality/stability preference
- Multipoint status and paired-device management
- Auto power-off, wearing detection, auto-pause, button assignment, and voice guidance
- Pairing mode and safe shutdown with explicit confirmation

Controls are capability-gated. A device that does not report a feature does not receive a dead toggle.

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

The build script fetches exactly the libmdr commit recorded in `scripts/libmdr-version.sh`, builds it locally, and then links the service. It does not install anything globally.

## Install on Omarchy

After building on the Omarchy machine:

```sh
./scripts/install.sh
systemctl --user enable --now sony-headphones.service
omarchy-shell shell rescanPlugins
```

Validate the copied plugin:

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.vyomjain6904.sony-headphones"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" \
  "$PLUGIN_DIR/BarWidget.qml" \
  "$PLUGIN_DIR/Panel.qml" \
  "$PLUGIN_DIR/Service.qml"
```

The plugin ID is `io.github.vyomjain6904.sony-headphones`. The installer copies only runtime plugin files, so the published folder contains no symlinks.

## Development loop

```sh
./scripts/check.sh
./scripts/install-plugin.sh
omarchy-shell shell rescanPlugins
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
- [THIRD_PARTY.md](THIRD_PARTY.md) — pinned sources, licenses, and system libraries

## License and affiliation

MIT licensed. This project is independent, unofficial, and not affiliated with or endorsed by Sony. Sony, Sony | Sound Connect, and product names are trademarks of their respective owners.
