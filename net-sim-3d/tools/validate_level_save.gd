extends SceneTree

## Mid-level save checks (LevelSave, 2026-11-24): for every level the real
## GameFlow loads it, the level is moved part-way (a step in the middle, some
## results, the timer, the player somewhere else), "บันทึกและออก" saves and goes
## to the menu, then "เล่นต่อ" loads it again. The resumed level must be on the
## same step with the same results, timer and player position, with no script
## errors, and reaching the summary must remove the save.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_level_save.gd
## Prints LEVEL_SAVE_VALID / LEVEL_SAVE_INVALID at the end.

const TEST_DIR := "user://level_save_test"


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
var flow: Node


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


## Loads `level` through GameFlow (fresh or resumed) up to the start page,
## then starts playing.
func _load(level: int, resume: bool) -> Node:
	flow.start_level(level, resume)
	var deadline := Time.get_ticks_msec() + 90000
	while not flow._awaiting_start and Time.get_ticks_msec() < deadline:
		await process_frame
	if not flow._awaiting_start:
		return null
	flow._begin_level()
	flow._controls_help.hide()
	flow.resume_game()
	await _frames(3)
	return flow._mission()


func _player() -> Node3D:
	return current_scene.get_node_or_null("ITSupportPlayer") as Node3D


## Moves each level part-way the way play would leave it.
func _advance(level: int, m: Node) -> void:
	m.elapsed_sec = 123.0
	m._timing = true
	match level:
		1:
			m._set_app_installed(true)
			m._enter(Mission01Controller.Stage.DESIGN)
		2:
			m.state.cable_types = {1: Mission02State.STRAIGHT, 2: Mission02State.CROSSOVER}
			for id: String in Mission02ToolDrawer.REQUIRED:
				m.drawer_taken[id] = true
			m.drawer_seen = true
			m._enter(Mission02Controller.Stage.CRIMP)
			m.crimp_panel.end_index = 2
			m.state.ends["1A"] = ["a", "b", "c", "d", "e", "f", "g", "h"]
			m.state.ends["1B"] = ["a", "b", "c", "d", "e", "f", "g", "h"]
			m.state.ends["2A"] = ["half", "", "", "", "", "", "", ""]
		3:
			m._teacher_met = true
			m.teacher_place = "staff_room"
			m.state.attach("TEACHER-PC", "192.168.1.10", "255.255.255.0", "192.168.1.1", Mission03State.REPLY, Mission03State.NORMAL)
			m._enter(Mission03Controller.Stage.INSPECT)
		4:
			m.saw_screen = true
			m.saw_port = true
			m.state.tool_first = "tester"
			m._enter(Mission04Controller.Stage.FETCH)
		5:
			m.state.app_opened = true
			m.state.conn_matched = true
			m.state.scan_status = Mission05State.ScanStatus.SCANNED
			m.greeted = true
			m._enter(Mission05Controller.Stage.QUARANTINE)
		6:
			m.state.call_answered = true
			m.state.mails_delivered = 1
			m.state.partner_online = true
			m.state.mail_read = true
			m.state.tv_opened = true
			m.state.session_active = true
			m.state.remote_muted = false
			m.state.remote_volume = 60
			m.state.wrong_id_count = 2
			m._enter(Mission06Controller.Stage.FIX)


## What the resumed level should show (the step can differ where resuming
## means going back to a step's start).
func _expected_stage(level: int) -> int:
	match level:
		1: return Mission01Controller.Stage.DESIGN
		2: return Mission02Controller.Stage.CRIMP
		3: return Mission03Controller.Stage.INSPECT
		4: return Mission04Controller.Stage.FETCH
		5: return Mission05Controller.Stage.QUARANTINE
		6: return Mission06Controller.Stage.CONNECT # the session dropped
	return -1


func _level_checks(level: int, m: Node, before: Dictionary) -> void:
	var after: Dictionary = m.save_snapshot()
	match level:
		1:
			_check(m.manager.find_host("IT-PC-01").has_app("netplan_edu"), "L1 NetPlan EDU installed again")
		2:
			_check(m.crimp_panel.end_index == 2 and m.state.ends.has("1B") and not m.state.ends.has("2A"), "L2 crimping goes on at end 2A (finished ends kept, the half one redone)")
			_check(m.drawer_taken.size() == Mission02ToolDrawer.REQUIRED.size() and m.state.cable_types.size() == 2, "L2 cables and tools still gathered")
		3:
			_check(m.state.records.has("TEACHER-PC") and m._teacher_met and m.teacher_place == "staff_room", "L3 first row attached, teacher met and gone")
			var person := current_scene.get_node_or_null("TeacherMale") as Node3D
			_check(person != null and person.global_position.distance_to(StaffRoomLife.seat_of("male")) < 1.0, "L3 the teacher sits in the teachers' room")
		4:
			_check(m.saw_screen and m.saw_port and m.state.tool_first == "tester", "L4 symptoms and first tool kept")
			_check(not m.teacher.seated and m.teacher.global_position.distance_to(Mission04Controller.TEACHER_WAIT) < 0.1, "L4 she waits beside her desk")
			_check(not m.phone.ringing, "L4 the phone is not ringing again")
		5:
			_check(m.state.scan_status == Mission05State.ScanStatus.SCANNED and m.state.conn_matched and m.greeted, "L5 scan result and firewall progress kept")
		6:
			_check(not m.state.session_active and m.state.wrong_id_count == 2 and m.state.remote_volume == 60, "L6 session dropped, mistakes and volume kept")
			_check(m.station.mail.size() == 1, "L6 the e-mail with the password is in Mail again")
	var same := true
	var differs := PackedStringArray()
	for key in ["drawer_taken", "saw_screen", "saw_port", "teacher_met", "greeted", "teacher_place"]:
		if before.has(key) and before[key] != after.get(key):
			same = false
			differs.append(key)
	# The whole state object, except what resuming changes on purpose.
	var changed_on_purpose := {6: ["session_active"], 2: ["ends"]}
	var s_before: Dictionary = before.get("state", before.get("design", {}))
	var s_after: Dictionary = after.get("state", after.get("design", {}))
	for key in s_before:
		if key in changed_on_purpose.get(level, []):
			continue
		if var_to_str(s_before[key]) != var_to_str(s_after.get(key)):
			same = false
			differs.append("state." + str(key))
	_check(same, "L%d every other saved field comes back unchanged %s" % [level, differs])


func _run() -> void:
	flow = root.get_node("GameFlow")
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	LevelSave.folder = TEST_DIR
	flow.save_file = TEST_DIR.path_join("menu.cfg")
	GameProgress.save_path = TEST_DIR.path_join("progress.json")
	Mission01SaveStore.save_path = TEST_DIR.path_join("mission_01_save.json")
	for level in [1, 2, 3, 4, 5, 6]:
		LevelSave.clear(level)
	for level in [1, 2, 3, 4, 5, 6]:
		print("Level %d" % level)
		var m := await _load(level, false)
		_check(m != null, "L%d loads" % level)
		if m == null:
			continue
		_advance(level, m)
		var player := _player()
		var spot := player.global_position + Vector3(0.6, 0, 0.4)
		player.global_position = spot
		player.rotation.y = 1.1
		await _frames(2)
		# Let the HUD stamp the mistakes _advance made (it looks twice a second).
		await create_timer(0.8).timeout
		var stamped: Dictionary = m.hud.mistake_seen.duplicate(true)
		# Time per step: the first step's time so far, kept across the save.
		m.hud.step_seconds[0] = 11.0
		var steps_count: int = m.hud.steps.size()
		var before: Dictionary = m.save_snapshot()
		var paused_at: float = m.elapsed_sec
		# The pause page's "บันทึกและออก".
		flow.pause_game()
		var button := flow._body.find_child("SaveAndQuit", true, false) as Button
		_check(button != null and button.text.contains("บันทึกและออก") or (button != null and button.text == "Save and quit"), "L%d pause page has บันทึกและออก" % level)
		var has_menu_button := false
		for b in flow._body.find_children("*", "Button", true, false):
			has_menu_button = has_menu_button or (b as Button).text == "กลับเมนูหลัก"
		_check(not has_menu_button, "L%d no กลับเมนูหลัก on the pause page" % level)
		flow.save_and_quit()
		await _frames(3)
		_check(LevelSave.exists(level) and flow.current_level == 0, "L%d saved and back at the menu" % level)
		_check(flow.last_level == level, "L%d is the level Continue starts" % level)
		# Home page "เล่นต่อ".
		m = await _load(level, LevelSave.exists(flow.last_level))
		_check(m != null, "L%d resumes" % level)
		if m == null:
			continue
		_check(int(m.stage) == _expected_stage(level), "L%d on the saved step (stage %d)" % [level, int(m.stage)])
		_check(absf(m.elapsed_sec - paused_at) < 1.0 and m._timing, "L%d timer goes on from %.0f s (now %.1f)" % [level, paused_at, m.elapsed_sec])
		_check(_player().global_position.distance_to(spot) < 0.05 and absf(_player().rotation.y - 1.1) < 0.01, "L%d player where they were" % level)
		_level_checks(level, m, before)
		_check(absf(float(m.hud.step_seconds[0]) - 11.0) < 0.5, "L%d time on step 1 kept (%.1f s)" % [level, float(m.hud.step_seconds[0])])
		_check(var_to_str(m.hud.mistake_seen) == var_to_str(stamped), "L%d when each mistake happened is kept (%d stamped)" % [level, stamped.size()])
		# Play on a little: deferred work after the restore must not fail.
		await create_timer(1.5).timeout
		# Autosave writes too; the summary removes the save.
		_check(flow.save_level(), "L%d autosave writes" % level)
		var active_before: int = m.hud._active_index
		m.finish()
		await _frames(2)
		var recorded: Variant = GameProgress.history(level)[-1].get("step_times")
		_check(recorded is Array and (recorded as Array).size() == steps_count and absf(float(recorded[0]["sec"]) - 11.0) < 0.5,
			"L%d the attempt records time for all %d steps" % [level, steps_count])
		# Mistakes: where (what) / why / when, for every line of the score.
		var log: Variant = GameProgress.history(level)[-1].get("mistake_log")
		var mistakes: Array = GameProgress.history(level)[-1].get("mistakes", [])
		var complete := log is Array and (log as Array).size() == mistakes.size()
		if complete:
			for entry: Dictionary in log:
				complete = complete and String(entry["what"]) != "" and String(entry["why"]) != "" and int(entry["step"]) > 0 and entry.has("at_sec")
		_check(complete, "L%d each of the %d mistakes has where, why and when" % [level, mistakes.size()])
		var cards: Array = m.summary.find_children("MistakeCard*", "PanelContainer", true, false)
		_check(cards.size() == mistakes.size(), "L%d summary shows a card per mistake (%d)" % [level, cards.size()])
		if not cards.is_empty():
			var why := cards[0].find_child("MistakeWhy", true, false) as Label
			var when := cards[0].find_child("MistakeWhen", true, false) as Label
			_check(why != null and why.text != "" and when != null and when.text.contains("ขั้นที่"), "L%d a card says why and when (%s | %s)" % [level, when.text if when else "-", why.text if why else "-"])
		if level in [2, 6]:
			var during := false
			for entry: Dictionary in (log if log is Array else []):
				if not bool(entry["at_end"]) and float(entry["at_sec"]) > 0.0:
					during = true
					print("       %s | ขั้นที่ %d | %.1f s" % [entry["what"], int(entry["step"]), float(entry["at_sec"])])
			_check(during, "L%d a mistake made during play keeps its step and time" % level)
		if recorded is Array and active_before >= 0 and active_before < (recorded as Array).size():
			_check(float(recorded[active_before]["sec"]) > 1.0 and String(recorded[active_before]["name"]) != "", "L%d the step being played gained time (%.1f s on step %d)" % [level, float(recorded[active_before]["sec"]), active_before + 1])
		_check(not LevelSave.exists(level), "L%d the summary removes the save" % level)
		_check(not flow.save_level(), "L%d nothing saved after the summary" % level)
		flow.return_to_menu()
		await _frames(3)
	# Choosing a level that has a save asks first.
	LevelSave.write(2, {"player": {}, "mission": {"stage": 1}})
	flow.choose_level(2)
	await _frames(2)
	var texts := PackedStringArray()
	for b in flow._body.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	_check("เล่นต่อจากที่บันทึกไว้" in texts and "เริ่มใหม่" in texts, "a level with a save asks: continue or start over (%s)" % ", ".join(texts))
	flow.start_level(2)
	_check(not LevelSave.exists(2), "starting over removes the old save")
	while flow.loading:
		await process_frame
	flow.return_to_menu()
	await _frames(3)
	for e in logger.errors:
		print("  ERROR ", e)
	_check(logger.errors.is_empty(), "no script errors (%d)" % logger.errors.size())
	print("LEVEL_SAVE_VALID" if failures == 0 else "LEVEL_SAVE_INVALID failures=%d" % failures)
	quit(0 if failures == 0 else 1)
