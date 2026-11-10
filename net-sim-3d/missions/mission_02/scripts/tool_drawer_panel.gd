class_name Mission02ToolDrawer
extends CanvasLayer

## The "ชุดเข้าหัวสาย" drawer in the storage room: a window listing what is in
## it, each with a small 3D picture. "หยิบ" puts the item in the player's tool
## case (PlayerPresentation). Besides the crimping kit it holds a few things a
## technician might confuse with it (RJ11 heads, a screwdriver, a punch-down
## tool); taking those costs nothing, the crimping desk just says what is
## still missing.

signal item_taken(id: String, title: String)
signal closed

const TOOL_CATALOG := preload("res://scripts/held_item_catalog.gd")
const PREVIEW_SIZE := Vector2i(176, 84)
## Items drawn smaller than their box (true size next to each other): RJ11 vs RJ45.
const PREVIEW_ZOOM_OUT := {"rj11_heads": 1.3}

## [id, title, what it looks like] in drawer order (needed and other items mixed).
const ITEMS := [
	["rj45_heads", "หัว RJ45", "หัวต่อใส 8 ช่อง ถุงละ 10 หัว"],
	["screwdriver", "ไขควงปากแฉก", "ไขควงด้ามยาง ปากแฉก"],
	["cable_stripper", "คีมปอกสาย", "ปอกเปลือกนอกของสายกลม"],
	["punch_down", "เครื่องมือ Punch Down", "ด้ามกดพร้อมใบมีดกระแทก"],
	["crimping_tool", "คีมย้ำสาย LAN", "คีมย้ำหัวต่อ มีช่องตัดสาย"],
	["rj11_heads", "หัว RJ11", "หัวต่อใส 4 ช่อง ถุงละ 10 หัว"],
	["cable_tester", "เครื่องทดสอบสาย LAN", "ตัวเครื่องหลัก + ตัวรับปลายทาง"],
]
## What the crimping job needs from the drawer.
const REQUIRED := ["rj45_heads", "cable_stripper", "crimping_tool", "cable_tester"]

## ids already taken (shared with the controller).
var taken := {}
var _buttons := {}
var _previews: Array[SubViewport] = []


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.name = "DrawerCard"
	card.add_theme_stylebox_override("panel", GameUI.box(Color(0.95, 0.96, 0.97), Color(0.55, 0.6, 0.66), 12, 22, 12))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(GameUI.label("ลิ้นชัก  ·  ชุดเข้าหัวสาย", 22, GameUI.INK, true))
	col.add_child(GameUI.label("เลือกหยิบของที่ต้องใช้ใส่กระเป๋าช่าง (กด E เพื่อดูของในกระเป๋า)", 16, GameUI.INK_SOFT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for entry: Array in ITEMS:
		grid.add_child(_item_card(entry))
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(footer)
	var close_button := GameUI.button("ปิดลิ้นชัก", false, 160)
	close_button.name = "CloseButton"
	close_button.set_meta("sound", "back")
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func open(already_taken: Dictionary) -> void:
	taken = already_taken
	_refresh()
	for viewport in _previews:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sound.play("drawer_open" if Sound.has_sound("drawer_open") else "popup_open")


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


static func title_of(id: String) -> String:
	for entry: Array in ITEMS:
		if entry[0] == id:
			return entry[1]
	return id


## Takes `id` out of the drawer (also what its button does).
func take(id: String) -> bool:
	if not visible or not _buttons.has(id) or taken.has(id):
		return false
	item_taken.emit(id, title_of(id))
	_refresh()
	return true


func _refresh() -> void:
	for id: String in _buttons:
		var button: Button = _buttons[id]
		button.disabled = taken.has(id)
		button.text = "อยู่ในกระเป๋าแล้ว" if taken.has(id) else "หยิบ"


func _item_card(entry: Array) -> Control:
	var id: String = entry[0]
	var card := PanelContainer.new()
	card.name = "Item_" + id
	card.custom_minimum_size = Vector2(196, 0)
	card.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1), Color(0.82, 0.85, 0.9), 10, 10, 8))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	col.add_child(_preview(id))
	var title := GameUI.label(entry[1], 16, GameUI.INK, true)
	col.add_child(title)
	var note := GameUI.label(entry[2], 13, GameUI.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(176, 36)
	col.add_child(note)
	var button := GameUI.button("หยิบ", true, 176)
	button.name = "Take_" + id
	button.custom_minimum_size.y = 34
	button.set_meta("sound", "select")
	button.pressed.connect(func(): take(id))
	col.add_child(button)
	_buttons[id] = button
	return card


# ------------------------------------------------------------ 3D pictures

## A small own-world viewport with the item, lit and framed; rendered once
## each time the drawer opens.
func _preview(id: String) -> Control:
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(PREVIEW_SIZE)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	holder.add_child(viewport)
	_previews.append(viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.ambient_light_energy = 0.9
	environment.environment = env
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var model := _model(id)
	viewport.add_child(model)
	var bounds := _bounds(model)
	# Longest side along X so every item fills the picture the same way.
	var size := bounds.size
	if size.z > size.x and size.z >= size.y:
		model.rotate_y(PI / 2)
	elif size.y > size.x and size.y > size.z:
		model.rotate_z(PI / 2)
	bounds = _bounds(model)
	model.position -= bounds.get_center()
	var camera := Camera3D.new()
	camera.fov = 30.0
	var reach := maxf(bounds.size.x * 0.62, bounds.size.y * 1.05) * float(PREVIEW_ZOOM_OUT.get(id, 1.0))
	var distance := reach / tan(deg_to_rad(camera.fov * 0.5)) * 0.62
	var eye := Vector3(0, 0.55, 1).normalized() * maxf(distance, 0.05)
	camera.transform = Transform3D(Basis.looking_at(-eye, Vector3.UP), eye)
	viewport.add_child(camera)
	return holder


func _model(id: String) -> Node3D:
	if TOOL_CATALOG.TOOLS.has(id):
		return (TOOL_CATALOG.TOOLS[id]["scene"] as PackedScene).instantiate()
	var root := Node3D.new()
	match id:
		"rj45_heads", "rj11_heads":
			var wide := id == "rj45_heads"
			var w := 0.0118 if wide else 0.0096
			var pins := 8 if wide else 4
			for i in 3:
				var head := Node3D.new()
				head.position = Vector3((i - 1) * (w + 0.006), 0, (i % 2) * 0.004)
				head.rotation_degrees.y = (i - 1) * 12.0
				root.add_child(head)
				_box(head, Vector3(w, 0.008, 0.021 if wide else 0.017), Vector3(0, 0.004, 0), Color(0.86, 0.9, 0.95, 0.55), true)
				_box(head, Vector3(w * 0.4, 0.003, 0.009), Vector3(0, 0.0095, 0.004), Color(0.86, 0.9, 0.95, 0.55), true) # latch
				var pitch := w * 0.8 / pins
				for p in pins:
					_box(head, Vector3(pitch * 0.5, 0.0012, 0.004), Vector3(-w * 0.4 + pitch * (p + 0.5), 0.0006, -0.0075 if wide else -0.0055), Color(0.85, 0.68, 0.2))
		"screwdriver":
			_cylinder(root, 0.011, 0.09, Vector3(-0.045, 0, 0), Color(0.82, 0.16, 0.12))
			_cylinder(root, 0.0035, 0.1, Vector3(0.05, 0, 0), Color(0.75, 0.77, 0.8))
			_box(root, Vector3(0.008, 0.005, 0.005), Vector3(0.102, 0, 0), Color(0.6, 0.62, 0.66))
		"punch_down":
			_cylinder(root, 0.014, 0.11, Vector3(-0.05, 0, 0), Color(0.95, 0.62, 0.1))
			_cylinder(root, 0.009, 0.02, Vector3(0.015, 0, 0), Color(0.2, 0.22, 0.25))
			_box(root, Vector3(0.04, 0.0025, 0.007), Vector3(0.045, 0, 0), Color(0.75, 0.77, 0.8))
	return root


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, clear := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, clear)
	mesh.position = at
	parent.add_child(mesh)


## A cylinder lying along X.
func _cylinder(parent: Node3D, radius: float, length: float, at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	mesh.material_override = _material(color, false)
	mesh.position = at
	mesh.rotation_degrees.z = 90.0
	parent.add_child(mesh)


func _material(color: Color, clear: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35 if clear else 0.55
	if clear:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false) + ([model] if model is MeshInstance3D else []):
		var m := node as MeshInstance3D
		if m.mesh == null:
			continue
		var to_model := model.transform * _relative(model, m)
		var box := to_model * m.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result if not first else AABB(Vector3(-0.05, -0.02, -0.02), Vector3(0.1, 0.04, 0.04))


## m's transform relative to `model` (works before the nodes are in the tree).
func _relative(model: Node3D, m: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var node: Node = m
	while node != null and node != model:
		if node is Node3D:
			t = (node as Node3D).transform * t
		node = node.get_parent()
	return t


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
