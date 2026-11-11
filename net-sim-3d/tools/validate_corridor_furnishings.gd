extends SceneTree

## Exercise the real player capsule, props, door sweeps and stair approach.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CORRIDOR: " + message)

func _run() -> void:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 5:
		await physics_frame
	var props: Node3D = map.get_node("CorridorFurnishings")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	# This checks permanent furniture clearance. Dynamic student collision,
	# yielding and looping are exercised separately by validate_students.gd.
	for student: StudentCharacter in map.get_node("CorridorStudents").students:
		student.process_mode = Node.PROCESS_MODE_DISABLED
		student.collision_layer = 0
	player.require_mouse_capture = false
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-6.15, .02, 7)
	var space := map.get_world_3d().direct_space_state
	var bounds: Array[AABB] = []
	var names: Array[String] = []
	var benches := 0
	var plants := 0
	var racks := 0
	for prop: Node3D in props.get_children():
		var collider: CollisionShape3D
		if prop.has_node("Collision"):
			collider = prop.get_node("Collision")
		else:
			collider = prop.get_node("PotCollision")
		var box := collider.global_transform * collider.shape.get_debug_mesh().get_aabb()
		bounds.append(box)
		names.append(prop.name)
		check(absf(box.position.y) < .002, prop.name + " must rest on floor")
		check(box.position.x > -9.1146 and box.end.x < -3.1854, prop.name + " intersects corridor wall")
		if prop.name.begins_with("Bench"):
			benches += 1
		elif prop.name.begins_with("Plant"):
			plants += 1
		else:
			racks += 1
			check(prop.get_meta("pair_capacity") == 30, prop.name + " capacity")
			check(prop.get_meta("columns") * prop.get_meta("rows") == 30, prop.name + " compartments")
		# Every solid prop must stop a player-sized capsule, not be visual-only.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = (player.get_node("CollisionShape3D") as CollisionShape3D).shape
		query.transform = Transform3D(Basis.IDENTITY, Vector3(box.get_center().x, .9, box.get_center().z))
		query.collision_mask = 1
		var hit_self := false
		for hit in space.intersect_shape(query):
			if hit.collider == prop:
				hit_self = true
		check(hit_self, prop.name + " does not stop player capsule")
	check(benches == 8 and plants == 11 and racks == 2, "unexpected furniture counts")
	for i in bounds.size():
		for j in range(i + 1, bounds.size()):
			check(not bounds[i].intersects(bounds[j]), names[i] + " overlaps " + names[j])
		# Clear approach to the stairwell, with no furniture on its landing.
		var stair_approach := AABB(Vector3(-9.2, 0, -30.52), Vector3(1.7, 2.1, 6.43))
		check(not bounds[i].intersects(stair_approach), names[i] + " blocks stair approach")
	# The whole animated leaf sweep must miss the new furniture, not just
	# the closed/open endpoints. No change to door code or room geometry.
	for door: InteractiveDoor in map.get_node("Doors").get_children():
		for k in range(13):
			var angle: float = door._open_angle * k / 12.0
			var swing := door.global_transform * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
			var shape_transform := swing * door._body.transform * door._shape.transform
			var leaf_box := shape_transform * door._shape.shape.get_debug_mesh().get_aabb()
			for i in bounds.size():
				check(not bounds[i].grow(.04).intersects(leaf_box), names[i] + " enters " + door.name + " swing")
	# Move the actual CharacterBody through the entire corridor in three lanes.
	# Fixed small steps use the real physics sweep, independently of frame rate.
	for lane in [-7.5, -6.15, -4.8]:
		for direction in [-1.0, 1.0]:
			var start_z := 8.5 if direction < 0 else -42.5
			player.global_position = Vector3(lane, .02, start_z)
			player.velocity = Vector3.ZERO
			for i in 510:
				var contact := player.move_and_collide(Vector3(0, 0, .1 * direction))
				if contact:
					check(false, "blocked lane x=%s at %s by %s" % [lane, player.global_position, contact.get_collider()])
					break
			check(absf(player.global_position.z - (start_z + 51 * direction)) < .05, "corridor traversal incomplete")
	# Cross from the corridor onto the stair entrance, without descending.
	for stair_z in [-25.3, -28.9]:
		player.global_position = Vector3(-6.15, .02, stair_z)
		for i in 33:
			var contact := player.move_and_collide(Vector3(-.1, 0, 0))
			if contact:
				check(false, "stair entrance blocked at " + str(player.global_position))
				break
		check(player.global_position.x < -9.3, "cannot enter stair landing")
	if failures == 0:
		print("CORRIDOR_VALID benches=8 plants=11 racks=2 capacity=60 pairs walks=6 stair_approaches=2 door_sweeps=8")
	else:
		print("CORRIDOR_INVALID failures=", failures)
	quit(1 if failures else 0)
