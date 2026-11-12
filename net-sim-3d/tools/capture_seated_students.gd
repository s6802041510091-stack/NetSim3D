extends SceneTree

## Seats all seven corridor students and photographs each one from where a
## standing player looks at them, plus a side view; also the girls standing,
## to check the runtime thighs stay inside the skirt.
var camera: Camera3D
var output := "D:/NetSim3D/Preview/โถงทางเดิน/students/seated"
const SEATS := {"mullet": "BenchLeft02", "two_block": "BenchRight02", "bob": "BenchLeft01",
	"wendy": "BenchRight03", "layer": "BenchRight01", "mullet_b": "BenchLeft04", "bob_b": "BenchRight04"}

func _initialize() -> void:
	call_deferred("_run")

func shot(file: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file + ".png"))

func _run() -> void:
	root.size = Vector2i(960, 800)
	DirAccess.make_dir_recursive_absolute(output)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	(map.get_node("CorridorStudents") as StudentLife).random_seed = 3
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
	await create_timer(4).timeout
	# Girls standing, low and from the side: thighs must stay under the skirt.
	for s in life.students:
		if s.student_id in StudentLife.FEMALE and not s.seated and not s.hidden:
			# In the middle of the corridor, facing along it, for clear views.
			s.set_physics_process(false)
			s.global_position = Vector3(-6.15, .02, -2.0)
			s.rotation.y = PI / 2
			await create_timer(.3).timeout
			var f := s.global_basis.z
			var side := s.global_basis.x
			await shot("standing-%s-front" % s.student_id, s.global_position + f * 1.3 + Vector3(0, .7, 0), s.global_position + Vector3(0, .65, 0))
			await shot("standing-%s-side" % s.student_id, s.global_position + side * 1.3 + Vector3(0, .7, 0), s.global_position + Vector3(0, .65, 0))
			s.set_physics_process(true)
	# Everyone onto a bench of their own, for good.
	for s in life.students:
		life._release(s)
		s.chat_group = ""
		if s.seated:
			s.hold_time = 9999
			s._leaving = false
			continue
		var step := life.seat(SEATS[s.student_id], 9999, .0)
		step["anchor"] = true
		s.global_position = step["point"]
		s.rotation.y = step["yaw"]
		var plan: Array[Dictionary] = [step]
		s.start_routine(life, plan)
	await create_timer(4).timeout
	for s in life.students:
		print("SEATED ", s.student_id, " seated=", s.seated, " phase=", s.phase, " at ", s.global_position)
		var f := s.global_basis.z
		var side := s.global_basis.x
		var at := s.global_position
		await shot("seated-%s-player-view" % s.student_id, at + f * .95 + Vector3(0, 1.62, 0), at + f * .3 + Vector3(0, .45, 0))
		await shot("seated-%s-low-front" % s.student_id, at + f * 1.2 + Vector3(0, .75, 0), at + f * .25 + Vector3(0, .5, 0))
		await shot("seated-%s-side" % s.student_id, at + side * 1.25 + f * .35 + Vector3(0, .8, 0), at + f * .2 + Vector3(0, .5, 0))
	print("SEATED_CAPTURE_OK ", output)
	quit()
