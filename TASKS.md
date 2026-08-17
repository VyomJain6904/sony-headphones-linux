# Working Tasks

## Repository foundation

- [x] Add README, specification, roadmap, changelog, contribution, security, and architecture documentation.
- [x] Add `AGENTS.md` and scoped native/QML rules.
- [x] Define the permanent namespaced plugin ID.
- [x] Document dependencies, privilege boundaries, and source-build policy.
- [x] Make the maintained C++/QML project the repository root.
- [ ] Publish this repository publicly before Marketplace submission.

## Omarchy plugin

- [x] Add schema-v1 bar-widget manifest.
- [x] Add bar entry point and nested panel lifecycle forwarding.
- [x] Add watched state service with command queue and optimistic controls.
- [x] Add capability-driven battery, noise, conversation, EQ, playback, and connection UI.
- [x] Add pure JavaScript parser/label/command tests.
- [ ] Run `omarchy plugin validate` on Omarchy.
- [ ] Run `qmllint` with Omarchy shell imports.
- [ ] Verify click, Escape, keyboard, shell summon/hide, disable/re-enable, restart, and removal.

## Native service

- [x] Add C++20 daemon and CLI targets.
- [x] Add private XDG state/socket paths and atomic state publishing.
- [x] Add strict line-oriented IPC parsing.
- [x] Add deterministic mock backend.
- [x] Add a compile-time no-libmdr backend for development checks.
- [x] Add pinned libmdr source/build integration.
- [x] Add BlueZ D-Bus discovery and MDR v2/v1 connection state machine.
- [x] Add capability/state mapping and initial setters.
- [x] Verify a full real-backend compile/link with the exact Debian BlueZ development package in a temporary sysroot.
- [ ] Install Debian `libbluetooth-dev` for normal local real-backend builds.
- [ ] Test against WH-1000XM5 hardware.
- [ ] Add BLE/LE Audio transport after a real device proves it necessary.

## Reliability and performance

- [x] Avoid QML subprocess polling and unchanged state writes.
- [x] Release the control connection after a configurable idle deadline.
- [ ] Add automated stale-socket and concurrent-client tests.
- [ ] Add sleep/resume and BlueZ restart recovery.
- [ ] Benchmark idle wakeups, active latency, reconnect time, and RSS.
- [ ] Run ASan/UBSan and long reconnect soak tests.

## Feature completion

- [x] Initial battery, ANC/ambient, focus-on-voice, Speak-to-Chat, EQ preset, DSEE, playback, volume, and connection-priority commands.
- [ ] Custom EQ bands and Clear Bass editing.
- [ ] Adaptive ambient sensitivity.
- [ ] Multipoint device management.
- [ ] Auto-off, wearing detection, auto-pause, gestures, buttons, and voice guidance.
- [ ] Safe-listening display.
- [ ] Optional PipeWire codec/profile adapter.

## Release

- [ ] Populate the hardware compatibility matrix.
- [ ] Complete release dependency/license/security review, including libbluetooth-linked binary obligations.
- [ ] Add Arch package/release artifact.
- [ ] Create `preview.png`.
- [ ] Publish 1.0 and Marketplace metadata.
