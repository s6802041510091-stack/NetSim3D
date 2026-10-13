extends SceneTree

## Headless check for the Network Designer program (Mission 1 software).
## Run: godot --headless --path net-sim-3d -s res://tools/validate_network_designer.gd

var failures := 0
var completed_result := []
var mistake_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("DESIGNER CHECK FAILED: " + message)


func _run() -> void:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 3:
		await physics_frame
	var manager: ComputerManager = map.get_node("Computers")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var pc := manager.find_host("IT-PC-01")
	manager.open_computer(pc, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.4).timeout
	var desktop: DesktopOS = manager.desktop
	_check(desktop._desktop.visible, "desktop not ready")
	_check(desktop._designer_icon.visible, "Network Designer icon missing on the desktop")

	var opened := []
	desktop.app_opened.connect(func(id, app): opened.append(id))
	var app := desktop.open_network_designer()
	_check(app != null and opened == ["network_designer"], "Network Designer did not open")
	app.mistake_made.connect(func(_r, _p): mistake_count += 1)
	app.completed.connect(func(s, t, m): completed_result.append([s, t, m]))
	await process_frame

	# Step 5-7: topology question.
	_check(app.stage == NetworkDesigner.Stage.BRIEF and app._brief_page.visible, "brief page not shown first")
	_check(not app.choose_topology("bus"), "Bus accepted")
	_check(app.score == 90 and app._banner_label.text.contains("Bus"), "wrong topology not penalised/explained")
	_check(not app.choose_topology("mesh"), "Mesh accepted")
	_check(app.choose_topology("star"), "Star rejected")
	_check(app.stage == NetworkDesigner.Stage.DESIGN and app._design_page.visible, "design page not shown after Star")
	var score := 80

	# Step 9 + 11: placing devices.
	_check(not app.try_place("hub", "switch"), "Hub accepted as switch")
	score -= 5
	_check(app._banner_label.text.contains("Hub"), "hub reason missing")
	_check(not app.try_place_at("router", Vector2(20, 20)), "device placed outside a slot")
	score -= 5
	_check(not app.try_place("switch", "router"), "Switch accepted in router slot")
	score -= 5
	_check(app.try_place("router", "router"), "router not placed")
	_check(app.try_place("switch", "switch"), "switch not placed")
	_check(app.try_place("teacher_pc", "teacher"), "teacher PC not placed")
	_check(not app.try_place("student_pc", "router"), "occupied slot accepted a device")
	_check(app.score == score, "occupied slot should not cost points (score %d, expected %d)" % [app.score, score])
	for i in range(1, NetworkDesigner.STUDENT_COUNT + 1):
		_check(app.try_place("student_pc", "student%d" % i), "student PC %d not placed" % i)

	# Step 12 early: cables missing.
	var problems := app.check_answer()
	score -= 5
	_check(problems.size() >= 3 and app.stage == NetworkDesigner.Stage.DESIGN, "unfinished design passed the check")

	# Step 10 + 11: cables.
	var router: Panel = app.get_slot("router").device
	var switch: Panel = app.get_slot("switch").device
	var teacher: Panel = app.get_slot("teacher").device
	_check(not app.try_link(app.internet_node, "ISP", router, "LAN1"), "Internet into router LAN accepted")
	score -= 5
	_check(app._banner_label.text.contains("WAN"), "WAN hint missing")
	_check(app.try_link(app.internet_node, "ISP", router, "WAN"), "Internet -> WAN rejected")
	_check(not app.try_link(router, "LAN1", switch, "3"), "router into switch port 3 accepted")
	score -= 5
	_check(app.try_link(router, "LAN1", switch, "Uplink"), "router LAN -> switch uplink rejected")
	var student1: Panel = app.get_slot("student1").device
	_check(not app.try_link(student1, "LAN", router, "LAN2"), "PC straight into router accepted")
	score -= 5
	_check(not app.try_link(teacher, "LAN", switch, "Uplink"), "busy uplink accepted")
	_check(app.score == score, "busy port should not cost points")
	_check(app.try_link(teacher, "LAN", switch, "1"), "teacher -> switch rejected")
	for i in range(1, NetworkDesigner.STUDENT_COUNT + 1):
		var pc_node: Panel = app.get_slot("student%d" % i).device
		_check(app.try_link(pc_node, "LAN", switch, str(i + 1)), "student %d -> switch rejected" % i)

	# Step 12-13: final check.
	problems = app.check_answer()
	_check(problems.is_empty(), "correct design failed: " + " | ".join(problems))
	_check(app.stage == NetworkDesigner.Stage.DONE and app._result_page.visible, "result page not shown")
	_check(app.score == score, "final score %d, expected %d" % [app.score, score])
	_check(completed_result.size() == 1 and completed_result[0][0] == score and completed_result[0][2] == app.mistakes, "completed signal wrong: " + str(completed_result))
	_check(mistake_count == app.mistakes, "mistake signals %d vs %d" % [mistake_count, app.mistakes])
	_check(app._result_text.text.contains("เวลาที่ใช้"), "time not shown")

	# Close the program, then leave the computer (step 14).
	app.close_requested.emit()
	await process_frame
	_check(not desktop._windows.has("network_designer"), "program window did not close")
	manager.close_computer()
	await create_timer(manager.zoom_time + 0.2).timeout
	_check(not player.controls_locked and not desktop.visible, "did not return to first person")

	# Computers without the program installed do not show it.
	var other := manager.find_host("PC-R1-L1")
	other.installed_apps = PackedStringArray()
	manager.open_computer(other, player)
	await create_timer(manager.zoom_time + DesktopOS.BOOT_TIME + 0.4).timeout
	_check(not desktop._designer_icon.visible and desktop.open_network_designer() == null, "program shown on a computer without it")
	manager.close_computer()
	await create_timer(manager.zoom_time + 0.2).timeout

	if failures == 0:
		print("NETWORK_DESIGNER_VALID score=", score, " mistakes=", mistake_count)
		quit()
	else:
		print("NETWORK_DESIGNER_INVALID failures=", failures)
		quit(1)
