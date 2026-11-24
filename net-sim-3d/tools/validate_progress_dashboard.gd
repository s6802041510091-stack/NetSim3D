extends SceneTree

## Progress dashboard of the main menu (added 2026-11-18): the fifth home
## button, the overview of every level and the per-level page with the
## attempt history. Uses a scratch progress file, so real results are untouched.
## Run it WITH a window (not --headless): the checks that the level page
## scrolls inside the card and that the back button stays in view need a
## real screen (headless they fail), and the screenshots go to
## Preview/ความคืบหน้า/:
##   godot --path net-sim-3d -s res://tools/validate_progress_dashboard.gd

const SHOTS := "res://../Preview/ความคืบหน้า"

var failures := 0
var flow: Node


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, title: String) -> void:
	print("PASS: " if condition else "FAIL: ", title)
	if not condition:
		failures += 1


func run() -> void:
	flow = root.get_node("GameFlow")
	var real_settings: String = flow.save_file
	flow.save_file = OS.get_user_data_dir().path_join("validate_progress_dashboard.cfg")
	var real_progress := GameProgress.save_path
	GameProgress.save_path = OS.get_user_data_dir().path_join("validate_progress_dashboard.json")
	GameProgress.clear()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	change_scene_to_file("res://scenes/start_menu.tscn")
	await process_frame
	await process_frame

	# Home: five painted buttons, Progress is the fourth.
	flow.show_home()
	var names := []
	for button in flow._home_hotspots.find_children("*Hotspot", "Button", true, false):
		names.append(String(button.name))
	check(names == ["PLAYHotspot", "CONTINUEHotspot", "SETTINGSHotspot", "PROGRESSHotspot", "EXIT TO LOBBYHotspot".replace(" ", "")], "home has five buttons in order: %s" % [names])
	await _shot("home_th")

	# Empty progress: every level unplayed, no details to open.
	flow.show_progress()
	await process_frame
	check(flow._screen == "progress", "progress button opens the dashboard")
	for level in range(1, 7):
		var details := flow._body.find_child("Level%dDetails" % level, true, false) as Button
		check(details != null and details.disabled, "level %d: no results yet, details disabled" % level)
	await _shot("overview_empty")

	# Old save format (before the attempt log): history falls back to the last result.
	var old := FileAccess.open(GameProgress.save_path, FileAccess.WRITE)
	old.store_string(JSON.stringify({"4": {"attempts": 2, "best_total": 64, "best_stars": 2, "last": {"total": 64, "stars": 2, "passed": true, "correctness": 24, "process": 30, "time": 10, "elapsed_sec": 512.0, "mistakes": ["ลืมปิดเครื่องก่อนถอดการ์ด"], "finished_at": "2026-11-12T10:05:00"}}}))
	old.close()
	check(GameProgress.history(4).size() == 1 and int(GameProgress.history(4)[0]["total"]) == 64, "old save: history is the last result")

	# Attempts: level 1 three times (fail, pass, rainbow), level 2 once, level 3 failed.
	_attempt(1, 6, 1, 3, 400.0, ["เลือก Hub แทน Switch"], [40.0, 300.0, 60.0])
	_attempt(1, 24, 2, 3, 260.0, ["ต่อ Access Point ผิดช่อง"], [30.0, 190.0, 40.0])
	_attempt(1, 30, 3, 3, 38.7, [], [12.5, 51.0, 9.2])
	_attempt(2, 24, 6, 9, 520.0, ["เรียงสีสายผิดฝั่ง B", "ไม่ทดสอบสายก่อนส่งงาน"])
	_attempt(3, 6, 2, 8, 900.0, ["ping ผิดเครื่อง"])
	check(GameProgress.history(1).size() == 3, "level 1 keeps three attempts")
	check(GameProgress.level_record(1)["history"][0]["mistakes"] == ["เลือก Hub แทน Switch"], "an attempt keeps its mistakes")
	for i in GameProgress.HISTORY_LIMIT + 5:
		_attempt(6, 30, 4, 4, 300.0, [])
	check(GameProgress.history(6).size() == GameProgress.HISTORY_LIMIT, "history is capped at %d" % GameProgress.HISTORY_LIMIT)
	check(int(GameProgress.level_record(6)["attempts"]) == GameProgress.HISTORY_LIMIT + 5, "attempt count still counts every attempt")
	# Level 6 is only for the cap test; drop it so the screenshots look like a learner's.
	var all := GameProgress.load_all()
	all.erase("6")
	var file := FileAccess.open(GameProgress.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(all))
	file.close()

	flow.show_progress()
	await process_frame
	var details_1 := flow._body.find_child("Level1Details", true, false) as Button
	check(details_1 != null and not details_1.disabled, "level 1 details can be opened")
	check((flow._body.find_child("Level5Details", true, false) as Button).disabled, "unplayed level 5 has no details")
	await _shot("overview")
	await _shot("overview_bottom", true)

	details_1.pressed.emit()
	await process_frame
	check(flow._screen == "progress_level", "details opens the level page")
	check(flow._scroll.scroll_vertical == 0, "the level page opens at its top (overview was scrolled down)")
	var chart: Control = flow._body.find_child("ScoreChart", true, false)
	var expected := GameProgress.history(1).map(func(e): return int(e["total"]))
	check(chart != null and chart.scores == expected and expected == [36, 73, 100], "chart shows each attempt's score: %s" % [chart.scores if chart else null])
	var table := flow._body.find_child("HistoryTable", true, false) as VBoxContainer
	check(table != null and table.get_child_count() == 1 + 3, "history table: header + 3 attempts")
	if table:
		var newest := table.get_child(1)
		check((newest.find_child("Cell0", true, false) as Label).text == "3" and (newest.find_child("Cell2", true, false) as Label).text == "100 / 100", "newest attempt first")
	check(flow._body.find_children("Section*", "PanelContainer", true, false).size() == 4 and flow._body.find_child("StepTimes", true, false) != null, "level page has five sections: chart, latest result, time per step (StepTimes), mistakes, history")
	# Time per step (teacher's request 2026-11-24).
	var steps_card: Control = flow._body.find_child("StepTimes", true, false) as Control
	check(steps_card != null, "level page has the time-per-step card")
	if steps_card:
		var rows: Array = steps_card.find_children("StepTime*", "HBoxContainer", true, false)
		check(rows.size() == 3, "one row per step of level 1 (%d)" % rows.size())
		if rows.size() == 3:
			var middle := rows[1].find_child("StepSeconds", true, false) as Label
			check(middle.text.begins_with("0:51"), "step 2 of the latest attempt: 0:51 (%s)" % middle.text)
			var fill := (rows[1].get_children().filter(func(c): return c is ProgressBar)[0] as ProgressBar).get_theme_stylebox("fill") as StyleBoxFlat
			check(fill.bg_color == Color("e08a1e"), "the longest step's bar is orange (ProgressDashboard.SLOW)")
			var avg_found := false
			for label in rows[0].find_children("*", "Label", true, false):
				avg_found = avg_found or (label as Label).text.begins_with("เฉลี่ย 0:28")
			check(avg_found, "step 1 shows the average over 3 attempts (0:28)")
	await _shot("level_1")
	await _shot("level_1_steps", false, steps_card)
	await _shot("level_1_bottom", true)
	check(flow._scroll.scroll_vertical > 0, "the level page scrolls inside the card")
	var window := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var back := flow._top_bar.find_child("ProgressLevelBack", false, false) as Button
	check(back != null and back.is_visible_in_tree() and not flow._scroll.is_ancestor_of(back), "the back button sits above the scrolling page")
	if back:
		check(window.encloses(back.get_global_rect()) and back.get_global_rect().end.y <= flow._scroll.get_global_rect().position.y, "the back button stays in view, above the page, scrolled to the bottom: %s" % back.get_global_rect())
	check(window.encloses(flow._card.get_global_rect()), "the card stays whole on screen while scrolled (rounded corners visible): card %s window %s" % [flow._card.get_global_rect(), window])

	flow.show_progress_level(4)
	await process_frame
	check(flow._body.find_child("HistoryTable", true, false).get_child_count() == 1 + 1, "old-format level shows its last result")
	check(flow._body.find_children("Mistake", "Label", true, false).size() == 1, "old-format level lists its mistake")
	var no_steps := false
	for label in flow._body.find_child("StepTimes", true, false).find_children("*", "Label", true, false):
		no_steps = no_steps or (label as Label).text.contains("ยังไม่มีเวลารายขั้นตอน")
	check(no_steps, "an attempt from before step timing says it has none")
	await _shot("level_4_old_save")
	flow.show_progress_level(2)
	await process_frame
	check(flow._body.find_children("Mistake", "Label", true, false).size() == 2, "level 2 lists both mistakes")
	await _shot("level_2_bottom", true)

	# Mistakes with where / why / when (2026-11-24): one card each.
	var score5 := MissionScore.compute(30, 6, 8, 300.0, 120.0, 900.0)
	score5.mistakes = PackedStringArray(["กด Allow access ให้ Unknown_Update.exe ที่ไม่ทราบผู้ผลิต — ควรกด Cancel ให้การเชื่อมต่อยังถูกปิดกั้นไว้", "ไม่ได้เปิด Protection history ก่อนส่งผล — ควรยืนยันว่ากักกันไฟล์แล้วจริง"])
	GameProgress.record_attempt(5, score5, {"mistake_log": [
		{"text": score5.mistakes[0], "what": "", "why": "", "step": 4, "step_name": "จัดการการแจ้งเตือนของ Firewall", "at_sec": 161.0, "at_end": false},
		{"text": score5.mistakes[1], "what": "", "why": "", "step": 7, "step_name": "ตรวจสถานะและส่งผลการตรวจสอบ", "at_sec": 402.0, "at_end": true}]})
	flow.show_progress_level(5)
	await process_frame
	var mistake_cards: Array = flow._body.find_children("MistakeCard*", "PanelContainer", true, false)
	check(mistake_cards.size() == 2, "level 5: a card per mistake (%d)" % mistake_cards.size())
	if mistake_cards.size() == 2:
		var when_1 := (mistake_cards[0].find_child("MistakeWhen", true, false) as Label).text
		var why_1 := (mistake_cards[0].find_child("MistakeWhy", true, false) as Label).text
		var when_2 := (mistake_cards[1].find_child("MistakeWhen", true, false) as Label).text
		check(when_1.begins_with("นาทีที่ 2:41") and when_1.contains("ขั้นที่ 4"), "card 1 says when: %s" % when_1)
		check(why_1.begins_with("ควรกด Cancel"), "card 1 says why: %s" % why_1)
		check(when_2.begins_with("ตอนส่งงาน นาทีที่ 6:42"), "a mistake found at hand-in says so: %s" % when_2)
		await _shot("level_5_mistakes", false, mistake_cards[0].get_parent().get_parent() as Control)

	(flow._top_bar.find_child("ProgressLevelBack", false, false) as Button).pressed.emit()
	check(flow._screen == "progress", "back returns to the overview")
	(flow._top_bar.find_child("ProgressBack", false, false) as Button).pressed.emit()
	check(flow._screen == "home", "back returns to the main menu")

	GameProgress.clear()
	GameProgress.save_path = real_progress
	DirAccess.remove_absolute(flow.save_file)
	flow.save_file = real_settings
	print("PROGRESS_DASHBOARD_FINISHED failures=", failures)
	quit(1 if failures else 0)


func _attempt(level: int, correctness: int, right: int, decisions: int, seconds: float, mistakes: Array, step_secs: Array = []) -> void:
	var score := MissionScore.compute(correctness, right, decisions, seconds, 120.0, 900.0)
	score.mistakes = PackedStringArray(mistakes)
	var names := ["รับภารกิจจากหัวหน้างาน Data Center", "เลือกอุปกรณ์เครือข่ายใน NetPlan EDU ที่คอมพิวเตอร์ของคุณ (IT-PC-01)", "รายงานผลกับหัวหน้างาน Data Center"]
	var steps := []
	for i in step_secs.size():
		steps.append({"step": i + 1, "name": names[i % names.size()], "sec": step_secs[i]})
	GameProgress.record_attempt(level, score, {"step_times": steps} if not steps.is_empty() else {})


func _shot(name: String, bottom := false, show: Control = null) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await process_frame
	if show:
		flow._scroll.ensure_control_visible(show)
		for i in 3:
			await process_frame
	if bottom:
		flow._scroll.scroll_vertical = 100000
		for i in 3:
			await process_frame
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOTS)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(name + ".png"))
