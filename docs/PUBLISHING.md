# Publishing Guide

Sony Headphones has two complementary distribution channels:

- The Omarchy Marketplace lists the public Git repository and installs the QML plugin into the current user's plugin directory.
- The stable `sony-headphones-omarchy` AUR package builds and installs the native daemon, CLI, and systemd user service under pacman ownership.

Neither channel is a security sandbox. The maintainer remains responsible for the code, assets, dependency pins, documentation, license compliance, safe installation, and safe removal.

## Omarchy Marketplace

### Repository checklist

Before submitting the listing, confirm that the repository is public and its root contains:

- a current, valid `manifest.json`;
- the entry-point QML declared by the manifest;
- a README with dependencies, installation, updating, removal, limitations, and screenshots;
- the MIT license and third-party notices;
- installation and removal code that does not require root or launch a second Quickshell process.

The optional dark and light previews under `docs/screenshots/` are already optimized for the repository. The Marketplace may optimize its own preview copy.

### Manifest contract

This repository intentionally declares the `bar-widget` kind supported by Omarchy Quattro:

```json
{
  "schemaVersion": 1,
  "id": "io.github.vyomjain6904.sony-headphones",
  "name": "Sony Headphones",
  "version": "0.2.1",
  "author": "Vyom Jain",
  "description": "Capability-driven controls and battery status for Sony Sound Connect headphones.",
  "kinds": ["bar-widget"],
  "entryPoints": {
    "barWidget": "BarWidget.qml"
  }
}
```

Keep the permanent ID, version, kind, and entry point synchronized with the implementation. Validate the release checkout with:

```sh
omarchy plugin validate "$PWD"
./scripts/qml-lint.sh
```

The QML entry point must remain an `Item`/Omarchy `BarWidget`, not a `ShellRoot`. The plugin must use the existing Omarchy shell process.

### Submission fields

Use these values in the Marketplace issue form:

- Repository: `https://github.com/VyomJain6904/sony-headphones-omarchy`
- Category: `Audio`
- Suggested tags: `sony`, `headphones`, `bluetooth`, `audio`, `noise-cancelling`
- Preview: `docs/screenshots/panel-dark.png` or both repository screenshots if the form accepts multiple files

Paste this into **Maintainer notes**:

> This hardware-alpha plugin has a QML bar widget plus a native C++ companion. Omarchy installs and validates the QML repository but intentionally does not run the native build or installer. Users must build/install the daemon and CLI from the pinned sources, or install the separately prepared AUR package when that listing becomes available, then enable `sony-headphones.service` as an unprivileged user service. No root service, setuid binary, broad D-Bus policy, Python, Electron, telemetry, network runtime, or second Quickshell process is used. The daemon opens RFCOMM on demand and releases it after the panel's idle deadline so Sony's phone app can regain control. Controls are exposed only from reported protocol capabilities. Hardware evidence currently covers WH-1000XM5 firmware 2.5.1; other models are not claimed as tested. Removal instructions cover the native service, binaries/package, QML checkout, and optional private state.

Automated Marketplace validation checks the submitted commit before a maintainer approves the listing. Submit only after the signed tag, final checks, and public release are visible. The submission itself remains manual.

## AUR package

Publishing to the AUR is free and uses a separate AUR account plus an SSH public key. GitHub authentication does not authenticate with `aur.archlinux.org`. The AUR receives package metadata, not built binaries.

The reviewed package files live under `packaging/aur/`. The package owns:

```text
/usr/bin/sony-headphonesd
/usr/bin/sony-headphonesctl
/usr/lib/systemd/user/sony-headphones.service
/usr/share/licenses/sony-headphones-omarchy/
/usr/share/doc/sony-headphones-omarchy/
```

It must never write to a user's home, enable a user service as root, edit Omarchy's configuration, or install the QML checkout. After package installation, each user explicitly runs:

```sh
systemctl --user enable --now sony-headphones.service
```

### Package source policy

The stable package builds from the signed version tag and declares three immutable archives in `source=()`:

- Sony Headphones for Omarchy `v0.2.1`;
- SonyHeadphonesClient/libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24`;
- fmt commit `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f`.

All archives require SHA-256 hashes. The libmdr and fmt patches are applied during `prepare()`. CMake receives `FETCHCONTENT_FULLY_DISCONNECTED=ON` and the already verified fmt source directory, so `build()` cannot fetch undeclared dependencies.

After creating the upstream tag, calculate the application archive hash, update `PKGBUILD`, regenerate `.SRCINFO`, and run:

```sh
./scripts/check-aur.sh
cd packaging/aur
makepkg --verifysource
makepkg --cleanbuild --syncdeps
namcap PKGBUILD sony-headphones-omarchy-*.pkg.tar.zst
```

Also run `extra-x86_64-build` from `devtools` when a clean Arch chroot is available. Inspect the resulting file list and dependency report before copying `PKGBUILD`, `.SRCINFO`, and `sony-headphones-omarchy.install` into the separate AUR Git repository.

Do not submit the AUR package during this preparation release. Submission follows a final maintainer review and is documented in `packaging/aur/README.md`.

## Release gate

Run and record:

```sh
./scripts/check.sh
./scripts/build.sh --without-libmdr
ctest --test-dir build/native --output-on-failure
./scripts/build.sh
./scripts/qml-lint.sh
omarchy plugin validate "$PWD"
```

On a live Omarchy session, use only the existing shell process and verify plugin enable/disable, bar/panel behavior, keyboard and mouse interaction, dark/light live theming, overflow scrolling, daemon restart, Git update/removal, and idempotent reinstall. Test protocol changes with `sony-headphonesd --mock` before real hardware.

Every hardware report must add its model, firmware, transport, protocol generation, reads, writes, restoration, and regressions to `docs/COMPATIBILITY.md`. Do not turn the single WH-1000XM5 result into an all-Sony claim.

## Version and source release

1. Update `SPEC.md` before changing public behavior or distribution contracts.
2. Update `CHANGELOG.md`, `TASKS.md`, compatibility evidence, verification evidence, README, and release notes.
3. Keep the manifest, CMake, AUR, changelog, and release-note versions identical.
4. Review the complete diff as unsandboxed QML and native Bluetooth code.
5. Run the repository and live release gates.
6. Create and verify a signed `v0.2.1` tag, push it, and wait for tag CI.
7. Hash the immutable GitHub tag archive, replace the temporary application checksum in the AUR template, regenerate `.SRCINFO`, then validate and commit that packaging finalization on `main`.
8. Publish the source-only GitHub prerelease. Do not attach native binaries without a separate reproducibility and license review.
9. Manually submit the Omarchy Marketplace listing. Keep the AUR submission prepared but unpublished until explicitly approved.

Avoid force-pushing published release history. If native source changes, release notes must tell source-install users to rebuild and reinstall, while AUR users rebuild/update the package and restart their user service.

## Approved compatibility wording

“Designed for Sony Sound Connect-compatible headphones using supported MDR protocols; hardware-tested on the devices listed in the compatibility matrix.”

Do not claim universal compatibility, Sony affiliation, cloud parity, firmware updating, 360 Reality Audio, account/location functions, factory reset, or other excluded features.
