class_name CrimpBench
extends Node3D

## The cable end the player works on at the crimping desk, drawn 3x real size
## so the eight colours read clearly in the close-up. Local axes: the cable
## comes from -X (the player) and its end points to +X; +Z is the right side
## of the screen, so pin 1 sits on the left (-Z), as when looking at an RJ45
## head with the clip down and the cable towards you.
## show_state() rebuilds the end for each step; play_tool() slides a tool in.

enum Look { WHOLE, CUT, STRIPPED, UNTWISTED, ARRANGED, TRIMMED, INSERTED, CRIMPED }

const TOOL_CATALOG := preload("res://scripts/held_item_catalog.gd")
const JACKET_RADIUS := 0.009
const JACKET_COLOR := Color(0.62, 0.72, 0.84)
const JACKET_END := -0.06 # where the jacket stops after stripping
const WIRE_WIDTH := 0.0042
const WIRE_HEIGHT := 0.0036
const PIN_PITCH := 0.0047
const TRIMMED_LENGTH := 0.039 # 13 mm x 3
const HEAD_SIZE := Vector3(0.063, 0.024, 0.036) # 21 x 8 x 12 mm, x3
## Natural pair order coming out of the jacket (before arranging).
const PAIRS := [["white_orange", "orange"], ["white_green", "green"], ["white_blue", "blue"], ["white_brown", "brown"]]

var look := Look.WHOLE
var order: Array = [] # wire ids by pin (may hold "" for empty pins)
var _parts: Node3D
var _materials := {}


func _ready() -> void:
	show_state(Look.WHOLE)


## Camera pose for the close-up: above and behind the end, the cable on the
## left part of the screen (the step panel covers the right).
func view_transform() -> Transform3D:
	var eye := global_transform * Vector3(-0.1, 0.085, 0.05)
	var target := global_transform * Vector3(-0.03, 0.0, 0.05)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


func show_state(next: Look, wire_order: Array = []) -> void:
	look = next
	order = wire_order.duplicate()
	if _parts:
		_parts.queue_free()
	_parts = Node3D.new()
	_parts.name = "CableEnd"
	add_child(_parts)
	match look:
		Look.WHOLE:
			_jacket(-0.2, 0.12)
		Look.CUT:
			_jacket(-0.2, 0.0)
		Look.STRIPPED:
			_jacket(-0.2, JACKET_END)
			_pairs()
		Look.UNTWISTED:
			_jacket(-0.2, JACKET_END)
			_untwisted()
		Look.ARRANGED:
			_jacket(-0.2, JACKET_END)
			_flat(order, 0.075)
		Look.TRIMMED:
			_jacket(-0.2, JACKET_END)
			_flat(order, TRIMMED_LENGTH)
		Look.INSERTED, Look.CRIMPED:
			_jacket(-0.2, JACKET_END)
			_flat(order, TRIMMED_LENGTH)
			_head(look == Look.CRIMPED)


## Slides tool `id` (from the tool catalog) onto the end and back out.
func play_tool(id: String, duration := 0.7) -> void:
	if not TOOL_CATALOG.TOOLS.has(id):
		return
	var tool: Node3D = (TOOL_CATALOG.TOOLS[id]["scene"] as PackedScene).instantiate()
	tool.scale = Vector3.ONE * 1.4
	tool.rotation_degrees = Vector3(0, 90, 0)
	var at := Vector3(JACKET_END + 0.02, 0.05, 0.0)
	tool.position = at + Vector3(0, 0.12, 0.12)
	add_child(tool)
	var tween := create_tween()
	tween.tween_property(tool, "position", at, duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration * 0.2)
	tween.tween_property(tool, "position", at + Vector3(0, 0.12, 0.12), duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	tool.queue_free()


# ---------------------------------------------------------------- pieces

func _jacket(from_x: float, to_x: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Jacket"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = JACKET_RADIUS
	cylinder.bottom_radius = JACKET_RADIUS
	cylinder.height = to_x - from_x
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	mesh.material_override = _material("jacket", JACKET_COLOR)
	mesh.rotation_degrees = Vector3(0, 0, 90)
	mesh.position = Vector3((from_x + to_x) * 0.5, 0, 0)
	_parts.add_child(mesh)


## Four twisted pairs: each pair is two wires crossing a few times.
func _pairs() -> void:
	for p in PAIRS.size():
		var center_z := (p - 1.5) * 0.0075
		var length := 0.06
		var steps := 4
		for s in steps:
			var x0 := JACKET_END + s * length / steps
			for w in 2:
				var side := (1.0 if (s + w) % 2 == 0 else -1.0)
				_wire(PAIRS[p][w], Vector3(x0 + length / steps * 0.5, 0.0, center_z + side * 0.0018), length / steps + 0.002, 0.0)


## Eight separate wires, still in pair order, fanned out a little.
func _untwisted() -> void:
	var i := 0
	for p in PAIRS.size():
		for w in 2:
			var z := (i - 3.5) * 0.0056
			var angle := (i - 3.5) * 2.2
			_wire(PAIRS[p][w], Vector3(JACKET_END + 0.04, 0.0, z * 1.15), 0.08, angle)
			i += 1


## Wires side by side by pin (pin 1 at -Z), `length` out of the jacket.
func _flat(wires: Array, length: float) -> void:
	for pin in 8:
		var id: String = wires[pin] if pin < wires.size() else ""
		if id == "":
			continue
		_wire(id, Vector3(JACKET_END + length * 0.5, 0.0, (pin - 3.5) * PIN_PITCH), length, 0.0)


func _head(crimped: bool) -> void:
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.88, 0.93, 0.98, 0.32)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.1
	var back := JACKET_END - 0.012
	var head := _box("RJ45Head", HEAD_SIZE, Vector3(back + HEAD_SIZE.x * 0.5, 0.0, 0.0), clear)
	head.sorting_offset = 1.0
	# The clip underneath.
	_box("Clip", Vector3(0.03, 0.004, 0.014), Vector3(back + 0.025, -HEAD_SIZE.y * 0.5 - 0.002, 0.0), clear)
	var gold := _material("gold_up" if not crimped else "gold_down", Color(0.95, 0.78, 0.25) if crimped else Color(0.75, 0.62, 0.3))
	for pin in 8:
		var y := HEAD_SIZE.y * 0.5 - (0.0035 if crimped else 0.0)
		_box("Contact", Vector3(0.008, 0.003, 0.0026), Vector3(back + HEAD_SIZE.x - 0.008, y, (pin - 3.5) * PIN_PITCH), gold)


func _wire(id: String, center: Vector3, length: float, yaw_degrees: float) -> void:
	if not WireColors.WIRES.has(id):
		return
	var color: Color = WireColors.WIRES[id][1]
	var striped := bool(WireColors.WIRES[id][2])
	var holder := Node3D.new()
	holder.position = center
	holder.rotation_degrees.y = yaw_degrees
	_parts.add_child(holder)
	var body := _box_in(holder, Vector3(length, WIRE_HEIGHT, WIRE_WIDTH), Vector3.ZERO, _material("white" if striped else id, WireColors.WHITE if striped else color))
	body.name = "Wire_" + id
	if striped:
		# Coloured stripe along the top of a white wire.
		_box_in(holder, Vector3(length, 0.0006, WIRE_WIDTH * 0.45), Vector3(0, WIRE_HEIGHT * 0.5 + 0.0002, 0), _material(id, color))


func _box(part_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := _box_in(_parts, size, position, material)
	mesh.name = part_name
	return mesh


func _box_in(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)
	return mesh


func _material(key: String, color: Color) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.45
		_materials[key] = m
	return _materials[key]
