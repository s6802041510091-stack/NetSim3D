class_name WallRack9U
extends StaticBody3D

## The 9U wall rack behind the teacher's desk in the computer room
## (600 W x 500 H x 450 D mm, mounted 1.5 m above the floor), built from simple
## boxes so it costs almost nothing on the Web.
## What is inside follows the story (GameFlow.configure_level sets `stage`):
##   EMPTY     Level 1 — nothing installed yet (the player only plans the devices)
##   INSTALLED Level 2 — Router + Switched Hub 24 Port, not cabled (Mission 2 round)
##   CABLED    Level 3-6 — installed and cabled correctly (Mission 2 round)
## Devices for INSTALLED/CABLED are added in the Mission 2 round; until then
## those stages look like EMPTY.

enum Stage { EMPTY, INSTALLED, CABLED }

const SIZE := Vector3(0.60, 0.50, 0.45)
const SHEET := 0.012

@export var stage: Stage = Stage.EMPTY:
	set(value):
		stage = value
		if is_inside_tree():
			_build()

var _visual: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	_build()


func _build() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var steel := _material(Color(0.13, 0.14, 0.16), 0.45, 0.55)
	var rail := _material(Color(0.55, 0.57, 0.6), 0.6, 0.4)
	var glass := _material(Color(0.55, 0.65, 0.72, 0.28), 0.1, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var half := SIZE * 0.5
	# Back, sides, top and bottom sheets (front is the glass door).
	_box(Vector3(SIZE.x, SIZE.y, SHEET), Vector3(0, 0, -half.z + SHEET * 0.5), steel, "Back")
	_box(Vector3(SHEET, SIZE.y, SIZE.z), Vector3(-half.x + SHEET * 0.5, 0, 0), steel, "SideLeft")
	_box(Vector3(SHEET, SIZE.y, SIZE.z), Vector3(half.x - SHEET * 0.5, 0, 0), steel, "SideRight")
	_box(Vector3(SIZE.x, SHEET, SIZE.z), Vector3(0, half.y - SHEET * 0.5, 0), steel, "Top")
	_box(Vector3(SIZE.x, SHEET, SIZE.z), Vector3(0, -half.y + SHEET * 0.5, 0), steel, "Bottom")
	# 19-inch mounting rails, front pair.
	for x in [-0.2325, 0.2325]:
		_box(Vector3(0.02, SIZE.y - 0.04, 0.02), Vector3(x, 0, half.z - 0.08), rail, "Rail")
	# Vent slots on the sides.
	for i in 5:
		var y := -0.12 + i * 0.06
		for side in [-1.0, 1.0]:
			_box(Vector3(0.004, 0.012, 0.22), Vector3(side * (half.x + 0.001), y, 0), _material(Color(0.05, 0.05, 0.06), 0.2, 0.8), "Vent")
	# Glass front door with a steel frame and a handle.
	_box(Vector3(SIZE.x - 0.04, SIZE.y - 0.04, 0.005), Vector3(0, 0, half.z - 0.003), glass, "DoorGlass")
	for y in [-half.y + 0.012, half.y - 0.012]:
		_box(Vector3(SIZE.x, 0.024, 0.012), Vector3(0, y, half.z - 0.006), steel, "DoorFrame")
	for x in [-half.x + 0.012, half.x - 0.012]:
		_box(Vector3(0.024, SIZE.y, 0.012), Vector3(x, 0, half.z - 0.006), steel, "DoorFrame")
	_box(Vector3(0.015, 0.09, 0.02), Vector3(half.x - 0.05, 0, half.z + 0.01), rail, "Handle")


func _box(size: Vector3, position: Vector3, material: Material, part_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position
	_visual.add_child(mesh)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m
