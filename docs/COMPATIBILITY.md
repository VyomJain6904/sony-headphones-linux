# Compatibility

## Claim policy

The architecture targets Sony | Sound Connect-compatible headphones that expose a supported MDR service and capabilities. That is not the same as a claim that every Sony model is tested or that every Sound Connect feature is implemented.

Controls are exposed from discovered capabilities, not a model allowlist. The name heuristics used for discovery are only a fallback when BlueZ omits service UUIDs; users can select an address explicitly through configuration.

## Hardware evidence

| Model | Firmware | Transport | Protocol | Read tests | Write tests | Status |
|---|---|---|---|---|---|---|
| WH-1000XM5 | not recorded | Classic RFCOMM | MDR v2 expected | pending | pending | Reference device; not yet tested in this repository |

Do not add a green/supported row without recording the firmware and actual read/write results.

## Protocol evidence from upstream research

The pinned libmdr API can discover identity; main, left, right, and case battery; playback; noise cancelling; ambient/adaptive ambient; Speak-to-Chat; listening modes; equalizer/DSEE; paired devices; pairing; general settings; assignable controls; auto-off; wearing/auto-pause; gestures; voice guidance; connection quality; shutdown; and safe listening.

Independent implementations contain model configurations spanning LinkBuds, ULT, WF-1000X, WF-C, WF-SP, WH-1000X, WH-CH, WH-XB, and WI families. That supports the protocol-family design, but their hardware results are not inherited by this project.

Sony's official compatibility list changes over time. Recheck it for release claims rather than copying a fixed count into marketing text.

## Known WH-1000XM5 evidence

Upstream libmdr documentation reports working XM5 battery, volume, ANC/ambient, equalizer, touch/button-related controls, media control, and power operations. Multipoint and Speak-to-Chat require project-local verification before they are described as working here.

## Excluded even when a device supports it

- 360 Reality Audio
- Firmware updates
- Account/cloud/activity/location functions
- Factory reset
