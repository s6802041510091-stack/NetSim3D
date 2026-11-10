class_name NetworkPort
extends Node3D

## One RJ45 socket on a device (e.g. the network card on the back of the
## teacher's PC) with its link LED. Faces local +Z. A mission plugs a cable in
## with plug() and turns the LED on with set_link().

const OPENING := Vector3(0.0116, 0.0098, 0.004)
const LED_ON := Color(0.25, 1.0, 0.35)
const LED_OFF := Color(0.08, 0.1, 0.09)

@export var port_id := "teacher_pc_nic"
@export var label_text := "LAN"

var link_on := false
var plugged := false
var _led: MeshInstance3D
var _led_material: StandardMaterial3D
var _plug: Node3D


func _ready() -> void:
	var plate := _box(Vector3(0.024, 0.022, 0.002), Vector3(0, 0, -0.001), _material(Color(0.62, 0.64, 0.68), 0.6, 0.4))
	plate.name = "Plate"
	var hole := _box(OPENING, Vector3(0, 0, 0.0005), _material(Color(0.02, 0.02, 0.025), 0.0, 0.9))
	hole.name = "Opening"
	_led_material = StandardMaterial3D.new()
	_led_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_led = _box(Vector3(0.003, 0.0022, 0.002), Vector3(0.0045, 0.0072, 0.0005), _led_material)
	_led.name = "LinkLed"
	set_link(link_on)
	if label_text != "":
		var label := Label3D.new()
		label.text = label_text
		label.pixel_size = 0.0001
		label.font_size = 64
		label.modulate = Color(0.15, 0.16, 0.2)
		label.position = Vector3(0, -0.0095, 0.0005)
		add_child(label)


func set_link(on: bool) -> void:
	link_on = on
	if _led_material:
		_led_material.albedo_color = LED_ON if on else LED_OFF


## Shows an RJ45 plug with a coloured boot in the socket.
func plug(boot_color: Color = Color(0.16, 0.42, 0.85)) -> void:
	if plugged:
		return
	plugged = true
	_plug = Node3D.new()
	_plug.name = "Plug"
	add_child(_plug)
	var clear := _material(Color(0.85, 0.9, 0.95, 0.55), 0.0, 0.2)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(0.0112, 0.0082, 0.012), Vector3(0, 0, 0.002), clear, _plug)
	_box(Vector3(0.0128, 0.0108, 0.02), Vector3(0, 0, 0.017), _material(boot_color, 0.0, 0.6), _plug)


func unplug() -> void:
	plugged = false
	if _plug:
		_plug.queue_free()
		_plug = null


## Where a cable leaves the plug (world space).
func cable_start() -> Vector3:
	return global_transform * Vector3(0, 0, 0.027)


func _box(size: Vector3, position: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)
	return mesh


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m
