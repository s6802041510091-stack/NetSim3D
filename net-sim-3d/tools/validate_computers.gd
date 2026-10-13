extends SceneTree

## Headless check for the computers: E -> zoom -> 2 s set-up -> desktop.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_computers.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("COMPUTER CHECK FAILED: " + message)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	await _frames(3)

	var manager: ComputerManager = map.get_node("Computers")
	_check(manager.stations.size() == 25, "expected 25 computers (24 in the map + DATACENTER-PC), found %d" % manager.stations.size())
	var ips := {}
	for station in manager.stations:
		_check(not ips.has(station.ip_address), "duplicate IP " + station.ip_address)
		ips[station.ip_address] = true
	var it_pc := manager.find_host("IT-PC-01")
	_check(it_pc != null, "IT-PC-01 missing")
	_check(manager.find_host("PC-R1-L1") != null and manager.find_host("PC-R1-L1").ip_address == "192.168.1.11", "student PC naming")

	# Stand at the IT Support player desk, look at its screen.
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.require_mouse_capture = false
	var screen_center: Vector3 = it_pc.screen.global_transform * it_pc.screen.get_aabb().get_center()
	player.global_position = Vector3(-14.35, 0.02, -42.66)
	await _frames(2)
	player.look_at(Vector3(screen_center.x, player.global_position.y, screen_center.z), Vector3.UP)
	var eye: Vector3 = player.camera.global_position
	player.camera.rotation.x = atan2(screen_center.y - eye.y, Vector2(screen_center.x - eye.x, screen_center.z - eye.z).length())
	await _frames(3)
	_check(player.focused_computer == it_pc, "player is not focused on IT-PC-01 (focused: %s)" % str(player.focused_computer))
	_check(player._prompt.visible and player._prompt.text.contains("IT-PC-01"), "computer prompt not shown: " + player._prompt.text)

	var start_position := player.global_position
	var home_camera: Transform3D = player.camera.transform
	player.interact()
	_check(player.controls_locked, "controls not locked after E")

	# Camera zoom (0.7 s), then the set-up screen for 2 s.
	await _frames(int(0.75 * 60) + 2)
	var view := it_pc.get_view_transform(player.camera.fov)
	_check(player.camera.global_position.distance_to(view.origin) < 0.01, "camera did not zoom to the screen")
	_check(manager.desktop.visible and manager.desktop.is_booting, "set-up screen not showing after zoom")
	await create_timer(1.0).timeout
	_check(manager.desktop.is_booting, "set-up ended before 2 seconds")
	await create_timer(1.3).timeout
	_check(not manager.desktop.is_booting and manager.desktop._desktop.visible, "desktop not shown after set-up")

	# Walking is disabled while seated.
	Input.action_press("move_forward")
	await _frames(20)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start_position) < 0.05, "player walked while using the computer")

	# Command Prompt.
	manager.desktop._open_cmd()
	manager.desktop.run_command("ipconfig")
	var out: String = manager.desktop._cmd_output.get_parsed_text()
	_check(out.contains("192.168.1.101") and out.contains("192.168.1.1"), "ipconfig output wrong")
	manager.desktop.run_command("ping 192.168.1.11")
	await create_timer(2.2).timeout
	out = manager.desktop._cmd_output.get_parsed_text()
	_check(out.contains("Reply from 192.168.1.11") and out.contains("Received = 4"), "ping to PC-R1-L1 failed")
	manager.desktop.run_command("ping 192.168.1.250")
	await create_timer(2.2).timeout
	out = manager.desktop._cmd_output.get_parsed_text()
	_check(out.contains("Request timed out.") and out.contains("Received = 0"), "ping to unknown host should time out")
	it_pc.network_connected = false
	manager.desktop.run_command("ipconfig")
	_check(manager.desktop._cmd_output.get_parsed_text().contains("Media disconnected"), "unplugged cable not shown")
	it_pc.network_connected = true

	# Shut down: back to the player's eyes with walking restored.
	manager.close_computer()
	await _frames(int(0.75 * 60) + 3)
	_check(not manager.desktop.visible, "desktop still visible after shut down")
	_check(not player.controls_locked, "controls still locked after shut down")
	_check(not player.camera.top_level and player.camera.transform.is_equal_approx(home_camera), "camera did not return to the head")

	if failures == 0:
		print("COMPUTERS_VALID computers=", manager.stations.size())
		quit()
	else:
		print("COMPUTERS_INVALID failures=", failures)
		quit(1)
