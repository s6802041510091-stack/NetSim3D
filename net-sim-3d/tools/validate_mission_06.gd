extends SceneTree

## Headless check for Mission 6 — phone call + TeamViewer (simulated) in the real map.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_06.gd
## Prints MISSION_06_VALID / MISSION_06_INVALID. Uses its own save file.

const TEST_SAVE := "user://test_validate_mission_06.json"


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
var events: Array[String] = []


func _initialize() -> void:
	OS.add_logger(logger)
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL ", message)


func _text_of(node: Node) -> String:
	var out := ""
	for l in node.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out += (l as Label).text + "\n"
	return out


func _boot(manager: ComputerManager, station: ComputerStation, player: Node) -> void:
	manager.open_computer(station, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.4).timeout


func _leave(manager: ComputerManager) -> void:
	manager.desktop.request_shutdown()
	await create_timer(manager.zoom_time + 0.4).timeout


func _run() -> void:
	Mission06SaveStore.save_path = TEST_SAVE
	Mission06SaveStore.clear()
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 4:
		await physics_frame
	var manager: ComputerManager = map.get_node("Computers")
	var mission: Mission06Controller = map.get_node("Mission06")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var desktop: DesktopOS = manager.desktop
	var data := mission.data
	player.require_mouse_capture = false
	mission.mission_completed.connect(func(s, a, b, c): events.append("done:%d:%d:%d:%d" % [s, a, b, c]))

	# The player's own computer in the IT Support (Data Center) room is the only one with TeamViewer.
	var dc := manager.find_host("IT-PC-01")
	_check(dc != null and dc.has_app("teamviewer"), "IT-PC-01 missing or without TeamViewer")
	_check(not manager.find_host("IT-HEAD-PC").has_app("teamviewer"), "TeamViewer on another computer")
	_check(not manager.find_host("STAFF-PC-01").has_app("teamviewer"), "TeamViewer on a teachers' room computer")
	_check(manager.stations.size() == 29, "expected 29 computers, found %d" % manager.stations.size())
	_check(mission.phone != null and mission.phone.ringing, "phone is not ringing")

	# TeamViewer before the call: the partner is not ready, no points lost.
	await _boot(manager, dc, player)
	_check(desktop._teamviewer_icon.visible, "TeamViewer icon missing")
	var app := desktop.open_teamviewer() as TeamViewerSim
	await process_frame
	_check(app != null and _text_of(app).contains("Control Remote Computer"), "TeamViewer did not open")
	_check(not app.connect_partner("482731965") and app.state.score == 100, "connected before the call / lost points")
	_check(_text_of(app).contains("รับสายโทรศัพท์"), "partner-not-ready message missing")
	_check(app.try_close(), "could not close TeamViewer outside a session")
	await _leave(manager)
	_check(not player.controls_locked, "player still locked after leaving the computer")

	# Walk to the player's desk (chair side, west of the phone), look at the phone, press E.
	var phone_pos := mission.phone.global_position
	player.global_position = Vector3(phone_pos.x - 0.95, 0.02, phone_pos.z)
	for i in 3:
		await physics_frame
	player.look_at(Vector3(phone_pos.x, player.global_position.y, phone_pos.z), Vector3.UP)
	var eye: Vector3 = player.camera.global_position
	player.camera.rotation.x = atan2(phone_pos.y + 0.05 - eye.y, Vector2(phone_pos.x - eye.x, phone_pos.z - eye.z).length())
	for i in 4:
		await physics_frame
	_check(player.focused_interactable == mission.phone, "player does not see the phone")
	_check(player._prompt.text.contains("รับสาย"), "phone prompt missing: " + player._prompt.text)
	player.interact()
	await process_frame
	_check(mission.dialog.is_open() and player.controls_locked, "call did not start")
	var seen := ""
	for i in data.call_lines.size():
		await create_timer(0.3).timeout
		seen += mission.dialog._text.text + "\n"
		mission.dialog.advance()
	await process_frame
	_check(seen.contains("482 731 965") and seen.contains("N7q4P2"), "ID/password not said in the call")
	_check(not mission.dialog.is_open() and not player.controls_locked, "call did not end")
	_check(mission._toast_layer.visible and mission._toast_label.text == data.mission_received_text, "mission-received message missing")
	_check(not mission.phone.ringing and mission.state.call_answered, "phone still ringing / call not saved")

	# Phase 2-4: Partner ID and password.
	await _boot(manager, dc, player)
	app = desktop.open_teamviewer() as TeamViewerSim
	await process_frame
	app.session_started.connect(func(): events.append("session"))
	app.teacher_confirmed.connect(func(): events.append("teacher"))
	_check(not app.connect_partner("") and app.state.score == 100, "empty ID cost points")
	_check(not app.connect_partner("482 731 966") and app.state.score == 95, "wrong ID accepted / score")
	_check(_text_of(app).contains(data.msg_wrong_id) and not _text_of(app).contains("482 731 965"), "wrong-ID message wrong or reveals the ID")
	_check(app.connect_partner("482731965") and app._auth_card.visible, "ID without spaces rejected")
	_check(not app.log_on("n7q4p2") and app.state.score == 90, "password is not case-sensitive / score")
	_check(_text_of(app).contains(data.msg_wrong_password), "wrong-password message missing")
	_check(app.log_on("N7q4P2"), "right password rejected")
	_check(_text_of(app).contains("Connection established"), "Connection established not shown")
	await create_timer(TeamViewerSim.CONNECT_DELAY + 0.3).timeout
	var session_text := _text_of(app)
	_check(app.session_active and "session" in events, "session did not start")
	for want in ["Remote Session", "Connected to: TEACHER-PC", "Session status: Active"]:
		_check(session_text.contains(want), "session bar missing: " + want)
	_check(app.find_child("EndSessionButton", true, false) != null, "End Session button missing")

	# Closing during the session is not allowed (-10 each time).
	_check(not app.try_close() and app.state.score == 80 and app.state.close_without_end_count == 1, "close during session allowed / score")
	desktop.request_shutdown()
	await process_frame
	_check(desktop.visible and app.state.score == 70, "shutdown during session allowed / score")

	# Fix the sound: advice only, no points lost.
	app.open_volume_flyout()
	_check(app._flyout.visible, "volume flyout did not open")
	_check(app.test_sound() == "muted" and app.state.score == 70, "muted test")
	app.toggle_mute()
	_check(app.test_sound() == "low" and app._advice.text == data.msg_volume_low and app.state.score == 70, "low volume advice")
	app.set_volume(90)
	_check(app.test_sound() == "high" and app._advice.text == data.msg_volume_high, "high volume advice")
	app.set_volume(60)
	_check(app.test_sound() == "ok" and app.state.teacher_confirmed and "teacher" in events, "correct volume not accepted")
	_check(_text_of(app).contains(data.teacher_confirm_line), "teacher confirmation missing")

	# End Session -> confirm -> Disconnect.
	app.request_end_session()
	_check(app._confirm_card.visible and _text_of(app).contains(data.msg_end_confirm), "end confirmation missing")
	app.cancel_end_session()
	_check(app.session_active, "cancel ended the session")
	app.request_end_session()
	app.confirm_disconnect()
	await process_frame
	_check(not app.session_active and app.state.session_ended and _text_of(app).contains("Session status: Session ended"), "session not ended")
	desktop.request_shutdown()
	await process_frame
	_check(desktop.visible and app.state.score == 70, "shutdown with TeamViewer open allowed / penalised")
	_check(app.try_close() and not desktop._windows.has("teamviewer"), "TeamViewer did not close")

	# Switch the player's computer off -> summary and mission complete.
	desktop.request_shutdown()
	await create_timer(manager.zoom_time + 0.8).timeout
	_check(mission.summary_visible, "summary not shown")
	var summary := _text_of(mission._summary_layer)
	for want in [data.mission_complete_text, "TeamViewer", "AnyDesk", "AnyDesk Address", "ซอฟต์แวร์ควบคุมระยะไกล", "70 / 100"]:
		_check(summary.contains(want), "summary missing: " + want)
	_check("done:70:1:1:2" in events, "completion signal wrong: " + str(events))
	_check(mission.state.completed and mission.state.computer_off, "completion not saved")
	mission.close_summary()
	_check(not player.controls_locked, "player locked after the summary")

	_check(logger.errors.is_empty(), "errors logged:\n" + "\n".join(logger.errors))
	Mission06SaveStore.clear()
	if failures == 0:
		print("MISSION_06_VALID score=70")
		quit()
	else:
		print("MISSION_06_INVALID failures=", failures)
		quit(1)
