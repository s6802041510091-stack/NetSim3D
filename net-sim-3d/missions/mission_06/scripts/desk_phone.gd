class_name DeskPhone
extends StaticBody3D

## Desk telephone on the player's desk in the IT Support room (Mission 6). While it rings, a red light
## blinks and the player can look at it and press E to answer.
## The player finds it through the shared "interactable" meta (like computers).

signal answered(player: Node)

const META_KEY := &"interactable"
## Same physics layer as computers: hit by the player's interact ray, never blocks walking.
const COLLISION_LAYER := 8

@export var ringing: bool = false:
	set(value):
		ringing = value
		_update_light()
		_update_ring_sound()

## The ring (assets/audio/generated/phone_ring.wav, a 3 s loop), heard from
## the phone in the room: plays while ringing, stops when answered.
const RING_SOUND := "res://assets/audio/generated/phone_ring.wav"

@onready var _ring_light: MeshInstance3D = get_node_or_null("RingLight")
@onready var _handset: Node3D = get_node_or_null("Handset")
var _time := 0.0
var _handset_home := Vector3.ZERO
var _ring_player: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	set_meta(META_KEY, self)
	if _handset:
		_handset_home = _handset.position
	_ring_player = AudioStreamPlayer3D.new()
	_ring_player.name = "RingSound"
	var stream := load(RING_SOUND) as AudioStream if ResourceLoader.exists(RING_SOUND) else null
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ring_player.stream = stream
	_ring_player.bus = "SoundEffect"
	_ring_player.volume_db = -2.0
	_ring_player.unit_size = 4.0
	_ring_player.max_distance = 28.0
	add_child(_ring_player)
	_update_light()
	_update_ring_sound()


## Ringing -> the ring loops; answered (ringing = false) -> silent at once.
func _update_ring_sound() -> void:
	if _ring_player == null or not is_inside_tree():
		return
	if ringing and not _ring_player.playing and _ring_player.stream:
		_ring_player.play()
	elif not ringing and _ring_player.playing:
		_ring_player.stop()


func _process(delta: float) -> void:
	if not ringing:
		return
	_time += delta
	var on := fmod(_time, 0.8) < 0.45
	if _ring_light:
		_ring_light.visible = on
	if _handset:
		# A little rattle while ringing.
		_handset.position = _handset_home + Vector3(0, 0.004 if on and fmod(_time, 0.1) < 0.05 else 0.0, 0)


func get_prompt_text() -> String:
	return "กด F เพื่อรับสาย (โทรศัพท์ดัง)" if ringing else ""


func use(player: Node) -> void:
	if ringing:
		answered.emit(player)


func _update_light() -> void:
	if not is_inside_tree():
		return
	if _ring_light:
		_ring_light.visible = ringing
	if _handset and not ringing:
		_handset.position = _handset_home
