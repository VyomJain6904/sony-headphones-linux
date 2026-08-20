# Verification Record

## 2026-08-17 — Debian development host

Environment:

- Debian testing/trixie development host
- GCC 14.2.0
- CMake 3.31.6
- Node 26.7.0
- D-Bus development library 1.16.2
- BlueZ development package 5.82-1.1 extracted into a temporary test sysroot because the host package is not installed
- libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24`
- fmt commit `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f`

Passed:

- Manifest JSON parse and repository policy check
- Pure JavaScript state/model tests
- No-libmdr Debug and RelWithDebInfo builds
- Native state schema, command parser, and mock backend tests
- Mock daemon/CLI end-to-end actions and JSON revision updates
- State directory `0700`, state file `0600`, runtime directory `0700`, and socket `0600`
- Clean daemon shutdown removes the status file and socket
- CMake installs both native executables with mode `0755` under a temporary prefix
- Mock daemon idle RSS measured at 3,764 KiB; the RelWithDebInfo binaries contained 88,541 bytes (`daemon`) and 65,206 bytes (`ctl`) of text before stripping
- Real libmdr/libmdr-bt compilation
- Real backend compilation and final native link against the temporary BlueZ sysroot
- Real-backend native tests
- QML syntax parse with Debian's Qt 6.8 `qmllint` extracted into a temporary sysroot

Not run on this host:

- Omarchy manifest validation because Omarchy is not installed
- Full QML lint with Omarchy's `qs.Ui` and `qs.Commons` imports; the local syntax-only run necessarily reported those modules as unresolved
- Live WH-1000XM5 discovery, reads, writes, reconnect, or idle release
- Real-backend RSS, wakeups, connect latency, and action latency
- systemd unit launch after installation; static verification only reports the intentionally not-yet-installed `%h/.local/bin/sony-headphonesd`

Temporary Debian package contents were used only for compilation verification and were not installed or copied into the repository.

## 2026-08-18–19 — Omarchy Quattro and WH-1000XM5

Environment:

- Omarchy 4.0.0-1, Quickshell git `0.3.0.r20.g28771c7-1`, Qt/qmllint 6.11.1
- GCC 16.2.1, CMake 4.4.2, Node 26.7.0
- D-Bus 1.16.2, BlueZ 5.87
- WH-1000XM5 firmware 2.5.1 over Classic RFCOMM/MDR v2, LDAC active
- libmdr commit `db0ae2574d8f8e1407e8ea28a7ee87db9dde1c24` plus the tracked v2 connection-priority validation patch
- fmt commit `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f`

Passed:

- `./scripts/check.sh`
- ShellCheck across every Bash script and YAML parsing of the two-tier GitHub Actions workflow
- `./scripts/build.sh --without-libmdr` and all three native CTest cases
- Full pinned libmdr/libmdr-bt build and all native CTest cases
- Clang-Tidy analyzer, bug-prone, performance, and portability audit of the first-party no-libmdr native targets; only intentional `#pragma once` portability notices remain
- ASan/UBSan native build and all three native CTest cases
- `omarchy plugin validate "$PWD"`
- Qt 6 QML lint with Omarchy's special `qs` import namespace; the remaining warnings are incomplete dynamic singleton/host-object type metadata, not unresolved imports
- Mock daemon and CLI end to end, including every implemented write command, status revision updates, eight concurrent clients, private permissions, and stale-socket recovery
- Installed plugin/service discovery, enablement, shell IPC summon/hide, shell restart persistence, and user-service restart
- Dark-theme visual pass and a live light-palette pass through Omarchy's `applyTheme` IPC; foreground, popup surface, border, controls, slider, scrollbar, font, padding, and spacing all updated without a second Quickshell process
- Final centered-button, icon-only bar, standard scrollbar, dark/light screenshot, arrow-key cursor, and Escape dismissal pass; transport playback controls are absent by design
- Ambient and volume slider release-order audit and fix: the panel retains the last pointer/wheel value so an external state binding cannot resend the pre-drag value
- WH-1000XM5 identity, firmware, codec, battery, capability, noise, conversation, DSEE/EQ read, playback/volume, and connection-priority reads
- Reversible ANC/ambient, ambient-level, focus-on-voice, Speak-to-Chat, DSEE, playback, volume, and connection-priority writes with restoration
- Empty equalizer writable-preset list hides the panel buttons and rejects a direct preset write
- Panel-close 15-second RFCOMM release and panel-open resynchronization
- Clean uninstall removed the service unit, binaries, plugin files, registry entry, and right-bar layout entry; a fresh reinstall restored and re-enabled the user service and plugin
- User service is enabled and active; plugin remains enabled in the right bar section
- Signed public candidate commit `9359a5d` is GitHub-verified and its push CI passed
- `omarchy plugin add` cloned the public HTTPS URL at `9359a5d` into an isolated temporary home and the cloned tree passed the Omarchy validator
- `omarchy plugin update` fast-forwarded that isolated checkout to signed follow-up `043e074`, validation passed again, and `omarchy plugin remove` deleted it cleanly
- The isolated lifecycle profile and shell shim were removed; the live user service remained enabled/active and the live plugin remained enabled in the right-bar layout
- GitHub marks the annotated `v0.2.0` tag signature valid; tag CI passed both the native-core and Arch full-backend jobs
- The non-draft `v0.2.0` hardware-alpha prerelease was published source-only with no uploaded binary assets

Still required before a stable multi-device release:

- Full mouse interaction pass on a second clean user account
- Bluetooth power-cycle, BlueZ restart, sleep/resume, and soak testing
- MDR v1 over-ear and true-wireless hardware evidence
- Release binary/license review and reproducible packaging if binaries are distributed

## 2026-08-19 — v0.2.1 release and AUR preparation

Environment:

- Omarchy Quattro 4.0.0-1 on Arch Linux x86_64
- GCC 16.2.1, CMake 4.4.2, makepkg 7.1.0, D-Bus 1.16.2, and BlueZ 5.87
- The same pinned libmdr and fmt revisions recorded above

Passed before tagging:

- Manifest/CMake/AUR version consistency for `0.2.1`
- Bash syntax and ShellCheck, including the new AUR consistency checker
- Generated `.SRCINFO` comparison with the tracked file
- `./scripts/check.sh`
- `./scripts/build.sh --without-libmdr` and all four native CTest cases
- `./scripts/build.sh` with the pinned hardware backend and all four native CTest cases
- Mock daemon/CLI end-to-end, concurrent-client, permission, and stale-socket checks
- ASan/UBSan build and all four native CTest cases
- `omarchy plugin validate "$PWD"`
- QML lint with only the previously documented dynamic Omarchy/Quickshell metadata warnings
- Offline package-equivalent build from the downloaded libmdr and fmt commit archives, including both reviewed patches, `FETCHCONTENT_FULLY_DISCONNECTED=ON`, application link, and all four native CTest cases
- `./scripts/release-check.sh`

Passed after tagging:

- Signed tag `v0.2.1` verification against the dedicated Ed25519 release key
- GitHub Actions tag run `32185173699`, including policy/native-core and pinned Arch Bluetooth-backend jobs
- Non-draft `v0.2.1` GitHub hardware-alpha prerelease published source-only with no uploaded binary assets
- Immutable GitHub tag archive SHA-256 `d2118b33ef893a5247356ce360a401fb230fad2cece1921761ef3f921a3057ae`
- `makepkg --verifysource` for the application, libmdr, and fmt archives
- Exact tagged `makepkg --cleanbuild --syncdeps` build, including both patches, disconnected CMake configuration, and all four native CTest cases
- Package inspection: 19 main-package files, no home/config paths, `/usr/bin` executables, `/usr/lib/systemd/user` service, documentation, and all three MIT notices
- Packaged unit validation with `ExecStart=/usr/bin/sony-headphonesd`
- `namcap` inspection; the main package reported only the intentional indirect `bluez` service dependency, while the automatically generated debug package reported its expected cross-package build-ID links and empty generated build directories
- Temporary local package installation, ownership verification with zero missing files, isolated packaged-daemon mock lifecycle, volume `20`, ambient level `12`, version `0.2.1`, static systemd unit verification, and clean package removal
- Safe source installer update of the live user-owned plugin and native companion to `0.2.1`; the installed plugin validated and the enabled user service restarted active
- AUR SSH authentication for account `VyomJain` after verifying the server Ed25519 fingerprint `SHA256:RFzBCUItH9LZS0cKB5UE6ceAYhBD5C8GeOBip8Z11+4` against Arch's published value

The temporary package and `namcap` dependencies were removed after verification. The existing source-installed user service, QML plugin, and private state were preserved. No Marketplace listing was submitted automatically.

Passed after AUR publication:

- AUR repository `sony-headphones-omarchy` initial import pushed with PKGBUILD, .SRCINFO, and sony-headphones-omarchy.install for version 0.2.1
- AUR package page live at https://aur.archlinux.org/packages/sony-headphones-omarchy showing version 0.2.1-1, maintainer VyomJain, correct dependencies, and upstream URL
- Repository documentation updated to reflect the live AUR listing

## 2026-08-20 — v0.2.2 publication repair and Linux rename

Environment:

- Omarchy Quattro on Arch Linux x86_64
- GCC 16.2.1, CMake 4.4.2, makepkg 7.1.0, D-Bus 1.16.2, and BlueZ 5.87
- The same pinned libmdr and fmt revisions recorded above

Passed before tagging:

- Canonical GitHub repository renamed to `VyomJain6904/sony-headphones-linux` while preserving the manifest ID and native runtime names
- Signed immutable application source commit `08e680333350610a92022dc551b8c2d4d0821054`
- Application source archive SHA-256 `79cf440efc796e83eb7d4035ef0c9879add2fce294473825fe5d1ae2f2dbe46b`
- Root README reduced to 165 lines with tracked, executable install and removal commands
- Root `preview.png` is a valid 455×656 PNG sourced from the live dark-theme screenshot
- Bash syntax and ShellCheck for repository scripts and installer tests
- `./scripts/release-check.sh`, including policy/model checks, no-libmdr build, all four native CTests, isolated installer ownership/state preservation, mock E2E, ASan/UBSan, exact libmdr/fmt build, QML lint, and Omarchy plugin validation
- fmt revision verification before its reviewed patch or any CMake configuration; libmdr configuration used `FETCHCONTENT_FULLY_DISCONNECTED=ON` and `FETCHCONTENT_SOURCE_DIR_FMT`
- Final AUR `.SRCINFO` regeneration and exact comparison
- `makepkg --verifysource` for the immutable application, libmdr, and fmt archives
- Clean `makepkg` build with both reviewed patches, disconnected CMake configuration, and all four native CTests
- Package inspection: 19 main-package files, generic `/usr/share` ownership paths, `/usr/bin` executables, `/usr/lib/systemd/user/sony-headphones.service`, and all three MIT notices
- Packaged unit verification with `/usr/bin/sony-headphonesd` and the canonical Linux repository URL
- `namcap` inspection; only the intentional BlueZ service dependency and expected cross-package debug build-ID/empty-directory findings remain
- Temporary package installation, zero missing owned files, isolated packaged mock daemon, volume `20`, ambient level `12`, CLI/daemon version `0.2.2`, and static unit validation
- Clean temporary package removal preserved the existing user plugin, source-installed native companion, and private state

Passed after tagging and publication:

- Signed final commit `2115b1ae0e1aada891040b5c008c55457dc1fbde` and annotated tag `v0.2.2` verified against the dedicated Ed25519 release key
- GitHub Actions main run `32391079569` and tag run `32391084159`, including policy/native-core and pinned Arch Bluetooth-backend jobs
- Non-draft `v0.2.2` GitHub hardware-alpha prerelease published source-only with no uploaded binary assets
- AUR repository `sony-headphones-linux` initial signed import at commit `1cda9b91e1ae133d7acd3c5ef00b63a78d0179de`
- Official AUR RPC reports `sony-headphones-linux` version `0.2.2-1`, maintainer `VyomJain`, canonical upstream URL, and the intended provide/conflict/replace relationship to `sony-headphones-omarchy`
- Marketplace issue 712 title, repository URL, maintainer notes, ownership boundaries, install/removal paths, dependency verification description, and screenshots updated for the generic v0.2.2 tree
- Marketplace reviewer follow-up posted with the exact fixed commit, signed prerelease, AUR package, CI runs, and local release-gate evidence
- Marketplace automation revalidated commit `2115b1ae0e1aada891040b5c008c55457dc1fbde`, detected the root preview, removed `needs-fixes`, and retained only the expected manual security review gate
- The temporary package, AUR publishing checkout, source archive, signature-verification file, `namcap`, and its now-unused dependencies were removed; the existing source-installed service, plugin, and private state remain preserved

Still pending external review or authenticated web action:

- AUR Package Maintainer acceptance of the submitted merge request from `sony-headphones-omarchy` into `sony-headphones-linux`; both package bases remain live until acceptance
- Remediation of the post-listing source-installer ownership finding and a Marketplace snapshot refresh for issue 712

## 2026-08-21 — v0.2.3 source-installer ownership repair

Finding addressed:

- Marketplace issue 712 identified that the receipt-free v0.2.2 source installer overwrote fixed user paths and the uninstaller disabled/removed them without proving ownership.

Passed during implementation:

- Bash syntax and ShellCheck for the shared lifecycle helper, installer, uninstaller, and expanded test suite
- Fresh source install, idempotent reinstall, exact legacy adoption, and clean receipt-backed removal
- Fail-closed rejection of unrelated regular files, partial conflicts, symbolic links at every managed destination, a symbolic-linked managed directory, and a symbolic-linked receipt
- Fail-closed update and removal after an owned service file is modified, with no disable or reload action after the failed preflight
- Fail-closed update and removal for a foreign-checkout receipt
- Safe removal when one recorded artifact is already absent
- Refusal to disable or remove an existing native path when no ownership receipt exists
- Preservation of daemon status state and a separately managed Omarchy plugin marker across every successful removal
- Byte-for-byte validation and receipt adoption of the live v0.2.2 source installation before rebuilding v0.2.3
- Receipt-verified live update to daemon/CLI version 0.2.3; the user service remained enabled and active and the receipt remained a single-link, user-owned regular file with mode `0600`
- Signed immutable application source commit `927b69d23d18806e75fe260010447234299ed73a`
- Application source archive SHA-256 `9cc364626f817b273420898f09cbab731752d60272bd129ebb741f4ebb2fafa7`
- Complete `./scripts/release-check.sh` gate: repository/source policy, ShellCheck, native tests without libmdr, installer lifecycle, mock end to end, ASan/UBSan, the pinned libmdr/fmt backend, QML lint, and Omarchy validation
- Clean AUR `makepkg --verifysource` and `makepkg --cleanbuild --clean`; all three immutable archives passed SHA-256 verification and all four packaged native tests passed
- Temporary installation of the resulting `sony-headphones-linux 0.2.3-1` package verified both `/usr/bin` programs at version 0.2.3 and confirmed that the existing receipt-managed user unit retained precedence; package removal preserved that source installation and private state

Publication completed:

- Signed finalization commit and signed `v0.2.3` tag at `94733d6c1919eb4d15a88b21083c79ca63d23fc3`
- Successful GitHub Actions runs for [main](https://github.com/VyomJain6904/sony-headphones-linux/actions/runs/32412601527) and the [v0.2.3 tag](https://github.com/VyomJain6904/sony-headphones-linux/actions/runs/32412601363), including the pinned Bluetooth backend on the tag
- Source-only [v0.2.3 hardware-alpha prerelease](https://github.com/VyomJain6904/sony-headphones-linux/releases/tag/v0.2.3) with no uploaded binary assets
- Signed AUR update commit `35b4e1a097bd96015d7c93d55e9e47b3eb6a99dd`; the public `sony-headphones-linux` package metadata exposes version `0.2.3-1`, the immutable source commit, and its verified SHA-256 checksum

Still pending external Marketplace action:

- Issue 712 maintainer review, removal of the post-listing `needs-fixes` label, and refresh of the listing snapshot to the fixed commit
