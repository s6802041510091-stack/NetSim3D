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


func _run() -> void:
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
	_check(mission.stage == Mission02Controller.Stage.GATHER and mission._timing, "after the briefing: gather, timer running")
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
	map.queue_free()
	await _frames(2)
	_finish()


func _finish() -> void:
	print("MISSION_02_VALID" if failures == 0 else "MISSION_02_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
