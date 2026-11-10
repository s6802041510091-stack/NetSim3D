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
	# The storage room: cable boxes on the drawer island, the crimping-kit drawer.
	camera.fov = 70.0
	camera.global_position = Vector3(-12.9, 1.6, -35.4)
	camera.look_at(Vector3(-16.4, 0.9, -33.4))
	await _shot("m2_storage_from_door")
	camera.global_position = Vector3(-15.45, 1.45, -33.75)
	camera.look_at(Vector3(-16.32, 1.02, -33.75))
	await _shot("m2_storage_cable_boxes")
	camera.global_position = Vector3(-14.4, 1.6, -32.5)
	camera.look_at(Vector3(-14.6, 1.0, -31.1))
	await _shot("m2_storage_drawer")
	camera.global_position = Vector3(-15.6, 1.65, -40.4)
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
	# The cable box window and the drawer window.
	var mission: Mission02Controller = map.get_node("Mission02")
	mission.box_panel.open(Mission02State.STRAIGHT, {1: Mission02State.STRAIGHT})
	await _shot("m2_cable_box_window")
	mission.box_panel.visible = false
	mission.drawer.open({"cable_stripper": true})
	await _shot("m2_drawer_window")
	mission.drawer.visible = false
	# The crimping desk: sit, then the cable end through the steps.
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.global_position = Vector3(-14.6, 0.05, -38.43)
	mission.state.set_cable_type(1, Mission02State.STRAIGHT)
	mission.state.set_cable_type(2, Mission02State.CROSSOVER)
	mission._enter(Mission02Controller.Stage.CRIMP)
	camera.make_current()
	camera.fov = 70.0
	camera.global_position = Vector3(-14.45, 1.55, -38.1)
	camera.look_at(Vector3(-13.55, 0.76, -38.5))
	await _shot("m2_desk_laid_out")
	camera.global_position = Vector3(-15.6, 1.65, -40.4)
	camera.look_at(Vector3(-13.6, 0.8, -38.43))
	await _shot("m2_desk_room_view_laid_out")
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
	# The tester: cable 1 good, cable 2 with the green pair swapped.
	await mission.leave_desk()
	var swapped := WireColors.T568B.duplicate()
	swapped[2] = WireColors.T568B[5]
	swapped[5] = WireColors.T568B[2]
	mission.state.ends = {"1A": WireColors.T568B, "1B": WireColors.T568B, "2A": WireColors.T568B, "2B": swapped}
	mission._enter(Mission02Controller.Stage.TEST)
	await mission.sit_at_desk(player)
	player.camera.make_current()
	var tester_panel := mission.tester_panel
	await _shot("m2_tester_start")
	tester_panel.do_step()
	tester_panel.do_step()
	await _shot("m2_tester_plugged_on")
	tester_panel.do_step() # test cable 1
	tester_panel.judge(true)
	tester_panel.do_step() # cable 2: plug, power, test
	tester_panel.do_step()
	tester_panel.do_step()
	# Main LED 3 lights with remote LED 6 on cable 2.
	await create_timer(0.28 * 2 + 0.1).timeout
	await _shot("m2_tester_cable2_pin3")
	await create_timer(0.28 * 3).timeout
	await _shot("m2_tester_cable2_pin6")
	# Installing at the rack (cable 2 discarded -> spare).
	await mission.leave_desk()
	mission.state.tester_verdicts = {1: true, 2: false}
	mission.state.spare_cables = [2]
	player.global_position = Vector3(8.2, 0.05, -8.3)
	mission._enter(Mission02Controller.Stage.INSTALL)
	await mission.open_rack(player)
	player.camera.make_current()
	await _shot("m2_install_router_choice")
	var install := mission.install_panel
	install.choose_router_port("router_lan1")
	install.do_step()
	install.do_step()
	install.do_step()
	await _shot("m2_install_rack_done")
	await create_timer(0.8 + Mission02Controller.DESK_ZOOM_TIME + 0.4).timeout
	player.global_position = Vector3(6.26, 0.05, -7.0)
	mission.plug_pc(player)
	await create_timer(Mission02Controller.DESK_ZOOM_TIME + 0.5).timeout
	await _shot("m2_install_pc_port")
	# The summary (test progress file, removed afterwards).
	await create_timer(Mission02Controller.PC_LED_LOOK + Mission02Controller.DESK_ZOOM_TIME + 0.3).timeout
	GameProgress.save_path = "user://capture_progress_m2.json"
	mission.state.set_cable_type(1, Mission02State.STRAIGHT)
	mission.state.set_cable_type(2, Mission02State.CROSSOVER)
	mission.state.router_port = "router_lan1"
	mission.elapsed_sec = 860.0
	mission.finish(player)
	await create_timer(1.8).timeout
	await _shot("m2_summary")
	mission.summary.show_details()
	await _shot("m2_summary_details")
	GameProgress.clear()
	print("CAPTURE_DONE ", out_dir)
	quit()
