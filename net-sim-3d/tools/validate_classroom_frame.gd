extends SceneTree

## Tight frame fit regression: centre-only tests missed a 40 mm hinge gap.
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CLASSROOM FRAME: " + message)


func _bounds(mesh: MeshInstance3D) -> AABB:
	return mesh.global_transform * mesh.get_aabb()


func _check_closed(door: InteractiveDoor, visual: Node3D, leaf: MeshInstance3D) -> void:
	var front := _bounds(visual.get_node("Door_Frame_Front_Jamb"))
	var rear := _bounds(visual.get_node("Door_Frame_Rear_Jamb"))
	var header := _bounds(visual.get_node("Door_Frame_Header"))
	var panel := _bounds(leaf)
	var hinge_gap := panel.position.z - front.end.z
	var latch_gap := rear.position.z - panel.end.z
	var top_gap := header.position.y - panel.end.y
	var depth_offset := panel.get_center().x - header.get_center().x
	_check(absf(hinge_gap - 0.004) < 0.001, "hinge gap is %.4f m, expected 0.004" % hinge_gap)
	_check(absf(latch_gap - 0.004) < 0.001, "latch gap is %.4f m, expected 0.004" % latch_gap)
	_check(absf(top_gap - 0.004) < 0.001, "header gap is %.4f m, expected 0.004" % top_gap)
	_check(absf(panel.position.y - 0.008) < 0.001, "floor gap is %.4f m, expected 0.008" % panel.position.y)
	_check(absf(depth_offset) < 0.001, "leaf is %.4f m out of the frame plane" % depth_offset)
	_check(absf(door.global_position.x - header.get_center().x) < 0.001 and
		absf(door.global_position.z - front.end.z) < 0.001, "hinge is not on the frame's inner edge")
	var collider_bounds: AABB = door._shape.global_transform * door._shape.shape.get_debug_mesh().get_aabb()
	_check(collider_bounds.get_center().distance_to(panel.get_center()) < 0.001 and
		collider_bounds.size.distance_to(panel.size) < 0.001, "moving collider does not fit the corrected leaf")
	print("CLASSROOM_FRAME_GAPS hinge=", hinge_gap, " latch=", latch_gap,
		" top=", top_gap, " floor=", panel.position.y, " depth=", depth_offset)


func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	var door: InteractiveDoor = main.get_node("Doors/ClassroomDoor")
	var visual: Node3D = main.get_node("MapVisual")
	var leaf: MeshInstance3D = door.get_node("Swing/Door_Leaf_Open_63deg")
	_check_closed(door, visual, leaf)
	# Repeated animated cycles must return to the same fit, without accumulating drift.
	for cycle in range(3):
		_check(door.set_open(true), "open request failed")
		for i in range(40):
			await physics_frame
		_check(door.is_open and not door.is_moving, "open animation did not finish")
		_check(door.set_open(false), "close request failed")
		for i in range(40):
			await physics_frame
		_check(not door.is_open and not door.is_moving, "close animation did not finish")
		_check_closed(door, visual, leaf)
	print("CLASSROOM_FRAME_VALIDATION cycles=3 failures=", failures)
	quit(0 if failures == 0 else 1)
