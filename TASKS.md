# Working Tasks

## Repository foundation

- [x] Add README, specification, roadmap, changelog, contribution, security, and architecture documentation.
- [x] Add `AGENTS.md` and scoped native/QML rules.
- [x] Define the permanent namespaced plugin ID.
- [x] Document dependencies, privilege boundaries, and source-build policy.
- [x] Make the maintained C++/QML project the repository root.
- [x] Publish this repository publicly so Omarchy can install it from Git.

## Omarchy plugin

- [x] Add schema-v1 bar-widget manifest.
- [x] Add bar entry point and nested panel lifecycle forwarding.
- [x] Add watched state service with command queue and optimistic controls.
- [x] Add capability-driven battery, noise, conversation, EQ, volume, and connection UI.
- [x] Add pure JavaScript parser/label/command tests.
- [x] Run `omarchy plugin validate` on Omarchy.
- [x] Run Qt 6 `qmllint` with Omarchy shell imports.
- [x] Verify shell summon/hide and persistence across an Omarchy shell restart.
- [x] Verify native theme controls, icon rendering, standard scrolling, and live dark/light palette changes.
- [x] Verify Escape and arrow-key cursor navigation in the live Omarchy shell.
- [x] Add labeled, theme-aware icons to the sound-control mode buttons.
- [x] Compact the panel footprint without reducing control or text sizing.
- [ ] Verify mouse click and disable/re-enable on a clean user account.

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
- [x] Verify normal real-backend builds with installed BlueZ development headers on Omarchy.
- [x] Test the implemented control surface against WH-1000XM5 firmware 2.5.1.
- [x] Normalize the public percentage volume contract to Sony MDR's 31 hardware levels.
- [ ] Add BLE/LE Audio transport after a real device proves it necessary.

## Reliability and performance

- [x] Avoid QML subprocess polling and unchanged state writes.
- [x] Release the control connection after a configurable idle deadline.
- [x] Add automated stale-socket and concurrent-client tests.
- [ ] Add sleep/resume and BlueZ restart recovery.
- [ ] Benchmark idle wakeups, active latency, reconnect time, and RSS.
- [x] Run ASan/UBSan on the native core and tests.
- [ ] Run long reconnect soak tests.

## Feature completion

- [x] Initial battery, ANC/ambient, focus-on-voice, Speak-to-Chat, EQ preset, DSEE, playback, volume, and connection-priority commands.
- [ ] Custom EQ bands and Clear Bass editing.
- [ ] Adaptive ambient sensitivity.
- [ ] Multipoint device management.
- [ ] Auto-off, wearing detection, auto-pause, gestures, buttons, and voice guidance.
- [ ] Safe-listening display.
- [ ] Optional PipeWire codec/profile adapter.

## Release

- [x] Populate the hardware compatibility matrix with the WH-1000XM5 hardware-alpha evidence.
- [x] Add source-checkout-aware install and uninstall scripts.
- [x] Complete the source-release dependency/license/security review; keep binary licensing as separate artifact work.
- [x] Add and validate stable AUR packaging for the native companion with immutable, checksummed sources and an offline build phase.
- [ ] Submit `sony-headphones-omarchy` to the AUR after final maintainer review.
- [ ] Submit the v0.2.1 repository to the Omarchy Marketplace issue form.
- [x] Create dark/light repository screenshots from the live Omarchy shell.
- [x] Test Git add/update/remove from an isolated clean Omarchy profile.
- [x] Publish signed/tagged 0.2.0 hardware-alpha source release.
- [ ] Publish signed/tagged 1.0 source release after cross-device acceptance criteria pass.
