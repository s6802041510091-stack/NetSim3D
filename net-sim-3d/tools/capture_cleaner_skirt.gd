extends SceneTree

## Housekeeper walking away from the camera: pictures of the back of her skirt
## mid-stride, with and without the runtime thighs, to find what shows through.
var output := "D:/NetSim3D/Preview/โถงทางเดิน/cleaner/skirt"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 5:
		await physics_frame
	var life: StudentLife = map.get_node("CorridorStudents")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.set_physics_process(false)
	player.global_position = Vector3(3, .02, 0)
	player.hide()
	for s in life.students:
		s.set_physics_process(false)
		s.hide()
	var c := life.cleaner
	c.global_position = Vector3(-6.15, .02, 4)
	c.rotation.y = PI
	var walk: Array[Dictionary] = [{"point": Vector3(-6.15, .02, -30), "via": true}]
	c.start_routine(life, walk)
	var cam := Camera3D.new()
	map.add_child(cam)
	cam.fov = 50
	cam.make_current()
	var thighs := c.find_child("Thighs (runtime)", true, false) as Node3D
	print("SKIRT thighs=", thighs != null)
	var shot := 0
	var t := 0.0
	while shot < 6:
		await physics_frame
		t += 1.0 / 60.0
		var p := c.global_position
		cam.global_position = p + Vector3(.1, 1.0, 1.25)
		cam.look_at(p + Vector3(0, .65, 0))
		if t > 3.0 + shot * .37:
			for with_thighs in [true, false]:
				if thighs:
					thighs.visible = with_thighs
				await process_frame
				await RenderingServer.frame_post_draw
				var img := root.get_viewport().get_texture().get_image()
				img.save_png("%s/back_%d_%s.png" % [output, shot, "thighs" if with_thighs else "no_thighs"])
			if thighs:
				thighs.visible = true
			shot += 1
	print("SKIRT_CAPTURE_OK ", output)
	quit()
