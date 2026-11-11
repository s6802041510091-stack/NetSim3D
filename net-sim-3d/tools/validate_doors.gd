extends SceneTree

## Frame fit, animated open/close and real player traversal for all F-to-open doors.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_doors.gd

const DOORWAYS := {
	"ClassroomDoor": ["Door_Frame_Front_Jamb", "Door_Frame_Rear_Jamb"],
	"BackgroundClassDoor": ["BackgroundClass_Jamb", "BackgroundClass_Jamb_001"],
	"FemaleWCDoor": ["FemaleWC_Jamb", "FemaleWC_Jamb_001"],
	"MaleWCDoor": ["MaleWC_Jamb", "MaleWC_Jamb_001"],
	"ITSupportDoor": ["ITSupport_Jamb", "ITSupport_Jamb_001"],
	"StorageDoor": ["Storage_Jamb", "Storage_Jamb_001"],
	"StaffDoor": ["Staff_Jamb", "Staff_Jamb_001"],
	"ServerDoor": ["Server_Jamb", "Server_Jamb_001"],
}

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("DOOR CHECK FAILED: " + message)


func _run() -> void:
	var reference: Node3D = load("res://assets/models/classroom_shell.glb").instantiate()
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in range(3):
		await physics_frame

	var visual := map.get_node("MapVisual")
	var space := map.get_world_3d().direct_space_state
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.require_mouse_capture = false
	for door_name: String in DOORWAYS:
		var door: InteractiveDoor = map.get_node("Doors/" + door_name)
		var swing := door.get_node_or_null("Swing")
		_check(swing != null, door_name + " has no swing pivot")
		if swing == null:
			continue
		var leaf: MeshInstance3D = null
		for part in swing.get_children():
			if part is MeshInstance3D and String(part.name).begins_with(door.part_prefix + "Leaf"):
				leaf = part
		_check(leaf != null, door_name + " leaf was not collected")
		_check(not door.is_open, door_name + " should start closed")
		var swing_degrees := absf(rad_to_deg(door._open_angle))
		_check(swing_degrees > 55.0 and swing_degrees < 125.0, door_name + " swing angle %.1f" % swing_degrees)

		# Closed: the leaf sits inside the doorway between its jambs.
		var jambs: Array = DOORWAYS[door_name]
		var a: Vector3 = visual.get_node(jambs[0]).global_position
		var b: Vector3 = visual.get_node(jambs[1]).global_position
		var doorway := (a + b) / 2.0
		var leaf_center := leaf.global_transform * leaf.get_aabb().get_center()
		var offset := Vector2(leaf_center.x - doorway.x, leaf_center.z - doorway.z).length()
		_check(offset < 0.06, door_name + " closed leaf is %.3f m from the doorway centre" % offset)
		var leaf_bounds: AABB = leaf.global_transform * leaf.get_aabb()
		# Check both edges and the frame plane: a centre-only check can miss a
		# visible jamb gap or a shifted map rotating around an unshifted hinge.
		var jamb_a: AABB = visual.get_node(jambs[0]).global_transform * visual.get_node(jambs[0]).get_aabb()
		var jamb_b: AABB = visual.get_node(jambs[1]).global_transform * visual.get_node(jambs[1]).get_aabb()
		var low: AABB = jamb_a if jamb_a.position.z < jamb_b.position.z else jamb_b
		var high: AABB = jamb_b if jamb_a.position.z < jamb_b.position.z else jamb_a
		# Classroom: 4 mm in the model, 2 mm after school_visual_fixes.gd moves the
		# jambs into the opening (they were coplanar with the wall edge).
		var expected_gap := 0.002 if door_name == "ClassroomDoor" else 0.0
		var low_gap := leaf_bounds.position.z - low.end.z
		var high_gap := high.position.z - leaf_bounds.end.z
		var depth := leaf_bounds.get_center().x - (jamb_a.get_center().x + jamb_b.get_center().x) / 2.0
		_check(absf(low_gap - expected_gap) < 0.001 and absf(high_gap - expected_gap) < 0.001,
			door_name + " jamb gaps do not fit: " + str(low_gap, ", ", high_gap))
		_check(absf(depth) < 0.001, door_name + " leaf is outside the frame plane: " + str(depth))
		_check(leaf_bounds.position.y >= -0.005 and leaf_bounds.position.y < 0.025,
			door_name + " leaf is floating or sunk into the floor: " + str(leaf_bounds.position.y))

		# Closed door blocks a chest-high ray through the doorway; open does not.
		var chest := Vector3(doorway.x, 1.3, doorway.z)
		var ray := PhysicsRayQueryParameters3D.create(chest + Vector3(-0.6, 0, 0), chest + Vector3(0.6, 0, 0), 1)
		_check(not space.intersect_ray(ray).is_empty(), door_name + " closed door does not block the doorway")
		_check(door.set_open(true), door_name + " animated opening refused")
		for i in range(40):
			await physics_frame
		_check(door.is_open and not door.is_moving, door_name + " animated opening did not finish")
		await physics_frame
		await physics_frame
		var hit := space.intersect_ray(ray)
		_check(hit.is_empty(), door_name + " open door still blocks the doorway: " + (str(hit.collider.name, " ", hit.position) if not hit.is_empty() else ""))

		# Open: preserve Blender's hinge/height, extending narrow presentation
		# poses to the runtime minimum angle (90 degrees by default).
		var original: Node3D = reference.get_node(String(leaf.name))
		var authored_angle := (door.global_basis.inverse() * original.basis).orthonormalized().get_euler().y
		var extra_swing := Transform3D(Basis(Vector3.UP, door._open_angle - authored_angle), Vector3.ZERO)
		var expected := door.global_transform * extra_swing * door.global_transform.affine_inverse() * original.transform
		var drift := expected.origin.distance_to(leaf.global_transform.origin)
		_check(drift < 0.002, door_name + " open pose drifted %.4f m from the model" % drift)
		_check(expected.basis.is_equal_approx(leaf.global_basis), door_name + " open rotation differs from expected hinge swing")

		# Real capsule + keyboard movement, both directions, for EVERY doorway.
		# A ray alone can miss a blocker at knee height or on the approach.
		for direction in [-1.0, 1.0]:
			player.global_position = Vector3(doorway.x - direction * 1.4, 0.02, doorway.z)
			player.velocity = Vector3.ZERO
			player.rotation.y = -direction * PI / 2.0
			for i in range(3):
				await physics_frame
			Input.action_press("move_forward")
			for i in range(65):
				await physics_frame
			Input.action_release("move_forward")
			var crossed: float = (player.global_position.x - doorway.x) * direction
			if crossed <= 0.75:
				for i in range(player.get_slide_collision_count()):
					var contact := player.get_slide_collision(i)
					print("DOOR_WALK_CONTACT ", door_name, " ", contact.get_collider_shape().get_path(), " normal=", contact.get_normal())
			_check(crossed > 0.75, door_name + " cannot walk through (direction %.0f): %s" % [direction, player.global_position])
			_check(absf(player.global_position.y) < 0.03, door_name + " doorway floor is not level: " + str(player.global_position))
		# Keep the player outside every swing while changing the next door's state.
		player.global_position = Vector3(-7.0, 0.02, -40.0)
		player.velocity = Vector3.ZERO
		await physics_frame
		_check(door.set_open(false), door_name + " animated closing refused")
		for i in range(40):
			await physics_frame
		_check(not door.is_open and not door.is_moving, door_name + " animated closing did not finish")
		var returned: AABB = leaf.global_transform * leaf.get_aabb()
		_check(returned.position.distance_to(leaf_bounds.position) < 0.001 and returned.size.distance_to(leaf_bounds.size) < 0.001,
			door_name + " did not return to its original frame fit")
		var collider_bounds: AABB = door._shape.global_transform * door._shape.shape.get_debug_mesh().get_aabb()
		_check(collider_bounds.position.distance_to(returned.position) < 0.001 and collider_bounds.size.distance_to(returned.size) < 0.001,
			door_name + " collider does not match the closed leaf")
		print("DOOR_FIT ", door_name, " gaps_mm=", Vector2(low_gap, high_gap) * 1000,
			" depth_mm=", depth * 1000, " animated_cycle=complete bidirectional_walk=complete")

	# Player walks up to the IT Support door, presses E and walks through.
	var it_door: InteractiveDoor = map.get_node("Doors/ITSupportDoor")
	player.require_mouse_capture = false
	player.global_position = Vector3(-8.2, 0.02, -34.98)
	player.rotation = Vector3(0, PI / 2.0, 0)
	player.camera.rotation.x = 0.0
	for i in range(4):
		await physics_frame
	_check(player.focused_door == it_door, "player is not focused on the IT Support door")
	_check(player._prompt.visible and player._prompt.text.contains("เปิด"), "open prompt not shown: " + player._prompt.text)

	Input.action_press("move_forward")
	for i in range(40):
		await physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.x > -9.0, "closed door did not stop the player: " + str(player.global_position))

	player.interact()
	for i in range(45):
		await physics_frame
	_check(it_door.is_open and not it_door.is_moving, "E did not open the IT Support door")

	Input.action_press("move_forward")
	for i in range(70):
		await physics_frame
	Input.action_release("move_forward")
	var inside := player.global_position
	_check(inside.x < -9.6, "player could not walk through the open door: " + str(inside))

	# Standing in the leaf's path, the door refuses to close on the player.
	player.global_position = Vector3(-9.75, 0.02, -35.0)
	player.velocity = Vector3.ZERO
	await physics_frame
	_check(not it_door.toggle(), "door closed through the player")
	_check(it_door.is_open, "blocked door changed state")

	# Step clear, then E closes it again.
	player.global_position = Vector3(-8.2, 0.02, -34.98)
	await physics_frame
	await physics_frame
	_check(player.focused_door == it_door, "player lost focus on the door")
	player.interact()
	for i in range(45):
		await physics_frame
	_check(not it_door.is_open, "E did not close the IT Support door")

	reference.free()
	if failures == 0:
		print("DOORS_VALID doors=", DOORWAYS.size(), " bidirectional_walks=16 floor_and_open_pose=valid walked_to=", inside)
		quit()
	else:
		print("DOORS_INVALID failures=", failures)
		quit(1)
