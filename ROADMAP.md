# Roadmap

The roadmap is evidence-gated: a milestone is complete only when its checks and hardware evidence exist.

## 0.1 — Repository and deterministic prototype

- [x] Research Sony | Sound Connect features and Linux protocol options.
- [x] Define product scope, exclusions, schemas, safety rules, and dependency policy.
- [x] Scaffold the Omarchy bar-widget contract.
- [x] Add a native C++ state/IPC core and deterministic mock backend.
- [x] Add pure JavaScript and native tests.
- [x] Validate QML and the mock workflow against a live Omarchy Quattro installation.

Exit: mock daemon, CLI, watched state, and panel work end to end without Python.

## 0.2 — WH-1000XM5 hardware alpha

- [x] Complete BlueZ service discovery and MDR v2 connection.
- [x] Verify initialization, event handling, commit flow, and idle release.
- [x] Verify battery, ANC, ambient level, focus on voice, Speak-to-Chat, DSEE, playback, volume, and connection priority.
- [x] Record XM5 firmware and feature matrix.
- [ ] Exercise Bluetooth off/on and sleep/resume; shell and daemon restart already pass.
- [x] Expose equalizer preset writes only after the protocol layer reports the device's writable preset list; hide and reject them when the stable ABI reports no list.

Exit: repeated XM5 control sessions with no stale UI or leaked control connection.

## 0.3 — Cross-generation beta

- Test one MDR v1 model and one WF/LinkBuds model.
- Add BLE transport only if required by tested LE Audio devices.
- Finish adaptive ambient, Speak-to-Chat, custom EQ bands, Clear Bass, auto-off, wearing, and voice controls.
- Add opt-in PipeWire/WirePlumber codec adapter.
- Measure CPU wakeups, RSS, action latency, and reconnect time.

Exit: compatibility claims are based on at least three protocol/form-factor groups.

## 0.4 — Multipoint and distribution

- Implement paired-device status/actions with defensive confirmations.
- Complete install, upgrade, and removal scripts for Omarchy.
- Add package/release artifacts and checksums.
- Add CI on current Debian and Arch containers.
- Prepare public Git release metadata and optional preview images.

Exit: reproducible release artifacts and documented upgrade path.

## 1.0 — Stable

- Pass every acceptance criterion in `SPEC.md`.
- Complete security and license review.
- Freeze schema v1 and document compatibility policy.
- Publish a signed/tagged Git release installable with `omarchy plugin add`.

## Non-goals across all milestones

360 Reality Audio, Sony cloud/account features, activity/location tracking, firmware flashing, factory reset, and a second Quickshell process remain out of scope.
