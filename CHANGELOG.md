# Changelog

All notable changes will be documented here. The format follows Keep a Changelog, and releases use Semantic Versioning.

## [Unreleased]

### Added

- Initial Omarchy bar-widget manifest, bar entry point, nested details panel, watched-state service, and capability-driven model.
- Native C++20 daemon and CLI architecture with private Unix IPC, atomic JSON state, and no Python runtime.
- Deterministic mock backend and compile-time development backend.
- Pinned libmdr build integration, BlueZ D-Bus discovery, MDR v2/v1 connection flow, and initial read/write mapping.
- User-level systemd service and local install/build/check scripts.
- Product specification, roadmap, tasks, compatibility, architecture, development, security, and contribution documentation.

### Changed

- Promoted the maintained C++/QML implementation to the repository root and expanded generated-file, local-environment, editor, log, and temporary-file exclusions.

### Security

- Control socket and state directory are user-private.
- Bluetooth MAC addresses are excluded from the QML-facing state document.
- Firmware flashing, factory reset, cloud/account functions, tracking, and 360 Reality Audio are explicitly out of scope.

[Unreleased]: https://github.com/VyomJain6904/sony-headphones-omarchy/compare/HEAD...HEAD
