class_name ObjectiveMarker
extends Node3D

## A gold arrow that floats above the current objective (an NPC, a computer, a
## device) so students always know where to go next. It bobs, turns slowly and
## is drawn on top of walls, so it can be followed from another room.
## It hides itself when the camera is very close (e.g. sitting at the computer).
## Missions call point_at(target) / clear().

const GOLD := Color(1.0, 0.76, 0.12)
const BOB_HEIGHT := 0.08
const BOB_SPEED := 2.6
const SPIN_SPEED := 1.4
## Closer than this (camera to arrow, metres) the arrow is hidden.
const HIDE_DISTANCE := 1.4
## Size follows the distance (playtest 2026-11-24): small close by, so it does
## not cover the person or device, and bigger far away so it can still be
## found from another room. Scale 1 at SCALE_REF metres, clamped.
const SCALE_REF := 6.0
const SCALE_MIN := 0.45
const SCALE_MAX := 2.6
## How fast the size catches up (per second), so it does not jump.
const SCALE_EASE := 6.0

var target: Node3D
## Where the arrow tip sits, relative to the target's origin (or the point given).
var offset := Vector3(0, 2.2, 0)
var _point := Vector3.ZERO
var _use_point := false
var _time := 0.0
var _arrow: Node3D
var _scale := 0.0


func _ready() -> void:
	top_level = true
	_arrow = Node3D.new()
	_arrow.name = "Arrow"
	add_child(_arrow)
	var material := StandardMaterial3D.new()
	material.albedo_color = GOLD
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 0.9
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 10
	# Arrow head (cone pointing down) with the tip at the node's origin.
	var head := MeshInstance3D.new()
	head.name = "Head"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.13
	cone.height = 0.24
	cone.radial_segments = 16
	head.mesh = cone
	head.material_override = material
	head.rotation_degrees.x = 180.0
	head.position.y = 0.12
	_arrow.add_child(head)
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var tube := CylinderMesh.new()
	tube.top_radius = 0.045
	tube.bottom_radius = 0.045
	tube.height = 0.26
	tube.radial_segments = 12
	shaft.mesh = tube
	shaft.material_override = material
	shaft.position.y = 0.37
	_arrow.add_child(shaft)
	for part: GeometryInstance3D in [head, shaft]:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Point at a node; the tip floats `height` metres above its origin.
func point_at(node: Node3D, height: float = 2.2) -> void:
	target = node
	offset = Vector3(0, height, 0)
	_use_point = false
	visible = target != null


## Point at a fixed world position (the tip sits `height` metres above it).
func point_at_position(world_position: Vector3, height: float = 0.35) -> void:
	target = null
	_point = world_position + Vector3(0, height, 0)
	_use_point = true
	visible = true


func clear() -> void:
	target = null
	_use_point = false
	visible = false


func is_active() -> bool:
	return _use_point or (target != null and is_instance_valid(target))


func tip_position() -> Vector3:
	if _use_point:
		return _point
	if target != null and is_instance_valid(target):
		return target.global_position + offset
	return global_position


func _process(delta: float) -> void:
	if not is_active():
		visible = false
		_scale = 0.0
		return
	_time += delta
	var camera := get_viewport().get_camera_3d()
	var tip := tip_position()
	var distance := camera.global_position.distance_to(tip) if camera else SCALE_REF
	var wanted := size_for_distance(distance)
	# First frame after (re)appearing: take the size at once.
	_scale = wanted if _scale <= 0.0 else lerpf(_scale, wanted, minf(1.0, SCALE_EASE * delta))
	_arrow.scale = Vector3.ONE * _scale
	# The tip stays on the target; the bob grows with the arrow.
	global_position = tip + Vector3(0, BOB_HEIGHT * _scale * (0.5 + 0.5 * sin(_time * BOB_SPEED)), 0)
	_arrow.rotation.y += SPIN_SPEED * delta
	visible = camera == null or distance > HIDE_DISTANCE
	if not visible:
		_scale = 0.0


## Arrow scale for a camera distance in metres.
static func size_for_distance(distance: float) -> float:
	return clampf(distance / SCALE_REF, SCALE_MIN, SCALE_MAX)
