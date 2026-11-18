extends SceneTree

## Menu, level select, unlocking, audio settings and the six levels' setup.
## Updated 2026-11-18: all six levels are built (the old version expected
## levels 3-4 to be locked), the level select is painted artwork with
## hotspots, and a level is ready once GameFlow has prepared the world (the
## tree is already paused behind the loading screen).
## Run with a separate APPDATA so real settings and progress are untouched.

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
	# In the editor SavePaths points at the project's .saves/ (the developer's
	# own settings), not APPDATA: write menu settings to a scratch file.
	var real_settings: String = flow.save_file
	flow.save_file = OS.get_user_data_dir().path_join("validate_game_menu.cfg")
	var real_progress := GameProgress.save_path
	GameProgress.save_path = OS.get_user_data_dir().path_join("validate_game_menu_progress.json")
	GameProgress.clear()
	change_scene_to_file("res://scenes/start_menu.tscn")
	await process_frame
	await process_frame
	flow.show_home()
	check(flow._layer.visible, "main menu visible")
	check(not paused, "menu does not pause tree")

	# Level select: six levels, all playable from the editor.
	check(flow.AVAILABLE == [1, 2, 3, 4, 5, 6], "all six levels are built")
	flow.show_levels()
	for level in range(1, 7):
		var hotspot := flow._home_hotspots.find_child("Level%dHotspot" % level, true, false) as Button
		check(hotspot != null and not hotspot.disabled, "level %d listed and playable in the editor" % level)

	# Unlocking (exported builds): level 1 open, the next opens once passed.
	check(GameProgress.is_unlocked(1, flow.AVAILABLE) and not GameProgress.is_unlocked(2, flow.AVAILABLE), "fresh progress: only level 1 open")
	var file := FileAccess.open(GameProgress.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"1": {"best_total": MissionScore.PASS_SCORE}}))
	file.close()
	check(GameProgress.is_unlocked(2, flow.AVAILABLE) and not GameProgress.is_unlocked(3, flow.AVAILABLE), "passing level 1 opens level 2 only")
	GameProgress.clear()

	for bus in ["Music", "SoundEffect", "Sound"]:
		flow.set_volume(bus, 0.0)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus + " mute")
		flow.set_volume(bus, 37.0)
		check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus + " unmute")
		check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)), 0.37), bus + " gain")
	flow.load_preferences()
	check(flow.volumes.Sound == 37.0 and flow.volumes.Music == 37.0, "volume persists")

	for level in range(1, 7):
		flow.start_level(level)
		var deadline := Time.get_ticks_msec() + 180000
		# Ready = the loading bar has finished and the start prompt is up
		# (_world_prepared alone is set while the bar is still filling).
		while not (flow._awaiting_start and not flow.loading and current_scene and current_scene.scene_file_path == flow.MAP) and Time.get_ticks_msec() < deadline:
			await process_frame
		for i in 3:
			await process_frame
		check(current_scene.scene_file_path == flow.MAP, "level %d: school scene loaded" % level)
		if current_scene.scene_file_path != flow.MAP:
			break
		check(paused, "level %d ready screen pauses the world" % level)
		check(flow.last_level == level, "Continue selects last successful level")
		flow.load_preferences()
		check(flow.last_level == level, "Continue persisted to disk")
		var manager := current_scene.get_node("Computers")
		check(manager.stations.size() == 29, "29 computers retained")
		var counts := {"netplan_edu": 0, "windows_security": 0, "teamviewer": 0, "browser": 0, "mail": 0}
		for station in manager.stations:
			for app in counts:
				if station.has_app(app):
					counts[app] += 1
		# Level 1 installs NetPlan EDU after the supervisor's briefing, not at load.
		check(counts.netplan_edu == 0, "NetPlan waits for the level 1 briefing")
		check(counts.browser == (2 if level == 4 else 0), "only level 4 installs the browser (2 staff PCs)")
		check(counts.windows_security == (1 if level == 5 else 0), "only level 5 installs Security")
		check(counts.teamviewer == (1 if level == 6 else 0), "only level 6 installs TeamViewer")
		check(counts.mail == (1 if level == 6 else 0), "only level 6 installs Mail")
		for mission in range(1, 7):
			check(current_scene.has_node("Mission%02d" % mission) == (level == mission), "level %d: Mission%02d controller only in its level" % [level, mission])
		check(current_scene.has_node("Mission02Props") == (level == 2), "level 2 props isolated")
		var rack: WallRack9U = current_scene.get_node("ComputerRoomRack")
		var want_stage := WallRack9U.Stage.EMPTY if level == 1 else (WallRack9U.Stage.INSTALLED if level == 2 else WallRack9U.Stage.CABLED)
		check(rack.stage == want_stage, "wall rack follows the story")
		# Start: the controls help opens first; closing it starts the level.
		flow.resume_game()
		check(flow._controls_help.visible and paused, "start shows the controls help, world still paused")
		flow._controls_help.dismiss()
		await process_frame
		check(not paused and not flow._layer.visible, "closing the help starts the level")
		flow.pause_game()
		check(paused and flow.paused_menu, "pause stops world")
		flow.show_settings()
		check(paused, "settings keeps world paused")
		flow.return_to_menu()
		await process_frame
		await process_frame
		check(current_scene.scene_file_path == flow.MENU and not paused, "return to lightweight menu")
	GameProgress.save_path = real_progress
	DirAccess.remove_absolute(flow.save_file)
	flow.save_file = real_settings
	print("MENU_VALIDATION_FINISHED failures=", failures)
	quit(1 if failures else 0)
