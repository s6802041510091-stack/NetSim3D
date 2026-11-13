extends SceneTree

## Screenshots of Level 4 played through (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_mission_04.gd -- <out_dir>

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _talk_through(dialogue: DialogueBox) -> void:
	var guard := 0
	while dialogue.is_open() and not dialogue.choosing and guard < 60:
		dialogue.advance(true)
		guard += 1
	for i in 2:
		await process_frame


func _until(cond: Callable, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://capture_progress_m4.json"
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 4)
	root.add_child(map)
	for i in 10:
		await process_frame
	var mission: Mission04Controller = map.get_node("Mission04")
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var teacher: NpcCharacter = map.get_node("TeacherFemale")
	var desktop := manager.desktop
	var cam := Camera3D.new()
	cam.fov = 60
	map.add_child(cam)
	mission.phone.use(player)
	await create_timer(0.5).timeout
	await _talk_through(mission.dialogue)
	mission._on_teacher_talked(player)
	await create_timer(0.8).timeout
	await _talk_through(mission.dialogue)
	await _until(func(): return not teacher.walking and not teacher.seated, 8.0)
	await create_timer(0.5).timeout
	cam.make_current()
	cam.global_position = Vector3(6.9, 1.55, -26.3)
	cam.look_at(Vector3(8.5, 0.8, -28.2))
	await _shot("m4_01_teacher_waits_tower_on_desk")
	player.camera.make_current()
	manager.open_computer(mission.station, player)
	await create_timer(3.4).timeout
	await _shot("m4_02_screen_lan_x")
	manager.close_computer()
	await create_timer(1.0).timeout
	mission.use_tower(player)
	await create_timer(1.0).timeout
	await _shot("m4_03_port_no_led")
	await _until(func(): return mission.stage == Mission04Controller.Stage.TEST and not mission._busy, 6.0)
	mission.use_tower(player)
	await create_timer(0.4).timeout
	await _shot("m4_04_tool_choice")
	mission.choice.pick("cable_tester")
	await _until(func(): return mission.dialogue.choosing, 8.0)
	await create_timer(0.5).timeout
	await _shot("m4_05_tester_verdict")
	mission.dialogue.choose(0)
	await _until(func(): return mission.stage == Mission04Controller.Stage.SWAP and not mission._busy, 6.0)
	mission.use_swap_pc(player)
	await create_timer(1.9).timeout
	await _shot("m4_06a_swap_led")
	await _until(func(): return mission.choice.is_open(), 6.0)
	await create_timer(0.3).timeout
	await _shot("m4_06_swap_question")
	mission.choice.pick("nic_suspect")
	await _until(func(): return mission.stage == Mission04Controller.Stage.ANALYZE and mission.choice.is_open(), 4.0)
	mission.choice.pick("new_cable")
	await create_timer(0.3).timeout
	await _shot("m4_07_analysis_hint")
	mission.choice.pick("replace_nic")
	await create_timer(0.3).timeout
	cam.make_current()
	cam.global_position = Mission04Controller.PARTS_BOX + Vector3(0.8, 0.7, 0.6)
	cam.look_at(Mission04Controller.PARTS_BOX)
	await _shot("m4_08_parts_box")
	player.camera.make_current()
	mission.open_parts(player)
	mission.choice.pick("nic")
	await create_timer(0.3).timeout
	mission.use_tower(player)
	await create_timer(4.2).timeout
	await _shot("m4_09_replacing_nic")
	await _until(func(): return mission.stage == Mission04Controller.Stage.VERIFY, 15.0)
	manager.open_computer(mission.station, player)
	await create_timer(3.4).timeout
	desktop.open_browser()
	await create_timer(0.5).timeout
	await _shot("m4_10_browser_ok")
	GameProgress.clear()
	quit()
