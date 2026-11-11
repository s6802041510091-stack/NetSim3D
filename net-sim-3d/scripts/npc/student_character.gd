class_name StudentCharacter
extends NpcCharacter

## Ambient students reuse the approved MakeHuman rig/arm solver. Unlike the
## older desk routine, locomotion uses CharacterBody physics, not teleporting.
@export var student_id := ""
@export var stroll_speed := 1.0
@export var phase_offset := 0.0
var manager: Node
var routine: Array[Dictionary] = []
var step_index := 0
var completed_loops := 0
var visits: Dictionary = {}
var activity := "idle"
var phase := "hold"
var hold_time := 0.0
var blocked_time := 0.0
var distance_walked := 0.0
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

func _ready() -> void:
	super._ready()
	if skeleton == null:
		push_error("Student rig missing: " + student_id)
		return
	_apply_pose(_standing_pose())
	_support = StudentPoseSupport.new()
	_support.setup(self)
	_phase = phase_offset
	_pose_time = phase_offset
	floor_snap_length = .15
	set_process(true)
	set_physics_process(true)

func start_routine(owner_node: Node, steps: Array[Dictionary]) -> void:
	manager = owner_node
	routine = steps
	_begin_step()

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

func current_step() -> Dictionary:
	return routine[step_index] if not routine.is_empty() else {}

func _physics_process(delta: float) -> void:
	if routine.is_empty() or skeleton == null:
		return
	_pose_time += delta
	if phase == "walk":
		_walk_physics(delta)
	elif phase == "turn":
		velocity = Vector3.ZERO
		var yaw: float = current_step().get("yaw", rotation.y)
		rotation.y = rotate_toward(rotation.y, yaw, 3.0 * delta)
		if absf(angle_difference(rotation.y, yaw)) < .035:
			_arrive()
	elif phase == "sit" or phase == "stand":
		_seat_transition(delta)
	elif phase == "hold":
		velocity = Vector3.ZERO
		if activity == "chat":
			var friend: StudentCharacter = manager.chat_partner(self)
			if friend and friend.activity == "chat" and friend.phase == "hold" and global_position.distance_to(friend.global_position) < 1.5:
				_chat_started = true
				friend._chat_started = true
				var to := friend.global_position - global_position
				rotation.y = rotate_toward(rotation.y, atan2(to.x, to.z), delta * 2.5)
			# A rendezvous has a bounded wait, so an interrupted partner cannot
			# strand this student forever. Once paired both finish their chat.
			if _chat_started:
				hold_time -= delta
			else:
				_elapsed += delta
				if _elapsed > 22:
					hold_time = 0
		else:
			hold_time -= delta
		if hold_time <= 0:
			if seated:
				if _exit_clear():
					phase = "stand"
					_elapsed = 0
			else:
				_advance()
	_walk_blend = move_toward(_walk_blend, 1.0 if walking and not blocked else 0.0, delta * 4)

func _walk_physics(delta: float) -> void:
	var target: Vector3 = current_step()["point"]
	var to := target - global_position
	to.y = 0
	if to.length() < .07:
		walking = false
		blocked = false
		velocity = Vector3.ZERO
		phase = "turn"
		return
	var direction := _avoid_people(to.normalized())
	blocked = direction.length_squared() < .01
	if blocked:
		blocked_time += delta
		velocity = Vector3.ZERO
	else:
		blocked_time = 0
		var yaw := atan2(direction.x, direction.z)
		rotation.y = rotate_toward(rotation.y, yaw, 3.4 * delta)
		var speed := stroll_speed * minf(1.0, to.length() / .22)
		if absf(angle_difference(rotation.y, yaw)) > .65:
			speed *= .18
		velocity = direction * speed
	velocity.y = -.5
	var from := global_position
	move_and_slide()
	var travelled := Vector2(global_position.x - from.x, global_position.z - from.z).length()
	distance_walked += travelled
	_phase += travelled / STRIDE * PI
	# The gait stops if physical collision stopped the body.
	if travelled < .0001:
		blocked = true

func _avoid_people(wanted: Vector3) -> Vector3:
	var steer := wanted
	var people: Array[Node3D] = []
	people.assign(manager.students)
	if is_instance_valid(manager.player):
		people.append(manager.player)
	for other: Node3D in people:
		if other == self:
			continue
		var offset := other.global_position - global_position
		offset.y = 0
		var distance := offset.length()
		if distance < .001 or distance > 1.15:
			continue
		var ahead := wanted.dot(offset)
		var lateral := (offset - wanted * ahead).length()
		if ahead < -.10 or lateral > .57:
			continue
		if other == manager.player:
			# Never push through the player: wait and resume when they move.
			if ahead > 0 and distance < .95:
				return Vector3.ZERO
			continue
		if ahead > .0:
			var own_right := wanted.cross(Vector3.UP)
			steer += own_right * (1.4 * (1.0 - distance / 1.15))
			steer -= offset.normalized() * (.35 * (1.0 - distance / 1.15))
	return steer.normalized()

func _arrive() -> void:
	activity = current_step().get("activity", "idle")
	visits[activity] = int(visits.get(activity, 0)) + 1
	hold_time = float(current_step().get("seconds", 2))
	_elapsed = 0
	if activity == "rest":
		_bench = manager.bench_for(current_step()["bench"])
		if _bench:
			_approach = global_position
			_seat = _bench.global_position + _bench.global_basis.z * .05
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

func _advance() -> void:
	step_index += 1
	if step_index >= routine.size():
		step_index = 0
		completed_loops += 1
	_begin_step()

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
	var query := PhysicsShapeQueryParameters3D.new()
	var shape: CollisionShape3D = get_node("CollisionShape3D")
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, _approach + shape.position)
	query.collision_mask = 2
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _seat_transition(delta: float) -> void:
	var next_elapsed := _elapsed + delta
	var t := smoothstep(0.0, 1.0, minf(1, next_elapsed / 1.1))
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
	if _elapsed >= 1.1:
		if phase == "sit":
			seated = true
			phase = "hold"
		else:
			seated = false
			remove_collision_exception_with(_bench)
			_bench = null
			_advance()

func _process(delta: float) -> void:
	if skeleton == null:
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
	if activity == "chat" and _chat_started:
		var speaking:bool=manager.is_speaking(self)
		_rotate_global("neck01", Vector3.RIGHT, sin(_pose_time * 1.6) * (.025 if speaking else .012))
		var gesture := maxf(0, sin(_pose_time * 1.3)) * (.40 if speaking else .03)
		_rotate_global("lowerarm01.R", Vector3.RIGHT, -gesture)
		_rotate_global("upperarm01.R", Vector3.RIGHT, -gesture * .35)
	elif activity == "shoes":
		_rotate_global("neck01", Vector3.RIGHT, .18)
		_rotate_global("head", Vector3.RIGHT, .08)
	elif activity == "window" or (phase == "hold" and not seated):
		_rotate_global("neck01", Vector3.UP, sin(_pose_time * .45) * .12)
