extends SceneTree

## Player-eye views of the stairwell (corridor end, main landing, both
## flights, the floors above and below), for judging its look.
## Run with a window: godot --path net-sim-3d -s res://tools/capture_stairwell.gd -- <out_dir>
const VIEWS := {
	"1_from_corridor": [Vector3(-6.6, 1.6, -28.0), Vector3(-15.0, 1.9, -28.4)],
	"2_down_flight": [Vector3(-10.4, 1.6, -25.9), Vector3(-16.0, -1.6, -25.9)],
	"3_up_flight": [Vector3(-10.4, 1.6, -28.8), Vector3(-17.5, 3.6, -28.8)],
	"4_lower_floor": [Vector3(-19.6, -1.9, -25.5), Vector3(-12.0, -2.6, -28.5)],
	"5_upper_floor": [Vector3(-12.0, 4.85, -28.9), Vector3(-19.5, 4.2, -28.4)],
	"6_landing_wall": [Vector3(-13.5, 1.6, -27.3), Vector3(-9.2, 1.5, -30.5)],
	"7_landing_close": [Vector3(-8.6, 1.6, -25.4), Vector3(-12.2, 0.7, -28.6)],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://stairwell"
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
	camera.fov = 70.0
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
