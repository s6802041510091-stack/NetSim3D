extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error("STUDENTS: " + note)

func _run() -> void:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 5:
		await physics_frame
	var life: StudentLife = map.get_node("CorridorStudents")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.set_physics_process(false)
	player.global_position = Vector3(3, .02, 0) # out of every corridor route
	check(life.students.size() == 5, "five students")
	var space := map.get_world_3d().direct_space_state
	for student in life.students:
		check(student.skeleton != null and student.skeleton.get_bone_count() >= 160, student.student_id + " rig")
		for bone in ["upperarm01.L", "upperleg01.L", "spine05", "wrist.R"]:
			check(student.skeleton.find_bone(bone) >= 0, student.student_id + " bone " + bone)
		var shape: CollisionShape3D = student.get_node("CollisionShape3D")
		var points: Array[Vector3] = [student.global_position]
		for step in student.routine:
			points.append(step["point"])
		points.append(student.routine[0]["point"])
		for i in range(points.size()-1):
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape.shape
			q.transform = Transform3D(Basis.IDENTITY, points[i] + shape.position)
			q.motion = points[i+1] - points[i]
			q.collision_mask = 1
			check(space.cast_motion(q)[0] >= .999, "%s route leg %d meets furniture/wall" % [student.student_id,i])
	# Simulate several complete real physics loops, including seat transitions.
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 6
	var elapsed := 0.0
	var checkpoint := 30.0
	var seated_seen: Dictionary = {}
	var paired_chat_seen := false
	var nearest_pair := INF
	var hand_body_gap := INF
	for tick in 10000:
		await physics_frame
		elapsed += .05
		for student in life.students:
			check(student.global_position.x > -9.10 and student.global_position.x < -3.19, student.student_id + " left corridor")
			if student.seated:
				seated_seen[student.student_id] = true
			check(student.global_position.y > -.03 and student.global_position.y < .06, student.student_id + " floor")
			if student.blocked_time > 24:
				check(false, student.student_id + " stalled at " + str(student.global_position))
				break
		var a := life.students[1]
		var b := life.students[3]
		paired_chat_seen = paired_chat_seen or (a._chat_started and b._chat_started)
		if tick%2==0:
			for i in life.students.size():
				for j in range(i+1,life.students.size()):
					var first:=life.students[i]
					var second:=life.students[j]
					var separation:=Vector2(first.global_position.x-second.global_position.x,first.global_position.z-second.global_position.z).length()
					nearest_pair=minf(nearest_pair,separation)
					check(separation>.43,"student capsules overlap")
					if separation<1.3:
						for pair:Array in [[first,second],[second,first]]:
							var s:StudentCharacter=pair[0]
							var other:StudentCharacter=pair[1]
							var hip:=other.skeleton.global_transform*other._bone_pos(other.skeleton.find_bone("upperleg01.L"))
							var chest:=other.skeleton.global_transform*other._bone_pos(other.skeleton.find_bone("spine03"))
							for bone in ["lowerarm01.L","lowerarm01.R","wrist.L","wrist.R","finger3-1.L","finger3-1.R"]:
								var at:=s.skeleton.global_transform*s._bone_pos(s.skeleton.find_bone(bone))
								var gap:=at.distance_to(Geometry3D.get_closest_point_to_segment(at,hip,chest))-.20
								hand_body_gap=minf(hand_body_gap,gap)
								check(gap>-.025,"arm/hand enters another student's torso")
		if elapsed >= checkpoint:
			var states := []
			for student in life.students:
				states.append("%s:%s/%s step%d loops%d at%s" % [student.student_id,student.phase,student.activity,student.step_index,student.completed_loops,student.global_position])
			print("STUDENTS_PROGRESS t=", int(elapsed), " ", " | ".join(states))
			checkpoint += 30
		var all_looped := true
		for student in life.students:
			all_looped = all_looped and student.completed_loops >= 2
		if all_looped or failures > 0:
			break
	for student in life.students:
		check(student.completed_loops >= 2, student.student_id + " did not repeat routine twice")
		check(student.distance_walked > 12, student.student_id + " no real walking")
		check(seated_seen.has(student.student_id), student.student_id + " never sat on bench")
		print("STUDENT_RESULT ", student.student_id, " loops=", student.completed_loops, " metres=", snappedf(student.distance_walked,.1), " activities=", student.visits)
	check(paired_chat_seen, "students never met for paired chat")
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 60
	# Menu pause stops routines too, without losing their current activity.
	var paused_positions: Array[Vector3] = []
	for student in life.students:
		paused_positions.append(student.global_position)
	paused = true
	for tick in 10:
		await physics_frame
	for i in life.students.size():
		check(life.students[i].global_position.is_equal_approx(paused_positions[i]), "student moved while game paused")
	paused = false
	# Put the player on one short clear route: the walker waits rather than
	# pushing, then resumes; the player's capsule also collides with the NPC.
	for student in life.students:
		student.set_physics_process(false)
	var walker := life.students[0]
	check(not walker.seated, "yield-test walker should be standing after loop")
	walker.global_position = Vector3(-6.15,.02,-4)
	walker.rotation.y = PI
	walker.step_index = 0
	walker.start_routine(life, [life.stop(-6.15,-10)])
	walker.set_physics_process(true)
	player.global_position = Vector3(-6.15,.02,-4.8)
	for tick in 60:
		await physics_frame
	check(walker.blocked and walker.global_position.distance_to(Vector3(-6.15,.02,-4)) < .05, "walker did not wait for player")
	var held := walker.global_position
	player.global_position = Vector3(-5,.02,-4.8)
	for tick in 100:
		await physics_frame
	check(not walker.blocked and walker.global_position.distance_to(held) > .7, "walker did not resume after player moved")
	walker.set_physics_process(false)
	player.global_position = walker.global_position + Vector3(0,0,1.2)
	var npc_hit := false
	for tick in 15:
		var contact := player.move_and_collide(Vector3(0,0,-.1))
		if contact:
			npc_hit = contact.get_collider() == walker
			break
	check(npc_hit, "player can walk through a student")
	# Distant animation culling must still update a sitting/standing posture.
	var far_camera := Camera3D.new()
	map.add_child(far_camera)
	far_camera.global_position = Vector3(40,2,0)
	far_camera.make_current()
	var bob := life.students[2]
	bob.set_process(false)
	bob._last_pose_far = true
	bob._last_seat_pose = -1
	bob._seat_blend = 1
	bob._process(.06)
	check((bob.get_node("Visual") as Node3D).position.y < -.2, "distant student never adopted seated pose")
	bob._seat_blend = 0
	bob._process(.06)
	var sole_height:=bob._support.sole_heights()
	check(absf(minf(sole_height["L"],sole_height["R"])-.003)<.006, "distant standing feet are not grounded")
	print("STUDENT_CLEARANCE nearest_centres_m=",nearest_pair," arm_torso_proxy_gap_m=",hand_body_gap)
	if failures == 0:
		print("STUDENTS_VALID count=5 loops>=2 paired_chat=yes bench_seating=5 physical_routes=clear player_yield=pass pause=pass")
	else:
		print("STUDENTS_INVALID failures=",failures)
	quit(1 if failures else 0)
