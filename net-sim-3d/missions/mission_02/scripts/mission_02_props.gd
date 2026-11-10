class_name Mission02Props
extends Node3D

## Level 2 only. In the storage room (ห้องเก็บอุปกรณ์, the south-west corner of
## the IT Support room): two pull boxes of UTP Cat6 on the drawer island, one
## labelled Straight-Through and one Crossover, and the "ชุดเข้าหัวสาย" drawer
## cabinet on the south wall (a window lists what is inside). On the spare
## desk in the IT Support room: the spot where the crimping happens. GameFlow
## adds this node for Level 2; the Mission 2 controller turns the parts on.

## Spare desk: x -13.995..-13.145 (player sits on the -x side), z -39.38..-37.48.
const DESK_TOP := 0.758
const DESK_FRONT_X := -13.995
const DESK_CENTER := Vector3(-13.57, DESK_TOP, -38.43)

## Storage room drawer island: centre (-17.4, -33.75), worktop at 0.88 m,
## x -18.72..-16.08, z -34.22..-33.28. The boxes stand at its east end, their
## labels towards the door (the room's door is on the east wall).
const ISLAND_TOP := 0.88
const CABLE_BOXES := {
	Mission02State.STRAIGHT: Vector3(-16.32, ISLAND_TOP, -33.52),
	Mission02State.CROSSOVER: Vector3(-16.32, ISLAND_TOP, -33.98),
}
## The decorative tools and cable roll on the island (map model) would look
## like the mission's items, so Level 2 hides them.
const ISLAND_DECOR := "ST_Island_Items"
## "ชุดเข้าหัวสาย" parts-drawer cabinet (ST_Parts_Drawers_4): 0.9 m wide, 1.8 m
## tall, its front at z -31.11, facing -z (into the room).
const DRAWER_FRONT := Vector3(-14.66, 0.0, -31.11)

var cable_boxes := {} # type -> Mission02CableBox
## Look at the drawer cabinet and press F (prompt set by the controller).
var drawer_spot: InteractSpot
## Where the player sits to crimp (F at the desk; the camera zooms to its bench).
var crimp_station: CrimpStation


func _ready() -> void:
	name = "Mission02Props"
	for type: String in CABLE_BOXES:
		var box := Mission02CableBox.new()
		box.name = "CableBox_" + type
		box.type = type
		box.position = CABLE_BOXES[type]
		add_child(box)
		cable_boxes[type] = box
	drawer_spot = InteractSpot.new()
	drawer_spot.name = "ToolDrawer"
	drawer_spot.size = Vector3(0.9, 1.5, 0.12)
	drawer_spot.position = DRAWER_FRONT + Vector3(0, 0.95, -0.04)
	add_child(drawer_spot)
	_mark_drawer()
	crimp_station = CrimpStation.new()
	crimp_station.name = "CrimpStation"
	crimp_station.position = Vector3(-13.74, DESK_TOP, -38.43)
	add_child(crimp_station)
	_hide_island_decor.call_deferred()


## A drawer of the cabinet pulled out a little, with a bright label, so the
## player can tell which of the many small drawers is meant.
func _mark_drawer() -> void:
	var root := Node3D.new()
	root.name = "OpenDrawer"
	root.position = DRAWER_FRONT + Vector3(0.1125, 1.02, 0.0)
	add_child(root)
	var steel := Color(0.7, 0.72, 0.72)
	_box(root, Vector3(0.2, 0.13, 0.012), Vector3(0, 0, -0.1), steel)          # drawer front, pulled 10 cm
	_box(root, Vector3(0.19, 0.11, 0.1), Vector3(0, -0.005, -0.045), steel.darkened(0.25)) # its sides
	_box(root, Vector3(0.09, 0.012, 0.02), Vector3(0, 0.03, -0.112), Color(0.8, 0.81, 0.83))
	_box(root, Vector3(0.17, 0.045, 0.003), Vector3(0, -0.025, -0.1075), Color(0.98, 0.84, 0.25))
	var label := Label3D.new()
	label.text = "ชุดเข้าหัวสาย"
	label.font = preload("res://assets/fonts/Sarabun-Bold.ttf")
	label.font_size = 64
	label.pixel_size = 0.00042
	label.outline_size = 0
	label.modulate = Color(0.12, 0.14, 0.2)
	label.position = Vector3(0, -0.025, -0.1095)
	label.rotation_degrees.y = 180.0 # faces -z, into the room
	root.add_child(label)


func _hide_island_decor() -> void:
	var visual := get_parent().get_node_or_null("MapVisual") if get_parent() else null
	var decor := visual.find_child(ISLAND_DECOR, true, false) if visual else null
	if decor is Node3D:
		(decor as Node3D).visible = false


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	material.metallic = 0.3
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
