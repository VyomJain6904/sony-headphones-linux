# Product and Technical Specification

Status: hardware alpha for `0.2.3`
Last updated: 2026-08-20

## 1. Product goal

Provide a native Linux service and CLI that exposes the useful local controls of Sony | Sound Connect headphones without a phone app, cloud service, or Python process. The daemon publishes a versioned JSON state file and accepts commands over a private Unix socket, allowing any desktop environment, status bar, or script to read and control the headphones. An included Omarchy Quattro bar widget provides a ready-made graphical frontend.

The first reference device is WH-1000XM5. The design target is the broader set of headphones that speak Sony's MDR v1, MDR v2, or supported BLE control protocol. Compatibility is determined by transport and feature discovery, not by marketing-name allowlists.

## 2. Users and environments

Primary runtime:

- Any Linux desktop with BlueZ and D-Bus (GNOME, KDE, Hyprland, Sway, i3, Omarchy, etc.)
- Wayland or X11
- systemd user services
- PipeWire/WirePlumber or PulseAudio for audio (the daemon controls the headset, not the audio server)

Included frontend:

- Omarchy Quattro bar widget (requires Omarchy's long-running Quickshell process)

Development runtime:

- Debian with i3/X11 and Quickshell
- Mock backend when Sony hardware is unavailable
- Native unit tests independent of Bluetooth hardware

## 3. Scope

### 3.1 Required for the first hardware beta

- Discover connected Sony devices through BlueZ D-Bus.
- Select MDR v2 or v1 using advertised service UUIDs, falling back safely where necessary.
- Initialize and synchronize via libmdr.
- Publish a versioned state document atomically.
- Expose a private, versioned, line-oriented command socket.
- Render battery and connection state in the bar and panel.
- Control ANC, ambient sound, ambient level, focus on voice, Speak-to-Chat, DSEE, volume, and connection priority when supported.
- Provide an idle control-channel release policy.
- Support mouse and keyboard panel interaction.
- Provide a deterministic mock backend.

### 3.2 Later capability-gated features

- Custom equalizer bands and Clear Bass.
- Multipoint and paired-device actions.
- Pairing mode.
- Auto power-off, wearing behavior, auto-pause, head gesture, assignable controls, noise-control button, and voice guidance.
- Safe-listening display.
- Optional PipeWire codec/profile display and switching as a separate adapter.
- BLE transport for models connected through LE Audio.

### 3.3 Out of scope

- 360 Reality Audio in every form.
- Firmware download, verification, flashing, or rollback.
- Sony account login, cloud synchronization, activity tracking, location, badges, and partner-service integrations.
- Factory reset.
- Replacing BlueZ, PipeWire, or WirePlumber.
- Running a second Quickshell process.

## 4. User experience

### 4.1 Bar widget

- Shows a compact Nerd Font headphone glyph; battery and mode details stay in the tooltip and panel.
- Indicates disconnected, connecting, ready, or error state without animation loops.
- Left click toggles the panel.
- It remains visible by default while disconnected so setup errors are discoverable; users may hide it through manifest settings.

### 4.2 Panel

- Header: device/model, firmware, active codec, and connection phase.
- Battery: only reported components.
- Sound: only supported noise modes, ambient slider, focus-on-voice, and adaptive controls.
- Conversation: Speak-to-Chat only when supported.
- Equalizer: presets/DSEE and later custom bands only when supported.
- The volume section appears only when its capability exists. Transport playback controls are not exposed in the panel.
- Volume remains a normalized `0..100` public value. MDR hardware's 31 raw levels (`0..30`) are converted at the native protocol boundary, and the panel settles committed values to the nearest representable percentage.
- Errors are short, actionable, and never expose raw packet data by default.
- The panel consumes Omarchy's live `Color` and `Style` tokens, native controls, panel padding, and standard `ScrollView`; it must update without a shell restart when the theme changes.
- Action buttons use content-sized native controls arranged in responsive rows whose contents are centered. Toggle rows, sliders, battery rows, and headings remain full-width.
- Keyboard navigation follows Omarchy's cursor model: Up/Down traverses visible control groups; Left/Right selects actions or adjusts sliders; Enter/Space activates; hover synchronizes the cursor; Escape closes; and Tab/Shift+Tab retains cross-panel switching. Moving the cursor keeps its control visible in the scroll viewport.

### 4.3 Lifecycle

- Opening the panel requests a control connection.
- Closing starts a configurable idle deadline, default 15 seconds.
- The daemon releases RFCOMM after the deadline unless work is pending.
- A write command extends the deadline.
- The state file remains readable with the last state and current phase while the daemon runs; it is removed on a clean daemon exit.

### 4.4 Distribution and ownership

- The canonical upstream project and native package are named `sony-headphones-linux`; the service is not tied to a desktop environment.
- Omarchy owns the Git-managed QML checkout under `~/.config/omarchy/plugins/io.github.vyomjain6904.sony-headphones`.
- The stable Arch package owns only native companion files under `/usr`: the daemon, CLI, systemd user unit, documentation, and license notices.
- Package installation and removal scripts never write to a specific user's home, edit Omarchy configuration, or enable a user service on behalf of an account.
- Source installation remains available under `~/.local/bin` and `~/.config/systemd/user`; `scripts/install.sh` and `scripts/uninstall.sh` manage only those native files and never alter a Git-managed plugin checkout.
- A versioned private receipt binds source-installed paths and content hashes to the canonical checkout. Install and removal preflight every destination and fail before file or service changes when a path is unrelated, modified, symbolic-linked, hard-linked, or owned by another checkout.
- Receipt-free legacy paths may be adopted only when every existing artifact is byte-identical to the current build input. There is no force-overwrite or force-remove mode.
- Source uninstall disables the user service only after the complete ownership preflight succeeds, removes only unchanged receipt-owned artifacts, removes the receipt itself, and preserves daemon state plus every separately managed desktop plugin.
- A package-managed native companion and Git-managed QML plugin can be installed, updated, and removed independently without leaving conflicting owned files.

## 5. Public runtime contracts

### 5.1 Plugin manifest

- Schema: Omarchy plugin schema version 1.
- ID: `io.github.vyomjain6904.sony-headphones`.
- Kind: `bar-widget` only.
- Entry point: `BarWidget.qml`.
- `Panel.qml` is nested and is not a separate manifest kind.

### 5.2 State schema v1

Path:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/sony-headphones/status.json
```

Top-level fields:

- `schema_version`: integer, currently 1.
- `daemon_version`: semantic version string.
- `revision`: monotonically increasing integer for this daemon process.
- `phase`: `idle`, `discovering`, `connecting`, `syncing`, `ready`, or `error`.
- `connected`: true only after a successful protocol sync.
- `device`: display-safe identity without Bluetooth address.
- `battery`: main/left/right/case objects.
- `capabilities`: booleans mapped from libmdr feature availability.
- `noise`, `speak_to_chat`, `equalizer`, `playback`, and `connection` state.
- `equalizer.available_presets`: optional array of setter-safe preset slugs. An absent or empty array means readers must display the current preset as state only and must not offer preset writes.
- `last_error`: user-facing error string.

Readers must reject newer schema versions rather than guessing. Missing fields in the same version use safe defaults.

### 5.3 Command schema v1

Socket:

```text
${XDG_RUNTIME_DIR}/sony-headphones/daemon.sock
```

The directory is mode `0700`; the Unix stream socket is mode `0600`. One UTF-8 command line is accepted per connection. Maximum request size is 4096 bytes. Responses are `ok`, `ok <message>`, or `error <message>`.

Initial commands:

```text
panel-open
panel-close
refresh
noise off|anc|ambient
ambient-level 1..20
focus-on-voice on|off
speak-to-chat on|off
dsee on|off
eq-preset <reported-slug>
connection quality|stable
volume 0..100
playback play|pause|next|previous
```

The CLI is the only supported shell-facing client. It validates argument shape before contacting the daemon, and the daemon rejects a preset that the current device state did not advertise in `equalizer.available_presets`.

The v1 state and command schemas retain playback fields and commands for backward compatibility, but the Omarchy panel does not expose transport playback controls.
The `volume` command and `playback.volume` state field are normalized percentages. The MDR backend maps them to and from the device's discrete `0..30` scale; callers must tolerate state settling to the nearest representable percentage.

## 6. Native design

- Language: C++20.
- Event model: one process, one event loop, no polling subprocesses.
- Protocol: pinned libmdr C ABI plus libmdr-bt Linux backend.
- Discovery: BlueZ ObjectManager over system D-Bus.
- Persistence: atomic write, `fsync`, and rename.
- IPC: Unix domain socket with user-only permissions.
- Service: unprivileged systemd user unit with restart-on-failure.
- Packaged service: `/usr/lib/systemd/user/sony-headphones.service` launches `/usr/bin/sony-headphonesd`; the source installer retains its `~/.local/bin` unit.
- Logging: stderr/journal, no packet payloads unless a future explicit debug mode is enabled.

## 7. Performance and reliability requirements

- No shell command polling from QML.
- No periodic state writes when nothing changed.
- Idle daemon poll deadline of at least 500 ms; active transport target of 20–50 ms.
- Normal click-to-command acknowledgement under 100 ms, excluding Bluetooth connection setup.
- Resident service target below 15 MiB RSS after optimization; measure before stable release.
- Recover from daemon restart, stale socket, Bluetooth power cycle, headphone reconnect, shell restart, and malformed state files.
- Never send a setter before successful initialization and synchronization.
- Never fabricate support for a feature that libmdr reports unavailable.

## 8. Security and privacy

- No root or privilege escalation.
- No network access or telemetry.
- No Bluetooth address in the QML state document.
- Strict command parsing; no command is passed through a shell.
- State and socket paths are derived from trusted XDG directories with private permissions.
- Upstream dependencies are pinned and reviewed before updating.
- Destructive actions require explicit UI confirmation; factory reset remains excluded.

## 9. Compatibility claims

The project may state “designed for Sound Connect-compatible Sony headphones using supported MDR protocols.” It must not state “works on all Sony headphones” until the compatibility matrix contains adequate hardware results. Each hardware report records model, firmware, transport, discovered features, successful reads/writes, and regressions.

## 10. Acceptance criteria for 1.0

- Omarchy manifest and all QML files validate on current Quattro.
- Native release build and tests pass on current Omarchy and supported Debian development environment.
- WH-1000XM5 core controls pass repeated reconnect/restart testing.
- At least one MDR v1 over-ear, one MDR v2 over-ear, and one true-wireless model are tested.
- No high-severity findings in dependency/license/security review.
- Install, upgrade, disable, re-enable, restart, and remove flows are documented and verified.
