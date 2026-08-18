# Compatibility

## Claim policy

The architecture targets Sony | Sound Connect-compatible headphones that expose a supported MDR service and capabilities. That is not the same as a claim that every Sony model is tested or that every Sound Connect feature is implemented.

Controls are exposed from discovered capabilities, not a model allowlist. The name heuristics used for discovery are only a fallback when BlueZ omits service UUIDs; users can select an address explicitly through configuration.

## Hardware evidence

| Model | Firmware | Transport | Protocol | Read tests | Write tests | Status |
|---|---|---|---|---|---|---|
| WH-1000XM5 | 2.5.1 | Classic RFCOMM | MDR v2 | Identity, firmware, LDAC codec, main battery, capabilities, noise/ambient/focus, Speak-to-Chat, current EQ/DSEE, playback/volume, connection priority | ANC/ambient, ambient level, focus on voice, Speak-to-Chat, DSEE, play/pause, volume, quality/stability; every changed setting restored | Hardware-alpha pass on 2026-08-18 |

Do not add a green/supported row without recording the firmware and actual read/write results.

## Protocol evidence from upstream research

The pinned libmdr API can discover identity; main, left, right, and case battery; playback; noise cancelling; ambient/adaptive ambient; Speak-to-Chat; listening modes; equalizer/DSEE; paired devices; pairing; general settings; assignable controls; auto-off; wearing/auto-pause; gestures; voice guidance; connection quality; shutdown; and safe listening.

Independent implementations contain model configurations spanning LinkBuds, ULT, WF-1000X, WF-C, WF-SP, WH-1000X, WH-CH, WH-XB, and WI families. That supports the protocol-family design, but their hardware results are not inherited by this project.

Sony's official compatibility list changes over time. Recheck it for release claims rather than copying a fixed count into marketing text.

## WH-1000XM5 test notes

Environment: Omarchy Quattro 4.0.0, WH-1000XM5 firmware 2.5.1, BlueZ 5.87, LDAC active, pinned libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24` plus the reviewed connection-priority validation patch.

The device reported these capabilities: main battery, playback metadata/control/volume, noise cancelling, ambient sound, Speak-to-Chat, equalizer, DSEE, paired-device management, pairing, general settings, noise-control button, auto-off, wearing detection, auto-pause, voice guidance, shutdown, connection mode, and safe listening. The UI still exposes only implemented, locally safe controls.

Reversible write checks passed for ANC/ambient mode, ambient level `20 → 12 → 20`, focus on voice, Speak-to-Chat, DSEE, volume, play/pause, and connection priority `quality → stable → quality`. The state was re-read between writes and restored to the pre-test value.

The current libmdr C ABI reports equalizer capability and the active preset but not the device's writable preset list. Schema v1 therefore publishes an empty `equalizer.available_presets`, the panel hides preset buttons, and direct preset commands are rejected. This is a deliberate capability gate, not a claim that the XM5 lacks EQ.

Panel close released RFCOMM after the 15-second idle deadline, and panel reopen synchronized again. Daemon restart and Omarchy shell restart also recovered. Sleep/resume, BlueZ restart, multipoint actions, shutdown, pairing, and long-duration soak behavior were not tested.

## Excluded even when a device supports it

- 360 Reality Audio
- Firmware updates
- Account/cloud/activity/location functions
- Factory reset
