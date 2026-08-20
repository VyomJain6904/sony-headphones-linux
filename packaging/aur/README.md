# AUR packaging

This directory is the reviewed source for the `sony-headphones-linux` AUR package. The package owns only the desktop-independent native companion: `sony-headphonesd`, `sony-headphonesctl`, the systemd user unit, documentation, and licenses. Omarchy owns its optional QML checkout separately.

The package is published at https://aur.archlinux.org/packages/sony-headphones-linux.

## Validate locally

Run after the immutable application source commit and every checksum are final:

```sh
./scripts/check-aur.sh
cd packaging/aur
makepkg --verifysource
makepkg --clean --cleanbuild --syncdeps
makepkg --printsrcinfo > .SRCINFO.generated
diff -u .SRCINFO .SRCINFO.generated
namcap PKGBUILD sony-headphones-linux-*.pkg.tar.zst
```

`bluez` is an intentional runtime dependency even though it is not an ELF library dependency: the daemon discovers and controls the headset through the BlueZ D-Bus service. Inspect any automatically generated debug package together with the main archive when reviewing build-ID links.

Use `extra-x86_64-build` from `devtools` when a clean Arch chroot is available. Never commit source archives, built packages, `src/`, or `pkg/` to the AUR Git repository.

## Publish or update

For the first generic package publication:

```sh
git clone ssh://aur@aur.archlinux.org/sony-headphones-linux.git aur-sony-headphones-linux
cp packaging/aur/PKGBUILD packaging/aur/.SRCINFO \
  packaging/aur/sony-headphones-linux.install packaging/aur/LICENSE \
  aur-sony-headphones-linux/
cd aur-sony-headphones-linux
git add PKGBUILD .SRCINFO sony-headphones-linux.install LICENSE
git commit -m "Initial import: sony-headphones-linux 0.2.2"
git push
```

The merge request from `sony-headphones-omarchy` into `sony-headphones-linux` has been submitted. Until an AUR Package Maintainer accepts it, keep `provides`, `conflicts`, and `replaces` metadata and publish updates only to `sony-headphones-linux`. Do not push renamed package metadata to the old package base.
