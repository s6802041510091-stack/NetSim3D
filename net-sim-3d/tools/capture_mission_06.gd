extends SceneTree

## Screenshots of Level 6 v2 (2026-11-15) played through (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_mission_06.gd -- <out_dir>

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _talk_to_choice(mission: Mission06Controller) -> void:
	for i in 80:
		await process_frame
		if mission.dialogue.choosing:
			return
		if mission.dialogue.is_open():
			mission.dialogue.advance(true)
			mission.dialogue.advance(true)
		elif mission.asking == "" and not mission._busy:
			return


func _choose(mission: Mission06Controller, right: bool) -> void:
	var q := mission.data.get_question(mission.asking)
	for i in mission.ask_order.size():
		if (mission.ask_order[i] == q.correct_index) == right:
			mission.dialogue.choose(i)
			return


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://capture_progress_m6.json"
	var data := load(TeamViewerSim.DATA_PATH) as Mission06Data
	data.mail_delay = 1.0
	data.restart_mail_delay = 1.0
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 6)
	root.add_child(map)
	for i in 10:
		await process_frame
	var mission: Mission06Controller = map.get_node("Mission06")
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var desktop := manager.desktop
	var station := manager.find_host("IT-PC-01")

	# 1. The call from the small meeting room.
	mission.phone.use(player)
	await create_timer(1.6).timeout
	await _shot("m6_01_call")
	# The three choices in the call.
	for id in ["program", "request", "keep_open"]:
		await _talk_to_choice(mission)
		await create_timer(2.5).timeout
		await _shot("m6_02_choice_" + id)
		_choose(mission, true)
	await _talk_to_choice(mission)

	# 2. The e-mail.
	manager.open_computer(station, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 1.2).timeout
	await _shot("m6_03_new_mail_toast")
	desktop.open_mail()
	await create_timer(0.4).timeout
	await _shot("m6_04_mail")

	# 3–4. TeamViewer, connect.
	var app := desktop.open_teamviewer() as TeamViewerSim
	await create_timer(0.3).timeout
	(app.find_child("PartnerIdEdit", true, false) as LineEdit).text = data.partner_id
	await _shot("m6_05_teamviewer_home")
	app.connect_partner(data.partner_id)
	(app.find_child("PasswordEdit", true, false) as LineEdit).text = data.partner_password
	await _shot("m6_06_authentication")
	app.log_on(data.partner_password)
	await create_timer(TeamViewerSim.CONNECT_DELAY + 2.6).timeout
	await _shot("m6_07_remote_desktop_chat")

	# 5. Sound, the private file, the start menu.
	app.open_volume_flyout()
	await _shot("m6_08_muted")
	app.toggle_mute()
	app.set_volume(60)
	await _shot("m6_09_volume_60")
	app.open_volume_flyout()
	app.open_remote_file(data.private_file)
	await _shot("m6_10_private_file_opened")
	(app.find_child("SheetClose", true, false) as Button).pressed.emit()
	app.open_start_menu()
	(app.find_child("PowerButton", true, false) as Button).pressed.emit()
	await _shot("m6_11_start_power_menu")
	app.open_start_menu()

	# 6. The chat.
	app.open_chat()
	app.send_chat("แก้แล้วครับ ครูลองเปิดคลิปฟังเสียงดูหน่อยครับ")
	await create_timer(TeamViewerSim.REPLY_DELAY + 0.5).timeout
	await _shot("m6_12_teacher_confirms")
	# Her two questions in the chat (reply buttons).
	await create_timer(TeamViewerSim.REPLY_DELAY * 2 + 0.5).timeout
	await _shot("m6_12b_chat_question")
	app.answer_chat_question(data.get_question("limits").correct_index)
	await create_timer(TeamViewerSim.REPLY_DELAY * 3 + 0.5).timeout
	app.answer_chat_question(data.get_question("password").correct_index)
	await create_timer(TeamViewerSim.REPLY_DELAY + 0.5).timeout
	await _shot("m6_12c_chat_done")

	# 7–8. End Session, close, switch off -> summary.
	app.request_end_session()
	await _shot("m6_13_end_session")
	app.confirm_disconnect()
	await _shot("m6_14_session_ended")
	app.try_close()
	await create_timer(0.3).timeout
	desktop.request_shutdown()
	await create_timer(manager.zoom_time + 1.8).timeout
	await _shot("m6_15_summary")
	GameProgress.clear()
	quit()
