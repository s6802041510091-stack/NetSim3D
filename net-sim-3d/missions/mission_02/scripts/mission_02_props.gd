class_name Mission02Props
extends Node3D

## Level 2 only: what the player needs on the spare desk in the IT Support room
## (UTP Cat6 cable, RJ45 heads, cable stripper, crimping tool, LAN cable
## tester) and the spot where the crimping happens. GameFlow adds it for
## Level 2; the Mission 2 controller makes the items pickable.

const TOOL_CATALOG := preload("res://scripts/held_item_catalog.gd")

## Spare desk: x -13.995..-13.145 (player sits on the -x side), z -39.38..-37.48.
const DESK_TOP := 0.758
const DESK_FRONT_X := -13.995
const DESK_CENTER := Vector3(-13.57, DESK_TOP, -38.43)

## item id -> [title, position on the desk, yaw degrees]
const ITEMS := {
	"utp_cat6": ["สาย UTP Cat6", Vector3(-13.40, DESK_TOP, -39.12), 20.0],
	"rj45_heads": ["หัว RJ45", Vector3(-13.78, DESK_TOP, -38.95), 0.0],
	"cable_stripper": ["คีมปอกสาย", Vector3(-13.80, DESK_TOP, -38.62), 80.0],
	"crimping_tool": ["คีมย้ำสาย LAN", Vector3(-13.80, DESK_TOP, -38.20), 95.0],
	"cable_tester": ["เครื่องทดสอบสาย LAN", Vector3(-13.62, DESK_TOP, -37.80), 90.0],
}

var items := {} # id -> PickupItem
## Where the player sits to crimp (the camera zooms here later).
var crimp_station: Node3D


func _ready() -> void:
	name = "Mission02Props"
	for id: String in ITEMS:
		var entry: Array = ITEMS[id]
		var item := PickupItem.new()
		item.name = "Pickup_" + id
		item.item_id = id
		item.title = entry[0]
		item.position = entry[1]
		item.rotation_degrees.y = entry[2]
		item.add_child(_visual_for(id))
		add_child(item)
		items[id] = item
	crimp_station = Node3D.new()
	crimp_station.name = "CrimpStation"
	crimp_station.position = DESK_CENTER
	add_child(crimp_station)


## Lets the player pick the items up (after the briefing).
func set_items_available(on: bool) -> void:
	for item: PickupItem in items.values():
		item.available = on


func missing_items() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in items:
		if not (items[id] as PickupItem).taken:
			out.append(String(ITEMS[id][0]))
	return out


func _visual_for(id: String) -> Node3D:
	if TOOL_CATALOG.TOOLS.has(id):
		var tool: Node3D = (TOOL_CATALOG.TOOLS[id]["scene"] as PackedScene).instantiate()
		tool.name = "Visual"
		return tool
	var root := Node3D.new()
	root.name = "Visual"
	match id:
		"utp_cat6":
			# A pull box of Cat6 cable with the cable end coming out of the top.
			_box(root, Vector3(0.2, 0.2, 0.2), Vector3(0, 0.1, 0), Color(0.22, 0.38, 0.62))
			_box(root, Vector3(0.12, 0.06, 0.002), Vector3(0, 0.13, 0.101), Color(0.92, 0.93, 0.95))
			_label(root, "UTP Cat6", Vector3(0, 0.13, 0.103), 0.0006, Color(0.1, 0.2, 0.4))
			root.add_child(CableBuilder.build([Vector3(0.03, 0.2, 0), Vector3(0.03, 0.24, 0.0), Vector3(0.05, 0.25, 0.05),
				Vector3(0.06, 0.2, 0.13), Vector3(0.06, 0.004, 0.2), Vector3(0.0, 0.004, 0.26)], Color(0.35, 0.55, 0.85), "CableEnd", 0.003))
		"rj45_heads":
			# A small clear box of RJ45 heads.
			var clear := Color(0.85, 0.9, 0.95, 0.4)
			_box(root, Vector3(0.1, 0.035, 0.07), Vector3(0, 0.0175, 0), clear, true)
			for i in 6:
				_box(root, Vector3(0.0118, 0.008, 0.021), Vector3(-0.03 + (i % 3) * 0.03, 0.006, -0.015 + (i / 3) * 0.03), Color(0.9, 0.93, 0.96, 0.8), true)
			_label(root, "RJ45", Vector3(0, 0.037, 0), 0.0004, Color(0.15, 0.18, 0.25), true)
	return root


func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color, see_through := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)


func _label(parent: Node3D, text: String, position: Vector3, pixel: float, color: Color, on_top := false) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.font_size = 64
	label.outline_size = 0
	label.modulate = color
	label.position = position
	if on_top:
		label.rotation_degrees.x = -90.0
	parent.add_child(label)
