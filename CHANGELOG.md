# Changelog

All notable changes will be documented here. The format follows Keep a Changelog, and releases use Semantic Versioning.

## [Unreleased]

### Added

- Add a Decky Loader plugin (`decky/`) that gives Steam Deck Game Mode a Quick Access panel for `sony-headphonesd`.

## [0.2.3] - 2026-08-21

### Added

- Add a private schema-v1 ownership receipt that binds source-installed destination paths and content hashes to the canonical checkout.
- Expand the isolated installer lifecycle suite across legacy adoption, idempotent reinstall, partial conflicts, destination and directory symlinks, modified artifacts, foreign receipts, missing owned files, and unowned uninstall.

### Changed

- Make source install stage verified files and receipt data before replacing any destination, with rollback backups for interrupted updates.
- Make source uninstall validate the full receipt and every remaining artifact before stopping the user service or removing any file.

### Fixed

- Refuse to overwrite or remove unrelated, linked, hard-linked, foreign-checkout, or locally modified native paths.
- Preserve the Omarchy checkout and private runtime state while removing only unchanged source-owned artifacts and their receipt.

## [0.2.2] - 2026-08-20

### Added

- Add a supported root Marketplace preview and an isolated native installer lifecycle test.
- Add integration guide with examples for Waybar, Polybar, eww, AGS, i3status-rust, Conky, Hyprland/Sway/i3 keybindings, Python, KDE Plasma, GNOME Shell, and any Quickshell config.

### Changed

- Rename the canonical upstream project and native AUR package to `sony-headphones-linux` while preserving the Omarchy plugin ID and every runtime interface.
- Replace the root README with a concise installation-first guide and move detailed development, integration, and publication material into focused documents.
- Restore transparent `install.sh` and `uninstall.sh` entry points that manage only the desktop-independent native companion.

### Fixed

- Verify the exact fmt commit before CMake configuration and force libmdr to consume that local source with FetchContent fully disconnected.
- Correct every current removal instruction to invoke a tracked executable script.

### Security

- Remove command-name obfuscation and document package, remote-build, and user-service capabilities explicitly for Marketplace review.
## [0.2.1] - 2026-08-19

### Added

- Add stable AUR packaging for the native daemon, CLI, and systemd user service, with every source archive pinned and checksummed.
- Add complete source, Marketplace, AUR, update, and uninstall guidance plus paste-ready Marketplace maintainer notes.

### Changed

- Add labeled, theme-aware icons to the Noise cancelling, Ambient, and Off sound-control buttons.
- Reduce the panel width and maximum height slightly while preserving control and text sizing.
- Split distribution ownership cleanly: the system package manager owns native companion files under `/usr`, while Omarchy owns the per-user QML checkout.
- Let makepkg control binary stripping and optional debug-symbol extraction for the Arch package.

### Fixed

- Normalize the public `0..100` volume contract to Sony MDR's raw `0..30` scale and settle the panel immediately to a representable hardware level.

## [0.2.0] - 2026-08-19

### Added

- Initial Omarchy bar-widget manifest, bar entry point, nested details panel, watched-state service, and capability-driven model.
- Native C++20 daemon and CLI architecture with private Unix IPC, atomic JSON state, and no Python runtime.
- Deterministic mock backend and compile-time development backend.
- Pinned libmdr build integration, BlueZ D-Bus discovery, MDR v2/v1 connection flow, and initial read/write mapping.
- User-level systemd service and local install/build/check scripts.
- Qt 6/Omarchy-aware QML lint wrapper and source-checkout-aware uninstaller.
- Two-tier GitHub Actions checks, sanitizer/release wrappers, and structured bug/device report forms.
- Schema-v1 optional `equalizer.available_presets` field and capability-gated mock preset validation.
- Product specification, roadmap, tasks, compatibility, architecture, development, security, and contribution documentation.

### Changed

- Promoted the maintained C++/QML implementation to the repository root and expanded generated-file, local-environment, editor, log, and temporary-file exclusions.
- Reworked the bar entry as an icon-only Nerd Font headphone glyph and moved battery detail to the tooltip/panel.
- Reworked the panel with Omarchy's live color/style tokens, native hero/buttons/toggles/sliders, standard themed scrolling, and consistent spacing.
- Centered every action-button row and added Omarchy-style arrow-key navigation, activation, slider adjustment, hover synchronization, and automatic cursor scrolling.
- Removed transport playback buttons from the panel while retaining the v1 native command contract for backward compatibility.
- Hide equalizer preset controls unless the daemon reports the exact writable preset list.
- Made install/uninstall safe when Omarchy clones the repository directly into its managed plugin directory.

### Fixed

- Corrected MDR v2 protocol reporting and a pinned libmdr validation defect that rejected the WH-1000XM5 sound-quality connection mode.
- Prefer current protocol errors over stale transport details and suppress meaningless `N/A` error suffixes.
- Avoid transient QML null-to-integer warnings while optimistic slider values are installed.
- Commit the last actual ambient/volume slider position instead of allowing the external state binding to restore and resend the previous value at pointer release.

### Security

- Control socket and state directory are user-private.
- Bluetooth MAC addresses are excluded from the QML-facing state document.
- Firmware flashing, factory reset, cloud/account functions, tracking, and 360 Reality Audio are explicitly out of scope.

[Unreleased]: https://github.com/VyomJain6904/sony-headphones-linux/compare/v0.2.3...HEAD
[0.2.3]: https://github.com/VyomJain6904/sony-headphones-linux/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/VyomJain6904/sony-headphones-linux/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/VyomJain6904/sony-headphones-linux/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/VyomJain6904/sony-headphones-linux/releases/tag/v0.2.0
