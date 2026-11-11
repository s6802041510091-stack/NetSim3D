extends SceneTree
const OUTPUT := "D:/NetSim3D/Preview/UI_Desktop_Windows11/actual/"

func _initialize() -> void:
	call_deferred("_check")

func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _click(button: Button) -> void:
	await _settle()
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	root.push_input(event)
	await _settle()

func _shot(name: String) -> void:
	await _settle()
	assert(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK)

func _check() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	var flow := root.get_node("GameFlow")
	var locale := root.get_node("L10n")
	var previous: String = locale.locale
	locale.set_locale("en", false)
	flow._layer.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var station := ComputerStation.new()
	station.hostname = "IT-PC-01"
	root.add_child(station)
	var desktop := DesktopOS.new()
	root.add_child(desktop)
	desktop.station = station
	desktop.show()
	desktop._show_desktop()
	await _shot("desktop-before-work-en")
	assert(not desktop._netplan_icon.visible)
	assert(not desktop._taskbar_buttons.netplan_edu.visible)
	assert(not desktop._app_menu_buttons.netplan_edu.visible)
	station.installed_apps.append("netplan_edu")
	desktop._show_desktop()
	await _shot("desktop-after-work-en")
	assert(desktop._taskbar_buttons.netplan_edu.visible)
	assert(desktop._clock.text.contains("\n"))
	await _click(desktop._taskbar_buttons.cmd)
	assert(desktop._windows.has("cmd"))
	desktop.run_command("hostname")
	assert(desktop._cmd_output.get_parsed_text().contains("IT-PC-01"))
	await _click(desktop._taskbar_buttons.cmd)
	assert(not desktop._windows.cmd.visible)
	await _click(desktop._taskbar_buttons.cmd)
	assert(desktop._windows.cmd.visible)
	desktop._close_window("cmd")
	await _click(desktop._taskbar.find_child("TaskbarSearch", true, false))
	assert(desktop._start_menu.visible and desktop._search.has_focus())
	desktop._search.text = "NetPlan"
	desktop._search.text_changed.emit("NetPlan")
	await _shot("start-search-en")
	var visible_entries := 0
	for entry in desktop._menu_entries:
		visible_entries += 1 if entry.visible else 0
	assert(visible_entries == 1 and desktop._app_menu_buttons.netplan_edu.visible)
	var save_path := Mission01SaveStore.save_path
	Mission01SaveStore.save_path = "user://desktop_shell_test.json"
	await _click(desktop._taskbar_buttons.netplan_edu)
	assert(desktop._netplan != null and desktop._netplan.visible)
	assert(not desktop._start_menu.visible)
	desktop._netplan.emit_signal("minimize_requested")
	await _settle()
	assert(not desktop._netplan.visible)
	assert(desktop._taskbar_buttons.netplan_edu.get_node("Running").visible)
	await _click(desktop._taskbar_buttons.netplan_edu)
	assert(desktop._netplan.visible)
	desktop._netplan.emit_signal("close_requested")
	await _settle()
	assert(not desktop._windows.has("netplan_edu"))
	assert(not desktop._taskbar_buttons.netplan_edu.get_node("Running").visible)
	locale.set_locale("th", false)
	flow._layer.hide()
	desktop._show_desktop()
	await _shot("desktop-after-work-th")
	assert(desktop._taskbar.find_child("TaskbarSearch", true, false).text == "ค้นหา")
	desktop.power_off()
	desktop.queue_free()
	station.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Mission01SaveStore.save_path))
	Mission01SaveStore.save_path = save_path
	locale.set_locale(previous, false)
	print("DESKTOP_SHELL_OK artwork, installed-app gating, native taskbar clicks, command prompt, search, minimize/restore/close and TH/ENG")
	quit()
