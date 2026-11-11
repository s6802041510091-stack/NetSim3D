@tool
extends Node3D

## The lower stairwell wall ends exactly at the entrance slab's top (y=0).
## Its hidden cap is coplanar with the walking surface, causing z-fighting.
## Recess the wall to the underside of the slab on a local mesh copy. This also
## avoids duplicate vertical faces along the slab edge. Collision stays intact.
## Also: the computer room door frame (see _fix_computer_room_door_frame) and
## two plants in the middle of the teachers' room (_move_teachers_room_plants).
func _ready() -> void:
	_fix_computer_room_door_frame()
	_move_teachers_room_plants()
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


## The computer room door jambs (Door_Frame_*_Jamb) sit inside the wall, so
## each jamb's inner face lies in the same plane as the edge of the wall
## opening (z = -7.95 and -8.95): the two faces flicker as stripes beside the
## door leaf. Moving each jamb 2 mm into the opening puts its face in front
## of the wall edge; the closed leaf still clears both jambs by 2 mm.
const JAMB_NUDGE := 0.002


func _fix_computer_room_door_frame() -> void:
	var front := get_node_or_null("Door_Frame_Front_Jamb") as Node3D
	var rear := get_node_or_null("Door_Frame_Rear_Jamb") as Node3D
	if front == null or rear == null:
		push_warning("Computer room door frame fix: jambs not found")
		return
	# The opening lies between the two jambs; each moves towards the other.
	var toward := (rear.global_position - front.global_position)
	toward.y = 0.0
	toward = toward.normalized() * JAMB_NUDGE
	front.global_position += toward
	rear.global_position -= toward


## Two potted plants stood in the open middle of the teachers' room, where
## people walk. Each goes beside a teacher's desk against the east wall, in
## the free space between the desk's end and the next cubicle partition:
## plant 1 beside STAFF-PC-02, plant 2 beside STAFF-PC-04. The plant's
## collider (built by map_collision.gd from the same name) moves with it.
const MOVED_PLANTS := {
	"TR_Plant_Center_1": Vector2(8.56, -22.95),
	"TR_Plant_Center_2": Vector2(8.56, -13.75),
}
const COLLISION_NODE := "../MapCollision"


func _move_teachers_room_plants() -> void:
	for plant_name: String in MOVED_PLANTS:
		var plant := get_node_or_null(plant_name) as MeshInstance3D
		if plant == null:
			push_warning("Teachers' room plant not found: " + plant_name)
			continue
		var centre := (plant.global_transform * plant.get_aabb()).get_center()
		var target: Vector2 = MOVED_PLANTS[plant_name]
		var shift := Vector3(target.x - centre.x, 0.0, target.y - centre.z)
		plant.global_position += shift
		# MapCollision comes after MapVisual in main.tscn: its colliders exist
		# only once its _ready has run.
		_move_collider.call_deferred(plant_name, shift)


func _move_collider(collider_name: String, shift: Vector3) -> void:
	var collider := get_node_or_null(NodePath(COLLISION_NODE + "/" + collider_name)) as Node3D
	if collider:
		collider.position += shift
