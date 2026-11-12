extends SceneTree

## Mission 3 checks: scoring rules, then the whole level played headless.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_03.gd

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
	while dialogue.is_open() and guard < 60:
		dialogue.advance(true)
		guard += 1
	await _frames(2)


func _test_rules() -> void:
	var s := Mission03State.new()
	s.set_expected("TEACHER-PC", "192.168.1.5", "255.255.255.0", "192.168.1.1", true)
	s.set_expected("PC-R1-L1", "192.168.1.11", "255.255.255.0", "192.168.1.1", true)
	s.set_expected("PC-R5-R2", "192.168.1.30", "255.255.255.0", "192.168.1.1", false)
	_check(not s.ready_to_attach("TEACHER-PC") and not s.attach("NOPE", "", "", "", "reply", "normal"), "nothing attachable before the commands")
	for host in ["TEACHER-PC", "PC-R1-L1", "PC-R5-R2"]:
		s.note_ipconfig(host)
		s.note_ping(host, "192.168.1.1")
	_check(s.ready_to_attach("TEACHER-PC") and s.pinged_gateway("PC-R5-R2"), "ipconfig + ping -> attachable, gateway ping noted")
	s.attach("TEACHER-PC", " 192.168.1.5 ", "255.255.255.0", "192.168.1.1", "reply", "normal")
	s.attach("PC-R1-L1", "192.168.1.11", "255.255.255.0", "192.168.1.1", "reply", "normal")
	s.attach("PC-R5-R2", "192.168.1.30", "255.255.255.0", "192.168.1.1", "timeout", "abnormal")
	_check(not s.attach("PC-R5-R2", "x", "x", "x", "reply", "normal"), "a row is attached once")
	var full := s.mission_score(60.0, 480.0, 1200.0)
	_check(full.correctness == 30 and full.process == 50 and full.time == 20 and full.mistakes.is_empty(), "perfect run: 30 / 50 / 20 (%d/%d/%d)" % [full.correctness, full.process, full.time])
	_check(s.note_harm("netsh") and not s.note_harm("shutdown /r"), "harm counted once")
	var harmed := s.mission_score(60.0, 480.0, 1200.0)
	_check(harmed.process == 45 and harmed.correctness == 30, "harm costs 5 once (process %d)" % harmed.process)

	var w := Mission03State.new()
	w.set_expected("TEACHER-PC", "192.168.1.5", "255.255.255.0", "192.168.1.1", true)
	w.set_expected("PC-R1-L1", "192.168.1.11", "255.255.255.0", "192.168.1.1", true)
	w.set_expected("PC-R5-R2", "192.168.1.30", "255.255.255.0", "192.168.1.1", false)
	for host in ["TEACHER-PC", "PC-R1-L1", "PC-R5-R2"]:
		w.note_ipconfig(host)
	w.note_ping("TEACHER-PC", "192.168.1.1")
	w.note_ping("PC-R1-L1", "8.8.8.8") # not the gateway
	w.note_ping("PC-R5-R2", "192.168.1.1")
	w.attach("TEACHER-PC", "192.168.1.5", "255.255.255.0", "192.168.1.1", "reply", "normal")
	w.attach("PC-R1-L1", "192.168.1.11", "255.255.0.0", "192.168.1.1", "reply", "normal") # wrong mask
	w.attach("PC-R5-R2", "192.168.1.30", "255.255.255.0", "192.168.1.1", "timeout", "normal") # wrong status
	var part := w.mission_score(60.0, 480.0, 1200.0)
	# correctness: only the teacher row -> 10. process: gw 2, values 2, status 2, safe 1 = 7 x 5 = 35.
	_check(part.correctness == 10 and part.process == 35, "mistakes: correctness 10, process 35 (%d / %d)" % [part.correctness, part.process])
	_check(part.mistakes.size() == 3, "3 mistake lines: %s" % [part.mistakes])


func _run() -> void:
	root.size = Vector2i(1280, 720)
	GameProgress.save_path = "user://test_validate_progress_m3.json"
	GameProgress.clear()
	_test_rules()
	var flow := root.get_node("GameFlow")
	_check(3 in flow.AVAILABLE, "Level 3 is selectable")

	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	flow.configure_level(map, 3)
	root.add_child(map)
	for i in 3:
		await physics_frame
	var mission: Mission03Controller = map.get_node_or_null("Mission03")
	_check(mission != null, "Level 3 has the Mission03 controller")
	if mission == null:
		_finish()
		return
	_check(map.get_node_or_null("Mission02") == null and map.get_node_or_null("Mission06") == null, "no other mission controllers")
	var manager: ComputerManager = map.get_node("Computers")
	var teacher_pc := manager.find_host("TEACHER-PC")
	var front := manager.find_host("PC-R1-L1")
	var back := manager.find_host("PC-R5-R2")
	_check(mission.stations.size() == 3 and back.link_fault and not front.link_fault and not teacher_pc.link_fault, "3 sample computers, only the back one is faulty")
	var d_front := teacher_pc.global_position.distance_to(front.global_position)
	var d_back := teacher_pc.global_position.distance_to(back.global_position)
	_check(d_front < d_back, "PC-R1-L1 is nearer the teacher's PC than PC-R5-R2 (%.1f m < %.1f m)" % [d_front, d_back])
	var teacher := map.get_node("TeacherMale") as NpcCharacter
	_check(teacher != null and teacher.seated and teacher.global_position.distance_to(Mission03Controller.TEACHER_SEAT) < 0.05, "male teacher sits working at TEACHER-PC")
	_check(teacher_pc.collision_layer == 0, "TEACHER-PC is in use: the player cannot sit there yet")
	for pair: Array in [[Mission03Controller.TEACHER_CHAIR, Mission03Controller.TEACHER_SEAT, Vector3.RIGHT], ["TR_Chair_2", StaffRoomLife.seat_of("male"), Vector3.BACK], ["TR_Chair_1", StaffRoomLife.seat_of("female"), Vector3.BACK]]:
		var chair: MeshInstance3D = map.get_node("MapVisual").get_node(String(pair[0]))
		var center: Vector3 = chair.global_transform * chair.get_aabb().get_center()
		var off := absf((center - (pair[1] as Vector3)).dot(pair[2]))
		_check(off < 0.02, "chair %s centred under the seated teacher (%.3f m)" % [pair[0], off])
	_check(mission.stage == Mission03Controller.Stage.BRIEFING and mission.marker.target == mission.supervisor, "starts at the briefing, arrow on the supervisor")
	# His walk to the teachers' room clears the map (doors open).
	for d in map.get_node("Doors").get_children():
		d.set_open(true, false)
	await physics_frame
	await physics_frame
	var space := map.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.5
	var points: Array = [Mission03Controller.TEACHER_SEAT - Vector3(0, 0, NpcCharacter.STAND_BACK)] + Mission03Controller.WALK_TO_DOOR + Mission03Controller.WALK_CORRIDOR + Mission03Controller.WALK_STAFF_ROOM
	var worst := 1.0
	for i in points.size() - 1:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, (points[i] as Vector3) + Vector3(0, 0.95, 0))
		query.motion = (points[i + 1] as Vector3) - (points[i] as Vector3)
		worst = minf(worst, space.cast_motion(query)[0])
	_check(worst >= 1.0, "teacher's route clears the map (%.2f)" % worst)
	_check((points[-1] as Vector3).distance_to(StaffRoomLife.seat_of("male") - Vector3(NpcCharacter.STAND_BACK, 0, 0)) < 0.01, "route ends where he sits down at his own desk")
	for d in map.get_node("Doors").get_children():
		d.set_open(false, false)

	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	mission._on_talked(player)
	await create_timer(mission.supervisor.turn_time + 0.5).timeout
	_check(mission.dialogue.is_open() and mission.dialogue.lines.size() == mission.BRIEFING.size(), "briefing dialogue opens")
	var said := " ".join(mission.dialogue.lines)
	_check(not said.contains("192.168"), "the briefing never gives an IP number")
	await _finish_dialogue(mission.dialogue)
	await create_timer(0.3).timeout
	_check(mission.stage == Mission03Controller.Stage.INSPECT and mission._timing and not player.controls_locked, "inspecting, timer running, player free")
	var steps := mission.hud.steps
	_check(steps.size() == 7 and steps[0][1] == ObjectiveHUD.STEP_DONE and steps[1][1] == ObjectiveHUD.STEP_ACTIVE and steps[2][1] == ObjectiveHUD.STEP_TODO, "tracker: briefing done, 'ask the teacher' current, rest grey")
	_check(mission.marker.target == teacher, "arrow on the teacher at his PC")

	# The teacher: greeting, then he gets up and leaves for the teachers' room.
	mission._on_teacher_talked(player)
	await create_timer(0.8).timeout
	_check(mission.dialogue.is_open() and mission.dialogue.lines.size() == mission.TEACHER_FIRST.size(), "teacher greets the player")
	_check(String(mission.dialogue.lines[4]).contains("ฝากเรื่องตรวจสอบระบบด้วยนะครับ ขอบคุณครับ"), "teacher asks to check the system")
	await _finish_dialogue(mission.dialogue)
	_check(not player.controls_locked and mission.teacher_place == "leaving", "player free, the teacher leaves")
	await create_timer(NpcCharacter.STAND_TIME + 0.3).timeout
	_check(not teacher.seated and teacher_pc.collision_layer == ComputerStation.COLLISION_LAYER, "he stood up: TEACHER-PC can be used")
	steps = mission.hud.steps
	_check(steps[1][1] == ObjectiveHUD.STEP_DONE and steps[2][1] == ObjectiveHUD.STEP_ACTIVE, "tracker: teacher PC is current now")
	_check(mission.marker._use_point and mission.marker._point.distance_to(teacher_pc.global_position) < 1.0, "arrow on the teacher's PC")
	var row1: Label = mission.hud.find_child("Step1", true, false).get_node("Text")
	var row3: Label = mission.hud.find_child("Step3", true, false).get_node("Text")
	var row4: Label = mission.hud.find_child("Step4", true, false).get_node("Text")
	_check(row1.get_theme_color("font_color") == ObjectiveHUD.COLOR_DONE and row3.get_theme_color("font_color") == ObjectiveHUD.COLOR_ACTIVE and row4.get_theme_color("font_color") == ObjectiveHUD.COLOR_TODO, "tracker colours: green / blue / grey")

	var desktop := manager.desktop
	# Strict order: the front PC first is refused.
	await _use_pc(manager, front, player)
	_check(not mission.checklist.is_open(), "front PC before the teacher's: no checklist")
	desktop._open_cmd()
	desktop.run_command("ipconfig")
	_check(not mission.state.activity.has("PC-R1-L1"), "commands out of order are not recorded")
	manager.close_computer()
	await create_timer(0.95).timeout
	# Teacher PC: sit, boot, commands.
	await _use_pc(manager, teacher_pc, player)
	_check(mission.checklist.is_open() and mission.checklist.host == "TEACHER-PC", "checklist opens at the teacher's PC")
	_check(mission.hud.right_inset > 300.0 and desktop.reserved_right > 300.0, "objective tab and windows keep clear of the checklist")
	_check(mission.checklist.attach_button.disabled, "attach disabled before the commands")
	desktop._open_cmd()
	var cmd_window: Control = desktop._windows["cmd"]
	_check(cmd_window.position.x + cmd_window.size.x <= 1280 - desktop.reserved_right + 1, "Command Prompt opens left of the checklist (right edge %.0f)" % (cmd_window.position.x + cmd_window.size.x))
	_check(desktop._cmd_input.placeholder_text.find("192.168.1.1") == -1, "Command Prompt hint does not give the gateway")
	desktop.run_command("tracert 192.168.1.1")
	_check(desktop._cmd_output.get_parsed_text().contains(mission.OFF_TASK_MESSAGE) and not mission.state.altered, "tracert: off-task notice, no penalty")
	desktop.run_command("ipconfig /release")
	_check(desktop._cmd_output.get_parsed_text().contains(mission.HARM_MESSAGE) and mission.state.altered, "ipconfig /release blocked and counted")
	_check(teacher_pc.network_connected, "nothing changed on the computer")
	desktop.run_command("ipconfig")
	var out := desktop._cmd_output.get_parsed_text()
	_check(out.contains("192.168.1.5") and out.contains("255.255.255.0") and out.contains("192.168.1.1"), "ipconfig shows the teacher PC's values")
	desktop.run_command("ping 192.168.1.1")
	await create_timer(2.3).timeout
	out = desktop._cmd_output.get_parsed_text()
	_check(out.contains("Reply from 192.168.1.1") and out.contains("Approximate round trip times"), "teacher PC reaches the gateway, Windows-style statistics")
	_check(mission.state.pinged_gateway("TEACHER-PC"), "gateway ping noted")
	mission.checklist.fill("192.168.1.5", "255.255.255.0", "192.168.1.1", Mission03State.REPLY, Mission03State.NORMAL)
	_check(not mission.checklist.attach_button.disabled, "attach enabled when complete")
	mission.checklist.attach()
	_check(mission.state.records.has("TEACHER-PC") and mission.checklist.attach_button.disabled and not mission.checklist.ip_edit.editable, "row attached and locked")
	desktop._open_network()
	var edit: Button = desktop.find_child("EditIpButton", true, false)
	_check(edit != null, "Network Settings has the edit button in Level 3")
	if edit:
		edit.pressed.emit()
		var notice: Label = desktop.find_child("EditIpNotice", true, false)
		_check(notice != null and notice.text == mission.HARM_MESSAGE and mission.state.harm_attempts.size() == 2, "edit IP refused")
	manager.close_computer()
	await create_timer(0.95).timeout
	_check(not mission.checklist.is_open() and mission.marker._point.distance_to(front.global_position) < 1.0, "checklist closes, arrow on the front PC")

	# Front PC.
	await _use_pc(manager, front, player)
	desktop._open_cmd()
	desktop.run_command("ipconfig")
	desktop.run_command("ping 192.168.1.1")
	await create_timer(2.3).timeout
	mission.checklist.fill("192.168.1.11", "255.255.255.0", "192.168.1.1", Mission03State.REPLY, Mission03State.NORMAL)
	mission.checklist.attach()
	manager.close_computer()
	await create_timer(0.95).timeout

	# Back PC: the cable cannot be pulled; ping times out.
	_check(mission.unplug_spot.get_prompt_text() != "", "unplug spot active behind the back PC")
	mission.unplug_spot.use(player)
	_check(back.network_connected and mission.state.harm_attempts.size() == 3 and mission.state.altered, "unplugging refused")
	await _use_pc(manager, back, player)
	desktop._open_cmd()
	desktop.run_command("ipconfig")
	out = desktop._cmd_output.get_parsed_text()
	_check(out.contains("192.168.1.30") and not out.contains("Media disconnected"), "back PC: ipconfig looks normal")
	desktop.run_command("ping 192.168.1.1")
	await create_timer(2.3).timeout
	out = desktop._cmd_output.get_parsed_text()
	_check(out.count("Request timed out.") == 4 and out.contains("Received = 0") and not out.contains("Reply from"), "back PC: every ping times out")
	mission.checklist.fill("192.168.1.30", "255.255.255.0", "192.168.1.1", Mission03State.TIMEOUT, Mission03State.ABNORMAL)
	mission.checklist.attach()
	await _frames(2)
	_check(mission.state.records.size() == 3, "3 rows attached: %s" % [mission.state.records.keys()])
	_check(mission.report.is_open() and not mission.checklist.is_open(), "report opens after the third row")
	mission.report.confirm()
	await create_timer(0.95).timeout
	_check(mission.stage == Mission03Controller.Stage.RETURN and not desktop.visible and mission.marker.target == mission.supervisor, "report confirmed: computer closed, back to the supervisor")

	mission._on_talked(player)
	await create_timer(mission.supervisor.turn_time + 0.5).timeout
	_check(mission.dialogue.is_open() and String(mission.dialogue.lines[0]).contains("ไม่สามารถติดต่อ Default Gateway"), "player reports the back PC")
	await _finish_dialogue(mission.dialogue)
	await _frames(3)
	var score := mission.score
	_check(score != null and score.correctness == 30 and score.process == 45, "score: correctness 30, process 45 after one harm (%s)" % ["-" if score == null else "%d/%d/%d" % [score.correctness, score.process, score.time]])
	_check(mission.stage == Mission03Controller.Stage.DONE and mission.summary.visible, "summary shown")
	_check(GameProgress.best_score(3) == score.total(), "progress recorded")
	# Meanwhile the teacher walked to the teachers' room and sat down.
	Engine.time_scale = 6.0
	var t0 := Time.get_ticks_msec()
	while mission.teacher_place != "staff_room" and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	Engine.time_scale = 1.0
	_check(mission.teacher_place == "staff_room" and teacher.seated and teacher.global_position.distance_to(StaffRoomLife.seat_of("male")) < 0.1, "teacher sits at his desk in the teachers' room (%s, %s)" % [mission.teacher_place, teacher.global_position])
	_check((map.get_node("Doors/ClassroomDoor") as InteractiveDoor).is_open == false and (map.get_node("Doors/StaffDoor") as InteractiveDoor).is_open == false, "he closed both doors behind him")
	_check(mission.teacher_talk.prompt != "", "he can be greeted at his desk")
	map.queue_free()
	await _frames(2)

	# The fault and the guard exist only in Level 3.
	map = load("res://scenes/main.tscn").instantiate()
	flow.configure_level(map, 5)
	root.add_child(map)
	for i in 3:
		await physics_frame
	var other: ComputerManager = map.get_node("Computers")
	_check(not other.find_host("PC-R5-R2").link_fault and not other.desktop.command_guard.is_valid(), "Level 5: no bad crimp, no command guard")
	map.queue_free()
	await _frames(2)
	GameProgress.clear()
	_finish()


func _use_pc(manager: ComputerManager, station: ComputerStation, player: Node) -> void:
	manager.open_computer(station, player)
	await create_timer(0.8).timeout
	await create_timer(2.4).timeout


func _finish() -> void:
	if failures == 0:
		print("MISSION_03_VALID")
		quit()
	else:
		print("MISSION_03_INVALID failures=", failures)
		quit(1)
