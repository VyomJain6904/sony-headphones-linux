# Publishing Guide

This project is distributed as a public Git repository with an Omarchy schema-v1 plugin manifest at its root. Omarchy Quattro currently installs third-party plugins directly from Git; it does not use a separate Marketplace submission or package-upload workflow.

The authoritative references are Omarchy's [shell plugin documentation](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md), [engineering contract](https://github.com/basecamp/omarchy/blob/quattro/AGENTS.md), and the `omarchy plugin validate` command shipped by the target Omarchy release.

## Manifest requirements

Before every release, `manifest.json` must satisfy all current validator rules:

- `schemaVersion` is the JSON number `1`.
- `id`, `name`, `version`, `kinds`, and `entryPoints` exist; the ID remains `io.github.vyomjain6904.sony-headphones`.
- The ID contains only letters, numbers, `.`, `_`, and `-`, contains no `..`, and does not use the reserved `omarchy.*` namespace.
- `kinds` is a non-empty array. This repository declares only `bar-widget`.
- `entryPoints.barWidget` is a safe, existing relative path with no `..` component.
- `barWidget.defaultSection`, when present, is `left`, `center`, or `right`.
- No symlink exists anywhere in the plugin tree outside `.git`.
- The entry-point QML is an `Item`/Omarchy `BarWidget`, never a second `ShellRoot` or Quickshell process.

Run the validator from a clean checkout before building, and again from the release tree:

```sh
omarchy plugin validate "$PWD"
```

On the release host, `./scripts/release-check.sh` combines these checks with ShellCheck, mock IPC lifecycle coverage, and ASan/UBSan.

## Native companion requirements

`omarchy plugin add` only clones, validates, discovers, and optionally enables QML. It intentionally runs no plugin code, native build, install hook, or privileged command. Publishing this repository therefore also requires clear manual steps for the C++ daemon:

- Document every build/runtime package for Omarchy and Debian.
- Build libmdr/fmt only from the immutable commits in `scripts/libmdr-version.sh`.
- Keep the reviewed patch under `patches/` and fail the build if it does not apply cleanly.
- Install only to the user's `~/.local/bin`, user systemd directory, and user plugin directory.
- Never require root, setuid, a broad D-Bus policy, Python, Electron, or another Quickshell process.
- Preserve the 15-second on-demand RFCOMM release behavior so Sony's phone app can regain control.

The install, update, and removal commands in `README.md` are part of the release contract. Test both layouts: a normal development checkout copied into the plugin directory and a repository cloned directly there by `omarchy plugin add`.

## Required release evidence

Run and record:

```sh
./scripts/check.sh
./scripts/build.sh --without-libmdr
ctest --test-dir build/native --output-on-failure
./scripts/build.sh
./scripts/qml-lint.sh
omarchy plugin validate "$PWD"
```

On a live Omarchy session, use only the existing shell process and verify:

- bar icon, tooltip, left-click panel, right-click shortcut, Escape, keyboard navigation, summon/hide, overflow scrollbar, and multiple screen edges;
- live dark/light theme changes, font changes, spacing scale, popup padding, controls, and borders;
- plugin enable/disable, shell restart, daemon restart, Git add/update/remove, and idempotent uninstall/reinstall;
- mock state and every mock command before touching hardware;
- hardware reads before writes, one reversible setting at a time, state restoration, reconnect, and RFCOMM idle release.

Every hardware report must add model, firmware, transport, protocol generation, read functions, write functions, and regressions to `docs/COMPATIBILITY.md`. Do not turn the single WH-1000XM5 result into an all-Sony claim.

## Version and source release

1. Finish the scoped release tasks and update `SPEC.md` before any public behavior change.
2. Update `CHANGELOG.md`, `TASKS.md`, `docs/COMPATIBILITY.md`, and `docs/VERIFICATION.md`.
3. Set the SemVer value in `manifest.json`; the Git tag must match it (for example, manifest `0.2.0`, tag `v0.2.0`).
4. Review the complete diff as unsandboxed shell code and native Bluetooth code.
5. Complete dependency/license/security review. Keep both MIT notices and document obligations before attaching a native binary.
6. Create a signed tag and public source release. Source-only is the initial distribution method; binary packages/checksums remain separate release work.
7. Test the public URL with `omarchy plugin add <url>` from a clean user account before announcing it.

Omarchy updates Git-managed plugins by showing a diff and fast-forwarding the checkout. Avoid force-pushing published release history. If the native source changes, release notes must tell users to rebuild, rerun `scripts/install.sh`, and restart the user service after `omarchy plugin update`.

The repository CI has two tiers: policy/model/no-libmdr checks on every push and pull request, plus a full pinned Bluetooth-backend build on tags or manual dispatch. CI supplements but does not replace current-Omarchy QML validation, visual checks, or recorded hardware evidence.

## Security and compatibility wording

Plugin QML runs unsandboxed inside Omarchy's long-lived shell, so users must be told to review the repository before enabling it. The native service has access to the system BlueZ bus and the connected headset but remains unprivileged, makes no network requests, and excludes Bluetooth addresses from public state.

Approved wording: “Designed for Sony Sound Connect-compatible headphones using supported MDR protocols; hardware-tested on the devices listed in the compatibility matrix.”

Do not claim universal compatibility, Sony affiliation, cloud parity, or support for firmware updates, 360 Reality Audio, account/location functions, factory reset, or other explicitly excluded features.
