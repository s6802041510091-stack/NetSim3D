class_name CleanerCharacter
extends StudentCharacter

## The school housekeeper. She uses the student locomotion, doors and
## avoidance; StudentLife gives her a cleaning schedule instead of student
## activities. Steps marked `mop` are walked slowly while swinging the
## approved mop side to side in front of her; otherwise she carries it upright
## at her right side. Both hands grip the handle by arm IK.
const MOP_SCENE := preload("res://assets/models/cleaner/cleaner_mop.glb")
const MOP_SPEED := 0.22
const SWING_TIME := 3.4 # seconds per left-right-left swing: calm, like her steps
const SWING_WIDTH := .22 # metres the mop head moves to each side
## Grip heights along the handle, measured from the mop head (model units).
const UPPER_GRIP := 1.3
const LOWER_GRIP := 1.02

var mop: Node3D
var _mop_blend := 0.0
var _swing_phase := 0.0

func _ready() -> void:
	super._ready()
	mop = MOP_SCENE.instantiate()
	mop.name = "Mop"
	add_child(mop)
	_pose_mop(false)

func is_mopping() -> bool:
	return not hidden and bool(current_step().get("mop", false)) and phase in ["walk", "turn"]

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_mopping():
		_swing_phase += delta * TAU / SWING_TIME

func _apply_animation_pose(far := false) -> void:
	super._apply_animation_pose(far)
	_pose_mop(not far)

## Places the mop in body space, then the hands on its handle.
func _pose_mop(with_arms: bool) -> void:
	if mop == null or skeleton == null:
		return
	_mop_blend = move_toward(_mop_blend, 1.0 if is_mopping() else 0.0, .08)
	var m := smoothstep(0.0, 1.0, _mop_blend)
	var sway := sin(_swing_phase) * SWING_WIDTH * m
	# Body space: +Z forward, +X her left. Mopping: head on the floor ahead,
	# swinging; carrying: upright at her right side, head just off the floor.
	var head := Vector3(-.3, .1, .12).lerp(Vector3(sway, 0.0, .6), m)
	var anchor := Vector3(-.26, 1.3, .14).lerp(Vector3(-.05 + sway * .12, 1.05, .25), m)
	var up := (anchor - head).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < .01:
		side = Vector3.RIGHT
	var front := side.cross(up).normalized()
	mop.transform = Transform3D(Basis(side, up, front), head)
	if not with_arms:
		return
	var to_skeleton := skeleton.global_transform.affine_inverse() * global_transform
	var axis := (to_skeleton.basis * up).normalized()
	# Carrying, she holds it lower down, arm relaxed at her side.
	var upper := to_skeleton * (head + up * lerpf(.95, UPPER_GRIP, m))
	var lower := to_skeleton * (head + up * lerpf(.75, LOWER_GRIP, m))
	# Right hand on top, left hand lower; fingers wrap across the handle.
	_grip("R", upper, axis, Vector3(-.5, -.6, -.2), Vector3(1, 0, 0), 1.0)
	if m > .4:
		_grip("L", lower, axis, Vector3(.5, -.7, -.1), Vector3(-1, 0, 0), -1.0)
	# Eyes on the floor she is mopping, following the mop head a little from
	# side to side; carrying, just a slight look down ahead of her feet.
	_rotate_global("neck01", Vector3.RIGHT, lerpf(.08, .38, m))
	_rotate_global("head", Vector3.RIGHT, lerpf(.04, .22, m))
	_rotate_global("neck01", Vector3.UP, sway * .9)

## Fingers point across the handle, thumb side up along it, so the palm faces
## her body and the handle lies against the palm from the front; the fingers
## then wrap round behind it. `wrap` is the turn direction about the handle
## that curls these fingers back toward her (+1 right hand, -1 left hand).
func _grip(side: String, grip: Vector3, axis: Vector3, elbow_hint: Vector3, across: Vector3, wrap: float) -> void:
	var dir := (across - axis * across.dot(axis)).normalized()
	var back := axis.cross(dir).normalized() * wrap # from the palm toward her body
	_place_hand(side, grip - dir * .06 - back * .035, elbow_hint, dir, axis)
	for finger in [2, 3, 4, 5]:
		for joint in 3:
			_rotate_global("finger%d-%d.%s" % [finger, joint + 1, side], axis, wrap * deg_to_rad([45.0, 60.0, 40.0][joint]))

## She never sits, and her slimmer skirt would show the seated-thigh fix
## through its back while she walks.
func _sits() -> bool:
	return false
