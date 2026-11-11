extends SceneTree

var camera: Camera3D
var output := "D:/NetSim3D/Preview/โถงทางเดิน/students"
func _initialize() -> void:
	call_deferred("_run")

func shot(file: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file+".png"))

func _run() -> void:
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(output)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 5:
		await process_frame
	var player: Node3D = map.get_node("ITSupportPlayer")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.hide()
	player.global_position = Vector3(3,.02,0)
	root.get_node("GameFlow")._layer.hide()
	for child in root.find_children("*", "CanvasLayer", true, false):
		child.hide()
	camera = Camera3D.new()
	camera.fov = 63
	map.add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await shot("corridor-students",Vector3(-6.1,1.65,5),Vector3(-6.1,1,-10))
	await create_timer(8).timeout
	await shot("bench-rest",Vector3(-6.7,1.4,1.5),Vector3(-8.6,.9,-.4))
	await shot("friends-chat",Vector3(-7.1,1.55,-13.8),Vector3(-5,1,-16.2))
	await create_timer(4.5).timeout
	await shot("friends-chat-reply",Vector3(-7.1,1.55,-13.8),Vector3(-5,1,-16.2))
	var life: StudentLife = map.get_node("CorridorStudents")
	for student in life.students:
		print("CAPTURE_STUDENT ",student.student_id," ",student.phase," ",student.activity," ",student.global_position)
	print("STUDENT_CAPTURE_OK")
	quit()
