class_name NpcCharacter
extends CharacterBody3D

## A MakeHuman NPC that can sit at a desk and turn to look at the player.
## The character models have no animations, so the seated pose and the
## look-at turn are set on the skeleton bones in code (rotations applied in
## skeleton space, parents before children).

## Sit on the chair this node stands on (feet forward under the desk).
@export var seated := false
## How far the whole model drops to put the pelvis on the seat, in metres.
@export var seat_drop := 0.41
## Turning to the player: largest upper-body yaw (degrees) and how long it takes.
@export var max_turn_degrees := 75.0
@export var turn_time := 0.45

var skeleton: Skeleton3D
var turn_amount := 0.0 # Current upper-body yaw (radians).
var _base_pose := {} # bone index -> local rotation of the seated/standing pose
var _turn_tween: Tween

## Spine-to-head chain and the share of the turn each bone takes.
const TURN_CHAIN := {"spine03": 0.25, "spine01": 0.3, "neck01": 0.2, "head": 0.25}


func _ready() -> void:
	var found := find_children("*", "Skeleton3D", true, false)
	skeleton = found[0] as Skeleton3D if not found.is_empty() else null
	if skeleton == null:
		return
	if seated:
		sit()
	_store_base_pose()


## Puts the character in a seated, typing pose.
func sit() -> void:
	seated = true
	var visual := get_node_or_null("Visual") as Node3D
	if visual:
		visual.position.y = -seat_drop
	for side in ["L", "R"]:
		_rotate_global("upperleg01." + side, Vector3.RIGHT, deg_to_rad(-88.0))
		_rotate_global("lowerleg01." + side, Vector3.RIGHT, deg_to_rad(92.0))
		_rotate_global("foot." + side, Vector3.RIGHT, deg_to_rad(-8.0))
		# Arms down from the A-pose, elbows bent so the hands rest toward the desk.
		var sign := -1.0 if side == "L" else 1.0
		_rotate_global("upperarm01." + side, Vector3.BACK, deg_to_rad(42.0) * sign)
		_rotate_global("upperarm01." + side, Vector3.RIGHT, deg_to_rad(-18.0))
		_rotate_global("lowerarm01." + side, Vector3.RIGHT, deg_to_rad(-62.0))
		_rotate_global("lowerarm01." + side, Vector3.UP, deg_to_rad(16.0) * sign)


## Turns the upper body and head toward `target` (e.g. the player) and waits.
func turn_to(target: Node3D) -> void:
	if skeleton == null or target == null:
		return
	var to := global_transform.affine_inverse() * target.global_position
	# Model forward is +Z; yaw toward the target around the body's up axis.
	var yaw := atan2(to.x, to.z)
	var limit := deg_to_rad(max_turn_degrees)
	await _tween_turn(clampf(yaw, -limit, limit))


## Back to looking at the desk.
func turn_back() -> void:
	if skeleton == null:
		return
	await _tween_turn(0.0)


func _tween_turn(target_yaw: float) -> void:
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_method(_apply_turn, turn_amount, target_yaw, turn_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _turn_tween.finished


func _apply_turn(yaw: float) -> void:
	turn_amount = yaw
	for bone in _base_pose:
		skeleton.set_bone_pose_rotation(bone, _base_pose[bone])
	for bone_name: String in TURN_CHAIN:
		_rotate_global(bone_name, Vector3.UP, yaw * TURN_CHAIN[bone_name])


func _store_base_pose() -> void:
	for bone_name: String in TURN_CHAIN:
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			_base_pose[bone] = skeleton.get_bone_pose_rotation(bone)


## Rotates a bone by `angle` around `axis` given in skeleton space (Y up,
## +Z forward, +X the character's left), keeping its children attached.
func _rotate_global(bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var parent := skeleton.get_bone_parent(bone)
	var global_basis := skeleton.get_bone_global_pose(bone).basis
	var wanted := Basis(axis.normalized(), angle) * global_basis
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * wanted).orthonormalized().get_rotation_quaternion())
