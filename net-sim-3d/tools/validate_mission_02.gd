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
	await _test_tester(mission, props, player)


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
	panel.do_step()
	panel.do_step()
	panel.do_step()
	_check(tester.is_on and tester.is_testing and panel.current_step() == "verdict", "plugged, powered, testing")
	panel.judge(false)
	_check(mission.state.tester_verdicts.get(1) == false and mission.state.spare_cables.is_empty() and panel.message.contains("ใช้งานได้"), "good cable discarded: told it works, kept: " + panel.message)
	_check(panel.cable == 2 and not tester.is_on, "next cable, tester off")
	panel.do_step()
	panel.do_step()
	await mission.leave_desk()
	_check(not tester.is_on and not mission.at_desk, "standing up stops the tester")
	await mission.sit_at_desk(player)
	_check(panel.cable == 2 and panel.current_step() == "test" and tester.is_on, "back at the desk: same cable, still powered")
	panel.do_step()
	panel.judge(false)
	_check(mission.state.spare_cables == [2] and panel.message.contains("สำรอง"), "bad cable discarded: spare cable: " + panel.message)
	_check(not mission.state.set_verdict(2, true), "a verdict cannot be changed")
	_check(is_equal_approx(mission.state.tester_points(), 5.0), "tester points 5 (one right)")
	_check(mission.state.installed_cable_works(1) and mission.state.installed_cable_works(2) and not mission.state.cable_good(2), "both installed cables work (cable 2 is the spare)")
	await create_timer(Mission02Controller.TESTING_DONE_PAUSE + Mission02Controller.DESK_ZOOM_TIME + 0.4).timeout
	_check(mission.stage == Mission02Controller.Stage.INSTALL and not mission.at_desk and not player.controls_locked, "testing done -> install stage, player free")
	_check(station.get_prompt_text() == "" and not tester.visible, "desk cleared after testing")
	await _test_install(mission, player)


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
