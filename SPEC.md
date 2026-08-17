# Product and Technical Specification

Status: draft for `0.1.0`
Last updated: 2026-08-17

## 1. Product goal

Provide a responsive, stable, keyboard-accessible Omarchy bar widget that exposes the useful local controls of Sony | Sound Connect headphones on Linux without a phone app, cloud service, Python process, or duplicate shell.

The first reference device is WH-1000XM5. The design target is the broader set of headphones that speak Sony's MDR v1, MDR v2, or supported BLE control protocol. Compatibility is determined by transport and feature discovery, not by marketing-name allowlists.

## 2. Users and environments

Primary runtime:

- Omarchy Quattro
- Wayland
- Omarchy's long-running Quickshell process
- BlueZ and PipeWire/WirePlumber
- systemd user services

Development runtime:

- Debian with i3/X11 and Quickshell
- Mock backend when the Omarchy `qs.Ui` module or Sony hardware is unavailable
- Native unit tests independent of Bluetooth hardware

## 3. Scope

### 3.1 Required for the first hardware beta

- Discover connected Sony devices through BlueZ D-Bus.
- Select MDR v2 or v1 using advertised service UUIDs, falling back safely where necessary.
- Initialize and synchronize via libmdr.
- Publish a versioned state document atomically.
- Expose a private, versioned, line-oriented command socket.
- Render battery and connection state in the bar and panel.
- Control ANC, ambient sound, ambient level, focus on voice, Speak-to-Chat, DSEE, equalizer preset, playback, volume, and connection priority when supported.
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

- Shows a compact Sony/headphone label and best available battery value.
- Indicates disconnected, connecting, ready, or error state without animation loops.
- Left click toggles the panel.
- It remains visible by default while disconnected so setup errors are discoverable; users may hide it through manifest settings.

### 4.2 Panel

- Header: device/model, firmware, active codec, and connection phase.
- Battery: only reported components.
- Sound: only supported noise modes, ambient slider, focus-on-voice, and adaptive controls.
- Conversation: Speak-to-Chat only when supported.
- Equalizer: presets/DSEE and later custom bands only when supported.
- Playback and system sections appear only when their capabilities exist.
- Errors are short, actionable, and never expose raw packet data by default.

### 4.3 Lifecycle

- Opening the panel requests a control connection.
- Closing starts a configurable idle deadline, default 15 seconds.
- The daemon releases RFCOMM after the deadline unless work is pending.
- A write command extends the deadline.
- The state file remains readable with the last state and current phase while the daemon runs; it is removed on a clean daemon exit.

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
eq-preset <known-slug>
connection quality|stable
volume 0..100
playback play|pause|next|previous
```

The CLI is the only supported shell-facing client. It validates arguments before contacting the daemon.

## 6. Native design

- Language: C++20.
- Event model: one process, one event loop, no polling subprocesses.
- Protocol: pinned libmdr C ABI plus libmdr-bt Linux backend.
- Discovery: BlueZ ObjectManager over system D-Bus.
- Persistence: atomic write, `fsync`, and rename.
- IPC: Unix domain socket with user-only permissions.
- Service: unprivileged systemd user unit with restart-on-failure.
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
