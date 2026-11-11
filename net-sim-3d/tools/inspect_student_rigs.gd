extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var life: StudentLife = map.get_node("CorridorStudents")
	for s in life.students:
		s.process_mode = Node.PROCESS_MODE_DISABLED
		s._apply_pose(s._rest_pose)
		var sk := s.skeleton
		print("RIG ",s.student_id," global=",sk.global_transform)
		for name in ["upperleg01.L","lowerleg01.L","foot.L","upperarm01.L","lowerarm01.L","wrist.L"]:
			var b := sk.find_bone(name)
			var before := sk.get_bone_global_pose(b)
			var rest := sk.get_bone_rest(b)
			s._rotate_bone(b,Vector3.UP,0)
			print("BONE ",name," rest_angle=",rad_to_deg(rest.basis.get_rotation_quaternion().get_angle())," zero_rotation_drift=",rad_to_deg(before.basis.get_rotation_quaternion().angle_to(sk.get_bone_global_pose(b).basis.get_rotation_quaternion())))
			s._apply_pose(s._rest_pose)
		for mesh: MeshInstance3D in s.get_node("Visual").find_children("*","MeshInstance3D",true,false):
			if not mesh.mesh or mesh.skin == null:
				continue
			var bind := mesh.skin
			var vertices := 0
			var max_error := 0.0
			var mesh_error := 0.0
			for surface in mesh.mesh.get_surface_count():
				var a := mesh.mesh.surface_get_arrays(surface)
				var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				vertices += vs.size()
				var joints: PackedInt32Array = a[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
				if joints.is_empty():continue
				var stride := joints.size()/vs.size()
				for i in range(0,vs.size(),maxi(1,vs.size()/50)):
					var posed := Vector3.ZERO
					for k in stride:
						var ji := joints[i*stride+k]
						var bone := bind.get_bind_bone(ji)
						if bone < 0:bone=sk.find_bone(bind.get_bind_name(ji))
						posed += (sk.get_bone_global_pose(bone)*bind.get_bind_pose(ji)*vs[i])*weights[i*stride+k]
					max_error=maxf(max_error,(sk.global_transform*posed).distance_to(mesh.global_transform*vs[i]))
					mesh_error=maxf(mesh_error,(mesh.global_transform*posed).distance_to(mesh.global_transform*vs[i]))
			if "Shoes" in mesh.name:
				print("DETAIL mesh_global=",mesh.global_transform," bone0_pose=",sk.get_bone_global_pose(0)," bind0=",bind.get_bind_pose(0))
			print("MESH ",mesh.name," vertices=",vertices," skel_error=",max_error," mesh_error=",mesh_error)
	quit()
