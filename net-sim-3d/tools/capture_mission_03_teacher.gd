extends SceneTree

## Screenshots of the Level 3 male teacher: at TEACHER-PC, talking, walking
## out to the teachers' room, seated at his own desk (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_mission_03_teacher.gd -- <out_dir>

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://capture_progress_m3t.json"
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 3)
	root.add_child(map)
	for i in 10:
		await process_frame
	var mission: Mission03Controller = map.get_node("Mission03")
	var teacher: NpcCharacter = map.get_node("TeacherMale")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	mission.hud.set_collapsed(true)
	var camera := Camera3D.new()
	camera.fov = 60.0
	map.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(5.6, 1.55, -6.3)
	camera.look_at(Vector3(6.75, 1.0, -8.7))
	await create_timer(1.0).timeout
	await _shot("t1_teacher_at_teacher_pc")

	# The player talks to him from in front of the desk.
	player.global_position = Vector3(6.8, player.global_position.y, -6.75)
	player.look_at(Vector3(6.8, player.global_position.y, -9.0))
	player.camera.make_current()
	await create_timer(0.3).timeout
	mission._on_teacher_talked(player)
	await create_timer(0.9).timeout
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	await create_timer(0.3).timeout
	await _shot("t2_teacher_talks")
	var guard := 0
	while mission.dialogue.is_open() and guard < 40:
		mission.dialogue.advance(true)
		guard += 1
	# Walking out of the computer room.
	camera.make_current()
	player.global_position = Vector3(1.0, player.global_position.y, -14.0) # out of his way
	await create_timer(4.5).timeout
	camera.global_position = Vector3(1.5, 1.7, -4.0)
	camera.look_at(teacher.global_position + Vector3(0, 1.0, 0))
	await _shot("t3_walking_to_door")
	while teacher.global_position.z > -14.0:
		await process_frame
	camera.global_position = teacher.global_position + Vector3(-1.2, 1.6, -3.5)
	camera.look_at(teacher.global_position + Vector3(0, 1.0, 0))
	await _shot("t4_corridor")
	var t0 := Time.get_ticks_msec()
	while mission.teacher_place != "staff_room" and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await create_timer(1.0).timeout
	camera.global_position = Vector3(5.7, 1.6, -19.9)
	camera.look_at(Vector3(7.8, 1.0, -21.4))
	await _shot("t5_teacher_back_at_his_desk")
	print("PLACE ", mission.teacher_place, " doors: ", (map.get_node("Doors/ClassroomDoor") as InteractiveDoor).is_open, (map.get_node("Doors/StaffDoor") as InteractiveDoor).is_open)
	GameProgress.clear()
	quit()
