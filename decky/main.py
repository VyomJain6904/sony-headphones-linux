"""Decky backend: bridges the Quick Access panel to sony-headphonesd.

Talks to the daemon's private Unix socket directly (same one-line protocol
sony-headphonesctl uses), including for status, so a dead daemon is never shown as live.
Runs as the Decky user (no "root" flag), so the daemon's 0700 dirs are reachable.
"""

import asyncio
import json
import os
import re
import socket

import decky

_WORD = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")
_ALLOWED_VERBS = {
    "panel-open", "panel-close", "refresh",
    "noise", "ambient-level", "focus-on-voice", "speak-to-chat", "dsee",
    "eq-preset", "connection", "volume",
}


def _socket_path() -> str:
    # The daemon runs as a systemd --user service, so XDG_RUNTIME_DIR is /run/user/<uid>.
    # Decky's environment usually lacks XDG_RUNTIME_DIR, so derive it from our uid.
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return os.path.join(runtime, "sony-headphones", "daemon.sock")


def _request(words: list[str]) -> str:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(3.0)
        sock.connect(_socket_path())
        sock.sendall((" ".join(words) + "\n").encode())
        sock.shutdown(socket.SHUT_WR)
        chunks = []
        while True:
            chunk = sock.recv(8192)
            if not chunk:
                break
            chunks.append(chunk)
    return b"".join(chunks).decode(errors="replace").strip()


def _send_blocking(words: list[str]) -> dict:
    response = _request(words)
    if response == "ok" or response.startswith("ok "):
        return {"ok": True, "error": ""}
    if response.startswith("error "):
        return {"ok": False, "error": response[6:]}
    return {"ok": False, "error": "Malformed daemon response"}


def _status_blocking() -> dict:
    # Ask the daemon directly rather than reading status.json: a crashed daemon leaves
    # that file behind, which would keep showing a stale "Connected" state.
    response = _request(["status"])
    if response.startswith("ok "):
        return {"ok": True, "status": json.loads(response[3:]), "error": ""}
    if response.startswith("error "):
        return {"ok": False, "status": None, "error": response[6:]}
    return {"ok": False, "status": None, "error": "Malformed daemon response"}


class Plugin:
    async def status(self) -> dict:
        try:
            return await asyncio.to_thread(_status_blocking)
        except (FileNotFoundError, ConnectionRefusedError):
            return {"ok": False, "status": None, "error": "sony-headphonesd is not running"}
        except ValueError as exc:
            return {"ok": False, "status": None, "error": f"Invalid status from daemon: {exc}"}
        except OSError as exc:
            return {"ok": False, "status": None,
                    "error": f"Could not contact sony-headphonesd: {exc}"}

    async def command(self, words: list) -> dict:
        if (not isinstance(words, list) or not 1 <= len(words) <= 2
                or not all(isinstance(w, str) and _WORD.match(w) for w in words)
                or words[0] not in _ALLOWED_VERBS):
            return {"ok": False, "error": "Rejected command"}
        try:
            return await asyncio.to_thread(_send_blocking, [str(w) for w in words])
        except (FileNotFoundError, ConnectionRefusedError):
            return {"ok": False, "error": "sony-headphonesd is not running"}
        except OSError as exc:
            return {"ok": False, "error": f"Could not contact sony-headphonesd: {exc}"}

    async def _main(self):
        decky.logger.info("Sony Headphones backend loaded; socket %s", _socket_path())

    async def _unload(self):
        # Never leave the control session pinned open, so Sony's phone app can reconnect.
        try:
            await asyncio.to_thread(_send_blocking, ["panel-close"])
        except OSError:
            pass

    async def _uninstall(self):
        pass
