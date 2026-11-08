extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = node.global_transform * node.get_aabb()
		if bounds.position.x < -13 and bounds.end.x > -13 and bounds.position.z < -25.8 and bounds.end.z > -25.8 and bounds.position.y < 0.1 and bounds.end.y > -0.3:
			print("OBSTRUCTION_CANDIDATE ", node.get_path(), " ", bounds)
	var query := PhysicsRayQueryParameters3D.create(Vector3(-13, 1, -25.8), Vector3(-13, -4, -25.8), 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	print("STAIR_RAY ", hit)
	var failures := 0
	for x in [-12.0, -14.0, -17.0]:
		var start := Vector3(x, 0.2, -25.8275)
		var end := Vector3(x, -3.5, -25.8275)
		for mesh in world.get_node("ExteriorTown/CampusAndGround").find_children("*", "MeshInstance3D", true, false):
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			for i in range(0, faces.size(), 3):
				var intersection: Variant = Geometry3D.segment_intersects_triangle(start, end, mesh.global_transform * faces[i], mesh.global_transform * faces[i+1], mesh.global_transform * faces[i+2])
				if intersection != null:
					push_error("Town blocks stair shaft: " + str(mesh.name) + " at " + str(intersection))
					failures += 1
	var player: CharacterBody3D = world.get_node("ITSupportPlayer")
	player.require_mouse_capture = false
	player.position = Vector3(-10.5, 0.01, -25.8275)
	player.rotation.y = PI / 2
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	for i in range(145):
		await physics_frame
	Input.action_release("move_forward")
	print("DOWN_STAIRS_POSITION ", player.position)
	if player.position.y > -3.2 or player.position.x > -17.5:
		failures += 1
	Input.action_press("move_back")
	for i in range(150):
		await physics_frame
	Input.action_release("move_back")
	print("RETURN_UP_POSITION ", player.position)
	if player.position.y < -0.05 or player.position.x < -11.0:
		failures += 1
	print("STAIR_CLEARANCE_VALIDATION failures=", failures)
	quit(1 if failures else 0)
