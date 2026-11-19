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
	_attempt(1, 6, 1, 3, 400.0, ["เลือก Hub แทน Switch"])
	_attempt(1, 24, 2, 3, 260.0, ["ต่อ Access Point ผิดช่อง"])
	_attempt(1, 30, 3, 3, 38.7, [])
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
	check(flow._body.find_children("Section*", "PanelContainer", true, false).size() == 4, "level page has four sections: chart, latest result, mistakes, history")
	await _shot("level_1")
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
	await _shot("level_4_old_save")
	flow.show_progress_level(2)
	await process_frame
	check(flow._body.find_children("Mistake", "Label", true, false).size() == 2, "level 2 lists both mistakes")
	await _shot("level_2_bottom", true)

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


func _attempt(level: int, correctness: int, right: int, decisions: int, seconds: float, mistakes: Array) -> void:
	var score := MissionScore.compute(correctness, right, decisions, seconds, 120.0, 900.0)
	score.mistakes = PackedStringArray(mistakes)
	GameProgress.record_attempt(level, score)


func _shot(name: String, bottom := false) -> void:
	if DisplayServer.get_name() == "headless":
		return
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
