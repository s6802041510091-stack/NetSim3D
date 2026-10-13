extends SceneTree

## Headless check for Mission 5 — Windows Security (simulated).
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_05.gd
## Prints MISSION_05_VALID / MISSION_05_INVALID at the end.
## Uses its own save file, so it never touches a player's real progress.

const TEST_SAVE := "user://test_validate_mission_05.json"
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
		out += (l as Label).text + "\n"
	return out


func _boot(manager: ComputerManager, station: ComputerStation, player: Node) -> void:
	manager.open_computer(station, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.4).timeout


func _run() -> void:
	Mission05SaveStore.save_path = TEST_SAVE
	Mission05SaveStore.clear()
	var data := load(WindowsSecurity.DATA_PATH) as Mission05Data
	_check(data != null and data.validate_data() == "", "mission data invalid: " + (data.validate_data() if data else "missing"))

	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	(map.get_node("Computers") as ComputerManager).mission_05_save_path = TEST_SAVE
	root.add_child(map)
	for i in 3:
		await physics_frame
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var desktop: DesktopOS = manager.desktop

	# Only the target computer has the program and the red warning screen.
	var target := manager.find_host(TARGET)
	_check(target != null and target.has_app("windows_security"), "target computer has no Windows Security")
	_check(target.screen_alert and target.screen.material_override != null, "target screen does not show the warning")
	var other := manager.find_host("PC-R1-L1")
	_check(not other.has_app("windows_security") and not other.screen_alert, "another computer has the program or warning")

	# Phase 2: E at the target -> Set-up -> Desktop with the warning pop-up.
	await _boot(manager, target, player)
	_check(desktop._desktop.visible and desktop._winsec_icon.visible, "desktop/icon missing on target")
	_check(desktop._security_toast.visible, "security warning pop-up not shown")
	var opened := []
	desktop.app_opened.connect(func(id, _app): opened.append(id))
	var app := desktop.open_windows_security() as WindowsSecurity
	_check(app != null and opened == ["windows_security"], "Windows Security did not open")
	await process_frame
	app.firewall_choice_made.connect(func(id, ok): events.append("fw:%s:%s" % [id, ok]))
	app.threat_choice_made.connect(func(id, ok): events.append("av:%s:%s" % [id, ok]))
	app.mistake_made.connect(func(_h, p): events.append("mistake:%d" % p))
	app.protected_reached.connect(func(): events.append("protected"))
	app.report_submitted.connect(func(s, w): events.append("report:%d:%d" % [s, w]))
	_check(_text_of(app).contains("ต้องดำเนินการ"), "home is not red 'ต้องดำเนินการ'")
	_check((app.find_child("SubmitButton", true, false) as Button).disabled, "submit enabled before fixing")
	_check(_text_of(app).contains("จำลองเพื่อการศึกษา"), "simulation note missing")

	# Firewall: wrong, wrong, then block.
	app.open_page(WindowsSecurity.Page.FIREWALL)
	_check(_text_of(app).contains(data.firewall_alert) and _text_of(app).contains("Unknown_Update.exe"), "firewall alert/details missing")
	_check(not app.choose_firewall("allow"), "allow accepted")
	_check(app.state.score == 90 and _text_of(app).contains(data.get_firewall_choice("allow").hint), "allow: hint/score wrong")
	_check(not app.current_hint().contains("ปิดกั้นการเชื่อมต่อ"), "hint gives the answer away")
	_check(not app.choose_firewall("disable"), "disable accepted")
	_check(app.state.score == 80 and app.current_hint() == data.get_firewall_choice("disable").hint, "disable: hint/score wrong")
	_check(app.choose_firewall("block"), "block rejected")
	_check(_text_of(app).contains("Unauthorized connection blocked") and app.find_child("BlockedDiagram", true, false) != null, "blocked result not shown")
	_check(not app.choose_firewall("allow") and app.state.score == 80, "firewall answer changed after it was fixed")

	# Anti-Virus: nothing to quarantine before the scan.
	app.open_page(WindowsSecurity.Page.VIRUS)
	_check(_text_of(app).contains("ยังไม่ได้ตรวจสอบเครื่องในวันนี้"), "not-scanned message missing")
	_check(not app.choose_threat("quarantine"), "quarantine before scan accepted")
	_check(app.start_scan() and app.scanning, "scan did not start")
	await create_timer(2.0).timeout
	_check(app.scanning and app.find_child("ScanBar", true, false) != null, "scan finished too early (design: 3–5 s)")
	await create_timer(data.scan_seconds - 2.0 + 0.4).timeout
	_check(not app.scanning and _text_of(app).contains("Threats found: 1") and _text_of(app).contains("Student_Game_Crack.exe"), "scan result missing")
	_check(not app.choose_threat("allow") and app.state.score == 70, "allow file accepted / score")
	_check(not app.choose_threat("exclude") and app.state.score == 60, "exclusion accepted / score")
	_check(app.current_hint() == data.get_threat_choice("exclude").hint, "exclusion hint wrong")
	_check(app.choose_threat("quarantine"), "quarantine rejected")
	_check(_text_of(app).contains("Threat quarantined") and _text_of(app).contains("Quarantined"), "quarantine result missing")

	# Summary: Protected, warning gone, submit enabled.
	app.open_page(WindowsSecurity.Page.HOME)
	var home := _text_of(app)
	for line in ["Security status: Protected", "Firewall is active", "Unauthorized connection blocked", "Virus scan completed", "Threat quarantined"]:
		_check(home.contains(line), "summary missing: " + line)
	_check("protected" in events and not target.screen_alert, "protected signal / screen warning")
	var submit := app.find_child("SubmitButton", true, false) as Button
	_check(submit != null and not submit.disabled, "submit not enabled when protected")

	# Submit -> leave the computer -> first person again.
	submit.pressed.emit()
	_check("report:60:4" in events, "report signal wrong: " + str(events))
	_check(app.state.report_submitted and Mission05SaveStore.has_save(), "report not saved")
	await create_timer(app.exit_delay + manager.zoom_time + 0.4).timeout
	_check(not desktop.visible and not player.controls_locked, "did not return to first person after submitting")

	# Progress is kept: open again -> still Protected, nothing to do, no warning.
	await _boot(manager, target, player)
	_check(not desktop._security_toast.visible, "warning shown after the fix")
	app = desktop.open_windows_security() as WindowsSecurity
	await process_frame
	_check(app.is_protected() and app.state.score == 60 and (app.find_child("SubmitButton", true, false) as Button).disabled, "saved progress not restored")
	_check(app.handle_escape() and not desktop._windows.has("windows_security"), "Esc did not close the program")
	manager.close_computer()
	await create_timer(manager.zoom_time + 0.3).timeout

	var expected := ["fw:allow:false", "fw:disable:false", "fw:block:true", "av:allow:false", "av:exclude:false", "av:quarantine:true"]
	for e in expected:
		_check(e in events, "missing event " + e)
	_check(logger.errors.is_empty(), "errors logged: " + "\n".join(logger.errors))
	Mission05SaveStore.clear()
	if failures == 0:
		print("MISSION_05_VALID score=60 wrong=4")
		quit()
	else:
		print("MISSION_05_INVALID failures=", failures)
		quit(1)
