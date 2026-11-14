extends SceneTree

## Mission 6 v2 checks (2026-11-15): scoring rules, then the whole level played
## headless (phone -> e-mail -> TeamViewer -> MEETING-PC -> chat -> End Session
## -> close -> switch off -> summary), including the mistakes.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_06.gd
## Prints MISSION_06_VALID / MISSION_06_INVALID at the end.

const HOST := "IT-PC-01"
const FULL := Mission06Controller.TIME_FULL_SEC
const ZERO := Mission06Controller.TIME_ZERO_SEC


class ErrorCounter extends Logger:
	var errors: PackedStringArray = PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s:%d %s() %s %s" % [file, line, function, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var failures := 0
var logger := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(logger)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		print("  ok   ", message)
	else:
		failures += 1
		print("  FAIL ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _finish_dialogue(dialogue: DialogueBox) -> void:
	var guard := 0
	while dialogue.is_open() and not dialogue.choosing and guard < 60:
		dialogue.advance(true)
		guard += 1
	await _frames(2)


func _wait_until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame
	return cond.call()


func _text_of(node: Node) -> String:
	var out := ""
	for l in node.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out += (l as Label).text + "\n"
	return out


## Talks through the call until the next choice (or its end); returns the text said.
func _talk_until_question(mission: Mission06Controller) -> String:
	var said := ""
	var guard := 0
	while guard < 60:
		await process_frame
		if mission.dialogue.choosing:
			return said + mission.dialogue._text.text + "
"
		if not mission.dialogue.is_open():
			if mission.asking == "" and not mission._busy:
				return said
			guard += 1
			continue
		said += mission.dialogue._text.text + "
"
		mission.dialogue.advance(true)
		mission.dialogue.advance(true)
		guard += 1
	return said


## Answers the call question on screen with its right (or a wrong) button.
func _answer_call(mission: Mission06Controller, right: bool) -> void:
	var q := mission.data.get_question(mission.asking)
	for i in mission.ask_order.size():
		if (mission.ask_order[i] == q.correct_index) == right:
			mission.dialogue.choose(i)
			return


func _test_rules(data: Mission06Data) -> void:
	var s := Mission06State.new()
	s.reset(data)
	_check(s.partner_password == data.partner_password and s.remote_volume == data.start_volume and not s.partner_online, "fresh state: muted, 25 %, partner not ready")
	_check(s.sound_result(data) == "muted", "muted at first")
	s.remote_muted = false
	_check(s.sound_result(data) == "low", "unmuted at 25 %: too quiet")
	s.remote_volume = 80
	_check(s.sound_result(data) == "high", "80 %: too loud")
	s.remote_volume = 60
	_check(s.sound_result(data) == "ok", "60 %: right")
	for id: String in Mission06State.QUESTION_ORDER:
		s.note_question(id, 0, true)
	s.connected_once = true
	s.teacher_confirmed = true
	s.last_end = "disconnect"
	_check(s.work_done() and not s.ready_to_finish(), "work done, TeamViewer still open")
	s.tv_closed = true
	s.computer_off = true
	var best := s.mission_score(60.0, FULL, ZERO)
	_check(best.correctness == 30 and best.process == 50 and best.time == 20 and best.mistakes.is_empty(), "perfect run 30/50/20 (%d/%d/%d)" % [best.correctness, best.process, best.time])

	var w := Mission06State.new()
	w.reset(data)
	w.wrong_id_count = 1
	w.opened_private_file = true
	w.disruptive.append("restart")
	w.ended_before_confirm = true
	w.close_in_session_count = 1
	w.shutdown_with_tv_count = 1
	w.connected_once = true
	w.teacher_confirmed = true
	w.last_end = "disconnect"
	w.computer_off = true
	var bad := w.mission_score(60.0, FULL, ZERO)
	_check(bad.correctness == 30 and bad.process == 0, "every process mistake: 30/0 (%d/%d)" % [bad.correctness, bad.process])
	_check(bad.mistakes.size() == 8 and w.wrong_count() == 6, "6 wrong picks + 2 unanswered chat questions: 8 lines (%d / %d)" % [bad.mistakes.size(), w.wrong_count()])
	_check(MissionScore.time_points(300.0, FULL, ZERO) == 20 and MissionScore.time_points(900.0, FULL, ZERO) == 0, "time: full at 5 min, 0 at 15 min")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://test_validate_progress_m6.json"
	GameProgress.clear()
	var data := load(TeamViewerSim.DATA_PATH) as Mission06Data
	_check(data != null and data.validate_data() == "", "mission data valid")
	_test_rules(data)
	# Short waits for the test (the game uses 10 / 12 s).
	data.mail_delay = 0.5
	data.restart_mail_delay = 0.6

	var flow := root.get_node("GameFlow")
	_check(6 in flow.AVAILABLE, "Level 6 is selectable")
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	flow.configure_level(map, 6)
	root.add_child(map)
	for i in 3:
		await physics_frame
	var mission := map.get_node_or_null("Mission06") as Mission06Controller
	_check(mission != null, "Level 6 has the Mission06 controller")
	if mission == null:
		_finish()
		return
	var manager: ComputerManager = map.get_node("Computers")
	var station := manager.find_host(HOST)
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var desktop := manager.desktop
	_check(map.get_node_or_null("Mission03") == null and map.get_node_or_null("Mission05") == null, "no other mission controllers")
	_check(map.get_node_or_null("TeacherFemale") == null, "the female teacher is in the meeting room (not in the map)")
	_check(station.has_app("teamviewer") and station.has_app("mail"), "IT-PC-01 has TeamViewer and Mail")
	_check(not manager.find_host("STAFF-PC-01").has_app("mail"), "no other computer has Mail")
	_check(TeamViewerSim.shared_state == mission.state and mission.phone.ringing and mission.stage == Mission06Controller.Stage.CALL, "a fresh play: the phone rings")
	_check(station.collision_layer == ComputerStation.COLLISION_LAYER, "IT-PC-01 (the player's own desk computer) is always usable")
	_check(mission.hud.steps.size() == 8 and mission.hud.steps[0][1] == ObjectiveHUD.STEP_ACTIVE, "tracker: 8 steps, the phone first")

	# 1. The call from the meeting room.
	mission.phone.use(player)
	await _frames(2)
	_check(mission.dialogue.is_open() and mission.dialogue._header.text.contains("ห้องประชุมเล็ก"), "the call: the small meeting room")
	# The three choices in the call (objective ก): the program (wrong first),
	# what to ask for, keeping TeamViewer open.
	var said := await _talk_until_question(mission)
	_check(mission.asking == "program" and mission.dialogue._choices.get_child_count() == 4 and mission.dialogue._choices.vertical, "choice 1: which program (4 stacked answers)")
	var names := ""
	for b in mission.dialogue._choices.get_children():
		names += (b as Button).text + " "
	_check(names.contains("TeamViewer") and names.contains("TeamSpeak") and names.contains("After Effects") and names.contains("Adobe Express"), "TeamViewer / TeamSpeak / After Effects / Adobe Express")
	_answer_call(mission, false)
	said += await _talk_until_question(mission)
	_check(mission.asking == "program" and mission.state.question_answers["program"].size() == 1, "wrong program: the teacher reacts, asked again")
	_answer_call(mission, true)
	said += await _talk_until_question(mission)
	_check(mission.asking == "request", "choice 2: what to ask the teacher for")
	_answer_call(mission, true)
	said += await _talk_until_question(mission)
	_check(mission.asking == "keep_open" and mission.dialogue._speaker.text == "ครูสาว", "choice 3: the teacher asks to close TeamViewer")
	_answer_call(mission, true)
	said += await _talk_until_question(mission)
	_check(said.contains("TeamViewer") and said.contains("อีเมล") and said.contains("ก่อนขึ้นนำเสนอ") and said.contains("ขออนุญาต"), "permission asked, ID / Password by e-mail, test before presenting")
	_check(mission.state.question_first_right("request") and mission.state.question_first_right("keep_open") and not mission.state.question_first_right("program"), "call choices recorded")
	await _frames(2)
	_check(mission.stage == Mission06Controller.Stage.MAIL and mission._timing and not mission.phone.ringing, "after the call: wait for the e-mail, timer running")

	# 2. Sit down; the e-mail arrives.
	manager.open_computer(station, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.4).timeout
	_check(await _wait_until(func(): return station.mail.size() == 1, 3.0), "the e-mail arrived")
	await _frames(2)
	_check(desktop._mail_icon.visible and desktop._mail_toast.visible and desktop._mail_toast_label.text.contains(data.mail_subject), "Mail icon and the new-mail notification")
	var mail := desktop.open_mail()
	await _frames(2)
	var body := mail.find_child("MailBody", true, false) as RichTextLabel if mail else null
	_check(body != null and body.text.contains(data.partner_password) and body.text.contains(data.partner_id) and body.selection_enabled, "the e-mail shows the ID and Password (selectable to copy)")
	_check(mission.state.mail_read and mission.stage == Mission06Controller.Stage.OPEN, "e-mail read: step 3")

	# 3. TeamViewer (English like the real one; no checklist).
	var app := desktop.open_teamviewer() as TeamViewerSim
	await _frames(2)
	_check(app != null and mission.app == app and mission.stage == Mission06Controller.Stage.CONNECT, "TeamViewer open: step 4")
	var home := _text_of(app)
	_check(home.contains("Ready to connect (secure connection)") and home.contains("Control Remote Computer") and not home.contains("รายการตรวจสอบ"), "status line, no checklist")

	# 4. Partner ID / Password (a wrong one each, then right).
	_check(not app.connect_partner("123 456 789") and mission.state.wrong_id_count == 1, "wrong Partner ID: recorded")
	_check(app.connect_partner("482731965") and app._auth_card.visible, "ID without spaces: the password window")
	_check(not app.log_on(data.partner_password.to_lower()) and mission.state.wrong_password_count == 1, "password is case-sensitive")
	(app.find_child("PasswordEdit", true, false) as LineEdit).text = data.partner_password + " "
	_check(app.log_on((app.find_child("PasswordEdit", true, false) as LineEdit).text), "pasted password (with a trailing space) works")
	await create_timer(TeamViewerSim.CONNECT_DELAY + 0.3).timeout
	_check(app.view == TeamViewerSim.View.SESSION and _text_of(app).contains("Connected to: MEETING-PC") and mission.stage == Mission06Controller.Stage.FIX, "Remote Session with MEETING-PC: step 5")
	_check(await _wait_until(func(): return app._chat.visible and app.chat_lines().size() == 1, 3.0), "the teacher's first chat message pops the chat open")

	# 5. Asking before fixing; the private file; the sound.
	_check(app.send_chat("ลองเปิดคลิปดูครับ"), "chat sent")
	_check(await _wait_until(func(): return app.chat_lines().size() == 3, 3.0) and app.chat_lines()[2][1] == data.chat_reply_muted, "the teacher: still silent")
	app.open_remote_file(data.private_file)
	_check(mission.state.opened_private_file and (app.find_child("PrivateSheet", true, false) as Control).visible, "the grade file opened: recorded")
	app.open_volume_flyout()
	app.toggle_mute()
	_check(not mission.state.remote_muted and mission.state.sound_result(data) == "low" and mission.stage == Mission06Controller.Stage.FIX, "unmuted: still too quiet")
	app.set_volume(60)
	await _frames(1)
	_check(mission.stage == Mission06Controller.Stage.CONFIRM, "60 %: step 6 (ask the teacher)")

	# Restart of MEETING-PC: the session drops, a new password comes by e-mail.
	app.open_start_menu()
	(app.find_child("PowerButton", true, false) as Button).pressed.emit()
	(app.find_child("PowerRestart", true, false) as Button).pressed.emit()
	await _frames(2)
	_check("restart" in mission.state.disruptive and not mission.state.session_active and not mission.state.partner_online and app._partner_card.visible, "Restart: recorded, session ended, partner offline")
	_check(mission.stage == Mission06Controller.Stage.CONNECT, "back to connecting")
	(app.find_child("PartnerGoneOk", true, false) as Button).pressed.emit()
	_check(not app.connect_partner(data.partner_id) and mission.state.wrong_id_count == 1, "partner offline: no connection, not counted as wrong")
	_check(await _wait_until(func(): return station.mail.size() == 2, 3.0), "the teacher e-mailed the new password")
	await _frames(2)
	_check(mission.stage == Mission06Controller.Stage.MAIL and mission.state.partner_online, "a new e-mail to read")
	desktop.open_mail()
	await _frames(2)
	_check(mission.state.mail_read and mission.stage == Mission06Controller.Stage.CONNECT, "new e-mail read")
	_check(app.connect_partner(data.partner_id) and not app.log_on(data.partner_password) and mission.state.wrong_password_count == 2, "the old password no longer works")
	_check(app.log_on(data.partner_password_after_restart), "the new password works")
	await create_timer(TeamViewerSim.CONNECT_DELAY + 0.3).timeout
	_check(app.view == TeamViewerSim.View.SESSION and mission.stage == Mission06Controller.Stage.CONFIRM, "reconnected; the sound settings stayed")

	# Closing in the middle of a session: refused, recorded.
	_check(not app.try_close() and mission.state.close_in_session_count == 1, "close during the session: refused, recorded")
	# 6. The teacher confirms in the chat.
	app.open_chat()
	var lines_before := app.chat_lines().size()
	app.send_chat("ลองเปิดคลิปอีกครั้งครับ")
	_check(await _wait_until(func(): return mission.state.teacher_confirmed, 3.0) and app.chat_lines()[lines_before + 1][1] == data.chat_reply_ok, "the teacher hears it: confirmed")
	await _frames(1)
	_check(mission.stage == Mission06Controller.Stage.END, "step 7: end the session")

	# Her two questions in the chat, answered with reply buttons.
	_check(await _wait_until(func(): return app.chat_question == "limits", 4.0), "chat question 1: can hardware be fixed remotely?")
	_check(app.find_child("ReplyBox", true, false).get_child_count() == 5, "4 reply buttons")
	var limits := data.get_question("limits")
	app.answer_chat_question((limits.correct_index + 1) % 4)
	_check(await _wait_until(func(): return app.chat_question == "limits" and app.chat_lines()[-1][1] == limits.reactions[(limits.correct_index + 1) % 4], 4.0), "wrong reply: her reaction, asked again")
	(app.find_child("Reply%d" % limits.correct_index, true, false) as Button).pressed.emit()
	_check(await _wait_until(func(): return app.chat_question == "password", 6.0), "chat question 2: does the password still work?")
	app.answer_chat_question(data.get_question("password").correct_index)
	_check(await _wait_until(func(): return app.chat_question == "" and mission.state.question_done["password"], 4.0), "both chat questions answered")

	# 7. End Session -> Disconnect.
	(app.find_child("EndSessionButton", true, false) as Button).pressed.emit()
	_check(app._confirm_card.visible, "End Session asks first")
	(app.find_child("DisconnectButton", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(mission.state.last_end == "disconnect" and not mission.state.ended_before_confirm and mission.stage == Mission06Controller.Stage.CLOSE, "Disconnect after the confirmation: step 8")

	# 8. Switching off with TeamViewer open (recorded), then close and switch off.
	desktop.request_shutdown()
	await _frames(1)
	_check(desktop.visible and mission.state.shutdown_with_tv_count == 1, "switch off with TeamViewer open: refused, recorded")
	_check(app.try_close() and mission.state.tv_closed, "TeamViewer closed")
	await _frames(2)
	desktop.request_shutdown()
	await create_timer(manager.zoom_time + 1.0).timeout
	var score := mission.score
	# Correctness 30. Process: only "waited for the confirmation" 10.
	# Process (10 x 5): request, keep_open, password, confirmed_first = 20.
	_check(score != null and score.correctness == 30 and score.process == 20 and score.time == 20, "score 30/20/20 (%s)" % ["-" if score == null else "%d/%d/%d" % [score.correctness, score.process, score.time]])
	_check(score != null and score.mistakes.size() == 8, "8 mistake lines: %s" % ["-" if score == null else str(score.mistakes)])
	_check(mission.stage == Mission06Controller.Stage.DONE and mission.summary.visible and GameProgress.best_score(6) == score.total(), "summary shown, progress recorded")

	var first_state := mission.state
	map.queue_free()
	await _frames(3)
	_check(TeamViewerSim.shared_state == null, "state released when the level ends")
	var map2: Node3D = load("res://scenes/main.tscn").instantiate()
	flow.configure_level(map2, 6)
	root.add_child(map2)
	for i in 3:
		await physics_frame
	var again := map2.get_node("Mission06") as Mission06Controller
	_check(again.state != first_state and TeamViewerSim.shared_state == again.state and not again.state.call_answered and (map2.get_node("Computers") as ComputerManager).find_host(HOST).mail.is_empty(), "replay starts fresh, empty inbox")
	map2.queue_free()
	await _frames(3)

	_check(logger.errors.is_empty(), "no errors logged" + ("" if logger.errors.is_empty() else ":\n" + "\n".join(logger.errors)))
	GameProgress.clear()
	_finish()


func _finish() -> void:
	if failures == 0:
		print("MISSION_06_VALID")
		quit()
	else:
		print("MISSION_06_INVALID failures=", failures)
		quit(1)
