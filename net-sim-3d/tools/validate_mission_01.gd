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


## Rule-level answer: choose `device` with its right reason (or a wrong one).
func _answer(s: Mission01State, point: int, device: String, right_reason: bool = true) -> bool:
	var index := data.correct_reason(point, device) if right_reason else -1
	if index < 0:
		index = 0 if data.correct_reason(point, device) != 0 else 1
	return s.set_answer(point, device, index, data)


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
		5: "เปิด NetPlan EDU + ไฟล์ Project", 6: "คลิกจุดที่ 1–3 ได้ แต่ละจุดมี 4 อุปกรณ์พร้อมรูป", 7: "คลิกอุปกรณ์ = เลือก แล้วตอบเหตุผล 4 ตัวเลือก",
		8: "เส้นทาง LAN แสดงและแก้ไขไม่ได้", 9: "ความคืบหน้า 0/3 → 3/3", 10: "แจ้งเตือนเมื่อเลือกไม่ครบ",
		11: "ไม่เฉลยก่อนตรวจ", 12: "สถานะถูก/ผิดหลังตรวจ", 13: "คะแนนความถูกต้อง 30 หักถูกต้อง", 14: "คะแนนไม่ติดลบ",
		15: "คะแนนรวม 30/50/20 ดาว และจุดที่ผิดพลาด", 16: "บันทึกข้อมูลได้", 17: "ออกจากคอมแล้วผู้เล่นควบคุมได้",
		18: "Esc ปิด Popup → โปรแกรม → ออกจากคอม", 19: "ไม่มีส่วนที่ขัดกับ Web Export",
		20: "คุยกับหัวหน้างาน รับภารกิจ และรายงานผล", 21: "หน้าสรุปผล + บันทึกความก้าวหน้า/ปลดล็อก", 22: "Wall Rack ว่างในห้องคอม",
		23: "ลูกศรสีทองชี้เป้าหมายตามขั้นตอน", 24: "แถบภารกิจพับ/เปิดด้วย Tab และพับเองตอนใช้คอม",
		25: "หัวหน้านั่งพิมพ์/ใช้เมาส์ หยุดแล้วหันแค่หัวมาคุย แล้วกลับไปทำงาน", 26: "คำสำคัญในบทสนทนาเป็นสีทอง",
		27: "NetPlan EDU แบบเรียบ: จุดถัดไปสีทอง ขั้นตอน 1-2-3",
	}
	for i in range(1, 28):
		var ok: bool = results.get(i, false)
		print("%s [%02d] %s" % ["PASS" if ok else "FAIL", i, names[i]])
	if failures == 0:
		print("MISSION_01_VALID items=27")
		quit()
	else:
		print("MISSION_01_INVALID failures=", failures)
		quit(1)


# ================================================================ rules (no UI)

func _test_data_and_rules() -> void:
	_check(13, data.validate_data() == "", "mission data invalid: " + data.validate_data())
	for q in data.questions:
		_check(6, q.options.size() == 4, "point %d should have 4 devices" % q.point_id)
		for option in q.options:
			_check(11, option in FULL_NAMES, "option is not a full device name: " + option)
			_check(6, Mission01Data.device_icon(option) != null, "no picture for " + option)
			var options := data.reason_options(q.point_id, option)
			_check(7, options.size() == 4, "point %d %s should have 4 reasons" % [q.point_id, option])
			# Distractors about as long as the right answer, so length gives nothing away.
			var shortest := 9999
			var longest := 0
			for o in options:
				shortest = mini(shortest, String(o.text).length())
				longest = maxi(longest, String(o.text).length())
			_check(7, longest <= shortest * 1.5, "point %d %s: reasons %d..%d characters" % [q.point_id, option, shortest, longest])
	_check(13, data.get_question(1).correct_option == "Router" and data.get_question(1).max_score == 10, "point 1 data")
	_check(13, data.get_question(2).correct_option == "Switched Hub 24 Port" and data.get_question(2).max_score == 10, "point 2 data")
	_check(13, data.get_question(3).correct_option == "Wireless Access Point" and data.get_question(3).max_score == 10, "point 3 data")
	_check(13, not "Modem" in data.get_question(1).options, "Modem was removed")

	var s := Mission01State.new()
	s.reset(data)
	_check(13, s.total_score() == 30, "start correctness should be 30")
	_check(7, not s.set_answer(1, "Router", 7, data), "an answer needs one of the 4 reasons")
	_check(7, _answer(s, 1, "Router"), "choose Router")
	_check(7, _answer(s, 2, "Shared Hub 24 Port", false), "choose Shared Hub")
	var r := Mission01Validator.check(s, data)
	_check(10, not r.checked and r.missing == [3] and s.check_count == 0 and s.total_score() == 30, "incomplete check must not count or cost points")
	# Changing answers before a check is free; only the first reason per device is scored.
	_check(7, _answer(s, 2, "Switched Hub 24 Port"), "change to Switched Hub 24 Port")
	_check(7, _answer(s, 2, "Shared Hub 24 Port", true), "change back to Shared Hub")
	_check(7, s.scored_reasons[2].size() == 2 and not bool(s.scored_reasons[2]["Shared Hub 24 Port"].correct), "each device is scored once, on its first answer")
	_check(13, s.total_score() == 30, "changing an answer cost points")
	_answer(s, 3, "Router")
	r = Mission01Validator.check(s, data)                      # P2, P3 wrong
	_check(12, r.checked and r.wrong == [2, 3] and r.correct == [1], "first check result")
	_check(13, s.get_point_score(2) == 5 and s.get_point_score(3) == 5 and s.total_score() == 20, "first check score %d" % s.total_score())
	_check(12, s.get_status(1) == Mission01State.PointStatus.CORRECT and s.get_status(2) == Mission01State.PointStatus.WRONG, "states after check")
	_check(12, not _answer(s, 1, "Wireless Access Point"), "a point already checked correct must stay locked")
	_answer(s, 2, "Switched Hub 24 Port")
	_check(12, s.get_status(2) == Mission01State.PointStatus.SELECTED, "changed wrong point should be 'selected' again")
	r = Mission01Validator.check(s, data)                      # only P3 wrong, again
	_check(13, s.get_point_score(2) == 5 and s.get_point_score(3) == 0 and s.total_score() == 15, "second check score %d" % s.total_score())
	_check(14, s.get_point_score(3) == 0, "point score went below 0")
	_answer(s, 3, "Wireless Access Point", false)             # right device, wrong reason
	r = Mission01Validator.check(s, data)
	_check(13, r.completed and s.passed and s.final_score == 15 and s.check_count == 3, "pass: final %d checks %d" % [s.final_score, s.check_count])
	_check(13, s.ever_wrong_count() == 2 and 2 in s.ever_wrong and 3 in s.ever_wrong, "ever-wrong points")
	r = Mission01Validator.check(s, data)
	_check(13, s.check_count == 3 and s.final_score == 15, "checking after passing must not change anything")
	_check(13, not _answer(s, 2, "Shared Hub 24 Port"), "answers must be locked after passing")
	# Decisions: P1 Router ok; P2 Shared x, Switched24 ok; P3 Router x, AP (wrong reason) x.
	var counts := s.decision_counts()
	_check(15, counts == Vector2i(2, 5), "decision counts %s" % counts)
	var score := Mission01Validator.mission_score(s, data, 200.0)
	_check(15, score.correctness == 15 and score.process == 20 and score.time == 20 and score.total() == 55 and score.stars() == 1, "mission score %s" % score.to_dict())
	var joined := "\n".join(score.mistakes)
	_check(15, joined.contains("จุดที่ 2: เลือก Shared Hub 24 Port — อุปกรณ์นี้ไม่เหมาะกับจุดนี้") and joined.contains("จุดที่ 3: เลือก Wireless Access Point — อุปกรณ์ถูก แต่เหตุผลไม่ถูก") and joined.contains("เข้าใจผิดว่า"), "mistakes list:\n" + joined)

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
	for key in ["answers", "reasons", "scored_reasons", "current_score", "check_count", "ever_wrong", "passed", "final_score"]:
		_check(16, b.has(key), "save is missing " + key)
	# Saves from earlier versions start fresh instead of crashing.
	var old := Mission01State.new()
	old.from_dict({"version": 2, "answers": {"1": "Router"}, "passed": true}, data)
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
	# Simplified layout: one title bar, the plan, and the step list with one check button.
	for hidden in ["MenuPanel", "ToolbarPanel", "ProjectPanel", "StatusBar"]:
		_check(27, not (app.get_node("%" + hidden) as Control).visible, hidden + " should be hidden")
	_check(27, app.find_child("TitleRequirementsButton", true, false) != null and app.find_child("TitleBriefButton", true, false) != null, "title bar reference buttons")
	_check(27, app.next_point_id() == 1 and app._plan.get_point(1).is_pulsing() and not app._plan.get_point(2).is_pulsing(), "only the next point (1) should pulse gold")
	_check(27, (app._rows[1].device as Label).text.contains("ทำต่อที่จุดนี้"), "step card 1 should say to work here next")

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
		_check(7, popup.get_node("%ConfirmButton").disabled and not popup._reasons.visible, "nothing to confirm before a device is chosen")
		_check(6, popup.find_child("RejectButton", true, false) == null and popup.find_child("Quantity", true, false) == null, "no 'ไม่เลือก' button and no quantity field")
		for card in popup._devices.get_children():
			_check(6, (card.find_child("Picture", true, false) as TextureRect).texture != null, "device card without a picture: " + card.name)
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

	# The whole answer with real clicks: device card, reason, confirm.
	await _click(plan.get_point(2))
	var shared := popup._devices.get_node("Option_Shared_Hub_24_Port") as Button
	await _click(shared)
	_check(7, popup.selected_option == "Shared Hub 24 Port" and popup._reasons.visible, "device click did not ask for the reason")
	_check(7, popup._reasons.get_child_count() == 4 and popup._reason_title.text.contains("เลือก Shared Hub 24 Port เพราะ"), "choosing should show 4 reasons")
	_check(7, popup.get_node("%ConfirmButton").disabled, "confirming needs a reason first")
	# The pop-up must fit the smallest screen with the reason list open.
	_check(2, popup.get_node("%Card").size.y <= 672.0, "pop-up is %d px tall" % popup.get_node("%Card").size.y)
	await _click(popup._reasons.get_child(0))
	_check(7, not popup.get_node("%ConfirmButton").disabled, "a reason should enable confirming")
	await _click(popup.get_node("%ConfirmButton"))
	_check(7, not popup.visible and app.state.get_answer(2) == "Shared Hub 24 Port" and app.state.scored_reasons[2].has("Shared Hub 24 Port"), "confirm did not save the answer")
	_check(10, app.status_message == NetPlanEdu.MSG_SELECTED % 2, "status after choosing: " + app.status_message)
	_check(9, app.get_node("%ProgressLabel").text == "1/3 จุด", "progress should be 1/3")
	# Reopening shows the saved device and reason.
	app.open_point(2)
	_check(7, popup.selected_option == "Shared Hub 24 Port" and popup.selected_reason == app.state.get_reason(2), "pop-up does not show the saved answer")
	popup.cancel()
	app.choose_answer(1, "Router")
	_check(9, app.get_node("%ProgressLabel").text == "2/3 จุด", "progress should be 2/3")
	_check(27, app.next_point_id() == 3 and app._plan.get_point(3).is_pulsing(), "after points 1-2 the gold point moves to 3")

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

	# First check (the single "ตรวจสอบแบบ" in the step list): 1 correct, 2 and 3 wrong.
	await _click(app.get_node("%SideCheckButton"))
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

## World positions of an NPC's shoulders, wrists and fingertips.
func _hand_snapshot(npc: NpcCharacter) -> Dictionary:
	var out := {}
	for side in ["L", "R"]:
		for bone_name in ["upperarm01", "wrist", "finger2-3", "finger3-3", "finger4-3", "finger5-3"]:
			var bone := npc.skeleton.find_bone(bone_name + "." + side)
			out[bone_name + "." + side] = npc.skeleton.global_transform * npc.skeleton.get_bone_global_pose(bone).origin
	return out


## Largest move between two snapshots, for bones whose name starts with `prefix`.
func _snapshot_moved(a: Dictionary, b: Dictionary, prefix: String) -> float:
	var most := 0.0
	for key: String in a:
		if key.begins_with(prefix):
			most = maxf(most, (a[key] as Vector3).distance_to(b[key]))
	return most


func _look_at(player: CharacterBody3D, target: Vector3) -> void:
	player.look_at(Vector3(target.x, player.global_position.y, target.z), Vector3.UP)
	var eye: Vector3 = player.camera.global_position
	player.camera.rotation.x = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())
	for i in 3:
		await physics_frame


func _finish_dialogue(dialogue: DialogueBox) -> void:
	var guard := 0
	while dialogue.is_open() and guard < 60:
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
	_check(26, DialogueBox.highlight("มี**20 เครื่อง**").contains("[b][color=") and DialogueBox.highlight("a [b] b") == "a [lb]b] b", "highlight markup")
	_check(23, mission.marker.is_active() and mission.marker.target == supervisor_node, "gold arrow should point at the supervisor first")
	_check(4, not pc.has_app("netplan_edu"), "NetPlan EDU must appear only after the briefing")
	_check(4, not manager.find_host("PC-R1-L1").has_app("netplan_edu"), "student PCs should not have NetPlan EDU")
	var rack: WallRack9U = map.get_node_or_null("ComputerRoomRack")
	_check(22, rack != null and rack.stage == WallRack9U.Stage.EMPTY and rack.global_position.distance_to(Vector3(8.2, 1.75, -9.525)) < 0.01, "empty wall rack behind the teacher desk")

	# Talk to the supervisor with the real prompt and F.
	player.require_mouse_capture = false
	var supervisor: NpcCharacter = map.get_node("ITSupportSupervisor")
	_check(25, supervisor.seated and supervisor.global_position.distance_to(Vector3(-18.88, 0.02, -42.51)) < 0.05, "supervisor should sit at the head desk")
	_check(25, not manager.find_host("IT-HEAD-PC").collision_layer, "the supervisor's own computer must not block talking to him")
	# Stand off to one side so the supervisor has to turn to face the player.
	player.global_position = supervisor.global_position + Vector3(2.3, 0, 0.9)
	for i in 2:
		await physics_frame
	await _look_at(player, supervisor.global_position + Vector3(0, 1.0, 0))
	_check(20, player.focused_interactable == mission.talk and player._prompt.text.contains("หัวหน้างาน"), "supervisor prompt: " + player._prompt.text)
	# Working at the desk: the hands keep moving (typing or using the mouse).
	var work_a := _hand_snapshot(supervisor)
	await create_timer(0.6).timeout
	var work_b := _hand_snapshot(supervisor)
	_check(25, _snapshot_moved(work_a, work_b, "wrist") > 0.001 or _snapshot_moved(work_a, work_b, "finger") > 0.002, "the supervisor's hands should keep working while not talking")
	await _press_interact()
	_check(25, not mission.dialogue.is_open() and player.controls_locked, "the supervisor should turn before speaking")
	await create_timer(supervisor.turn_time + 0.3).timeout
	_check(25, absf(supervisor.turn_amount) > 0.01, "the supervisor did not turn toward the player")
	var talk_a := _hand_snapshot(supervisor)
	await create_timer(0.3).timeout
	var talk_b := _hand_snapshot(supervisor)
	_check(25, _snapshot_moved(talk_a, talk_b, "") < 0.0005, "the supervisor's hands should stop while talking")
	_check(25, _snapshot_moved(work_b, talk_a, "upperarm") < 0.001, "only the head should turn (the shoulders moved)")
	var on_keys: Vector3 = supervisor.get_node("KeyboardHand").global_position
	var on_mouse: Vector3 = supervisor.get_node("MouseHand").global_position
	var right_keys: Vector3 = supervisor.get_node("KeyboardRightHand").global_position
	var wrist_r: Vector3 = talk_a["wrist.R"]
	_check(25, (talk_a["wrist.L"] as Vector3).distance_to(on_keys) < 0.04 and minf(wrist_r.distance_to(on_mouse), wrist_r.distance_to(right_keys)) < 0.04,
		"hands should stay on the keyboard / mouse while talking")
	_check(20, mission.dialogue.is_open() and player.controls_locked, "talking did not open the dialogue")
	_check(26, mission.dialogue.current_text().replace(" ", " ").contains("20 เครื่อง") and mission.dialogue._text.text.contains("[color="), "important words should be highlighted: " + mission.dialogue._text.text)
	await _finish_dialogue(mission.dialogue)
	await create_timer(supervisor.turn_time + 0.2).timeout
	_check(25, absf(supervisor.turn_amount) < 0.01, "the supervisor should turn back to his desk after talking")
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
	player.global_position = supervisor.global_position + Vector3(2.3, 0, 0)
	for i in 2:
		await physics_frame
	await _look_at(player, supervisor.global_position + Vector3(0, 1.0, 0))
	_check(20, player._prompt.text.contains("รายงานผล"), "report prompt: " + player._prompt.text)
	await _press_interact()
	await create_timer(supervisor.turn_time + 0.3).timeout
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
