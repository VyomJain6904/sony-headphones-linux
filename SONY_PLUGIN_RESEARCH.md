# Sony Sound Connect-style Omarchy plugin: research and architecture

Research date: 2026-08-17

## Recommendation

Build this as two deliberately separate programs:

- A small Omarchy `bar-widget` written in QML/JavaScript. It renders cached state, opens the panel, and sends explicit user actions. It must never open Bluetooth sockets itself.
- A headless native C++20 service and CLI built around the MIT-licensed `libmdr` and Linux `libmdr-bt` backend from `mos9527/SonyHeadphonesClient`, pinned to a reviewed commit. It owns Sony RFCOMM, capability discovery, serialization, retries, and state publication.

Do not rewrite the Sony protocol in Rust or Go for the first stable release. A Rust or Go wrapper would still need FFI into the mature C++ library, while a native rewrite would duplicate the least documented and most failure-prone part of the system. C++ is the lowest-risk choice here, not merely the fastest language.

The plugin should be model-agnostic and capability-driven. It should recognize the two Sony MDR service UUID families, ask the connected device for its advertised support tables, and show only supported controls. A model database is useful for tested-status notes and quirks, but must not be the feature authority.

## Honest compatibility conclusion

Sony's official May 2026 compatibility page lists 46 headphone/gaming-headphone models or model families supported by Sound Connect. No current open-source Linux implementation has hardware-verified control coverage for all 46.

- `mos9527/SonyHeadphonesClient` has device-support reports for eight modern models and implements a capability-oriented V1/V2 protocol library.
- BudsLink has explicit Sony configuration profiles for 22 model families, covering both older and newer generations.
- The union of those published model lists is roughly half of Sony's current Sound Connect list. Other devices may work through shared V1/V2 protocol capabilities, but that is not the same as verified support.

Therefore the correct product claim is: **supports Sony Sound Connect devices that expose the MDR V1 or V2 control service, with controls gated by device-advertised capabilities; tested models are listed separately.** Do not claim “all Sound Connect headphones” until each model is represented by a captured capability report and a hardware test result.

For the user's WH-1000XM5, the evidence is strong. The active C++ project reports battery, volume, noise/ambient controls, equalizer, touch sensor enable/disable, NC/AMB button settings, track controls, and power-off working. Multipoint and Speak-to-Chat remain marked untested in that project's WH-1000XM5 support document, despite protocol support existing in the library. They need a real-device test before being called stable.

## Sound Connect feature inventory

### Include in the native/device-control surface

These features are device-resident, represented by current protocol implementations, or can be delegated cleanly to Linux audio services:

- Device name, model, firmware version, connection state, and current codec
- Main battery or left/right/case battery, including charging state when exposed
- Noise canceling, Ambient Sound, Off, ambient level, Focus on Voice/voice passthrough
- Auto Ambient support and sensitivity when the device advertises it
- Speak-to-Chat on/off, detection sensitivity, and timeout
- Equalizer preset, custom bands, and Clear Bass when supported
- DSEE on/off and reported DSEE type
- Sound-quality-versus-stable-connection mode
- Multipoint device list, connect/disconnect, and playback-device selection
- Playback status, play/pause, previous/next, and volume
- Touch/button assignments and NC/AMB switching pattern
- Wearing detection, pause/resume when removed, and automatic power-off
- Notification/voice guidance on/off and volume when supported
- Pairing mode and safe power-off
- Head gesture when advertised and verified
- Safe-listening instantaneous status if the headset exposes it; do not pretend this is Sony's cloud history

### Exclude from the plugin

- 360 Reality Audio, explicitly excluded by the project requirement
- Firmware updates. Keep signed firmware delivery in Sony's official app; a failure here can brick a device.
- Voice-guidance language package downloads unless a later audited implementation can reproduce the complete signed-transfer flow
- Sony account, cloud backup, badges, Discover content, service integrations, and usage analytics
- Phone-location/activity Adaptive Sound Control. A later desktop “scenes” feature could be built, but it would be a different feature and should be named honestly.
- Auto Play and Sony speaker Auto Switch integrations
- Ear-photo personalization, optimal earbud-tip tests, and app-only onboarding/tutorial flows
- Factory initialization/reset in the normal UI. If ever added, hide it behind an explicit destructive confirmation and a separate command.

## Runtime architecture

1. BlueZ D-Bus discovers paired/connected devices and watches property changes.
2. The service checks for Sony MDR V1 (`96cc203e-5068-46ad-b32d-e316f5e069ba`) or V2 (`956c7b26-d49a-4ba8-b03f-b17d393cb6e2`).
3. `libmdr-bt` opens an authenticated, encrypted RFCOMM socket and discovers the service channel through SDP.
4. `libmdr` identifies the protocol family, reads the headset's support tables, syncs state, and emits typed events.
5. The service atomically writes a versioned JSON snapshot under `$XDG_STATE_HOME` and exposes a user-only Unix socket under `$XDG_RUNTIME_DIR`.
6. The QML widget watches the state file, so idle UI causes zero process spawns and no polling. The CLI is used only for commands.

Recommended state path: `$XDG_STATE_HOME/sony-headphones/status.json`.

Recommended control path: `$XDG_RUNTIME_DIR/sony-headphones.sock`, created with user-only permissions. Never fall back to a predictable `/tmp` socket.

The service can stay running without holding a Sony control connection. By default it should acquire RFCOMM while the panel is open or an action is active, then release it after a short idle timeout. Sony control connections can conflict with the phone app, so provide three policies: `on-demand` (default), `connected`, and `always`. The first is the safest default; the last should carry a clear warning.

## Performance and stability rules

- Event-driven BlueZ and Sony notifications; no fixed-interval polling.
- Atomic state writes (`write` temporary file, `fsync` as appropriate, then `rename`) and a monotonically increasing schema version.
- Optimistic UI for explicit changes, reconciled against the next headset event, with a bounded timeout.
- Serialize commands. Coalesce slider repeats so only the newest pending ambient/EQ value is sent.
- Strict input validation before packet serialization. Unknown capabilities remain hidden.
- Bounded reconnect with jitter; reset backoff immediately on a BlueZ connection event.
- Timeouts on SDP, RFCOMM connect, initialization, sync, and commit. Never let the shell wait on Bluetooth I/O.
- One daemon per user, one control socket, one Sony session per device, and never a second Quickshell process.
- Preserve the last valid state during a transient parse/read failure, but mark it stale and show the error.
- Include packet replay tests, parser fuzzing, golden JSON snapshots, disconnect/reconnect tests, and hardware smoke tests.
- Keep dangerous/raw protocol commands out of the public IPC surface.

## Why C++20 wins for version 1

The chosen upstream already provides:

- Typed V1 and V2 protocol definitions and generated serializers/validators
- Dynamic support-table-to-feature mapping
- A stable C ABI in `libmdr/include/mdr-c`
- A Linux backend using D-Bus, BlueZ SDP, and RFCOMM
- An event-polling API, request initialization/sync/commit, and typed getters/setters
- MIT licensing

A focused build can disable the ImGui client, LLVM code generation, and tests while using the committed generated sources. The resulting service does not need SDL, ImGui, GTK, Qt, Python, Node, or Electron.

Rust remains a good possible phase-two host language if memory safety is prioritized: bind the C ABI, keep all Bluetooth/protocol ownership in `libmdr`, and put only service orchestration/JSON/Unix-socket code in Rust. That is extra FFI and packaging complexity without a version-one feature benefit.

Go would add cgo for the same library or require a full protocol rewrite. Its garbage collector is not a performance problem at this scale, but it offers no advantage over the direct C++ path.

## Dependencies and build feasibility

Minimal runtime dependencies on Omarchy/Arch:

- `bluez` and the running system BlueZ service
- `bluez-libs` for `libbluetooth.so` at runtime
- `dbus` for `libdbus-1.so`
- `glibc` and the C++ runtime
- PipeWire/WirePlumber already supplied by Omarchy for audio routing and codecs

Build-only dependencies:

- C++20 compiler (`base-devel`/GCC)
- CMake 3.31 or a small downstream patch lowering the requirement after testing
- Ninja or Make
- `pkgconf`, `git`, `bluez-libs`, and `dbus`
- `fmt` 12.1.0, either vendored/pinned or fetched only during a reproducible release build

The core library was configured and built successfully during this research with GCC 14.2 and CMake 3.31.6 using:

`MDR_BUILD_CLIENT=OFF`, `MDR_ENABLE_CODEGEN=OFF`, and `BUILD_TESTING=OFF`.

The Linux transport build then failed only because this Debian-like research container lacks `bluetooth/sdp.h`. Arch's official `bluez-libs` package contains `bluetooth/sdp.h`, `sdp_lib.h`, `rfcomm.h`, and `libbluetooth.so`, so that failure identifies a normal package prerequisite rather than a code blocker.

Do not build or privately install a second BlueZ or D-Bus stack. Those are system services and should come from Arch packages. Build the plugin's daemon and its pinned library dependency from source, then install only the resulting user binary, CLI, and user systemd unit under `~/.local`.

## Lessons from the four supplied Omarchy plugins

### `thisisgm/omarchy-pods`

Use its process boundary: protocol daemon publishes a state file, QML watches it, and a CLI is invoked only for changes. Also copy its security decision to place the control socket under `$XDG_RUNTIME_DIR`, its schema-version behavior, optimistic state reconciliation, command coalescing, and explicit systemd user lifecycle. Do not copy its AirPods daemon or Qt-heavy build.

### `hrzlgnm/omarchy-headsetcontrol`

Use its capability-gated UI idea: every control is visible only when the backend reports the corresponding capability. Do not use HeadsetControl itself for consumer XM headsets; its Sony support is for INZONE gaming devices and its main architecture targets USB/dongle gaming headsets. Avoid its 30-second polling design for this plugin.

### `nightdevil00/bt.codecs`

Reuse its PipeWire/PulseAudio card-profile concepts and codec labels, but update discovery to parse structured JSON where possible. Codec/profile switching is a Linux host concern and should not be sent through Sony's private protocol.

### `hlasensky/omarchy-peripheral-battery`

Prefer its native, event-driven UPower/BlueZ path for baseline battery visibility and use protocol battery only for richer per-component data. A connected Sony model with no supported private-control path should still get a useful battery-only panel instead of disappearing.

## Proposed Omarchy plugin contract

- Kind: `bar-widget` only for the first release. The details panel is nested in the bar widget.
- Entry point: `BarWidget.qml`, loading `Panel.qml` internally.
- Module ID: choose a permanent reverse-DNS ID before publishing and use it identically in the manifest, bar widget, panel, and IPC target.
- QML files: `BarWidget.qml`, `Panel.qml`, `Service.qml`, `Model.js`, and focused reusable row components if needed.
- Native directory: `daemon/` with the service, CLI, user unit, vendored/pinned `libmdr`, tests, and its own license notices.
- Public IPC: `open`, `close`, `toggle`, `refresh`, and named safe setters. No raw bytes and no shell-string command execution.

## Release sequence

### Milestone 1: WH-1000XM5 stable core

Battery, connection, codec status, ANC/Ambient/Off, ambient level, Focus on Voice, EQ, DSEE, auto-pause, touch control, connection quality, and power-off. Validate every setting against a physical WH-1000XM5 and two firmware versions if possible.

### Milestone 2: modern V2 capability mode

Add WF-1000XM5, WH/WF-1000XM6, WH-CH720N, WF-C510, LinkBuds Open, and other V2 devices through support-table discovery. Add left/right/case battery and multipoint where verified.

### Milestone 3: legacy V1

Enable WH-1000XM2/XM3/XM4 and older WF/WI families only after protocol replay tests and physical reports. Treat the active upstream's V1 work as evolving until it is merged/released and its device matrix is stronger.

### Milestone 4: broad compatibility program

Ship a read-only `probe --report` command that redacts MAC addresses and exports model, firmware, service UUID, protocol version, capability IDs, and pass/fail checks. A model becomes “tested” only after a signed-off report and command smoke test.

## Primary references

- Sony Sound Connect compatible models, May 2026: https://www.sony.com/electronics/support/articles/00346846
- Sony Sound Connect product/features page: https://www.sony.com/electronics/support/software/00269130
- WH-1000XM5 app feature list: https://helpguide.sony.net/mdr/wh1000xm5/v1/en/contents/TP1000534533.html
- Sony's current app walkthrough: https://www.sony.com/electronics/support/articles/00399613
- `libmdr` implementation: https://github.com/mos9527/SonyHeadphonesClient
- Archived original Sony client: https://github.com/Plutoberth/SonyHeadphonesClient
- BudsLink broad model configurations: https://github.com/maniacx/BudsLink
- Omarchy pods architecture: https://github.com/thisisgm/omarchy-pods
- Omarchy HeadsetControl UI: https://github.com/hrzlgnm/omarchy-headsetcontrol
- Omarchy codec UI: https://github.com/nightdevil00/bt.codecs
- Omarchy peripheral battery: https://github.com/hlasensky/omarchy-peripheral-battery
- Official Omarchy Quattro shell contract: https://github.com/basecamp/omarchy/blob/quattro/shell/README.md
- WirePlumber Bluetooth codec configuration: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
- Arch `bluez-libs` file list: https://archlinux.org/packages/extra/x86_64/bluez-libs/files/
