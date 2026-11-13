class_name Mission04Tower
extends Node3D

## A simple desktop PC case for Mission 4 (made in-game, no model file):
## local +Z = front (faces the user), -Z = rear I/O, the side cover on -X
## comes off. Inside: the motherboard on +X, one PCI Express slot and the
## network card (NIC) whose bracket and RJ45 port (NetworkPort) are at the
## rear. replace_nic() plays the agreed repair: power off -> cover off ->
## old card out -> spare card in -> cover on -> power on.

const SIZE := Vector3(0.19, 0.4, 0.4)
const STEP_TIME := 0.9
const CASE_COLOR := Color(0.12, 0.13, 0.15)
const PCB_COLOR := Color(0.1, 0.42, 0.22)
const STEEL := Color(0.72, 0.74, 0.78)

var port: NetworkPort
var nic: Node3D
var cover: Node3D
var power_led: MeshInstance3D
var powered := true
var _led_on: StandardMaterial3D
var _led_off: StandardMaterial3D
## Where the card sits in its slot (local).
var _nic_home := Vector3.ZERO
## Where the side cover sits when closed (the model's cover is not at 0).
var _cover_home := Vector3.ZERO
## The Blender model (3Dmodel/ด่าน_04, made by GPT on 2026-11-13).
const MODEL := "res://assets/models/mission_04/pc_tower_nic.glb"
## A clean copy of the model's NIC_Card for the spare card.
var _card_template: Node3D
var work_light: Light3D


func _init() -> void:
	# A hollow case, open on the -X side (the cover closes it).
	var w := SIZE.x
	var h := SIZE.y
	var d := SIZE.z
	_box(self, Vector3(0.004, h, d), Vector3(w * 0.5 - 0.002, h * 0.5, 0), CASE_COLOR, 0.5).name = "RightPanel"
	_box(self, Vector3(w, 0.004, d), Vector3(0, h - 0.002, 0), CASE_COLOR, 0.5).name = "TopPanel"
	_box(self, Vector3(w, 0.004, d), Vector3(0, 0.002, 0), CASE_COLOR, 0.5).name = "BottomPanel"
	_box(self, Vector3(w, h, 0.004), Vector3(0, h * 0.5, d * 0.5 - 0.002), CASE_COLOR, 0.5).name = "FrontPanel"
	_box(self, Vector3(w, h, 0.004), Vector3(0, h * 0.5, -d * 0.5 + 0.002), CASE_COLOR, 0.5).name = "RearPanel"
	# ATX board, top-rear of the right panel (the PSU sits under it).
	var board := _box(self, Vector3(0.003, 0.29, 0.25), Vector3(w * 0.5 - 0.0055, 0.225, -0.065), PCB_COLOR.darkened(0.35), 0.7)
	board.name = "Motherboard"
	var slot := _box(self, Vector3(0.012, 0.01, 0.09), Vector3(w * 0.5 - 0.013, 0.11, -0.14), Color(0.08, 0.08, 0.09), 0.6)
	slot.name = "PcieSlot"
	# Front: bezel and power LED.
	var bezel := _box(self, Vector3(SIZE.x, SIZE.y, 0.012), Vector3(0, SIZE.y * 0.5, SIZE.z * 0.5 + 0.004), Color(0.07, 0.07, 0.08), 0.4)
	bezel.name = "Bezel"
	_led_on = _glow(Color(0.3, 0.6, 1.0))
	_led_off = StandardMaterial3D.new()
	_led_off.albedo_color = Color(0.08, 0.09, 0.12)
	power_led = _box(self, Vector3(0.012, 0.012, 0.004), Vector3(0, SIZE.y - 0.04, SIZE.z * 0.5 + 0.011), Color.WHITE, 0.4)
	power_led.name = "PowerLed"
	power_led.material_override = _led_on
	# Rear I/O plate and fan grille for the look.
	_box(self, Vector3(0.05, 0.16, 0.004), Vector3(0.03, 0.3, -SIZE.z * 0.5 - 0.002), Color(0.55, 0.57, 0.6), 0.5)
	_box(self, Vector3(0.12, 0.12, 0.004), Vector3(-0.02, 0.26, -SIZE.z * 0.5 - 0.0025), Color(0.2, 0.21, 0.23), 0.5)
	# Fingers in the slot, bracket in the rear panel.
	_nic_home = Vector3(SIZE.x * 0.5 - 0.05, 0.118, -SIZE.z * 0.5 + 0.0565 - 0.001)
	nic = make_nic(true)
	nic.name = "NIC"
	add_child(nic)
	nic.position = _nic_home
	port = nic.get_node("Port") as NetworkPort
	cover = Node3D.new()
	cover.name = "SideCover"
	add_child(cover)
	_box(cover, Vector3(0.004, SIZE.y, SIZE.z), Vector3(-SIZE.x * 0.5, SIZE.y * 0.5, 0), CASE_COLOR.lightened(0.08), 0.45)
	_box(cover, Vector3(0.002, 0.012, 0.03), Vector3(-SIZE.x * 0.5 - 0.003, SIZE.y * 0.5, -SIZE.z * 0.5 + 0.03), STEEL, 0.4)


## The inside of a real desktop PC (the teacher's PC in Mission 4): power
## supply, CPU cooler with fan, RAM, chipset heatsink, M.2 SSD, more
## expansion slots, a drive cage with HDD and SSD, case fans and cables.
## Local: board face at x = 0.088, open side -X, front +Z, rear -Z.
func add_details() -> void:
	var parts := Node3D.new()
	parts.name = "Interior"
	add_child(parts)
	var dark := Color(0.09, 0.09, 0.1)
	var alu := Color(0.75, 0.77, 0.8)
	var bx := SIZE.x * 0.5 - 0.007 # board face
	# Power supply at the bottom rear, label facing the open side.
	_box(parts, Vector3(0.15, 0.085, 0.15), Vector3(0.005, 0.0475, -0.12), dark, 0.5).name = "PSU"
	_box(parts, Vector3(0.001, 0.045, 0.08), Vector3(-0.0705, 0.05, -0.12), Color(0.82, 0.84, 0.86), 0.6)
	_box(parts, Vector3(0.11, 0.004, 0.11), Vector3(0.005, 0.0905, -0.12), Color(0.16, 0.16, 0.18), 0.7) # fan grille
	# CPU cooler: base, aluminium fins, a fan on the front face.
	_box(parts, Vector3(0.012, 0.06, 0.06), Vector3(bx - 0.006, 0.3, -0.08), alu.darkened(0.2), 0.3)
	for i in 9:
		_box(parts, Vector3(0.045, 0.085, 0.0016), Vector3(bx - 0.035, 0.3, -0.116 + i * 0.009), alu, 0.35)
	_box(parts, Vector3(0.05, 0.088, 0.012), Vector3(bx - 0.035, 0.3, -0.034), dark, 0.6).name = "CpuFanFrame"
	_cyl(parts, 0.036, 0.013, Vector3(bx - 0.035, 0.3, -0.034), Vector3(PI * 0.5, 0, 0), Color(0.18, 0.18, 0.2))
	_cyl(parts, 0.012, 0.015, Vector3(bx - 0.035, 0.3, -0.034), Vector3(PI * 0.5, 0, 0), Color(0.5, 0.1, 0.1))
	# RAM: two sticks in their slots, in front of the cooler.
	for z in [-0.016, -0.004]:
		_box(parts, Vector3(0.006, 0.135, 0.008), Vector3(bx - 0.003, 0.3, z), Color(0.12, 0.12, 0.13), 0.5)
		_box(parts, Vector3(0.032, 0.13, 0.004), Vector3(bx - 0.019, 0.3, z), Color(0.08, 0.08, 0.09), 0.4).name = "RAM"
		_box(parts, Vector3(0.004, 0.13, 0.0045), Vector3(bx - 0.036, 0.3, z), Color(0.75, 0.15, 0.15), 0.4)
	# Board details: 24-pin socket, chipset heatsink, M.2 SSD, more slots.
	_box(parts, Vector3(0.012, 0.05, 0.012), Vector3(bx - 0.006, 0.27, 0.05), Color(0.92, 0.92, 0.9), 0.5)
	_box(parts, Vector3(0.01, 0.04, 0.04), Vector3(bx - 0.005, 0.16, -0.01), Color(0.25, 0.35, 0.5), 0.3).name = "Chipset"
	_box(parts, Vector3(0.002, 0.022, 0.08), Vector3(bx - 0.001, 0.205, -0.03), Color(0.05, 0.05, 0.06), 0.4).name = "M2"
	_box(parts, Vector3(0.0022, 0.012, 0.03), Vector3(bx - 0.0021, 0.205, -0.03), Color(0.85, 0.85, 0.85), 0.5)
	for slot: Array in [[0.15, 0.03], [0.19, 0.09], [0.23, 0.03]]:
		_box(parts, Vector3(0.01, 0.008, slot[1]), Vector3(bx - 0.005, slot[0], -0.185 + slot[1] * 0.5), Color(0.08, 0.08, 0.09), 0.6)
		_box(parts, Vector3(0.07, 0.018, 0.0012), Vector3(0.04, slot[0] + 0.004, -SIZE.z * 0.5 - 0.0015), STEEL, 0.35) # slot cover
	# Drive cage at the front bottom: a 3.5" HDD and a 2.5" SSD.
	_box(parts, Vector3(0.115, 0.004, 0.125), Vector3(-0.01, 0.065, 0.125), STEEL.darkened(0.45), 0.5)
	_box(parts, Vector3(0.004, 0.11, 0.125), Vector3(0.05, 0.06, 0.125), STEEL.darkened(0.45), 0.5)
	_box(parts, Vector3(0.1, 0.026, 0.118), Vector3(-0.01, 0.03, 0.125), Color(0.55, 0.57, 0.6), 0.35).name = "HDD"
	_box(parts, Vector3(0.07, 0.008, 0.1), Vector3(-0.01, 0.075, 0.13), Color(0.12, 0.13, 0.16), 0.4).name = "SSD"
	# Case fans: front intake, rear exhaust.
	_box(parts, Vector3(0.12, 0.12, 0.022), Vector3(-0.005, 0.27, 0.183), dark, 0.6)
	_cyl(parts, 0.055, 0.023, Vector3(-0.005, 0.27, 0.183), Vector3(PI * 0.5, 0, 0), Color(0.17, 0.17, 0.19))
	_cyl(parts, 0.016, 0.025, Vector3(-0.005, 0.27, 0.183), Vector3(PI * 0.5, 0, 0), Color(0.1, 0.1, 0.11))
	_box(parts, Vector3(0.09, 0.09, 0.022), Vector3(0.025, 0.31, -0.185), dark, 0.6)
	_cyl(parts, 0.04, 0.023, Vector3(0.025, 0.31, -0.185), Vector3(PI * 0.5, 0, 0), Color(0.17, 0.17, 0.19))
	# Cables: 24-pin bundle, CPU power, SATA data (red) and SATA power.
	parts.add_child(CableBuilder.build([Vector3(0.03, 0.09, -0.05), Vector3(0.06, 0.15, 0.07), Vector3(0.075, 0.25, 0.075), Vector3(bx - 0.012, 0.27, 0.058)], Color(0.07, 0.07, 0.08), "Atx24Pin", 0.008))
	parts.add_child(CableBuilder.build([Vector3(0.045, 0.09, -0.185), Vector3(0.05, 0.24, -0.19), Vector3(0.06, 0.375, -0.15), Vector3(bx - 0.008, 0.37, -0.12)], Color(0.07, 0.07, 0.08), "CpuPower", 0.0045))
	parts.add_child(CableBuilder.build([Vector3(0.04, 0.035, 0.066), Vector3(0.06, 0.09, 0.05), Vector3(bx - 0.006, 0.12, 0.04)], Color(0.75, 0.12, 0.12), "SataData", 0.0025))
	parts.add_child(CableBuilder.build([Vector3(-0.04, 0.09, -0.05), Vector3(-0.045, 0.06, 0.06), Vector3(-0.045, 0.035, 0.066)], Color(0.07, 0.07, 0.08), "SataPower", 0.003))
	# A soft work light, on only while the cover is off (replace_nic).
	var light := OmniLight3D.new()
	work_light = light
	light.name = "WorkLight"
	light.position = Vector3(-0.3, 0.32, 0.05)
	light.omni_range = 0.8
	light.light_energy = 0.9
	light.visible = false
	parts.add_child(light)
	parts.add_child(CableBuilder.build([Vector3(0.0, 0.385, 0.185), Vector3(0.07, 0.385, 0.075), Vector3(0.08, 0.1, 0.068), Vector3(bx - 0.004, 0.09, 0.04)], Color(0.3, 0.3, 0.33), "FrontPanelWires", 0.0018))


static func _cyl(parent: Node, radius: float, height: float, pos: Vector3, rot: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 20
	mesh.mesh = cyl
	mesh.position = pos
	mesh.rotation = rot
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


## A network card: green PCB, a chip, gold fingers and the metal bracket with
## its RJ45 port (facing out of the case's rear). `with_port` adds the
## NetworkPort (the spare card gets its own when installed).
static func make_nic(with_port: bool) -> Node3D:
	var card := Node3D.new()
	# Lies flat (tower case): height along X away from the motherboard (+X).
	_box(card, Vector3(0.06, 0.002, 0.11), Vector3.ZERO, PCB_COLOR, 0.6)
	_box(card, Vector3(0.016, 0.003, 0.016), Vector3(0, 0.002, 0.01), Color(0.1, 0.1, 0.11), 0.4)
	_box(card, Vector3(0.008, 0.0025, 0.07), Vector3(0.033, 0, 0.005), Color(0.85, 0.68, 0.2), 0.3)
	# Bracket at the rear end (-Z), a strip in the rear panel.
	_box(card, Vector3(0.07, 0.018, 0.0012), Vector3(-0.005, 0.004, -0.0565), STEEL, 0.35)
	if with_port:
		var p := NetworkPort.new()
		p.name = "Port"
		p.port_id = "staff_pc_nic"
		p.label_text = ""
		card.add_child(p)
		p.position = Vector3(-0.005, 0.004, -0.0585)
		p.rotation = Vector3(0.0, PI, 0.0)
	return card


func set_power(on: bool) -> void:
	powered = on
	power_led.material_override = _led_on if on else _led_off


## The repair, step by step; `on_step(index, text)` lets the caller show a
## caption. Ends with a new card whose port LED is on (if `cable_in`).
func replace_nic(on_step: Callable = Callable(), cable_in := true) -> void:
	_step(on_step, 0, "ปิดเครื่องคอมพิวเตอร์และถอดสายไฟ")
	set_power(false)
	port.set_link(false)
	await _wait(STEP_TIME)
	_step(on_step, 1, "เปิดฝาเคสคอมพิวเตอร์")
	var light := work_light
	if light:
		light.visible = true
	await _tween(cover, "position", _cover_home + Vector3(-0.12, 0, 0), STEP_TIME)
	cover.visible = false
	_step(on_step, 2, "ถอด Network Interface Card (NIC) ที่มีปัญหา")
	var was_plugged := port.plugged
	port.unplug()
	await _tween(nic, "position", _nic_home + Vector3(-0.05, 0.0, 0.0), STEP_TIME)
	await _tween(nic, "position", _nic_home + Vector3(-0.26, 0.06, 0.04), STEP_TIME * 0.6)
	nic.queue_free()
	_step(on_step, 3, "ติดตั้ง Network Interface Card (NIC) ตัวสำรอง")
	var holder := nic.get_parent() if is_instance_valid(nic) and nic.get_parent() else self
	nic = _new_card()
	holder.add_child(nic)
	nic.position = _nic_home + Vector3(-0.26, 0.06, 0.04)
	await _tween(nic, "position", _nic_home + Vector3(-0.05, 0.0, 0.0), STEP_TIME * 0.6)
	await _tween(nic, "position", _nic_home, STEP_TIME)
	_step(on_step, 4, "ปิดฝาเคส ต่อสาย และเปิดเครื่อง")
	cover.visible = true
	await _tween(cover, "position", _cover_home, STEP_TIME)
	if light:
		light.visible = false
	if was_plugged and cable_in:
		port.plug()
	set_power(true)
	await _wait(STEP_TIME * 0.6)
	port.set_link(cable_in)


## A new card for the slot: the model's spare (a copy of NIC_Card) or the
## simple one, with its NetworkPort.
func _new_card() -> Node3D:
	if _card_template == null:
		var simple := make_nic(true)
		simple.name = "NIC"
		port = simple.get_node("Port") as NetworkPort
		return simple
	var card := _card_template.duplicate() as Node3D
	card.name = "NIC_Card"
	_attach_model_port(card)
	return card


## Replaces the simple boxes with the Blender model: Case_Body, Side_Cover,
## Interior, Power_LED, NIC_Card (NIC_Link_LED, NIC_Port_Point). The game's
## NetworkPort sits on NIC_Port_Point (its -Z points into the socket) and
## drives NIC_Link_LED. Returns false (simple case kept) if the file is missing.
func use_model() -> bool:
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	var card := model.find_child("NIC_Card", true, false) as Node3D
	var side := model.find_child("Side_Cover", true, false) as Node3D
	var led := model.find_child("Power_LED", true, false) as MeshInstance3D
	if card == null or side == null or led == null or card.find_child("NIC_Port_Point", true, false) == null:
		push_warning("PC tower model: missing parts, keeping the simple case")
		model.free()
		return false
	for child in get_children():
		remove_child(child)
		child.free()
	model.name = "Model"
	add_child(model)
	_double_sided(model)
	cover = side
	_cover_home = side.position
	power_led = led
	set_power(powered)
	nic = card
	_nic_home = card.position
	_card_template = card.duplicate() as Node3D
	_attach_model_port(card)
	work_light = OmniLight3D.new()
	work_light.name = "WorkLight"
	work_light.position = Vector3(-0.3, 0.32, 0.05)
	work_light.omni_range = 0.8
	work_light.light_energy = 0.9
	work_light.visible = false
	add_child(work_light)
	return true


## Some panels of the model face inward (Blender shows back faces, Godot
## culls them): draw the model's materials from both sides.
func _double_sided(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var material := mi.get_active_material(i) as BaseMaterial3D
			if material and material.cull_mode != BaseMaterial3D.CULL_DISABLED:
				material = material.duplicate() as BaseMaterial3D
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, material)


func _attach_model_port(card: Node3D) -> void:
	var point := card.find_child("NIC_Port_Point", true, false) as Node3D
	var p := ModelPort.new()
	p.name = "Port"
	p.port_id = "staff_pc_nic"
	p.label_text = ""
	p.led_mesh = card.find_child("NIC_Link_LED", true, false) as MeshInstance3D
	point.add_child(p)
	# Only the marker's position is used: the glTF export turned the empty's
	# axes (its +Z points up in Godot). The port faces out of the case's rear
	# (-Z of the card / case), so the cable plugs in toward the front.
	var marker_in_card := point.transform if point.get_parent() == card else card.global_transform.affine_inverse() * point.global_transform
	p.basis = marker_in_card.basis.orthonormalized().inverse() * Basis(Vector3.UP, PI)
	port = p


## The game's NetworkPort without its own socket boxes: the model has the
## socket; plug() still shows the cable's plug and set_link() lights the
## model's NIC_Link_LED.
class ModelPort extends NetworkPort:
	var led_mesh: MeshInstance3D
	var _on := StandardMaterial3D.new()
	var _off := StandardMaterial3D.new()

	func _init() -> void:
		_on.albedo_color = NetworkPort.LED_ON
		_on.emission_enabled = true
		_on.emission = NetworkPort.LED_ON
		_on.emission_energy_multiplier = 2.5
		_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_off.albedo_color = NetworkPort.LED_OFF

	func _ready() -> void:
		super._ready()
		for part in ["Plate", "Opening", "LinkLed"]:
			var node := get_node_or_null(part) as Node3D
			if node:
				node.visible = false

	func set_link(on: bool) -> void:
		super.set_link(on)
		if led_mesh:
			led_mesh.material_override = _on if on else _off


func _step(on_step: Callable, index: int, text: String) -> void:
	if on_step.is_valid():
		on_step.call(index, text)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _tween(node: Node3D, property: String, value: Vector3, seconds: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, property, value, seconds)
	await t.finished


static func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
