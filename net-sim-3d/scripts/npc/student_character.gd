class_name StudentCharacter
extends NpcCharacter

## Ambient students reuse the approved MakeHuman rig/arm solver. Locomotion
## uses CharacterBody physics, not teleporting.
##
## A student follows a short plan of steps handed out by StudentLife (the
## corridor director). Step keys:
##   point    where to walk (world space)
##   via      true: pass through without stopping or turning
##   activity what to do on arrival (idle, window, shoes, chat, rest, inside...)
##   seconds  how long to stay
##   yaw/face facing on arrival: a fixed yaw, or a world point to look toward
##   bench    sit on this corridor bench (slot = offset along the bench)
##   anchor   the long stay of the plan; leaving it asks the director first
##   door     InteractiveDoor name; door_op "open"/"close" outside the door
##   hide     disappear on arrival (inside a room), reappear through the door
@export var student_id := ""
@export var stroll_speed := 0.8
@export var phase_offset := 0.0
## Hair colour variation for students that share a model with someone else.
@export var hair_tint := Color(1, 1, 1, 0)

const SIT_TIME := 1.7
const WALK_TURN_RATE := 2.1 # rad/s while walking
const FACE_RATE := 1.5 # rad/s turning on the spot
const ACCEL := 0.8 # m/s^2, both speeding up and slowing down
const VIA_RADIUS := 0.55
const CHAT_WAIT := 70.0 # how long to wait for a friend who is on the way

var manager: Node
var routine: Array[Dictionary] = []
var step_index := 0
var completed_loops := 0 # finished plans
var visits: Dictionary = {}
var activity := "idle"
var phase := "hold"
var hold_time := 0.0
var blocked_time := 0.0
var distance_walked := 0.0
var hidden := false
var chat_group := ""
var _elapsed := 0.0
var _pose_time := 0.0
var _pose_accum := 0.0
var _seat_blend := 0.0
var _bench_pose: Dictionary = {}
var _bench: StaticBody3D
var _approach := Vector3.ZERO
var _seat := Vector3.ZERO
var _drop := .37
var _chat_started := false
var _last_pose_far := false
var _last_seat_pose := -1.0
var _support: StudentPoseSupport
var _speed := 0.0
var _leaving := false
var _pending: Array[Dictionary] = []
var _door: InteractiveDoor
var _door_op := ""
var _closing := 0.0 # >0: still trying to shut the door behind us
var _retry := 0.0
var _look := 0.0
var _stuck := 0.0
var _yield_scale := 1.0

func _ready() -> void:
	super._ready()
	if skeleton == null:
		push_error("Student rig missing: " + student_id)
		return
	_apply_pose(_standing_pose())
	# Seated thighs fill the skirt opening; only for characters who sit.
	if _sits():
		StudentThighs.add_to(get_node("Visual"))
	_support = StudentPoseSupport.new()
	_support.setup(self)
	_phase = phase_offset
	_pose_time = phase_offset
	floor_snap_length = .15
	if hair_tint.a > 0:
		_tint_hair()
	set_process(true)
	set_physics_process(true)

func _tint_hair() -> void:
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name.begins_with("Hair"):
				var copy := mat.duplicate() as StandardMaterial3D
				var tint := Color(hair_tint.r, hair_tint.g, hair_tint.b)
				copy.albedo_color = copy.albedo_color * tint # keeps strand tone variation
				mi.set_surface_override_material(i, copy)

func start_routine(owner_node: Node, steps: Array[Dictionary]) -> void:
	manager = owner_node
	if seated:
		# Stand up first (when the way is clear), then follow the new plan.
		_pending = steps
		hold_time = 0
		_leaving = true
		return
	routine = steps
	step_index = 0
	_begin_step()

## Called by the director when a friend comes over to talk.
func join_chat(group: String, seconds: float) -> void:
	chat_group = group
	activity = "chat"
	hold_time = seconds
	_chat_started = false
	_elapsed = 0
	_leaving = false

func leave_chat(stay_seconds: float) -> void:
	chat_group = ""
	_chat_started = false
	activity = "rest" if seated else "idle"
	if stay_seconds > 0:
		hold_time = stay_seconds
		_leaving = false

func _begin_step() -> void:
	if routine.is_empty():
		return
	phase = "walk"
	activity = "walk"
	walking = true
	blocked = false
	_elapsed = 0
	blocked_time = 0
	_chat_started = false
	_leaving = false

func current_step() -> Dictionary:
	return routine[step_index] if not routine.is_empty() else {}

func is_anchored() -> bool:
	return phase == "hold" and bool(current_step().get("anchor", false))

## Walking, turning, opening doors, sitting down or standing up.
func is_moving() -> bool:
	return not hidden and not is_anchored()

func _physics_process(delta: float) -> void:
	if routine.is_empty() or skeleton == null:
		return
	_pose_time += delta
	if _closing > 0:
		_try_close(delta)
	match phase:
		"walk":
			_walk_physics(delta)
		"turn":
			velocity = Vector3.ZERO
			var yaw = _arrival_yaw()
			if yaw == null:
				_arrive()
			else:
				rotation.y = rotate_toward(rotation.y, yaw, FACE_RATE * delta)
				if absf(angle_difference(rotation.y, yaw)) < .03:
					_arrive()
		"sit", "stand":
			_seat_transition(delta)
		"door":
			velocity = Vector3.ZERO
			_door_physics(delta)
		"hold":
			velocity = Vector3.ZERO
			_hold_physics(delta)
	var moving := walking and not blocked and _speed > .05
	var pace: float = current_step().get("speed", stroll_speed) if not routine.is_empty() else stroll_speed
	_walk_blend = move_toward(_walk_blend, clampf(_speed / maxf(pace, .1), 0, 1) * clampf(pace / .6, .45, 1.0) if moving else 0.0, delta * 2.5)

func _arrival_yaw() -> Variant:
	var step := current_step()
	if step.has("face"):
		var to: Vector3 = step["face"] - global_position
		return atan2(to.x, to.z)
	if step.has("yaw"):
		return float(step["yaw"])
	return null

func _hold_physics(delta: float) -> void:
	if activity == "chat" and chat_group != "":
		var friend: StudentCharacter = manager.chat_partner(self)
		if friend and friend.activity == "chat" and friend.phase == "hold" and _together(friend):
			_chat_started = true
			friend._chat_started = true
			if not seated:
				var to := friend.global_position - global_position
				rotation.y = rotate_toward(rotation.y, atan2(to.x, to.z), delta * 1.2)
		# A rendezvous has a bounded wait, so a friend who never arrives
		# cannot strand this student. Once paired both finish their chat.
		if _chat_started:
			hold_time -= delta
		else:
			_elapsed += delta
			if _elapsed > CHAT_WAIT:
				hold_time = 0
	else:
		hold_time -= delta
	if hold_time > 0:
		return
	if not _leaving and current_step().get("anchor", false):
		var extra: float = manager.hold_extension(self)
		if extra > 0:
			hold_time = extra
			return
		_leaving = true
	if hidden:
		_door_op = "exit"
		_retry = 0
		_elapsed = 0
		phase = "door"
	elif seated:
		if _exit_clear():
			phase = "stand"
			_elapsed = 0
	else:
		_advance()

func _together(friend: StudentCharacter) -> bool:
	if seated or friend.seated:
		return seated and friend.seated and _bench == friend._bench
	return global_position.distance_to(friend.global_position) < 1.6

func _walk_physics(delta: float) -> void:
	var step := current_step()
	var target: Vector3 = step["point"]
	var to := target - global_position
	to.y = 0
	var dist := to.length()
	var via: bool = step.get("via", false)
	if via and dist < VIA_RADIUS:
		_advance() # keep walking: no stop, no turn on the spot
		return
	if not via and dist < .06:
		walking = false
		blocked = false
		_speed = 0
		velocity = Vector3.ZERO
		phase = "turn"
		return
	var direction := _avoid_people(to / dist)
	blocked = direction.length_squared() < .01
	if blocked:
		blocked_time += delta
		_speed = 0
		velocity = Vector3.ZERO
		if via and blocked_time > 10:
			_advance()
			return
	else:
		blocked_time = 0
		var yaw := atan2(direction.x, direction.z)
		var off := absf(angle_difference(rotation.y, yaw))
		rotation.y = rotate_toward(rotation.y, yaw, WALK_TURN_RATE * delta)
		var wanted: float = step.get("speed", stroll_speed)
		if not via:
			# Ease into the stop instead of braking at the last step.
			wanted = minf(wanted, sqrt(2.0 * ACCEL * .75 * dist) + .04)
		wanted *= _yield_scale
		if off > .9:
			wanted *= .3
		elif off > .4:
			wanted *= .65
		_speed = move_toward(_speed, wanted, ACCEL * delta) if wanted > _speed else move_toward(_speed, wanted, ACCEL * 2.0 * delta)
		var forward := Vector3(sin(rotation.y), 0, cos(rotation.y))
		velocity = forward.lerp(direction, .35).normalized() * _speed
	velocity.y = -.5
	var from := global_position
	move_and_slide()
	var travelled := Vector2(global_position.x - from.x, global_position.z - from.z).length()
	distance_walked += travelled
	_phase += travelled / STRIDE * PI
	# The gait stops if physical collision stopped the body.
	if travelled < .0001 and not blocked:
		blocked = true
	# Pinned by something solid (not the player, whom we wait for): give up
	# on a corner after a while, or settle where we are rather than stalling.
	_stuck = _stuck + delta if travelled < .002 and _speed > .05 else 0.0
	if _stuck > 5 and via:
		_stuck = 0
		_advance()
	elif _stuck > 5 and step.get("hide", false):
		_stuck = 0
		phase = "turn"
	elif _stuck > 15:
		_stuck = 0
		_speed = 0
		phase = "turn"

func _avoid_people(wanted: Vector3) -> Vector3:
	var steer := wanted
	_yield_scale = 1.0
	var people: Array[Node3D] = []
	people.assign(manager.people() if manager.has_method("people") else manager.students)
	if is_instance_valid(manager.player):
		people.append(manager.player)
	for other: Node3D in people:
		if other == self or (other is StudentCharacter and (other as StudentCharacter).hidden):
			continue
		var offset := other.global_position - global_position
		offset.y = 0
		var distance := offset.length()
		var still := other is StudentCharacter and not (other as StudentCharacter).is_moving()
		if other is StudentCharacter and not still and distance < 3.5:
			# Another walker: look where we both will be over the next two
			# seconds and step aside early instead of brushing shoulders.
			var other_v := (other as StudentCharacter).velocity
			other_v.y = 0
			var rel_v := other_v - wanted * maxf(_speed, .3)
			var t := clampf(-offset.dot(rel_v) / maxf(rel_v.length_squared(), .0001), 0.0, 2.0)
			var closest := offset + rel_v * t
			var gap := closest.length()
			# Catching up with someone going the same way: fall in behind
			# at their pace instead of squeezing past in the lane.
			var ahead_now := wanted.dot(offset)
			var their_pace := other_v.dot(wanted)
			if ahead_now > 0 and ahead_now < 1.6 and (offset - wanted * ahead_now).length() < .6 and their_pace > .45:
				_yield_scale = minf(_yield_scale, clampf(their_pace / maxf(_speed, .1) * clampf((ahead_now - .7) / .6, .3, 1.0), .1, 1.0))
				continue
			if gap < .8:
				var right := wanted.cross(Vector3.UP)
				var away := -signf(right.dot(closest))
				if absf(right.dot(closest)) < .05:
					away = 1.0 # dead ahead: both keep to their right
				steer += right * away * (1.3 * (1.0 - gap / .8)) * (1.15 - t * .4)
				if gap < .55 and t < 1.2:
					_yield_scale = minf(_yield_scale, .45)
		# Give settled people (standing, sitting) a wider berth than walkers.
		var reach := 1.4 if still else 1.15
		if distance < .001 or distance > reach:
			continue
		if still and chat_group != "" and other == manager.chat_partner(self):
			continue # the friend we are walking up to
		var ahead := wanted.dot(offset)
		var lateral := (offset - wanted * ahead).length()
		if ahead < -.10 or lateral > (.7 if still else .57):
			continue
		if other == manager.player:
			# Never push through the player: wait and resume when they move.
			if ahead > 0 and distance < .95:
				return Vector3.ZERO
			continue
		if ahead > .0 and lateral < .55:
			# Someone right in front: slow down and let the gap open.
			_yield_scale = minf(_yield_scale, clampf((distance - .55) / .5, .1, 1.0))
		if ahead > .0:
			# Pass on the side away from them.
			var own_right := wanted.cross(Vector3.UP)
			var side := 1.0 if own_right.dot(offset) <= 0 else -1.0
			if not still:
				side = 1.0 # two walkers both keep to their right
			steer += own_right * side * (1.4 * (1.0 - distance / reach))
			steer -= offset.normalized() * (.35 * (1.0 - distance / reach))
	return steer.normalized()

func _arrive() -> void:
	var step := current_step()
	activity = step.get("activity", "idle")
	visits[activity] = int(visits.get(activity, 0)) + 1
	hold_time = float(step.get("seconds", 0.0))
	_elapsed = 0
	_leaving = false
	if step.has("door_op"):
		_door = manager.door(step["door"])
		_door_op = step["door_op"]
		_retry = 0
		phase = "door"
		if _door == null:
			_advance()
		return
	if step.get("hide", false):
		_set_hidden(true)
		if step.has("door"):
			_closing = 6.0
	if step.has("bench"):
		_bench = manager.bench_for(step["bench"])
		if _bench:
			var slot: float = step.get("slot", 0.0)
			_approach = global_position
			_seat = _bench.global_position + _bench.global_basis.z * .05 + _bench.global_basis.x * slot
			_seat.y = global_position.y
			add_collision_exception_with(_bench)
			_walk_blend = 0
			(get_node("Visual") as Node3D).position.y = 0
			_apply_pose(_standing_pose())
			_support.capture_plants()
			_build_bench_pose()
			phase = "sit"
			# Corrective cloth shape is authored against the actual seated pose.
			global_position = _seat
			_seat_blend = 1
			_apply_animation_pose()
			_support.prepare_clothes()
			_seat_blend = 0
			global_position = _approach
			_apply_animation_pose()
			return
	phase = "hold"

# --- Doors -------------------------------------------------------------------

func _door_physics(delta: float) -> void:
	if _door == null:
		_advance()
		return
	var to := _door.get_doorway_center() - global_position
	if not hidden:
		rotation.y = rotate_toward(rotation.y, atan2(to.x, to.z), FACE_RATE * delta)
	_retry -= delta
	_elapsed += delta
	match _door_op:
		"open":
			if _door.is_open and not _door.is_moving:
				if _elapsed > .5:
					_advance()
			elif _retry <= 0 and not _door.is_moving:
				_door.set_open(true)
				_retry = .6
		"exit":
			if manager.room_busy(current_step()["door"], self):
				_elapsed = 0 # someone is coming through: wait inside
			elif _door.is_open and not _door.is_moving:
				if _spot_clear(global_position):
					_set_hidden(false)
					_advance() # walk back out through the doorway
			elif _retry <= 0 and not _door.is_moving:
				_door.set_open(true)
				_retry = .6
		"close":
			# Always shut it behind us, as people do with restroom doors.
			if _door.is_open and _elapsed < 4:
				if _retry <= 0 and not _door.is_moving:
					_door.set_open(false)
					_retry = .6
			elif not _door.is_moving and _elapsed > .6:
				_advance()

func _try_close(delta: float) -> void:
	_closing -= delta
	_retry -= delta
	if _door == null or not _door.is_open:
		_closing = 0
		return
	if _retry <= 0 and not _door.is_moving:
		if _door.set_open(false):
			_closing = 0
		_retry = .5


func _set_hidden(value: bool) -> void:
	hidden = value
	visible = not value
	collision_layer = 0 if value else 2
	collision_mask = 0 if value else 3
	velocity = Vector3.ZERO

func _spot_clear(at: Vector3) -> bool:
	var shape: CollisionShape3D = get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, at + shape.position)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

# --- Plans -------------------------------------------------------------------

func _advance() -> void:
	step_index += 1
	if step_index < routine.size():
		_begin_step()
		return
	completed_loops += 1
	step_index = 0
	if not _pending.is_empty():
		routine = _pending
		_pending = []
		_begin_step()
	elif manager and manager.has_method("plan_finished"):
		manager.plan_finished(self)
	else:
		_begin_step()

# --- Benches -----------------------------------------------------------------

func _build_bench_pose() -> void:
	_apply_pose(_standing_pose())
	var hip := skeleton.find_bone("upperleg01.L")
	# Account for the imported rig scale and origin, which vary per student.
	_drop = (skeleton.global_transform * _bone_pos(hip)).y - global_position.y - .56
	for side in ["L", "R"]:
		_rotate_global("upperleg01." + side, Vector3.RIGHT, deg_to_rad(-88))
		_rotate_global("lowerleg01." + side, Vector3.RIGHT, deg_to_rad(92))
		_rotate_global("foot." + side, Vector3.RIGHT, deg_to_rad(-5))
	_rotate_global("spine05", Vector3.RIGHT, deg_to_rad(7))
	_rotate_global("neck01", Vector3.RIGHT, deg_to_rad(-5))
	_bench_pose = _current_pose()
	_apply_pose(_standing_pose())

func _exit_clear() -> bool:
	return _spot_clear(_approach)

func _seat_transition(delta: float) -> void:
	var next_elapsed := _elapsed + delta
	var t := smoothstep(0.0, 1.0, minf(1, next_elapsed / SIT_TIME))
	var blend := t if phase == "sit" else 1.0 - t
	var next_position := _approach.lerp(_seat,blend)
	# Check the swept capsule throughout the transition, not only its final
	# exit point: someone may step into the space after the stand-up starts.
	var shape:CollisionShape3D=get_node("CollisionShape3D")
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape.shape
	query.transform=Transform3D(Basis.IDENTITY,global_position+shape.position)
	query.motion=next_position-global_position
	query.collision_mask=2
	query.exclude=[get_rid()]
	if get_world_3d().direct_space_state.cast_motion(query)[0]<.999:
		return
	query.transform.origin=next_position+shape.position
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		return
	_elapsed=next_elapsed
	_seat_blend=blend
	global_position=next_position
	velocity = Vector3.ZERO
	if _elapsed >= SIT_TIME:
		if phase == "sit":
			seated = true
			phase = "hold"
		else:
			seated = false
			remove_collision_exception_with(_bench)
			_bench = null
			_advance()

# --- Posing ------------------------------------------------------------------

func _process(delta: float) -> void:
	if skeleton == null or hidden:
		return
	_pose_accum += delta
	if _pose_accum < .05:
		return # 20Hz near-camera skeletal posing; movement stays on physics ticks.
	_pose_accum = 0
	var camera := get_viewport().get_camera_3d()
	var far := camera != null and camera.global_position.distance_to(global_position) > 24
	if far and _last_pose_far and is_equal_approx(_last_seat_pose, _seat_blend):
		return
	_last_pose_far = far
	_last_seat_pose = _seat_blend
	_apply_animation_pose(far)

func _apply_animation_pose(far := false) -> void:
	var stand := _standing_pose()
	_apply_pose(stand)
	var visual: Node3D = get_node("Visual")
	visual.position.y = -_drop * _seat_blend
	if _seat_blend > .001:
		for bone in _bench_pose:
			skeleton.set_bone_pose_rotation(bone, (stand[bone] as Quaternion).slerp(_bench_pose[bone], _seat_blend))
		# Feet stay at their floor contacts while the pelvis travels to/from
		# the seat. Hands follow the resulting knees without twisting shoulders.
		_support.plant_feet()
		_support.settle_planted_feet()
		_support.rest_hands(smoothstep(.12, .85, _seat_blend))
		if phase == "sit" or phase == "stand":
			_rotate_global("spine05",Vector3.RIGHT,sin(_seat_blend*PI)*.16)
	else:
		_pose_walk()
		var soles := _support.sole_heights()
		var floor_y := minf(soles["L"],soles["R"])
		if is_finite(floor_y):visual.position.y += .003 - floor_y
	_support.blend_clothes(_seat_blend)
	if far:
		return
	var breath := sin(_pose_time * 1.7) * .008
	_rotate_global("spine03", Vector3.RIGHT, breath)
	var settled := phase == "hold"
	_look = lerp_angle(_look, _look_target() if settled else 0.0, .1)
	_rotate_global("neck01", Vector3.UP, _look * .55)
	_rotate_global("head", Vector3.UP, _look * .45)
	if activity == "chat" and _chat_started:
		var speaking:bool=manager.is_speaking(self)
		_rotate_global("neck01", Vector3.RIGHT, sin(_pose_time * 1.6) * (.025 if speaking else .012))
		var gesture := maxf(0, sin(_pose_time * 1.3)) * ((.40 if not seated else .18) if speaking else .03)
		_rotate_global("lowerarm01.R", Vector3.RIGHT, -gesture)
		_rotate_global("upperarm01.R", Vector3.RIGHT, -gesture * .35)
	elif activity == "shoes":
		_rotate_global("neck01", Vector3.RIGHT, .18)
		_rotate_global("head", Vector3.RIGHT, .08)
	elif settled and seated:
		# Resting on a bench: mostly looking down (phone, lap), now and then up.
		var down := smoothstep(-.2, .4, sin(_pose_time * .13 + phase_offset))
		_rotate_global("neck01", Vector3.RIGHT, .22 * down)

## Head yaw (body space) for a settled student: the friend they talk to,
## the player passing close by, or a slow look around.
func _look_target() -> float:
	if activity == "chat" and _chat_started:
		var friend: StudentCharacter = manager.chat_partner(self)
		if friend:
			return _yaw_to(friend.global_position, .9)
	if activity != "shoes" and manager and is_instance_valid(manager.player):
		var player_at: Vector3 = manager.player.global_position
		if player_at.distance_to(global_position) < 3.5:
			var yaw := _yaw_to(player_at, 2.0)
			if absf(yaw) < 1.3:
				return clampf(yaw, -.8, .8)
	if activity == "window":
		return sin(_pose_time * .35) * .25
	if activity == "shoes" or seated:
		return 0.0
	return sin(_pose_time * .22 + phase_offset) * .35

func _yaw_to(point: Vector3, limit: float) -> float:
	var to := global_transform.basis.inverse() * (point - global_position)
	return clampf(atan2(to.x, to.z), -limit, limit)

## Whether this character ever sits down (the seated-thigh fix is only for them).
func _sits() -> bool:
	return true
