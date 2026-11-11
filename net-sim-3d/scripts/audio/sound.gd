class_name Sound
extends Node

## Sound effects and music for the whole game (autoload "SoundManager").
## Call from anywhere:
##   Sound.play("door_open", door)        # 3D at a node or a Vector3
##   Sound.play("confirm")                # 2D (UI)
##   Sound.music("level")                 # cross-fades the background music
## Every Button and slider makes a sound by itself: a click, "select" for
## toggle buttons, or the id in the button's meta "sound" ("" = silent).
## Buses follow the settings page: Music, SoundEffect (mission, computer,
## dialogue), Sound (ambience, footsteps, doors).

const KENNEY := "res://assets/audio/kenney/"
const GENERATED := "res://assets/audio/generated/"
const MUSIC_DIR := "res://assets/audio/music/"

## id -> files, bus, volume (dB), random pitch spread, 3D max distance (m),
## shortest gap between two plays (s).
const BANK := {
	# Moving around (bus Sound)
	"step": {"files": ["footstep_concrete_000.ogg", "footstep_concrete_001.ogg", "footstep_concrete_002.ogg", "footstep_concrete_003.ogg", "footstep_concrete_004.ogg"],
		"bus": "Sound", "db": -12.0, "pitch": 0.08},
	"door_open": {"files": ["doorOpen_1.ogg", "doorOpen_2.ogg"], "bus": "Sound", "db": -6.0, "range": 20.0},
	"door_close": {"files": ["doorClose_1.ogg", "doorClose_2.ogg", "doorClose_4.ogg"], "bus": "Sound", "db": -6.0, "range": 20.0},
	"door_blocked": {"files": ["metalLatch.ogg"], "bus": "Sound", "db": -6.0, "range": 12.0},
	"chair": {"files": ["cloth1.ogg", "cloth2.ogg"], "bus": "Sound", "db": -8.0},
	# Crimping desk (bus SoundEffect)
	"snip": {"files": ["@key_tap.wav"], "bus": "SoundEffect", "db": -4.0, "pitch": 0.05},
	"crimp": {"files": ["metalLatch.ogg"], "bus": "SoundEffect", "db": -2.0, "pitch": 0.04},
	# NPC at work (bus Sound, quiet and close)
	"key_tap": {"files": ["@key_tap.wav"], "bus": "Sound", "db": -14.0, "pitch": 0.12, "range": 7.0},
	"mouse_click": {"files": ["@mouse_click.wav"], "bus": "Sound", "db": -16.0, "pitch": 0.08, "range": 6.0},
	# Interface and mission (bus SoundEffect)
	"click": {"files": ["click_002.ogg", "click_003.ogg"], "bus": "SoundEffect", "db": -8.0, "pitch": 0.04, "gap": 0.05},
	"select": {"files": ["select_001.ogg"], "bus": "SoundEffect", "db": -6.0, "pitch": 0.03, "gap": 0.05},
	"confirm": {"files": ["confirmation_001.ogg"], "bus": "SoundEffect", "db": -4.0},
	"load_complete": {"files": ["confirmation_001.ogg"], "bus": "SoundEffect", "db": -3.0},
	"correct": {"files": ["confirmation_002.ogg"], "bus": "SoundEffect", "db": -3.0},
	"wrong": {"files": ["error_004.ogg"], "bus": "SoundEffect", "db": -4.0},
	"back": {"files": ["back_001.ogg"], "bus": "SoundEffect", "db": -8.0, "gap": 0.05},
	"popup_open": {"files": ["@popup_soft.wav"], "bus": "SoundEffect", "db": -8.0},
	"popup_close": {"files": ["close_002.ogg"], "bus": "SoundEffect", "db": -8.0},
	"window_open": {"files": ["maximize_003.ogg"], "bus": "SoundEffect", "db": -8.0},
	"window_close": {"files": ["minimize_003.ogg"], "bus": "SoundEffect", "db": -8.0},
	"toggle_on": {"files": ["switch_002.ogg"], "bus": "SoundEffect", "db": -8.0},
	"toggle_off": {"files": ["switch_003.ogg"], "bus": "SoundEffect", "db": -8.0},
	"slider": {"files": ["tick_002.ogg"], "bus": "SoundEffect", "db": -12.0, "gap": 0.06},
	"objective": {"files": ["drop_002.ogg"], "bus": "SoundEffect", "db": -4.0},
	"type_tick": {"files": ["@type_tick.wav"], "bus": "SoundEffect", "db": -14.0, "pitch": 0.12, "gap": 0.035},
	"pc_boot": {"files": ["@pc_boot.wav"], "bus": "SoundEffect", "db": -6.0},
	"pc_off": {"files": ["@pc_off.wav"], "bus": "SoundEffect", "db": -8.0},
	"jingle_pass": {"files": ["@jingle_pass.wav"], "bus": "SoundEffect", "db": -3.0},
	"jingle_fail": {"files": ["@jingle_fail.wav"], "bus": "SoundEffect", "db": -4.0},
	"star": {"files": ["@star.wav"], "bus": "SoundEffect", "db": -6.0},
}
## Background music (put the files in assets/audio/music/, see README there).
const MUSIC := {
	"menu": {"file": "LofiLoop.ogg", "db": -10.0},
	"level": {"file": "calm_track-loop.ogg", "db": -16.0},
}
const MUSIC_FADE := 1.5
const POOL_2D := 10
const POOL_3D := 10

static var _instance: Sound

var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0
var _cache := {}
var _last_play := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_id := ""
var _active_music: AudioStreamPlayer
var _music_fade: Tween
## The last few ids played, newest last (for tests).
var history: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SoundEffect", "Sound"]:
		_ensure_bus(bus)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 3.0
		add_child(p)
		_players_3d.append(p)
	_music_a = _music_player()
	_music_b = _music_player()
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	for p in _players + [_music_a, _music_b]:
		p.stop()
		p.stream = null
	for p in _players_3d:
		p.stop()
		p.stream = null
	_cache.clear()


# --- static API ----------------------------------------------------------------

## Plays sound `id`; with `at` (a Node3D or a Vector3) it comes from that spot.
static func play(id: String, at: Variant = null, volume_db := 0.0, pitch := 1.0) -> void:
	if is_instance_valid(_instance):
		_instance._play(id, at, volume_db, pitch)


## Switches the background music ("menu", "level" or "" for none).
static func music(id: String) -> void:
	if is_instance_valid(_instance):
		_instance._switch_music(id)


## True when sound `id` has a file that can be loaded.
static func has_sound(id: String) -> bool:
	return is_instance_valid(_instance) and _instance._stream(id) != null


# --- playing ---------------------------------------------------------------------

func _play(id: String, at: Variant, volume_db: float, pitch: float) -> void:
	var entry: Dictionary = BANK.get(id, {})
	var stream := _stream(id)
	if entry.is_empty() or stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(id, -10.0)) < float(entry.get("gap", 0.0)):
		return
	_last_play[id] = now
	history.append(id)
	if history.size() > 40:
		history.remove_at(0)
	var spread: float = entry.get("pitch", 0.0)
	var scale := pitch * (1.0 + randf_range(-spread, spread))
	var db: float = float(entry.get("db", 0.0)) + volume_db
	var where: Variant = at.global_position if at is Node3D and is_instance_valid(at) else at
	if where is Vector3:
		var p := _players_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _players_3d.size()
		p.stream = stream
		p.bus = entry["bus"]
		p.volume_db = db
		p.pitch_scale = scale
		p.max_distance = float(entry.get("range", 15.0))
		p.global_position = where
		p.play()
	else:
		var p := _players[_next_2d]
		_next_2d = (_next_2d + 1) % _players.size()
		p.stream = stream
		p.bus = entry["bus"]
		p.volume_db = db
		p.pitch_scale = scale
		p.play()


## A random file of sound `id` (cached), null when none exists.
func _stream(id: String) -> AudioStream:
	var entry: Dictionary = BANK.get(id, {})
	var files: Array = entry.get("files", [])
	if files.is_empty():
		return null
	var file: String = files[randi() % files.size()]
	var path := (GENERATED + file.substr(1)) if file.begins_with("@") else (KENNEY + file)
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


# --- music -----------------------------------------------------------------------

func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _switch_music(id: String) -> void:
	if id == _music_id and _active_music != null and _active_music.playing:
		return
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	_music_id = id
	var old := _active_music
	var new := _music_b if old == _music_a else _music_a
	# Cancel a previous transition before reusing either voice, so an older
	# fade-out callback cannot stop music that was just restarted.
	new.stop()
	var entry: Dictionary = MUSIC.get(id, {})
	var path: String = MUSIC_DIR + String(entry.get("file", ""))
	if entry.is_empty() or not ResourceLoader.exists(path):
		if old != null and old.playing:
			_music_fade = create_tween()
			_music_fade.tween_property(old, "volume_db", -80.0, MUSIC_FADE)
			_music_fade.tween_callback(old.stop)
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	new.stream = stream
	new.volume_db = -60.0
	new.play()
	_active_music = new
	_music_fade = create_tween().set_parallel(true)
	_music_fade.tween_property(new, "volume_db", float(entry["db"]), MUSIC_FADE)
	if old != null and old.playing:
		_music_fade.tween_property(old, "volume_db", -80.0, MUSIC_FADE)
		_music_fade.chain().tween_callback(old.stop)


# --- automatic UI sounds -----------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node.has_meta("_sound_hooked"):
		return
	if node is BaseButton:
		node.set_meta("_sound_hooked", true)
		var button := node as BaseButton
		button.pressed.connect(_on_button_pressed.bind(button))
	elif node is HSlider or node is VSlider:
		node.set_meta("_sound_hooked", true)
		(node as Range).value_changed.connect(func(_v: float): _play("slider", null, 0.0, 1.0))


func _on_button_pressed(button: BaseButton) -> void:
	var id := "click"
	if button.toggle_mode:
		id = "select"
	if button.has_meta("sound"):
		id = String(button.get_meta("sound"))
	if id != "":
		_play(id, null, 0.0, 1.0)


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, "Master")
