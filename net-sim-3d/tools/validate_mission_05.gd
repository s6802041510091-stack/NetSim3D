extends SceneTree

## Mission 5 checks (v2.1, 2026-11-15): scoring rules, then the whole level
## played headless (phone -> PC-R3-L2 -> Windows Security: Firewall alerts,
## rules, scan, quarantine, history -> tell the teacher + report choice -> summary).
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_05.gd
## Prints MISSION_05_VALID / MISSION_05_INVALID at the end.

const TARGET := "PC-R3-L2"
const FULL := Mission05Controller.TIME_FULL_SEC
const ZERO := Mission05Controller.TIME_ZERO_SEC
const SCHOOL := Mission05State.ALERT_SCHOOL
const UNKNOWN := Mission05State.ALERT_UNKNOWN


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


## Answers the teacher's question with its right (or a wrong) button.
func _answer(mission: Mission05Controller, right: bool) -> void:
	var q := mission.data.get_question(mission.asking)
	for i in mission._order.size():
		if (mission._order[i] == q.correct_index) == right:
			mission.dialogue.choose(i)
			return


func _test_rules() -> void:
	var s := Mission05State.new()
	s.note_section("firewall")
	_check(s.conn_tool_first == "firewall" and s.next_alert() == SCHOOL, "Firewall first; SchoolLab alert comes first")
	_check(not s.note_alert(UNKNOWN, "block"), "the second alert waits for the first")
	_check(s.note_alert(SCHOOL, "allow_private") and s.next_alert() == UNKNOWN, "SchoolLab: Allow on Private is right")
	_check(not s.can_scan(), "no scan before both alerts")
	_check(s.note_alert(UNKNOWN, "block") and s.alerts_done() and s.can_scan(), "Unknown_Update.exe: Cancel is right; scan opens")
	s.note_section(Mission05State.TOOL_RULES)
	_check(s.rules_checked and s.file_tool_first == "", "rules checked (a Firewall page: not the file decision)")
	s.note_section("virus")
	s.scan_status = Mission05State.ScanStatus.SCANNED
	s.note_threat("quarantine")
	s.note_section("history")
	_check(s.history_checked, "Protection history checked after the quarantine")
	_check(s.note_submit(), "perfect run: report accepted")
	s.told_teacher = true
	_check(s.pending_question() == "report", "the report choice after talking to the teacher")
	s.note_question("report", 0, true)
	var best := s.mission_score(60.0, FULL, ZERO)
	_check(best.correctness == 30 and best.process == 50 and best.time == 20 and best.mistakes.is_empty(), "perfect run 30/50/20 (%d/%d/%d) %s" % [best.correctness, best.process, best.time, best.mistakes])
	_check(best.decisions_correct == 6 and best.decisions_total == 6, "6 process decisions")

	var early_rules := Mission05State.new()
	early_rules.note_section(Mission05State.TOOL_RULES)
	_check(not early_rules.rules_checked and early_rules.conn_tool_first == "firewall", "rules page before the alerts: not the check (counts as Firewall)")

	var both := Mission05State.new()
	_check(both.note_alert(SCHOOL, "allow_both") and both.alert_tries(SCHOOL) == 1, "Private + Public is accepted (no harm in real life)")
	_check(Mission05State.alert_answer(true, false, true) == "allow_public" and not Mission05State.is_alert_right(SCHOOL, "allow_public"), "Public only (no Private) is wrong")
	_check(not Mission05State.is_alert_right(SCHOOL, "allow_none"), "no network ticked is wrong")

	var w := Mission05State.new()
	_check(not w.note_submit() and w.submit_first == "early", "submit before Protected is refused")
	w.note_section("account")
	w.note_section("firewall")
	w.note_alert(SCHOOL, "block")
	w.note_alert(SCHOOL, "allow_none")
	w.note_alert(SCHOOL, "allow_private")
	w.note_alert(UNKNOWN, "allow_private")
	w.note_firewall_off()
	w.note_alert(UNKNOWN, "block")
	w.note_section("app")
	w.note_section("virus")
	_check(w.conn_tool_first == "account" and w.file_tool_first == "app", "wrong first sections recorded")
	w.scan_status = Mission05State.ScanStatus.SCANNED
	w.note_threat("realtime_off")
	w.note_threat("remove")
	w.note_threat("quarantine")
	_check(w.note_submit(), "report accepted once Protected")
	w.told_teacher = true
	w.note_question("report", 1, false)
	w.note_question("report", 0, true)
	var bad := w.mission_score(60.0, FULL, ZERO)
	# SchoolLab 3rd try 0 + Unknown 2nd try 5 + Quarantine 3rd try 0 = 5; process 0.
	_check(bad.correctness == 5 and bad.process == 0, "mistakes: correctness 5, process 0 (%d/%d)" % [bad.correctness, bad.process])
	# school 2 + unknown 1 + 2 sections + switch 1 + threat 2 + early 1 + report 1
	_check(w.wrong_count() == 10, "10 wrong picks (%d)" % w.wrong_count())
	_check(bad.mistakes.size() == 12, "12 mistake lines (%d): %s" % [bad.mistakes.size(), bad.mistakes])
	_check(MissionScore.time_points(420.0, FULL, ZERO) == 20 and MissionScore.time_points(1020.0, FULL, ZERO) == 0, "time: full at 7 min, 0 at 17 min")


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

	# The class (user 2026-11-15): nobody in the corridor but the housekeeper;
	# six students work at their PCs, PC-R3-L2's owner stands beside it.
	var corridor := map.get_node("CorridorStudents") as StudentLife
	_check(corridor.students.is_empty() and corridor.cleaner != null, "no students in the corridor (the housekeeper stays)")
	var holder := map.get_node_or_null(ClassroomStudents.NODE)
	_check(holder != null and holder.get_child_count() == ClassroomStudents.SEATS.size(), "%d students in the computer room" % ClassroomStudents.SEATS.size())
	for id: String in ClassroomStudents.SEATS:
		var s := holder.get_node_or_null(id) as NpcCharacter if holder else null
		var host: String = ClassroomStudents.SEATS[id]
		if id == ClassroomStudents.WATCHER:
			continue
		_check(s != null and s.seated and s.global_position.distance_to(ClassroomStudents.seat_of(host)) < 0.05 and host in manager.npc_used_hosts and manager.find_host(host).collision_layer == 0, "%s works at %s" % [id, host])
	var watcher := mission.watcher
	_check(watcher != null and not ClassroomStudents.WATCHER_HOST in manager.npc_used_hosts, "PC-R3-L2 stays free for the player")
	_check(await _wait_until(func(): return mission.watcher_state == "watching", 6.0), "PC-R3-L2's owner gets up and stands beside it")
	_check(watcher != null and not watcher.seated and watcher.global_position.distance_to(ClassroomStudents.WATCH_SPOT) < 0.1, "standing at the watching spot")

	# 1. The call (the teacher needs SchoolLab Classroom).
	mission.phone.use(player)
	await _frames(2)
	_check(mission.dialogue.is_open(), "the call opens")
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	_check(mission.dialogue._text.text.contains("SchoolLab Classroom"), "the teacher says the class needs SchoolLab Classroom")
	await _finish_dialogue(mission.dialogue)
	await _frames(2)
	_check(mission.stage == Mission05Controller.Stage.GO and mission._timing and not mission.phone.ringing, "after the call: go to PC-R3-L2, timer running")
	_check(target.collision_layer == ComputerStation.COLLISION_LAYER, "the computer can be used now")
	_check(mission.hud.steps[0][1] == ObjectiveHUD.STEP_DONE and mission.hud.steps[1][1] == ObjectiveHUD.STEP_ACTIVE, "step 1 green, step 2 current")

	# Walking into the computer room: the teacher greets the player at once.
	_check(not mission.greeted and not mission.dialogue.is_open(), "no greeting outside the room")
	player.global_position = Vector3(-1.6, 0.02, -6.5)
	_check(await _wait_until(func(): return mission.dialogue.is_open() and mission.dialogue._text.text.contains("คุณช่างมาพอดีเลย"), 2.0), "inside the room: the teacher greets the player")
	_check(mission.greeted and player.controls_locked and mission.dialogue._speaker.text == Mission05Controller.TEACHER, "the greeting holds the player for a moment")
	await _finish_dialogue(mission.dialogue)
	await _frames(3)
	_check(not player.controls_locked and not mission.dialogue.is_open(), "free to move after the greeting")
	# Only once.
	player.global_position = Vector3(-4.4, 0.02, -6.5)
	await _frames(3)
	player.global_position = Vector3(-1.6, 0.02, -6.5)
	await _frames(5)
	_check(not mission.dialogue.is_open(), "the greeting comes only once")

	# The teacher points the player at the computer.
	mission._on_teacher_talked(player)
	await create_timer(0.8).timeout
	_check(mission.dialogue.is_open() and mission.dialogue._text.text.contains("PC-R3-L2"), "the teacher says which computer")
	await _finish_dialogue(mission.dialogue)
	await create_timer(0.6).timeout

	# 2. Sit at PC-R3-L2: no quiz, no alert on the desktop (user 2026-11-15).
	await _boot(manager, target, player)
	_check(desktop.visible and desktop._winsec_icon.visible and desktop._security_toast.visible, "desktop with the icon and the warning pop-up")
	_check(mission.stage == Mission05Controller.Stage.OPEN and not mission.dialogue.is_open(), "step 3: open Windows Security (nothing asked on the desktop)")

	# 3. The program (Windows 11 look, English).
	var app := desktop.open_windows_security() as WindowsSecurity
	await _frames(2)
	_check(app != null and mission.app == app and mission.stage == Mission05Controller.Stage.FIREWALL, "program open, step 4")
	_check(not app.alert_visible(), "no alert before the Firewall page")
	var home := _text_of(app)
	_check(home.contains("Security at a glance") and home.count("Actions recommended.") == 2, "Home: Firewall and Virus tiles say Actions recommended")
	for nav in ["Nav_HOME", "Nav_VIRUS", "Nav_ACCOUNT", "Nav_FIREWALL", "Nav_APP", "Nav_DEVICE", "Nav_HEALTH", "Nav_FAMILY", "Nav_HISTORY", "Nav_SETTINGS"]:
		_check(app.find_child(nav, true, false) != null, "sidebar: " + nav)
	_check(not home.contains("ต้องดำเนินการ") and not home.contains("ปัญหาที่พบ"), "no Thai inside the program")

	# Early submit: refused with a hint (process 5 lost).
	(app.find_child("SubmitButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not mission.state.report_submitted and mission.state.submit_first == "early" and app.current_hint() == WindowsSecurity.SUBMIT_EARLY_HINT, "early submit refused with a hint")

	# Virus first: process 1 lost; Quick scan waits for the alerts.
	app.open_page(WindowsSecurity.Page.VIRUS)
	_check(mission.state.conn_tool_first == "virus", "opened Virus first: process 1 lost")
	var quick := app.find_child("QuickScanButton", true, false) as Button
	_check(quick != null and quick.disabled and not app.start_scan(), "Quick scan waits for the firewall alerts")

	# 4. Firewall page: the alerts come up here.
	app.open_page(WindowsSecurity.Page.FIREWALL)
	var alerts := app.alerts()
	_check(alerts != null and app.alert_visible() and alerts.current_alert() == SCHOOL and mission.state.conn_matched, "the SchoolLab alert pops up on the Firewall page")
	_check((alerts.find_child("AlertBehind", true, false) as Control).visible, "the second alert peeks out behind it")
	_check((alerts.find_child("Info_Name", true, false) as Label).text == data.school_app and (alerts.find_child("Info_Publisher", true, false) as Label).text == data.school_publisher, "SchoolLab: name and publisher")
	_check((alerts.find_child("PrivateBox", true, false) as CheckBox).button_pressed and not (alerts.find_child("PublicBox", true, false) as CheckBox).button_pressed, "Private ticked by default, Public not")
	var fw := _text_of(app)
	_check(fw.contains("Private network (active)") and not fw.contains("Public network (active)"), "the school network is Private (active)")

	# SchoolLab: Cancel (wrong), Public only (wrong), close + Review, Private + Public.
	_check(not alerts.press(false) and alerts.current_hint() == data.school_block_hint, "SchoolLab Cancel: not applied, hint")
	_check(not alerts.current_hint().contains("Allow"), "hint does not give the answer")
	_check(not alerts.press(true, false, true) and alerts.current_hint() == data.school_no_private_hint, "Allow on Public only: hint about the network type")
	(alerts.find_child("AlertClose", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(not app.alert_visible() and app.find_child("ReviewButton", true, false) != null, "alert closed; Review button stays")
	(app.find_child("ReviewButton", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(app.alert_visible() and alerts.current_alert() == SCHOOL, "Review brings it back")
	_check(alerts.press(true, true, true), "Private + Public: accepted")
	_check(alerts.current_hint() == "" and alerts.current_note() == data.school_public_note, "a note (not a hint) about Public")
	await _frames(1)
	var behind := alerts.find_child("AlertBehind", true, false) as Control
	_check(alerts.current_alert() == UNKNOWN and (behind == null or not behind.visible), "Unknown_Update.exe now in front")
	_check((alerts.find_child("Info_Path", true, false) as Label).text == data.firewall_path, "Unknown_Update.exe: the Downloads path")

	# Unknown_Update.exe: Allow (wrong); the firewall switch (wrong); close and
	# open the page again; then Cancel.
	_check(not alerts.press(true) and alerts.current_hint() == data.get_firewall_choice("allow").hint, "Unknown_Update.exe Allow: hint about the unknown publisher")
	app.open_profile("Private")
	await _frames(1)
	(app.find_child("FirewallToggle", true, false).get_node("Switch") as Button).pressed.emit()
	await _frames(2)
	_check(mission.state.firewall_off_count == 1 and app.current_hint() == data.get_firewall_choice("disable").hint, "switch off: recorded, hint")
	_check(app.find_child("FirewallToggle", true, false).get_node("Switch").get_meta("on") == true, "the switch is back on")
	app.close_program()
	await _frames(2)
	app = desktop.open_windows_security() as WindowsSecurity
	await _frames(2)
	_check(app.state == mission.state and not mission.state.alerts_done() and mission.state.alert_done(SCHOOL), "reopened: progress kept")
	app.open_page(WindowsSecurity.Page.FIREWALL)
	alerts = app.alerts()
	_check(app.alert_visible() and alerts.current_alert() == UNKNOWN, "the Unknown_Update.exe alert again on the Firewall page")
	_check(alerts.press(false), "Unknown_Update.exe Cancel is right")
	await _frames(2)
	_check(mission.state.alerts_done() and not app.alert_visible(), "both alerts answered")
	_check(mission.stage == Mission05Controller.Stage.SCAN and mission.hud.steps[3][1] == ObjectiveHUD.STEP_DONE, "step 4 green, step 5 current")
	fw = _text_of(app)
	_check(fw.contains("Unauthorized connection blocked") and fw.contains("allowed on private and public networks"), "Firewall page: blocked + SchoolLab allowed")

	# The check (process 2): Allow an app through firewall.
	(app.find_child("Link_Allowanappthroughfirewall", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(app.page == WindowsSecurity.Page.ALLOWED_APPS and mission.state.rules_checked, "Allowed apps opened: rules checked")
	var school_rule := app.find_child("Rule_SchoolLabClassroom", true, false) as CheckBox
	var unknown_rule := app.find_child("Rule_Unknown_Updateexe", true, false) as CheckBox
	_check(school_rule != null and school_rule.button_pressed and unknown_rule != null and not unknown_rule.button_pressed, "SchoolLab allowed, Unknown_Update.exe not")
	_check(mission.state.file_tool_first == "", "the rules page is not the file decision")

	# 5. Virus & threat protection first (process 3), Quick scan.
	app.open_page(WindowsSecurity.Page.HOME)
	_check(_text_of(app).count("Actions recommended.") == 1, "Home: Firewall tile green now")
	(app.find_child("TileVirus", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(app.page == WindowsSecurity.Page.VIRUS and mission.state.file_tool_first == "virus", "file problem -> Virus first: process 3")
	quick = app.find_child("QuickScanButton", true, false) as Button
	_check(quick != null and not quick.disabled, "Quick scan enabled")
	quick.pressed.emit()
	_check(app.scanning, "scan starts")
	await create_timer(2.0).timeout
	_check(app.scanning and _text_of(app).contains("Quick scan running"), "still scanning after 2 s (design: 3–5 s)")
	await create_timer(data.scan_seconds - 2.0 + 0.4).timeout
	var av := _text_of(app)
	_check(not app.scanning and av.contains("Threats found") and av.contains(data.threat_name), "scan result")
	await _frames(2)
	_check(mission.stage == Mission05Controller.Stage.QUARANTINE, "step 6: handle the file")

	# Exclusions trap.
	(app.find_child("Link_Managesettings", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("Link_Addorremoveexclusions", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("AddExclusionButton", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("Exclude_File", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("File_Student_Game_Crack", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("PickerOpen", true, false) as Button).pressed.emit()
	await _frames(2)
	_check("exclude" in mission.state.threat_choices and app.current_hint() == data.get_threat_choice("exclude").hint, "Add an exclusion: recorded, hint")

	# 6. The threat: details with two files; Quarantine.
	app.open_page(WindowsSecurity.Page.VIRUS)
	(app.find_child("ThreatRow", true, false) as Button).pressed.emit()
	await _frames(1)
	av = _text_of(app)
	_check(av.contains(data.threat_path) and av.contains(data.firewall_path), "details: both files (the crack dropped Unknown_Update.exe)")
	(app.find_child("Action_quarantine", true, false) as CheckBox).button_pressed = true
	(app.find_child("StartActionsButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(mission.state.threat_quarantined and _text_of(app).contains("No current threats.") and not target.screen_alert, "quarantined, warning screen gone")
	_check(mission.stage == Mission05Controller.Stage.SUBMIT and not mission.dialogue.is_open(), "step 7, nothing asked on the computer")

	# 7. Protection history (process 5), Home all green, submit.
	app.open_page(WindowsSecurity.Page.HISTORY)
	_check(app.find_child("HistoryEntry", true, false) != null and _text_of(app).contains("Affected items: 2") and mission.state.history_checked, "Protection history: quarantined, 2 items, checked")
	app.open_page(WindowsSecurity.Page.HOME)
	home = _text_of(app)
	_check(not home.contains("Actions recommended.") and not home.contains("Threats found"), "Home: every tile green")
	(app.find_child("SubmitButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(mission.state.report_submitted and mission.stage == Mission05Controller.Stage.TELL, "report accepted, step 8: tell the teacher")
	await create_timer(app.exit_delay + manager.zoom_time + 0.5).timeout
	_check(not desktop.visible and not player.controls_locked, "back to first person after submitting")
	_check(target.collision_layer == 0, "PC-R3-L2 is its owner's again")
	_check(await _wait_until(func(): return mission.watcher_state == "seated", 10.0), "the owner sits down at PC-R3-L2")
	_check(watcher.seated and watcher.global_position.distance_to(ClassroomStudents.seat_of(ClassroomStudents.WATCHER_HOST)) < 0.05, "seated at his PC")
	_check(mission.marker.target == teacher, "arrow on the teacher")

	# 8. Tell the teacher; his question (wrong, then right) -> summary.
	mission._on_teacher_talked(player)
	_check(await _wait_until(func(): return mission.dialogue.is_open() and mission.dialogue._text.text.contains("PC-R3-L2"), 3.0), "the teacher asks how PC-R3-L2 is")
	await _finish_dialogue(mission.dialogue)
	_check(await _wait_until(func(): return mission.asking == "report" and mission.dialogue.choosing, 2.0), "the player chooses what to report")
	_check(mission.dialogue._choices.vertical and mission.dialogue._choices.get_child_count() == 4 and player.controls_locked, "4 answers, one per row; the player stays put")
	_answer(mission, false)
	_check(await _wait_until(func(): return mission.asking == "report" and mission.dialogue.choosing, 2.0), "wrong report: asked again")
	_check(mission.dialogue._header.text.contains(data.get_question("report").hint), "with the hint above it")
	_answer(mission, true)
	_check(await _wait_until(func(): return mission.dialogue.is_open() and not mission.dialogue.choosing and mission.dialogue._speaker.text == "คุณ" and mission.dialogue._text.text.contains("SchoolLab"), 3.0), "the player says the chosen report")
	mission.dialogue.advance(true)
	mission.dialogue.advance(true)
	_check(mission.dialogue._speaker.text == Mission05Controller.TEACHER and mission.dialogue._text.text.contains("ดาวน์โหลดโปรแกรมภายนอก"), "the teacher will warn the students about outside downloads")
	await _finish_dialogue(mission.dialogue)
	await _frames(3)
	var score := mission.score
	# Correctness: SchoolLab 3rd try 0 + Unknown 2nd try 5 + Quarantine 2nd
	# (after the exclusion) 5 = 10. Process: rules 10 + Virus first 10 = 20
	# (Virus opened before Firewall, switch off + exclusion, early submit,
	# report wrong first).
	_check(score != null and score.correctness == 10 and score.process == 20 and score.time == 20, "score 10/20/20 (%s)" % ["-" if score == null else "%d/%d/%d" % [score.correctness, score.process, score.time]])
	_check(score != null and score.mistakes.size() == 8, "8 mistake lines: %s" % ["-" if score == null else str(score.mistakes)])
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
	_check(again.state != first_state and WindowsSecurity.shared_state == again.state and not again.state.alerts_done() and (map2.get_node("Computers") as ComputerManager).find_host(TARGET).screen_alert, "replay starts fresh, warning screen back")
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
