extends SceneTree

## Check the actual imported visuals against the generated collision data, then
## walk across the widened corridor and into the computer room. Run headlessly.
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("MAP ALIGNMENT: " + message)


func _walk(player: CharacterBody3D, rotation_y: float, frames: int) -> void:
	player.rotation.y = rotation_y
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	for i in range(frames):
		await physics_frame
	Input.action_release("move_forward")
	player.velocity = Vector3.ZERO


func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in range(3):
		await physics_frame
	var visual: Node3D = main.get_node("MapVisual")
	var collision: StaticBody3D = main.get_node("MapCollision")
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_collisions_phase5.json"))
	var checked := 0
	for entry: Dictionary in records:
		if entry.kind == "door":
			continue # Tested in both poses by validate_doors.gd.
		var mesh := visual.get_node_or_null(String(entry.name).replace(".", "_")) as MeshInstance3D
		_check(mesh != null, "missing visual for " + entry.name)
		if mesh == null:
			continue
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		# gltfpack can split one Blender object's materials into child meshes.
		for part: MeshInstance3D in mesh.find_children("*", "MeshInstance3D", true, false):
			bounds = bounds.merge(part.global_transform * part.get_aabb())
		var center := Vector3(entry.center[0], entry.center[1], entry.center[2])
		var size := Vector3(entry.size[0], entry.size[1], entry.size[2])
		if entry.name == "StairShell_Lower_EastWall":
			# The visible wall ends underneath the entrance slab to avoid duplicate
			# surfaces. Its existing solid collider may extend inside that slab.
			var slab: MeshInstance3D = visual.get_node("StairShell_Entrance_Threshold")
			var slab_bounds: AABB = slab.global_transform * slab.get_aabb()
			_check(bounds.end.y <= slab_bounds.position.y - 0.001,
				"stair wall still overlaps the visible threshold edge")
			bounds.size.y = slab_bounds.end.y - bounds.position.y
		var expected_size := bounds.size.max(Vector3.ONE * 0.02)
		_check(center.distance_to(bounds.get_center()) < 0.015, entry.name + " collider centre differs from visual: " + str(center - bounds.get_center()))
		_check(size.distance_to(expected_size) < 0.03, entry.name + " collider size differs from visual: " + str(size - expected_size))
		if entry.has("faces"):
			var coordinates: Array = entry.faces
			var faces_bounds := AABB(Vector3(coordinates[0], coordinates[1], coordinates[2]), Vector3.ZERO)
			for i in range(3, coordinates.size(), 3):
				faces_bounds = faces_bounds.expand(Vector3(coordinates[i], coordinates[i + 1], coordinates[i + 2]))
			_check(faces_bounds.get_center().distance_to(bounds.get_center()) < 0.015,
				entry.name + " triangle collision still uses an old transform")
		checked += 1
	_check(checked == collision.get_child_count(), "collision/visual coverage mismatch")
	# Re-aligning the colliders must not remove solid floors, walls or glass.
	var space := main.get_world_3d().direct_space_state
	for point in [Vector3(-4.5, 0.5, -10.5), Vector3(8.5, 0.5, -8.5)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN, 1))
		_check(not hit.is_empty() and absf(hit.position.y) < 0.01, "missing level floor at " + str(point))
	var panes_checked := 0
	for entry: Dictionary in records:
		if not String(entry.name).begins_with("EW_"):
			continue
		var center := Vector3(entry.center[0], entry.center[1], entry.center[2])
		var normal := Vector3.RIGHT if entry.size[0] < entry.size[2] else Vector3.BACK
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(center - normal * 0.15, center + normal * 0.15, 1))
		_check(not hit.is_empty(), entry.name + " glass does not block movement")
		panes_checked += 1
	_check(panes_checked == 62, "expected all exterior panes to remain solid")

	var player: CharacterBody3D = main.get_node("ITSupportPlayer")
	player.require_mouse_capture = false
	# This crossed the OLD right corridor wall at x=-6.075 before the fix.
	player.global_position = Vector3(-7.0, 0.02, -10.5)
	await _walk(player, -PI / 2.0, 55)
	_check(player.global_position.x > -4.5, "old invisible wall blocks widened corridor: " + str(player.global_position))
	# Follow a continuous L-shaped approach to the classroom, without teleporting
	# across the stale wall as the old short doorway ray test did.
	await _walk(player, PI, 38)
	var door: InteractiveDoor = main.get_node("Doors/ClassroomDoor")
	_check(door.set_open(true, false), "classroom could not open")
	await physics_frame
	await _walk(player, -PI / 2.0, 55)
	_check(player.global_position.x > -2.4, "cannot enter classroom from corridor: " + str(player.global_position))
	_check(absf(player.global_position.y) < 0.03, "classroom floor collision is not level")
	print("MAP_ALIGNMENT checked=", checked, " solid_panes=", panes_checked, " classroom_walk_end=", player.global_position, " failures=", failures)
	quit(0 if failures == 0 else 1)
