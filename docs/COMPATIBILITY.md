# Compatibility

## Claim policy

The architecture targets Sony | Sound Connect-compatible headphones that expose a supported MDR service and capabilities. That is not the same as a claim that every Sony model is tested or that every Sound Connect feature is implemented.

Controls are exposed from discovered capabilities, not a model allowlist. The name heuristics used for discovery are only a fallback when BlueZ omits service UUIDs; users can select an address explicitly through configuration.

## Hardware evidence

| Model | Firmware | Transport | Protocol | Read tests | Write tests | Status |
|---|---|---|---|---|---|---|
| WH-1000XM5 | 2.5.1 | Classic RFCOMM | MDR v2 | Identity, firmware, LDAC codec, main battery, capabilities, noise/ambient/focus, Speak-to-Chat, current EQ/DSEE, playback/volume, connection priority | ANC/ambient, ambient level, focus on voice, Speak-to-Chat, DSEE, play/pause, normalized volume, quality/stability; every changed setting restored | Hardware-alpha pass on 2026-08-19 |
| WH-1000XM4 | 3.0.1 | Classic RFCOMM | MDR v1 | Identity, firmware, LDAC codec, main battery, capabilities, noise/ambient/focus, Speak-to-Chat, current EQ/DSEE, playback/volume, connection priority | Ambient level, focus on voice (in Ambient mode), DSEE confirmed and restored; ANC↔Ambient↔Off mode switching observed working but not cleanly isolated from a physical button press; Speak-to-Chat engaged on-device but its state wasn't reflected back — see notes | Hardware-alpha pass on 2026-08-28, with the caveats below |

Do not add a green/supported row without recording the firmware and actual read/write results.

## Protocol evidence from upstream research

The pinned libmdr API can discover identity; main, left, right, and case battery; playback; noise cancelling; ambient/adaptive ambient; Speak-to-Chat; listening modes; equalizer/DSEE; paired devices; pairing; general settings; assignable controls; auto-off; wearing/auto-pause; gestures; voice guidance; connection quality; shutdown; and safe listening.

Independent implementations contain model configurations spanning LinkBuds, ULT, WF-1000X, WF-C, WF-SP, WH-1000X, WH-CH, WH-XB, and WI families. That supports the protocol-family design, but their hardware results are not inherited by this project.

Sony's official compatibility list changes over time. Recheck it for release claims rather than copying a fixed count into marketing text.

## WH-1000XM5 test notes

Environment: Omarchy Quattro 4.0.0, WH-1000XM5 firmware 2.5.1, BlueZ 5.87, LDAC active, pinned libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24` plus the reviewed connection-priority validation patch.

The device reported these capabilities: main battery, playback metadata/control/volume, noise cancelling, ambient sound, Speak-to-Chat, equalizer, DSEE, paired-device management, pairing, general settings, noise-control button, auto-off, wearing detection, auto-pause, voice guidance, shutdown, connection mode, and safe listening. The UI still exposes only implemented, locally safe controls.

Reversible write checks passed for ANC/ambient mode, ambient level `20 → 12 → 20`, focus on voice, Speak-to-Chat, DSEE, volume, play/pause, and connection priority `quality → stable → quality`. The state was re-read between writes and restored to the pre-test value. Volume normalization was separately verified on 2026-08-19: MDR raw level `6` read as `20%`, `20 → 50 → 20` writes succeeded, and each normalized value was re-read from the device before restoring the original level.

The current libmdr C ABI reports equalizer capability and the active preset but not the device's writable preset list. Schema v1 therefore publishes an empty `equalizer.available_presets`, the panel hides preset buttons, and direct preset commands are rejected. This is a deliberate capability gate, not a claim that the XM5 lacks EQ.

The v0.2.2 publication work and v0.2.3 source-installer safety repair do not add device evidence or broaden compatibility. They use the same WH-1000XM5 firmware 2.5.1 verification recorded above.

Panel close released RFCOMM after the 15-second idle deadline, and panel reopen synchronized again. Daemon restart and Omarchy shell restart also recovered. Sleep/resume, BlueZ restart, multipoint actions, shutdown, pairing, and long-duration soak behavior were not tested.

## WH-1000XM4 test notes

Environment: CachyOS (kernel 7.2.0-1-cachyos, not Omarchy), WH-1000XM4 firmware 3.0.1, BlueZ 5.87, LDAC active, pinned libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24` plus the three reviewed MDR v1 patches (`libmdr-v1-device-info-validation`, `libmdr-v1-playback-name-field-order`, `libmdr-v1-playback-name-optional-second-entry`) alongside the existing v2 connection-priority patch.

`libmdr-v1-device-info-validation` is directly hardware-confirmed: without it, the generated v1 validation rejected `GetDeviceInfo` responses from this device outright. With the patch applied, `panel-open` reliably completes a fresh RFCOMM sync (`connected:true`, `phase:ready`) and correctly reports model, firmware, and protocol generation, with an empty `last_error`.

`libmdr-v1-playback-name-field-order` and `libmdr-v1-playback-name-optional-second-entry` are reviewed and correct against the wire format (confirmed by inspecting the actual generated code after patching), but **not hardware-exercised**: the native daemon does not currently issue the `PLAYBACK_CONTROLLER` TRACK_NAME/ALBUM_NAME/ARTIST_NAME query at all, so there is no live signal yet that proves or disproves them against this device. Track/album/artist name is not a daemon feature today.

Reversible write checks cleanly passed for ambient level (`20 → 12 → 20`), focus on voice (only takes effect while in Ambient Sound mode, per Sony's documented behavior — confirmed working there), and DSEE. Each was re-read and restored to its pre-test value. ANC↔Ambient↔Off mode switching was also exercised and the daemon correctly tracked every transition, but see the first open item below before counting it as a clean isolated pass.

Two open items surfaced during this pass, not yet root-caused:

- The physical NC/Ambient button on the earcup was pressed mid-session (confirmed by the user), and its state change was correctly reflected back through the daemon — useful incidental evidence the v1 read/notify path works, but it also interrupted a couple of software-driven ANC-mode-switch attempts with transient "not synchronized" reconnects. A fully clean, uninterrupted software-only ANC on/off/restore cycle was not completed this session.
- Speak-to-Chat: on-device behavior was inconsistent across repeated attempts with the same `speak-to-chat on` command — music pause-on-speech didn't happen the first time, then did on a later attempt (Focus on Voice also appeared to engage automatically on speech during this window, without an explicit command). The daemon's `speak_to_chat.enabled` state field never flipped to `true` after the command in any attempt observed (command returned success, `last_error` empty) — so the state readback looks unreliable regardless of the on-device outcome. Needs investigation before marking Speak-to-Chat write-verified.

Ambient sensitivity, adaptive ambient, EQ preset/bands, paired-device management, pairing, general settings, auto-off, wearing detection, auto-pause, voice guidance, connection priority, volume, playback control, shutdown, multipoint, sleep/resume, and long-duration soak behavior were not tested this pass.

## Excluded even when a device supports it

- 360 Reality Audio
- Firmware updates
- Account/cloud/activity/location functions
- Factory reset
