# Sony Headphones for Decky Loader (Steam Deck)

A [Decky Loader](https://decky.xyz) Quick Access panel for `sony-headphonesd`. You can control
noise cancelling, ambient sound, focus-on-voice, speak-to-chat, DSEE, EQ presets, connection and
volume, and see battery levels, all from Game Mode.

## Requirements

- Decky Loader installed on the Steam Deck.
- `sony-headphonesd` from this repository, built and running as a `systemd --user` service on the
  Deck (see the top-level README and `docs/DEVELOPMENT.md`). The plugin talks to the daemon's
  socket at `$XDG_RUNTIME_DIR/sony-headphones/daemon.sock` and reads
  `~/.local/state/sony-headphones/status.json`.

## Install from a release

1. Download `sony-headphones.zip` from the Releases page of this fork.
2. In Decky, open Settings, then Developer, and turn on Developer mode. Choose **Install Plugin
   from ZIP** and pick the file.

## Build from source

```sh
cd decky
pnpm install
pnpm build            # writes dist/index.js
./scripts/package.sh  # writes out/sony-headphones.zip
sudo ./install.sh     # or install the built plugin directly into ~/homebrew/plugins
```

## Notes

- The backend is a small Python bridge, because Decky requires one. It has no root flag. It only
  forwards an allow-listed set of daemon commands, and it closes the control session when it
  unloads so Sony's phone app can reconnect.
