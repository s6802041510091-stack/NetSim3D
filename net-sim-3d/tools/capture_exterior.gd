extends SceneTree

## Views of the town around the school, from above and from the street.
## Run with a window: godot --path net-sim-3d -s res://tools/capture_exterior.gd -- <out_dir>
const VIEWS := {
	"aerial_ne": [Vector3(70, 45, 40), Vector3(0, -5, -15)],
	"aerial_sw": [Vector3(-80, 40, -70), Vector3(0, -5, -15)],
	"street_level": [Vector3(30, -5.4, 30), Vector3(0, -2, -10)],
	"street_houses": [Vector3(-2, -5.6, 43), Vector3(-14, -4.5, 56)],
	"konbini_corner": [Vector3(-50, -5.6, 40), Vector3(-66, -4.5, 52)],
	"east_from_school": [Vector3(11, 1.6, -5), Vector3(60, -4, -5)],
	"railway": [Vector3(104, -5.5, -60), Vector3(114, 1.5, -10)],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 10:
		await physics_frame
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 2000.0
	map.add_child(camera)
	camera.make_current()
	# The train halfway along the line, for the pictures.
	var suburb := map.get_node_or_null("ExteriorTown/JapaneseSuburb")
	if suburb:
		suburb._train_t = 16.0
	var views := VIEWS.duplicate()
	for key: String in views:
		camera.global_position = views[key][0]
		camera.look_at(views[key][1])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(key + ".png"))
		print("SHOT ", key, " ", Engine.get_frames_per_second(), " fps ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " draws")
	quit()
