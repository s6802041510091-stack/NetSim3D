extends Node3D

# Coordinates below are Blender x,y,z; conversion is x,z,-y.
const VIEWS := {
	"corridor": [Vector3(-6.15,-7.4,1.65), Vector3(-6.15,12,1.65), 22.0],
	"windows": [Vector3(-6.45,-4.5,1.65), Vector3(-0.2,-1.4,1.4), 25.0],
	"doors": [Vector3(-5.7,32.8,1.65), Vector3(-9.6,35.3,1.3), 32.0],
	"stairs": [Vector3(-9.9,27.2,1.65), Vector3(-14.8,28.3,1.9), 22.0],
	"classroom": [Vector3(6.9,-7.6,1.65), Vector3(-0.8,5.8,1.5), 24.0],
	"windows_reverse": [Vector3(-0.5,-2.8,1.65), Vector3(-10,-2.8,1.65), 25.0],
}
var camera: Camera3D
var light_group: Node3D
var materials := {}
var meshes := 0
var screens := 0
var errors: Array[String] = []
var view_names: Array = VIEWS.keys()
var current_view := 0

func from_blender(point: Vector3) -> Vector3:
	return Vector3(point.x, point.z, -point.y)

func _ready() -> void:
	var model: PackedScene = load("res://architecture.glb")
	add_child(model.instantiate())
	inspect(self)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88,0.92,1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	light_group = Node3D.new()
	add_child(light_group)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.near = 0.04
	var overlay := CanvasLayer.new()
	var label := Label.new()
	label.text = "Phase 2 material preview   |   1–6: camera views   |   Esc: close"
	label.position = Vector2(16,16)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	overlay.add_child(label)
	add_child(overlay)
	var pbr := []
	var glass_ok := false
	for id in materials:
		var mat: StandardMaterial3D = materials[id]
		if mat.resource_name.begins_with("P2"):
			pbr.append({"name":mat.resource_name,"albedo":mat.albedo_texture != null,
				"roughness":mat.roughness_texture != null,"normal":mat.normal_enabled and mat.normal_texture != null,
				"alpha":mat.albedo_color.a,"transparency":mat.transparency,"two_sided":mat.cull_mode == BaseMaterial3D.CULL_DISABLED})
			if mat.resource_name == "P2 | Clear glass":
				glass_ok = mat.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] and mat.albedo_color.a < 0.15 and mat.cull_mode == BaseMaterial3D.CULL_DISABLED
			if mat.resource_name in ["P2 | Ceiling","P2 | Stone","P2 | WashTile","P2 | Aluminium","P2 | ServerFloor"]:
				if not (mat.albedo_texture and mat.roughness_texture and mat.normal_texture):
					errors.append("Missing texture: " + mat.resource_name)
	if not glass_ok: errors.append("Clear glass import mismatch")
	if screens != 29: errors.append("Expected 29 screens, found " + str(screens))
	var report := {"passed":errors.is_empty(),"errors":errors,"mesh_instances":meshes,"interactive_screen_meshes":screens,
		"glass_alpha_and_two_sided_verified":glass_ok,"p2_materials":pbr,"renderer":RenderingServer.get_current_rendering_method(),
		"scope":"Visual import only; production interactions and web performance not tested."}
	var file := FileAccess.open("res://import_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("P2_IMPORT ",JSON.stringify(report))
	set_view("corridor")
	if "--capture" in OS.get_cmdline_user_args():
		overlay.hide()
		for name in VIEWS:
			set_view(name)
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png("res://godot_" + name + ".png")
			if error != OK: errors.append("Capture failed: " + name)
			print("P2_CAPTURE ",name," ",error)
		get_tree().quit(0 if errors.is_empty() else 1)

func set_view(name: String) -> void:
	var view: Array = VIEWS[name]
	camera.position = from_blender(view[0])
	camera.look_at(from_blender(view[1]))
	# Blender 36mm horizontal sensor -> Godot vertical FOV for a 3:2 viewport.
	camera.fov = rad_to_deg(2.0*atan(12.0/float(view[2])))
	for lamp in light_group.get_children():
		light_group.remove_child(lamp)
		lamp.queue_free()
	var focus: Vector3 = view[0]
	for x in [-16.5,-6.15,3.0]:
		for y in [-5.0,4.0,13.0,22.0,31.0,40.0]:
			var point := Vector3(x,y,2.85)
			if point.distance_to(focus) > 19.0: continue
			var lamp := OmniLight3D.new()
			light_group.add_child(lamp)
			lamp.position = from_blender(point)
			lamp.omni_range = 8.0
			lamp.omni_attenuation = 1.0
			lamp.light_energy = 0.14
			lamp.shadow_enabled = true
	if name == "stairs":
		var lamp := OmniLight3D.new()
		light_group.add_child(lamp)
		lamp.position = from_blender(Vector3(-16.0,28.7,5.5))
		lamp.light_energy = 0.4
		lamp.omni_range = 8.0
		lamp.shadow_enabled = true

func inspect(node: Node) -> void:
	if node is MeshInstance3D:
		meshes += 1
		if "Monitor_Display_Surface" in str(node.name): screens += 1
		for i in node.mesh.get_surface_count():
			var mat = node.get_active_material(i)
			if mat is StandardMaterial3D: materials[mat.get_instance_id()] = mat
	for child in node.get_children(): inspect(child)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			current_view = int(event.keycode-KEY_1)
			set_view(view_names[current_view])
