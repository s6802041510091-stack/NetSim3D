extends SceneTree

## Views of the floors below and above, as seen from the corridor's landing
## and from inside them, for judging how finished they look.
## Run with a window: godot --path net-sim-3d -s res://tools/capture_stairwell_ends.gd -- <out_dir>
const VIEWS := {
	"a_look_down": [Vector3(-10.6, 1.6, -25.6), Vector3(-15.5, -1.8, -25.9)],
	"b_look_up": [Vector3(-10.6, 1.6, -28.9), Vector3(-17.0, 4.2, -28.8)],
	"c_lower_portal": [Vector3(-17.4, -1.85, -25.8), Vector3(-21.3, -2.3, -25.8)],
	"d_lower_back": [Vector3(-20.6, -1.85, -28.5), Vector3(-12.0, -2.0, -29.5)],
	"e_upper_portal": [Vector3(-17.4, 4.95, -25.8), Vector3(-21.3, 4.5, -25.8)],
	"f_upper_back": [Vector3(-20.6, 4.95, -26.0), Vector3(-12.0, 4.6, -26.5)],
	"g_beyond_lower": [Vector3(-20.0, -1.85, -25.9), Vector3(-25.0, -2.0, -25.9)],
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
	(map.get_node("ITSupportPlayer") as Node3D).visible = false
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 75.0
	map.add_child(camera)
	camera.make_current()
	for key: String in VIEWS:
		camera.global_position = VIEWS[key][0]
		camera.look_at(VIEWS[key][1])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(key + ".png"))
		print("SHOT ", key)
	quit()
