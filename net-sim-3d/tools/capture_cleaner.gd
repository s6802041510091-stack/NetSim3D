extends SceneTree

## Photographs the housekeeper mopping the corridor and a restroom, and
## carrying the mop, from several angles.
var camera: Camera3D
var output := "D:/NetSim3D/Preview/โถงทางเดิน/cleaner"

func _initialize() -> void:
	call_deferred("_run")

func shot(file: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file + ".png"))

func around(c: CleanerCharacter, tag: String) -> void:
	var at := c.global_position
	var f := c.global_basis.z
	var side := c.global_basis.x
	c.set_physics_process(false)
	await shot(tag + "-front", at + f * 2.2 + Vector3(0, 1.3, 0), at + Vector3(0, .8, 0))
	await shot(tag + "-side", at + side * 2.2 + Vector3(0, 1.2, 0), at + f * .3 + Vector3(0, .8, 0))
	await shot(tag + "-hands", at + f * 1.0 - side * .6 + Vector3(0, 1.3, 0), at + f * .25 + Vector3(0, 1.0, 0))
	c.set_physics_process(true)

func _run() -> void:
	root.size = Vector2i(960, 800)
	DirAccess.make_dir_recursive_absolute(output)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	(map.get_node("CorridorStudents") as StudentLife).random_seed = 1
	root.add_child(map)
	for i in 5:
		await process_frame
	var player: Node3D = map.get_node("ITSupportPlayer")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.hide()
	player.global_position = Vector3(3, .02, 0)
	for child in root.find_children("*", "CanvasLayer", true, false):
		child.hide()
	camera = Camera3D.new()
	camera.fov = 60
	map.add_child(camera)
	camera.make_current()
	var life: StudentLife = map.get_node("CorridorStudents")
	var c := life.cleaner
	Engine.time_scale = 4
	var got := {}
	var t := 0.0
	while t < 900 and got.size() < 3:
		await process_frame
		t += get_root().get_process_delta_time() if false else 1.0 / 60.0 * 4
		camera.global_position = c.global_position + Vector3(0, 1.6, 2.5)
		if c.hidden:
			continue
		var in_room := c.global_position.x < -11.5
		var key := ""
		if c.is_mopping() and c._mop_blend > .99:
			key = "restroom-mopping" if in_room else "corridor-mopping"
		elif not c.is_mopping() and c._mop_blend < .01 and c.phase == "walk" and c.global_position.x > -9:
			key = "carrying"
		if key != "" and not got.has(key):
			Engine.time_scale = 1
			await process_frame
			await around(c, key)
			got[key] = true
			Engine.time_scale = 4
	Engine.time_scale = 1
	print("CLEANER_CAPTURE_OK ", got.keys(), " ", output)
	quit()
