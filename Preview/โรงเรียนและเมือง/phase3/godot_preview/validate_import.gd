extends Node3D

const EXPECTED_TEXTURED := [
	"P3 | Satin metal",
	"P3 | Anodised graphite",
	"P3 | Flexible black PVC",
	"P3 | Ivory ABS",
	"P3 | Mouse pale blue",
	"P3 | Cable pale grey",
	"P3 | Red switch polymer",
	"P3 | Rack perforation",
	"P3 | Network blue PVC",
	"P3 | Network yellow PVC",
]

var materials := {}
var mesh_instances := 0
var screens := 0
var rack_detail_instances := 0
var errors: Array[String] = []

func _ready() -> void:
	var packed := load("res://equipment_map.glb")
	if not packed is PackedScene:
		errors.append("equipment_map.glb did not import as PackedScene")
		finish()
		return
	var model := (packed as PackedScene).instantiate()
	add_child(model)
	inspect(model)
	var p3_materials := []
	for id in materials:
		var mat: StandardMaterial3D = materials[id]
		if not mat.resource_name.begins_with("P3 | "):
			continue
		var record := {
			"name": mat.resource_name,
			"albedo": mat.albedo_texture != null,
			"roughness": mat.roughness_texture != null,
			"normal": mat.normal_enabled and mat.normal_texture != null,
		}
		p3_materials.append(record)
		if mat.resource_name in EXPECTED_TEXTURED and not (record.albedo and record.roughness and record.normal):
			errors.append("Missing PBR texture: " + mat.resource_name)
	for expected in EXPECTED_TEXTURED:
		if not p3_materials.any(func(record): return record.name == expected):
			errors.append("Missing material: " + expected)
	if screens != 29:
		errors.append("Expected 29 screens, found " + str(screens))
	if rack_detail_instances != 20:
		errors.append("Expected 20 rack detail instances, found " + str(rack_detail_instances))
	var report := {
		"passed": errors.is_empty(),
		"errors": errors,
		"mesh_instances": mesh_instances,
		"interactive_screen_meshes": screens,
		"rack_detail_instances": rack_detail_instances,
		"p3_materials": p3_materials,
		"renderer": RenderingServer.get_current_rendering_method(),
		"scope": "Visual GLB import; production interactions and web performance are separate Phase 5 checks.",
	}
	finish(report)

func inspect(node: Node) -> void:
	if node is MeshInstance3D:
		mesh_instances += 1
		if "Monitor_Display_Surface" in str(node.name):
			screens += 1
		if str(node.name).begins_with("P3_Detail_"):
			rack_detail_instances += 1
		for index in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(index)
			if mat is StandardMaterial3D:
				materials[mat.get_instance_id()] = mat
	for child in node.get_children():
		inspect(child)

func finish(report := {}) -> void:
	if report.is_empty():
		report = {"passed": false, "errors": errors}
	var file := FileAccess.open("res://import_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("P3_IMPORT ", JSON.stringify(report))
	get_tree().quit(0 if report.passed else 1)
