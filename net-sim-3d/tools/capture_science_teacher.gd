extends SceneTree

## Views of ครูแสตมป์ at the science-room laptop, for picking his outfit.
## Run with a window:
##   godot --path net-sim-3d -s res://tools/capture_science_teacher.gd -- <out_dir> <outfit>
const VIEWS := {
	"front": [Vector3(-14.1, 1.6, -5.2), Vector3(-14.3, 1.0, -8.2)],
	"side": [Vector3(-12.2, 1.55, -7.6), Vector3(-14.3, 1.05, -8.1)],
	"room": [Vector3(-11.6, 1.65, -2.0), Vector3(-14.6, 0.9, -7.8)],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://science_teacher"
	var outfit: String = args[1] if args.size() > 1 else "white"
	var teacher_script: GDScript = load("res://scripts/npc/science_teacher.gd")
	teacher_script.set("outfit", outfit)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 20:
		await physics_frame
	(map.get_node("ITSupportPlayer") as Node3D).visible = false
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 60.0
	map.add_child(camera)
	camera.make_current()
	for key: String in VIEWS:
		camera.global_position = VIEWS[key][0]
		camera.look_at(VIEWS[key][1])
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [outfit, key]))
		print("SHOT ", outfit, " ", key)
	quit()
