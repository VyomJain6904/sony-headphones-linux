# Architecture

## Components

`BarWidget.qml` is the only manifest entry point. It owns `Service.qml`, displays compact state, loads `Panel.qml`, and forwards the lifecycle methods Quattro expects. The nested panel receives the bar anchor and the shared service instance.

`Service.qml` watches one JSON file and launches `sony-headphonesctl` only for user actions. Its one-slot command queue coalesces repeated UI actions instead of starting parallel processes. `Model.js` owns schema parsing, labels, clamping, and command argument construction and runs in a plain JavaScript test harness.

`sony-headphonesd` owns discovery, protocol state, and mutation. It has a single event loop around the private command socket and a backend. The mock backend exercises the complete UI contract. The libmdr backend uses BlueZ ObjectManager discovery, libmdr-bt transport, and libmdr's C ABI.

`sony-headphonesctl` validates commands and sends one request through the private socket. It does not invoke a shell or talk to Bluetooth directly.

## Data flow

1. Opening the panel sends `panel-open`.
2. The daemon discovers connected BlueZ devices advertising Sony's MDR v2 or v1 UUID.
3. libmdr-bt opens RFCOMM; libmdr initializes and fetches current state.
4. Semantic events update the in-memory state.
5. The daemon serializes schema v1 to a temporary file, flushes it, and atomically renames it over `status.json`.
6. Quickshell's `FileView` reloads the file and the panel re-renders only supported controls.
7. A control action is validated by QML, the CLI, and the daemon before a libmdr setter and commit.
8. Closing the panel starts an idle deadline; the daemon disconnects the control channel after the deadline.

## Transport selection

Classic service UUIDs:

- MDR v2: `956c7b26-d49a-4ba8-b03f-b17d393cb6e2`
- MDR v1: `96cc203e-5068-46ad-b32d-e316f5e069ba`

The backend prefers an advertised UUID. If BlueZ reports both, v2 is tried first and v1 second. A configured address may use the same ordered fallback. BLE is a planned adapter, not silently substituted in the first alpha.

## State ownership

The daemon is authoritative. QML may hold a just-clicked value briefly to avoid visual snap-back, but clears the optimistic value when the daemon agrees, rejects the command, or the settle timer expires. The daemon publishes only after semantic changes, so no timer rewrites the same JSON.

## Failure behavior

- No daemon: the state file disappears and QML shows setup guidance.
- No compatible connected device: phase becomes `idle` with an actionable message.
- Connection failure: phase becomes `error`; while the panel remains open the daemon retries with backoff.
- Malformed/too-new state: the panel rejects it safely.
- Command failure: the panel clears optimism, reloads state, and shows a bounded one-line error.
- Daemon crash: systemd restarts it; stale sockets are replaced only inside the resolved private runtime directory.

## Dependency boundary

libmdr is built from an immutable source revision. BlueZ/D-Bus stay system-managed. PipeWire codec switching will be a separate optional adapter so protocol controls do not depend on an audio server choice.
