extends SceneTree

## Screenshots of the seated male teacher (Levels 1-2), the computer room
## door frame and the player looking down (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_teacher_door.gd -- <out_dir>

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 6:
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
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 20:
		await process_frame
	var camera := Camera3D.new()
	camera.fov = 65.0
	map.add_child(camera)
	camera.make_current()
	var seat := TeacherSeat.SEAT
	for view in [["teacher_side", seat + Vector3(-0.2, 1.5, 1.4), seat + Vector3(0.45, 0.8, 0.0)],
			["teacher_back", seat + Vector3(-1.3, 1.6, 0.4), seat + Vector3(0.5, 0.85, 0.0)],
			["teacher_hands", seat + Vector3(0.05, 1.35, -0.75), seat + Vector3(0.5, 0.78, 0.0)]]:
		camera.global_position = view[1]
		camera.look_at(view[2])
		await _shot(view[0])
	# The two plants moved out of the middle of the teachers' room.
	camera.global_position = Vector3(5.0, 1.65, -18.5)
	camera.look_at(Vector3(8.4, 0.6, -22.4))
	await _shot("plant_1_desk2")
	camera.global_position = Vector3(5.0, 1.65, -10.5)
	camera.look_at(Vector3(8.4, 0.6, -13.4))
	await _shot("plant_2_desk4")
	camera.global_position = Vector3(1.0, 1.65, -10.5)
	camera.look_at(Vector3(5.5, 0.6, -22.0))
	await _shot("teachers_room_middle")
	# The supervisor from the same angle, for comparison (same typing pose).
	var sup: Node3D = map.get_node("ITSupportSupervisor")
	camera.global_position = sup.global_transform * Vector3(0.75, 1.35, 0.05)
	camera.look_at(sup.global_transform * Vector3(0.0, 0.78, 0.5))
	await _shot("supervisor_hands")
	# The computer room door from the corridor, and close at the latch side.
	camera.global_position = Vector3(-4.8, 1.55, -6.6)
	camera.look_at(Vector3(-3.1, 1.1, -8.45))
	await _shot("door_corridor")
	camera.global_position = Vector3(-3.75, 1.3, -7.75)
	camera.look_at(Vector3(-3.1, 1.2, -7.95))
	await _shot("door_jamb_close")
	# The player looking down at the floor: no legs.
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.camera.make_current()
	player.camera.rotation.x = deg_to_rad(-80.0)
	await _shot("player_look_down")
	quit()
