class_name CrimpBench
extends Node3D

## The cable end the player works on at the crimping desk, drawn 3x real size
## so the eight colours read clearly in the close-up. Local axes: the cable
## comes from -X (the player) and its end points to +X; +Z is the right side
## of the screen, so pin 1 sits on the left (-Z), as when looking at an RJ45
## head with the clip down and the cable towards you.
## show_state() rebuilds the end for each step; play_tool() slides a tool in.
## While arranging (Look.ARRANGING) the camera looks straight down: loose
## wires lie in their own lanes on a rail to the left, placed ones in the 8
## numbered slots of a wire comb straight ahead. pick_wire() finds the wire
## under the mouse, slot_at() the comb slot under a dragged wire.

enum Look { WHOLE, CUT, STRIPPED, UNTWISTED, ARRANGED, TRIMMED, INSERTED, CRIMPED, ARRANGING }

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

## 1 cm of real cable in this 3x model.
const CM := 0.03

var look := Look.WHOLE
var order: Array = [] # wire ids by pin (may hold "" for empty pins)
var _parts: Node3D
var _materials := {}
var _guide: MeshInstance3D
var _crimper: Node3D
## Wires drawn now: id -> [holder, start, end] (bench space), for picking.
var _wires := {}
var hovered := ""
## Arranging: how far placed wires reach, the comb's slot spacing (wider
## than the head's pins so each wire reads), the rail's lanes, the view.
const FLAT_LENGTH := 0.075
const COMB_PITCH := 0.0075
const FAN_LANES := 8
const RAIL_Z0 := -0.042
const RAIL_PITCH := 0.0095
const RAIL_END := JACKET_END + FLAT_LENGTH + 0.005
const ARRANGE_HALF_X := 0.075
const ARRANGE_CENTER_X := -0.02
var _drag: Node3D
## Distance from the crimping tool's origin to the middle of its jaws (model units).
const CRIMPER_JAW := 0.055


func _ready() -> void:
	show_state(Look.WHOLE)


## Camera pose for the close-up: above and behind the end, the cable on the
## left part of the screen (the step panel covers the right).
func view_transform() -> Transform3D:
	var eye := global_transform * Vector3(-0.1, 0.085, 0.05)
	var target := global_transform * Vector3(-0.03, 0.0, 0.05)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


## `fan` (ARRANGING only): the order the loose wires lie in, left to right.
func show_state(next: Look, wire_order: Array = [], fan: Array = []) -> void:
	look = next
	order = wire_order.duplicate()
	_wires.clear()
	hovered = ""
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
			_flat(order, FLAT_LENGTH)
		Look.ARRANGING:
			_jacket(-0.2, JACKET_END)
			_comb()
			_comb_wires()
			_rail(fan)
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


## Strip minigame: a ring round the jacket where the stripper's blade sits,
## `cm` from the cut end (green inside the right range, red outside).
func set_strip_guide(on: bool, cm := 0.0, good := false) -> void:
	if _guide == null:
		_guide = MeshInstance3D.new()
		_guide.name = "StripGuide"
		var torus := TorusMesh.new()
		torus.inner_radius = JACKET_RADIUS * 1.02
		torus.outer_radius = JACKET_RADIUS * 1.45
		torus.rings = 24
		torus.ring_segments = 8
		_guide.mesh = torus
		_guide.rotation_degrees.z = 90.0
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_guide.material_override = material
		add_child(_guide)
	_guide.visible = on
	if on:
		_guide.position = Vector3(-cm * CM, 0, 0)
		(_guide.material_override as StandardMaterial3D).albedo_color = Color(0.2, 0.85, 0.35) if good else Color(0.95, 0.3, 0.25)


## Crimp minigame: the crimping tool over the RJ45 head, closing as `t` goes
## from 0 (open, above) to 1 (squeezed shut).
func set_crimp_tool(on: bool, t := 0.0) -> void:
	if on and _crimper == null:
		_crimper = (TOOL_CATALOG.TOOLS["crimping_tool"]["scene"] as PackedScene).instantiate()
		_crimper.name = "Crimper"
		_crimper.scale = Vector3.ONE * 1.4
		add_child(_crimper)
	if _crimper == null:
		return
	_crimper.visible = on
	if on:
		# The tool model lies in its XY plane, jaws towards +X (tip ~0.08 m),
		# handles towards -X. Turned 90 degrees it stands across the cable with
		# the jaws on the head and the handles running off to the right (+Z).
		var closed := clampf(t, 0.0, 1.0)
		var head := Vector3(JACKET_END - 0.012 + HEAD_SIZE.x * 0.5, 0.0, 0.0)
		_crimper.position = head + Vector3(0.0, 0.03 * (1.0 - closed), CRIMPER_JAW * _crimper.scale.x)
		_crimper.rotation_degrees = Vector3(0, 90, 6.0 * (1.0 - closed))


## The wire under screen point `at` seen by `camera` ("" if none within
## `reach` pixels). Works on the 3D model itself, not on a panel.
func pick_wire(camera: Camera3D, at: Vector2, reach := 16.0) -> String:
	var best := ""
	var best_d := reach
	for id: String in _wires:
		var a: Vector3 = global_transform * (_wires[id][1] as Vector3)
		var b: Vector3 = global_transform * (_wires[id][2] as Vector3)
		if camera.is_position_behind(a) or camera.is_position_behind(b):
			continue
		var d := Geometry2D.get_closest_point_to_segment(at, camera.unproject_position(a), camera.unproject_position(b)).distance_to(at)
		if d < best_d:
			best_d = d
			best = id
	return best


## Where wire `id` shows on screen (its middle), for tests and hints.
func wire_screen_point(camera: Camera3D, id: String) -> Vector2:
	if not _wires.has(id):
		return Vector2(-1, -1)
	var mid: Vector3 = ((_wires[id][1] as Vector3) + (_wires[id][2] as Vector3)) * 0.5
	return camera.unproject_position(global_transform * mid)


## Thickens the wire under the mouse so the player sees what a click takes.
func set_hovered(id: String) -> void:
	if id == hovered:
		return
	for key: String in [hovered, id]:
		if _wires.has(key) and is_instance_valid(_wires[key][0]):
			(_wires[key][0] as Node3D).scale = Vector3(1.0, 1.7, 1.7) if key == id else Vector3.ONE
	hovered = id


func wire_ids() -> PackedStringArray:
	return PackedStringArray(_wires.keys())


# ---------------------------------------------------------------- pieces

## The parking rail on the left: each loose wire bends out of the jacket and
## lies straight in its own lane (lane = its place in `fan`, so the others
## never move). Wires bound for far lanes bend first, so no two wires cross
## where they can be clicked. A grey tray with ridges sits under the lanes.
func _rail(fan: Array) -> void:
	var far_z := RAIL_Z0 - (FAN_LANES - 1) * RAIL_PITCH
	var tray_x0 := _bend_x(FAN_LANES - 1) - 0.004
	_box("RailTray", Vector3(RAIL_END + 0.004 - tray_x0, 0.0012, RAIL_Z0 - far_z + RAIL_PITCH),
		Vector3((tray_x0 + RAIL_END + 0.004) * 0.5, -WIRE_HEIGHT * 0.5 - 0.0008, (RAIL_Z0 + far_z) * 0.5), _material("rail_tray", Color(0.8, 0.82, 0.85)))
	for lane in FAN_LANES + 1:
		var z := RAIL_Z0 + RAIL_PITCH * 0.5 - lane * RAIL_PITCH
		_box("RailRidge", Vector3(RAIL_END - tray_x0, 0.002, 0.0008), Vector3((tray_x0 + RAIL_END) * 0.5, -WIRE_HEIGHT * 0.5, z), _material("rail_ridge", Color(0.68, 0.7, 0.74)))
	for i in fan.size():
		var id: String = fan[i]
		if id in order:
			continue
		var lane_z := RAIL_Z0 - i * RAIL_PITCH
		var bend := Vector3(_bend_x(i), 0.0, lane_z)
		var root := Vector3(JACKET_END, 0.0, -0.005)
		var d := bend - root
		_wire(id, (root + bend) * 0.5, d.length() + WIRE_WIDTH * 0.6, rad_to_deg(atan2(-d.z, d.x)))
		# The straight part last, so it is the one picked.
		_wire(id, Vector3((bend.x + RAIL_END) * 0.5, 0.0, lane_z), RAIL_END - bend.x, 0.0)


func _bend_x(lane: int) -> float:
	return JACKET_END + 0.03 - lane * 0.003


## The wire comb straight ahead: 8 numbered slots between thin teeth, the
## next free slot marked yellow.
func _comb() -> void:
	var next := order.find("") if order.size() == 8 else 0
	var comb_x := JACKET_END + FLAT_LENGTH * 0.62
	_box("CombBase", Vector3(0.016, 0.0015, 8 * COMB_PITCH + 0.003), Vector3(comb_x, -WIRE_HEIGHT * 0.5 - 0.001, 0.0), _material("comb_base", Color(0.3, 0.33, 0.38)))
	for k in 9:
		_box("CombTooth", Vector3(0.014, 0.006, 0.0011), Vector3(comb_x, 0.0005, (k - 4) * COMB_PITCH), _material("comb", Color(0.93, 0.94, 0.96)))
	for pin in 8:
		var label := Label3D.new()
		label.text = str(pin + 1)
		label.font_size = 48
		label.pixel_size = 0.00013
		label.outline_size = 10
		label.outline_modulate = Color(0.05, 0.1, 0.2)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1.0, 0.9, 0.3) if pin == next else Color(0.92, 0.95, 1.0)
		label.position = Vector3(JACKET_END + FLAT_LENGTH + 0.009, 0.003, (pin - 3.5) * COMB_PITCH)
		_parts.add_child(label)
	if next >= 0:
		var clear := StandardMaterial3D.new()
		clear.albedo_color = Color(1.0, 0.9, 0.3, 0.55)
		clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		clear.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_box("NextPin", Vector3(FLAT_LENGTH - 0.008, 0.0008, COMB_PITCH * 0.8), Vector3(JACKET_END + 0.008 + (FLAT_LENGTH - 0.008) * 0.5, -WIRE_HEIGHT * 0.5, (next - 3.5) * COMB_PITCH), clear)


## Placed wires in the comb: a short bend out of the jacket, then straight
## along their slot.
func _comb_wires() -> void:
	for pin in 8:
		var id: String = order[pin] if pin < order.size() else ""
		if id == "":
			continue
		var z := (pin - 3.5) * COMB_PITCH
		var root := Vector3(JACKET_END, 0.0, z * 0.3)
		var bend := Vector3(JACKET_END + 0.008, 0.0, z)
		var d := bend - root
		_wire(id, (root + bend) * 0.5, d.length() + WIRE_WIDTH * 0.6, rad_to_deg(atan2(-d.z, d.x)))
		_wire(id, Vector3((bend.x + JACKET_END + FLAT_LENGTH) * 0.5, 0.0, z), JACKET_END + FLAT_LENGTH - bend.x, 0.0)


## Camera straight down on the rail and the comb (screen up = away from the
## player), framed for the part of the screen left of the step panel.
func arrange_view_transform(fov_degrees: float, aspect: float) -> Transform3D:
	var half := ARRANGE_HALF_X
	var height := half / tan(deg_to_rad(fov_degrees) * 0.5)
	# Left screen edge just past the far rail lane; the panel covers the right part.
	var center_z := -0.116 + half * aspect
	var eye := global_transform * Vector3(ARRANGE_CENTER_X, height, center_z)
	return Transform3D(Basis.looking_at(-global_basis.y.normalized(), global_basis.x.normalized()), eye)


## The point on the bench plane under screen point `at` (bench space).
func mouse_to_local(camera: Camera3D, at: Vector2) -> Vector3:
	var plane := Plane(global_basis.y.normalized(), global_position)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))
	return to_local(hit) if hit != null else Vector3(INF, 0, INF)


## Comb slot (0-7) at bench point `p`, -1 outside the comb.
func slot_at(p: Vector3) -> int:
	if p.x < JACKET_END - 0.006 or p.x > JACKET_END + FLAT_LENGTH + 0.016:
		return -1
	var pin := int(floor(p.z / COMB_PITCH + 4.0))
	return pin if pin >= 0 and pin < 8 else -1


func slot_screen_point(camera: Camera3D, pin: int) -> Vector2:
	return camera.unproject_position(global_transform * Vector3(JACKET_END + FLAT_LENGTH * 0.75, 0.0, (pin - 3.5) * COMB_PITCH))


## While dragging: a copy of wire `id` under the mouse and the slot it would
## drop into lit up. `id` "" clears both.
func set_drag(id: String, p := Vector3.ZERO, slot := -1) -> void:
	if _drag:
		_drag.queue_free()
		_drag = null
	if id == "" or not WireColors.WIRES.has(id):
		return
	_drag = Node3D.new()
	_drag.name = "Drag"
	add_child(_drag)
	var color: Color = WireColors.WIRES[id][1]
	var striped := bool(WireColors.WIRES[id][2])
	_box_in(_drag, Vector3(0.045, WIRE_HEIGHT, WIRE_WIDTH), Vector3(p.x, 0.006, p.z), _material("white" if striped else id, WireColors.WHITE if striped else color))
	if striped:
		_box_in(_drag, Vector3(0.045, 0.0006, WIRE_WIDTH * 0.45), Vector3(p.x, 0.006 + WIRE_HEIGHT * 0.5 + 0.0002, p.z), _material(id, color))
	if slot >= 0:
		var lit := StandardMaterial3D.new()
		lit.albedo_color = Color(0.3, 0.9, 0.45, 0.6)
		lit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_box_in(_drag, Vector3(FLAT_LENGTH - 0.008, 0.001, COMB_PITCH * 0.9), Vector3(JACKET_END + 0.008 + (FLAT_LENGTH - 0.008) * 0.5, -WIRE_HEIGHT * 0.5 + 0.0002, (slot - 3.5) * COMB_PITCH), lit)


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


func _wire(id: String, center: Vector3, length: float, yaw_degrees: float, pitch_degrees := 0.0) -> void:
	if not WireColors.WIRES.has(id):
		return
	var color: Color = WireColors.WIRES[id][1]
	var striped := bool(WireColors.WIRES[id][2])
	var holder := Node3D.new()
	holder.position = center
	holder.rotation_degrees = Vector3(0, yaw_degrees, pitch_degrees)
	_parts.add_child(holder)
	var half := holder.basis * Vector3(length * 0.5, 0, 0)
	_wires[id] = [holder, center - half, center + half]
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
