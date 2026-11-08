extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	var failures := 0
	for point in [Vector3(-6, 0, -17), Vector3(2, 0, 0)]:
		for node in world.get_node("ExteriorTown/CampusAndGround").find_children("*", "MeshInstance3D", true, false):
			var faces: PackedVector3Array = node.mesh.get_faces()
			for i in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(point + Vector3.UP, point - Vector3(0, 0.001, 0), node.global_transform * faces[i], node.global_transform * faces[i+1], node.global_transform * faces[i+2])
				if hit != null:
					print("COVERING_FLOOR ", node.name, " ", hit)
					failures += 1
	for name in ["Corridor_Floor", "Floor_Slab_150mm"]:
		var node := world.get_node("MapVisual").find_child(name, true, false) as MeshInstance3D
		if node == null:
			failures += 1
			continue
		var material := node.get_active_material(0) as StandardMaterial3D
		var textured := material != null and material.albedo_texture != null
		print("FLOOR_TEXTURE ", name, " ", textured)
		if not textured:
			failures += 1
	print("FLOOR_VISIBILITY_VALIDATION failures=", failures)
	quit(1 if failures else 0)
