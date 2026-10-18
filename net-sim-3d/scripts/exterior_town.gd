extends Node3D

## Visual-only district around the third-floor school. It never replaces the
## playable school's colliders, mission objects, camera, or input handling.
const GROUND_Y := -7.2
const TOWN_SCENE := "res://assets/exterior/town.glb"
const BUILDING_SCENE := "res://assets/exterior/japanese_buildings.glb"
const LAYOUT := "res://assets/exterior/japanese_layout.json"
const PANORAMA := "res://assets/exterior/town_panorama_v1.png"

var people: Array[Dictionary] = []
var _box_mesh := BoxMesh.new()
var _head_mesh := SphereMesh.new()
var _wheel_mesh := TorusMesh.new()


func _ready() -> void:
	var town_resource := load(TOWN_SCENE) as PackedScene
	var building_resource := load(BUILDING_SCENE) as PackedScene
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if town_resource == null or building_resource == null or not parsed is Dictionary:
		push_error("Exterior town assets could not be loaded")
		return
	var layout: Dictionary = parsed
	var town := town_resource.instantiate() as Node3D
	town.name = "CampusAndGround"
	add_child(town)
	_apply_horizon(town)
	_add_buildings(building_resource, layout)
	_apply_sky()
	_add_sun()
	_head_mesh.radial_segments = 8
	_head_mesh.rings = 4
	_wheel_mesh.inner_radius = 0.26
	_wheel_mesh.outer_radius = 0.34
	_wheel_mesh.rings = 12
	_wheel_mesh.ring_segments = 6
	for i in range(20):
		_make_person(i, i >= 14)


func _apply_horizon(town: Node3D) -> void:
	var ground := town.find_child("*Spring*", true, false) as MeshInstance3D
	if ground == null:
		push_error("Exterior spring ground was not found")
		return
	var original := ground.get_active_material(0) as StandardMaterial3D
	if original == null or original.albedo_texture == null:
		push_error("Exterior ground texture was not imported")
		return
	var horizon := ShaderMaterial.new()
	horizon.shader = load("res://assets/exterior/horizon_ground.gdshader")
	horizon.set_shader_parameter("grass", original.albedo_texture)
	horizon.set_shader_parameter("panorama", load(PANORAMA))
	ground.material_override = horizon


func _add_buildings(building_resource: PackedScene, layout: Dictionary) -> void:
	var library := building_resource.instantiate() as Node3D
	var district := Node3D.new()
	district.name = "JapaneseStreets_CC_BY_4_0"
	add_child(district)
	var count := 0
	for placement in layout.get("placements", []):
		var prototype := library.find_child(placement.prototype, true, false) as Node3D
		if prototype == null:
			push_error("Missing Japanese building prototype: " + str(placement.prototype))
			continue
		var building := prototype.duplicate() as Node3D
		district.add_child(building)
		building.position = Vector3(placement.position[0], placement.position[2], -placement.position[1])
		building.rotation.y = placement.rotation
		count += 1
	library.free()
	if count != int(layout.get("instance_count", -1)):
		push_error("Exterior building count mismatch: %d" % count)
	set_meta("building_count", count)


func _apply_sky() -> void:
	var world := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world == null:
		push_error("Main scene WorldEnvironment was not found")
		return
	var environment := world.environment.duplicate() as Environment
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/exterior/town_backdrop.gdshader")
	material.set_shader_parameter("panorama", load(PANORAMA))
	sky.sky_material = material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.80, 0.88, 1.0)
	environment.ambient_light_energy = 0.35
	world.environment = environment


func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ExteriorSun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.94, 0.83)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230.0
	add_child(sun)


func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result


func _shape(parent: Node3D, size: Vector3, position: Vector3, surface: Material, sphere: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _head_mesh if sphere else _box_mesh
	node.scale = size
	node.position = position
	node.material_override = surface
	parent.add_child(node)
	return node


func _make_person(index: int, bike: bool) -> void:
	var person := Node3D.new()
	person.name = "Cyclist_%02d" % index if bike else "Walker_%02d" % index
	add_child(person)
	var skin := _material(Color(0.94, 0.71, 0.54))
	var colors := [Color(0.18, 0.29, 0.48), Color(0.97, 0.69, 0.68), Color(0.72, 0.85, 0.89), Color(0.94, 0.90, 0.73)]
	var clothes := _material(colors[index % 4])
	var dark := _material(Color(0.13, 0.16, 0.23))
	_shape(person, Vector3(0.38, 0.60, 0.24), Vector3(0, 1.12, 0), clothes)
	_shape(person, Vector3(0.30, 0.34, 0.30), Vector3(0, 1.61, 0), skin, true)
	_shape(person, Vector3(0.32, 0.17, 0.32), Vector3(0, 1.73, 0.02), dark, true)
	var limbs: Array[Node3D] = []
	for x in [-0.12, 0.12]:
		var leg := Node3D.new()
		person.add_child(leg)
		leg.position = Vector3(x, 0.83, 0)
		_shape(leg, Vector3(0.13, 0.66, 0.15), Vector3(0, -0.33, 0), dark)
		limbs.append(leg)
	for x in [-0.26, 0.26]:
		var arm := Node3D.new()
		person.add_child(arm)
		arm.position = Vector3(x, 1.36, 0)
		_shape(arm, Vector3(0.12, 0.50, 0.12), Vector3(0, -0.25, 0), clothes)
		limbs.append(arm)
	var wheels: Array[MeshInstance3D] = []
	if bike:
		var frame := _material(Color(0.87, 0.39, 0.29))
		_shape(person, Vector3(0.10, 0.10, 1.1), Vector3(0, 0.49, 0), frame)
		_shape(person, Vector3(0.08, 0.55, 0.08), Vector3(0, 0.58, -0.5), frame)
		_shape(person, Vector3(0.6, 0.07, 0.08), Vector3(0, 0.9, -0.5), dark)
		for z in [-0.52, 0.52]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = _wheel_mesh
			wheel.material_override = dark
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(0, 0.34, z)
			person.add_child(wheel)
			wheels.append(wheel)
	people.append({"node": person, "distance": index * 21.4, "speed": 3.2 if bike else 1.2, "bike": bike, "limbs": limbs, "wheels": wheels})
	_update_people(0.0)


func _route(distance: float, bike: bool) -> Vector3:
	var points := [Vector3(-46.5, GROUND_Y + 0.25, 36.5), Vector3(49.5, GROUND_Y + 0.25, 36.5), Vector3(49.5, GROUND_Y + 0.25, -70.5), Vector3(-46.5, GROUND_Y + 0.25, -70.5)]
	if bike:
		points = [Vector3(-50, GROUND_Y + 0.06, 39.5), Vector3(53, GROUND_Y + 0.06, 39.5), Vector3(53, GROUND_Y + 0.06, -74), Vector3(-50, GROUND_Y + 0.06, -74)]
	var total := 0.0
	for i in range(4):
		total += points[i].distance_to(points[(i + 1) % 4])
	var remaining := fposmod(distance, total)
	for i in range(4):
		var length: float = points[i].distance_to(points[(i + 1) % 4])
		if remaining <= length:
			return points[i].lerp(points[(i + 1) % 4], remaining / length)
		remaining -= length
	return points[0]


func _update_people(delta: float) -> void:
	for person in people:
		person.distance += person.speed * delta
		var node: Node3D = person.node
		node.position = _route(person.distance, person.bike)
		node.look_at(_route(person.distance + 0.1, person.bike), Vector3.UP)
		for i in range(4):
			person.limbs[i].rotation.x = sin(person.distance * (3.0 if person.bike else 5.0) + i * PI) * (0.3 if person.bike else 0.45)
			if person.bike and i >= 2:
				person.limbs[i].rotation.x = -0.9
		for wheel in person.wheels:
			wheel.rotation.y = person.distance / 0.3


func _process(delta: float) -> void:
	_update_people(delta)
