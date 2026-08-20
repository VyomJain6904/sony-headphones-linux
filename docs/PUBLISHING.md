# Publishing Guide

Sony Headphones for Linux has two independent distribution channels:

- The Omarchy Marketplace installs the QML widget into the current user's plugin directory.
- The `sony-headphones-linux` AUR package builds and owns the native daemon, CLI, systemd user unit, documentation, and licenses under `/usr`.

Neither channel is a security sandbox. Keep every capability, dependency, installation action, and removal action explicit and reviewable.

## Omarchy Marketplace

The repository root must contain the public plugin source, `manifest.json`, `README.md`, `LICENSE`, and a safe installation/removal path. `preview.png` is the Marketplace card/detail preview; the dark and light originals remain under `docs/screenshots/`.

The permanent manifest identity is:

```json
{
  "schemaVersion": 1,
  "id": "io.github.vyomjain6904.sony-headphones",
  "name": "Sony Headphones",
  "version": "0.2.2",
  "author": "Vyom Jain",
  "description": "Capability-driven controls and battery status for Sony Sound Connect headphones.",
  "kinds": ["bar-widget"],
  "entryPoints": {
    "barWidget": "BarWidget.qml"
  }
}
```

Do not rename the plugin ID when the repository or native package is renamed. Validate the exact release tree with:

```sh
omarchy plugin validate "$PWD"
./scripts/qml-lint.sh
```

Use these submission values:

- Repository: `https://github.com/VyomJain6904/sony-headphones-linux`
- Category: `Widgets`
- Tags: `Quickshell`, `Bluetooth`
- Preview: root `preview.png`

Maintainer notes should state that the widget requires the separately installed unprivileged native companion, Marketplace installation runs no build hook, source dependencies are exact commits, CMake consumes the verified fmt source while fully disconnected, runtime performs no network requests, and hardware evidence is limited to WH-1000XM5 firmware 2.5.1 over MDR v2.

Document both source lifecycle commands exactly:

```sh
./scripts/install.sh
./scripts/uninstall.sh
```

Omarchy plugin add/remove remains separate. Package management, remote source builds, and user-service management are genuine capabilities and should remain visible to the automated security baseline.

## AUR package

Publishing to the AUR is free. The AUR stores package metadata, not built packages. The package owns:

```text
/usr/bin/sony-headphonesd
/usr/bin/sony-headphonesctl
/usr/lib/systemd/user/sony-headphones.service
/usr/share/licenses/sony-headphones-linux/
/usr/share/doc/sony-headphones-linux/
```

It must never write to a user's home, enable a user service for an account, edit Omarchy configuration, or install the QML checkout. Users explicitly enable the service after installation:

```sh
systemctl --user enable --now sony-headphones.service
```

The AUR Git repository must include `PKGBUILD`, `.SRCINFO`, `sony-headphones-linux.install`, and the 0BSD `LICENSE` covering the package metadata. The upstream application's `license=('MIT')` remains unchanged.

### Immutable sources

The final package declares and checksums:

- an exact signed upstream source commit for version 0.2.2;
- libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24`;
- fmt commit `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f`.

The application archive uses the source commit immediately before the packaging-only finalization commit. This avoids embedding a checksum that recursively changes its own source archive. The signed `v0.2.2` tag may differ from that source commit only in `packaging/aur/` metadata.

All archives require SHA-256 hashes. `prepare()` applies the two reviewed patches and removes upstream's forced linker stripping. `build()` passes `FETCHCONTENT_FULLY_DISCONNECTED=ON` and `FETCHCONTENT_SOURCE_DIR_FMT` so CMake cannot download undeclared dependencies.

### Rename migration

Publish `sony-headphones-linux` as a new AUR package base. It must provide, conflict with, and replace `sony-headphones-omarchy`. Do not push renamed `.SRCINFO` metadata into the old AUR Git repository. Once the new page is live, submit an AUR merge request from `sony-headphones-omarchy` into `sony-headphones-linux`.

## Release procedure

1. Update `SPEC.md` before public behavior or ownership changes.
2. Update the manifest, CMake version, changelog, tasks, README, documentation, and release notes.
3. Commit the release source with a signed commit and expose that exact commit temporarily so its GitHub archive can be checksummed.
4. Set the AUR `_upstream_commit` and application SHA-256 to that source commit, regenerate `.SRCINFO`, and verify that the finalization diff is limited to packaging and verification evidence.
5. Run the complete repository, native, QML, and AUR gates.
6. Create and verify the signed `v0.2.2` tag on the finalized tree, push `main` and the tag, then wait for both CI jobs.
7. Publish the source-only GitHub hardware-alpha prerelease. Do not attach native binaries without a separate reproducibility and license review.
8. Publish the new AUR package, submit the old-package merge request, and update Marketplace issue 712 with the exact fixed commit and check results.

## Release gate

```sh
./scripts/check.sh
./scripts/build.sh --without-libmdr
ctest --test-dir build/native --output-on-failure
./tests/installers.test.sh
./scripts/build.sh
./scripts/qml-lint.sh
omarchy plugin validate "$PWD"
```

Then validate the package:

```sh
cd packaging/aur
makepkg --verifysource
makepkg --clean --cleanbuild --syncdeps
makepkg --printsrcinfo > .SRCINFO.generated
diff -u .SRCINFO .SRCINFO.generated
namcap PKGBUILD sony-headphones-linux-*.pkg.tar.zst
```

Use `extra-x86_64-build` when a clean Arch chroot is available. Inspect the package file list, service `ExecStart`, dependencies, licenses, and absence of home-directory paths before publication.

## Compatibility wording

Use: “Designed for Sony Sound Connect-compatible headphones using supported MDR protocols; hardware-tested on the devices listed in the compatibility matrix.”

Do not claim universal compatibility, Sony affiliation, cloud parity, firmware updating, 360 Reality Audio, account/location functions, factory reset, or support not backed by recorded device evidence.
