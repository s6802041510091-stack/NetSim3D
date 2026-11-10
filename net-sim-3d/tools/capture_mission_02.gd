extends SceneTree

## Screenshots of the Mission 2 props (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_mission_02.gd -- <out_dir>

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 2)
	root.add_child(map)
	for i in 10:
		await process_frame
	var camera := Camera3D.new()
	camera.fov = 50.0
	map.add_child(camera)
	camera.make_current()
	var rack: WallRack9U = map.get_node("ComputerRoomRack")
	var front := rack.global_position + Vector3(0, 0, 0.225)
	print("PORTS ", rack.port_ids().size(), " wan_link=", rack.is_link_on("router_wan"))
	for stage_name in ["installed", "cabled"]:
		rack.stage = WallRack9U.Stage.INSTALLED if stage_name == "installed" else WallRack9U.Stage.CABLED
		await process_frame
		camera.global_position = front + Vector3(-0.15, -0.05, 0.75)
		camera.look_at(rack.global_position + Vector3(0, 0.0, 0.1))
		await _shot("m2_rack_%s" % stage_name)
		camera.global_position = rack.port_position("router_lan1") + Vector3(0.02, 0.06, 0.22)
		camera.look_at(rack.port_position("router_lan1") + Vector3(0.0, 0.05, 0.0))
		await _shot("m2_rack_%s_close" % stage_name)
	# Level 3+: the cable from switch port 2 to the teacher PC's network card.
	var pc_port: NetworkPort = map.get_node("TeacherPcPort")
	print("PC_PORT plugged=", pc_port.plugged, " link=", pc_port.link_on)
	camera.fov = 60.0
	camera.global_position = pc_port.global_position + Vector3(0.35, 0.25, 0.75)
	camera.look_at(pc_port.global_position + Vector3(0, -0.2, 0))
	await _shot("m2_teacher_pc_port")
	camera.global_position = Vector3(5.2, 1.7, -6.2)
	camera.look_at(Vector3(7.4, 0.6, -9.2))
	await _shot("m2_cable_route")
	# Tools on the spare desk in the IT Support room.
	var props: Mission02Props = map.get_node("Mission02Props")
	for id: String in props.items:
		var item: PickupItem = props.items[id]
		var shape := item.get_child(item.get_child_count() - 1) as CollisionShape3D
		print("ITEM ", id, " box=", (shape.shape as BoxShape3D).size if shape else Vector3.ZERO)
	camera.global_position = Vector3(-14.55, 1.45, -38.43)
	camera.look_at(Vector3(-13.6, 0.76, -38.43))
	await _shot("m2_desk_tools")
	camera.global_position = Vector3(-15.8, 1.6, -36.6)
	camera.look_at(Vector3(-13.6, 0.8, -38.43))
	await _shot("m2_desk_room_view")
	# Access point on the ceiling in the middle of the computer room.
	camera.fov = 70.0
	camera.global_position = Vector3(1.2, 1.65, 3.2)
	camera.look_at(Vector3(2.96, 3.1, 0.0))
	await _shot("m2_access_point")
	# The rack as the player sees it, standing in the room.
	rack.stage = WallRack9U.Stage.INSTALLED
	await process_frame
	camera.fov = 70.0
	camera.global_position = rack.global_position + Vector3(-1.2, -0.1, 2.2)
	camera.look_at(rack.global_position)
	await _shot("m2_rack_player_view")
	# The work order (cable type for the two points), one option picked.
	var mission: Mission02Controller = map.get_node("Mission02")
	mission.work_order.open()
	mission.work_order.choose(1, Mission02State.STRAIGHT)
	await _shot("m2_work_order")
	mission.work_order.visible = false
	# The crimping desk: sit, then the cable end through the steps.
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.global_position = Vector3(-14.6, 0.05, -38.43)
	mission._enter(Mission02Controller.Stage.CRIMP)
	await mission.sit_at_desk(player)
	player.camera.make_current()
	var panel := mission.crimp_panel
	await _shot("m2_desk_whole")
	await panel.do_step() # cut
	await panel.do_step() # strip
	await _shot("m2_desk_stripped")
	await panel.do_step() # untwist
	await _shot("m2_desk_untwisted")
	for id in ["white_orange", "orange", "white_green"]:
		panel.place_wire(id)
	await _shot("m2_desk_arranging")
	for id in ["blue", "white_blue", "green", "white_brown", "brown"]:
		panel.place_wire(id)
	await _shot("m2_desk_arranged")
	panel.confirm_arrangement()
	await panel.do_step() # trim
	await panel.do_step() # insert
	await _shot("m2_desk_inserted")
	await panel.do_step() # crimp
	panel.bench.show_state(CrimpBench.Look.CRIMPED, WireColors.T568B)
	await _shot("m2_desk_crimped")
	print("CAPTURE_DONE ", out_dir)
	quit()
