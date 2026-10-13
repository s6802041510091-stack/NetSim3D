class_name ComputerStation
extends StaticBody3D

## One usable computer. Created at start-up by ComputerManager for every
## monitor screen in the map model. The player looks at the screen and presses
## E to sit down and use it.

## Computers live on physics layer 4 so they never block walking.
const COLLISION_LAYER := 8
const META_KEY := &"interactable"
const SCREEN_SIZE := Vector3(0.54, 0.31, 0.04)

var manager: Node
var screen: MeshInstance3D
var hostname := "PC"
var ip_address := "192.168.1.10"
var subnet_mask := "255.255.255.0"
var gateway := "192.168.1.1"
var dns_server := "8.8.8.8"
var mac_address := "00-1A-2B-00-00-01"
## Missions can unplug a computer's LAN cable by setting this to false.
var network_connected := true
## Programs installed on this computer (desktop icons). Set by ComputerManager.
var installed_apps := PackedStringArray(["network_designer"])

## True while this computer shows a security warning (Mission 5 target):
## its screen glows red in the room and the desktop pops up a warning.
var screen_alert := false

var _screen_on_material: StandardMaterial3D
var _screen_alert_material: StandardMaterial3D


func setup(p_manager: Node, p_screen: MeshInstance3D) -> void:
	manager = p_manager
	screen = p_screen
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	set_meta(META_KEY, self)
	global_transform = screen.global_transform.orthonormalized()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SCREEN_SIZE
	shape.shape = box
	shape.position = screen.get_aabb().get_center()
	add_child(shape)


func has_app(app_id: String) -> bool:
	return app_id in installed_apps


func get_prompt_text() -> String:
	return "กด E เพื่อใช้งานคอมพิวเตอร์ (%s)" % hostname


func use(player: Node) -> void:
	manager.open_computer(self, player)


## Camera pose that fills the view with this screen.
func get_view_transform(fov_degrees: float) -> Transform3D:
	var aabb := screen.get_aabb()
	var center := screen.global_transform * aabb.get_center()
	var normal := screen.global_basis.z.normalized() # The viewer side of the screen.
	var height := aabb.size.y * screen.global_basis.get_scale().y
	var distance := (height * 0.5) / tan(deg_to_rad(fov_degrees) * 0.5) * 1.05
	var eye := center + normal * distance
	return Transform3D(Basis.looking_at(center - eye, Vector3.UP), eye)


func set_screen_on(on: bool) -> void:
	if on:
		if _screen_on_material == null:
			_screen_on_material = StandardMaterial3D.new()
			_screen_on_material.albedo_color = Color(0.05, 0.25, 0.55)
			_screen_on_material.emission_enabled = true
			_screen_on_material.emission = Color(0.12, 0.45, 0.9)
			_screen_on_material.emission_energy_multiplier = 1.2
		screen.material_override = _screen_on_material
	else:
		screen.material_override = _alert_material() if screen_alert else null


## Turns the red "security warning" screen on or off (Mission 5).
func set_screen_alert(on: bool) -> void:
	screen_alert = on
	if screen == null:
		return # Test benches use a computer without a 3D screen.
	if screen.material_override != _screen_on_material or _screen_on_material == null:
		screen.material_override = _alert_material() if on else null


func _alert_material() -> StandardMaterial3D:
	if _screen_alert_material == null:
		_screen_alert_material = StandardMaterial3D.new()
		_screen_alert_material.albedo_color = Color(0.45, 0.05, 0.05)
		_screen_alert_material.emission_enabled = true
		_screen_alert_material.emission = Color(0.9, 0.12, 0.1)
		_screen_alert_material.emission_energy_multiplier = 1.4
	return _screen_alert_material


static func from_collider(collider: Object) -> ComputerStation:
	if collider != null and collider.has_meta(META_KEY):
		return collider.get_meta(META_KEY) as ComputerStation
	return null
