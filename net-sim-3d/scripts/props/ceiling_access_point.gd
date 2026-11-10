class_name CeilingAccessPoint
extends Node3D

## The Wireless Access Point on the ceiling in the middle of the computer room
## (install point 3 of Mission 1). Installed from Level 2 on, following the
## story (GameFlow.configure_level sets `installed`). A white disc with a
## status LED ring, built from three meshes so it costs almost nothing.

const RADIUS := 0.11
const THICKNESS := 0.034
const LED := Color(0.35, 0.75, 1.0)

@export var installed := false:
	set(value):
		installed = value
		visible = value


func _ready() -> void:
	visible = installed
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.96)
	white.roughness = 0.35
	_disc("MountPlate", RADIUS * 0.75, 0.008, -0.004, white)
	_disc("Body", RADIUS, THICKNESS, -0.008 - THICKNESS * 0.5, white)
	var led := StandardMaterial3D.new()
	led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led.albedo_color = LED
	var ring := MeshInstance3D.new()
	ring.name = "StatusLed"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.016
	torus.outer_radius = 0.02
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = led
	ring.position = Vector3(0, -0.008 - THICKNESS - 0.0005, 0)
	add_child(ring)


func _disc(part_name: String, radius: float, height: float, y: float, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 0.96
	cylinder.height = height
	cylinder.radial_segments = 32
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = Vector3(0, y, 0)
	add_child(mesh)
