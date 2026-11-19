"""Decky backend: bridges the Quick Access panel to sony-headphonesd.

Talks to the daemon's private Unix socket directly (same one-line protocol
sony-headphonesctl uses) and reads the atomically published status.json.
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


def _home() -> str:
    return getattr(decky, "DECKY_USER_HOME", None) or os.path.expanduser("~")


def _state_file() -> str:
    return os.path.join(_home(), ".local", "state", "sony-headphones", "status.json")


def _socket_path() -> str:
    # The daemon runs as a systemd --user service, so XDG_RUNTIME_DIR is /run/user/<uid>.
    # Decky's environment usually lacks XDG_RUNTIME_DIR, so derive it from our uid.
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return os.path.join(runtime, "sony-headphones", "daemon.sock")


def _send_blocking(words: list[str]) -> dict:
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
    response = b"".join(chunks).decode(errors="replace").strip()
    if response == "ok" or response.startswith("ok "):
        return {"ok": True, "error": ""}
    if response.startswith("error "):
        return {"ok": False, "error": response[6:]}
    return {"ok": False, "error": "Malformed daemon response"}


class Plugin:
    async def status(self) -> dict:
        try:
            with open(_state_file(), encoding="utf-8") as handle:
                return {"ok": True, "status": json.load(handle), "error": ""}
        except FileNotFoundError:
            return {"ok": False, "status": None,
                    "error": "sony-headphonesd is not running (no status file)"}
        except (OSError, ValueError) as exc:
            # status.json is written atomically, so this is rare; the next poll recovers.
            return {"ok": False, "status": None, "error": f"Could not read status: {exc}"}

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
