extends SceneTree

## Screenshots of Level 5 played through (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_mission_05.gd -- <out_dir>

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


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://capture_progress_m5.json"
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 5)
	root.add_child(map)
	for i in 10:
		await process_frame
	var mission: Mission05Controller = map.get_node("Mission05")
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var teacher: Node3D = map.get_node("TeacherMale")
	var desktop := manager.desktop
	var target := manager.find_host("PC-R3-L2")

	# 1. The call, with the tracker.
	mission.phone.use(player)
	await create_timer(1.2).timeout
	await _shot("m5_01_call")
	await _talk_through(mission.dialogue)
	await create_timer(0.6).timeout

	# 2. The computer room: the red screen of PC-R3-L2, the teacher at the front.
	var cam := Camera3D.new()
	cam.fov = 62
	map.add_child(cam)
	var head := teacher.global_position + Vector3(0, 1.2, 0)
	var from := target.global_position + Vector3(0.9, 0.75, 1.9)
	cam.look_at_from_position(from, (head + target.global_position) * 0.5)
	cam.make_current()
	await create_timer(0.4).timeout
	await _shot("m5_02_computer_room")
	cam.clear_current()
	player.camera.make_current()

	# 3. Desktop with the warning pop-up.
	manager.open_computer(target, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.6).timeout
	await _shot("m5_03_desktop_warning")

	# 4. Windows Security: Security at a glance.
	var app := desktop.open_windows_security() as WindowsSecurity
	await create_timer(0.3).timeout
	await _shot("m5_04_home")

	# 5. Firewall page with the Windows Security Alert; a wrong answer shows the Thai hint.
	app.open_page(WindowsSecurity.Page.FIREWALL)
	await _shot("m5_05_firewall_alert")
	app.choose_firewall("allow")
	await _shot("m5_06_alert_wrong_hint")
	app.handle_escape()
	app.open_profile("Public")
	await _shot("m5_07_public_network")
	app.open_page(WindowsSecurity.Page.FIREWALL)
	app.choose_firewall("block")
	await _shot("m5_08_firewall_blocked")

	# 6. Virus & threat protection: scan, threat found, actions.
	app.open_page(WindowsSecurity.Page.HOME)
	await _shot("m5_09_home_firewall_ok")
	app.open_page(WindowsSecurity.Page.VIRUS)
	await _shot("m5_10_virus_page")
	app.start_scan()
	await create_timer(1.6).timeout
	await _shot("m5_11_scanning")
	await create_timer(3.0).timeout
	(app.find_child("ThreatRow", true, false) as Button).pressed.emit()
	await create_timer(0.2).timeout
	(app.find_child("Action_quarantine", true, false) as CheckBox).button_pressed = true
	await _shot("m5_12_threat_actions")
	app.open_page(WindowsSecurity.Page.EXCLUSIONS)
	(app.find_child("AddExclusionButton", true, false) as Button).pressed.emit()
	await create_timer(0.1).timeout
	(app.find_child("Exclude_File", true, false) as Button).pressed.emit()
	await _shot("m5_13_exclusion_picker")
	app.handle_escape()
	app.open_page(WindowsSecurity.Page.VIRUS)
	app.choose_threat("quarantine")
	await _shot("m5_14_quarantined")
	app.open_page(WindowsSecurity.Page.HISTORY)
	await _shot("m5_15_history")

	# 7. Protected.
	app.open_page(WindowsSecurity.Page.HOME)
	await _shot("m5_16_home_all_green")
	(app.find_child("SubmitButton", true, false) as Button).pressed.emit()
	await create_timer(app.exit_delay + manager.zoom_time + 0.6).timeout
	await _shot("m5_17_tell_teacher_tracker")

	# 9. Tell the teacher -> summary.
	mission._on_teacher_talked(player)
	await create_timer(1.0).timeout
	await _shot("m5_18_tell_dialogue")
	await _talk_through(mission.dialogue)
	await create_timer(1.5).timeout
	await _shot("m5_19_summary")
	GameProgress.clear()
	quit()
