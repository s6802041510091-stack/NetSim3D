extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	await process_frame
	root.get_node("GameFlow")._layer.hide()
	var station := ComputerStation.new()
	station.hostname = "IT-PC-01"
	root.add_child(station)
	assert(station.installed_apps.is_empty())
	var desktop := DesktopOS.new()
	root.add_child(desktop)
	desktop.station = station
	desktop.visible = true
	desktop._show_desktop()
	assert(not desktop.has_method("open_network_designer"))
	assert(not ResourceLoader.exists("res://scripts/computer/apps/network_designer.gd"))
	for icon in desktop._icons.get_children():
		assert(icon.tooltip_text != "Network Designer")
	assert(not desktop._netplan_icon.visible)
	assert(not desktop._app_menu_buttons.netplan_edu.visible)
	assert(desktop.open_netplan_edu() == null)
	var original_path := Mission01SaveStore.save_path
	Mission01SaveStore.save_path = "user://desktop_apps_check.json"
	station.installed_apps.append("netplan_edu")
	desktop._show_desktop()
	assert(desktop._netplan_icon.visible)
	assert(desktop._app_menu_buttons.netplan_edu.visible)
	var app := desktop.open_netplan_edu()
	assert(app != null and app is NetPlanEdu)
	desktop.power_off()
	desktop.queue_free()
	station.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Mission01SaveStore.save_path))
	Mission01SaveStore.save_path = original_path
	print("DESKTOP_APPS_OK retired app absent; NetPlan hidden until installed, then shown in Desktop/Start and opens")
	quit()
