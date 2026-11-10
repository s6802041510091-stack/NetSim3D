class_name Mission02CableBox
extends StaticBody3D

## A 305 m pull box of UTP Cat6 cable in the storage room, labelled with the
## cable it is meant for (Straight-Through B-B or Crossover A-B). Look at it
## and press F to take a cable from it for one of the connection points
## (Mission02CableBoxPanel). Interaction layer 8, like the other props.

signal used(player: Node, type: String)

const COLLISION_LAYER := 8
const SIZE := Vector3(0.34, 0.34, 0.34)
const CARDBOARD := Color(0.66, 0.5, 0.32)
const FONT := preload("res://assets/fonts/Sarabun-Bold.ttf")

## type -> [label title, end 1, end 2, stripe colour]
const TYPES := {
	Mission02State.STRAIGHT: ["Straight-Through", "T568B", "T568B", Color(0.16, 0.47, 0.86)],
	Mission02State.CROSSOVER: ["Crossover", "T568A", "T568B", Color(0.88, 0.45, 0.12)],
}

@export var type := Mission02State.STRAIGHT
var prompt := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_meta(&"interactable", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.02, 0.12, 0.02)
	shape.shape = box
	shape.position = Vector3(0, SIZE.y * 0.5 + 0.05, 0)
	add_child(shape)
	_build()


func title() -> String:
	return String(TYPES[type][0]) + " Cable"


func set_prompt(text: String) -> void:
	prompt = text
	collision_layer = COLLISION_LAYER if text != "" else 0


func get_prompt_text() -> String:
	return prompt


func use(player: Node) -> void:
	if prompt != "":
		used.emit(player, type)


## The box faces +X: the label is on that side.
func _build() -> void:
	var info: Array = TYPES[type]
	var stripe: Color = info[3]
	_mesh(SIZE, Vector3(0, SIZE.y * 0.5, 0), CARDBOARD)
	# Packing tape across the top and a coloured band around the box.
	_mesh(Vector3(SIZE.x + 0.004, 0.003, 0.06), Vector3(0, SIZE.y + 0.0015, 0), Color(0.75, 0.62, 0.38))
	_mesh(Vector3(SIZE.x + 0.004, 0.04, SIZE.z + 0.004), Vector3(0, SIZE.y - 0.03, 0), stripe)
	# Front label plate (+X side).
	var front := SIZE.x * 0.5 + 0.002
	_mesh(Vector3(0.003, 0.17, 0.31), Vector3(front, 0.14, 0), Color(0.97, 0.97, 0.94))
	_mesh(Vector3(0.004, 0.035, 0.3), Vector3(front + 0.0005, 0.2075, 0), stripe)
	_label("UTP Cat6 · 305 m", Vector3(front + 0.003, 0.2075, 0), 0.00042, Color.WHITE)
	_label(String(info[0]), Vector3(front + 0.003, 0.155, 0), 0.00062, Color(0.1, 0.13, 0.2))
	_label("ปลาย 1 %s  ·  ปลาย 2 %s" % [info[1], info[2]], Vector3(front + 0.003, 0.09, 0), 0.0003, Color(0.25, 0.29, 0.36))
	# The cable end coming out of the pull hole, in the band's colour family.
	add_child(CableBuilder.build([Vector3(-0.04, SIZE.y, -0.08), Vector3(-0.04, SIZE.y + 0.05, -0.08),
		Vector3(-0.0, SIZE.y + 0.07, -0.1), Vector3(0.06, SIZE.y + 0.03, -0.12), Vector3(0.1, SIZE.y + 0.004, -0.12)],
		Color(0.35, 0.55, 0.85), "CableEnd", 0.0035))


func _mesh(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	return mesh


func _label(text: String, at: Vector3, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 64
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = color
	label.position = at
	label.rotation_degrees.y = 90.0 # faces +X
	add_child(label)
	return label
