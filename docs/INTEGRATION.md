# Integration Guide

The native daemon (`sony-headphonesd`) and CLI (`sony-headphonesctl`) are standalone Linux programs. They have no dependency on Omarchy, Quickshell, or any specific desktop environment. Any tool that can read a JSON file or run a shell command can display headphone state and send control commands.

## Interfaces

### Status file

The daemon atomically publishes device state to:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/sony-headphones/status.json
```

The file is atomically written (write → fsync → rename), so readers never see a partial update. The directory is mode `0700` and the file is mode `0600`.

Example contents:

```json
{
  "schema_version": 1,
  "daemon_version": "0.2.3",
  "revision": 9,
  "phase": "ready",
  "connected": true,
  "device": {
    "name": "WH-1000XM5",
    "model": "WH-1000XM5",
    "firmware": "2.5.1",
    "protocol": 2,
    "codec": "ldac"
  },
  "battery": {
    "main": { "present": true, "level": 73, "charging": "no" },
    "left": { "present": false, "level": -1, "charging": "unknown" },
    "right": { "present": false, "level": -1, "charging": "unknown" },
    "case": { "present": false, "level": -1, "charging": "unknown" }
  },
  "capabilities": {
    "battery_single": true,
    "noise_cancelling": true,
    "ambient_sound": true,
    "speak_to_chat": true,
    "equalizer": true,
    "dsee": true,
    "playback_volume": true,
    "connection_mode": true
  },
  "noise": {
    "mode": "anc",
    "ambient_level": 12,
    "focus_on_voice": false,
    "adaptive": false,
    "adaptive_sensitivity": "unknown"
  },
  "speak_to_chat": {
    "enabled": false,
    "sensitivity": "unknown",
    "timeout": "unknown"
  },
  "equalizer": {
    "preset": "bright",
    "available_presets": ["off", "rock", "pop", "jazz", "bright", "bass"],
    "clear_bass": 2,
    "bands": [-2, 0, 2],
    "dsee_enabled": true,
    "dsee_type": "dsee_extreme"
  },
  "playback": {
    "status": "unknown",
    "volume": 63
  },
  "connection": {
    "priority": "quality"
  },
  "last_error": ""
}
```

Check `capabilities` before displaying a control. A missing or `false` capability means the headphones do not support that feature.

### CLI commands

`sony-headphonesctl` sends one validated command to the daemon per invocation:

```text
status                              Print the current status JSON
noise off|anc|ambient               Set the noise control mode
ambient-level 1..20                 Set ambient sound level
focus-on-voice on|off               Toggle focus on voice in ambient mode
speak-to-chat on|off                Toggle Speak-to-Chat
dsee on|off                         Toggle DSEE sound upscaling
eq-preset <preset>                  Set equalizer preset
connection quality|stable           Set connection priority
volume 0..100                       Set playback volume (percentage)
playback play|pause|next|previous   Control playback
```

Exit code `0` means success. A non-zero exit prints the error to stderr.

### Unix socket

For direct IPC without the CLI, connect to the Unix stream socket:

```text
${XDG_RUNTIME_DIR}/sony-headphones/daemon.sock
```

Send one UTF-8 command line (max 4096 bytes). The response is `ok`, `ok <payload>`, or `error <message>`.

## Desktop bar integrations

### Waybar

Use a custom JSON module that reads the status file:

```jsonc
// ~/.config/waybar/config
"custom/sony": {
    "exec": "cat ~/.local/state/sony-headphones/status.json",
    "return-type": "json",
    "interval": 3,
    "on-click": "sony-headphonesctl noise anc",
    "on-click-right": "sony-headphonesctl noise ambient",
    "on-click-middle": "sony-headphonesctl noise off"
}
```

For a reactive approach using `inotifywait`:

```sh
#!/bin/sh
# ~/.config/waybar/scripts/sony.sh
cat ~/.local/state/sony-headphones/status.json
inotifywait -m -q -e close_write ~/.local/state/sony-headphones/status.json 2>/dev/null | while read -r _; do
  jq -c '{
    text: ("󰋋 " + (.battery.main.level|tostring) + "%"),
    tooltip: ("Mode: " + .noise.mode + "\nDevice: " + .device.name),
    class: .noise.mode
  }' ~/.local/state/sony-headphones/status.json
done
```

### Polybar

```ini
[module/sony-headphones]
type = custom/script
exec = jq -r 'if .connected then "󰋋 " + (.battery.main.level|tostring) + "% [" + .noise.mode + "]" else "" end' ~/.local/state/sony-headphones/status.json 2>/dev/null
interval = 3
click-left = sony-headphonesctl noise anc
click-right = sony-headphonesctl noise ambient
click-middle = sony-headphonesctl noise off
```

### eww (ElKowar's Wacky Widgets)

Use `deflisten` with `inotifywait` for reactive state:

```yuck
(deflisten sony_status :initial "{}"
  `inotifywait -m -q -e close_write ~/.local/state/sony-headphones/status.json | while read -r _; do cat ~/.local/state/sony-headphones/status.json; done`)

(defwidget headphones []
  (box :class "headphones" :orientation "h" :space-evenly false
    (label :text {sony_status.connected
      ? "󰋋 ${sony_status.battery.main.level}%"
      : "󰋐 Disconnected"})
    (button :onclick "sony-headphonesctl noise anc" "ANC")
    (button :onclick "sony-headphonesctl noise ambient" "Ambient")
    (button :onclick "sony-headphonesctl noise off" "Off")
    (scale :min 0 :max 100
           :value {sony_status.playback.volume ?: 0}
           :onchange "sony-headphonesctl volume {}")))
```

### i3status-rust

```toml
[[block]]
block = "custom"
command = "jq -r 'if .connected then \"󰋋 \" + (.battery.main.level|tostring) + \"% (\" + .noise.mode + \")\" else \"󰋐\" end' ~/.local/state/sony-headphones/status.json"
interval = 3
[[block.click]]
button = "left"
cmd = "sony-headphonesctl noise anc"
[[block.click]]
button = "right"
cmd = "sony-headphonesctl noise ambient"
```

### AGS (Aylur's GTK Shell)

```javascript
const statePath = GLib.get_user_state_dir() + '/sony-headphones/status.json';

const sonyService = Variable({}, {
    listen: [['inotifywait', '-m', '-q', '-e', 'close_write', statePath],
             () => JSON.parse(Utils.readFile(statePath))],
});

const SonyWidget = () => Widget.Button({
    child: Widget.Label({
        label: sonyService.bind().as(s =>
            s.connected ? `󰋋 ${s.battery?.main?.level}% (${s.noise?.mode})` : '󰋐'),
    }),
    on_primary_click: () => Utils.execAsync(['sony-headphonesctl', 'noise', 'anc']),
    on_secondary_click: () => Utils.execAsync(['sony-headphonesctl', 'noise', 'ambient']),
});
```

### Conky

```text
${if_existing ~/.local/state/sony-headphones/status.json}
  Headphones: ${execi 3 jq -r '.device.name // "Sony"' ~/.local/state/sony-headphones/status.json}
  Battery:    ${execi 3 jq -r '.battery.main.level' ~/.local/state/sony-headphones/status.json}%
  ANC Mode:   ${execi 3 jq -r '.noise.mode' ~/.local/state/sony-headphones/status.json}
  Volume:     ${execi 3 jq -r '.playback.volume' ~/.local/state/sony-headphones/status.json}%
${endif}
```

## Window manager keybindings

### Hyprland

```text
bind = $mainMod, F9, exec, sony-headphonesctl noise anc
bind = $mainMod, F10, exec, sony-headphonesctl noise ambient
bind = $mainMod, F11, exec, sony-headphonesctl noise off
bind = $mainMod, F12, exec, sony-headphonesctl speak-to-chat on
```

### Sway / i3

```text
bindsym $mod+F9 exec sony-headphonesctl noise anc
bindsym $mod+F10 exec sony-headphonesctl noise ambient
bindsym $mod+F11 exec sony-headphonesctl noise off
bindsym $mod+F12 exec sony-headphonesctl speak-to-chat on
```

### sxhkd

```text
super + F9
    sony-headphonesctl noise anc
super + F10
    sony-headphonesctl noise ambient
```

## Scripting

### Shell script

```bash
#!/bin/bash
# Switch to ANC and set volume for a meeting
sony-headphonesctl noise anc
sony-headphonesctl focus-on-voice on
sony-headphonesctl volume 60

# Read battery level
battery=$(jq -r '.battery.main.level' ~/.local/state/sony-headphones/status.json)
echo "Battery: ${battery}%"
```

### Python

Read the status file:

```python
import json
from pathlib import Path

state_dir = Path.home() / ".local" / "state" / "sony-headphones"
status = json.loads((state_dir / "status.json").read_text())
print(f"Battery: {status['battery']['main']['level']}%")
print(f"Mode: {status['noise']['mode']}")
```

Send commands directly through the Unix socket:

```python
import os
import socket

def send_command(cmd: str) -> str:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/tmp/sony-headphones-{os.getuid()}")
    sock_path = os.path.join(runtime_dir, "sony-headphones", "daemon.sock")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(sock_path)
        client.sendall(f"{cmd}\n".encode("utf-8"))
        client.shutdown(socket.SHUT_WR)
        return client.recv(4096).decode("utf-8").strip()

print(send_command("noise anc"))
print(send_command("volume 70"))
```

## Desktop environment widgets

### KDE Plasma

A custom Plasmoid can use Qt's `FileView` or `QFile` to watch `status.json` and run `sony-headphonesctl` through the `Executable` data source to build a full panel widget in the KDE system tray.

### GNOME Shell

A GNOME Shell extension can use `Gio.FileMonitor` on the status file and `Gio.Subprocess` to run `sony-headphonesctl`, placing battery and noise-mode controls in the GNOME status area popup.

## Automation

### Meeting mode script

```bash
#!/bin/bash
# Detect meeting and switch headphone profile
if pgrep -x zoom > /dev/null || pgrep -x teams > /dev/null; then
    sony-headphonesctl noise ambient
    sony-headphonesctl focus-on-voice on
    sony-headphonesctl speak-to-chat on
fi
```

### Low battery notification

```bash
#!/bin/bash
battery=$(jq -r '.battery.main.level // -1' ~/.local/state/sony-headphones/status.json 2>/dev/null)
if [ "$battery" -ge 0 ] && [ "$battery" -le 15 ]; then
    notify-send "Sony Headphones" "Battery low: ${battery}%"
fi
```

## Quickshell (non-Omarchy)

The included `Service.qml` and `Model.js` files use only standard `Quickshell` and `Quickshell.Io` APIs (`FileView`, `Process`, `StdioCollector`). They can be imported directly into any Quickshell configuration without Omarchy:

```qml
import QtQuick
import Quickshell
import "path/to/sony-headphones/Service.qml" as SonyService

Item {
    SonyService {
        id: sony
        // sony.status contains the parsed JSON
        // sony.setNoiseMode("anc") sends a command
    }

    Text {
        text: sony.connected
            ? "󰋋 " + sony.status.battery.main.level + "%"
            : "Disconnected"
    }
}
```

The Omarchy-specific components (`BarWidget.qml`, `Panel.qml`) use `qs.Ui` and `qs.Commons` APIs and require Omarchy's shell process.
