extends SceneTree

## Close-ups of a door's lever as the door opens: at rest, pressed down,
## sprung back. Run with a window:
## godot --path net-sim-3d -s res://tools/capture_door_lever.gd -- <out_dir> [door name]
func _initialize() -> void:
	call_deferred("_run")

func _shot(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var door_name: String = args[1] if args.size() > 1 else "BackgroundClassDoor"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(960, 540)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 10:
		await physics_frame
	(map.get_node("ITSupportPlayer") as Node3D).visible = false
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var door: InteractiveDoor = map.get_node("Doors/" + door_name)
	print("pivots ", door._lever_pivots.size())
	var pivot: Node3D = door._lever_pivots[0]
	var across := door.global_basis.x.normalized()
	var lever := pivot.get_child(0) as MeshInstance3D
	var side := signf(across.dot((lever.global_transform * lever.get_aabb().get_center()) - door.get_doorway_center()))
	var camera := Camera3D.new()
	camera.fov = 40.0
	map.add_child(camera)
	camera.make_current()
	camera.global_position = pivot.global_position + across * side * 0.55 + Vector3(0, 0.12, 0) + door.global_basis.z.normalized() * 0.15
	camera.look_at(pivot.global_position + Vector3(0, -0.03, 0))
	for i in 4:
		await process_frame
	await _shot(out_dir, door_name + "_1_rest")
	door.set_open(true)
	await create_timer(0.13).timeout
	await _shot(out_dir, door_name + "_2_pressed")
	await create_timer(0.7).timeout
	print("rotations ", door._lever_pivots.map(func(p: Node3D): return snappedf(p.rotation.x, 0.001)))
	quit()
