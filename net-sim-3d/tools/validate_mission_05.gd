extends SceneTree

## Mission 5 checks: scoring rules, then the whole level played headless
## (phone -> PC-R3-L2 -> Windows Security -> tell the teacher -> summary).
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_05.gd
## Prints MISSION_05_VALID / MISSION_05_INVALID at the end.

const TARGET := "PC-R3-L2"


## Collects every engine/script error printed while the test runs.
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


func _boot(manager: ComputerManager, station: ComputerStation, player: Node) -> void:
	manager.open_computer(station, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.4).timeout


func _test_rules() -> void:
	var s := Mission05State.new()
	s.note_section("firewall")
	s.note_firewall("block")
	s.note_section("firewall") # the profile page after the fix does not count for (c)
	s.note_section("virus")
	s.scan_status = Mission05State.ScanStatus.SCANNED
	s.note_threat("quarantine")
	_check(s.note_submit(), "perfect run: report accepted")
	var best := s.mission_score(60.0, 300.0, 900.0)
	_check(best.correctness == 30 and best.process == 50 and best.time == 20 and best.mistakes.is_empty(), "perfect run 30/50/20 (%d/%d/%d)" % [best.correctness, best.process, best.time])

	var w := Mission05State.new()
	_check(not w.note_submit() and w.submit_first == "early", "submit before Protected is refused")
	w.note_section("account")
	w.note_section("firewall")
	_check(w.conn_tool_first == "account" and w.conn_matched, "connection: Account first (wrong), then Firewall")
	w.note_firewall("allow")
	w.note_firewall("disable")
	w.note_firewall("block")
	w.note_section("app")
	w.note_section("virus")
	_check(w.file_tool_first == "app" and w.file_matched, "file: App & browser control first (wrong), then Virus")
	w.scan_status = Mission05State.ScanStatus.SCANNED
	w.note_threat("realtime_off")
	w.note_threat("quarantine")
	_check(w.note_submit(), "report accepted once Protected")
	var bad := w.mission_score(60.0, 300.0, 900.0)
	# Firewall right on the 3rd try 0 + quarantine on the 2nd 8; no decision right.
	_check(bad.correctness == 8 and bad.process == 0, "mistakes: correctness 8, process 0 (%d/%d)" % [bad.correctness, bad.process])
	_check(bad.mistakes.size() == 6 and w.wrong_count() == 6, "6 mistakes listed (%d): %s" % [w.wrong_count(), bad.mistakes])
	_check(MissionScore.time_points(300.0, 300.0, 900.0) == 20 and MissionScore.time_points(900.0, 300.0, 900.0) == 0, "time: full at 5 min, 0 at 15 min")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://test_validate_progress_m5.json"
	GameProgress.clear()
	_test_rules()
	var data := load(WindowsSecurity.DATA_PATH) as Mission05Data
	_check(data != null and data.validate_data() == "", "mission data valid")

	var flow := root.get_node("GameFlow")
	_check(5 in flow.AVAILABLE, "Level 5 is selectable")
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	flow.configure_level(map, 5)
	root.add_child(map)
	for i in 3:
		await physics_frame
	var mission: Mission05Controller = map.get_node_or_null("Mission05")
	_check(mission != null, "Level 5 has the Mission05 controller")
	if mission == null:
		_finish()
		return
	var manager: ComputerManager = map.get_node("Computers")
	var target := manager.find_host(TARGET)
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var teacher := map.get_node("TeacherMale") as NpcCharacter
	var desktop := manager.desktop
	_check(map.get_node_or_null("Mission03") == null and map.get_node_or_null("Mission04") == null and map.get_node_or_null("Mission06") == null, "no other mission controllers")
	_check(target != null and target.has_app("windows_security") and target.screen_alert, "PC-R3-L2 has Windows Security and the red warning screen")
	_check(not manager.find_host("PC-R1-L1").has_app("windows_security") and not manager.find_host("IT-PC-01").has_app("windows_security"), "no other computer has the program")
	_check(teacher != null and teacher.seated and teacher.global_position.distance_to(Mission03Controller.TEACHER_SEAT) < 0.3, "the male teacher works at TEACHER-PC in the computer room")
	_check(WindowsSecurity.shared_state == mission.state and not mission.state.app_opened, "a fresh state for this play")
	_check(mission.phone.ringing and mission.stage == Mission05Controller.Stage.CALL, "the desk phone rings")
	_check(target.collision_layer == 0, "the computer waits for the call (mission order)")
	_check(mission.hud.steps.size() == 8 and mission.hud.steps[0][1] == ObjectiveHUD.STEP_ACTIVE and mission.hud.steps[1][1] == ObjectiveHUD.STEP_TODO, "tracker: 8 steps, the phone first")

	# 1. The call.
	mission.phone.use(player)
	await _frames(2)
	_check(mission.dialogue.is_open(), "the call opens")
	await _finish_dialogue(mission.dialogue)
	await _frames(2)
	_check(mission.stage == Mission05Controller.Stage.GO and mission._timing and not mission.phone.ringing, "after the call: go to PC-R3-L2, timer running")
	_check(target.collision_layer == ComputerStation.COLLISION_LAYER, "the computer can be used now")
	_check(mission.marker.target == null or mission.marker.target != teacher, "arrow on the computer, not the teacher")
	_check(mission.hud.steps[0][1] == ObjectiveHUD.STEP_DONE and mission.hud.steps[1][1] == ObjectiveHUD.STEP_ACTIVE, "step 1 green, step 2 current")

	# The teacher points the player at the computer.
	mission._on_teacher_talked(player)
	await create_timer(0.8).timeout
	_check(mission.dialogue.is_open() and mission.dialogue._text.text.contains("PC-R3-L2"), "the teacher says which computer")
	await _finish_dialogue(mission.dialogue)
	await create_timer(0.6).timeout

	# 2. Sit at PC-R3-L2.
	await _boot(manager, target, player)
	_check(desktop.visible and desktop._winsec_icon.visible and desktop._security_toast.visible, "desktop with the icon and the warning pop-up")
	_check(mission.stage == Mission05Controller.Stage.OPEN, "step 3: open Windows Security")

	# 3. Open the program (Windows 11 look, English).
	var app := desktop.open_windows_security() as WindowsSecurity
	await _frames(2)
	_check(app != null and mission.app == app and mission.stage == Mission05Controller.Stage.FIREWALL, "program open, step 4")
	var home := _text_of(app)
	_check(home.contains("Security at a glance") and app.find_child("Tiles", true, false) != null, "Home: Security at a glance with tiles")
	_check(home.count("Actions recommended.") == 2, "Firewall and Virus tiles both say Actions recommended")
	for nav in ["Nav_HOME", "Nav_VIRUS", "Nav_ACCOUNT", "Nav_FIREWALL", "Nav_APP", "Nav_DEVICE", "Nav_HEALTH", "Nav_FAMILY", "Nav_HISTORY", "Nav_SETTINGS"]:
		_check(app.find_child(nav, true, false) != null, "sidebar: " + nav)
	_check(not home.contains("ต้องดำเนินการ") and not home.contains("ปัญหาที่พบ"), "no Thai inside the program")

	# Early submit (game panel): refused with a hint (decision (e) lost).
	var submit := app.find_child("SubmitButton", true, false) as Button
	_check(submit != null and not submit.disabled, "submit can be pressed")
	submit.pressed.emit()
	await _frames(2)
	_check(not mission.state.report_submitted and mission.state.submit_first == "early" and app.current_hint() == WindowsSecurity.SUBMIT_EARLY_HINT, "early submit refused with a hint")
	_check((app.find_child("HintPanel", true, false) as Control).visible, "the Thai hint shows in the game panel")

	# Virus first (wrong for (a)); Quick scan waits for the firewall.
	app.open_page(WindowsSecurity.Page.VIRUS)
	_check(mission.state.conn_tool_first == "virus", "opened Virus first: decision (a) lost")
	var quick := app.find_child("QuickScanButton", true, false) as Button
	_check(quick != null and quick.disabled and not app.start_scan(), "Quick scan waits for the firewall alert")

	# 4. Firewall: the Windows Security Alert.
	app.open_page(WindowsSecurity.Page.FIREWALL)
	_check(app.alert_visible() and mission.state.conn_matched, "Windows Security Alert pops up on the Firewall page")
	var fw := _text_of(app)
	_check(fw.contains("Windows Defender Firewall has blocked some features of this app") and fw.contains(data.firewall_app), "alert text and app name")
	_check(fw.contains("Domain network") and fw.contains("Private network") and fw.contains("Public network (active)"), "network profiles listed")
	(app.find_child("AllowAccessButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not mission.state.firewall_blocked and app.alert_visible() and app.current_hint() == data.get_firewall_choice("allow").hint, "Allow access: not applied, hint")
	_check(not app.current_hint().contains("Cancel"), "hint does not give the answer")
	(app.find_child("AlertClose", true, false) as Button).pressed.emit()
	_check(not app.alert_visible() and app.find_child("ReviewButton", true, false) != null, "alert closed; Review button stays")

	# Switching the firewall off on the profile page: wrong, switches back on.
	app.open_profile("Public")
	await _frames(1)
	var toggle := app.find_child("FirewallToggle", true, false)
	_check(toggle != null, "Public network: firewall switch")
	(toggle.get_node("Switch") as Button).pressed.emit()
	await _frames(2)
	_check(Mission05State.FIREWALL_OFF in mission.state.firewall_choices and app.current_hint() == data.get_firewall_choice("disable").hint, "switch off: recorded, hint")
	var toggle2 := app.find_child("FirewallToggle", true, false)
	_check(toggle2 != null and toggle2.get_node("Switch").get_meta("on") == true, "the switch is back on")

	# Close and open again mid-way: progress is kept (same play).
	app.close_program()
	await _frames(2)
	app = desktop.open_windows_security() as WindowsSecurity
	await _frames(2)
	_check(app.state == mission.state and mission.state.conn_matched and not mission.state.firewall_blocked, "reopened: progress kept")
	app.open_page(WindowsSecurity.Page.FIREWALL)
	_check(app.alert_visible(), "alert again on the Firewall page")
	(app.find_child("CancelButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(mission.state.firewall_blocked and not app.alert_visible() and _text_of(app).contains("Unauthorized connection blocked"), "Cancel keeps it blocked")
	_check(mission.stage == Mission05Controller.Stage.SCAN and mission.hud.steps[3][1] == ObjectiveHUD.STEP_DONE, "step 4 green, step 5 current")

	# 5. Virus & threat protection, Quick scan.
	app.open_page(WindowsSecurity.Page.HOME)
	_check(_text_of(app).count("Actions recommended.") == 1, "Home: Firewall tile green now")
	(app.find_child("TileVirus", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(app.page == WindowsSecurity.Page.VIRUS and mission.state.file_tool_first == "virus", "file problem -> Virus first: decision (c)")
	quick = app.find_child("QuickScanButton", true, false) as Button
	_check(quick != null and not quick.disabled, "Quick scan enabled")
	quick.pressed.emit()
	_check(app.scanning, "scan starts")
	await create_timer(2.0).timeout
	_check(app.scanning and app.find_child("ScanBar", true, false) != null and _text_of(app).contains("Quick scan running"), "still scanning after 2 s (design: 3–5 s)")
	await create_timer(data.scan_seconds - 2.0 + 0.4).timeout
	var av := _text_of(app)
	_check(not app.scanning and av.contains("Threats found") and av.contains(data.threat_name), "scan result")
	await _frames(2)
	_check(mission.stage == Mission05Controller.Stage.QUARANTINE, "step 6: handle the file")

	# Exclusions trap: Settings -> Exclusions -> Add an exclusion -> File.
	(app.find_child("Link_Managesettings", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(app.page == WindowsSecurity.Page.AV_SETTINGS and _text_of(app).contains("Real-time protection"), "Virus & threat protection settings")
	(app.find_child("Link_Addorremoveexclusions", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("AddExclusionButton", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("Exclude_File", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(app.picker_visible(), "file picker (Downloads)")
	(app.find_child("File_Student_Game_Crack", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("PickerOpen", true, false) as Button).pressed.emit()
	await _frames(2)
	_check("exclude" in mission.state.threat_choices and not app.picker_visible() and app.current_hint() == data.get_threat_choice("exclude").hint, "Add an exclusion: recorded, hint")

	# 6. The threat: Remove (wrong), then Quarantine.
	app.open_page(WindowsSecurity.Page.VIRUS)
	(app.find_child("ThreatRow", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(_text_of(app).contains(data.threat_path), "threat details: affected file")
	var start := app.find_child("StartActionsButton", true, false) as Button
	_check(start != null and start.disabled, "Start actions waits for a choice")
	(app.find_child("Action_remove", true, false) as CheckBox).button_pressed = true
	(app.find_child("StartActionsButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not mission.state.threat_quarantined and app.current_hint() == data.get_threat_choice("remove").hint, "Remove: not applied, hint")
	_check(app.find_child("Action_quarantine", true, false) != null, "the details stay open to choose again")
	(app.find_child("Action_quarantine", true, false) as CheckBox).button_pressed = true
	(app.find_child("StartActionsButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(mission.state.threat_quarantined and _text_of(app).contains("No current threats.") and app.current_hint() == "", "quarantined, no current threats")
	_check(not target.screen_alert, "the red warning screen is gone")
	_check(mission.stage == Mission05Controller.Stage.SUBMIT, "step 7: check status and submit")
	app.open_page(WindowsSecurity.Page.HISTORY)
	_check(app.find_child("HistoryEntry", true, false) != null and _text_of(app).contains("Threat quarantined"), "Protection history: Threat quarantined")

	# 7. Home all green, submit -> back to first person.
	app.open_page(WindowsSecurity.Page.HOME)
	home = _text_of(app)
	_check(not home.contains("Actions recommended.") and not home.contains("Threats found"), "Home: every tile green")
	(app.find_child("SubmitButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(mission.state.report_submitted and mission.stage == Mission05Controller.Stage.TELL, "report accepted, step 8: tell the teacher")
	_check(_text_of(app).contains("แจ้งผลกับครูประจำห้องคอมพิวเตอร์"), "the game panel says to tell the teacher")
	await create_timer(app.exit_delay + manager.zoom_time + 0.5).timeout
	_check(not desktop.visible and not player.controls_locked, "back to first person after submitting")
	_check(mission.marker.target == teacher, "arrow on the teacher")

	# 8. Tell the teacher -> summary.
	mission._on_teacher_talked(player)
	await create_timer(0.8).timeout
	_check(mission.dialogue.is_open() and mission.dialogue._text.text.contains("ปิดกั้นการเชื่อมต่อ"), "the report dialogue")
	await _finish_dialogue(mission.dialogue)
	await _frames(3)
	var score := mission.score
	# Firewall: allow, disable, block -> 3rd try 0. Threat: exclude, remove,
	# quarantine -> 3rd try 0. Process: only (c) Virus right after the firewall.
	_check(score != null and score.correctness == 0 and score.process == 10, "score: correctness 0, process 10 (%s)" % ["-" if score == null else "%d/%d/%d" % [score.correctness, score.process, score.time]])
	_check(score != null and score.mistakes.size() == 6, "6 mistake lines: %s" % ["-" if score == null else str(score.mistakes)])
	_check(mission.stage == Mission05Controller.Stage.DONE and mission.summary.visible and GameProgress.best_score(5) == score.total(), "summary shown, progress recorded")

	var first_state := mission.state
	map.queue_free()
	await _frames(3)
	_check(WindowsSecurity.shared_state == null, "state released when the level ends")

	# Replay: a new play starts fresh with the warning again.
	var map2: Node3D = load("res://scenes/main.tscn").instantiate()
	flow.configure_level(map2, 5)
	root.add_child(map2)
	for i in 3:
		await physics_frame
	var again: Mission05Controller = map2.get_node("Mission05")
	_check(again.state != first_state and WindowsSecurity.shared_state == again.state and not again.state.firewall_blocked and (map2.get_node("Computers") as ComputerManager).find_host(TARGET).screen_alert, "replay starts fresh, warning screen back")
	map2.queue_free()
	await _frames(3)

	_check(logger.errors.is_empty(), "no errors logged" + ("" if logger.errors.is_empty() else ":\n" + "\n".join(logger.errors)))
	GameProgress.clear()
	_finish()


func _finish() -> void:
	if failures == 0:
		print("MISSION_05_VALID")
		quit()
	else:
		print("MISSION_05_INVALID failures=", failures)
		quit(1)
