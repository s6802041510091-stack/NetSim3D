class_name CeilingLights
extends Node3D
## The school's ceiling lighting: one downward spot light under every ceiling
## light panel (agreed with the user 2026-11-18). It replaced 17 large omni
## "ambient" lights that sat in the middle of rooms, away from the panels,
## and painted a round bright spot on the ceiling where no fixture was.
##
## The panels are found by their material in the school model, so a panel
## moved or added in Blender gets its light automatically. Places with a
## ceiling but no panel get a copy of a room panel (EXTRA_PANELS), so every
## light still has a fixture above it.
##
## Brightness was matched to the old lighting room by room (average picture
## brightness within about 5 % in most rooms, measured 2026-11-18).
## Needs rendering/limits/opengl/max_lights_per_object raised in
## project.godot: the corridor floor and long walls are single meshes under
## more than the default 8 lights.

const PANEL_MATERIAL := "MAP | Light diffuser"
## Room panel copied to places that have a ceiling but no fixture.
const TEMPLATE_PANEL := "Light_Panel_ITSupport"
## Centre (x, z) of each added panel. IT return area between the IT Support
## room and the storeroom: its ceiling had no light.
const EXTRA_PANELS := {"Light_Panel_ITReturn": Vector2(-10.8, -33.75)}

const ROOM_ENERGY := 3.3
## Panels in small rooms or close together (and the long corridor) made those
## places 15-23 % brighter than before at ROOM_ENERGY; matched room by room
## (panel name prefix -> energy).
const AREA_ENERGY := {
	"Corridor_Light_Panel": 1.6,
	"Light_Panel_FemaleWC": 1.8,
	"Light_Panel_MaleWC": 1.8,
	"Light_Panel_Storage": 2.0,
	"Light_Panel_Server": 2.2,
	"Light_Panel_ITReturn": 4.2,
}
const SPOT_ANGLE := 60.0
## Reaches the floor at the edge of the cone (panel at ~3.1 m) and little
## beyond, so light leaking through walls (no shadows) stays faint.
const SPOT_RANGE := 5.5
const COLOR := Color(1.0, 0.98, 0.95)


func _ready() -> void:
	var visual := get_parent().get_node_or_null("MapVisual")
	if visual == null:
		push_error("CeilingLights: MapVisual not found")
		return
	var template: MeshInstance3D
	var panels: Array[MeshInstance3D] = []
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var material := mesh_instance.get_active_material(0)
		if mesh_instance.mesh and material and material.resource_name == PANEL_MATERIAL:
			panels.append(mesh_instance)
			if mesh_instance.name == TEMPLATE_PANEL:
				template = mesh_instance
	if template:
		for panel_name: String in EXTRA_PANELS:
			panels.append(_copy_panel(template, panel_name, EXTRA_PANELS[panel_name]))
	for panel in panels:
		_add_light(panel)


func _copy_panel(template: MeshInstance3D, panel_name: String, at: Vector2) -> MeshInstance3D:
	var panel := MeshInstance3D.new()
	panel.name = panel_name
	panel.mesh = template.mesh
	for surface in template.get_surface_override_material_count():
		panel.set_surface_override_material(surface, template.get_surface_override_material(surface))
	panel.cast_shadow = template.cast_shadow
	add_child(panel)
	var box := _box(template)
	var place := template.global_transform
	place.origin += Vector3(at.x - box.get_center().x, 0.0, at.y - box.get_center().z)
	panel.global_transform = place
	return panel


func _add_light(panel: MeshInstance3D) -> void:
	var box := _box(panel)
	var light := SpotLight3D.new()
	light.name = "Light_" + panel.name
	add_child(light)
	# Just under the diffuser, shining straight down (a spot shines along -Z).
	light.global_position = Vector3(box.get_center().x, box.position.y - 0.05, box.get_center().z)
	light.global_rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	light.spot_angle = SPOT_ANGLE
	light.spot_angle_attenuation = 0.6
	light.spot_range = SPOT_RANGE
	light.light_color = COLOR
	light.light_energy = ROOM_ENERGY
	for prefix: String in AREA_ENERGY:
		if String(panel.name).begins_with(prefix):
			light.light_energy = AREA_ENERGY[prefix]


func _box(mesh_instance: MeshInstance3D) -> AABB:
	return mesh_instance.global_transform * mesh_instance.get_aabb()
