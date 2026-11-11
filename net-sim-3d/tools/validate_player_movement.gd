extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/it_support_player.tscn")
	var player: CharacterBody3D = scene.instantiate()
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(player)
	await process_frame

	# The player's own body (legs included) is hidden from the first-person camera.
	var shown := 0
	var hidden := 0
	for part in player.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		if part.layers == 2:
			hidden += 1
		else:
			shown += 1
	if shown > 0 or hidden < 2:
		push_error("First-person body layers are wrong: shown=%d hidden=%d" % [shown, hidden])
		quit(1)
		return

	_add_box(world, "Floor", Vector3(4.0, 0.2, 4.0), Vector3(0, -0.1, 0))
	_add_box(world, "LowStep", Vector3(0.5, 0.18, 1.0), Vector3(0.25, 0.09, 0))
	player.global_position = Vector3(-0.33, 0, 0)
	await physics_frame
	player._try_step_up(Vector3(0.12, 0, 0))
	var stepped_height := player.global_position.y
	if stepped_height < 0.14 or stepped_height > 0.29:
		push_error("The 18 cm step was not climbed: y=%f" % stepped_height)
		quit(1)
		return

	player.global_position = Vector3(-0.33, 0, 0)
	var low_step: StaticBody3D = world.get_node("LowStep")
	low_step.queue_free()
	await physics_frame
	_add_box(world, "HighBlock", Vector3(0.5, 0.6, 1.0), Vector3(0.25, 0.3, 0))
	await physics_frame
	player._try_step_up(Vector3(0.12, 0, 0))
	if player.global_position.y > 0.03:
		push_error("A 60 cm wall was climbed: y=%f" % player.global_position.y)
		quit(1)
		return
	player.global_position = Vector3(-1.5, 0, 1.5)
	player.velocity = Vector3.ZERO
	player.require_mouse_capture = false
	Input.action_press("move_forward")
	Input.action_press("run")
	for i in range(26):
		await physics_frame
	var measured_run_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("run")
	Input.action_release("move_forward")
	if measured_run_speed < player.walk_speed + 1.0:
		push_error("Run speed did not exceed walk speed: %f" % measured_run_speed)
		quit(1)
		return

	var map_scene: PackedScene = load("res://scenes/main.tscn")
	var map: Node3D = map_scene.instantiate()
	root.add_child(map)
	var map_player: CharacterBody3D = map.get_node("ITSupportPlayer")
	map_player.global_position = Vector3(-10.98, 0, -28.7875)
	await physics_frame
	map_player._try_step_up(Vector3(-0.12, 0, 0))
	var map_stair_height := map_player.global_position.y
	if map_stair_height < 0.13 or map_stair_height > 0.28:
		push_error("The map's first stair was not climbed: y=%f" % map_stair_height)
		quit(1)
		return

	map_player.global_position = Vector3(-10.70, 0, -28.7875)
	map_player.rotation.y = PI / 2.0
	map_player.require_mouse_capture = false # Headless tests have no captured window.
	Input.action_press("move_forward")
	for i in range(24):
		await physics_frame
	Input.action_release("move_forward")
	if map_player.global_position.y < 0.13:
		push_error("Keyboard movement did not climb the map staircase: " + str(map_player.global_position))
		quit(1)
		return
	var climbed_position := map_player.global_position
	Input.action_press("move_back")
	for i in range(45):
		await physics_frame
	Input.action_release("move_back")
	if map_player.global_position.y > 0.05:
		push_error("Floor snapping did not descend the map staircase: " + str(map_player.global_position))
		quit(1)
		return

	print("PLAYER_MOVEMENT_VALID body_hidden=", hidden, " run_speed=", measured_run_speed, " step_height=", stepped_height, " map_stair_height=", map_stair_height, " climbed_to=", climbed_position, " descended_to=", map_player.global_position)
	quit()


func _add_box(parent: Node3D, name: String, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	parent.add_child(body)
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
