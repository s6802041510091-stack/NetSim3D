extends SceneTree

## ครูแสตมป์ (scripts/npc/science_teacher.gd): seated at the science-room
## laptop in every level, white shirt, the chair under him, and E from across
## the bench or beside him shows his two welcome lines, then he goes back to work.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_science_teacher.gd
## With a window and `-- <out_dir>` it also saves the conversation (stamp_talk.png).

const TEACHER := preload("res://scripts/npc/science_teacher.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ", message)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _load(level: int) -> Node3D:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, level)
	root.add_child(map)
	await _frames(6)
	return map


func _look_at(player: CharacterBody3D, target: Vector3) -> void:
	player.look_at(Vector3(target.x, player.global_position.y, target.z), Vector3.UP)
	var eye: Vector3 = player.camera.global_position
	player.camera.rotation.x = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())
	await _frames(3)


func _press_interact() -> void:
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = &"interact"
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for level in [1, 3, 5, 6]:
		var map := await _load(level)
		var teacher := map.get_node_or_null(TEACHER.NODE_NAME) as NpcCharacter
		_check(teacher != null and teacher.seated, "level %d: ครูแสตมป์ seated" % level)
		_check(map.find_children("TeacherStamp", "", true, false).size() == 1, "level %d: only one" % level)
		if level == 1 and teacher:
			await _test_level_1(map, teacher)
		map.queue_free()
		await _frames(2)
	print("SCIENCE_TEACHER_VALID" if failures == 0 else "SCIENCE_TEACHER_INVALID failures=%d" % failures)
	quit(1 if failures else 0)


func _test_level_1(map: Node3D, teacher: NpcCharacter) -> void:
	_check(teacher.global_position.distance_to(TEACHER.SEAT) < 0.01, "at the laptop seat")
	# White shirt, dark trousers, no khaki epaulets.
	var shirt := Color(0, 0, 0, 0)
	var epaulets_visible := false
	for node in teacher.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if String(mesh.name).begins_with("Uniform | epaulets") and mesh.visible:
			epaulets_visible = true
		if String(mesh.name).begins_with("Uniform_Shirt"):
			shirt = (mesh.get_active_material(0) as BaseMaterial3D).albedo_color
	_check(shirt.is_equal_approx(TEACHER.OUTFITS["white"]["shirt"]), "white shirt: %s" % shirt)
	_check(not epaulets_visible, "no epaulets")
	var chair := map.get_node("MapVisual/" + TEACHER.CHAIR) as MeshInstance3D
	var chair_center: Vector3 = chair.global_transform * chair.get_aabb().get_center()
	_check(Vector2(chair_center.x - TEACHER.SEAT.x, chair_center.z - TEACHER.SEAT.z).length() < 0.12, "chair under him: %s" % chair_center)
	var hands := teacher.get_node("KeyboardHand") as Node3D
	_check(absf(hands.global_position.y - 0.92) < 0.03 and hands.global_position.z > -7.62 and hands.global_position.z < -7.4, "left hand on the laptop: %s" % hands.global_position)

	var player := map.get_node("ITSupportPlayer") as CharacterBody3D
	player.require_mouse_capture = false
	var head := TEACHER.SEAT + Vector3(0, 1.3, 0.05)
	var life := map.get_node("ScienceTeacher")
	var dialogue: DialogueBox = life.get("dialogue")
	# From across the bench (where the students stand) and from beside him.
	for spot: Vector3 in [Vector3(-13.15, 0.02, -8.05), Vector3(-14.25, 0.02, -6.45)]:
		player.global_position = spot
		await _frames(2)
		await _look_at(player, head)
		var focus: Object = player.focused_interactable
		_check(focus is Talkable and (focus as Node).get_parent() == teacher, "focus from %s: %s" % [spot, focus])
		_check(player._prompt.text == "กด E เพื่อคุยกับครูแสตมป์", "prompt: " + player._prompt.text)

	await _press_interact()
	var wait := 0
	while not dialogue.is_open() and wait < 600:
		await _frames(1)
		wait += 1
	_check(player.controls_locked, "talking locks the player")
	_check(dialogue.is_open() and "สวัสดีนักเรียน" in dialogue.current_text(), "first line: " + dialogue.current_text())
	if OS.get_cmdline_user_args().size() > 0:
		dialogue.advance(true) # whole line shown
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("stamp_talk.png"))
	dialogue.advance(true) # finish typing
	dialogue.advance(true) # next line
	await _frames(3)
	dialogue.advance(true)
	_check("ครูตั้งใจพัฒนาจริงๆ" in dialogue.current_text(), "second line: " + dialogue.current_text())
	var guard := 0
	while dialogue.is_open() and guard < 10:
		dialogue.advance(true)
		guard += 1
		await _frames(1)
	await _frames(40)
	_check(not dialogue.is_open() and not player.controls_locked, "back to play after the talk")
	_check(teacher.seated, "still seated at the laptop")
