# AUR packaging

This directory is the reviewed source for the stable `sony-headphones-omarchy` AUR package. The AUR package owns only the native companion: `sony-headphonesd`, `sony-headphonesctl`, the systemd user unit, documentation, and license notices. Omarchy continues to own the QML plugin checkout under the user's configuration directory.

The package is prepared for submission but is not yet published in the AUR. Do not advertise `omarchy pkg aur add sony-headphones-omarchy` as available until its AUR page exists.

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

## Submit later

An AUR account and an SSH public key registered with that account are separate from GitHub authentication. After local review:

```sh
git clone ssh://aur@aur.archlinux.org/sony-headphones-omarchy.git aur-sony-headphones-omarchy
cp packaging/aur/PKGBUILD packaging/aur/.SRCINFO packaging/aur/sony-headphones-omarchy.install aur-sony-headphones-omarchy/
cd aur-sony-headphones-omarchy
git add PKGBUILD .SRCINFO sony-headphones-omarchy.install
git commit -m "Initial import: sony-headphones-omarchy 0.2.1"
git push
```

Only AUR package metadata belongs in the AUR Git repository. Never commit source archives or built `.pkg.tar.zst` files there.
