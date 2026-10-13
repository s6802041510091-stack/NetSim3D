@tool
extends StaticBody3D

## Collision is authored from the Blender source's major architectural pieces.
## Decorative computer parts, wires and lettering remain visual-only.
const COLLISION_DATA := "res://data/map_collisions.json"


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLISION_DATA))
	if not parsed is Array:
		push_error("Cannot load map collision data: " + COLLISION_DATA)
		return

	for entry: Dictionary in parsed:
		# Door leaves are exported in their open pose; InteractiveDoor nodes in
		# main.tscn give each leaf its own moving collider instead.
		if entry.get("kind", "") == "door":
			continue
		var collision := CollisionShape3D.new()
		collision.name = entry["name"]
		if entry.has("faces"):
			var points := PackedVector3Array()
			var coordinates: Array = entry["faces"]
			for i in range(0, coordinates.size(), 3):
				points.append(Vector3(coordinates[i], coordinates[i + 1], coordinates[i + 2]))
			var concave := ConcavePolygonShape3D.new()
			concave.set_faces(points)
			collision.shape = concave
		else:
			var dimensions: Array = entry["size"]
			var center: Array = entry["center"]
			var box := BoxShape3D.new()
			box.size = Vector3(dimensions[0], dimensions[1], dimensions[2])
			collision.shape = box
			collision.position = Vector3(center[0], center[1], center[2])
		add_child(collision)
