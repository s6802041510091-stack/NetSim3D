class_name Mission02DeskLayout
extends Node3D

## What lies on the spare desk around the crimping spot, at real size (the
## close-up cable end, CrimpBench, is drawn 3x and only shows while seated):
##   - a blueprint-style work mat (blue, 1 cm grid, no colour order printed)
##   - the two cables taken from the storage-room boxes, each a coil with a
##     paper tag ("จุดที่ 1 · Straight-Through") and a loose end
##   - the crimping kit from the drawer: RJ45 heads, stripper, crimper, tester
## Local axes as CrimpStation: the player sits on -X, +Z is their right.
## The desk top spans x -0.255..0.595 and z -0.95..0.95 from the station.

const FONT := preload("res://assets/fonts/Sarabun-Bold.ttf")
const TOOL_CATALOG := preload("res://scripts/held_item_catalog.gd")
const MAT_SIZE := Vector2(0.6, 0.5) # x (depth) by z (width), metres
const MAT_CENTER := Vector3(0.07, 0.0, 0.0)
const MAT_THICKNESS := 0.002
## UTP Cat6 is about 6 mm; drawn a little thicker so it reads from standing height.
const CABLE_RADIUS := 0.0042
const CABLE_COLOR := Color(0.62, 0.72, 0.84) # same jacket colour as the close-up
const COIL_RADIUS := 0.14
const COIL_LOOPS := 4
## point -> coil centre; the loose end runs towards the mat.
const COILS := {1: Vector3(0.25, 0.0, -0.45), 2: Vector3(0.25, 0.0, -0.77)}
## id -> [position, yaw degrees]
const TOOLS := {
	"cable_stripper": [Vector3(0.02, MAT_THICKNESS, 0.36), 80.0],
	"crimping_tool": [Vector3(0.2, 0.0, 0.42), 95.0],
	"cable_tester": [Vector3(0.36, 0.0, 0.66), 90.0],
}
const HEADS_AT := Vector3(-0.1, 0.0, 0.5)

var mat: MeshInstance3D
var _cables := {} # point -> Node3D
var _tools := {} # id -> Node3D


func _ready() -> void:
	name = "DeskLayout"
	mat = _make_mat()
	add_child(mat)


## Puts the two cables (with their tags) and the kit on the desk.
## `types`: connection point -> cable type taken from the storage boxes.
func lay_out(types: Dictionary) -> void:
	for point: int in COILS:
		if _cables.has(point):
			continue
		var type: String = types.get(point, Mission02State.STRAIGHT)
		var coil := _make_coil(point, type)
		add_child(coil)
		_cables[point] = coil
	if _tools.is_empty():
		for id: String in TOOLS:
			var tool: Node3D = (TOOL_CATALOG.TOOLS[id]["scene"] as PackedScene).instantiate()
			tool.name = "Tool_" + id
			tool.position = TOOLS[id][0]
			tool.rotation_degrees.y = TOOLS[id][1]
			add_child(tool)
			_tools[id] = tool
		var heads := _make_heads()
		add_child(heads)
		_tools["rj45_heads"] = heads


func cables_shown() -> bool:
	return not _cables.is_empty() and (_cables.values()[0] as Node3D).visible


## The cables leave the desk when they go to the rack.
func set_cables_visible(on: bool) -> void:
	for coil: Node3D in _cables.values():
		coil.visible = on


## The tester on the side of the desk (hidden while the station shows its own).
func set_side_tester_visible(on: bool) -> void:
	if _tools.has("cable_tester"):
		(_tools["cable_tester"] as Node3D).visible = on


func tool_ids() -> PackedStringArray:
	return PackedStringArray(_tools.keys())


# ------------------------------------------------------------------ pieces

## A thin blue sheet with a white 1 cm grid (bold every 5 cm), a ruler edge
## and a title block. Drawn into one small texture, one mesh.
func _make_mat() -> MeshInstance3D:
	var px_per_cm := 8
	var w := int(MAT_SIZE.x * 100.0) * px_per_cm # along X (depth)
	var h := int(MAT_SIZE.y * 100.0) * px_per_cm # along Z (width)
	var image := Image.create(w, h, false, Image.FORMAT_RGB8)
	var blue := Color(0.1, 0.3, 0.58)
	image.fill(blue)
	var fine := blue.lerp(Color.WHITE, 0.22)
	var bold := blue.lerp(Color.WHITE, 0.55)
	for cm in range(0, int(MAT_SIZE.x * 100.0) + 1):
		var x := mini(cm * px_per_cm, w - 1)
		image.fill_rect(Rect2i(x, 0, 2 if cm % 5 == 0 else 1, h), bold if cm % 5 == 0 else fine)
	for cm in range(0, int(MAT_SIZE.y * 100.0) + 1):
		var y := mini(cm * px_per_cm, h - 1)
		image.fill_rect(Rect2i(0, y, w, 2 if cm % 5 == 0 else 1), bold if cm % 5 == 0 else fine)
	# A white border like a printed sheet.
	for r in [Rect2i(0, 0, w, 3), Rect2i(0, h - 3, w, 3), Rect2i(0, 0, 3, h), Rect2i(w - 3, 0, 3, h)]:
		image.fill_rect(r, Color(0.92, 0.95, 1.0))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	# A thin dark sheet with the printed grid on a plane on top (a plane maps
	# the texture's width along X and its height along Z, so cells stay square).
	var mesh := MeshInstance3D.new()
	mesh.name = "BlueprintMat"
	var box := BoxMesh.new()
	box.size = Vector3(MAT_SIZE.x, MAT_THICKNESS, MAT_SIZE.y)
	mesh.mesh = box
	var edge := StandardMaterial3D.new()
	edge.albedo_color = blue.darkened(0.3)
	mesh.material_override = edge
	mesh.position = MAT_CENTER + Vector3(0, MAT_THICKNESS * 0.5, 0)
	var top := MeshInstance3D.new()
	top.name = "Print"
	var plane := PlaneMesh.new()
	plane.size = MAT_SIZE
	top.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.85
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	top.material_override = material
	top.position.y = MAT_THICKNESS * 0.5 + 0.0002
	mesh.add_child(top)
	# Title along the far edge, reading left to right for the seated player.
	var title := _flat_label("CABLE WORK MAT  ·  1 ช่อง = 1 cm", Vector3(MAT_SIZE.x * 0.5 - 0.025, MAT_THICKNESS * 0.5 + 0.0006, 0.0), 0.0002, Color(0.92, 0.95, 1.0))
	mesh.add_child(title)
	return mesh


## Stacked loops of real-size cable, a loose end towards the mat and a
## paper tag with the point and the type written on it.
func _make_coil(point: int, type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Cable%d" % point
	root.position = COILS[point]
	var material := StandardMaterial3D.new()
	material.albedo_color = CABLE_COLOR
	material.roughness = 0.55
	for i in COIL_LOOPS:
		var loop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var r := COIL_RADIUS - i * 0.007
		torus.inner_radius = r - CABLE_RADIUS
		torus.outer_radius = r + CABLE_RADIUS
		torus.rings = 40
		torus.ring_segments = 8
		loop.mesh = torus
		loop.material_override = material
		loop.position = Vector3(i * 0.004, CABLE_RADIUS + i * CABLE_RADIUS * 1.6, i * 0.003)
		root.add_child(loop)
	# The loose end leaves the coil on the player's side and lies towards the mat.
	var y := CABLE_RADIUS
	var start := Vector3(-COIL_RADIUS * 0.7, y * 2.0, COIL_RADIUS * 0.7)
	var end_at := Vector3(-0.3, y, 0.18 if point == 1 else 0.3)
	root.add_child(CableBuilder.build([start, start + Vector3(-0.05, -y, 0.06), end_at * 0.6 + start * 0.4 + Vector3(0, 0, 0.02),
		end_at], CABLE_COLOR, "LooseEnd", CABLE_RADIUS))
	# Paper tag tied near the start of the loose end.
	var info: Array = Mission02CableBox.TYPES[type]
	var tag := Node3D.new()
	tag.name = "Tag"
	tag.position = start + Vector3(-0.03, 0.0035, 0.05)
	tag.rotation_degrees.y = -20.0
	root.add_child(tag)
	_mesh(tag, Vector3(0.065, 0.001, 0.12), Vector3.ZERO, Color(0.97, 0.95, 0.86))
	_mesh(tag, Vector3(0.01, 0.0012, 0.12), Vector3(0.0275, 0, 0), info[3])
	tag.add_child(_flat_label("สายจุดที่ %d" % point, Vector3(0.008, 0.0008, 0.0), 0.00024, Color(0.12, 0.14, 0.2)))
	tag.add_child(_flat_label(String(info[0]), Vector3(-0.016, 0.0008, 0.0), 0.00018, Color(0.3, 0.33, 0.4)))
	return root


## A small clear box of RJ45 heads.
func _make_heads() -> Node3D:
	var root := Node3D.new()
	root.name = "RJ45Heads"
	root.position = HEADS_AT
	var clear := Color(0.85, 0.9, 0.95, 0.4)
	_mesh(root, Vector3(0.1, 0.035, 0.07), Vector3(0, 0.0175, 0), clear, true)
	for i in 6:
		_mesh(root, Vector3(0.0118, 0.008, 0.021), Vector3(-0.03 + (i % 3) * 0.03, 0.006, -0.015 + (i / 3) * 0.03), Color(0.9, 0.93, 0.96, 0.8), true)
	root.add_child(_flat_label("RJ45", Vector3(0, 0.0355, 0), 0.0004, Color(0.15, 0.18, 0.25)))
	return root


func _mesh(parent: Node3D, size: Vector3, at: Vector3, color: Color, see_through := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


## Text lying flat, reading left to right for the seated player (right = +Z).
func _flat_label(text: String, at: Vector3, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 64
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = color
	label.position = at
	label.rotation_degrees = Vector3(-90, -90, 0)
	return label
