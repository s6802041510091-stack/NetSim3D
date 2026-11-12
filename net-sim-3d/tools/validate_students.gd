extends SceneTree

## Runs the corridor director for eight in-game minutes and checks that the
## students behave like people in a school corridor: long stays, few walkers,
## standing only against walls, doors shut behind them, real conversations.
const SIM_SECONDS := 480.0
const COUNT := 7
const DOORS := ["FemaleWCDoor", "MaleWCDoor", "BackgroundClassDoor"]

var failures := 0
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error("STUDENTS: " + note)

func _near_wall(p: Vector3) -> bool:
	return p.x < -8.2 or p.x > -4.1 or p.z < -42.8 or p.z > 8.5

func _run() -> void:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	# `-- 7` runs one fixed random seed; without it every run differs.
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if not args.is_empty() else 0
	(map.get_node("CorridorStudents") as StudentLife).random_seed = seed
	print("STUDENTS_SEED ", seed)
	root.add_child(map)
	for i in 5:
		await physics_frame
	var life: StudentLife = map.get_node("CorridorStudents")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.set_physics_process(false)
	player.global_position = Vector3(3, .02, 0) # out of the corridor
	check(life.students.size() == COUNT, "seven students")
	for student in life.students:
		check(student.skeleton != null and student.skeleton.get_bone_count() >= 160, student.student_id + " rig")
		for bone in ["upperarm01.L", "upperleg01.L", "spine05", "wrist.R", "head", "neck01"]:
			check(student.skeleton.find_bone(bone) >= 0, student.student_id + " bone " + bone)
	# Every authored standing spot fits a capsule (no wall, furniture or plant).
	var space := map.get_world_3d().direct_space_state
	var shape: CollisionShape3D = life.students[0].get_node("CollisionShape3D")
	var spots: Array[Vector3] = []
	for key in life.window_spots: spots.append(life.window_spots[key][0])
	for key in life.lean_spots: spots.append(life.lean_spots[key][0])
	for key in life.chat_spots: spots.append_array([life.chat_spots[key][0], life.chat_spots[key][1]])
	for p in spots:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape.shape
		q.transform = Transform3D(Basis.IDENTITY, p + shape.position + Vector3(0, .03, 0))
		q.collision_mask = 1
		check(space.intersect_shape(q, 1).is_empty(), "standing spot %s meets wall/furniture" % p)
		check(_near_wall(p), "standing spot %s is not against a wall" % p)
	# Both lanes are clear end to end.
	for lane in [life.WEST_LANE, life.EAST_LANE]:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape.shape
		q.transform = Transform3D(Basis.IDENTITY, Vector3(lane, .02, life.Z_MAX) + shape.position)
		q.motion = Vector3(0, 0, life.Z_MIN - life.Z_MAX)
		q.collision_mask = 1
		check(space.cast_motion(q)[0] >= .999, "lane x=%s meets furniture/wall" % lane)

	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 6
	var dt := 1.0 / 120.0 * 6.0
	var elapsed := 0.0
	var checkpoint := 60.0
	var seated_seen: Dictionary = {}
	var chats := 0
	var chat_seen: Dictionary = {}
	var max_walkers := 0
	var moving_time: Dictionary = {}
	var stays: Array[float] = []
	var stay_start: Dictionary = {}
	var nearest_pair := INF
	var hand_body_gap := INF
	var door_open_idle: Dictionary = {}
	var mid_corridor_stand := 0.0
	while elapsed < SIM_SECONDS and failures == 0:
		await physics_frame
		elapsed += dt
		var walking_now := 0
		for student in life.students:
			var p := student.global_position
			var step := student.current_step()
			if not student.hidden:
				var at_door: bool = step.has("door")
				check(p.x > (-10.7 if at_door else -9.10) and p.x < -3.19, student.student_id + " left corridor at " + str(p))
				check(p.y > -.03 and p.y < .06, student.student_id + " floor")
			if student.seated:
				seated_seen[student.student_id] = true
			if student.blocked_time > 24:
				check(false, student.student_id + " stalled at " + str(p))
			if student.is_moving():
				walking_now += 1
				moving_time[student.student_id] = float(moving_time.get(student.student_id, 0.0)) + dt
				if stay_start.has(student.student_id):
					stays.append(elapsed - float(stay_start[student.student_id]))
					stay_start.erase(student.student_id)
			elif not stay_start.has(student.student_id):
				stay_start[student.student_id] = elapsed
			# Settled and standing: must be against a wall, never in the walkway.
			if student.is_anchored() and not student.hidden and not student.seated and not _near_wall(p):
				mid_corridor_stand += dt
			if student._chat_started and student.chat_group != "" and not chat_seen.has(student.chat_group):
				chat_seen[student.chat_group] = true
				chats += 1
		if elapsed > 12:
			max_walkers = maxi(max_walkers, walking_now)
		# Doors students used are shut again once nobody is using them.
		for door_name in DOORS:
			var d := life.door(door_name)
			var in_use := false
			for student in life.people():
				in_use = in_use or student.current_step().get("door", "") == door_name or student._closing > 0
			if d.is_open and not d.is_moving and not in_use:
				door_open_idle[door_name] = float(door_open_idle.get(door_name, 0.0)) + dt
		var visible: Array[StudentCharacter] = []
		for s in life.students:
			if not s.hidden:
				visible.append(s)
		for i in visible.size():
			for j in range(i + 1, visible.size()):
				var first := visible[i]
				var second := visible[j]
				var separation := Vector2(first.global_position.x - second.global_position.x, first.global_position.z - second.global_position.z).length()
				nearest_pair = minf(nearest_pair, separation)
				check(separation > .43, "student capsules overlap: %s %s/%s %s %s/%s" % [first.student_id, first.phase, first.activity, second.student_id, second.phase, second.activity])
				if separation < 1.3:
					for pair: Array in [[first, second], [second, first]]:
						var s: StudentCharacter = pair[0]
						var other: StudentCharacter = pair[1]
						var hip := other.skeleton.global_transform * other._bone_pos(other.skeleton.find_bone("upperleg01.L"))
						var chest := other.skeleton.global_transform * other._bone_pos(other.skeleton.find_bone("spine03"))
						for bone in ["lowerarm01.L", "lowerarm01.R", "wrist.L", "wrist.R", "finger3-1.L", "finger3-1.R"]:
							var at := s.skeleton.global_transform * s._bone_pos(s.skeleton.find_bone(bone))
							var gap := at.distance_to(Geometry3D.get_closest_point_to_segment(at, hip, chest)) - .20
							hand_body_gap = minf(hand_body_gap, gap)
							check(gap > -.025, "arm/hand enters another student's torso: %s %s/%s %s -> %s %s/%s %s t=%d" % [s.student_id, s.phase, s.activity, s.global_position, other.student_id, other.phase, other.activity, other.global_position, int(elapsed)])
		if elapsed >= checkpoint:
			var states := []
			for student in life.students:
				states.append("%s:%s/%s plans%d%s" % [student.student_id, student.phase, student.activity, student.completed_loops, " hidden" if student.hidden else ""])
			print("STUDENTS_PROGRESS t=", int(elapsed), " walkers=", walking_now, " | ", " | ".join(states))
			checkpoint += 60
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 60
	var rooms := 0
	for student in life.students:
		rooms += int(student.visits.get("inside", 0))
		var share := float(moving_time.get(student.student_id, 0.0)) / elapsed
		check(student.completed_loops >= 2, student.student_id + " never moved on to a new place")
		check(share < .45, "%s walks %d%% of the time" % [student.student_id, int(share * 100)])
		print("STUDENT_RESULT ", student.student_id, " plans=", student.completed_loops, " metres=", snappedf(student.distance_walked, .1), " moving=", int(share * 100), "% activities=", student.visits)
	stays.sort()
	var median: float = stays[stays.size() / 2] if not stays.is_empty() else 0.0
	check(max_walkers <= life.MAX_WALKERS, "too many walking at once: %d" % max_walkers)
	check(mid_corridor_stand < 1.0, "settled students stood in the walkway for %.1fs" % mid_corridor_stand)
	check(chats >= 3, "only %d conversations" % chats)
	check(rooms >= 2, "only %d room visits" % rooms)
	check(seated_seen.size() >= 3, "only %d students sat down" % seated_seen.size())
	check(median >= 40, "median stay %.0fs is too short" % median)
	for door_name in door_open_idle:
		check(float(door_open_idle[door_name]) < 3.0, "%s left open %.1fs" % [door_name, door_open_idle[door_name]])

	# Menu pause stops routines too, without losing their current activity.
	var paused_positions: Array[Vector3] = []
	for student in life.students:
		paused_positions.append(student.global_position)
	paused = true
	for tick in 10:
		await physics_frame
	for i in life.students.size():
		check(life.students[i].global_position.is_equal_approx(paused_positions[i]), "student moved while game paused")
	paused = false
	# Put the player on one short clear route: the walker waits rather than
	# pushing, then resumes; the player's capsule also collides with the NPC.
	for student in life.students:
		student.set_physics_process(false)
	var walker: StudentCharacter
	for student in life.students:
		if not student.seated and not student.hidden:
			walker = student
			break
	check(walker != null, "no standing student for the yield test")
	walker._closing = 0
	walker.global_position = Vector3(-6.15, .02, -4)
	walker.rotation.y = PI
	var short_walk: Array[Dictionary] = [life.stop(-6.15, -10)]
	walker.start_routine(life, short_walk)
	walker.set_physics_process(true)
	player.global_position = Vector3(-6.15, .02, -4.8)
	for tick in 60:
		await physics_frame
	check(walker.blocked and walker.global_position.distance_to(Vector3(-6.15, .02, -4)) < .05, "walker did not wait for player")
	var held := walker.global_position
	player.global_position = Vector3(-5, .02, -4.8)
	for tick in 150:
		await physics_frame
	check(not walker.blocked and walker.global_position.distance_to(held) > .7, "walker did not resume after player moved")
	walker.set_physics_process(false)
	player.global_position = walker.global_position + Vector3(0, 0, 1.2)
	var npc_hit := false
	for tick in 15:
		var contact := player.move_and_collide(Vector3(0, 0, -.1))
		if contact:
			npc_hit = contact.get_collider() == walker
			break
	check(npc_hit, "player can walk through a student")
	# Distant animation culling must still update a sitting/standing posture.
	var far_camera := Camera3D.new()
	map.add_child(far_camera)
	far_camera.global_position = Vector3(40, 2, 0)
	far_camera.make_current()
	var bob := life.students[2]
	bob._set_hidden(false)
	bob.set_process(false)
	bob._last_pose_far = true
	bob._last_seat_pose = -1
	bob._seat_blend = 1
	bob._process(.06)
	check((bob.get_node("Visual") as Node3D).position.y < -.2, "distant student never adopted seated pose")
	bob._seat_blend = 0
	bob._process(.06)
	var sole_height: Dictionary = bob._support.sole_heights()
	check(absf(minf(sole_height["L"], sole_height["R"]) - .003) < .006, "distant standing feet are not grounded")
	print("STUDENT_SUMMARY max_walkers=", max_walkers, " conversations=", chats, " room_visits=", rooms, " median_stay_s=", int(median), " seated=", seated_seen.size(), " nearest_centres_m=", snappedf(nearest_pair, .01), " arm_torso_gap_m=", snappedf(hand_body_gap, .001))
	if failures == 0:
		print("STUDENTS_VALID count=%d walkers<=%d chats=%d rooms=%d median_stay=%ds player_yield=pass pause=pass" % [COUNT, max_walkers, chats, rooms, int(median)])
	else:
		print("STUDENTS_INVALID failures=", failures)
	quit(1 if failures else 0)
