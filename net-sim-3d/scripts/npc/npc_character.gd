class_name NpcCharacter
extends CharacterBody3D

## A MakeHuman NPC that can sit at a desk, work at the computer and turn to
## look at the player. The character models have no animations, so the seated
## pose, the typing and the look-at turn are set on the skeleton bones in code
## (rotations applied in skeleton space, parents before children).

## Sit on the chair this node stands on (feet forward under the desk).
@export var seated := false
## How far the whole model drops to put the pelvis on the seat, in metres.
@export var seat_drop := 0.41
## How far the body slides forward on the seat (toward the desk), in metres.
@export var seat_forward := 0.0
## Seated forward lean of the upper body, in degrees (the head stays up).
@export var lean_degrees := 0.0
## Where the wrists go when seated: left hand on the keyboard, right hand on the
## mouse, and where the right hand types when it leaves the mouse.
## Left empty = the arms just rest toward the desk.
@export_node_path("Node3D") var left_hand_target: NodePath
@export_node_path("Node3D") var right_hand_target: NodePath
@export_node_path("Node3D") var right_typing_target: NodePath
## Seated with hand targets: keep typing and using the mouse while not talking.
@export var work_at_desk := true
## Turning to the player: largest yaw (degrees) and how long it takes.
## Seated characters turn only the neck and head, so the hands stay at the desk.
@export var max_turn_degrees := 75.0
@export var turn_time := 0.45

var skeleton: Skeleton3D
var turn_amount := 0.0 # Current look yaw (radians).
var turn_pitch := 0.0 # Current look pitch (radians, + = up).
## True from turn_to until turn_back has finished: the hands stop working.
var talking := false
var _base_pose := {} # bone index -> local rotation of the seated/standing pose
var _turn_tween: Tween
var _turn_token := 0

## Bones that turn toward the player and the share of the yaw each one takes.
const BODY_TURN_CHAIN := {"spine03": 0.25, "spine01": 0.3, "neck01": 0.2, "head": 0.25}
const HEAD_TURN_CHAIN := {"neck01": 0.3, "neck02": 0.2, "neck03": 0.2, "head": 0.3}
## Looking up/down at the player's eyes.
const PITCH_CHAIN := {"neck01": 0.4, "head": 0.6}
const HEAD_TURN_LIMIT := 70.0
const PITCH_LIMIT_UP := 25.0
const PITCH_LIMIT_DOWN := 20.0
## Seconds to finish the keystroke before turning to talk.
const PAUSE_BEFORE_TURN := 0.2

## Hand pose on a target, in skeleton space (+X = the character's left, +Z forward):
## where the fingers point, where the elbow bends, which way the thumb faces,
## how much the four fingers close together (0-1) and curl (degrees per joint).
## The model's fingers are already bent ~26 degrees at rest, so a negative first
## curl straightens them: knuckles stay ~2.5 cm over the keys / on the mouse's
## back and only the fingertips reach down (tools/capture_supervisor_pose.gd
## prints the heights).
const HAND_POSE := {
	"L": {"dir": Vector3(-0.12, -0.09, 1.0), "elbow": Vector3(0.45, -1.0, -0.25), "thumb": Vector3(-1, 0, 0),
		"close": 0.3, "curl": [-22.0, 8.0, 8.0]},
	"R_mouse": {"dir": Vector3(0.03, -0.05, 1.0), "elbow": Vector3(-0.45, -1.0, -0.25), "thumb": Vector3(1, 0, 0),
		"close": 0.65, "curl": [-18.0, 16.0, 18.0]},
	"R_keys": {"dir": Vector3(0.2, -0.09, 1.0), "elbow": Vector3(-0.45, -1.0, -0.25), "thumb": Vector3(1, 0, 0),
		"close": 0.3, "curl": [-22.0, 8.0, 8.0]},
}

# --- Working at the desk -----------------------------------------------------
## Seconds for the right hand to move between the mouse and the keyboard.
const TRAVEL_TIME := 0.45
const TRAVEL_LIFT := 0.05
## One key press (seconds) and how far a pressing finger bends (degrees).
const TAP_TIME := 0.16
const TAP_CURL := 5.0 # fingertip ~0.8 cm down, about a key's travel
const TAP_JOINT_SHARE := [1.0, 0.5, 0.3]
const PRESS_DIP := 0.0015 # the whole hand dips this much (m) on a press
## Only animate while the camera is this close (metres), this many times a second.
const WORK_RANGE := 14.0
const WORK_FPS := 30.0

var _hand_goals := {} # "L" / "R_mouse" / "R_keys" -> wrist position in skeleton space
var _arm_rest := {} # bone -> local rotation of the arms before the hands are placed
var _right_on_keys := false
var _travel := -1.0 # 0..1 while the right hand moves, otherwise -1
var _hold := 0.0 # seconds left before the right hand moves again
var _clock := 0.0 # animation time; stops while talking
var _activity := 1.0 # 1 = working, 0 = still (talking)
var _next_tap := 0.0
var _since_update := 0.0
var _taps := {"L": [0.0, 0.0, 0.0, 0.0], "R": [0.0, 0.0, 0.0, 0.0]} # time left per finger 2-5
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var found := find_children("*", "Skeleton3D", true, false)
	skeleton = found[0] as Skeleton3D if not found.is_empty() else null
	set_process(false)
	if skeleton == null:
		return
	if seated:
		sit()
	_store_base_pose()
	set_process(not _arm_rest.is_empty())


## Puts the character in a seated pose, hands on the keyboard and mouse when
## there are targets for them.
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
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var paths := {"L": left_hand_target, "R_mouse": right_hand_target, "R_keys": right_typing_target}
	for key: String in paths:
		var path: NodePath = paths[key]
		var node: Node3D = null if path.is_empty() else get_node_or_null(path) as Node3D
		if node:
			_hand_goals[key] = to_skeleton * node.global_position
	for side in ["L", "R"]:
		if _hand_goals.has("L" if side == "L" else "R_mouse"):
			_store_arm_rest(side)
			continue
		# No target: arms down from the A-pose, elbows bent toward the desk.
		var sign := -1.0 if side == "L" else 1.0
		_rotate_global("upperarm01." + side, Vector3.BACK, deg_to_rad(42.0) * sign)
		_rotate_global("upperarm01." + side, Vector3.RIGHT, deg_to_rad(-18.0))
		_rotate_global("lowerarm01." + side, Vector3.RIGHT, deg_to_rad(-62.0))
		_rotate_global("lowerarm01." + side, Vector3.UP, deg_to_rad(16.0) * sign)
	_rng.randomize()
	_hold = _rng.randf_range(1.5, 4.0)
	_update_hands()


## Looks at `target` (e.g. the player): stops working, then turns the head
## (seated) or the upper body (standing) and waits until the turn is done.
func turn_to(target: Node3D) -> void:
	if skeleton == null or target == null:
		return
	talking = true
	_turn_token += 1
	var token := _turn_token
	if not _arm_rest.is_empty():
		await get_tree().create_timer(PAUSE_BEFORE_TURN).timeout
		if token != _turn_token:
			return
	# Look at the eyes when the target has a camera (the player), else its origin.
	var point := target.global_position
	var eyes: Variant = target.get("camera")
	if eyes is Node3D:
		point = (eyes as Node3D).global_position
	var from := global_position
	var head := skeleton.find_bone("head")
	if head >= 0:
		from = skeleton.global_transform * _bone_pos(head)
	var to := global_transform.basis.inverse() * (point - from)
	# Model forward is +Z; yaw toward the target around the body's up axis.
	var yaw_limit := deg_to_rad(minf(max_turn_degrees, HEAD_TURN_LIMIT) if seated else max_turn_degrees)
	var yaw := clampf(atan2(to.x, to.z), -yaw_limit, yaw_limit)
	var pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), deg_to_rad(-PITCH_LIMIT_DOWN), deg_to_rad(PITCH_LIMIT_UP))
	await _tween_turn(Vector2(yaw, pitch))


## Back to looking at the desk, then back to work.
func turn_back() -> void:
	if skeleton == null:
		return
	_turn_token += 1
	var token := _turn_token
	await _tween_turn(Vector2.ZERO)
	if token == _turn_token:
		talking = false


func _tween_turn(target: Vector2) -> void:
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_method(_apply_turn, Vector2(turn_amount, turn_pitch), target, turn_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _turn_tween.finished


func _apply_turn(look: Vector2) -> void:
	turn_amount = look.x
	turn_pitch = look.y
	for bone in _base_pose:
		skeleton.set_bone_pose_rotation(bone, _base_pose[bone])
	var chain := _turn_chain()
	for bone_name: String in chain:
		_rotate_global(bone_name, Vector3.UP, look.x * chain[bone_name])
	# Around the turned left-right axis: rotating about +X tips the head down.
	var across := Basis(Vector3.UP, look.x) * Vector3.RIGHT
	for bone_name: String in PITCH_CHAIN:
		_rotate_global(bone_name, across, -look.y * PITCH_CHAIN[bone_name])


func _turn_chain() -> Dictionary:
	return HEAD_TURN_CHAIN if seated else BODY_TURN_CHAIN


func _store_base_pose() -> void:
	for bone_name: String in _turn_chain().keys() + PITCH_CHAIN.keys():
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			_base_pose[bone] = skeleton.get_bone_pose_rotation(bone)


# --- Working at the desk -----------------------------------------------------

func _process(delta: float) -> void:
	if not work_at_desk:
		return
	_since_update += delta
	if _since_update < 1.0 / WORK_FPS:
		return
	var step := minf(_since_update, 0.1)
	_since_update = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_to(global_position) > WORK_RANGE:
		return
	var was_still := _is_still()
	_step_work(step)
	if not (was_still and _is_still()):
		_update_hands()


## True when nothing is moving (talking, the last key press finished).
func _is_still() -> bool:
	if _activity > 0.0 or _travel >= 0.0:
		return false
	for side in _taps:
		for t: float in _taps[side]:
			if t > 0.0:
				return false
	return true


func _step_work(delta: float) -> void:
	_activity = move_toward(_activity, 0.0 if talking else 1.0, delta / PAUSE_BEFORE_TURN)
	_clock += delta * _activity
	for side in _taps:
		var taps: Array = _taps[side]
		for i in taps.size():
			taps[i] = maxf(taps[i] - delta, 0.0)
	# The right hand moves between the mouse and the keyboard; a move that has
	# started always finishes, a new one waits until the talk is over.
	if _travel >= 0.0:
		_travel += delta / TRAVEL_TIME
		if _travel >= 1.0:
			_travel = -1.0
			_right_on_keys = not _right_on_keys
			_hold = _rng.randf_range(3.0, 6.0) if _right_on_keys else _rng.randf_range(2.0, 4.5)
		return
	if talking:
		return
	if _hand_goals.has("R_mouse") and _hand_goals.has("R_keys"):
		_hold -= delta
		if _hold <= 0.0:
			_travel = 0.0
			return
	_next_tap -= delta
	if _next_tap > 0.0:
		return
	if _right_on_keys or not _hand_goals.has("R_mouse"):
		# Typing: quick presses from either hand, now and then a short pause.
		var side := "L" if _rng.randf() < 0.5 or not _hand_goals.has("R_keys") else "R"
		_taps[side][_rng.randi_range(0, 3)] = TAP_TIME
		_next_tap = _rng.randf_range(0.07, 0.2)
		if _rng.randf() < 0.06:
			_next_tap += _rng.randf_range(0.4, 0.9)
	else:
		# Using the mouse: a click with the index finger now and then.
		_taps["R"][0] = TAP_TIME
		_next_tap = _rng.randf_range(0.8, 2.5)


## 0 = right hand on the mouse, 1 = on the keyboard (eased while moving).
func _keys_blend() -> float:
	var from := 1.0 if _right_on_keys else 0.0
	if _travel < 0.0:
		return from
	return lerpf(from, 1.0 - from, smoothstep(0.0, 1.0, _travel))


## How far each finger 2-5 of `side` is pressed right now (0-1).
func _presses(side: String) -> Array:
	var out := []
	for t: float in _taps[side]:
		out.append(sin(PI * (1.0 - t / TAP_TIME)) if t > 0.0 else 0.0)
	return out


func _update_hands() -> void:
	for bone in _arm_rest:
		skeleton.set_bone_pose_rotation(bone, _arm_rest[bone])
	var drift := Vector3(sin(_clock * 0.7) * 0.006, 0, sin(_clock * 0.45) * 0.004)
	if _hand_goals.has("L"):
		var presses := _presses("L")
		var goal: Vector3 = _hand_goals["L"] + drift + Vector3.DOWN * PRESS_DIP * float(presses.max())
		_pose_hand("L", goal, HAND_POSE["L"], HAND_POSE["L"], 0.0, presses)
	if _hand_goals.has("R_mouse"):
		var keys := _keys_blend()
		var presses := _presses("R")
		var mouse_move := Vector3(sin(_clock * 1.7) * 0.008 + sin(_clock * 0.53) * 0.01, 0, sin(_clock * 1.1 + 1.0) * 0.01)
		var on_mouse: Vector3 = _hand_goals["R_mouse"] + mouse_move
		var on_keys: Vector3 = _hand_goals.get("R_keys", on_mouse) + drift + Vector3.DOWN * PRESS_DIP * float(presses.max())
		var lift := sin(PI * _travel) * TRAVEL_LIFT if _travel >= 0.0 else 0.0
		_pose_hand("R", on_mouse.lerp(on_keys, keys) + Vector3.UP * lift,
			HAND_POSE["R_mouse"], HAND_POSE["R_keys"], keys, presses)


## Places hand `side` at `goal` with a pose blended from `a` to `b` by `t`.
func _pose_hand(side: String, goal: Vector3, a: Dictionary, b: Dictionary, t: float, presses: Array) -> void:
	var dir: Vector3 = (a["dir"] as Vector3).lerp(b["dir"], t)
	var elbow: Vector3 = (a["elbow"] as Vector3).lerp(b["elbow"], t)
	_place_hand(side, goal, elbow, dir, a["thumb"])
	var curl := []
	for j in 3:
		curl.append(lerpf(a["curl"][j], b["curl"][j], t))
	_shape_fingers(side, dir, a["thumb"], lerpf(a["close"], b["close"], t), curl, presses)


func _store_arm_rest(side: String) -> void:
	var stack := [skeleton.find_bone("upperarm01." + side)]
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		if bone < 0:
			continue
		_arm_rest[bone] = skeleton.get_bone_pose_rotation(bone)
		stack.append_array(Array(skeleton.get_bone_children(bone)))


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
## curls each joint down by `curl` degrees (base, middle, tip), plus the key
## press of each finger (`presses`, 0-1 for fingers 2-5).
func _shape_fingers(side: String, dir: Vector3, thumb: Vector3, close: float, curl: Array, presses: Array = []) -> void:
	var hand := dir.normalized()
	var palm := hand.cross(thumb).normalized()
	var bend_axis := hand.cross(Vector3.DOWN).normalized()
	for finger in [2, 3, 4, 5]:
		var base := skeleton.find_bone("finger%d-1.%s" % [finger, side])
		var next := skeleton.find_bone("finger%d-2.%s" % [finger, side])
		if base >= 0 and next >= 0:
			_roll(base, palm, _bone_pos(next) - _bone_pos(base), hand, close)
		var press: float = presses[finger - 2] if presses.size() == 4 else 0.0
		for joint in 3:
			var angle: float = curl[joint] + TAP_CURL * press * TAP_JOINT_SHARE[joint]
			_rotate_global("finger%d-%d.%s" % [finger, joint + 1, side], bend_axis, deg_to_rad(angle))


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
