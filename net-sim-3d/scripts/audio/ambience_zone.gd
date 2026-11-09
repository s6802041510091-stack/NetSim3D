class_name AmbienceZone
extends AudioStreamPlayer

## One layer of background sound for a room (air conditioner, computer fans,
## the outside through the windows). It fades to `inside_db` while the camera
## is inside one of `zones` (world-space boxes) and to `outside_db` elsewhere,
## so walls seem to keep each room's sound in. The stream should loop.

@export var zones: Array[AABB] = []
@export var inside_db := -16.0
@export var outside_db := -60.0
## Seconds to fade fully in or out.
@export var fade_time := 1.0

const SILENT_DB := -60.0


func _ready() -> void:
	if bus == &"Master":
		bus = &"Sound"
	volume_db = SILENT_DB
	play()


func _exit_tree() -> void:
	stop() # a looping playback would keep the stream alive at quit
	stream = null


func _process(delta: float) -> void:
	var target := outside_db
	var camera := get_viewport().get_camera_3d()
	if camera:
		for zone in zones:
			if zone.has_point(camera.global_position):
				target = inside_db
				break
	volume_db = move_toward(volume_db, target, absf(inside_db - SILENT_DB) * delta / fade_time)


## True while the camera is in one of this layer's rooms (tests).
func is_inside() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	for zone in zones:
		if zone.has_point(camera.global_position):
			return true
	return false
