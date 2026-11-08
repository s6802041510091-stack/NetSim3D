extends SceneTree

## Export the actual runtime meshes (including imported GLB transforms) for an
## independent triangle-intersection check in Blender. --baseline feeds fitting.
func _initialize() -> void:
	call_deferred("run")

func geometry(node: Node3D, reference: Node3D) -> Dictionary:
	var vertices := []
	var triangles := []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var transform: Transform3D = reference.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface)
			var start := vertices.size()
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = transform * vertex
				vertices.append([point.x, -point.z, point.y])
			var indices = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				triangles.append([start + indices[i], start + indices[i+1], start + indices[i+2]])
	return {"vertices": vertices, "triangles": triangles}

func run() -> void:
	var player = load("res://scenes/it_support_player.tscn").instantiate()
	root.add_child(player)
	var presentation = player.get_node("Presentation")
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var result := {}
	for id in presentation.HELD_ITEMS.TOOLS:
		presentation.preview_item(id)
		if baseline:
			var delta: Vector3 = presentation.HELD_ITEMS.TOOLS[id].get("fit_offset", Vector3.ZERO)
			presentation.held_model.position -= presentation.gripping_arm.basis * Vector3(delta.x, delta.z, -delta.y)
		result[id] = geometry(presentation.held_model, presentation.gripping_arm)
		if not baseline:
			result[id]["hand"] = geometry(presentation.gripping_arm, presentation.gripping_arm)
	var folder := ProjectSettings.globalize_path("res://../tmp/avatar_arm_export")
	DirAccess.make_dir_recursive_absolute(folder)
	var filename := "grip_geometry.json" if baseline else "grip_runtime_geometry.json"
	var file := FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("EXPORTED_GRIPS ", result.size(), " ", filename)
	quit()
