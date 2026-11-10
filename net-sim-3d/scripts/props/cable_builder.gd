class_name CableBuilder
extends RefCounted

## Draws a LAN cable through a list of points as thin cylinders with round
## joints (cheap enough for the Web: one material, a few meshes per bend).


## Returns a Node3D holding the cable; `points` are in the parent's space.
static func build(points: Array, color: Color, cable_name: String = "Cable", radius: float = 0.0032) -> Node3D:
	var holder := Node3D.new()
	holder.name = cable_name
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	var segment_mesh_cache := {}
	var joint := SphereMesh.new()
	joint.radius = radius
	joint.height = radius * 2.0
	joint.radial_segments = 8
	joint.rings = 4
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.0005:
			continue
		var key := snappedf(length, 0.0001)
		if not segment_mesh_cache.has(key):
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = radius
			cylinder.bottom_radius = radius
			cylinder.height = length
			cylinder.radial_segments = 8
			cylinder.rings = 1
			segment_mesh_cache[key] = cylinder
		var segment := MeshInstance3D.new()
		segment.mesh = segment_mesh_cache[key]
		segment.material_override = material
		var up := (b - a) / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		segment.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
		holder.add_child(segment)
		if i > 0:
			var ball := MeshInstance3D.new()
			ball.mesh = joint
			ball.material_override = material
			ball.position = a
			holder.add_child(ball)
	return holder
