# Sound credits

All sounds in the game are free to use in this thesis, on the web and in
commercial work. None of them requires credit (CC0 / public domain); the
credits are given anyway.

| Folder | What | Source | License |
|---|---|---|---|
| `kenney/` | Footsteps, doors, chair (cloth), interface clicks, confirm/error, windows | Kenney — Impact Sounds, Interface Sounds, RPG Audio (www.kenney.nl) | CC0 1.0 (`kenney/LICENSE_kenney.txt`) |
| `generated/` | Room ambience (outside, air conditioner, computer fans), computer boot/shutdown, keyboard and mouse clicks, dialogue typing, result jingles and star | Made for this game by `tools/audio/generate_sounds.cjs` | Part of this project |
| `music/LofiLoop.ogg` | Menu music | "Lofi Hip Hop Loop" by omfgdude (OMF-Games), https://opengameart.org/content/lofi-hip-hop-loop | CC0 |
| `music/calm_track-loop.ogg` | Level music | "Calm Track" by pmiller, https://opengameart.org/content/calm-track | CC0 / public domain |

Which sound plays for what: `scripts/audio/sound.gd` (`BANK` and `MUSIC`).
Room ambience layers: node `Ambience` in `scenes/main.tscn`.
