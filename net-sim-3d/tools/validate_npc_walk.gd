extends SceneTree

## NPC walking (NpcCharacter): stand up, walk a route in the teachers' room,
## wait for the player in the way, come back and sit down.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_npc_walk.gd
## With a window and `-- <out_dir>` it also saves screenshots.

var failures := 0
var out_dir := ""

## Male teacher: from his desk (STAFF-PC-02) along the aisle to the door of
## the female teacher's office and in, as the chat routine will.
const ROUTE := [Vector3(6.6, 0.02, -21.39), Vector3(6.6, 0.02, -24.8), Vector3(7.95, 0.02, -24.8), Vector3(7.95, 0.02, -26.2)]


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ", message)
	if not ok:
		failures += 1


func _shot(name: String) -> void:
	if out_dir == "":
		return
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 5:
		await physics_frame
	var teacher := map.get_node("TeacherMale") as NpcCharacter
	var player := map.get_node("ITSupportPlayer") as CharacterBody3D
	player.global_position = Vector3(2.0, 0.05, -14.0) # out of the way
	var camera := Camera3D.new()
	camera.fov = 65.0
	map.add_child(camera)
	camera.make_current()
	_check(teacher != null and teacher.seated, "male teacher starts seated at his desk")
	var seat := teacher.global_transform

	# The route must clear the map's colliders (desks, partitions, walls).
	var space := map.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.5
	var points := [seat.origin - seat.basis.z.normalized() * NpcCharacter.STAND_BACK] + ROUTE
	for i in points.size() - 1:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, (points[i] as Vector3) + Vector3(0, 0.95, 0))
		query.motion = (points[i + 1] as Vector3) - (points[i] as Vector3)
		var hit := space.cast_motion(query)
		_check(hit[0] >= 1.0, "route leg %d clear of the map (%.2f)" % [i + 1, hit[0]])

	# Stand up.
	camera.global_position = seat.origin + Vector3(-1.6, 1.5, 1.4)
	camera.look_at(seat.origin + Vector3(0, 0.9, 0))
	teacher.stand_up() # runs on; checked below
	await create_timer(NpcCharacter.STAND_TIME * 0.5).timeout
	await _shot("walk_1_standing_up")
	await create_timer(NpcCharacter.STAND_TIME * 0.6).timeout
	var visual := teacher.get_node("Visual") as Node3D
	_check(not teacher.seated and visual.position.length() < 0.001, "stood up: body up off the seat")
	_check(teacher.global_position.distance_to(points[0]) < 0.01, "stood up a step back from the desk")
	var hand_l := teacher.skeleton.get_bone_global_pose(teacher.skeleton.find_bone("wrist.L")).origin
	var hip := teacher.skeleton.get_bone_global_pose(teacher.skeleton.find_bone("upperleg01.L")).origin
	_check(hand_l.y < hip.y + 0.05, "arms hang by the sides (wrist %.2f, hip %.2f)" % [hand_l.y, hip.y])
	await _shot("walk_2_standing")

	# Walk; the player steps in the way on the second leg.
	teacher.walk_path(ROUTE) # runs on; polled below
	await create_timer(0.7).timeout
	camera.global_position = teacher.global_position + Vector3(-2.4, 1.2, -0.9)
	camera.look_at(teacher.global_position + Vector3(0, 0.9, 0))
	await _shot("walk_3_walking")
	var thigh_l := teacher.skeleton.get_bone_pose_rotation(teacher.skeleton.find_bone("upperleg01.L"))
	var thigh_r := teacher.skeleton.get_bone_pose_rotation(teacher.skeleton.find_bone("upperleg01.R"))
	_check(teacher.walking and teacher._walk_blend > 0.5 and thigh_l.angle_to(thigh_r) > 0.05, "walking: the legs swing")
	while teacher.walking and teacher._path.size() > 3:
		await process_frame
	await create_timer(1.2).timeout
	camera.global_position = teacher.global_position + Vector3(-2.3, 1.15, -0.6)
	camera.look_at(teacher.global_position + Vector3(0, 0.85, -0.6))
	await _shot("walk_3b_side")
	while teacher.walking and teacher._path.size() > 2:
		await process_frame
	await create_timer(0.3).timeout
	var ahead := Vector3(sin(teacher.rotation.y), 0.0, cos(teacher.rotation.y))
	player.global_position = teacher.global_position + ahead * 0.7 + Vector3(0, 0.03, 0)
	await create_timer(0.6).timeout
	var held := teacher.global_position
	await create_timer(0.8).timeout
	_check(teacher.blocked and teacher.global_position.distance_to(held) < 0.01, "waits while the player stands in the way")
	player.global_position = Vector3(2.0, 0.05, -14.0)
	await create_timer(0.8).timeout
	_check(not teacher.blocked and teacher.global_position.distance_to(held) > 0.2, "walks on once the way is clear")
	while teacher.walking:
		await process_frame
	_check(teacher.global_position.distance_to(ROUTE[-1]) < 0.06, "arrived at the office")
	camera.global_position = Vector3(6.5, 1.6, -23.6)
	camera.look_at(teacher.global_position + Vector3(0, 0.9, 0))
	await _shot("walk_4_at_office")

	# Back to the desk and sit down.
	var back := ROUTE.duplicate()
	back.reverse()
	back.pop_front()
	back.append(points[0])
	await teacher.walk_path(back)
	await teacher.face_yaw(seat.basis.get_euler().y)
	await teacher.sit_down()
	_check(teacher.seated and teacher.global_transform.origin.distance_to(seat.origin) < 0.01 and absf(angle_difference(teacher.rotation.y, seat.basis.get_euler().y)) < 0.01, "back on his seat, facing the desk")
	_check(visual.position.distance_to(Vector3(0, -teacher.seat_drop, teacher.seat_forward)) < 0.001, "seated again")
	await create_timer(1.0).timeout
	camera.global_position = seat.origin + Vector3(-1.6, 1.5, 1.4)
	camera.look_at(seat.origin + Vector3(0, 0.9, 0))
	await _shot("walk_5_seated_again")
	print("NPC_WALK_VALID" if failures == 0 else "NPC_WALK_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
