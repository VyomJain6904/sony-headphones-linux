# Sony Headphones Plugin Engineering Guide

This repository builds an Omarchy Quattro bar widget and a native Linux service for Sony headphones supported by Sony | Sound Connect.

## Non-negotiable constraints

- Keep the runtime free of Python, Electron, and a second Quickshell process.
- Treat Sony protocol support as capability-driven. Never expose a control only because a model name is recognized.
- Never claim that every compatible model is hardware-tested. Update `docs/COMPATIBILITY.md` with evidence for each tested device.
- Do not implement 360 Reality Audio, firmware flashing, Sony account/cloud functions, location tracking, or factory reset.
- Keep Bluetooth control access in the native daemon. QML reads a state file and invokes the CLI; it must not poll shell commands.
- Preserve the on-demand RFCOMM policy so the official phone app can regain its control connection.
- Use the unprivileged user session. Do not require root, setuid binaries, or broad D-Bus policy changes.
- Pin source dependencies by immutable commit and document every runtime and build dependency.
- Keep the public state and command schemas versioned and backward compatible within a major release.

## Required checks

Run the checks appropriate to a change:

```sh
./scripts/check.sh
./scripts/build.sh --without-libmdr
ctest --test-dir build/native --output-on-failure
```

On an Omarchy machine also run:

```sh
omarchy plugin validate "$PWD"
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml
```

For live protocol work, test with `sony-headphonesd --mock` first. Hardware testing must record the model, firmware, protocol generation, and tested functions in `docs/COMPATIBILITY.md`.

## Change discipline

- Update `TASKS.md` when completing or discovering scoped work.
- Add user-visible changes to `CHANGELOG.md`.
- Update `SPEC.md` before changing public behavior or scope.
- Keep QML presentation logic in `Model.js` testable without Quickshell.
- Keep native serialization, command validation, and protocol mapping independently testable.
