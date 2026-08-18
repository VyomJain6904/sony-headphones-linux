# Third-Party Dependencies

## Statically linked source dependencies

### SonyHeadphonesClient / libmdr

- Source: `https://github.com/mos9527/SonyHeadphonesClient`
- Reviewed commit: `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24`
- License: MIT
- Purpose: Sony MDR v1/v2 packet handling and Linux Bluetooth transport
- Local changes: `patches/libmdr-v2-connection-priority-validation.patch` removes generated v2 validation that incorrectly rejected the valid `SOUND_QUALITY_PRIOR` connection-priority value reported by WH-1000XM5 firmware 2.5.1. `scripts/build.sh` verifies the immutable upstream commit and applies this reviewed patch deterministically before compilation.
- Notice: `licenses/libmdr-LICENSE`

### fmt

- Source: `https://github.com/fmtlib/fmt`
- Reviewed commit: `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f` (tag `12.1.0`)
- License: MIT with an optional binary exception
- Purpose: formatting used internally by libmdr
- Local changes: the one-line patch shipped by the pinned libmdr source
- Notice: `licenses/fmt-LICENSE`

The build verifies both Git revisions and checks the tracked libmdr patch before compilation.

## System-owned dynamic dependencies

### BlueZ / libbluetooth

- Provider: Linux distribution (`libbluetooth-dev` on Debian, `bluez-libs` on Arch)
- Purpose: SDP and Bluetooth socket support used by libmdr-bt
- Debian package copyright declares BlueZ primarily GPL-2.0-or-later, with some components under other licenses.

### D-Bus / libdbus-1

- Provider: Linux distribution (`libdbus-1-dev` on Debian, `dbus` on Arch)
- Purpose: BlueZ discovery and communication
- The shared library is distributed under GPL-2.0-or-later or AFL-2.1 with additional permissively licensed portions.

### C/C++ runtime and systemd

Provided by the distribution. systemd is used only to supervise the unprivileged user service.

## Distribution note

The repository's original source is MIT licensed. A distributed native binary is a combined work with statically linked MIT dependencies and dynamically linked system libraries. Before publishing binary artifacts, complete the release license review in `TASKS.md`, include the dependency notices, and determine the obligations that apply to the chosen distribution method. Source-only distribution and local builds do not remove the need to preserve the bundled MIT notices.

No code was copied from the GPL-licensed BudsLink implementation or other reference projects. Those projects were used only as behavioral evidence during research.
