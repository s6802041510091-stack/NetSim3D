extends SceneTree

## Screenshots of Level 5 (v2.1, 2026-11-15) played through (run WITH a window):
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


## Waits for a question, lets it finish typing, then answers it.
func _answer(mission: Mission05Controller, id: String, right: bool, shot: String = "") -> void:
	var t0 := Time.get_ticks_msec()
	while not (mission.asking == id and mission.dialogue.choosing) and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	await create_timer(2.5).timeout
	if shot != "":
		await _shot(shot)
	var q := mission.data.get_question(id)
	for i in mission._order.size():
		if (mission._order[i] == q.correct_index) == right:
			mission.dialogue.choose(i)
			break
	await create_timer(0.3).timeout


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

	# 1. The call (the teacher mentions SchoolLab Classroom), with the tracker.
	mission.phone.use(player)
	await create_timer(1.2).timeout
	await _shot("m5_01_call")
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	await create_timer(2.5).timeout
	await _shot("m5_02_call_schoollab")
	await _talk_through(mission.dialogue)
	await create_timer(0.6).timeout

	# 2. Walking in: the teacher greets the player (the class at the PCs, the
	# owner of PC-R3-L2 standing beside it).
	await create_timer(3.0).timeout # the owner has stepped aside by now
	player.global_position = Vector3(-1.6, 0.02, -6.5)
	player.rotation.y = PI * 0.82
	await create_timer(1.6).timeout
	await _shot("m5_02b_greeting")
	await _talk_through(mission.dialogue)
	await create_timer(0.4).timeout

	# The computer room: the warning screen of PC-R3-L2, the teacher at the front.
	var cam := Camera3D.new()
	cam.fov = 62
	map.add_child(cam)
	cam.look_at_from_position(Vector3(3.2, 1.75, 5.6), Vector3(1.6, 0.9, 0.6))
	cam.make_current()
	await create_timer(0.4).timeout
	await _shot("m5_02c_class_and_owner")
	# A seated female student up close (skirt and the runtime thighs).
	var bob := map.get_node("ClassroomStudents/bob") as Node3D
	cam.look_at_from_position(bob.global_position + Vector3(1.3, 1.15, 0.9), bob.global_position + Vector3(0, 0.6, 0))
	await create_timer(0.4).timeout
	await _shot("m5_02d_female_seated")
	var head := teacher.global_position + Vector3(0, 1.2, 0)
	var from := target.global_position + Vector3(0.9, 0.75, 1.9)
	cam.look_at_from_position(from, (head + target.global_position) * 0.5)
	await create_timer(0.4).timeout
	await _shot("m5_03_computer_room")
	# The warning picture on the monitor, as the player walks up to the desk.
	var view := target.get_view_transform(cam.fov)
	cam.global_transform = view.translated(view.basis.z * 0.55 + Vector3(0, 0.12, 0))
	cam.look_at(target.global_transform * target.screen.get_aabb().get_center())
	await create_timer(0.3).timeout
	await _shot("m5_03b_warning_screen")
	cam.clear_current()
	player.camera.make_current()

	# 3. Desktop with the warning pop-up; Windows Security: Home.
	manager.open_computer(target, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.6).timeout
	await _shot("m5_04_desktop_warning")
	var app := desktop.open_windows_security() as WindowsSecurity
	await create_timer(0.3).timeout
	await _shot("m5_05_home")

	# 4. Firewall page: the two alerts come up (SchoolLab in front).
	app.open_page(WindowsSecurity.Page.FIREWALL)
	await _shot("m5_06_firewall_alerts")
	var alerts := app.alerts()
	alerts.press(false)
	await _shot("m5_07_school_cancel_hint")
	alerts.press(true, true, true)
	await _shot("m5_08_public_note_unknown_front")
	alerts.press(true)
	await _shot("m5_09_unknown_allow_hint")
	alerts.press(false)
	await _shot("m5_10_firewall_done")
	(app.find_child("Link_Allowanappthroughfirewall", true, false) as Button).pressed.emit()
	await _shot("m5_11_allowed_apps")

	# 5. Virus & threat protection: scan.
	app.open_page(WindowsSecurity.Page.VIRUS)
	app.start_scan()
	await create_timer(1.6).timeout
	await _shot("m5_13_scanning")
	await create_timer(3.0).timeout
	(app.find_child("ThreatRow", true, false) as Button).pressed.emit()
	await create_timer(0.2).timeout
	(app.find_child("Action_quarantine", true, false) as CheckBox).button_pressed = true
	await _shot("m5_14_threat_two_files")
	app.choose_threat("quarantine")
	await _shot("m5_15_quarantined")
	app.open_page(WindowsSecurity.Page.HISTORY)
	await _shot("m5_16_history")

	# 6. Protected -> submit -> tell the teacher -> report choice -> summary.
	app.open_page(WindowsSecurity.Page.HOME)
	await _shot("m5_17_home_all_green")
	(app.find_child("SubmitButton", true, false) as Button).pressed.emit()
	await create_timer(app.exit_delay + manager.zoom_time + 0.6).timeout
	# The computer is fixed: its owner sits back down at it.
	var t0 := Time.get_ticks_msec()
	while mission.watcher_state != "seated" and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
	cam.look_at_from_position(Vector3(2.4, 1.6, 4.4), Vector3(0.7, 0.85, 1.6))
	cam.make_current()
	await create_timer(0.6).timeout
	await _shot("m5_17b_owner_seated")
	cam.clear_current()
	player.camera.make_current()
	mission._on_teacher_talked(player)
	await create_timer(1.5).timeout
	await _shot("m5_18_tell_dialogue")
	await _talk_through(mission.dialogue)
	await _answer(mission, "report", true, "m5_19_report_choice")
	await create_timer(0.8).timeout
	await _talk_through(mission.dialogue)
	await create_timer(1.5).timeout
	await _shot("m5_20_summary")
	GameProgress.clear()
	quit()
