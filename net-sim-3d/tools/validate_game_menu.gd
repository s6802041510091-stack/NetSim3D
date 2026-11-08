extends SceneTree

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
	change_scene_to_file("res://scenes/start_menu.tscn")
	await process_frame
	await process_frame
	flow.show_home()
	check(flow._layer.visible, "main menu visible")
	check(not paused, "menu does not pause tree")
	flow.show_levels()
	var disabled := 0
	for child in flow._body.get_children():
		if child is Button and child.disabled:
			disabled += 1
	check(disabled == 3, "levels 2, 3, 4 explicitly unavailable")
	flow.start_level(2)
	check(not flow.loading and flow.current_level == 0, "unfinished level cannot launch")
	for bus in ["Music", "SoundEffect", "Sound"]:
		flow.set_volume(bus, 0.0)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus + " mute")
		flow.set_volume(bus, 37.0)
		check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), bus + " unmute")
		check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus)), 0.37), bus + " gain")
	flow.load_preferences()
	check(flow.volumes.Sound == 37.0 and flow.volumes.Music == 37.0, "volume persists")
	for level in [1, 5, 6]:
		flow.start_level(level)
		var deadline := Time.get_ticks_msec() + 120000
		while not paused and Time.get_ticks_msec() < deadline:
			await process_frame
		check(paused, "level %d ready screen" % level)
		if not paused:
			break
		check(current_scene.scene_file_path == flow.MAP, "school scene loaded")
		check(flow.last_level == level, "Continue selects last successful level")
		flow.load_preferences()
		check(flow.last_level == level, "Continue persisted to disk")
		var manager := current_scene.get_node("Computers")
		check(manager.stations.size() == 29, "29 computers retained")
		var counts := {"netplan_edu": 0, "windows_security": 0, "teamviewer": 0}
		for station in manager.stations:
			for app in counts:
				if station.has_app(app):
					counts[app] += 1
		check(counts.netplan_edu == (1 if level == 1 else 0), "only level 1 installs NetPlan")
		check(counts.windows_security == (1 if level == 5 else 0), "only level 5 installs Security")
		check(counts.teamviewer == (1 if level == 6 else 0), "only level 6 installs TeamViewer")
		check(current_scene.has_node("Mission06") == (level == 6), "phone mission isolated")
		flow.resume_game()
		check(not paused and not flow._layer.visible, "resume hides overlay")
		flow.pause_game()
		check(paused and flow.paused_menu, "pause stops world")
		flow.show_settings()
		check(paused, "settings keeps world paused")
		flow.return_to_menu()
		await process_frame
		await process_frame
		check(current_scene.scene_file_path == flow.MENU and not paused, "return to lightweight menu")
	print("MENU_VALIDATION_FINISHED failures=", failures)
	quit(1 if failures else 0)
