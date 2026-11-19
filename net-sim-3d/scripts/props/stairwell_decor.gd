class_name StairwellDecor
extends Node3D

## Finishes for the stairwell (the map model gives plain grey stone steps,
## bare aluminium rails and blank walls). Visual only: nothing here collides.
## Design "A, classic terrazzo", chosen by the user on 2026-11-19 from three
## in-game previews:
##  * Steps, landings and stairwell floors: polished terrazzo (หินขัด).
##  * Dark anti-slip strips on the step edges.
##  * Wooden handrails on navy-painted balusters and posts (the aluminium
##    reflected the sky blue on some rails and the walls green on others).
##  * Two-tone walls: a blue-grey band up to dado height with a navy rail.
##  * Floor number and safety signs on the main landing.
## The landing's ceiling light is in CeilingLights (EXTRA_PANELS).

## Inner wall faces beside the flights and the stairwell's two ends (x).
const NORTH_FACE := -30.44
const SOUTH_FACE := -24.17
const EAST_END := -9.26
const WEST_END := -21.16
## Floor heights the stairwell serves: below, the corridor's, above.
const FLOORS := [-3.35, 0.0, 3.35]
const DADO := 1.0 # painted band height above each floor (m)
const RAIL_H := 0.06 # the dado rail on top of the band

const TERRAZZO := Color(0.80, 0.78, 0.74)
const CHIPS := [Color(0.55, 0.53, 0.5), Color(0.92, 0.91, 0.88), Color(0.42, 0.45, 0.48)]
const NAVY := Color(0.16, 0.25, 0.36)

var _tools := {} # material key -> SurfaceTool
var _materials := {}


func _ready() -> void:
	var visual := get_parent().get_node_or_null("MapVisual")
	if visual == null:
		push_error("StairwellDecor: MapVisual not found")
		return
	_make_materials()
	for child in visual.get_children():
		var mesh := child as MeshInstance3D
		var n := String(child.name)
		if mesh and (n.begins_with("Stair_") or n.begins_with("StairShell_")):
			var finish := _material_for(n)
			if finish:
				mesh.material_override = finish
	for floor_y: float in FLOORS:
		_wall_band(floor_y)
	_signs()
	_commit()


## This design's material for a stairwell piece, or null to keep the map's.
func _material_for(mesh_name: String) -> Material:
	if mesh_name.contains("Nosing"):
		return _materials["nosing"]
	if mesh_name.contains("Handrail") or mesh_name.contains("Landing_Rail") or mesh_name.contains("End_Rail") \
			or (mesh_name.contains("UpperGuard_") and not mesh_name.contains("Post")):
		return _materials["handrail"]
	if mesh_name.contains("Baluster") or mesh_name.contains("Post") or mesh_name.contains("Midrail"):
		return _materials["post"]
	if mesh_name.contains("Underside"):
		return _materials["plaster"]
	# Walls keep the school's paint (the men's restroom shares one of them);
	# the upper floor slabs are the ceiling over the landing and the flight down.
	if mesh_name.contains("Wall") or mesh_name.contains("Portal") or mesh_name.contains("Partition") \
			or mesh_name.contains("Roof") or mesh_name.contains("UpperFloor"):
		return null
	return _materials["terrazzo"] # steps, landings, floors, edge strips


## Band up to DADO and a rail on top, on the north and south walls, from the
## corridor end to the far wall, on the floor at height `floor_y`.
func _wall_band(floor_y: float) -> void:
	var length := EAST_END - WEST_END
	var mid_x := (EAST_END + WEST_END) * 0.5
	for side in [[NORTH_FACE, 1.0], [SOUTH_FACE, -1.0]]:
		var z: float = side[0] + 0.006 * side[1]
		_box("wall_low", Vector3(length, DADO, 0.004), Vector3(mid_x, floor_y + DADO * 0.5, z))
		_box("wall_rail", Vector3(length, RAIL_H, 0.02), Vector3(mid_x, floor_y + DADO + RAIL_H * 0.5, z + 0.008 * side[1]))


## Floor number beside the flight up; safety signs on both landing walls.
func _signs() -> void:
	_plate("ชั้น 2", Vector3(-9.95, 2.05, NORTH_FACE + 0.02), 0.0, Vector2(0.62, 0.3), 96, "sign_navy", Color.WHITE)
	_plate("ขึ้น-ลงบันได\nชิดซ้าย", Vector3(-10.75, 1.55, NORTH_FACE + 0.02), 0.0, Vector2(0.5, 0.36), 52, "sign_white", NAVY)
	_plate("ห้ามวิ่งเล่น\nบนบันได", Vector3(-10.4, 1.55, SOUTH_FACE - 0.02), PI, Vector2(0.5, 0.36), 52, "sign_white", Color(0.7, 0.14, 0.12))


func _plate(text: String, at: Vector3, yaw: float, size: Vector2, font_size: int, key: String, ink: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	_box(key, Vector3(size.x, size.y, 0.02), at, basis)
	var label := Label3D.new()
	label.name = "Sign"
	label.text = text
	label.font = GameUI.FONT_BOLD
	label.font_size = font_size
	label.pixel_size = 0.0016
	label.outline_size = 0
	label.modulate = ink
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.double_sided = false
	label.position = at + basis * Vector3(0, 0, 0.012)
	label.rotation.y = yaw
	add_child(label)


func _box(key: String, size: Vector3, at: Vector3, basis := Basis.IDENTITY) -> void:
	var box := BoxMesh.new()
	box.size = size
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	(_tools[key] as SurfaceTool).append_from(box, 0, Transform3D(basis, at))


## One mesh per material, no shadows (thin paint and plates).
func _commit() -> void:
	for key: String in _tools:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh_" + key
		mesh.mesh = (_tools[key] as SurfaceTool).commit()
		mesh.material_override = _materials[key]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	_tools.clear()


func _make_materials() -> void:
	var plain := func(color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		return m
	_materials["terrazzo"] = _terrazzo()
	_materials["nosing"] = plain.call(Color(0.14, 0.15, 0.16), 0.6)
	_materials["handrail"] = plain.call(Color(0.52, 0.33, 0.18), 0.45)
	_materials["post"] = plain.call(NAVY, 0.4, 0.2)
	_materials["plaster"] = plain.call(Color(0.86, 0.87, 0.86), 0.9)
	_materials["wall_low"] = plain.call(Color(0.62, 0.70, 0.76), 0.75)
	_materials["wall_rail"] = plain.call(NAVY, 0.5)
	_materials["sign_navy"] = plain.call(Color(0.13, 0.24, 0.38), 0.5)
	_materials["sign_white"] = plain.call(Color(0.97, 0.97, 0.95), 0.5)


## Polished terrazzo: light cement with small stone chips, laid in world
## space so every step and landing matches.
func _terrazzo() -> StandardMaterial3D:
	var px := 128
	var image := Image.create(px, px, false, Image.FORMAT_RGB8)
	image.fill(TERRAZZO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	for i in 650:
		var chip: Color = CHIPS[rng.randi() % CHIPS.size()]
		var size := rng.randi_range(1, 3)
		image.fill_rect(Rect2i(rng.randi() % px, rng.randi() % px, size, size), chip.lerp(TERRAZZO, rng.randf() * 0.4))
	image.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = 0.32
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
