@tool
class_name Restrooms
extends Node3D

## The women's and men's restrooms beside the corridor (the rooms in the map
## are empty shells: floor, ceiling, lights, doors). Built here in code, low
## detail but laid out like a Thai school restroom:
## Both rooms have six north-wall cubicles and two four-basin counters on
## the south wall. Men's urinals occupy the west wall. The entrance privacy
## wall joins the south wall and ceiling, with access around its north end.
## Seated (western) toilets with a bidet sprayer and a paper roll; stall doors
## are interactive with F. Half-height wall tiles
## and floor tiles. Everything with the same material is merged into one mesh
## (cheap for the Web); fixtures the player could walk into get box colliders.

## Inner faces of the rooms' walls (world space, from the map).
const WEST := -21.16
const EAST := -9.26
const F_SOUTH := -16.93 # women's: partition to the men's room
const F_NORTH := -9.90
const M_SOUTH := -24.02 # men's: partition to the stairwell
const M_NORTH := -17.08
## Door openings on the corridor (east) wall: z from, z to.
const F_DOOR := Vector2(-15.53, -14.49)
const M_DOOR := Vector2(-23.32, -22.28)

const STALL_W := 1.2
const STALL_D := 2.35
const STALL_H := 1.85
const STALL_GAP := 0.12 # open under the partitions
const PANEL_T := 0.025
const DOOR_W := 0.78
const TILE_H := 1.6 # wall tiles up to here
const TOILET=preload("res://assets/models/restrooms/school_toilet.glb")
const BASIN=preload("res://assets/models/restrooms/school_basin.glb")
const URINAL=preload("res://assets/models/restrooms/school_urinal.glb")
const STALL_SCRIPT=preload("res://scripts/props/restroom_stall_door.gd")

var _tools := {} # material key -> SurfaceTool
var _materials := {}
var _mesh_cache := {}
var _body: StaticBody3D
var stall_doors:Array[RestroomStallDoor]=[]
var _fixture_cache:Dictionary={}


func _ready() -> void:
	name = "Restrooms"
	# Generated children are previewable in the editor, but are not saved as
	# duplicate scene data when main.tscn is saved.
	for child in get_children():
		if child.get_meta("restroom_generated",false):child.free()
	_tools.clear();_materials.clear();_mesh_cache.clear();stall_doors.clear()
	_make_materials()
	_body = StaticBody3D.new()
	_body.name = "Colliders"
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.set_meta("restroom_generated",true)
	add_child(_body)
	_build_womens()
	_build_mens()
	_commit()
	_light(Vector3(-15.2,2.65,-13.5))
	_light(Vector3(-15.2,2.65,-20.5))


# ------------------------------------------------------------------ rooms

func _build_womens() -> void:
	_room_finish(F_SOUTH, F_NORTH, F_DOOR,"women_trim")
	# Six stalls along the north wall, doors to the south.
	for i in 6:
		var x0 := WEST + i * STALL_W
		_stall(Vector3(x0 + STALL_W * 0.5, 0.0, F_NORTH), 0.0, i == 0, i == 5, i+1, true)
	# Basin counter on the partition wall, mirror above.
	_basins(Vector3(-13.0, 0.0, F_SOUTH), 0.0, 4)
	_basins(Vector3(-17.8, 0.0, F_SOUTH), 0.0, 4)
	_towels_and_bin(Vector3(-15.15, 0.0, F_SOUTH), 0.0)
	_screen(F_SOUTH,F_DOOR,"women_trim")
	_closet_door(Vector3(WEST, 0.0, -16.15), PI * 0.5)
	_sign("กรุณาล้างมือทุกครั้ง", Vector3(-13.0, 2.12, F_SOUTH + 0.02), 0.0)


func _build_mens() -> void:
	_room_finish(M_SOUTH, M_NORTH, M_DOOR,"tile_trim")
	# Match the women's cubicle orientation and number.
	for i in 6:
		var x0 := WEST + i * STALL_W
		_stall(Vector3(x0 + STALL_W * 0.5, 0.0, M_NORTH), 0.0, i == 0, i == 5, i+1, false)
	# Six urinals fit the remaining west wall, clear of the cubicle frontage.
	for i in 6:
		_urinal(Vector3(WEST, 0.0, M_SOUTH + 0.4 + i * 0.7), -PI * 0.5, i > 0)
	_basins(Vector3(-13.0, 0.0, M_SOUTH), 0.0, 4)
	_basins(Vector3(-17.8, 0.0, M_SOUTH), 0.0, 4)
	_towels_and_bin(Vector3(-15.15, 0.0, M_SOUTH), 0.0)
	_screen(M_SOUTH,M_DOOR)
	_closet_door(Vector3(-20.3, 0.0, M_SOUTH), 0.0)
	_sign("กรุณาล้างมือทุกครั้ง", Vector3(-13.0, 2.12, M_SOUTH + 0.02), 0.0)


## Floor tiles and the tiled band on all four walls (around the door).
func _room_finish(south: float, north: float, door: Vector2, trim:="tile_trim") -> void:
	var w := EAST - WEST
	var d := north - south
	_box("floor", Vector3(w, 0.006, d), Vector3((WEST + EAST) * 0.5, 0.003, (south + north) * 0.5))
	var t := 0.012
	_box("wall_tile", Vector3(w, TILE_H, t), Vector3((WEST + EAST) * 0.5, TILE_H * 0.5, south + t * 0.5))
	_box("wall_tile", Vector3(w, TILE_H, t), Vector3((WEST + EAST) * 0.5, TILE_H * 0.5, north - t * 0.5))
	_box("wall_tile", Vector3(t, TILE_H, d), Vector3(WEST + t * 0.5, TILE_H * 0.5, (south + north) * 0.5))
	# East wall: tiles on both sides of the door opening.
	_box("wall_tile", Vector3(t, TILE_H, door.x - south), Vector3(EAST - t * 0.5, TILE_H * 0.5, (south + door.x) * 0.5))
	_box("wall_tile", Vector3(t, TILE_H, north - door.y), Vector3(EAST - t * 0.5, TILE_H * 0.5, (door.y + north) * 0.5))
	# A coloured border line on top of the tiles.
	for z in [south + t, north - t]:
		_box(trim, Vector3(w, 0.05, 0.016), Vector3((WEST + EAST) * 0.5, TILE_H + 0.025, z))
	_box(trim, Vector3(0.016, 0.05, d), Vector3(WEST + t, TILE_H + 0.025, (south + north) * 0.5))
	for span in [Vector2(south,door.x),Vector2(door.y,north)]:
		_box(trim,Vector3(.016,.05,span.y-span.x),Vector3(EAST-t,TILE_H+.025,(span.x+span.y)*.5))
	# Ceiling extractor grilles; no exterior windows in the restrooms.
	for x in [-16.8,-12.7]:
		_box("dispenser",Vector3(.44,.025,.44),Vector3(x,3.16,(south+north)/2))
		for i in 8:
			_box("dark",Vector3(.34,.008,.013),Vector3(x,3.142,(south+north)/2-.14+i*.04))


## One toilet stall against a wall. `at` = middle of the stall where it meets
## the back wall; `yaw` turns the stall (0 = back wall at +Z... facing -Z).
func _stall(at: Vector3, yaw: float, first: bool, last: bool, number:int, sanitary_bin: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var place := func(local: Vector3) -> Vector3: return at + b * local
	# Side partitions (shared between neighbours: draw the left one always,
	# the right one only on the last stall).
	for side in ([-1.0, 1.0] if last else [-1.0]):
		var x: float = side * STALL_W * 0.5
		if side < 0.0 and first:
			x = -STALL_W * 0.5 + PANEL_T * 0.5 # against the room's side wall: a thin panel
		_box("partition", Vector3(PANEL_T, STALL_H, STALL_D), place.call(Vector3(x, STALL_GAP + STALL_H * 0.5, -STALL_D * 0.5)), b, true)
	# Front: two pilasters either side of the door, a top rail.
	var pil := (STALL_W - DOOR_W) * 0.5
	for side in [-1.0, 1.0]:
		var cx: float = side * (STALL_W * 0.5 - pil * 0.5)
		_box("partition", Vector3(pil, STALL_H + STALL_GAP, PANEL_T), place.call(Vector3(cx, (STALL_H + STALL_GAP) * 0.5, -STALL_D)), b, true)
	_box("partition", Vector3(DOOR_W, 0.08, PANEL_T), place.call(Vector3(0.0, STALL_GAP + STALL_H - 0.04, -STALL_D)), b)
	# The cubicle door is a separate moving collider, usable from both sides.
	var hinge := Vector3(-DOOR_W * 0.5, 0.0, -STALL_D)
	var door:=Node3D.new()
	door.set_script(STALL_SCRIPT)
	door.name=("WomenStall" if sanitary_bin else "MenStall")+"%02d"%number
	door.transform=Transform3D(b,place.call(hinge))
	door.set("number",number);door.set("width",DOOR_W)
	door.set("height",STALL_H-.1);door.set("gap",STALL_GAP)
	door.set("material",_materials["women_door" if sanitary_bin else "stall_door"])
	door.set("start_open",number==1)
	door.set_meta("restroom_generated",true)
	add_child(door)
	stall_doors.append(door as RestroomStallDoor)
	# The toilet against the back wall, facing the door.
	_toilet(place.call(Vector3(0.0, 0.0, 0.0)), b)
	# Paper roll and bidet sprayer on the side partition.
	_cylinder("white", 0.055, 0.1, place.call(Vector3(STALL_W * 0.5 - 0.06, 0.72, -0.62)), b * Basis(Vector3.BACK, PI * 0.5))
	_cylinder("dark",.017,.002,place.call(Vector3(STALL_W*.5-.111,.72,-.62)),b*Basis(Vector3.BACK,PI*.5))
	_box("chrome", Vector3(0.03, 0.08, 0.06), place.call(Vector3(STALL_W * 0.5 - 0.03, 0.72, -0.62)), b)
	if sanitary_bin:
		var bin_at:Vector3=place.call(Vector3(STALL_W*.5-.16,.15,-1.05))
		_cylinder("bin",.11,.3,bin_at,b)
		_collider(Vector3(.22,.3,.22),bin_at,b)


## Seated toilet: tank on the wall, bowl and seat in front (local: wall at
## z = 0, toilet toward -Z).
func _toilet(at: Vector3, b: Basis) -> void:
	_fixture(TOILET,Transform3D(b*Basis(Vector3.UP,PI),at+b*Vector3(0,0,-.39)))
	_collider(Vector3(.46,.82,.74),at+b*Vector3(0,.41,-.39),b)


## A wall urinal (`at` on the wall, yaw 0: the room is at -Z); `divider`
## adds a privacy panel on its left.
func _urinal(at: Vector3, yaw: float, divider: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var place := func(local: Vector3) -> Vector3: return at + b * local
	_fixture(URINAL,Transform3D(b*Basis(Vector3.UP,PI),at))
	_collider(Vector3(.42,.69,.27),place.call(Vector3(0,.77,-.135)),b)
	if divider:
		_box("partition", Vector3(0.025, 0.85, 0.45), place.call(Vector3(-0.35, 1.0, -0.23)), b, true)


## A counter of `count` basins against a wall, a mirror above. `at` = middle
## where it meets the wall; yaw 0: the room is at +Z of the wall.
func _basins(at: Vector3, yaw: float, count: int) -> void:
	var b := Basis(Vector3.UP, yaw)
	var place := func(local: Vector3) -> Vector3: return at + b * local
	var length := count * 0.8
	var depth := 0.55
	_box("counter", Vector3(length, 0.05, depth), place.call(Vector3(0.0, 0.825, depth * 0.5)), b)
	_box("counter", Vector3(length, 0.16, 0.03), place.call(Vector3(0.0, 0.72, depth - 0.015)), b)
	for side in [-1.0, 1.0]:
		_box("counter", Vector3(0.04, 0.8, depth - 0.02), place.call(Vector3(side * (length * 0.5 - 0.02), 0.4, depth * 0.5)), b)
	# One collider for the whole counter.
	_collider(Vector3(length, 0.85, depth), place.call(Vector3(0.0, 0.425, depth * 0.5)), b)
	for i in count:
		var x := (i - (count - 1) * 0.5) * 0.8
		_fixture(BASIN,Transform3D(b,place.call(Vector3(x,.85,.28))))
		# Soap dispenser on the wall between basins.
		if i < count - 1:
			_box("dispenser", Vector3(0.1, 0.18, 0.08), place.call(Vector3(x + 0.4, 1.12, 0.05)), b)
	_box("mirror", Vector3(length - 0.1, 0.85, 0.012), place.call(Vector3(0.0, 1.55, 0.015)), b)
	_box("chrome", Vector3(length - 0.06, 0.03, 0.02), place.call(Vector3(0.0, 1.11, 0.02)), b)
	_box("chrome",Vector3(length-.06,.025,.024),place.call(Vector3(0,1.982,.02)),b)
	for side in [-1.0,1.0]:
		_box("chrome",Vector3(.025,.85,.024),place.call(Vector3(side*(length-.075)/2,1.55,.02)),b)


## Paper towel dispenser on the wall and a bin under it.
func _towels_and_bin(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	_box("dispenser", Vector3(0.3, 0.38, 0.12), at + b * Vector3(0.0, 1.3, 0.06), b)
	_box("dark", Vector3(0.2, 0.02, 0.02), at + b * Vector3(0.0, 1.12, 0.11), b)
	_cylinder("bin", 0.18, 0.55, at + b * Vector3(0.0, 0.275, 0.24), b)
	_collider(Vector3(0.36, 0.55, 0.36), at + b * Vector3(0.0, 0.275, 0.24), b)


## A tiled privacy wall inside the door: from outside you do not look
## straight into the room. The player walks round its north end.
func _screen(south:float,door: Vector2,trim:="tile_trim") -> void:
	# Continue all the way to the existing tiled wall: no detached panel or
	# unintended passage at the south end. Keep the north passage 1.2m clear.
	var z0 := south + .012
	var z1 := door.y + 0.6
	var mid:=(z0+z1)*.5
	_box("wall_paint",Vector3(.12,3.2,z1-z0),Vector3(-11.1,1.6,mid),Basis.IDENTITY,true)
	# Tile and trim end caps stand proud of the plaster core as well, avoiding
	# coplanar end faces flickering at the exposed north jamb.
	_box("wall_tile",Vector3(.132,TILE_H,z1-z0+.008),Vector3(-11.1,TILE_H*.5,mid+.004))
	_box(trim,Vector3(.136,.05,z1-z0+.010),Vector3(-11.1,TILE_H+.025,mid+.005))


## A closed cleaner's closet door on a wall (not interactive), with a sign.
## `at` on the wall; the room is at local +Z.
func _closet_door(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	_box("partition", Vector3(0.95, 2.06, 0.03), at + b * Vector3(0.0, 1.03, 0.015), b)
	_box("stall_door", Vector3(0.85, 2.0, 0.03), at + b * Vector3(0.0, 1.0, 0.04), b)
	_box("chrome", Vector3(0.12, 0.03, 0.05), at + b * Vector3(0.3, 1.0, 0.07), b)
	_sign("ห้องเก็บอุปกรณ์ทำความสะอาด", at + b * Vector3(0.0, 1.75, 0.06), yaw, 0.0011)


func _sign(text: String, at: Vector3, yaw: float, pixel := 0.0016) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = GameUI.FONT_BOLD
	label.font_size = 48
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = Color(0.12, 0.2, 0.36)
	label.position = at
	label.rotation.y = yaw
	label.set_meta("restroom_generated",true)
	add_child(label)

func _fixture(scene:PackedScene,where:Transform3D) -> void:
	if not _fixture_cache.has(scene.resource_path):
		var instance:=scene.instantiate()
		var pieces:Array=[]
		_gather_fixture(instance,Transform3D.IDENTITY,pieces)
		instance.free()
		_fixture_cache[scene.resource_path]=pieces
	for piece:Dictionary in _fixture_cache[scene.resource_path]:
		var mesh:Mesh=piece["mesh"]
		var surface:int=piece["surface"]
		var key:String=piece["key"]
		if not _tools.has(key):
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);_tools[key]=st
		(_tools[key] as SurfaceTool).append_from(mesh,surface,where*(piece["transform"] as Transform3D))

func _gather_fixture(node:Node,parent_transform:Transform3D,pieces:Array) -> void:
	var transform_here:=parent_transform
	if node is Node3D:transform_here=parent_transform*(node as Node3D).transform
	if node is MeshInstance3D:
		var mesh:Mesh=(node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var mat:=mesh.surface_get_material(surface)
			var key:="porcelain"
			if mat and "Chrome" in mat.resource_name:key="chrome"
			elif mat and "Drain" in mat.resource_name:key="dark"
			pieces.append({"mesh":mesh,"surface":surface,"key":key,"transform":transform_here})
	for child in node.get_children():_gather_fixture(child,transform_here,pieces)

func _light(at:Vector3) -> void:
	var light:=OmniLight3D.new();light.position=at
	light.light_color=Color(1,.97,.92);light.light_energy=.85
	light.omni_range=8;light.shadow_enabled=false
	light.set_meta("restroom_generated",true);add_child(light)


# ------------------------------------------------------------------ building

func _box(key: String, size: Vector3, at: Vector3, basis := Basis.IDENTITY, solid := false) -> void:
	var cache_key := "b%.4f_%.4f_%.4f" % [size.x, size.y, size.z]
	if not _mesh_cache.has(cache_key):
		var box := BoxMesh.new()
		box.size = size
		_mesh_cache[cache_key] = box
	_add(key, _mesh_cache[cache_key], Transform3D(basis, at))
	if solid:
		_collider(size, at, basis)


## Upright cylinder (radius, height) centred at `at`; `stretch` scales it
## (e.g. an oval bowl).
func _cylinder(key: String, radius: float, height: float, at: Vector3, basis := Basis.IDENTITY, stretch := Vector3.ONE) -> void:
	var cache_key := "c%.4f_%.4f" % [radius, height]
	if not _mesh_cache.has(cache_key):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = height
		cylinder.radial_segments = 16
		cylinder.rings = 1
		_mesh_cache[cache_key] = cylinder
	_add(key, _mesh_cache[cache_key], Transform3D(basis * Basis.from_scale(stretch), at))


func _add(key: String, mesh: Mesh, xform: Transform3D) -> void:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	(_tools[key] as SurfaceTool).append_from(mesh, 0, xform)


func _collider(size: Vector3, at: Vector3, basis := Basis.IDENTITY) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(basis.orthonormalized(), at)
	_body.add_child(shape)


## One mesh per material.
func _commit() -> void:
	for key: String in _tools:
		var st: SurfaceTool = _tools[key]
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh_" + key
		mesh.mesh = st.commit()
		mesh.material_override = _materials.get(key)
		mesh.set_meta("restroom_generated",true)
		add_child(mesh)
	_tools.clear()


func _make_materials() -> void:
	var plain := func(color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		return m
	_materials["porcelain"] = plain.call(Color(0.95, 0.96, 0.97), 0.18)
	_materials["white"] = plain.call(Color(.96,.95,.89),.85)
	_materials["seat"] = plain.call(Color(0.98, 0.98, 0.98), 0.3)
	_materials["water"] = plain.call(Color(0.78, 0.84, 0.88), 0.05)
	_materials["basin_in"] = plain.call(Color(0.85, 0.88, 0.9), 0.1)
	_materials["chrome"] = plain.call(Color(0.8, 0.82, 0.85), 0.18, 0.9)
	_materials["partition"] = plain.call(Color(0.62, 0.7, 0.78), 0.45)
	_materials["stall_door"] = plain.call(Color(0.3, 0.46, 0.62), 0.4)
	_materials["women_door"] = plain.call(Color(.30,.50,.45),.5)
	_materials["women_trim"] = plain.call(Color(.34,.53,.47),.5)
	_materials["counter"] = plain.call(Color(0.24, 0.25, 0.27), 0.3)
	# Not metallic: a metal mirror reflects the outdoor sky as a blurry picture.
	_materials["mirror"] = plain.call(Color(0.56, 0.65, 0.68), 0.08)
	var glass_gradient:=Gradient.new()
	glass_gradient.set_color(0,Color(.37,.48,.51))
	glass_gradient.set_color(1,Color(.76,.82,.83))
	glass_gradient.add_point(.48,Color(.61,.70,.72))
	var glass_texture:=GradientTexture2D.new();glass_texture.gradient=glass_gradient
	glass_texture.width=256;glass_texture.height=128
	glass_texture.fill_from=Vector2(0,0);glass_texture.fill_to=Vector2(1,.65)
	(_materials["mirror"] as StandardMaterial3D).albedo_color=Color.WHITE
	(_materials["mirror"] as StandardMaterial3D).albedo_texture=glass_texture
	_materials["dispenser"] = plain.call(Color(0.92, 0.93, 0.94), 0.35)
	_materials["bin"] = plain.call(Color(0.35, 0.38, 0.42), 0.5, 0.4)
	_materials["dark"] = plain.call(Color(0.12, 0.13, 0.15), 0.5)
	_materials["tile_trim"] = plain.call(Color(0.25, 0.45, 0.7), 0.3)
	_materials["wall_paint"] = plain.call(Color(.75,.77,.77),.8)
	_materials["wall_tile"] = _tile_material(Color(0.93, 0.95, 0.96), Color(0.78, 0.8, 0.82), 0.2, 0.25)
	_materials["floor"] = _tile_material(Color(0.7, 0.72, 0.74), Color(0.55, 0.57, 0.6), 0.3, 0.6)


## Square tiles with grout lines, laid in world space (triplanar) so every
## piece lines up whatever its size.
func _tile_material(tile: Color, grout: Color, tile_size: float, rough: float) -> StandardMaterial3D:
	var px := 64
	var image := Image.create(px, px, false, Image.FORMAT_RGB8)
	image.fill(tile)
	image.fill_rect(Rect2i(0, 0, px, 2), grout)
	image.fill_rect(Rect2i(0, 0, 2, px), grout)
	image.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_size
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
