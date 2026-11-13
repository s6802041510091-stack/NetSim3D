extends SceneTree

## Mission 4 checks: scoring rules, then the whole level played headless.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_04.gd

var failures := 0


func _initialize() -> void:
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


func _finish_dialogue(dialogue: DialogueBox) -> void:
	var guard := 0
	while dialogue.is_open() and not dialogue.choosing and guard < 60:
		dialogue.advance(true)
		guard += 1
	await _frames(2)


func _wait_until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame
	return cond.call()


func _test_rules() -> void:
	var s := Mission04State.new()
	s.note_tool("cable_tester")
	s.note_verdict("cable_ok")
	s.note_swap("nic_suspect")
	s.note_fix("replace_nic")
	s.note_part("nic")
	s.note_ping("192.168.1.1", "192.168.1.1", 4)
	var best := s.mission_score(60.0, 600.0, 1500.0)
	_check(best.correctness == 30 and best.process == 50 and best.time == 20 and best.mistakes.is_empty(), "perfect run 30/50/20 (%d/%d/%d)" % [best.correctness, best.process, best.time])
	var w := Mission04State.new()
	w.note_tool("crimper")
	w.note_tool("cable_tester")
	w.note_verdict("cable_ok")
	w.note_swap("cable_bad")
	w.note_swap("nic_suspect")
	_check(not w.note_fix("new_cable") and w.note_fix("replace_nic"), "fix: wrong then right")
	w.note_part("nic")
	w.note_ping("8.8.8.8", "192.168.1.1", 4)
	w.note_ping("192.168.1.1", "192.168.1.1", 4)
	var part := w.mission_score(60.0, 600.0, 1500.0)
	# correctness 15 (2nd try); process: verdict + part = 2 x 10.
	_check(part.correctness == 15 and part.process == 20 and w.verified_ping, "mistakes: correctness 15, process 20 (%d/%d)" % [part.correctness, part.process])
	_check(part.mistakes.size() == 4, "4 mistake lines: %s" % [part.mistakes])
	var late := Mission04State.new()
	for id in ["new_cable", "restart_network", "replace_nic"]:
		late.note_fix(id)
	_check(late.correctness_points() == 0, "right fix on the 3rd try: correctness 0")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://test_validate_progress_m4.json"
	GameProgress.clear()
	_test_rules()
	var flow := root.get_node("GameFlow")
	_check(4 in flow.AVAILABLE, "Level 4 is selectable")
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	flow.configure_level(map, 4)
	root.add_child(map)
	for i in 3:
		await physics_frame
	var mission: Mission04Controller = map.get_node_or_null("Mission04")
	_check(mission != null, "Level 4 has the Mission04 controller")
	if mission == null:
		_finish()
		return
	var manager: ComputerManager = map.get_node("Computers")
	var pc := manager.find_host("STAFF-PC-01")
	var pc3 := manager.find_host("STAFF-PC-03")
	var teacher := map.get_node("TeacherFemale") as NpcCharacter
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var desktop := manager.desktop
	_check(map.get_node_or_null("Mission03") == null and map.get_node_or_null("Mission06") == null, "no other mission controllers")
	_check(not pc.network_connected and pc.collision_layer == 0 and teacher.seated, "her PC has no link and is in use (she sits there)")
	_check(pc.has_app("browser") and not manager.find_host("IT-PC-01").has_app("browser"), "browser only on the staff PCs of this level")
	_check(mission.phone.ringing and mission.stage == Mission04Controller.Stage.CALL, "the desk phone rings")
	_check(mission.hud.steps.size() == 11 and mission.hud.steps[0][1] == ObjectiveHUD.STEP_ACTIVE, "tracker: 11 steps, the phone first")
	_check(not mission.tower.port.link_on and mission.tower.port.plugged, "NIC port: cable in, no LED")

	# 1. The call.
	mission.phone.use(player)
	await _frames(2)
	_check(mission.dialogue.is_open(), "the call opens")
	await _finish_dialogue(mission.dialogue)
	await _frames(2)
	_check(mission.stage == Mission04Controller.Stage.MEET and mission._timing and not mission.phone.ringing, "after the call: go to the teacher, timer running")
	_check(mission.marker.target == teacher, "arrow on the teacher")

	# 2. Meet her: she gets up and waits aside.
	mission._on_teacher_talked(player)
	await create_timer(0.8).timeout
	await _finish_dialogue(mission.dialogue)
	_check(mission.stage == Mission04Controller.Stage.INSPECT, "inspect stage")
	_check(await _wait_until(func(): return not teacher.walking and not teacher.seated and teacher.global_position.distance_to(Mission04Controller.TEACHER_WAIT) < 0.1, 10.0), "she waits beside her desk")
	_check(pc.collision_layer == ComputerStation.COLLISION_LAYER, "her PC is free for the player")

	# 3. Symptoms: before the fix ping fails and the browser has no page.
	manager.open_computer(pc, player)
	await create_timer(3.4).timeout
	_check(mission.saw_screen and desktop._tray_network.text == "LAN ✗", "screen shows LAN ✗")
	desktop._open_cmd()
	desktop.run_command("ipconfig")
	_check(desktop._cmd_output.get_parsed_text().contains("Media disconnected"), "ipconfig: media disconnected")
	desktop.open_browser()
	var page: Control = desktop.find_child("Page", true, false)
	_check(page != null and str(page.get_child(0).text).contains("ไม่สามารถเชื่อมต่อ"), "browser: no Internet page")
	manager.close_computer()
	await create_timer(1.0).timeout
	await mission.use_tower(player)
	_check(mission.saw_port and mission.stage == Mission04Controller.Stage.TEST, "port seen (no LED): test stage")

	# 4. The tool (wrong first), the tester, the verdict (wrong first).
	mission.use_tower(player)
	await _frames(2)
	_check(mission.choice.is_open() and mission.choice.ids.size() == 4, "tool list opens")
	mission.choice.pick("crimper")
	_check(mission.choice.is_open() and (mission.choice.buttons["crimper"] as Button).disabled, "wrong tool: hint, choose again")
	mission.choice.pick("cable_tester")
	_check(await _wait_until(func(): return mission._click_waiting, 4.0), "tester: click the plug at her PC to pull it out")
	_check(mission._click_layer.visible and mission._click_hint.text.contains("ถอด"), "click hint shown: " + mission._click_hint.text)
	mission.click_now()
	_check(await _wait_until(func(): return mission.board.active, 5.0), "heads on the desk: plug them into the tester by hand")
	_check(not mission.tower.port.plugged, "cable off her PC")
	_check(mission.board.plug_into("end1", "MAIN") and mission.board.plug_into("end2", "REMOTE"), "both heads go into MAIN and REMOTE")
	_check(await _wait_until(func(): return mission._click_waiting and mission._click_hint.text.contains("POWER"), 4.0), "then click POWER on the tester")
	mission.click_now()
	_check(await _wait_until(func(): return mission._click_waiting and mission._click_hint.text.contains("TEST"), 3.0), "then click TEST")
	mission.click_now()
	_check(await _wait_until(func(): return mission.dialogue.choosing, 8.0), "the verdict question after the scan")
	_check(mission.tester != null and mission.tester.is_on, "tester powered and testing")
	mission.dialogue.choose(1)
	await create_timer(1.6).timeout
	_check(mission.state.verdict_first == "cable_bad" and mission.dialogue.choosing, "wrong verdict noted, asked again")
	mission.dialogue.choose(0)
	for i in 2:
		_check(await _wait_until(func(): return mission._click_waiting, 4.0), "pull head %d out of the tester" % (i + 1))
		mission.click_now()
	_check(await _wait_until(func(): return mission.stage == Mission04Controller.Stage.SWAP and not mission._busy, 5.0), "cable OK: swap stage")
	_check(not mission.tower.port.plugged, "the cable is in the tool case, not in her PC")

	# 5. Swap test at STAFF-PC-03: plug by hand, conclude, pull out, plug back.
	mission.use_swap_pc(player)
	_check(await _wait_until(func(): return mission.board.active, 4.0), "STAFF-PC-03: plug the cable in by hand")
	mission.board.plug_into("cable", "nic")
	_check(await _wait_until(func(): return mission.choice.is_open(), 6.0), "conclusion asked")
	_check(pc3.network_connected and mission.swap_tower.port.link_on and mission.swap_tower.port.plugged, "STAFF-PC-03 online with the same cable")
	mission.choice.pick("nic_suspect")
	_check(await _wait_until(func(): return mission._click_waiting, 4.0), "pull the cable out of STAFF-PC-03")
	mission.click_now()
	_check(await _wait_until(func(): return mission.cable_home_pending and not mission._busy, 4.0), "carry the cable back to her PC")
	_check(not pc3.network_connected and not mission.swap_tower.port.plugged, "STAFF-PC-03 unplugged")
	_check(mission.tower_spot.get_prompt_text().contains("กลับ"), "her PC asks for the cable: " + mission.tower_spot.get_prompt_text())
	mission.use_tower(player)
	_check(await _wait_until(func(): return mission.board.active, 4.0), "plug it back in by hand")
	mission.board.plug_into("cable", "nic")
	_check(await _wait_until(func(): return mission.stage == Mission04Controller.Stage.ANALYZE and mission.choice.is_open(), 6.0), "analysis with the evidence")
	_check(mission.tower.port.plugged and not mission.tower.port.link_on, "cable back in her PC, still no LED")
	_check(mission.choice.ids.size() == 5, "5 options")

	# 6. Analysis: a wrong one first, then the NIC.
	mission.choice.pick("restart_network")
	_check(mission.choice.is_open() and mission.choice._feedback.text.contains("คอมพิวเตอร์เครื่องอื่น"), "hint for restart: " + mission.choice._feedback.text)
	mission.choice.pick("replace_nic")
	await _frames(2)
	_check(mission.stage == Mission04Controller.Stage.FETCH and not player.controls_locked, "go fetch the spare part")

	# 7. The parts box.
	mission.open_parts(player)
	_check(mission.choice.is_open() and mission.choice.ids.size() == 4, "parts box opens")
	mission.choice.pick("nic")
	await _frames(2)
	_check(mission.stage == Mission04Controller.Stage.REPLACE and mission.has_spare and not player.controls_locked, "spare NIC taken, player can walk again")

	# 8. Replace.
	var eye_home: Transform3D = player.camera.transform
	_check(mission.tower.has_service(), "her PC model has the parts for the hands-on repair")
	mission.use_tower(player)
	# Every step is a click (or plugging the LAN cable by hand); count them.
	var steps := 0
	var hints := PackedStringArray()
	var orbit_checked := false
	var t0 := Time.get_ticks_msec()
	while mission.stage == Mission04Controller.Stage.REPLACE and Time.get_ticks_msec() - t0 < 90000:
		if mission._click_waiting:
			hints.append(mission._click_hint.text)
			if mission._click_hint.text.contains("ปิดเครื่องก่อน"):
				_check(mission.tower.powered, "PC still on before the Power click")
			mission.click_now()
			steps += 1
		elif mission._drag_waiting:
			hints.append(mission._click_hint.text)
			mission.drag_now()
			steps += 1
		elif mission._hold_waiting:
			if not orbit_checked:
				orbit_checked = true
				var before: Vector3 = player.camera.global_position
				var wheel := InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_UP
				wheel.pressed = true
				var used: bool = mission._orbit_on and mission._orbit_input(wheel)
				var turn := InputEventMouseButton.new()
				turn.button_index = MOUSE_BUTTON_RIGHT
				turn.pressed = true
				mission._orbit_input(turn)
				var move := InputEventMouseMotion.new()
				move.relative = Vector2(60, 0)
				mission._orbit_input(move)
				turn.pressed = false
				mission._orbit_input(turn)
				_check(used and player.camera.global_position.distance_to(before) > 0.005, "free look: zoom and orbit move the camera during the repair")
			hints.append(mission._click_hint.text)
			mission.hold_now()
			steps += 1
		elif mission.board.active and not mission.board.is_plugged("cable"):
			mission.board.plug_into("cable", "nic")
			steps += 1
		await process_frame
	_check(hints.size() >= 16 and " / ".join(hints).contains("คายประจุ"), "repair includes the anti-static touch")
	_check(steps >= 17, "repair by hand: %d steps (%s)" % [steps, " / ".join(hints)])
	_check(mission.tower.find_child("Cover_Screw_1", true, false).visible and mission.tower.find_child("Cover_Screw_2", true, false).visible, "cover screws are back in")
	_check(mission.tower.find_child("Side_Cover", true, false).visible, "side cover is back on")
	await create_timer(0.5).timeout
	_check(not player.camera.top_level and player.camera.transform.is_equal_approx(eye_home), "camera back at the player's eyes after the repair")
	_check(mission.stage == Mission04Controller.Stage.VERIFY and pc.network_connected and mission.tower.port.link_on and mission.tower.powered, "new NIC: LED on, PC online")

	# 9. Verify: ping the gateway and open the website.
	manager.open_computer(pc, player)
	await create_timer(3.4).timeout
	desktop._open_cmd()
	desktop.run_command("ping 192.168.1.1")
	await create_timer(2.4).timeout
	_check(mission.state.ping_right and mission.state.verified_ping, "ping to the Default Gateway noted")
	desktop.open_browser()
	page = desktop.find_child("Page", true, false)
	_check(mission.state.verified_web, "the website opens")
	_check(mission.stage == Mission04Controller.Stage.TELL, "tell the teacher next")
	manager.close_computer()
	await create_timer(1.0).timeout

	# 10. Tell her: she sits back down, thanks.
	mission._on_teacher_talked(player)
	await create_timer(0.8).timeout
	await _finish_dialogue(mission.dialogue)
	_check(await _wait_until(func(): return teacher.seated and mission.dialogue.is_open(), 15.0), "she sits back at her desk and thanks the player")
	await _finish_dialogue(mission.dialogue)
	_check(mission.stage == Mission04Controller.Stage.REPORT and pc.collision_layer == 0, "report to the supervisor next")

	# 11. Report.
	mission._on_supervisor_talked(player)
	await create_timer(1.0).timeout
	await _finish_dialogue(mission.dialogue)
	await _frames(3)
	var score := mission.score
	_check(score != null and score.correctness == 15 and score.process == 30, "score: correctness 15, process 30 (%s)" % ["-" if score == null else "%d/%d/%d" % [score.correctness, score.process, score.time]])
	_check(mission.summary.visible and GameProgress.best_score(4) == score.total(), "summary shown, progress recorded")
	map.queue_free()
	await _frames(2)
	GameProgress.clear()
	_finish()


func _finish() -> void:
	if failures == 0:
		print("MISSION_04_VALID")
		quit()
	else:
		print("MISSION_04_INVALID failures=", failures)
		quit(1)
