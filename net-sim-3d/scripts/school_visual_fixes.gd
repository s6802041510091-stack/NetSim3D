@tool
extends Node3D

## The lower stairwell wall ends exactly at the entrance slab's top (y=0).
## Its hidden cap is coplanar with the walking surface, causing z-fighting.
## Recess the wall to the underside of the slab on a local mesh copy. This also
## avoids duplicate vertical faces along the slab edge. Collision stays intact.
func _ready() -> void:
	var wall := get_node_or_null("StairShell_Lower_EastWall") as MeshInstance3D
	var threshold := get_node_or_null("StairShell_Entrance_Threshold") as MeshInstance3D
	if wall == null or threshold == null:
		push_warning("Stair entrance visual fix: wall or threshold was not found")
		return
	var threshold_bounds := threshold.transform * threshold.get_aabb()
	var wall_top := threshold_bounds.position.y - 0.002
	var corrected := ArrayMesh.new()
	var changed := false
	for surface in range(wall.mesh.get_surface_count()):
		var arrays := wall.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var inverse := wall.transform.affine_inverse()
		for i in range(vertices.size()):
			var point: Vector3 = wall.transform * vertices[i]
			if point.y > wall_top:
				point.y = wall_top
				vertices[i] = inverse * point
				changed = true
		arrays[Mesh.ARRAY_VERTEX] = vertices
		corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		corrected.surface_set_material(corrected.get_surface_count() - 1, wall.mesh.surface_get_material(surface))
	if changed:
		wall.mesh = corrected
