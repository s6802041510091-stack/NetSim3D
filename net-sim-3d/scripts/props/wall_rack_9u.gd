class_name WallRack9U
extends StaticBody3D

## The 9U wall rack behind the teacher's desk in the computer room
## (600 W x 500 H x 450 D mm, mounted 1.5 m above the floor), built from simple
## boxes so it costs almost nothing on the Web.
## What is inside follows the story (GameFlow.configure_level sets `stage`):
##   EMPTY     Level 1 — nothing installed yet (the player only plans the devices)
##   INSTALLED Level 2 — Router + Switched Hub 24 Port, only the Internet line
##             in the Router's WAN port; the player plugs the rest (Mission 2)
##   CABLED    Level 3-6 — Router LAN 1 -> switch port 1, switch port 2 -> the
##             teacher's PC, links up
## Ports are named "router_wan", "router_lan1".."router_lan4", "switch_01"..
## "switch_24". port_position() / set_link() / plug() let a mission use them.
## Port openings and LEDs are two MultiMeshes, so the whole rack stays a handful
## of draw calls.

enum Stage { EMPTY, INSTALLED, CABLED }

const SIZE := Vector3(0.60, 0.50, 0.45)
const SHEET := 0.012

## Front of the devices (local z), just in front of the 19" rails.
const FRONT_Z := 0.155
const PORT_SIZE := Vector3(0.0116, 0.0098, 0.004)
const LED_SIZE := Vector3(0.0032, 0.0022, 0.002)
const SWITCH_Y := 0.13
const SWITCH_PORT_PITCH := 0.0145
const SWITCH_PORTS_CENTER_X := 0.03
const ROUTER_Y := -0.0425
const ROUTER_FRONT_Z := 0.12

const LED_ON := Color(0.25, 1.0, 0.35)
const LED_OFF := Color(0.08, 0.1, 0.09)
const LED_POWER := Color(0.3, 0.75, 1.0)
const CABLE_INTERNET := Color(0.82, 0.83, 0.85)
const CABLE_PATCH := Color(0.16, 0.42, 0.85)

@export var stage: Stage = Stage.EMPTY:
	set(value):
		stage = value
		if is_inside_tree():
			_build()
## The teacher PC's network card: cabled to switch port 2 in the CABLED stage.
@export_node_path("Node3D") var teacher_port: NodePath

var _visual: Node3D
var _ports := {} # id -> local position of the opening (front face)
var _port_index := {} # id -> instance index in the port / LED multimeshes
var _links := {} # id -> true when its link LED is on
var _leds: MultiMesh
var _plugged := {} # id -> plug node
var _internet := true


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	_build()


# ---------------------------------------------------------------- public API

## Every port id of the installed devices (empty in the EMPTY stage).
func port_ids() -> PackedStringArray:
	return PackedStringArray(_ports.keys())


func has_port(id: String) -> bool:
	return _ports.has(id)


## World position of port `id`'s opening.
func port_position(id: String) -> Vector3:
	return global_transform * (_ports.get(id, Vector3.ZERO) as Vector3)


func is_link_on(id: String) -> bool:
	return bool(_links.get(id, false))


## Switches the link LED of port `id`.
func set_link(id: String, on: bool) -> void:
	if not _port_index.has(id):
		return
	_links[id] = on
	_leds.set_instance_color(_port_index[id], LED_ON if on else LED_OFF)


func is_plugged(id: String) -> bool:
	return _plugged.has(id)


## Shows an RJ45 plug with a coloured boot in port `id` (the cable itself is
## drawn by whoever plugs it). Returns false for an unknown or busy port.
func plug(id: String, boot_color: Color = CABLE_PATCH) -> bool:
	if not _ports.has(id) or _plugged.has(id):
		return false
	var at: Vector3 = _ports[id]
	var node := Node3D.new()
	node.name = "Plug_" + id
	node.position = at
	_visual.add_child(node)
	var clear := _material(Color(0.85, 0.9, 0.95, 0.55), 0.0, 0.2)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box_in(node, Vector3(0.0112, 0.0082, 0.012), Vector3(0, 0, 0.002), clear, "Head")
	_box_in(node, Vector3(0.0128, 0.0108, 0.02), Vector3(0, 0, 0.017), _material(boot_color, 0.0, 0.6), "Boot")
	_plugged[id] = node
	return true


func unplug(id: String) -> void:
	if _plugged.has(id):
		(_plugged[id] as Node).queue_free()
		_plugged.erase(id)


# ---------------------------------------------------------------- building

func _build() -> void:
	if _visual:
		_visual.queue_free()
	_ports.clear()
	_port_index.clear()
	_links.clear()
	_plugged.clear()
	_internet = true
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
	if stage == Stage.EMPTY:
		return
	_build_switch()
	_build_router()
	_build_port_meshes()
	# The Internet line comes down from the ceiling into the Router's WAN port.
	plug("router_wan", CABLE_INTERNET)
	var wan: Vector3 = _ports["router_wan"]
	_cable([wan + Vector3(0, 0, 0.026), wan + Vector3(0, 0, 0.045), Vector3(-0.262, wan.y, 0.19),
		Vector3(-0.262, 0.2, 0.12), Vector3(-0.262, 0.26, 0.0), Vector3(-0.262, 1.5, -0.05)], CABLE_INTERNET, "InternetLine")
	set_link("router_wan", true)
	if stage == Stage.CABLED:
		_build_installed_cables()


func _build_switch() -> void:
	var body := _material(Color(0.2, 0.22, 0.26), 0.35, 0.5)
	var dark := _material(Color(0.1, 0.11, 0.13), 0.3, 0.6)
	var depth := 0.25
	_box(Vector3(0.44, 0.044, depth), Vector3(0, SWITCH_Y, FRONT_Z - depth * 0.5), body, "SwitchBody")
	_box(Vector3(0.482, 0.044, 0.003), Vector3(0, SWITCH_Y, FRONT_Z - 0.0015), dark, "SwitchFace")
	_label("Switched Hub 24 Port", Vector3(-0.17, SWITCH_Y + 0.012, FRONT_Z + 0.001), 0.00022)
	_label("PWR", Vector3(-0.2, SWITCH_Y - 0.012, FRONT_Z + 0.001), 0.00016)
	for i in 24:
		var column := i / 2
		var top := i % 2 == 0 # odd-numbered ports (1, 3, 5 ...) on the top row
		var x := SWITCH_PORTS_CENTER_X + (column - 5.5) * SWITCH_PORT_PITCH
		var y := SWITCH_Y + (0.0072 if top else -0.0082)
		_ports["switch_%02d" % (i + 1)] = Vector3(x, y, FRONT_Z)
	_box(Vector3(0.006, 0.004, 0.002), Vector3(-0.17, SWITCH_Y - 0.012, FRONT_Z + 0.001), _led_material(LED_POWER), "SwitchPowerLed")


func _build_router() -> void:
	var shelf := _material(Color(0.16, 0.17, 0.2), 0.4, 0.55)
	var body := _material(Color(0.12, 0.12, 0.14), 0.2, 0.45)
	_box(Vector3(0.465, 0.004, 0.3), Vector3(0, ROUTER_Y - 0.0195, 0.0), shelf, "RouterShelf")
	_box(Vector3(0.24, 0.035, 0.16), Vector3(0, ROUTER_Y, ROUTER_FRONT_Z - 0.08), body, "RouterBody")
	for side in [-1.0, 1.0]:
		var antenna := MeshInstance3D.new()
		antenna.name = "RouterAntenna"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.004
		cylinder.bottom_radius = 0.005
		cylinder.height = 0.12
		antenna.mesh = cylinder
		antenna.material_override = body
		antenna.position = Vector3(side * 0.1, ROUTER_Y + 0.0175 + 0.06, ROUTER_FRONT_Z - 0.15)
		_visual.add_child(antenna)
	_label("Router", Vector3(0.075, ROUTER_Y + 0.008, ROUTER_FRONT_Z + 0.001), 0.0002)
	_ports["router_wan"] = Vector3(-0.08, ROUTER_Y - 0.003, ROUTER_FRONT_Z)
	_label("WAN", Vector3(-0.08, ROUTER_Y + 0.0115, ROUTER_FRONT_Z + 0.001), 0.0001)
	_label("LAN", Vector3(-0.0165, ROUTER_Y + 0.0115, ROUTER_FRONT_Z + 0.001), 0.0001)
	# Blue frame marks the WAN (Internet) port, like real routers.
	_box(Vector3(0.0146, 0.0128, 0.002), Vector3(-0.08, ROUTER_Y - 0.003, ROUTER_FRONT_Z + 0.0002), _material(Color(0.15, 0.4, 0.9), 0.0, 0.5), "WanFrame")
	for i in 4:
		var x := -0.045 + i * 0.019
		_ports["router_lan%d" % (i + 1)] = Vector3(x, ROUTER_Y - 0.003, ROUTER_FRONT_Z)
		_label(str(i + 1), Vector3(x, ROUTER_Y - 0.0125, ROUTER_FRONT_Z + 0.001), 0.0001)
	_box(Vector3(0.004, 0.004, 0.002), Vector3(0.11, ROUTER_Y + 0.008, ROUTER_FRONT_Z + 0.001), _led_material(LED_POWER), "RouterPowerLed")


## One multimesh for all port openings and one for their link LEDs.
func _build_port_meshes() -> void:
	var ids := _ports.keys()
	var holes := MultiMesh.new()
	holes.transform_format = MultiMesh.TRANSFORM_3D
	var hole_mesh := BoxMesh.new()
	hole_mesh.size = PORT_SIZE
	holes.mesh = hole_mesh
	holes.instance_count = ids.size()
	_leds = MultiMesh.new()
	_leds.transform_format = MultiMesh.TRANSFORM_3D
	_leds.use_colors = true
	var led_mesh := BoxMesh.new()
	led_mesh.size = LED_SIZE
	_leds.mesh = led_mesh
	_leds.instance_count = ids.size()
	for i in ids.size():
		var id: String = ids[i]
		var at: Vector3 = _ports[id]
		_port_index[id] = i
		holes.set_instance_transform(i, Transform3D(Basis.IDENTITY, at + Vector3(0, 0, 0.0005)))
		# LED above the port, or below it on the switch's bottom row.
		var below := id.begins_with("switch_") and int(id.substr(7)) % 2 == 0
		_leds.set_instance_transform(i, Transform3D(Basis.IDENTITY, at + Vector3(0.003, -0.0072 if below else 0.0072, 0.001)))
		_leds.set_instance_color(i, LED_OFF)
	var hole_node := MultiMeshInstance3D.new()
	hole_node.name = "PortOpenings"
	hole_node.multimesh = holes
	hole_node.material_override = _material(Color(0.02, 0.02, 0.025), 0.0, 0.9)
	_visual.add_child(hole_node)
	var led_node := MultiMeshInstance3D.new()
	led_node.name = "LinkLeds"
	led_node.multimesh = _leds
	var led_material := StandardMaterial3D.new()
	led_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led_material.vertex_color_use_as_albedo = true
	led_node.material_override = led_material
	_visual.add_child(led_node)


## Level 3-6: Router LAN 1 -> switch port 1, switch port 2 -> down the wall to the teacher's PC.
func _build_installed_cables() -> void:
	patch("router_lan1", "switch_01")
	var pc: Node3D = null if teacher_port.is_empty() else get_node_or_null(teacher_port) as Node3D
	drop_to_pc("switch_02", pc, true)
	for id in ["router_lan1", "switch_01", "switch_02"]:
		set_link(id, true)
	if pc and pc.has_method("set_link"):
		pc.call("set_link", true)


## A patch cable from a Router port up to a switch port (both plugged).
func patch(router_id: String, switch_id: String, color: Color = CABLE_PATCH) -> void:
	if not _ports.has(router_id) or not _ports.has(switch_id):
		return
	plug(router_id, color)
	plug(switch_id, color)
	var r: Vector3 = _ports[router_id]
	var s: Vector3 = _ports[switch_id]
	_cable([r + Vector3(0, 0, 0.026), r + Vector3(0, 0, 0.05), Vector3(r.x, SWITCH_Y - 0.03, 0.19),
		s + Vector3(0, 0.01, 0.05), s + Vector3(0, 0, 0.026)], color, "Patch_%s_%s" % [router_id, switch_id])


## A cable from a switch port down the wall, along the floor and up behind the
## teacher's PC; plugged into its network card when `plug_pc`, otherwise the
## end lies on the desk behind the PC.
func drop_to_pc(switch_id: String, pc: Node3D, plug_pc: bool, color: Color = CABLE_PATCH) -> void:
	if not _ports.has(switch_id):
		return
	plug(switch_id, color)
	var p: Vector3 = _ports[switch_id]
	var points := [p + Vector3(0, 0, 0.026), p + Vector3(0, -0.01, 0.05), Vector3(0.262, SWITCH_Y - 0.04, 0.19),
		Vector3(0.262, -0.2, 0.12), Vector3(0.262, -0.26, 0.0), Vector3(0.262, -1.0, -0.12)]
	if pc:
		var route := teacher_pc_route(pc)
		if not plug_pc:
			# Stop on the desk behind the PC, short of the socket.
			route = route.slice(0, 4)
			route.append(route[3] + Vector3(0, 0, -0.08))
		elif pc.has_method("plug"):
			pc.call("plug", color)
		for point in route:
			points.append(to_local(point))
	var old := _visual.get_node_or_null("CableToTeacherPC")
	if old:
		old.free()
	_cable(points, color, "CableToTeacherPC")


## The player plugged into WAN: the Internet line is pulled out and hangs
## loose in front of the rack (no Internet for the room any more).
func disconnect_internet() -> void:
	_internet = false
	unplug("router_wan")
	set_link("router_wan", false)
	var line := _visual.get_node_or_null("InternetLine")
	if line:
		line.free()
	_cable([Vector3(-0.262, 1.5, -0.05), Vector3(-0.262, 0.26, 0.0), Vector3(-0.262, 0.2, 0.12),
		Vector3(-0.24, -0.1, 0.2), Vector3(-0.2, -0.3, 0.22)], CABLE_INTERNET, "InternetLine")


## False once the Internet line was pulled out of WAN (disconnect_internet).
func is_internet_connected() -> bool:
	return _internet


## The glass door is hidden while the player works inside the rack.
func set_door_open(open: bool) -> void:
	for part in ["DoorGlass", "DoorFrame", "Handle"]:
		for node in _visual.get_children():
			if node.name.begins_with(part):
				(node as Node3D).visible = not open


## Camera pose in front of the open rack, the devices on the left part of the
## screen (a panel covers the right).
func view_transform() -> Transform3D:
	var eye := global_transform * Vector3(0.11, 0.03, 0.46)
	var target := global_transform * Vector3(0.11, 0.03, 0.0)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


## World points from the bottom of the rack, down the wall, along the floor
## under the teacher's desk and up behind the PC to its network port.
func teacher_pc_route(pc: Node3D) -> Array:
	var bottom := global_transform * Vector3(0.262, -1.0, -0.12)
	var port: Vector3 = pc.call("cable_start") if pc.has_method("cable_start") else pc.global_position
	var floor_y := 0.03
	var desk_edge_z := port.z + 0.19 # just past the back edge of the desk
	return [Vector3(bottom.x, floor_y, bottom.z), Vector3(port.x, floor_y, bottom.z),
		Vector3(port.x, floor_y, desk_edge_z), Vector3(port.x, 0.77, desk_edge_z),
		Vector3(port.x, port.y - 0.01, port.z + 0.04), port]


## A cable through `points` (rack-local).
func _cable(points: Array, color: Color, cable_name: String) -> void:
	_visual.add_child(CableBuilder.build(points, color, cable_name))


func _label(text: String, position: Vector3, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.font_size = 64
	label.outline_size = 0
	label.modulate = Color(0.85, 0.88, 0.92)
	label.position = position
	label.double_sided = false
	_visual.add_child(label)


func _box(size: Vector3, position: Vector3, material: Material, part_name: String) -> void:
	_box_in(_visual, size, position, material, part_name)


func _box_in(parent: Node, size: Vector3, position: Vector3, material: Material, part_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)


static func _led_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m
