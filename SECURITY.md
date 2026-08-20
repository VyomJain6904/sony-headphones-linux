# Security Policy

## Trust boundary

Omarchy plugins execute unsandboxed with the user's permissions. This plugin therefore keeps its frontend small and delegates Bluetooth protocol work to one unprivileged native user service. It never asks for root, setuid, or a custom system D-Bus policy.

The daemon accepts commands only through a Unix socket in a mode-`0700` runtime directory. The socket is mode `0600`. The QML-facing state directory is private and its JSON deliberately omits the Bluetooth address.

## Network and data

The plugin performs no Internet requests, telemetry, account login, location tracking, or cloud synchronization. Runtime communication is limited to local Unix IPC, system D-Bus/BlueZ, and the selected Bluetooth device.

## Dependencies

- libmdr is fetched from a pinned commit and built locally; its fmt source revision is verified before compilation.
- BlueZ and D-Bus are supplied by the operating system so security updates remain distribution-managed.
- No Python, Electron, package-manager install hook, remote build, or downloaded executable is used.

Review a libmdr pin update as protocol-capable code: inspect its Git diff, licenses, build scripts, Bluetooth backend, generated code, and test results before changing the commit.

## Dangerous operations

Firmware flashing and factory reset are not implemented. Pairing, unpairing, shutdown, and multipoint writes must not be added without explicit confirmation UX and hardware tests.

## Reporting

Do not open a public issue for a vulnerability that could expose local data or send unintended device commands. Use [GitHub private vulnerability reporting](https://github.com/VyomJain6904/sony-headphones-linux/security/advisories/new) with the affected version, reproduction steps, and impact. Avoid including Bluetooth addresses or raw protocol captures unless necessary and encrypted.
