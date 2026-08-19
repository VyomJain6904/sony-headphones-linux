# AUR packaging

This directory is the reviewed source for the stable `sony-headphones-omarchy` AUR package. The AUR package owns only the native companion: `sony-headphonesd`, `sony-headphonesctl`, the systemd user unit, documentation, and license notices. Omarchy continues to own the QML plugin checkout under the user's configuration directory.

The package is published in the AUR at https://aur.archlinux.org/packages/sony-headphones-omarchy.

## Validate locally

Run these commands after the signed upstream tag exists and the first source checksum in `PKGBUILD` is final:

```sh
cd packaging/aur
makepkg --verifysource
makepkg --clean --cleanbuild --syncdeps
makepkg --printsrcinfo > .SRCINFO.generated
diff -u .SRCINFO .SRCINFO.generated
rm .SRCINFO.generated
namcap PKGBUILD sony-headphones-omarchy-*.pkg.tar.zst
```

`bluez` is an intentional runtime dependency even though `namcap` cannot see it through ELF linkage: the daemon discovers and controls the headset through the BlueZ D-Bus service. When the local makepkg configuration emits an automatic `-debug` package, `namcap` may also report cross-package build-ID links whose targets live in the main package; inspect both archives together.

Keep `--clean` enabled when building inside the upstream plugin checkout. makepkg's temporary `src/` archive links are valid package-build artifacts, but Omarchy intentionally rejects every symlink it finds in a plugin directory during later validation.

For the strongest release check, build the same files in a clean Arch chroot with `extra-x86_64-build` from `devtools`.

## Updating the AUR package

After a new version is released and the local PKGBUILD/SRCINFO are updated:

```sh
git clone ssh://aur@aur.archlinux.org/sony-headphones-omarchy.git aur-sony-headphones-omarchy
cp packaging/aur/PKGBUILD packaging/aur/.SRCINFO packaging/aur/sony-headphones-omarchy.install aur-sony-headphones-omarchy/
cd aur-sony-headphones-omarchy
git add PKGBUILD .SRCINFO sony-headphones-omarchy.install
git commit -m "Update sony-headphones-omarchy to <version>"
git push
```

Only AUR package metadata belongs in the AUR Git repository. Never commit source archives or built `.pkg.tar.zst` files there.
