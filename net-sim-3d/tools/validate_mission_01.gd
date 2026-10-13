extends SceneTree

## Headless check for Mission 1 — NetPlan EDU (เลือกอุปกรณ์เครือข่ายห้องคอม).
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_01.gd
## Prints one line per test item and MISSION_01_VALID / MISSION_01_INVALID at the end.
## Uses its own save file, so it never touches a player's real progress.

const APP_SCENE := "res://scenes/missions/mission_01/netplan_edu.tscn"
const TEST_SAVE := "user://test_validate_mission_01.json"
const FULL_NAMES := ["Router", "Wireless Access Point", "Switched Hub 24 Port", "Shared Hub 24 Port"]
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


func _run() -> void:
	# Headless windows start at 64x64; use the smallest supported screen, 1:1 pixels.
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	Mission01SaveStore.save_path = TEST_SAVE
	Mission01SaveStore.clear()
	data = load(NetPlanEdu.DATA_PATH) as Mission01Data

	_test_data_and_rules()
	await _test_program()
	await _test_in_game()
	_test_web_safety()

	Mission01SaveStore.clear()
	_check(1, logger.errors.is_empty(), "errors were printed: " + " | ".join(logger.errors))

	var names := {
		1: "ไม่มี error", 2: "เปิด Scene ภารกิจได้", 3: "Setup ประมาณ 2 วินาที", 4: "แสดง Desktop + ไอคอน NetPlan EDU",
		5: "เปิด NetPlan EDU + ไฟล์ Project", 6: "คลิกจุดที่ 1–3 ได้", 7: "Popup เลือก/เปลี่ยนอุปกรณ์ได้",
		8: "เส้นทาง LAN แสดงและแก้ไขไม่ได้", 9: "ความคืบหน้า 0/3 → 3/3", 10: "แจ้งเตือนเมื่อเลือกไม่ครบ",
		11: "ไม่เฉลยก่อนตรวจ", 12: "สถานะถูก/ผิดหลังตรวจ", 13: "หักคะแนนถูกต้อง", 14: "คะแนนไม่ติดลบ",
		15: "หน้าภารกิจสำเร็จ", 16: "บันทึกข้อมูลได้", 17: "ออกจากคอมแล้วผู้เล่นควบคุมได้",
		18: "Esc ปิด Popup → โปรแกรม → ออกจากคอม", 19: "ไม่มีส่วนที่ขัดกับ Web Export",
	}
	for i in range(1, 20):
		var ok: bool = results.get(i, false)
		print("%s [%02d] %s" % ["PASS" if ok else "FAIL", i, names[i]])
	if failures == 0:
		print("MISSION_01_VALID items=19")
		quit()
	else:
		print("MISSION_01_INVALID failures=", failures)
		quit(1)


# ================================================================ rules (no UI)

func _test_data_and_rules() -> void:
	_check(13, data.validate_data() == "", "mission data invalid: " + data.validate_data())
	for q in data.questions:
		for option in q.options:
			_check(11, option in FULL_NAMES, "option is not a full device name: " + option)
	_check(13, data.get_question(1).correct_option == "Router" and data.get_question(1).max_score == 30, "point 1 data")
	_check(13, data.get_question(2).correct_option == "Switched Hub 24 Port" and data.get_question(2).max_score == 40, "point 2 data")
	_check(13, data.get_question(3).correct_option == "Wireless Access Point" and data.get_question(3).max_score == 30, "point 3 data")

	var s := Mission01State.new()
	s.reset(data)
	_check(13, s.total_score() == 100, "start score should be 100")
	s.set_answer(1, "Router")
	s.set_answer(2, "Shared Hub 24 Port")
	var r := Mission01Validator.check(s, data)
	_check(10, not r.checked and r.missing == [3] and s.check_count == 0 and s.total_score() == 100, "incomplete check must not count or cost points")
	# Changing answers before a check is free.
	s.set_answer(2, "Switched Hub 24 Port")
	s.set_answer(2, "Shared Hub 24 Port")
	_check(13, s.total_score() == 100, "changing an answer cost points")
	s.set_answer(3, "Router")
	r = Mission01Validator.check(s, data)                      # P2, P3 wrong
	_check(13, r.checked and r.wrong == [2, 3] and r.correct == [1], "first check result")
	_check(13, s.get_point_score(2) == 35 and s.get_point_score(3) == 25 and s.total_score() == 90, "first check score %d" % s.total_score())
	_check(12, s.get_status(1) == Mission01State.PointStatus.CORRECT and s.get_status(2) == Mission01State.PointStatus.WRONG, "states after check")
	_check(12, not s.set_answer(1, "Wireless Access Point"), "a point already checked correct must stay locked")
	s.set_answer(2, "Switched Hub 24 Port")
	_check(12, s.get_status(2) == Mission01State.PointStatus.SELECTED, "changed wrong point should be 'selected' again")
	r = Mission01Validator.check(s, data)                      # only P3 wrong, again
	_check(13, s.get_point_score(2) == 35 and s.get_point_score(3) == 20 and s.total_score() == 85, "second check score %d" % s.total_score())
	s.set_answer(3, "Wireless Access Point")
	r = Mission01Validator.check(s, data)
	_check(13, r.completed and s.passed and s.final_score == 85 and s.check_count == 3, "pass: final %d checks %d" % [s.final_score, s.check_count])
	_check(13, s.ever_wrong_count() == 2 and 2 in s.ever_wrong and 3 in s.ever_wrong, "ever-wrong points")
	r = Mission01Validator.check(s, data)
	_check(13, s.check_count == 3 and s.final_score == 85, "checking after passing must not change anything")
	_check(13, not s.set_answer(2, "Shared Hub 24 Port"), "answers must be locked after passing")

	# Never below zero.
	var z := Mission01State.new()
	z.reset(data)
	z.set_answer(1, "Wireless Access Point")
	z.set_answer(2, "Shared Hub 24 Port")
	z.set_answer(3, "Router")
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
	for key in ["answers", "current_score", "check_count", "ever_wrong", "passed", "final_score", "reward_claimed"]:
		_check(16, b.has(key), "save is missing " + key)
	Mission01SaveStore.clear()


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
		var point := plan.get_point(id)
		await _click(point)
		_check(6, popup.visible and popup.point_id == id, "clicking point %d did not open its pop-up" % id)
		_check(7, popup.get_node("%Options").get_child_count() == 2, "point %d should offer 2 options" % id)
		_check(7, popup.get_node("%ConfirmButton").disabled, "confirm must be disabled until a choice is made")
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

	# Choose with real clicks: option, confirm.
	var p2 := plan.get_point(2)
	await _click(p2)
	var shared := popup.get_node("%Options").get_child(1) as Button
	await _click(shared)
	_check(7, popup.selected_option == "Shared Hub 24 Port" and not popup.get_node("%ConfirmButton").disabled, "option click not registered")
	await _click(popup.get_node("%ConfirmButton"))
	_check(7, not popup.visible and app.state.get_answer(2) == "Shared Hub 24 Port", "confirm did not save the answer")
	_check(10, app.status_message == NetPlanEdu.MSG_SELECTED % 2, "status after choosing: " + app.status_message)
	_check(9, app.get_node("%ProgressLabel").text == "1/3 จุด", "progress should be 1/3")
	# Change the answer later.
	_check(7, app.choose_answer(2, "Switched Hub 24 Port"), "could not change the answer")
	app.open_point(2)
	_check(7, popup.selected_option == "Switched Hub 24 Port" and (popup.get_node("%Options").get_child(0) as Button).button_pressed, "pop-up does not show the saved answer")
	popup.cancel()
	app.choose_answer(2, "Shared Hub 24 Port")
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
	_check(13, app.state.total_score() == 90 and app.get_node("%ScoreLabel").text.contains("90"), "score after first check")
	_check(13, app.get_node("%CheckCountLabel").text.contains("1"), "check count label")
	_check(15, not app.is_completion_shown(), "completion shown too early")
	# Correct point is locked.
	_check(12, not app.choose_answer(1, "Wireless Access Point") and app.state.get_answer(1) == "Router", "correct point should be locked")
	popup.cancel()

	# Fix the wrong points and pass.
	var completed := []
	app.mission_completed.connect(func(score: int, checks: int, wrong: int): completed.append([score, checks, wrong]))
	app.choose_answer(2, "Switched Hub 24 Port")
	app.choose_answer(3, "Wireless Access Point")
	r = app.request_validation()
	_check(15, r.completed and app.is_completion_shown(), "completion screen not shown")
	_check(15, completed == [[90, 2, 2]], "mission_completed signal: %s" % [completed])
	_check(15, app.get_node("%CompleteTitle").text == "ภารกิจสำเร็จ" and app.get_node("%CompleteScore").text.contains("90") and app.get_node("%CompleteChecks").text.contains("2") and app.get_node("%CompleteWrong").text.contains("2"), "completion texts")
	_check(15, app.get_node("%BackToDesktopButton").text == "กลับสู่ Desktop" and app.get_node("%ExitComputerButton").text == "ออกจากคอมพิวเตอร์", "completion buttons")
	_check(10, app.status_message == NetPlanEdu.MSG_DONE, "status should be ภารกิจสำเร็จ")
	_check(13, app.get_node("%CheckDesignButton").disabled, "check must be disabled after passing")
	var exit_requests := []
	var close_requests := []
	app.computer_exit_requested.connect(func(): exit_requests.append(true))
	app.close_requested.connect(func(): close_requests.append(true))
	await _click(app.get_node("%ExitComputerButton"))
	await _click(app.get_node("%BackToDesktopButton"))
	_check(15, exit_requests.size() == 1 and close_requests.size() == 1, "completion buttons do not send their signals")
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


# ================================================================ inside the game (main.tscn)

func _test_in_game() -> void:
	Mission01SaveStore.clear()
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 3:
		await physics_frame
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var desktop: DesktopOS = manager.desktop
	var pc := manager.find_host("IT-PC-01")
	_check(4, pc != null and pc.has_app("netplan_edu"), "IT-PC-01 should have NetPlan EDU installed")
	_check(4, not manager.find_host("PC-R1-L1").has_app("netplan_edu"), "student PCs should not have NetPlan EDU")

	# Walk-up prompt.
	player.require_mouse_capture = false
	var screen_center: Vector3 = pc.screen.global_transform * pc.screen.get_aabb().get_center()
	player.global_position = Vector3(-14.35, 0.02, -42.66)
	for i in 2:
		await physics_frame
	player.look_at(Vector3(screen_center.x, player.global_position.y, screen_center.z), Vector3.UP)
	var eye: Vector3 = player.camera.global_position
	player.camera.rotation.x = atan2(screen_center.y - eye.y, Vector2(screen_center.x - eye.x, screen_center.z - eye.z).length())
	for i in 3:
		await physics_frame
	_check(3, player.focused_computer == pc and player._prompt.text.contains("กด E เพื่อใช้งานคอมพิวเตอร์"), "prompt: " + player._prompt.text)

	# Press E (the "interact" input action).
	var start_pos := player.global_position
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	_check(3, player.controls_locked, "E did not lock the player")
	await create_timer(manager.zoom_time + 1.0).timeout
	_check(3, desktop.visible and desktop.is_booting and desktop._boot.visible, "Set-up screen not showing")
	await create_timer(1.35).timeout
	_check(3, not desktop.is_booting, "Set-up lasted longer than about 2 seconds")
	_check(4, desktop._desktop.visible and desktop._netplan_icon.visible, "Desktop / NetPlan EDU icon not shown")

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

	# Open NetPlan EDU by clicking its desktop icon.
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

	# Reopen and play: answers are kept in the save file.
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
	app.request_validation()                                   # point 2 wrong -> 95
	app.choose_answer(2, "Switched Hub 24 Port")
	app.request_validation()                                   # pass with 95
	_check(15, app.state.passed and app.state.final_score == 95 and app.is_completion_shown(), "in-game completion (score %d)" % app.state.final_score)

	# "ออกจากคอมพิวเตอร์" gives control back.
	await _click(app.get_node("%ExitComputerButton"))
	await create_timer(manager.zoom_time + 0.2).timeout
	_check(17, not desktop.visible and not player.controls_locked, "player still locked after leaving the computer")
	if DisplayServer.get_name() == "headless":
		print("  note [17] mouse capture cannot be observed with --headless; run under a display to check it")
	else:
		_check(17, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse mode not restored to captured (%d)" % Input.mouse_mode)
	# Walking input works again (the desk and chair may block the body, so look at the velocity too).
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

	# Saved result: reopening shows the result and gives no extra score.
	var saved := Mission01State.new()
	_check(16, Mission01SaveStore.load_into(saved, data) and saved.passed and saved.final_score == 95 and saved.check_count == 2 and saved.ever_wrong == [2], "saved result: %s" % saved.to_dict())
	manager.open_computer(pc, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.4).timeout
	app = desktop.open_netplan_edu() as NetPlanEdu
	await _frames(3)
	_check(16, app.is_completion_shown() and app.get_node("%CheckDesignButton").disabled, "finished mission should open on its result")
	app.request_validation()
	_check(16, app.state.final_score == 95 and app.state.check_count == 2, "a finished mission gave extra score")
	# Esc from the result: program closes, then Esc leaves the computer.
	await _press_key(KEY_ESCAPE)
	await _press_key(KEY_ESCAPE)
	await create_timer(manager.zoom_time + 0.2).timeout
	_check(18, not desktop.visible and not player.controls_locked, "Esc on the desktop should leave the computer")
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
	for dir in ["res://scripts/missions/mission_01", "res://scenes/missions/mission_01", "res://data/missions/mission_01"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
				out.append(dir + "/" + f)
	return out
