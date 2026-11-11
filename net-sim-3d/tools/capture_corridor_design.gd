extends SceneTree

## Preview-only capture; does not change the map or player saves.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 12:
		await process_frame
	root.get_node("GameFlow")._layer.hide()
	var player: Node3D = map.get_node("ITSupportPlayer")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.hide()
	for child in root.find_children("*", "CanvasLayer", true, false):
		child.hide()
	var camera := Camera3D.new()
	map.add_child(camera)
	camera.fov = 74.0
	camera.global_position = Vector3(-6.15, 1.65, 4.0)
	camera.look_at(Vector3(-6.15, 1.35, -20.0))
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "D:/NetSim3D/Preview/โถงทางเดิน"
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("corridor-built.png"))
	camera.global_position = Vector3(-6.4, 1.5, 2.5)
	camera.look_at(Vector3(-3.42, .55, 0))
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("shoe-rack-built.png"))
	camera.global_position = Vector3(-6.15, 1.65, -21.0)
	camera.look_at(Vector3(-9.2, 1.1, -27.3))
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("stairs-built.png"))
	print("CORRIDOR_CAPTURE_OK")
	quit()
