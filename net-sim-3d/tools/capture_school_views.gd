extends SceneTree

## Phase B visual check: screenshot the same camera views of the school so a
## reduced model can be compared with the original by eye.
## Run WITH a window (not --headless):
##   godot --path net-sim-3d -s res://tools/capture_school_views.gd -- <out_dir> [<original.glb>]
## With <original.glb> (an absolute path to an un-imported GLB) the map visual is
## swapped for that file, loaded at runtime, so "before" shots need no reimport.
## Views are derived from the computer screens, so both runs use identical poses.


func _initialize() -> void:
	call_deferred("_run")


func _screen_pose(station: ComputerStation) -> Array:
	var aabb := station.screen.get_aabb()
	var center := station.screen.global_transform * aabb.get_center()
	return [center, station.screen.global_basis.z.normalized()]


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	# No first-person arm in the shots.
	var player := main.get_node("ITSupportPlayer")
	main.remove_child(player)
	player.free()
	root.add_child(main)
	for i in 3:
		await process_frame
	var computers: ComputerManager = main.get_node("Computers")
	var views := {}
	var students := Vector3.ZERO
	var count := 0
	for station in computers.stations:
		if station.hostname.begins_with("PC-R"):
			students += _screen_pose(station)[0]
			count += 1
	students /= maxi(count, 1)
	var desk: Array = _screen_pose(computers.find_host("PC-R3-L2"))
	views["student_desk_closeup"] = [desk[0] + desk[1] * 0.85 + Vector3.UP * 0.3, desk[0] + Vector3.DOWN * 0.3]
	var teacher: Array = _screen_pose(computers.find_host("TEACHER-PC"))
	views["classroom_from_teacher"] = [teacher[0] + teacher[1] * 0.9 + Vector3.UP * 0.75, students]
	var it_pc: Array = _screen_pose(computers.find_host("IT-PC-01"))
	var it_head: Array = _screen_pose(computers.find_host("IT-HEAD-PC"))
	views["it_support_room"] = [it_pc[0] + it_pc[1] * 1.6 + Vector3.UP * 0.5, it_head[0]]
	var staff: Array = _screen_pose(computers.find_host("STAFF-PC-01"))
	views["teachers_room"] = [staff[0] + staff[1] * 2.4 + Vector3.UP * 0.5, staff[0]]
	views["server_room"] = [Vector3(-2.6, 1.7, -36.6), Vector3(-0.5, 1.0, -41.0)]

	if args.size() > 1:
		var visual := main.get_node("MapVisual")
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(args[1], state) != OK:
			push_error("cannot load " + args[1])
			quit(1)
			return
		var original := doc.generate_scene(state)
		original.transform = visual.transform
		main.remove_child(visual)
		visual.queue_free()
		main.add_child(original)
	var camera := Camera3D.new()
	camera.fov = 70.0
	main.add_child(camera)
	camera.make_current()
	for i in 30:
		await process_frame
	for view_name: String in views:
		var pose: Array = views[view_name]
		camera.global_position = pose[0]
		camera.look_at(pose[1])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(view_name + ".png"))
		print("SHOT ", view_name)
	print("CAPTURE_DONE ", out_dir)
	quit(0)
