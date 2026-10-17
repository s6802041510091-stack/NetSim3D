extends Node3D
var materials := {}
var meshes := 0
var screens := 0
var labels := 0
var rack_details := 0
var errors: Array[String] = []
var camera: Camera3D
var light_group: Node3D
var views: Dictionary
var overlay: CanvasLayer
var title: Label

func xyz(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1])

func _ready() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://expectations.json"))
	views = expected.views
	var packed := load("res://furniture_map.glb") as PackedScene
	if packed == null:
		push_error("Unable to load furniture_map.glb")
		get_tree().quit(1)
		return
	var model := packed.instantiate()
	add_child(model)
	inspect(model)
	var checked := []
	var found := {}
	for id in materials:
		var mat: StandardMaterial3D = materials[id]
		if mat.resource_name in expected.materials:
			found[mat.resource_name] = true
			var ok := mat.albedo_texture != null and mat.roughness_texture != null and mat.normal_enabled and mat.normal_texture != null
			checked.append({"material": mat.resource_name, "pbr_textures_present": ok})
			if not ok: errors.append("Missing PBR textures: " + mat.resource_name)
	for name in expected.materials:
		if not found.has(name): errors.append("Missing material: " + name)
	if screens != 29: errors.append("Expected 29 screens, found " + str(screens))
	if rack_details != 20: errors.append("Expected 20 Phase 3 rack details")
	if labels != int(expected.print_groups): errors.append("Print group count mismatch")
	var report := {"passed": errors.is_empty(), "errors": errors, "mesh_instances": meshes,
		"screens": screens, "phase3_rack_details": rack_details, "printed_label_groups": labels,
		"pbr_materials": checked, "renderer": RenderingServer.get_current_rendering_method(),
		"scope": "Isolated visual import; production gameplay and web performance deferred to Phase 5."}
	var file := FileAccess.open("res://import_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("P4_IMPORT ", JSON.stringify(report))
	if "--validate" in OS.get_cmdline_user_args():
		get_tree().quit(0 if errors.is_empty() else 1)
		return
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.92, 1.0)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	light_group = Node3D.new()
	add_child(light_group)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.near = 0.03
	overlay = CanvasLayer.new()
	title = Label.new()
	title.position = Vector2(16, 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	overlay.add_child(title)
	add_child(overlay)
	set_view("lounge")
	if "--capture" in OS.get_cmdline_user_args():
		overlay.hide()
		for name in views:
			set_view(name)
			await get_tree().create_timer(0.6).timeout
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png("res://godot_" + name + ".png")
			if result != OK: errors.append("Capture failed: " + name)
			print("P4_CAPTURE ", name, " ", result)
		get_tree().quit(0 if errors.is_empty() else 1)

func set_view(name: String) -> void:
	var v: Array = views[name]
	camera.position = xyz(v[0])
	camera.look_at(xyz(v[1]))
	camera.fov = rad_to_deg(2.0 * atan(12.0 / float(v[2])))
	title.text = "Phase 4 | " + name + " | 1-9, 0: views | Esc: close"
	for lamp in light_group.get_children():
		light_group.remove_child(lamp)
		lamp.queue_free()
	for x in [-17.5, -12.0, -6.0, 0.0, 5.0]:
		for y in [-6.0, 1.0, 7.0, 13.0, 19.0, 26.0, 32.0, 38.0, 42.0]:
			var point := Vector3(x, 2.8, -y)
			if point.distance_to(camera.position) > 13.0: continue
			var lamp := OmniLight3D.new()
			light_group.add_child(lamp)
			lamp.position = point
			lamp.omni_range = 7.0
			lamp.omni_attenuation = 1.0
			lamp.light_energy = 0.15
			lamp.shadow_enabled = true

func inspect(node: Node) -> void:
	if node is MeshInstance3D:
		meshes += 1
		if "Monitor_Display_Surface" in str(node.name): screens += 1
		if str(node.name).begins_with("P3_Detail_"): rack_details += 1
		if str(node.name).begins_with("P4_Print_"): labels += 1
		for i in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(i)
			if mat is StandardMaterial3D: materials[mat.get_instance_id()] = mat
	for child in node.get_children(): inspect(child)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		elif event.keycode == KEY_0: set_view("workstation")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			set_view(views.keys()[int(event.keycode-KEY_1)])
