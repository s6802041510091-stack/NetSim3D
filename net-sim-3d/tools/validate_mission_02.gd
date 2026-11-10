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
	_check(mission != null and props != null and props.items.size() == 5, "Level 2: controller and 5 items")
	if mission == null or props == null:
		_finish()
		return
	_check(mission.stage == Mission02Controller.Stage.BRIEFING and mission.marker.target == mission.supervisor, "starts at the briefing, arrow on the supervisor")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var first: PickupItem = props.items["utp_cat6"]
	_check(first.get_prompt_text() == "", "items cannot be picked before the briefing")

	mission._on_talked(player)
	await create_timer(mission.supervisor.turn_time + 0.5).timeout
	_check(mission.dialogue.is_open(), "briefing dialogue opens")
	_check(mission.dialogue.lines.size() == mission.BRIEFING.size(), "briefing lines")
	await _finish_dialogue(mission.dialogue)
	await create_timer(0.3).timeout
	# The work order: cable type for both points, once.
	var order := mission.work_order
	_check(mission.stage == Mission02Controller.Stage.CABLE_TYPE and order.is_open() and mission._timing, "after the briefing: work order open, timer running")
	_check(player.controls_locked and first.get_prompt_text() == "", "player stays put and items wait while the work order is open")
	var confirm: Button = order.find_child("ConfirmButton", true, false)
	order.choose(1, Mission02State.STRAIGHT)
	_check(confirm.disabled, "confirm waits for both points")
	order.choose(2, Mission02State.CROSSOVER)
	_check(not confirm.disabled, "confirm enabled with both answers")
	confirm.pressed.emit()
	await _frames(2)
	_check(not order.is_open() and mission.state.cable_types == {1: Mission02State.STRAIGHT, 2: Mission02State.CROSSOVER}, "answers saved: %s" % [mission.state.cable_types])
	_check(mission.state.cable_type_points() == 5.0, "cable type points = 5 (one right)")
	_check(not mission.state.set_cable_type(2, Mission02State.STRAIGHT) and mission.state.cable_types[2] == Mission02State.CROSSOVER, "an answer cannot be changed")
	_check(not player.controls_locked, "player free after the work order")
	_check(mission.stage == Mission02Controller.Stage.GATHER, "work order -> gather the tools")
	_check(mission.hud.objective_text.contains("0/5"), "objective counts items: " + mission.hud.objective_text)
	_check(first.get_prompt_text().contains("สาย UTP Cat6"), "item prompt: " + first.get_prompt_text())

	var presentation: Node = player.get_node("Presentation")
	var picked := 0
	for id: String in Mission02Props.ITEMS:
		var item: PickupItem = props.items[id]
		item.use(player)
		picked += 1
		_check(item.taken and not item.visible, "picked " + id)
		if picked < 5:
			_check(mission.hud.objective_text.contains("%d/5" % picked), "objective after %d items: %s" % [picked, mission.hud.objective_text])
	var owned := []
	for slot: Dictionary in presentation.items:
		if not slot.is_empty():
			owned.append(slot.id)
	_check(owned.size() == 5 and "crimping_tool" in owned and "cable_tester" in owned and "rj45_heads" in owned, "all 5 in the tool case: %s" % [owned])
	_check(mission.stage == Mission02Controller.Stage.CRIMP, "all items -> next stage")
	await _test_crimping(mission, props, player)
	map.queue_free()
	await _frames(2)
	_finish()


## The crimping desk: 4 ends, cable 2 end 2 gets one pair swapped.
func _test_crimping(mission: Mission02Controller, props: Mission02Props, player: CharacterBody3D) -> void:
	var station := props.crimp_station
	var panel := mission.crimp_panel
	var bench := station.bench
	_check(station.get_prompt_text() != "" and station.collision_layer == CrimpStation.COLLISION_LAYER, "desk prompt on in the crimp stage")
	_check(mission.hud.objective_text.contains("0/4"), "objective counts ends: " + mission.hud.objective_text)
	await mission.sit_at_desk(player)
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
			_check(bench.look == CrimpBench.Look.UNTWISTED, "%s: loose wires before arranging" % key)
			# Place two wires, take one back, then fill in the plan.
			panel.place_wire(plans[key][1])
			_check(panel.arrangement[0] == plans[key][1] and bench.look == CrimpBench.Look.ARRANGED, "%s: a wire goes to pin 1 and shows on the desk" % key)
			panel.remove_pin(0)
			for id: String in plans[key]:
				panel.place_wire(id)
			panel.confirm_arrangement()
			_check(mission.state.ends.get(key, []) == plans[key], "%s: arrangement saved" % key)
			panel.place_wire("brown")
			continue
		await panel.do_step()
		looks_seen[bench.look] = true
		if key == "1B" and panel.current_key() == "2A" and not left_once:
			# Stand up after the first cable and come back.
			left_once = true
			await mission.leave_desk()
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
	_check(station.get_prompt_text() == "", "desk prompt off after crimping")


func _finish() -> void:
	print("MISSION_02_VALID" if failures == 0 else "MISSION_02_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
