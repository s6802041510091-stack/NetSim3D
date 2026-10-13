extends SceneTree

## Headless check for the E-to-open doors.
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

		# Closed door blocks a chest-high ray through the doorway; open does not.
		var chest := Vector3(doorway.x, 1.3, doorway.z)
		var ray := PhysicsRayQueryParameters3D.create(chest + Vector3(-0.6, 0, 0), chest + Vector3(0.6, 0, 0), 1)
		_check(not space.intersect_ray(ray).is_empty(), door_name + " closed door does not block the doorway")
		door.set_open(true, false)
		await physics_frame
		await physics_frame
		var hit := space.intersect_ray(ray)
		_check(hit.is_empty(), door_name + " open door still blocks the doorway: " + (str(hit.collider.name, " ", hit.position) if not hit.is_empty() else ""))

		# Open: the leaf is back exactly where the Blender model put it.
		var original: Node3D = reference.get_node(String(leaf.name))
		var drift := original.transform.origin.distance_to(leaf.global_transform.origin)
		_check(drift < 0.002, door_name + " open pose drifted %.4f m from the model" % drift)
		door.set_open(false, false)
		await physics_frame

	# Player walks up to the IT Support door, presses E and walks through.
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
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
		print("DOORS_VALID doors=", DOORWAYS.size(), " walked_to=", inside)
		quit()
	else:
		print("DOORS_INVALID failures=", failures)
		quit(1)
