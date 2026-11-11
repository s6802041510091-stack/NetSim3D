# Background music

## Included and active

`LofiLoop.ogg` (1,430,666 bytes): main menu, level selection, settings and loading/ready screens. "Lofi Hip Hop Loop" by omfgdude, CC0.

Source page: https://opengameart.org/node/94031
Original download: https://opengameart.org/sites/default/files/LofiLoop_2.ogg
The original file is kept unchanged and renamed to match Sound.MUSIC's existing menu entry.

Godot loops the track and fades it in/out. It uses the Music bus, controlled by Settings → Music. It continues while the scene loads and the Start button is waiting; it fades out only when the player starts the level.

## Optional level track

`calm_track-loop.ogg` is still an optional file, not included. Its existing source reference is https://opengameart.org/content/calm-track ("Calm Track" by pmiller, CC0/public domain). Until a level track is added, the menu music fades out and the existing in-world ambience continues.

## Loading notification

`Sound.play("load_complete")` uses `kenney/confirmation_001.ogg` through the SoundEffect bus. GameFlow triggers it once when the world is ready and the displayed progress reaches 100%. It is independent of the percentage label's visibility.
