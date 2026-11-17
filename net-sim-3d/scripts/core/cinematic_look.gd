class_name CinematicLook
extends RefCounted
## "High" graphics quality, look "B" chosen by the user on 2026-11-18
## (prototype pictures: Preview/คุณภาพภาพ/ภาพยนตร์_ข้อเสนอ):
## - film tone mapping (AgX): softer highlights, deeper shadows
## - colour grade: cool shadows, warm highlights, a little more saturation
## - less flat fill light so the ceiling lights and shadows read
## - stronger glow, darker frame edges (vignette)
## - warm afternoon sun through the windows: the sun is turned to shine into
##   the IT Support room (where every level starts) and window glass no
##   longer blocks it, so window-frame patterns of light fall on desks and floor
## Off restores everything exactly (original values are kept as metadata).
## Cost measured 2026-11-18: the grade is within the noise (< 1 ms); the
## sunlight (see SUN_SHADOW_MODE) adds ~7-20 ms depending on the room.

const BASE := "cinematic_base"
const EXPOSURE := 1.45
const AGX_CONTRAST := 1.3
## Sky through the windows, so tone mapping does not leave it pale.
const SKY_ENERGY := 1.8
## Share of the normal fill (ambient) light that remains.
const AMBIENT_SHARE := 0.55
const SATURATION := 1.2
const CONTRAST := 1.05
const GLOW_INTENSITY := 1.0
const GLOW_BLOOM := 0.05
const SUN_ROTATION := Vector3(-34.0, 150.0, 0.0)
const SUN_ENERGY := 2.2
const SUN_COLOR := Color(1.0, 0.86, 0.68)
## Shorter shadow distance = sharper window patterns indoors. Not shorter:
## beyond it the sun is unshadowed and would shine through the roof.
const SUN_SHADOW_DISTANCE := 60.0
## The turned, lower sun's shadow covers far more of the school. Measured
## 2026-11-18 (Ryzen 5 3500U) against Medium: 4 splits +7-50 ms a frame,
## 2 splits +7-20 ms with the window bars still visible, 1 (orthogonal)
## +6-17 ms but the pattern turns blocky.
const SUN_SHADOW_MODE := DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
const VIGNETTE_NAME := "CinematicVignette"
## Below every UI layer (HUD 3, desktop, dialogue...), above the 3D view, so
## the in-game computer screen and the mission panel are never darkened.
const VIGNETTE_LAYER := -50


static func apply(world: Node, on: bool) -> void:
	for sky in world.find_children("*", "WorldEnvironment", true, false):
		if sky.environment:
			_environment(sky.environment, on)
	for sun in world.find_children("ExteriorSun", "DirectionalLight3D", true, false):
		_sun(sun, on)
	_glass(world, on)
	_vignette(world, on)


static func _environment(environment: Environment, on: bool) -> void:
	if not environment.has_meta(BASE):
		environment.set_meta(BASE, {
			"tonemap": environment.tonemap_mode, "exposure": environment.tonemap_exposure,
			"agx": environment.tonemap_agx_contrast, "sky": environment.background_energy_multiplier,
			"ambient": environment.ambient_light_energy, "adjust": environment.adjustment_enabled,
			"saturation": environment.adjustment_saturation, "contrast": environment.adjustment_contrast,
			"grade": environment.adjustment_color_correction})
	var base: Dictionary = environment.get_meta(BASE)
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX if on else base.tonemap
	environment.tonemap_exposure = EXPOSURE if on else base.exposure
	environment.tonemap_agx_contrast = AGX_CONTRAST if on else base.agx
	environment.background_energy_multiplier = base.sky * (SKY_ENERGY if on else 1.0)
	environment.ambient_light_energy = base.ambient * (AMBIENT_SHARE if on else 1.0)
	environment.adjustment_enabled = true if on else base.adjust
	environment.adjustment_saturation = SATURATION if on else base.saturation
	environment.adjustment_contrast = CONTRAST if on else base.contrast
	environment.adjustment_color_correction = _grade() if on else base.grade
	if on:
		environment.glow_intensity = GLOW_INTENSITY
		environment.glow_bloom = GLOW_BLOOM


## Brightness -> colour ramp: shadows lean blue, highlights warm.
static func _grade() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0.0, 0.03, 0.06), Color(0.5, 0.5, 0.49), Color(1.0, 0.97, 0.9)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	ramp.width = 256
	return ramp


static func _sun(sun: DirectionalLight3D, on: bool) -> void:
	if not sun.has_meta(BASE):
		sun.set_meta(BASE, {"rotation": sun.rotation_degrees, "energy": sun.light_energy,
			"color": sun.light_color, "distance": sun.directional_shadow_max_distance,
			"mode": sun.directional_shadow_mode})
	var base: Dictionary = sun.get_meta(BASE)
	sun.directional_shadow_mode = SUN_SHADOW_MODE if on else base.mode
	sun.rotation_degrees = SUN_ROTATION if on else base.rotation
	sun.light_energy = SUN_ENERGY if on else base.energy
	sun.light_color = SUN_COLOR if on else base.color
	sun.directional_shadow_max_distance = SUN_SHADOW_DISTANCE if on else base.distance


## Window glass (any transparent surface of the school) lets the sun through.
static func _glass(world: Node, on: bool) -> void:
	var visual := world.get_node_or_null("MapVisual")
	if visual == null:
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var transparent := false
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				transparent = true
				break
		if not transparent:
			continue
		if not mesh_instance.has_meta(BASE):
			mesh_instance.set_meta(BASE, mesh_instance.cast_shadow)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on \
			else mesh_instance.get_meta(BASE)


static func _vignette(world: Node, on: bool) -> void:
	var layer := world.get_node_or_null(VIGNETTE_NAME)
	if not on:
		if layer:
			layer.free()
		return
	if layer:
		return
	layer = CanvasLayer.new()
	layer.name = VIGNETTE_NAME
	layer.layer = VIGNETTE_LAYER
	var frame := ColorRect.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	d.x *= 1.25;
	COLOR = vec4(0.02, 0.01, 0.0, smoothstep(0.3, 0.8, length(d)) * 0.55);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	frame.material = material
	layer.add_child(frame)
	world.add_child(layer)
