# Contributing

Start with `AGENTS.md`, `SPEC.md`, and `docs/DEVELOPMENT.md`. Keep changes narrow, capability-driven, and testable without hardware where possible.

For a device report, include:

- Exact model and region if known
- Firmware version
- Linux distribution, BlueZ version, and connection type
- MDR protocol generation reported by the daemon
- Features discovered, reads verified, writes verified, and failures
- Relevant journal messages with addresses and personal device names removed

Do not submit proprietary Sony application code, decompiled source, encryption keys, copyrighted assets, or packet captures containing personal identifiers. Protocol behavior may be described and independently implemented; code copied from GPL projects cannot be incorporated into this MIT project.

Before a pull request:

```sh
./scripts/check.sh
./scripts/build.sh --without-libmdr
ctest --test-dir build/native --output-on-failure
```

On Omarchy, run `./scripts/qml-lint.sh` and `omarchy plugin validate "$PWD"`. Maintainers use `./scripts/release-check.sh` for the full pinned backend and sanitizer gate.

Hardware changes also require a compatibility-matrix update and a short test log in the pull request.
