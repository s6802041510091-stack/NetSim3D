extends SceneTree

## Headless check for Mission 1 — NetPlan EDU and the Level 1 flow.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_01.gd
## Prints one line per test item and MISSION_01_VALID / MISSION_01_INVALID at the end.
## Uses its own save and progress files, so it never touches a player's real data.

const APP_SCENE := "res://missions/mission_01/scenes/netplan_edu.tscn"
const TEST_SAVE := "user://test_validate_mission_01.json"
const TEST_PROGRESS := "user://test_validate_progress.json"
const FULL_NAMES := ["Router", "Wireless Access Point", "Switched Hub 24 Port", "Shared Hub 24 Port",
	"Switched Hub 16 Port", "Switched Hub 8 Port", "Repeater", "Bridge"]
const FORBIDDEN_WORDS := ["Topology", "Straight-Through", "Crossover", "Half-Duplex", "Full-Duplex",
	"IP Address", "Subnet", "Server", "Firewall", "Load Balancer", "Patch Panel"]
const CHOOSE := Mission01Data.DECISION_CHOOSE
const REJECT := Mission01Data.DECISION_REJECT


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
var results := {}
var logger := ErrorCounter.new()
var data: Mission01Data


func _initialize() -> void:
	OS.add_logger(logger)
	call_deferred("_run")


func _check(item: int, ok: bool, message: String) -> void:
	if not results.has(item):
		results[item] = true
	if not ok:
		results[item] = false
		failures += 1
		push_warning("MISSION 1 CHECK FAILED [%02d]: %s" % [item, message])
		print("  FAIL [%02d] %s" % [item, message])


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## Real mouse click (move, press, release) at a screen position.
## Pass a Control to click its centre after the layout has settled.
func _click(target: Variant) -> void:
	await _frames(2)
	var at: Vector2 = target if target is Vector2 else (target as Control).get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move)
	await _frames(1)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	root.push_input(up)
	await _frames(2)


func _press_key(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _press_interact() -> void:
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = &"interact"
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(1)


## Index of the right reason (or the first one when there is none).
func _reason(point: int, device: String, decision: String, right: bool = true) -> int:
	var options := data.reason_options(point, device, decision)
	for i in options.size():
		if bool(options[i].get("correct", false)) == right:
			return i
	return 0


## Rule-level answer: decide + reason, then (for "choose") set the device and quantity.
func _answer(s: Mission01State, point: int, device: String, quantity: int = 1, right_reason: bool = true) -> bool:
	if not s.record_reason(point, device, CHOOSE, _reason(point, device, CHOOSE, right_reason), data):
		return false
	return s.set_answer(point, device, quantity)


func _run() -> void:
	# Headless windows start at 64x64; use the smallest supported screen, 1:1 pixels.
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	Mission01SaveStore.save_path = TEST_SAVE
	Mission01SaveStore.clear()
	GameProgress.save_path = TEST_PROGRESS
	GameProgress.clear()
	data = load(NetPlanEdu.DATA_PATH) as Mission01Data

	_test_data_and_rules()
	_test_score_and_progress()
	await _test_program()
	await _test_in_game()
	_test_web_safety()

	Mission01SaveStore.clear()
	GameProgress.clear()
	_check(1, logger.errors.is_empty(), "errors were printed: " + " | ".join(logger.errors))

	var names := {
		1: "ไม่มี error", 2: "เปิด Scene ภารกิจได้ และพอดีจอ 1280x720", 3: "Setup ประมาณ 2 วินาที", 4: "NetPlan EDU ติดตั้งหลังรับภารกิจเท่านั้น",
		5: "เปิด NetPlan EDU + ไฟล์ Project", 6: "คลิกจุดที่ 1–3 ได้ แต่ละจุดมี 4 อุปกรณ์", 7: "เลือก/ไม่เลือก + เหตุผล + จำนวน",
		8: "เส้นทาง LAN แสดงและแก้ไขไม่ได้", 9: "ความคืบหน้า 0/3 → 3/3", 10: "แจ้งเตือนเมื่อเลือกไม่ครบ",
		11: "ไม่เฉลยก่อนตรวจ", 12: "สถานะถูก/ผิดหลังตรวจ (อุปกรณ์ + จำนวน)", 13: "คะแนนความถูกต้อง 30 หักถูกต้อง", 14: "คะแนนไม่ติดลบ",
		15: "คะแนนรวม 30/50/20 ดาว และจุดที่ผิดพลาด", 16: "บันทึกข้อมูลได้", 17: "ออกจากคอมแล้วผู้เล่นควบคุมได้",
		18: "Esc ปิด Popup → โปรแกรม → ออกจากคอม", 19: "ไม่มีส่วนที่ขัดกับ Web Export",
		20: "คุยกับหัวหน้างาน รับภารกิจ และรายงานผล", 21: "หน้าสรุปผล + บันทึกความก้าวหน้า/ปลดล็อก", 22: "Wall Rack ว่างในห้องคอม",
		23: "ลูกศรสีทองชี้เป้าหมายตามขั้นตอน", 24: "แถบภารกิจพับ/เปิดด้วย Tab และพับเองตอนใช้คอม",
	}
	for i in range(1, 25):
		var ok: bool = results.get(i, false)
		print("%s [%02d] %s" % ["PASS" if ok else "FAIL", i, names[i]])
	if failures == 0:
		print("MISSION_01_VALID items=24")
		quit()
	else:
		print("MISSION_01_INVALID failures=", failures)
		quit(1)


# ================================================================ rules (no UI)

func _test_data_and_rules() -> void:
	_check(13, data.validate_data() == "", "mission data invalid: " + data.validate_data())
	for q in data.questions:
		_check(6, q.options.size() == 4, "point %d should have 4 devices" % q.point_id)
		_check(7, q.correct_quantity == 1, "point %d quantity" % q.point_id)
		for option in q.options:
			_check(11, option in FULL_NAMES, "option is not a full device name: " + option)
	_check(13, data.get_question(1).correct_option == "Router" and data.get_question(1).max_score == 10, "point 1 data")
	_check(13, data.get_question(2).correct_option == "Switched Hub 24 Port" and data.get_question(2).max_score == 10, "point 2 data")
	_check(13, data.get_question(3).correct_option == "Wireless Access Point" and data.get_question(3).max_score == 10, "point 3 data")
	_check(13, not "Modem" in data.get_question(1).options, "Modem was removed")

	var s := Mission01State.new()
	s.reset(data)
	_check(13, s.total_score() == 30, "start correctness should be 30")
	_check(7, not s.set_answer(1, "Router", 1), "a device must be decided as 'choose' with a reason first")
	_check(7, _answer(s, 1, "Router"), "choose Router")
	_check(7, _answer(s, 2, "Shared Hub 24 Port", 1, false), "choose Shared Hub")
	var r := Mission01Validator.check(s, data)
	_check(10, not r.checked and r.missing == [3] and s.check_count == 0 and s.total_score() == 30, "incomplete check must not count or cost points")
	# Changing answers before a check is free; only the first reason per device is scored.
	_check(7, _answer(s, 2, "Switched Hub 24 Port"), "change to Switched Hub 24 Port")
	_check(7, s.get_mark(2, "Shared Hub 24 Port") == "", "choosing another device clears the old 'choose' mark")
	_check(7, _answer(s, 2, "Shared Hub 24 Port", 1, true), "change back to Shared Hub")
	_check(7, not bool(s.scored_reasons[2]["Shared Hub 24 Port"].correct), "the first (wrong) answer for a device stays the scored one")
	_check(13, s.total_score() == 30, "changing an answer cost points")
	# Rejecting a distractor with the right reason is a right decision.
	_check(7, s.record_reason(3, "Bridge", REJECT, _reason(3, "Bridge", REJECT), data) and bool(s.scored_reasons[3]["Bridge"].correct), "reject Bridge with the right reason")
	_check(7, s.record_reason(3, "Switched Hub 8 Port", REJECT, _reason(3, "Switched Hub 8 Port", REJECT, false), data) and not bool(s.scored_reasons[3]["Switched Hub 8 Port"].correct), "reject with a wrong reason is a wrong decision")
	_answer(s, 3, "Router")
	r = Mission01Validator.check(s, data)                      # P2, P3 wrong
	_check(12, r.checked and r.wrong == [2, 3] and r.correct == [1], "first check result")
	_check(13, s.get_point_score(2) == 5 and s.get_point_score(3) == 5 and s.total_score() == 20, "first check score %d" % s.total_score())
	_check(12, s.get_status(1) == Mission01State.PointStatus.CORRECT and s.get_status(2) == Mission01State.PointStatus.WRONG, "states after check")
	_check(12, not _answer(s, 1, "Wireless Access Point"), "a point already checked correct must stay locked")
	_check(12, s.quantity_results.size() == 3 and bool(s.quantity_results[1]), "quantities scored at the first check")
	_answer(s, 2, "Switched Hub 24 Port")
	_check(12, s.get_status(2) == Mission01State.PointStatus.SELECTED, "changed wrong point should be 'selected' again")
	r = Mission01Validator.check(s, data)                      # only P3 wrong, again
	_check(13, s.get_point_score(2) == 5 and s.get_point_score(3) == 0 and s.total_score() == 15, "second check score %d" % s.total_score())
	_answer(s, 3, "Wireless Access Point", 2)                   # right device, wrong quantity
	r = Mission01Validator.check(s, data)
	_check(12, r.wrong == [3] and s.get_status(3) == Mission01State.PointStatus.WRONG, "a wrong quantity makes the point wrong")
	_check(14, s.get_point_score(3) == 0, "point score went below 0")
	s.set_answer(3, "Wireless Access Point", 1)
	r = Mission01Validator.check(s, data)
	_check(13, r.completed and s.passed and s.final_score == 15 and s.check_count == 4, "pass: final %d checks %d" % [s.final_score, s.check_count])
	_check(13, s.ever_wrong_count() == 2 and 2 in s.ever_wrong and 3 in s.ever_wrong, "ever-wrong points")
	r = Mission01Validator.check(s, data)
	_check(13, s.check_count == 4 and s.final_score == 15, "checking after passing must not change anything")
	_check(13, not _answer(s, 2, "Shared Hub 24 Port"), "answers must be locked after passing")
	# Decisions: P1 Router ok; P2 Shared x, Switched24 ok; P3 Bridge ok, 8 Port x, Router x, AP ok; 3 quantities ok.
	var counts := s.decision_counts()
	_check(15, counts == Vector2i(7, 10), "decision counts %s" % counts)
	var score := Mission01Validator.mission_score(s, data, 200.0)
	_check(15, score.correctness == 15 and score.process == 35 and score.time == 20 and score.total() == 70 and score.stars() == 3, "mission score %s" % score.to_dict())
	var joined := "\n".join(score.mistakes)
	_check(15, joined.contains("จุดที่ 2: เลือก Shared Hub 24 Port — ควรไม่เลือก") and joined.contains("เข้าใจผิดว่า"), "mistakes list:\n" + joined)

	# Never below zero.
	var z := Mission01State.new()
	z.reset(data)
	_answer(z, 1, "Wireless Access Point")
	_answer(z, 2, "Shared Hub 24 Port")
	_answer(z, 3, "Router")
	for i in 12:
		Mission01Validator.check(z, data)
	_check(14, z.total_score() == 0 and z.get_point_score(1) == 0 and z.get_point_score(2) == 0, "score went below 0 or did not reach 0: %d" % z.total_score())
	_check(14, z.check_count == 12 and not z.passed, "check count / pass flag after many wrong checks")

	# Save round trip.
	Mission01SaveStore.save(s)
	var loaded := Mission01State.new()
	_check(16, Mission01SaveStore.load_into(loaded, data), "save file not found")
	var a := s.to_dict()
	var b := loaded.to_dict()
	_check(16, JSON.stringify(a) == JSON.stringify(b), "save round trip differs:\n%s\n%s" % [a, b])
	for key in ["answers", "quantities", "marks", "scored_reasons", "quantity_results", "current_score", "check_count", "ever_wrong", "passed", "final_score"]:
		_check(16, b.has(key), "save is missing " + key)
	# A version-1 save (2-option mission) starts fresh instead of crashing.
	var old := Mission01State.new()
	old.from_dict({"version": 1, "answers": {"1": "Router"}, "passed": true}, data)
	_check(16, old.get_answer(1) == "" and not old.passed, "old save should start fresh")
	Mission01SaveStore.clear()


func _test_score_and_progress() -> void:
	_check(15, MissionScore.time_points(100, 300, 900) == 20 and MissionScore.time_points(600, 300, 900) == 10 and MissionScore.time_points(900, 300, 900) == 0, "time points")
	_check(15, MissionScore.stars_for(49) == 0 and MissionScore.stars_for(50) == 1 and MissionScore.stars_for(60) == 2 and MissionScore.stars_for(70) == 3 and MissionScore.stars_for(80) == 4, "star thresholds")
	var full := MissionScore.compute(30, 6, 6, 100, 300, 900)
	_check(15, full.total() == 100 and full.passed() and full.stars() == 4, "perfect score")
	var fail := MissionScore.compute(5, 1, 6, 1000, 300, 900)
	_check(15, not fail.passed() and fail.total() == 13, "failing score %d" % fail.total())
	var built := [1, 5, 6]
	_check(21, GameProgress.is_unlocked(1, built) and not GameProgress.is_unlocked(5, built), "only level 1 open at first")
	GameProgress.record_attempt(1, fail)
	_check(21, not GameProgress.is_unlocked(5, built) and GameProgress.best_score(1) == 13, "a failed attempt does not unlock")
	var rec := GameProgress.record_attempt(1, full)
	_check(21, GameProgress.is_unlocked(5, built) and not GameProgress.is_unlocked(6, built) and int(rec.attempts) == 2 and int(rec.best_total) == 100, "pass unlocks the next built level: %s" % rec)
	GameProgress.record_attempt(1, fail)
	_check(21, GameProgress.best_score(1) == 100 and int(GameProgress.level_record(1).last.total) == 13, "best score kept, last result updated")
	GameProgress.clear()


# ================================================================ the program on its own

func _test_program() -> void:
	var scene := load(APP_SCENE) as PackedScene
	_check(2, scene != null, "cannot load " + APP_SCENE)
	var app := scene.instantiate() as NetPlanEdu
	_check(2, app != null, "scene root is not NetPlanEdu")
	app.use_save_file = false
	root.add_child(app)
	await _frames(4)
	var plan: RoomPlanView = app._plan
	var popup: EquipmentPopup = app._popup
	_check(2, app.is_inside_tree() and plan.size.x > 100.0, "program did not lay out")
	_check(5, app.get_node("%FileName").text.contains(data.project_file_name), "project file name missing in the title bar")
	_check(9, app.get_node("%ProgressLabel").text == "0/3 จุด", "progress should start at 0/3: " + app.get_node("%ProgressLabel").text)
	_check(10, app.status_message == NetPlanEdu.MSG_READY, "first status should be พร้อมทำภารกิจ")

	# Plan: exactly 3 clickable markers; LAN routes are drawn, not nodes.
	var markers := 0
	for child in plan.get_children():
		if child is EquipmentPoint:
			markers += 1
		elif child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_check(8, false, "unexpected clickable node on the plan: " + child.name)
	_check(6, markers == 3, "expected 3 install points, found %d" % markers)
	_check(8, RoomPlanView.LAN_ROUTES.size() >= 4, "LAN routes missing")

	# Real mouse clicks on each marker open the pop-up for that point.
	for id in [1, 2, 3]:
		await _click(plan.get_point(id))
		_check(6, popup.visible and popup.point_id == id, "clicking point %d did not open its pop-up" % id)
		_check(6, popup._devices.get_child_count() == 4, "point %d should offer 4 devices" % id)
		_check(7, popup.get_node("%ConfirmButton").disabled and not popup._decision_box.visible and not popup._quantity_row.visible, "nothing to confirm before a decision")
		await _click(popup.get_node("%CancelButton"))
		_check(7, not popup.visible and app.state.get_answer(id) == "", "cancel should close without saving")

	# Clicking on a LAN cable / the room does nothing.
	var before := JSON.stringify(app.state.to_dict())
	await _click(plan.global_position + plan.plan_to_local(Vector2(RoomPlanView.LEFT_TRUNK_X, 400)))
	await _click(plan.global_position + plan.plan_to_local(Vector2(500, RoomPlanView.TOP_TRUNK_Y)))
	_check(8, not popup.visible and JSON.stringify(app.state.to_dict()) == before, "clicking a LAN route changed something")
	app.get_node("%LanRoutesItem").button_pressed = true
	await _frames(1)
	_check(8, plan.lan_highlight and RoomPlanView.LAN_ROUTES.size() >= 4, "LAN route view did not highlight")
	_check(8, not plan.has_method("_can_drop_data") and not plan.has_method("_get_drag_data"), "plan must not support drag and drop")

	# The whole decision with real clicks: device, "เลือก", reason, save, quantity, confirm.
	await _click(plan.get_point(2))
	var shared := popup._devices.get_node("Option_Shared_Hub_24_Port") as Button
	await _click(shared)
	_check(7, popup.active_device == "Shared Hub 24 Port" and popup._decision_box.visible, "device click did not open the decision")
	await _click(popup._choose_button)
	_check(7, popup._reasons.get_child_count() == 3 and popup._reason_title.text.contains("เพราะ"), "choose did not show 3 reasons")
	_check(7, popup._save_reason.disabled, "saving needs a reason first")
	# The pop-up must fit the smallest screen with a long reason list open.
	_check(2, popup.get_node("%Card").size.y <= 672.0, "pop-up is %d px tall" % popup.get_node("%Card").size.y)
	await _click(popup._reasons.get_child(0))
	await _click(popup._save_reason)
	_check(7, app.state.get_mark(2, "Shared Hub 24 Port") == CHOOSE and app.state.scored_reasons[2].has("Shared Hub 24 Port"), "reason not recorded")
	_check(7, popup._quantity_row.visible and popup._quantity.value == 0 and popup.get_node("%ConfirmButton").disabled, "quantity starts at 0 and blocks confirming")
	popup.set_quantity(1)
	await _frames(1)
	await _click(popup.get_node("%ConfirmButton"))
	_check(7, not popup.visible and app.state.get_answer(2) == "Shared Hub 24 Port" and app.state.get_quantity(2) == 1, "confirm did not save the answer")
	_check(10, app.status_message == NetPlanEdu.MSG_SELECTED % 2, "status after choosing: " + app.status_message)
	_check(9, app.get_node("%ProgressLabel").text == "1/3 จุด", "progress should be 1/3")
	# Rejecting the chosen device removes the answer.
	_check(7, app.answer_device(2, "Shared Hub 24 Port", REJECT) and app.state.get_answer(2) == "", "rejecting the chosen device should clear the answer")
	popup.cancel()
	_check(7, app.choose_answer(2, "Shared Hub 24 Port"), "could not choose it again")
	app.choose_answer(1, "Router")
	_check(9, app.get_node("%ProgressLabel").text == "2/3 จุด", "progress should be 2/3")

	# Nothing is revealed before checking.
	for id in [1, 2]:
		_check(11, app.get_point_status(id) == Mission01State.PointStatus.SELECTED, "point %d revealed before check" % id)
		var row_text: String = (app._rows[id].device as Label).text
		_check(11, not row_text.contains("ถูกต้อง") and not row_text.contains("ต้องแก้ไข"), "side panel revealed the result before check")
	_check(11, app.get_node("%ScoreLabel").text.contains("ยังไม่ได้ตรวจสอบ"), "score shown before check")

	# Check with a point missing.
	var r := app.request_validation()
	_check(10, not r.checked and app.status_message.begins_with(NetPlanEdu.MSG_MISSING) and app.status_message.contains("3"), "missing-point warning: " + app.status_message)
	_check(10, app.state.check_count == 0, "incomplete check was counted")

	app.choose_answer(3, "Router")
	_check(9, app.get_node("%ProgressLabel").text == "3/3 จุด", "progress should be 3/3")
	_check(11, app.get_point_status(3) == Mission01State.PointStatus.SELECTED, "point 3 revealed before check")

	# First check: 1 correct, 2 and 3 wrong.
	await _click(app.get_node("%CheckDesignButton"))
	r = app.last_result
	_check(12, r != null and r.checked and r.wrong == [2, 3], "check button result")
	_check(12, app.get_point_status(1) == Mission01State.PointStatus.CORRECT and app.get_point_status(2) == Mission01State.PointStatus.WRONG and app.get_point_status(3) == Mission01State.PointStatus.WRONG, "states after check")
	_check(12, plan.get_point(2).status == Mission01State.PointStatus.WRONG and plan.get_point(1).status == Mission01State.PointStatus.CORRECT, "marker colours after check")
	_check(10, app.status_message.begins_with(NetPlanEdu.MSG_FIX), "status should be พบจุดที่ต้องแก้ไข: " + app.status_message)
	_check(11, not app.get_node("%HintLabel").text.contains("Switched") and not app.get_node("%HintLabel").text.contains("Wireless"), "hint gave the answer away")
	_check(13, app.state.total_score() == 20 and app.get_node("%ScoreLabel").text.contains("20 / 30"), "correctness after first check")
	_check(13, app.get_node("%CheckCountLabel").text.contains("1"), "check count label")
	_check(15, not app.is_completion_shown(), "completion shown too early")
	_check(12, not app.choose_answer(1, "Wireless Access Point") and app.state.get_answer(1) == "Router", "correct point should be locked")
	popup.cancel()

	# Fix the wrong points and pass.
	var completed := []
	app.mission_completed.connect(func(score: int, checks: int, wrong: int): completed.append([score, checks, wrong]))
	app.choose_answer(2, "Switched Hub 24 Port")
	app.choose_answer(3, "Wireless Access Point")
	r = app.request_validation()
	_check(15, r.completed and app.is_completion_shown(), "completion screen not shown")
	_check(15, completed == [[20, 2, 2]], "mission_completed signal: %s" % [completed])
	_check(15, app.get_node("%CompleteTitle").text == "ภารกิจสำเร็จ" and app.get_node("%CompleteScore").text.contains("รายงานหัวหน้างาน") and app.get_node("%CompleteChecks").text.contains("2"), "completion texts")
	_check(15, app.get_node("%BackToDesktopButton").text == "กลับสู่ Desktop" and app.get_node("%ExitComputerButton").text == "ออกจากคอมพิวเตอร์", "completion buttons")
	_check(10, app.status_message == NetPlanEdu.MSG_DONE, "status should be ภารกิจสำเร็จ")
	_check(13, app.get_node("%CheckDesignButton").disabled, "check must be disabled after passing")
	app.queue_free()
	await _frames(2)

	# Smallest supported screen (1280x720 minus the 48 px taskbar): everything must fit.
	var holder := Control.new()
	holder.size = Vector2(1280, 672)
	root.add_child(holder)
	var small := scene.instantiate() as NetPlanEdu
	small.use_save_file = false
	holder.add_child(small)
	small.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(4)
	var need := small.get_combined_minimum_size()
	_check(2, need.x <= 1280.0 and need.y <= 672.0 and small.size.is_equal_approx(Vector2(1280, 672)), "program needs %s, more than 1280x672" % need)
	holder.queue_free()
	await _frames(2)


# ================================================================ inside the game (main.tscn, Level 1)

func _look_at(player: CharacterBody3D, target: Vector3) -> void:
	player.look_at(Vector3(target.x, player.global_position.y, target.z), Vector3.UP)
	var eye: Vector3 = player.camera.global_position
	player.camera.rotation.x = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())
	for i in 3:
		await physics_frame


func _finish_dialogue(dialogue: DialogueBox) -> void:
	var guard := 0
	while dialogue.is_open() and guard < 20:
		dialogue.advance(true)
		guard += 1
	await _frames(2)


func _test_in_game() -> void:
	Mission01SaveStore.clear()
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	var flow: Node = root.get_node_or_null("GameFlow")
	_check(20, flow != null, "GameFlow autoload missing")
	flow.configure_level(map, 1)
	root.add_child(map)
	for i in 3:
		await physics_frame
	var mission: Mission01Controller = map.get_node_or_null("Mission01")
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var desktop: DesktopOS = manager.desktop
	var pc := manager.find_host("IT-PC-01")
	_check(20, mission != null and mission.stage == Mission01Controller.Stage.BRIEFING, "Level 1 controller missing")
	if mission == null:
		map.queue_free()
		return
	_check(20, mission.hud.objective_text.contains("หัวหน้างาน"), "first objective: " + mission.hud.objective_text)
	var supervisor_node: Node3D = map.get_node("ITSupportSupervisor")
	_check(23, mission.marker.is_active() and mission.marker.target == supervisor_node, "gold arrow should point at the supervisor first")
	_check(4, not pc.has_app("netplan_edu"), "NetPlan EDU must appear only after the briefing")
	_check(4, not manager.find_host("PC-R1-L1").has_app("netplan_edu"), "student PCs should not have NetPlan EDU")
	var rack: WallRack9U = map.get_node_or_null("ComputerRoomRack")
	_check(22, rack != null and rack.stage == WallRack9U.Stage.EMPTY and rack.global_position.distance_to(Vector3(8.2, 1.75, -9.525)) < 0.01, "empty wall rack behind the teacher desk")

	# Talk to the supervisor with the real prompt and F.
	player.require_mouse_capture = false
	var supervisor: Node3D = map.get_node("ITSupportSupervisor")
	player.global_position = supervisor.global_position + Vector3(1.4, 0, 0)
	for i in 2:
		await physics_frame
	await _look_at(player, supervisor.global_position + Vector3(0, 1.2, 0))
	_check(20, player.focused_interactable == mission.talk and player._prompt.text.contains("หัวหน้างาน"), "supervisor prompt: " + player._prompt.text)
	await _press_interact()
	_check(20, mission.dialogue.is_open() and player.controls_locked, "talking did not open the dialogue")
	await _finish_dialogue(mission.dialogue)
	_check(20, mission.stage == Mission01Controller.Stage.DESIGN and pc.has_app("netplan_edu") and not player.controls_locked, "briefing did not start the mission")
	_check(20, mission.hud.objective_text.contains("IT-PC-01"), "objective after briefing: " + mission.hud.objective_text)
	var pc_screen: Vector3 = pc.screen.global_transform * pc.screen.get_aabb().get_center()
	_check(23, mission.marker.is_active() and mission.marker.target == null and mission.marker.tip_position().distance_to(pc_screen + Vector3(0, 0.42, 0)) < 0.01, "gold arrow should move above IT-PC-01")

	# Walk-up prompt for the computer.
	var screen_center: Vector3 = pc.screen.global_transform * pc.screen.get_aabb().get_center()
	player.global_position = Vector3(-14.35, 0.02, -42.66)
	for i in 2:
		await physics_frame
	await _look_at(player, screen_center)
	_check(3, player.focused_computer == pc and player._prompt.text.contains("กด F เพื่อใช้งานคอมพิวเตอร์"), "prompt: " + player._prompt.text)
	var start_pos := player.global_position
	await _press_interact()
	_check(3, player.controls_locked, "F did not lock the player")
	await create_timer(manager.zoom_time + 1.0).timeout
	_check(3, desktop.visible and desktop.is_booting and desktop._boot.visible, "Set-up screen not showing")
	await create_timer(1.35).timeout
	_check(3, not desktop.is_booting, "Set-up lasted longer than about 2 seconds")
	_check(4, desktop._desktop.visible and desktop._netplan_icon.visible, "Desktop / NetPlan EDU icon not shown")
	_check(24, mission.hud.collapsed and mission.hud.auto_collapsed, "objective panel should fold while using the computer")
	await _press_key(KEY_TAB)
	_check(24, not mission.hud.collapsed, "Tab should open the objective panel")
	await _press_key(KEY_TAB)
	_check(24, mission.hud.collapsed, "Tab should fold the objective panel again")

	# No walking, running or looking around while seated.
	var yaw := player.rotation.y
	var max_speed := 0.0
	Input.action_press("move_back")
	Input.action_press("move_left")
	Input.action_press("run")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(300, 120)
	Input.parse_input_event(motion)
	for i in 20:
		await physics_frame
		max_speed = maxf(max_speed, Vector2(player.velocity.x, player.velocity.z).length())
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("run")
	_check(17, max_speed < 0.01 and player.global_position.distance_to(start_pos) < 0.05 and is_equal_approx(player.rotation.y, yaw), "player walked, ran or turned while using the computer (speed %.2f)" % max_speed)

	await _click(desktop._netplan_icon)
	var app := desktop.find_child("NetPlanEdu", true, false) as NetPlanEdu
	_check(5, app != null and app.visible, "clicking the NetPlan EDU icon did not open it")
	if app == null:
		map.queue_free()
		return
	await _frames(3)
	_check(5, app.get_node("%FileName").text.contains("ภารกิจที่ 1 — เลือกอุปกรณ์เครือข่ายห้องคอม"), "project file name")

	# Esc order: pop-up -> program -> leave computer.
	app.open_point(1)
	_check(18, app.is_popup_open(), "pop-up did not open")
	await _press_key(KEY_ESCAPE)
	_check(18, not app.is_popup_open() and is_instance_valid(app) and app.is_inside_tree(), "first Esc should only close the pop-up")
	await _press_key(KEY_ESCAPE)
	await _frames(2)
	_check(18, desktop.find_child("NetPlanEdu", true, false) == null and desktop.visible and player.controls_locked, "second Esc should close the program only")

	# Reopen and play: answers are kept while the level runs.
	app = desktop.open_netplan_edu() as NetPlanEdu
	await _frames(3)
	app.choose_answer(1, "Router")
	app.choose_answer(2, "Shared Hub 24 Port")
	await _click(app.get_node("%CloseButton"))
	await _frames(2)
	app = desktop.open_netplan_edu() as NetPlanEdu
	await _frames(3)
	_check(16, app.state.get_answer(1) == "Router" and app.state.get_answer(2) == "Shared Hub 24 Port", "answers not kept after closing the program")
	app.choose_answer(3, "Wireless Access Point")
	app.request_validation()                                   # point 2 wrong -> 25
	app.choose_answer(2, "Switched Hub 24 Port")
	app.request_validation()                                   # pass with 25
	_check(13, app.state.passed and app.state.final_score == 25 and app.is_completion_shown(), "in-game completion (correctness %d)" % app.state.final_score)
	_check(20, mission.stage == Mission01Controller.Stage.REPORT and mission.hud.objective_text.contains("รายงาน"), "passing should ask to report: " + mission.hud.objective_text)
	_check(23, mission.marker.target == supervisor_node, "gold arrow should return to the supervisor for the report")

	# "ออกจากคอมพิวเตอร์" gives control back.
	await _click(app.get_node("%ExitComputerButton"))
	await create_timer(manager.zoom_time + 0.2).timeout
	_check(17, not desktop.visible and not player.controls_locked, "player still locked after leaving the computer")
	_check(24, not mission.hud.collapsed and not mission.hud.auto_collapsed, "objective panel should open again after leaving the computer")
	if DisplayServer.get_name() == "headless":
		print("  note [17] mouse capture cannot be observed with --headless; run under a display to check it")
	else:
		_check(17, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse mode not restored to captured (%d)" % Input.mouse_mode)
	var walked := false
	for action in ["move_back", "move_left", "move_right"]:
		var from := player.global_position
		Input.action_press(action)
		for i in 12:
			await physics_frame
			if Vector2(player.velocity.x, player.velocity.z).length() > 0.5 or player.global_position.distance_to(from) > 0.05:
				walked = true
		Input.action_release(action)
	_check(17, walked, "player cannot walk after leaving the computer")
	var saved := Mission01State.new()
	_check(16, Mission01SaveStore.load_into(saved, data) and saved.passed and saved.final_score == 25 and saved.check_count == 2 and saved.ever_wrong == [2], "saved result: %s" % saved.to_dict())

	# Report to the supervisor -> summary.
	player.global_position = supervisor.global_position + Vector3(1.4, 0, 0)
	for i in 2:
		await physics_frame
	await _look_at(player, supervisor.global_position + Vector3(0, 1.2, 0))
	_check(20, player._prompt.text.contains("รายงานผล"), "report prompt: " + player._prompt.text)
	await _press_interact()
	await _finish_dialogue(mission.dialogue)
	await _frames(3)
	var score := mission.score
	_check(21, score != null and mission.summary.visible and mission.stage == Mission01Controller.Stage.DONE, "summary not shown after reporting")
	_check(23, not mission.marker.is_active(), "gold arrow should disappear when the level is done")
	if score:
		_check(21, score.correctness == 25 and score.time == 20 and score.process > 0 and score.total() == score.correctness + score.process + score.time, "summary score %s" % score.to_dict())
		_check(21, GameProgress.best_score(1) == score.total() and int(GameProgress.level_record(1).attempts) == 1, "progress not recorded")
		_check(21, mission.summary.replay_button != null and mission.summary.menu_button != null and mission.summary.next_button != null, "summary buttons")
	map.queue_free()
	await _frames(2)


# ================================================================ web export safety

func _test_web_safety() -> void:
	_check(19, ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "renderer must be GL Compatibility for the Web")
	var font := NetPlanTheme.FONT_REGULAR
	_check(19, font != null and font.has_char(0x0E01) and font.has_char(0x0E40) and font.has_char(0x41), "bundled font has no Thai glyphs")
	_check(19, ProjectSettings.get_setting("gui/theme/custom_font", "") != "", "project font not set (Thai would not render on the Web)")
	var files := _mission_files()
	_check(19, files.size() >= 10, "mission files not found")
	var forbidden_api := ["Thread.new", "OS.execute", "OS.shell_open", "OS.alert", "FileDialog", "DisplayServer.dialog", "DisplayServer.file_dialog", "OS.create_process", "GDExtension"]
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for api in forbidden_api:
			_check(19, not text.contains(api), "%s uses %s (not available in the Web export)" % [path, api])
		if path.ends_with(".gd") and path.contains("validate_"):
			continue
		for word in FORBIDDEN_WORDS:
			var re := RegEx.create_from_string("(?<![A-Za-z])" + word + "(?![A-Za-z])")
			_check(11, re.search(text) == null, "%s mentions out-of-scope content '%s'" % [path, word])
		for short in ["\"Hub\"", "\"Switch\"", "\"Access Point\""]:
			_check(11, not text.contains(short), "%s uses a shortened device name %s" % [path, short])


func _mission_files() -> PackedStringArray:
	var out := PackedStringArray()
	for dir in ["res://missions/mission_01/scripts", "res://missions/mission_01/scenes", "res://missions/mission_01/data"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres") or f.ends_with(".json"):
				out.append(dir + "/" + f)
	return out
