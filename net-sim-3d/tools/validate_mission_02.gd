extends SceneTree

## Mission 2 checks (grows with each step of the round).
## Run: godot --headless --path net-sim-3d -s res://tools/validate_mission_02.gd

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


func _load_level(level: int) -> Node3D:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, level)
	root.add_child(map)
	for i in 3:
		await physics_frame
	return map


func _finish_dialogue(dialogue: DialogueBox) -> void:
	var guard := 0
	while dialogue.is_open() and guard < 60:
		dialogue.advance(true)
		guard += 1
	await _frames(2)


## Scoring rules of Mission02State (README: A10 B24 D10 E6, job works = 30).
func _test_rules() -> void:
	var s := Mission02State.new()
	var b := WireColors.T568B.duplicate()
	var swapped := b.duplicate()
	swapped[0] = b[1]
	swapped[1] = b[0]
	_check(WireColors.correct_positions(b) == 8 and WireColors.correct_positions(swapped) == 6 and WireColors.correct_positions(WireColors.T568A) == 4, "T568B positions")
	s.set_cable_type(1, Mission02State.STRAIGHT)
	s.set_cable_type(2, Mission02State.STRAIGHT)
	for key in ["1A", "1B", "2A", "2B"]:
		s.ends[key] = b
	s.tester_verdicts = {1: true, 2: true}
	s.router_port = "router_lan1"
	_check(s.job_works() and is_equal_approx(s.process_points(), 50.0), "perfect job: works, process 50")
	s.ends["2B"] = swapped
	_check(not s.cable_good(2) and s.cable_good(1) and not s.job_works(), "one swapped pair breaks cable 2 and the job")
	_check(is_equal_approx(s.colour_points(), 22.5), "colours 22.5 with one pair swapped (%.2f)" % s.colour_points())
	_check(is_equal_approx(s.tester_points(), 5.0), "saying 'pass' to the bad cable loses 5")
	s.tester_verdicts[2] = false
	_check(is_equal_approx(s.tester_points(), 10.0) and is_equal_approx(s.process_points(), 48.5), "discarding the bad cable keeps D: process 48.5")
	s.ends["2B"] = b
	s.router_port = "router_wan"
	_check(not s.job_works() and is_equal_approx(s.port_points(), 0.0), "WAN port: job does not work, E = 0")


func _run() -> void:
	GameProgress.save_path = "user://test_validate_progress_m2.json"
	GameProgress.clear()
	_test_rules()
	var flow := root.get_node("GameFlow")
	_check(2 in flow.AVAILABLE, "Level 2 is selectable")

	# Equipment follows the story level by level.
	var map := await _load_level(1)
	var rack: WallRack9U = map.get_node("ComputerRoomRack")
	_check(rack.stage == WallRack9U.Stage.EMPTY and rack.port_ids().is_empty(), "Level 1: empty rack")
	_check(not (map.get_node("ComputerRoomAccessPoint") as CeilingAccessPoint).visible, "Level 1: no access point yet")
	_check(map.get_node_or_null("Mission02Props") == null and map.get_node_or_null("Mission02") == null, "Level 1: no Mission 2 props")
	map.queue_free()
	await _frames(2)

	map = await _load_level(3)
	rack = map.get_node("ComputerRoomRack")
	var pc_port: NetworkPort = map.get_node("TeacherPcPort")
	_check(rack.stage == WallRack9U.Stage.CABLED and rack.is_link_on("router_lan1") and rack.is_link_on("switch_01") and rack.is_link_on("switch_02"), "Level 3: rack cabled, links up")
	_check(pc_port.plugged and pc_port.link_on, "Level 3: teacher PC cabled")
	_check(map.get_node_or_null("Mission02Props") == null, "Level 3: no Mission 2 props")
	map.queue_free()
	await _frames(2)

	# Level 2.
	map = await _load_level(2)
	rack = map.get_node("ComputerRoomRack")
	pc_port = map.get_node("TeacherPcPort")
	_check(rack.stage == WallRack9U.Stage.INSTALLED and rack.port_ids().size() == 29, "Level 2: Router (WAN + 4 LAN) and 24-port switch installed")
	_check(rack.is_plugged("router_wan") and rack.is_link_on("router_wan"), "Level 2: Internet line in WAN, link up")
	for id in ["router_lan1", "switch_01", "switch_24"]:
		_check(not rack.is_plugged(id) and not rack.is_link_on(id), "Level 2: %s free and dark" % id)
	_check(not pc_port.plugged and not pc_port.link_on, "Level 2: teacher PC not cabled")
	_check((map.get_node("ComputerRoomAccessPoint") as CeilingAccessPoint).visible, "Level 2: access point on the ceiling")
	_check(rack.plug("switch_05") and rack.is_plugged("switch_05") and not rack.plug("switch_05"), "rack plug() once per port")
	rack.unplug("switch_05")
	rack.set_link("switch_05", true)
	_check(rack.is_link_on("switch_05"), "rack set_link()")
	rack.set_link("switch_05", false)

	var mission: Mission02Controller = map.get_node_or_null("Mission02")
	var props: Mission02Props = map.get_node_or_null("Mission02Props")
	_check(mission != null and props != null and props.cable_boxes.size() == 2 and props.drawer_spot != null, "Level 2: controller, 2 cable boxes and the drawer")
	if mission == null or props == null:
		_finish()
		return
	_check(mission.stage == Mission02Controller.Stage.BRIEFING and mission.marker.target == mission.supervisor, "starts at the briefing, arrow on the supervisor")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var straight_box: Mission02CableBox = props.cable_boxes[Mission02State.STRAIGHT]
	var crossover_box: Mission02CableBox = props.cable_boxes[Mission02State.CROSSOVER]
	_check(straight_box.get_prompt_text() == "" and props.drawer_spot.get_prompt_text() == "", "boxes and drawer wait for the briefing")
	var decor := map.get_node("MapVisual").find_child(Mission02Props.ISLAND_DECOR, true, false) as Node3D
	_check(decor != null and not decor.visible, "decorative tools on the storage island hidden in Level 2")

	mission._on_talked(player)
	await create_timer(mission.supervisor.turn_time + 0.5).timeout
	_check(mission.dialogue.is_open(), "briefing dialogue opens")
	_check(mission.dialogue.lines.size() == mission.BRIEFING.size(), "briefing lines")
	await _finish_dialogue(mission.dialogue)
	await create_timer(0.3).timeout
	_check(mission.stage == Mission02Controller.Stage.GATHER and mission._timing and not player.controls_locked, "after the briefing: gather in the storage room, timer running, player free")
	_check(straight_box.get_prompt_text().contains("Straight-Through") and crossover_box.get_prompt_text().contains("Crossover"), "box prompts: " + straight_box.get_prompt_text())
	_check(props.drawer_spot.get_prompt_text() != "" and props.crimp_station.get_prompt_text() != "", "drawer and desk prompts on")
	_check(mission.hud.objective_text.contains("(0/2)") and not mission.hud.objective_text.contains("คีม"), "objective counts cables, never lists tools: " + mission.hud.objective_text)
	_check(mission.marker._use_point and mission.marker._point.distance_to(straight_box.global_position) < 1.0, "arrow on the cable boxes")

	# The desk refuses while something is missing and says what.
	await mission.sit_at_desk(player)
	_check(not mission.at_desk and mission.stage == Mission02Controller.Stage.GATHER, "desk refuses with nothing in hand")
	_check(mission.missing_for_desk().size() == 6, "missing: 2 cables + 4 tools: %s" % [mission.missing_for_desk()])

	# Cable boxes: one cable per point, from whichever box; final.
	mission.open_cable_box(player, Mission02State.STRAIGHT)
	_check(mission.box_panel.is_open() and player.controls_locked, "straight box opens its window, player held")
	_check(mission.box_panel.take(1) and not mission.box_panel.take(1), "point 1 takes a cable once")
	var take2: Button = mission.box_panel.find_child("Take2", true, false)
	var take1: Button = mission.box_panel.find_child("Take1", true, false)
	_check(take1.disabled and not take2.disabled and take1.text.contains("Straight-Through"), "point 1 marked taken: " + take1.text)
	mission.box_panel.close()
	await _frames(1)
	_check(not player.controls_locked, "closing the box frees the player")
	mission.open_cable_box(player, Mission02State.CROSSOVER)
	take2.pressed.emit()
	mission.box_panel.close()
	await _frames(1)
	_check(mission.state.cable_types == {1: Mission02State.STRAIGHT, 2: Mission02State.CROSSOVER}, "cable types from the boxes: %s" % [mission.state.cable_types])
	_check(mission.state.cable_type_points() == 5.0, "cable type points = 5 (one right)")
	_check(not mission.state.set_cable_type(2, Mission02State.STRAIGHT) and mission.state.cable_types[2] == Mission02State.CROSSOVER, "an answer cannot be changed")
	_check(mission.hud.objective_text.contains("(2/2)") and mission.marker._point.distance_to(props.drawer_spot.global_position) < 1.0, "both cables -> arrow on the drawer")

	# The drawer: take the kit except the tester, plus a screwdriver.
	mission.open_drawer(player)
	_check(mission.drawer.is_open() and player.controls_locked, "drawer window opens")
	for id in ["rj45_heads", "screwdriver", "cable_stripper", "crimping_tool"]:
		_check(mission.drawer.take(id), "took " + id)
	_check(not mission.drawer.take("screwdriver"), "an item is taken once")
	mission.drawer.close()
	await _frames(1)
	_check(mission.marker._point.distance_to(props.crimp_station.global_position) < 1.0, "drawer seen -> arrow on the desk")
	await mission.sit_at_desk(player)
	_check(not mission.at_desk and mission.missing_for_desk() == PackedStringArray(["เครื่องทดสอบสาย LAN"]), "desk names the missing tester: %s" % [mission.missing_for_desk()])
	mission.open_drawer(player)
	(mission.drawer.find_child("Take_cable_tester", true, false) as Button).pressed.emit()
	mission.drawer.close()
	await _frames(1)

	var presentation: Node = player.get_node("Presentation")
	var owned := []
	for slot: Dictionary in presentation.items:
		if not slot.is_empty():
			owned.append(slot.id)
	_check(owned.size() == 7 and "lan_cable_1" in owned and "lan_cable_2" in owned and "cable_tester" in owned and "screwdriver" in owned, "tool case: %s" % [owned])
	await _test_crimping(mission, props, player)
	map.queue_free()
	await _frames(2)
	_finish()


## The crimping desk: 4 ends, cable 2 end 2 gets one pair swapped.
func _test_crimping(mission: Mission02Controller, props: Mission02Props, player: CharacterBody3D) -> void:
	var station := props.crimp_station
	var panel := mission.crimp_panel
	var bench := station.bench
	_check(station.get_prompt_text() != "" and station.collision_layer == CrimpStation.COLLISION_LAYER, "desk prompt on")
	_check(station.layout.mat != null and not station.layout.cables_shown() and not bench.visible, "desk: only the work mat before the crimp stage")
	await mission.sit_at_desk(player)
	_check(mission.stage == Mission02Controller.Stage.CRIMP and mission.hud.objective_text.contains("0/4"), "everything in hand: the desk opens the crimp stage: " + mission.hud.objective_text)
	_check(station.layout.cables_shown() and station.layout.tool_ids().size() == 4 and bench.visible, "cables and kit laid out, the cable end shown while seated")
	var tag_text := ""
	for l in station.layout.find_child("Cable2", true, false).find_children("*", "Label3D", true, false):
		tag_text += (l as Label3D).text + " "
	_check(tag_text.contains("สายจุดที่ 2") and tag_text.contains("Crossover"), "cable 2 tag shows the box it came from: " + tag_text)
	_check(mission.at_desk and panel.visible and player.controls_locked, "sitting at the desk opens the step panel")
	_check(player.camera.global_position.distance_to(bench.view_transform().origin) < 0.01, "camera moved to the cable end")
	_check(panel.current_key() == "1A" and panel.current_step() == "cut" and bench.look == CrimpBench.Look.WHOLE, "starts with cable 1 end 1: cut")
	var swapped := WireColors.T568B.duplicate()
	swapped[2] = WireColors.T568B[5] # white-green <-> green, a classic split-pair mistake
	swapped[5] = WireColors.T568B[2]
	var plans := {"1A": WireColors.T568B, "1B": WireColors.T568B, "2A": WireColors.T568B, "2B": swapped}
	var looks_seen := {}
	var left_once := false
	var guard := 0
	while not panel.is_done() and guard < 60:
		guard += 1
		var key := panel.current_key()
		var step := panel.current_step()
		if step == "arrange":
			await create_timer(CrimpPanel.ARRANGE_VIEW_TIME + 0.15).timeout
			_check(bench.look == CrimpBench.Look.ARRANGING and bench.wire_ids().size() == 8 and panel.find_child("Chip_orange", true, false) == null, "%s: 8 loose wires on the rail, no colour chips" % key)
			_check(player.camera.global_basis.z.dot(Vector3.UP) > 0.99, "%s: the camera looks straight down while arranging" % key)
			_check(WireColors.correct_positions(panel._chip_order()) <= 3, "%s: the loose wires do not come nearly in order" % key)
			# Click a wire on the model, click it again to take it back, then the plan.
			var cam: Camera3D = player.camera
			_click_wire(panel, cam, plans[key][1])
			_check(panel.arrangement[0] == plans[key][1], "%s: clicking a 3D wire puts it on pin 1" % key)
			_click_wire(panel, cam, plans[key][1])
			_check(panel.arrangement[0] == "", "%s: clicking the placed wire takes it back" % key)
			var misses := 0
			for id: String in plans[key]:
				if not _click_wire(panel, cam, id):
					misses += 1
			_check(misses == 0 and panel.arrangement == plans[key], "%s: all 8 placed by clicking the model (%d mis-picks)" % [key, misses])
			if key == "1A":
				# Drag the pin-1 wire onto slot 2: they swap; drag it back.
				var w1: String = plans[key][0]
				var w2: String = plans[key][1]
				_drag_wire(panel, cam, w1, 1)
				_check(panel.arrangement[0] == w2 and panel.arrangement[1] == w1, "1A: dropping on a full slot swaps the two wires")
				_drag_wire(panel, cam, w1, 0)
				_check(panel.arrangement == plans[key], "1A: dragging it back restores the order")
				panel.remove_pin(7)
				_drag_wire(panel, cam, plans[key][7], 7)
				_check(panel.arrangement == plans[key] and bench._drag == null, "1A: a wire dragged from the rail lands in the chosen slot")
			panel.confirm_arrangement()
			_check(mission.state.ends.get(key, []) == plans[key], "%s: arrangement saved" % key)
			panel.place_wire("brown")
			continue
		await _crimp_step(panel)
		looks_seen[bench.look] = true
		if key == "1B" and panel.current_key() == "2A" and not left_once:
			# Stand up after the first cable and come back.
			left_once = true
			await mission.leave_desk()
			_check(not bench.visible and station.layout.cables_shown(), "standing up hides the close-up end, the cables stay on the desk")
			_check(not mission.at_desk and not player.controls_locked and not panel.visible, "standing up frees the player")
			await mission.sit_at_desk(player)
			_check(panel.current_key() == "2A" and panel.current_step() == "cut", "sitting again resumes at cable 2")
	for look in [CrimpBench.Look.CUT, CrimpBench.Look.STRIPPED, CrimpBench.Look.TRIMMED, CrimpBench.Look.INSERTED]:
		_check(looks_seen.has(look), "cable end showed look %d" % look)
	await create_timer(Mission02Controller.DESK_ZOOM_TIME + 0.3).timeout
	_check(panel.is_done() and mission.state.ends.size() == 4, "all 4 ends crimped")
	_check(mission.state.cable_good(1) and not mission.state.cable_good(2), "cable 1 good, cable 2 has the swapped pair")
	_check(is_equal_approx(mission.state.colour_points(), 22.5), "colour points 22.5 (%.2f)" % mission.state.colour_points())
	_check(mission.stage == Mission02Controller.Stage.TEST and not mission.at_desk and not player.controls_locked, "crimping done -> test stage, player free")
	await _test_tester(mission, props, player)


## A left click on wire `id` where it shows on screen; true if the click
## picked that wire (and not a neighbour).
func _click_wire(panel: CrimpPanel, camera: Camera3D, id: String) -> bool:
	var at := panel.bench.wire_screen_point(camera, id)
	var picked := panel.bench.pick_wire(camera, at)
	_mouse(panel, at, true)
	_mouse(panel, at, false)
	return picked == id


## Press on wire `id`, move to comb slot `pin`, release there.
func _drag_wire(panel: CrimpPanel, camera: Camera3D, id: String, pin: int) -> void:
	var from := panel.bench.wire_screen_point(camera, id)
	var to := panel.bench.slot_screen_point(camera, pin)
	_mouse(panel, from, true)
	for t in [0.3, 0.7, 1.0]:
		var move := InputEventMouseMotion.new()
		move.position = from.lerp(to, t)
		panel._unhandled_input(move)
	_mouse(panel, to, false)


func _mouse(panel: Node, at: Vector2, down: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = down
	button.position = at
	panel._unhandled_input(button)


## One step at the desk, playing the minigames like a player: the first
## strip misses once (too short), every crimp is squeezed until the gauge is full.
var _strip_missed := false
func _crimp_step(panel: CrimpPanel) -> void:
	var step := panel.current_step()
	if step == "strip":
		var bench := panel.bench
		await _frames(2)
		_check(bench._guide != null and bench._guide.visible, "strip: the blade ring shows on the cable")
		if not _strip_missed:
			_strip_missed = true
			_check(not panel.strip_at(1.0) and panel.strip_misses == 1 and panel.current_step() == "strip", "strip at 1 cm: too short, a miss, the step stays")
			_check(not panel.strip_at(2.5), "no second try during the miss pause")
			await create_timer(CrimpPanel.STRIP_MISS_PAUSE + 0.05).timeout
		_check(panel.strip_at(2.5), "strip at 2.5 cm: in the green zone")
	elif step == "crimp":
		panel.squeeze()
		panel.squeeze()
		_check(panel.crimp_force > 15.0 and panel.current_step() == "crimp", "crimp: two squeezes fill the gauge part way")
		await create_timer(0.3).timeout
		_check(panel.crimp_force < 22.0, "the gauge eases off when squeezing stops (%.1f)" % panel.crimp_force)
		var guard := 0
		while panel.current_step() == "crimp" and not panel.busy and guard < 30:
			panel.squeeze()
			guard += 1
		_check(panel.busy or panel.current_step() != "crimp", "crimp: a full gauge crimps the head (%d squeezes)" % (guard + 2))
	else:
		await panel.do_step()
	var wait := 0
	while panel.busy and wait < 200:
		await process_frame
		wait += 1


## The tester: cable 1 is good but the player discards it; cable 2 has the
## swapped green pair and the player discards it (right) -> a spare cable.
func _test_tester(mission: Mission02Controller, props: Mission02Props, player: CharacterBody3D) -> void:
	var station := props.crimp_station
	var panel := mission.tester_panel
	_check(station.get_prompt_text().contains("Tester"), "desk prompt for testing: " + station.get_prompt_text())
	_check(mission.hud.objective_text.contains("0/2"), "objective counts tested cables: " + mission.hud.objective_text)
	await mission.sit_at_desk(player)
	var tester := station.tester
	_check(tester != null and tester.visible and not station.bench.visible and panel.visible, "the tester is on the desk, the cable end put away")
	_check(player.camera.global_position.distance_to(station.tester_view_transform().origin) < 0.01, "camera on the tester")
	_check(tester.get_plug_point("Main") != null and tester.get_plug_point("Remote") != null and tester._main_leds.size() == 9 and not tester._main_leds.has(null), "tester model has its LEDs and sockets")
	_check(mission.state.tester_mapping(1) == CableTester.STRAIGHT, "cable 1 shows straight 1-1 ... 8-8")
	_check(mission.state.tester_mapping(2) == [1, 2, 6, 4, 5, 3, 7, 8, 9], "cable 2 shows 3<->6 crossed: %s" % [mission.state.tester_mapping(2)])
	_check(panel.current_step() == "plug", "testing starts by plugging the cable in")
	panel.judge(true)
	_check(not mission.state.tester_verdicts.has(1), "no verdict before testing")
	await _test_plugging(station, player)
	_check(panel.current_step() == "power" and not station.plug_board.active, "both heads in: on to the power step")
	_check(player.camera.global_transform.origin.distance_to(station.tester_views()[0]["xform"].origin) < 0.01, "the camera is back on the whole tester")
	_check(panel.find_child("StepButton", true, false) == null, "no POWER / TEST buttons in the panel")
	var cam: Camera3D = player.camera
	var power_at := cam.unproject_position(tester.button("power").global_position)
	var test_at := cam.unproject_position(tester.button("test").global_position)
	_check(panel.button_at(power_at) == "power" and panel.button_at(test_at) == "test" and panel.button_at(power_at + Vector2(0, 120)) == "", "the tester's own buttons can be pointed at")
	var hover := InputEventMouseMotion.new()
	hover.position = power_at
	panel._unhandled_input(hover)
	_check(tester.button("power").material_overlay != null and tester.button("test").material_overlay == null, "the button under the mouse lights up")
	_mouse(panel, test_at, true)
	_check(panel.current_step() == "power" and not tester.is_testing and panel.message.contains("ยังไม่ได้เปิด"), "TEST with the power off: nothing lights, the panel says why")
	_mouse(panel, power_at, true)
	_check(tester.is_on and panel.current_step() == "test", "clicking POWER on the tester turns it on")
	_mouse(panel, test_at, true)
	_check(tester.is_on and tester.is_testing and panel.current_step() == "verdict", "plugged, powered, testing")
	var box := panel.verdict_box
	_check(not box.visible and panel.find_child("PassButton", true, false) == null, "no verdict buttons in the panel, no question before the LEDs are watched")
	await create_timer(TesterPanel.WATCH_BEFORE_ASK + 0.2).timeout
	var c0: Button = box.find_child("Choice0", true, false)
	var c1: Button = box.find_child("Choice1", true, false)
	_check(box.visible and box.choosing and c0 != null and c1 != null and c0.text.begins_with("ผ่าน") and c1.text.begins_with("ไม่ผ่าน"), "after one scan: the question at the bottom, pass on the left, discard on the right")
	_check(box._panel.get_global_rect().end.x <= 1280 - TesterPanel.PANEL_WIDTH, "the question stays clear of the step panel")
	box.advance()
	_check(box.visible and box.choosing, "F / click does not skip the question")
	c1.pressed.emit()
	_check(mission.state.tester_verdicts.get(1) == false and mission.state.spare_cables.is_empty() and panel.message.contains("ใช้งานได้"), "good cable discarded: told it works, kept: " + panel.message)
	_check(panel.cable == 2 and not tester.is_on, "next cable, tester off")
	_check(station.plug_board.active and station.test_heads().size() == 2 and not station.plug_board.is_plugged("A"), "cable 2: its heads lie on the mat, plugging again")
	station.plug_board.plug_into("A", "REMOTE")
	station.plug_board.plug_into("B", "MAIN")
	await create_timer(PlugBoard.SLIDE_TIME + PlugBoard.PLUGGED_HOLD + 0.4).timeout
	_check(panel.current_step() == "power", "either head fits either socket")
	_mouse(panel, power_at, true)
	await mission.leave_desk()
	_check(not tester.is_on and not mission.at_desk, "standing up stops the tester")
	await mission.sit_at_desk(player)
	_check(panel.cable == 2 and panel.current_step() == "test" and tester.is_on, "back at the desk: same cable, still powered")
	_mouse(panel, test_at, true)
	_check(tester.is_testing and panel.current_step() == "verdict", "clicking TEST on the tester starts the scan")
	await create_timer(TesterPanel.WATCH_BEFORE_ASK + 0.2).timeout
	box.advance() # show the whole line
	var two := InputEventKey.new()
	two.keycode = KEY_2
	two.pressed = true
	box._unhandled_input(two)
	_check(not box.visible, "key 2 answers the second choice")
	_check(mission.state.spare_cables == [2] and panel.message.contains("สำรอง"), "bad cable discarded: spare cable: " + panel.message)
	_check(not mission.state.set_verdict(2, true), "a verdict cannot be changed")
	_check(is_equal_approx(mission.state.tester_points(), 5.0), "tester points 5 (one right)")
	_check(mission.state.installed_cable_works(1) and mission.state.installed_cable_works(2) and not mission.state.cable_good(2), "both installed cables work (cable 2 is the spare)")
	await create_timer(Mission02Controller.TESTING_DONE_PAUSE + Mission02Controller.DESK_ZOOM_TIME + 0.4).timeout
	_check(mission.stage == Mission02Controller.Stage.INSTALL and not mission.at_desk and not player.controls_locked, "testing done -> install stage, player free")
	_check(not props.crimp_station.layout.cables_shown(), "the cables leave the desk for the install")
	_check(station.get_prompt_text() == "" and not tester.visible, "desk cleared after testing")
	await _test_install(mission, player)


## Plugging cable 1 by hand: Q / E views, a drop on the bare mat (the head
## goes back), then each head dragged into its socket from that socket's
## close-up view.
func _test_plugging(station: CrimpStation, player: CharacterBody3D) -> void:
	var board := station.plug_board
	var cam: Camera3D = player.camera
	_check(board.active and board.views.size() == 3 and board._bar.visible and station.test_heads().size() == 2, "plug view: 3 views, the view bar, 2 heads on the mat")
	_check(board._bar_label.text.contains("Q") and board._bar_label.text.contains("ภาพรวม"), "view bar: " + board._bar_label.text)
	_key(board, KEY_E)
	await create_timer(PlugBoard.VIEW_TIME + 0.1).timeout
	_check(board.view_index == 1 and cam.global_position.distance_to(board.views[1]["xform"].origin) < 0.01 and board._bar_label.text.contains("MAIN"), "E: the MAIN socket close up")
	_key(board, KEY_Q)
	_key(board, KEY_Q)
	await create_timer(PlugBoard.VIEW_TIME + 0.1).timeout
	_check(board.view_index == 2 and board._bar_label.text.contains("REMOTE"), "Q twice: round to the REMOTE socket")
	_key(board, KEY_E)
	await create_timer(PlugBoard.VIEW_TIME + 0.1).timeout
	# A head dropped on the bare mat goes back where it lay.
	var home := (station.test_heads()["A"] as Node3D).global_position
	var from := board.plug_screen_point("A")
	_drag(board, from, from + Vector2(-150, 60))
	await create_timer(0.35).timeout
	_check(not board.is_plugged("A") and (station.test_heads()["A"] as Node3D).global_position.distance_to(home) < 0.002, "dropped off a socket: the head goes back")
	# MAIN close up: drag head A in.
	_key(board, KEY_E)
	await create_timer(PlugBoard.VIEW_TIME + 0.1).timeout
	_drag(board, board.plug_screen_point("A"), board.socket_screen_point("MAIN"))
	_check(board.connected.get("MAIN", "") == "A", "head A dragged into MAIN (seen close up)")
	await create_timer(PlugBoard.SLIDE_TIME + 0.2).timeout
	var socket: Node3D = station.tester_sockets()["MAIN"]
	_check((station.test_heads()["A"] as Node3D).global_position.distance_to(socket.global_position) < 0.001, "the head slid all the way into the socket")
	_key(board, KEY_E)
	await create_timer(PlugBoard.VIEW_TIME + 0.1).timeout
	_drag(board, board.plug_screen_point("B"), board.socket_screen_point("REMOTE"))
	_check(board.connected.get("REMOTE", "") == "B", "head B dragged into REMOTE")
	await create_timer(PlugBoard.SLIDE_TIME + 0.3).timeout
	_check(board.active, "plugging stays on screen for a moment after the last head")
	await create_timer(PlugBoard.PLUGGED_HOLD + PlugBoard.VIEW_TIME).timeout


func _key(target: Node, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	target._unhandled_input(key)


func _drag(target: Node, from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	target._unhandled_input(press)
	for t in [0.25, 0.5, 0.75, 1.0]:
		var move := InputEventMouseMotion.new()
		move.position = from.lerp(to, t)
		target._unhandled_input(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	target._unhandled_input(release)


## Installing: LAN 1, both switch ports, the teacher PC, then the LEDs.
## Cable 1 is the player's good cable, cable 2 the spare (both work).
func _test_install(mission: Mission02Controller, player: CharacterBody3D) -> void:
	var rack := mission.rack
	var pc := mission.pc_port
	var panel := mission.install_panel
	_check(mission.install_step == "rack" and mission.rack_spot.get_prompt_text() != "" and mission.marker.is_active(), "install: go to the rack")
	await mission.open_rack(player)
	_check(mission.at_desk and panel.visible and panel.current_step() == "router", "the rack opens on the Router step")
	_check(not rack.find_child("DoorGlass", true, false).visible, "rack door open")
	panel.do_step()
	_check(panel.current_step() == "router", "the Router port must be chosen, not skipped")
	panel.choose_router_port("router_lan1")
	_check(mission.state.router_port == "router_lan1" and rack.is_plugged("router_lan1") and rack.is_internet_connected(), "cable 1 in LAN 1, Internet still in WAN")
	panel.do_step()
	_check(rack.is_plugged("switch_01") and rack.is_link_on("switch_01") and rack.is_link_on("router_lan1"), "switch port 1 plugged, links up (good cable)")
	panel.do_step()
	_check(rack.is_plugged("switch_02") and not rack.is_link_on("switch_02"), "switch port 2 plugged, dark until the PC end is in")
	panel.do_step()
	await create_timer(0.8 + Mission02Controller.DESK_ZOOM_TIME + 0.3).timeout
	_check(mission.install_step == "pc" and not mission.at_desk and mission.pc_spot.get_prompt_text() != "", "rack done -> go to the teacher PC")
	_check(not pc.plugged, "PC not plugged yet")
	await mission.plug_pc(player)
	_check(pc.plugged and pc.link_on and rack.is_link_on("switch_02"), "PC plugged, links up (spare cable)")
	_check(mission.install_step == "leds" and not player.controls_locked, "then check the LEDs at the rack")
	await mission.open_rack(player)
	_check(panel.mode == "leds" and panel.visible, "rack opens for the LED check")
	panel.confirm_leds()
	await create_timer(Mission02Controller.DESK_ZOOM_TIME + 0.3).timeout
	_check(mission.stage == Mission02Controller.Stage.REPORT and not mission.at_desk and rack.find_child("DoorGlass", true, false).visible, "LEDs checked -> report, door closed")
	_check(not mission.state.job_works() and mission.state.port_points() == 6.0, "job does not work (cable 2 was the player's bad one), Router port right")
	# Choosing WAN would pull out the Internet line.
	var other := WallRack9U.new()
	other.stage = WallRack9U.Stage.INSTALLED
	root.add_child(other)
	await process_frame
	other.disconnect_internet()
	other.plug("router_wan")
	_check(not other.is_internet_connected() and other.is_plugged("router_wan"), "WAN chosen: Internet line out, the player's cable in WAN")
	other.queue_free()
	await _test_report(mission, player)


## Reporting: the summary with the agreed score.
## A: 1 of 2 straight (5) + B 22.5 + D 1 of 2 (5) + E LAN (6) = 38.5 -> 39 (rounded);
## correctness 0 (cable 2 was the player's bad one); time full in a test run.
func _test_report(mission: Mission02Controller, player: CharacterBody3D) -> void:
	_check(mission.talk.prompt.contains("รายงาน") and mission.marker.target == mission.supervisor, "report prompt and arrow on the supervisor")
	var lines := mission.report_lines()
	_check(lines[0].contains("บางจุดไม่ติด") == false and "\n".join(lines).contains("สายสำรอง"), "report mentions the spare cable: %s" % ["\n".join(lines)])
	mission._on_talked(player)
	await create_timer(mission.supervisor.turn_time + 0.5).timeout
	await _finish_dialogue(mission.dialogue)
	await _frames(3)
	var score := mission.score
	_check(score != null and mission.summary.visible and mission.stage == Mission02Controller.Stage.DONE, "summary shown after reporting")
	if score == null:
		return
	_check(score.correctness == 0 and score.process == 39 and score.time == 20 and score.total() == 59, "score %s" % score.to_dict())
	_check(score.passed() and score.stars() == 1, "59 passes with 1 star")
	_check(score.decisions_correct == 6 and score.decisions_total == 9, "decisions %d/%d" % [score.decisions_correct, score.decisions_total])
	var mistakes := "\n".join(score.mistakes)
	for want in ["Crossover", "ปลายที่ 2: เรียงสีไม่ตรง T568B ที่ขา 3, 6", "อ่านผล Tester ผิด", "สายสำรอง", "ยังใช้งานไม่ได้จริง"]:
		_check(mistakes.contains(want), "mistakes list has: " + want)
	var last: Dictionary = GameProgress.level_record(2).get("last", {})
	_check(GameProgress.best_score(2) == 59 and last.get("job_works", true) == false and last.get("router_port", "") == "router_lan1", "progress recorded for Level 2: %s" % [GameProgress.level_record(2)])
	_check("screwdriver" in Array(last.get("drawer_items", [])) and Array(last.get("drawer_items", [])).size() == 5 and int(last.get("strip_misses", -1)) == 1, "drawer items and strip misses kept for the report: %s, %s" % [last.get("drawer_items"), last.get("strip_misses")])
	var details := ""
	for l in mission.summary._details.find_children("*", "Label", true, false):
		details += (l as Label).text + "\n"
	for want in ["ผลงานใช้งานได้จริง", "ถูก 30 จาก 32 ตำแหน่ง", "อ่านผล LAN Cable Tester", "LAN 1", "ใช้สายสำรอง"]:
		_check(details.contains(want), "details page has: " + want)
	_check((mission.summary._main.find_child("LevelName", true, false) as Label).text.begins_with("ด่านที่ 2"), "level name on the summary")


func _finish() -> void:
	GameProgress.clear()
	print("MISSION_02_VALID" if failures == 0 else "MISSION_02_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
