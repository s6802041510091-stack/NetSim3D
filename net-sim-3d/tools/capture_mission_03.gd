extends SceneTree

## Screenshots of Level 3 played through (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_mission_03.gd -- <out_dir>

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _finish_dialogue(dialogue: DialogueBox) -> void:
	var guard := 0
	while dialogue.is_open() and guard < 60:
		dialogue.advance(true)
		guard += 1
	for i in 2:
		await process_frame


func _use_pc(manager: ComputerManager, station: ComputerStation, player: Node) -> void:
	manager.open_computer(station, player)
	await create_timer(3.3).timeout


func _close_pc(manager: ComputerManager) -> void:
	manager.close_computer()
	await create_timer(1.0).timeout


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://capture_progress_m3.json"
	GameProgress.clear()
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 3)
	root.add_child(map)
	for i in 10:
		await process_frame
	var mission: Mission03Controller = map.get_node("Mission03")
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	await create_timer(0.5).timeout
	await _shot("m3_01_tracker_start")

	# The teacher in the computer room.
	var teacher: Node3D = map.get_node("TeacherMale")
	var spot := teacher.global_position + teacher.global_basis.z * 1.6
	spot.y = player.global_position.y
	player.global_position = spot
	player.look_at(Vector3(teacher.global_position.x, spot.y, teacher.global_position.z))
	mission._on_teacher_talked(player)
	await create_timer(0.6).timeout
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	await create_timer(0.3).timeout
	await _shot("m3_02_teacher")
	await _finish_dialogue(mission.dialogue)

	mission._on_talked(player)
	await create_timer(1.0).timeout
	await _finish_dialogue(mission.dialogue)
	await create_timer(0.5).timeout
	await _shot("m3_03_tracker_after_briefing")

	var desktop := manager.desktop
	var teacher_pc := manager.find_host("TEACHER-PC")
	var front := manager.find_host("PC-R1-L1")
	var back := manager.find_host("PC-R5-R2")
	# Out of order: the front PC first.
	await _use_pc(manager, front, player)
	await _shot("m3_04_out_of_order")
	await _close_pc(manager)

	await _use_pc(manager, teacher_pc, player)
	desktop._open_cmd()
	desktop._on_cmd_submitted("ipconfig")
	desktop._on_cmd_submitted("ping 192.168.1.1")
	await create_timer(2.4).timeout
	mission.checklist.fill("192.168.1.5", "255.255.255.0", "192.168.1.1", Mission03State.REPLY, Mission03State.NORMAL)
	await _shot("m3_05_teacher_pc_checklist")
	mission.checklist.attach()
	await _close_pc(manager)
	await _shot("m3_06_tracker_step3")

	await _use_pc(manager, front, player)
	desktop._open_cmd()
	desktop._on_cmd_submitted("ipconfig")
	desktop._on_cmd_submitted("ping 192.168.1.1")
	await create_timer(2.4).timeout
	mission.checklist.fill("192.168.1.11", "255.255.255.0", "192.168.1.1", Mission03State.REPLY, Mission03State.NORMAL)
	mission.checklist.attach()
	await _close_pc(manager)

	await _use_pc(manager, back, player)
	desktop._open_cmd()
	desktop._on_cmd_submitted("ipconfig")
	desktop._on_cmd_submitted("ping 192.168.1.1")
	await create_timer(2.4).timeout
	desktop._on_cmd_submitted("ipconfig /release")
	await _shot("m3_07_back_pc_timeout")
	mission.checklist.fill("192.168.1.30", "255.255.255.0", "192.168.1.1", Mission03State.TIMEOUT, Mission03State.ABNORMAL)
	mission.checklist.attach()
	await create_timer(0.3).timeout
	await _shot("m3_08_report")
	mission.report.confirm()
	await create_timer(1.2).timeout
	await _shot("m3_09_tracker_return")

	mission._on_talked(player)
	await create_timer(1.0).timeout
	await _finish_dialogue(mission.dialogue)
	await create_timer(2.5).timeout
	await _shot("m3_10_summary")
	GameProgress.clear()
	quit()
