extends Node3D

var camera: Camera3D
var materials := {}
var meshes := 0
var player_screen: MeshInstance3D

func _ready() -> void:
	var model: PackedScene = load("res://it_corner.glb")
	add_child(model.instantiate())
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.3, 0.33, 0.37)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.9, 1.0)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	for point in [Vector3(-15.2,2.8,-40.3), Vector3(-10.8,2.7,-41.8)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.omni_range = 10.0
		lamp.omni_attenuation = 0.7
		lamp.light_energy = 0.28
		lamp.shadow_enabled = true
		add_child(lamp)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(-16.3,1.75,-39.9)
	camera.look_at(Vector3(-12.9,1.02,-42.9))
	camera.fov = 43.3
	camera.near = 0.04
	camera.current = true
	inspect(self)
	var textured := []
	for key in materials:
		var mat: StandardMaterial3D = materials[key]
		if mat.resource_name.begins_with("P1"):
			textured.append({"name":mat.resource_name, "albedo":mat.albedo_texture != null,
				"normal":mat.normal_enabled and mat.normal_texture != null,
				"roughness":mat.roughness_texture != null})
	var report := {"meshes":meshes, "materials":materials.size(), "p1_materials":textured,
		"player_screen_found":player_screen != null, "renderer":RenderingServer.get_current_rendering_method(),
		"scope":"Isolated material import only. Main-game interaction and web performance not tested."}
	var file := FileAccess.open("res://import_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("P1_IMPORT_VALIDATION ",JSON.stringify(report))
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://godot_hero.png")
		print("P1_CAPTURE_RESULT ",error)
		get_tree().quit(error)

func inspect(node: Node) -> void:
	if node is MeshInstance3D:
		meshes += 1
		if str(node.name) in ["Monitor_Display_Surface_001", "Monitor_Display_Surface.001"]:
			player_screen = node
		for i in node.mesh.get_surface_count():
			var mat = node.get_active_material(i)
			if mat is StandardMaterial3D:
				materials[mat.get_instance_id()] = mat
	for child in node.get_children():
		inspect(child)
