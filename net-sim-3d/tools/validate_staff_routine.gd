extends SceneTree

## Teachers' room routine (StaffRoomLife): who is free in which level, the
## routes clear the map, a chat with speech bubbles, a coffee break, and both
## back at their desks afterwards.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_staff_routine.gd
## With a window and `-- <out_dir>` it also saves screenshots.

var failures := 0
var out_dir := ""
var camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ", message)
	if not ok:
		failures += 1


func _shot(name: String, eye: Vector3, at: Vector3) -> void:
	if out_dir == "":
		return
	camera.global_position = eye
	camera.look_at(at)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _load(level: int) -> Node3D:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, level)
	root.add_child(map)
	for i in 4:
		await physics_frame
	return map


func _wait_until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await process_frame
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	StaffRoomLife.auto_routine = false

	# Every level: who is free (male: missions 3, 5; female: missions 4, 6),
	# where each teacher is, who can be greeted.
	var free_by_level := {1: ["male", "female"], 2: ["male", "female"], 3: ["female"], 4: ["male"], 5: ["female"], 6: ["male"]}
	for lv: int in free_by_level:
		var m := await _load(lv)
		var lv_life: StaffRoomLife = m.get_node("StaffRoomLife")
		var free: Array = free_by_level[lv]
		_check(lv_life.idle.keys() == free, "Level %d: free teachers %s" % [lv, lv_life.idle.keys()])
		var m_male: Node3D = m.get_node("TeacherMale")
		if lv == 3:
			_check(m_male is NpcCharacter and (m_male as NpcCharacter).seated and m_male.global_position.distance_to(Vector3(6.78, 0.02, -8.88)) < 0.05, "Level 3: male teacher works at TEACHER-PC (Mission03Controller)")
		elif lv == 5:
			_check(not m_male is NpcCharacter and m_male.global_position.distance_to(Vector3(5.15, 0.02, -8.0)) < 0.01, "Level 5: male teacher in the computer room for his mission")
		else:
			_check(m_male is NpcCharacter and (m_male as NpcCharacter).seated and m_male.global_position.distance_to(StaffRoomLife.seat_of("male")) < 0.01, "Level %d: male teacher at his desk" % lv)
		var m_female := m.get_node("TeacherFemale") as NpcCharacter
		_check(m_female != null and m_female.seated and m_female.global_position.distance_to(StaffRoomLife.seat_of("female")) < 0.01, "Level %d: female teacher at her desk" % lv)
		_check((m_female.get_node_or_null("Talk") != null) == ("female" in free or lv == 4), "Level %d: female teacher greetable when free (Level 4: talks for her mission)" % lv)
		if lv == 4:
			# Alone in the teachers' room: his break is a coffee.
			var lv_male := m_male as NpcCharacter
			lv_life.run_coffee("male")
			var spot: Vector3 = StaffRoomLife.ROUTES["male_to_coffee"][-1]
			_check(await _wait_until(func(): return lv_male.global_position.distance_to(spot) < 0.06 and not lv_male.walking, 30.0), "Level 4: male teacher walks to the pantry")
			camera = Camera3D.new()
			camera.fov = 65.0
			m.add_child(camera)
			camera.make_current()
			await _shot("level4_male_coffee", Vector3(4.3, 1.6, -26.9), Vector3(3.1, 1.0, -29.6))
			_check(await _wait_until(func(): return lv_life.activity.get("male") == "desk", 45.0), "Level 4: back at his desk after the coffee")
		m.queue_free()
		for i in 2:
			await process_frame

	var map := await _load(1)
	var life: StaffRoomLife = map.get_node("StaffRoomLife")
	var male: NpcCharacter = map.get_node("TeacherMale")
	var female: NpcCharacter = map.get_node("TeacherFemale")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.global_position = Vector3(5.2, 0.05, -23.6) # in the room, out of the routes
	camera = Camera3D.new()
	camera.fov = 65.0
	map.add_child(camera)
	camera.make_current()
	_check(life.idle.size() == 2 and male.seated and female.seated, "Level 1: both teachers free and at their desks")

	# Every route leg clears the map colliders (from where each one stands up).
	var space := map.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.5
	for route_name: String in StaffRoomLife.ROUTES:
		var id := "male" if route_name.begins_with("male") else "female"
		var start: Vector3 = StaffRoomLife.seat_of(id) - Vector3(NpcCharacter.STAND_BACK, 0, 0)
		var points: Array = [start] + StaffRoomLife.ROUTES[route_name]
		var worst := 1.0
		for i in points.size() - 1:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY, (points[i] as Vector3) + Vector3(0, 0.95, 0))
			query.motion = (points[i + 1] as Vector3) - (points[i] as Vector3)
			worst = minf(worst, space.cast_motion(query)[0])
		_check(worst >= 1.0, "route %s clears the map (%.2f)" % [route_name, worst])

	# A chat: he walks over, they talk in turns, he walks back.
	life.run_chat()
	var chat_spot: Vector3 = StaffRoomLife.ROUTES["male_to_chat"][-1]
	_check(await _wait_until(func(): return male.global_position.distance_to(chat_spot) < 0.06 and not male.walking, 25.0), "male teacher walked to the female teacher's office")
	_check(await _wait_until(func(): return not life._bubbles.is_empty(), 4.0), "they talk: a speech bubble")
	await process_frame
	_check(not life._bubbles.is_empty() and life._bubbles[0].visible and life._bubbles[0].global_position.y > 1.5, "the bubble shows over a head to a player nearby")
	_check((male.get_node("Talk") as Talkable).prompt == "" and (female.get_node("Talk") as Talkable).prompt == "", "no greeting prompt while they chat")
	await _shot("routine_chat", Vector3(8.7, 1.75, -24.9), Vector3(7.9, 1.15, -27.3))
	var heard := {}
	while life.activity.get("female") == "away":
		for b in life._bubbles:
			heard[b.text] = true
		await process_frame
	_check(heard.size() >= 3, "the chat has lines from both (%d lines)" % heard.size())
	player.global_position = Vector3(1.0, 0.05, -14.0)
	await process_frame
	_check(await _wait_until(func(): return life.activity.get("male") == "desk", 25.0), "he walks back and sits down")
	_check(male.seated and male.global_position.distance_to(StaffRoomLife.seat_of("male")) < 0.01 and (male.get_node("Talk") as Talkable).prompt != "", "male teacher back at his desk, greeting on again")
	_check(female.seated and female.turn_amount == 0.0 and life.activity.get("female") == "desk", "female teacher back to work")

	# A coffee break.
	player.global_position = Vector3(5.2, 0.05, -23.6)
	life.run_coffee("female")
	var coffee: Vector3 = StaffRoomLife.ROUTES["female_to_coffee"][-1]
	_check(await _wait_until(func(): return female.global_position.distance_to(coffee) < 0.06 and absf(angle_difference(female.rotation.y, StaffRoomLife.COFFEE_YAW)) < 0.05, 30.0), "female teacher at the pantry counter, facing it")
	await _shot("routine_coffee", Vector3(4.6, 1.6, -26.9), Vector3(3.6, 1.0, -29.6))
	_check(await _wait_until(func(): return life.activity.get("female") == "desk", 45.0), "back to her desk after the coffee")
	_check(female.seated and female.global_position.distance_to(StaffRoomLife.seat_of("female")) < 0.01, "female teacher seated at her desk again")

	StaffRoomLife.auto_routine = true
	print("STAFF_ROUTINE_VALID" if failures == 0 else "STAFF_ROUTINE_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
