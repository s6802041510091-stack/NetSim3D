extends Node3D
class_name CrimpingTool
## NetLife3D - RJ-45 crimping tool (stage 2).
## The model is built closed; this script opens/closes the moving jaw around the pivot.
##   tool.set_open(1.0)        # fully open (handles apart)
##   tool.squeeze()            # animate closing -> emits squeezed, then re-opens
## The game decides what was crimped (e.g. a plug sitting at Crimp_Slot) and scores it.

signal squeezed            ## jaws fully closed (crimp / cut / strip happened)
signal released            ## jaws back open

@export_range(0.0, 30.0) var open_angle_deg := 16.0
@export var squeeze_time := 0.18
@export var release_time := 0.25

var _jaw: Node3D
var _amount := 1.0
var _busy := false


func _ready() -> void:
	_jaw = find_child("Jaw_Moving", true, false)
	set_open(1.0)


## 0 = closed, 1 = fully open
func set_open(amount: float) -> void:
	_amount = clampf(amount, 0.0, 1.0)
	# Blender +Y rotation becomes Godot rotation around -Z
	_jaw.rotation.z = -deg_to_rad(open_angle_deg) * _amount


func get_open() -> float:
	return _amount


func is_busy() -> bool:
	return _busy


func squeeze() -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_method(set_open, _amount, 0.0, squeeze_time).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): squeezed.emit())
	tw.tween_interval(0.08)
	tw.tween_method(set_open, 0.0, 1.0, release_time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_busy = false
		released.emit())


## Snap points: "Crimp_Slot" (8P die), "Cut_Point", "Strip_Point", "Hand_Grip".
## -Z of the slot node = direction the cable/plug goes in.
func get_point(point_name: String) -> Node3D:
	return find_child(point_name, true, false)
