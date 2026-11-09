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
## How far the body slides forward on the seat (toward the desk), in metres.
@export var seat_forward := 0.0
## Seated forward lean of the upper body, in degrees (the head stays up).
@export var lean_degrees := 0.0
## Where the wrists go when seated, e.g. markers on the keyboard and the mouse.
## Left empty = the arms just rest toward the desk.
@export_node_path("Node3D") var left_hand_target: NodePath
@export_node_path("Node3D") var right_hand_target: NodePath
## Turning to the player: largest upper-body yaw (degrees) and how long it takes.
@export var max_turn_degrees := 75.0
@export var turn_time := 0.45

var skeleton: Skeleton3D
var turn_amount := 0.0 # Current upper-body yaw (radians).
var _base_pose := {} # bone index -> local rotation of the seated/standing pose
var _turn_tween: Tween

## Spine-to-head chain and the share of the turn each bone takes.
const TURN_CHAIN := {"spine03": 0.25, "spine01": 0.3, "neck01": 0.2, "head": 0.25}
## Hand pose on a target, in skeleton space (+X = the character's left, +Z forward):
## where the fingers point, where the elbow bends, which way the thumb faces,
## how much the four fingers close together (0-1) and curl (degrees per joint).
## Left hand types (fingers a little inward and down), right hand holds the mouse.
const HAND_POSE := {
	"L": {"dir": Vector3(-0.12, -0.2, 1.0), "elbow": Vector3(0.45, -1.0, -0.25), "thumb": Vector3(-1, 0, 0),
		"close": 0.3, "curl": [0.0, 8.0, 5.0]},
	"R": {"dir": Vector3(0.03, -0.08, 1.0), "elbow": Vector3(-0.45, -1.0, -0.25), "thumb": Vector3(1, 0, 0),
		"close": 0.65, "curl": [18.0, 25.0, 15.0]},
}


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
		visual.position.z = seat_forward
	if lean_degrees != 0.0:
		_rotate_global("spine05", Vector3.RIGHT, deg_to_rad(lean_degrees))
		_rotate_global("neck01", Vector3.RIGHT, deg_to_rad(-lean_degrees * 0.7))
	for side in ["L", "R"]:
		_rotate_global("upperleg01." + side, Vector3.RIGHT, deg_to_rad(-88.0))
		_rotate_global("lowerleg01." + side, Vector3.RIGHT, deg_to_rad(92.0))
		_rotate_global("foot." + side, Vector3.RIGHT, deg_to_rad(-8.0))
		var target := get_node_or_null(left_hand_target if side == "L" else right_hand_target) as Node3D
		if target:
			var pose: Dictionary = HAND_POSE[side]
			_place_hand(side, skeleton.global_transform.affine_inverse() * target.global_position,
				pose["elbow"], pose["dir"], pose["thumb"])
			_shape_fingers(side, pose["dir"], pose["thumb"], pose["close"], pose["curl"])
			continue
		# No target: arms down from the A-pose, elbows bent toward the desk.
		var sign := -1.0 if side == "L" else 1.0
		_rotate_global("upperarm01." + side, Vector3.BACK, deg_to_rad(42.0) * sign)
		_rotate_global("upperarm01." + side, Vector3.RIGHT, deg_to_rad(-18.0))
		_rotate_global("lowerarm01." + side, Vector3.RIGHT, deg_to_rad(-62.0))
		_rotate_global("lowerarm01." + side, Vector3.UP, deg_to_rad(16.0) * sign)


## Puts the wrist of arm `side` on `goal` (skeleton space): the upper arm and
## forearm bend like a hinge with the elbow toward `elbow_hint`, the forearm
## twists so the palm faces down (thumb toward `thumb`), and the hand points along `dir`.
func _place_hand(side: String, goal: Vector3, elbow_hint: Vector3, dir: Vector3, thumb: Vector3) -> void:
	var upper := skeleton.find_bone("upperarm01." + side)
	var lower := skeleton.find_bone("lowerarm01." + side)
	var twist := skeleton.find_bone("lowerarm02." + side)
	var wrist := skeleton.find_bone("wrist." + side)
	var middle := skeleton.find_bone("finger3-1." + side)
	var index := skeleton.find_bone("finger2-1." + side)
	var little := skeleton.find_bone("finger5-1." + side)
	if [upper, lower, twist, wrist, middle, index, little].has(-1):
		return
	var shoulder := _bone_pos(upper)
	var upper_len := shoulder.distance_to(_bone_pos(lower))
	var fore_len := _bone_pos(lower).distance_to(_bone_pos(wrist))
	var reach := goal - shoulder
	var dist := clampf(reach.length(), absf(upper_len - fore_len) + 0.01, upper_len + fore_len - 0.005)
	var n := reach.normalized()
	var wrist_goal := shoulder + n * dist
	var along := (upper_len * upper_len - fore_len * fore_len + dist * dist) / (2.0 * dist)
	var out := (elbow_hint - n * elbow_hint.dot(n)).normalized()
	var elbow := shoulder + n * along + out * sqrt(maxf(upper_len * upper_len - along * along, 0.0))
	# Upper arm to the elbow, rolled so the elbow's hinge bends toward the wrist goal.
	_aim(upper, _bone_pos(lower) - shoulder, elbow - shoulder)
	var arm := (elbow - shoulder).normalized()
	_roll(upper, arm, arm.cross(_bone_pos(wrist) - _bone_pos(lower)), arm.cross(wrist_goal - elbow))
	_aim(lower, _bone_pos(wrist) - _bone_pos(lower), wrist_goal - _bone_pos(lower))
	# Palm down: twist the forearm, then point the hand and fix the last bit of roll.
	_roll(twist, (wrist_goal - elbow).normalized(), _bone_pos(index) - _bone_pos(little), thumb)
	_aim(wrist, _bone_pos(middle) - _bone_pos(wrist), dir)
	_roll(wrist, dir.normalized(), _bone_pos(index) - _bone_pos(little), thumb)


## Closes the spread fingers 2-5 toward the hand's direction (`close` 0-1) and
## curls each joint down by `curl` degrees (base, middle, tip).
func _shape_fingers(side: String, dir: Vector3, thumb: Vector3, close: float, curl: Array) -> void:
	var hand := dir.normalized()
	var palm := hand.cross(thumb).normalized()
	var bend_axis := hand.cross(Vector3.DOWN).normalized()
	for finger in [2, 3, 4, 5]:
		var base := skeleton.find_bone("finger%d-1.%s" % [finger, side])
		var next := skeleton.find_bone("finger%d-2.%s" % [finger, side])
		if base >= 0 and next >= 0:
			_roll(base, palm, _bone_pos(next) - _bone_pos(base), hand, close)
		for joint in 3:
			_rotate_global("finger%d-%d.%s" % [finger, joint + 1, side], bend_axis, deg_to_rad(curl[joint]))


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
	_rotate_bone(skeleton.find_bone(bone_name), axis, angle)


func _rotate_bone(bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or axis.length_squared() < 1e-10:
		return
	var parent := skeleton.get_bone_parent(bone)
	var global_basis := skeleton.get_bone_global_pose(bone).basis
	var wanted := Basis(axis.normalized(), angle) * global_basis
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * wanted).orthonormalized().get_rotation_quaternion())


func _bone_pos(bone: int) -> Vector3:
	return skeleton.get_bone_global_pose(bone).origin


## Turns `bone` the shortest way so the direction `from` points along `to`.
func _aim(bone: int, from: Vector3, to: Vector3) -> void:
	_rotate_bone(bone, from.cross(to).normalized(), from.angle_to(to))


## Rolls `bone` around `axis` so `from` lines up with `to` (both seen across the
## axis); `weight` < 1 turns only that share of the way.
func _roll(bone: int, axis: Vector3, from: Vector3, to: Vector3, weight := 1.0) -> void:
	var f := from - axis * from.dot(axis)
	var t := to - axis * to.dot(axis)
	if f.length_squared() < 1e-10 or t.length_squared() < 1e-10:
		return
	_rotate_bone(bone, axis, atan2(axis.dot(f.cross(t)), f.dot(t)) * weight)
