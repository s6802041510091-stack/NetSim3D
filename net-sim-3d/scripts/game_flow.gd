extends Node

## Lightweight front door: the school is loaded only after a level is selected.
## Continue resumes the last level from its mid-level save (LevelSave: the
## step the player was on, where they stood), written by "บันทึกและออก" on the
## pause page, by the 30 s autosave and when the window closes. Without a
## save it starts that level from the beginning.
const MAP := "res://scenes/main.tscn"
const MENU := "res://scenes/start_menu.tscn"
var save_file := SavePaths.file("menu.cfg")
const AVAILABLE := [1, 2, 3, 4, 5, 6]
const TITLES := ["เลือกอุปกรณ์เครือข่าย", "เข้าหัวสาย LAN", "ตรวจเครือข่ายด้วย ping", "เปลี่ยนการ์ดเครือข่าย", "ป้องกันภัยคอมพิวเตอร์", "ช่วยเหลือระยะไกล"]
const TITLES_EN := ["Choose Devices", "Crimp LAN Cables", "Ping Test", "Replace the NIC", "Firewall & Antivirus", "Remote Help"]
const AUDIO := {"Music": "เสียงเพลงประกอบ", "SoundEffect": "เสียงภารกิจ / โทรศัพท์ / คอมพิวเตอร์ / เสียงพูด", "Sound": "เสียงบรรยากาศ / เดิน / เปิด–ปิดประตู"}

var current_level := 0
var last_level := 0
var volumes := {"Music": 80.0, "SoundEffect": 80.0, "Sound": 80.0}
var loading := false
var paused_menu := false
var _previous_mouse := Input.MOUSE_MODE_VISIBLE
var _layer: CanvasLayer
var _background: TextureRect
var _breeze: MenuBreeze
var _home_hotspots: Control
var _art_canvas: Control
## Menu screens (home, level select, settings) are two layers (agreed with
## the user 2026-11-18): a 21:9 school background that covers the whole
## window (cropped at the edges, never stretched), and on top the menu panel
## cut from the original artwork (tools/cut_menu_panels.gd: a 16:9 canvas,
## transparent outside the card) with hotspots on its painted buttons. The
## panel keeps its proportions and sits centred, so every window shape is
## filled and the buttons are always whole.
var _art: TextureRect
const ART_SIZE := Vector2(1672, 943)
var _screen := "home"
## Graphics quality (agreed with the user 2026-11-17). The value is the 3D
## render resolution; the UI and text always stay sharp.
##   low    = 80 %, and the exterior sun casts no shadow (see
##            apply_world_quality: ~40 % less frame time, unseen indoors),
##            and small far-away school pieces are not drawn
##   medium = 100 %, the look the game has always had (default)
##   high   = 100 % + 4x MSAA (smooth edges) + anisotropic texture filtering
##            (floor tiles and walls stay sharp at a slant) + the nearest room
##            light casts shadows (NearLightShadows) + glow + film look "B"
##            with sunlight through the windows (CinematicLook).
const QUALITY := {"low": 0.8, "medium": 1.0, "high": 1.0}
const QUALITY_ORDER := ["low", "medium", "high"]
## Render layer 11, used only to let the shadowless "low" sun light the town.
const TOWN_LIGHT_LAYER := 1 << 10
## "low": school pieces smaller than this (metres) ...
const SMALL_PART := 0.4
## ... are not drawn farther away than this (metres).
const SMALL_PART_RANGE := 8.0
## Saved settings written before the 2026-11-17 remap used low 0.6,
## medium 0.8, high 1.0; scheme 2 keeps each tester's picture the same.
const QUALITY_SCHEME := 2
const QUALITY_FROM_SCHEME_1 := {"low": "low", "medium": "low", "high": "medium"}
var quality := "medium"
var _card: PanelContainer
var _positioner: MarginContainer
var _scroll: ScrollContainer
var _top_bar: HBoxContainer # buttons above the scrolling page (_top_button)
const TOP_BAR_GAP := 12
const TOP_BUTTON_PAD := 22 # space left and right of a top-bar button's text
var _page_area: MarginContainer
## Settings segments (language, quality): last choice drawn, per segment.
var _segment_shown := {}
const SEGMENT_SLIDE := 0.32
## Card padding above and below the page (pixels).
const CARD_PAD_Y := 25
## Pause and "are you sure?" pages: a short list of buttons, so a narrow card
## (the default 900 looked too wide, user 2026-11-18).
const SMALL_CARD_WIDTH := 600
var _body: VBoxContainer
var _page_title: Label
var _load_percent := 0 # shown on the loading screen
var _status: Label
var _loading_visual: LoadingDelivery
var _config := ConfigFile.new()
var _load_clock := 0.0
var _load_target := 0.0
var _display_progress := 0.0
var _load_instantiating := false
var _world_prepared := false
var _awaiting_start := false
var _load_saved := true
var _controls_help: ControlsHelpPopup
## The mid-level save being loaded ({} = a fresh start) and, while playing,
## the autosave clock; a level that has reached its summary is not saved.
var _resume := {}
var _autosave_clock := 0.0
var _level_finished := false
const AUTOSAVE_SEC := 30.0

const INK := Color("20364c")
const MUTED := Color("526b81")
const SKY := Color("e9f6ff")
const BLUE := Color("237db1")
const CORAL := Color("e97775")
const HEADING_FONT := preload("res://assets/fonts/Mitr-Medium.ttf")
const BODY_FONT := preload("res://assets/fonts/Mitr-Regular.ttf")
## 21:9 (1916x821). The older 16:9 school_spring_background.png is still
## used by the in-game college website (college_browser.gd).
const MENU_BACKGROUND := preload("res://assets/ui/school_spring_background-new.png")
const HOME_REFERENCE := preload("res://assets/ui/menu_panel_home_en.png")
const HOME_TH := preload("res://assets/ui/menu_panel_home_th.png")
const LEVELS_TH := preload("res://assets/ui/menu_panel_levels_th.png")
const LEVELS_EN := preload("res://assets/ui/menu_panel_levels_en.png")
const SETTINGS_TH := preload("res://assets/ui/menu_panel_settings_th.png")
const SETTINGS_EN := preload("res://assets/ui/menu_panel_settings_en.png")

func _panel(color: Color, radius: int, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(2 if border.a > 0.0 else 0)
	return box

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_preferences()
	_build_shell()
	_controls_help = ControlsHelpPopup.new()
	add_child(_controls_help)
	_controls_help.dismissed.connect(resume_game)
	L10n.language_changed.connect(_refresh_language)
	_hook_browser_unlock()
	_hook_browser_hide()
	# Direct F6/test scene launches must retain their original behavior.
	call_deferred("_show_initial_menu")

func _show_initial_menu() -> void:
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == MENU:
		show_home()
	elif get_tree().current_scene is Node3D:
		apply_world_quality(get_tree().current_scene) # F6 launch of a level

func load_preferences() -> void:
	_config.load(save_file)
	var saved: Variant = _config.get_value("session", "last_level", 0)
	last_level = int(saved) if saved is int and saved in AVAILABLE else 0
	for bus: String in AUDIO:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
		var value: Variant = _config.get_value("audio", bus, 80.0)
		set_volume(bus, float(value) if (value is float or value is int) else 80.0, false)
	# Default "medium" (full resolution, no extras): measured 2026-11-17 in
	# the web build (Compatibility renderer, Ryzen 5 3500U), a 3D scale below
	# 1.0 was no faster and in a small window slower (extra pass), and "high"
	# costs more, so both are opt-in only.
	var default_quality := "medium"
	var saved_quality: Variant = _config.get_value("video", "quality", default_quality)
	if not saved_quality is String or not QUALITY.has(saved_quality):
		saved_quality = default_quality
	elif _config.get_value("video", "quality_scheme", 1) != QUALITY_SCHEME:
		saved_quality = QUALITY_FROM_SCHEME_1[saved_quality]
	set_quality(saved_quality, false)

func set_quality(level: String, persist := true) -> void:
	if not QUALITY.has(level):
		return
	quality = level
	var root := get_tree().root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = QUALITY[level]
	root.msaa_3d = Viewport.MSAA_4X if level == "high" else Viewport.MSAA_DISABLED
	var scene := get_tree().current_scene
	if scene is Node3D:
		apply_world_quality(scene)
	_config.set_value("video", "quality", level)
	_config.set_value("video", "quality_scheme", QUALITY_SCHEME)
	if persist:
		_save_preferences()

## The quality parts that live in the loaded world rather than the viewport.
##
## Sun shadow: the exterior sun is the only light with a shadow, and its
## shadow falls only on the town outside the windows (the indoor lights have
## none). Measured 2026-11-17 (Ryzen 5 3500U, 1152x648): turning it off cut a
## frame from ~44-48 ms to ~26-28 ms, so "low" turns it off.
##
## Anisotropic filtering is a material setting in Godot, so "high" switches
## the textured materials between trilinear and anisotropic. The
## Compatibility renderer ignores Viewport.anisotropic_filtering_level
## (tested 2026-11-17); the strength comes from the project setting
## rendering/textures/default_filters/anisotropic_filtering_level.
func apply_world_quality(world: Node) -> void:
	for sun in world.find_children("ExteriorSun", "DirectionalLight3D", true, false):
		# Without its shadow the sun would also light the whole interior
		# (through roof and walls), turning rooms warmer and brighter. So at
		# "low" it lights only the town: town geometry gets an extra render
		# layer (it stays on layer 1, which the player camera sees) and the
		# sun's cull mask is cut to that layer.
		var town := sun.get_parent()
		for part in town.find_children("*", "VisualInstance3D", true, false):
			if part != sun:
				part.layers |= TOWN_LIGHT_LAYER
		sun.shadow_enabled = quality != "low"
		sun.light_cull_mask = TOWN_LIGHT_LAYER if quality == "low" else 0xFFFFFFFF # Godot's default
	var high := quality == "high"
	# Glow: ceiling panels, screens and light strips bloom softly. Cost
	# measured under 1 ms. The environment is the town's own copy (see
	# exterior_town.gd _apply_sky), so the scene file stays untouched.
	for sky in world.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = sky.environment
		if environment:
			environment.glow_enabled = high
			environment.glow_intensity = 0.6
			environment.glow_strength = 1.0
			environment.glow_bloom = 0.0
			environment.glow_hdr_threshold = 0.9
			environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# "high": film look B with sunlight through the windows (cinematic_look.gd).
	CinematicLook.apply(world, high)
	# "low": small pieces of the school (binders, keyboard keys, mice,
	# glassware: under SMALL_PART metres) are not drawn beyond SMALL_PART_RANGE.
	# Measured 2026-11-18 at "low" (Ryzen 5 3500U): views down the school
	# need up to ~3,900 draw calls; this cut 10-17 % of the frame time in
	# the teachers' room, science lab and corridor. Only the building and
	# corridor props: characters (shoes, eyes) and mission items keep showing.
	for part_root in [world.get_node_or_null("MapVisual"), world.get_node_or_null("CorridorFurnishings")]:
		if part_root == null:
			continue
		for part in part_root.find_children("*", "GeometryInstance3D", true, false):
			var geometry := part as GeometryInstance3D
			if quality == "low":
				var box: AABB = geometry.global_transform * geometry.get_aabb()
				if box.get_longest_axis_size() < SMALL_PART:
					geometry.visibility_range_end = SMALL_PART_RANGE
					geometry.visibility_range_end_margin = 0.5 # no flicker at the edge
			else:
				geometry.visibility_range_end = 0.0
	var shadows := world.get_node_or_null("NearLightShadows")
	if high and shadows == null:
		shadows = NearLightShadows.new()
		shadows.name = "NearLightShadows"
		world.add_child(shadows)
	elif not high and shadows:
		shadows.free() # _exit_tree turns its light's shadow off
	var wanted := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if quality == "high" \
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var done := {}
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var materials: Array = [node.material_override]
		if node is MeshInstance3D and node.mesh:
			for surface in node.mesh.get_surface_count():
				materials.append(node.mesh.surface_get_material(surface))
				materials.append(node.get_surface_override_material(surface))
		for material in materials:
			if material is BaseMaterial3D and not done.has(material):
				done[material] = true
				# Only the two smooth mipmapped modes; pixel-art or
				# no-mipmap materials keep their own filter.
				if material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
						BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]:
					material.texture_filter = wanted

func set_volume(bus: String, value: float, persist := true) -> void:
	if not AUDIO.has(bus) or not is_finite(value):
		return
	volumes[bus] = clampf(value, 0.0, 100.0)
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, volumes[bus] == 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus] / 100.0, 0.0001)))
	_config.set_value("audio", bus, volumes[bus])
	if persist:
		_save_preferences()

func _save_preferences() -> bool:
	DirAccess.make_dir_recursive_absolute(save_file.get_base_dir())
	var error := _config.save(save_file)
	if error != OK:
		push_warning("Menu settings could not be saved: " + error_string(error))
	return error == OK

func _build_shell() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_background = TextureRect.new()
	_background.texture = MENU_BACKGROUND
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_background)
	# Under the petals (the breeze is added after it), above the backdrop.
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.hide()
	_background.add_child(_art)
	_breeze = MenuBreeze.new()
	_breeze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.add_child(_breeze)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_background.add_child(margin)
	_page_area = margin
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	_positioner = MarginContainer.new()
	center.add_child(_positioner)
	_card = PanelContainer.new()
	_card.custom_minimum_size.x = 560
	var card_style := _panel(Color("f9fbffdb"), 28, Color("f8ffff"))
	card_style.shadow_color = Color("1f375c55")
	card_style.shadow_size = 12
	_card.add_theme_stylebox_override("panel", card_style)
	_positioner.add_child(_card)
	var padding := MarginContainer.new()
	for side in ["left", "right"]:
		padding.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, CARD_PAD_Y)
	_card.add_child(padding)
	# The card always stays whole on screen (all four corners rounded); a page
	# taller than the window scrolls inside it (agreed with the user 2026-11-18,
	# the progress pages used to slide the whole card past the window edge).
	_scroll = ScrollContainer.new()
	_scroll.name = "PageScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(_scroll.get_v_scroll_bar())
	# A bar above the scrolling page for buttons that must stay in view (the
	# progress pages' back button, asked for on 2026-11-19); hidden if empty.
	var frame := VBoxContainer.new()
	frame.name = "PageFrame"
	frame.add_theme_constant_override("separation", TOP_BAR_GAP)
	padding.add_child(frame)
	_top_bar = HBoxContainer.new()
	_top_bar.name = "PageTopBar"
	_top_bar.add_theme_constant_override("separation", 12)
	_top_bar.hide()
	_top_bar.visibility_changed.connect(_fit_card, CONNECT_DEFERRED)
	frame.add_child(_top_bar)
	frame.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.custom_minimum_size.x = 280
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)
	_body.minimum_size_changed.connect(_fit_card, CONNECT_DEFERRED)
	# The full-window background, not `margin`: the card would grow `margin`.
	_background.resized.connect(_fit_card)
	_home_hotspots = Control.new()
	_home_hotspots.name = "HomeHotspots"
	_home_hotspots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home_hotspots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_home_hotspots)
	_home_hotspots.hide()
	_layer.hide()

## The card is as tall as its page, but never taller than the window: the
## rest scrolls inside the card. (A ScrollContainer does not pass its
## child's height on, so the height is set here.)
func _fit_card() -> void:
	if not is_instance_valid(_scroll):
		return
	var available := _background.size.y - _page_area.get_theme_constant("margin_top") - _page_area.get_theme_constant("margin_bottom") - CARD_PAD_Y * 2
	if _top_bar.visible:
		available -= _top_bar.get_combined_minimum_size().y + TOP_BAR_GAP
	var needed := _body.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = maxf(minf(needed, available), 0.0)

## Keeps the page card clear of something drawn at the top of the window (the
## website login badge, ServerSync): `bottom` is that thing's lowest y, 0 for none.
func make_room_at_top(bottom: float) -> void:
	if not is_instance_valid(_page_area):
		return
	_page_area.add_theme_constant_override("margin_top", maxi(20, ceili(bottom) + 10))
	_fit_card()

func _style_scrollbar(bar: VScrollBar) -> void:
	var track := _panel(Color("dfe8f1aa"), 5)
	track.content_margin_left = 4
	track.content_margin_right = 4
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var colour := {"grabber": Color("9fb4c8"), "grabber_highlight": Color("7d97b0"), "grabber_pressed": BLUE}[state] as Color
		bar.add_theme_stylebox_override(state, _panel(colour, 5))

func _page(title: String, subtitle: String, card_width := 900, right_space := 0, home := false) -> void:
	_screen = "generic"
	_home_hotspots.hide()
	_card.show()
	_background.texture = MENU_BACKGROUND
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.material = null
	_art.hide()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for child in _top_bar.get_children():
		_top_bar.remove_child(child)
		child.queue_free()
	_top_bar.hide()
	_card.custom_minimum_size.x = card_width
	_scroll.scroll_vertical = 0 # a new page starts at its top
	_positioner.add_theme_constant_override("margin_right", right_space)
	_layer.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_body.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_body, "modulate:a", 1.0, 0.26)
	if home:
		_page_title = _label(title, 54, INK, true)
		_label(subtitle, 16, INK, true)
	else:
		_label("NetSim3D   /   SCHOOL NETWORK LAB", 23, INK, true)
		_page_title = _label(title, 34, INK, true)
		_label(subtitle, 17, MUTED)
	_body.add_child(HSeparator.new())

func _label(text: String, size := 18, color := INK, heading := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", HEADING_FONT if heading else BODY_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)
	return label

func _button(text: String, action: Callable, disabled := false, primary := true, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54
	button.add_theme_font_override("font", HEADING_FONT)
	button.add_theme_font_size_override("font_size", 20)
	var foreground := Color.WHITE if primary else INK
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var normal := _panel(Color("0789e6") if primary else Color("fffaf4"), 15, Color("c2e6ff") if primary else Color.WHITE)
	normal.shadow_color = Color("193a6155")
	normal.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _panel(Color("0872c9") if primary else Color("e5f5ff"), 15, BLUE))
	button.add_theme_stylebox_override("pressed", _panel(Color("d96258"), 15))
	button.add_theme_stylebox_override("disabled", _panel(Color("e7e9ed"), 15, Color("b9c4d0")))
	button.add_theme_stylebox_override("focus", _panel(Color.TRANSPARENT, 12, CORAL))
	button.disabled = disabled
	button.mouse_entered.connect(func(): if not button.disabled: create_tween().tween_property(button, "modulate", Color("e7f7ff"), 0.12))
	button.mouse_exited.connect(func(): create_tween().tween_property(button, "modulate", Color.WHITE, 0.12))
	button.pressed.connect(action)
	(parent if parent else _body).add_child(button)
	return button

func _show_art(texture: Texture2D, screen: String) -> void:
	_screen = screen
	_layer.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_card.hide()
	_background.texture = MENU_BACKGROUND
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.material = null # full-bleed, no blur (the panel is its own layer)
	_art.texture = texture
	_art.show()
	for child in _home_hotspots.get_children():
		_home_hotspots.remove_child(child)
		child.queue_free()
	_home_hotspots.show()
	_art_canvas = Control.new()
	_art_canvas.size = ART_SIZE
	_art_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_hotspots.add_child(_art_canvas)
	_scale_art()
	if not _home_hotspots.resized.is_connected(_scale_art):
		_home_hotspots.resized.connect(_scale_art)

func _scale_art() -> void:
	if not is_instance_valid(_art_canvas):
		return
	# One scale for both axes (fit inside), centred: the art and its hotspots
	# share the same rectangle so the buttons stay on the painted buttons.
	var area := _home_hotspots.size
	var s := minf(area.x / ART_SIZE.x, area.y / ART_SIZE.y)
	var offset := ((area - ART_SIZE * s) / 2.0).round()
	_art_canvas.scale = Vector2(s, s)
	_art_canvas.position = offset
	_art.position = offset
	_art.size = ART_SIZE * s

func _refresh_language() -> void:
	match _screen:
		"home": show_home()
		"levels": show_levels()
		"settings": show_settings()

func _art_button(label: String, rect: Rect2, action: Callable, disabled := false, hint := "") -> Button:
	var button := Button.new()
	button.name = label.replace(" ", "") + "Hotspot"
	button.text = label
	button.tooltip_text = hint if hint != "" else label
	button.position = rect.position
	button.size = rect.size
	for state in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _panel(Color.TRANSPARENT, 18))
	button.add_theme_stylebox_override("hover", _panel(Color("ffffff1b"), 18, Color("ffffff8a")))
	button.add_theme_stylebox_override("focus", _panel(Color.TRANSPARENT, 18, Color("ffffffaf")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	button.disabled = disabled
	button.pressed.connect(action)
	_art_canvas.add_child(button)
	return button

func _home_hotspot(label: String, y_top: float, y_bottom: float, action: Callable, disabled := false) -> void:
	_art_button(label, Rect2(193, y_top, 566, y_bottom - y_top), action, disabled)

func show_home() -> void:
	Sound.music("menu")
	_show_art(HOME_TH if L10n.locale == "th" else HOME_REFERENCE, "home")
	# Five painted buttons (tools/relayout_home_buttons.gd, 2026-11-18).
	_home_hotspot("PLAY", 383, 454, show_levels)
	_home_hotspot("CONTINUE", 466, 537, func(): start_level(last_level, LevelSave.exists(last_level)), last_level == 0)
	_home_hotspot("SETTINGS", 549, 620, show_settings)
	_home_hotspot("PROGRESS", 632, 703, show_progress)
	_home_hotspot("EXIT TO LOBBY", 715, 786, confirm_exit)

## The learner's own results per level: from the class system when logged in on
## the NetSim website (ServerSync), otherwise this browser / computer only.
func show_progress() -> void:
	var synced := ServerSync.is_student_synced()
	_page("ความคืบหน้าของฉัน", "สรุปผลทุกด่านของคุณจากระบบของห้องเรียน • เห็นเหมือนกันทุกเครื่องที่เข้าสู่ระบบ" if synced else "สรุปผลทุกด่านที่เล่นบนเครื่อง/เบราว์เซอร์นี้ • แสดงเฉพาะผลของคุณเอง", 980)
	_screen = "progress"
	ProgressDashboard.build_overview(_body, TITLES, AVAILABLE, is_level_unlocked, show_progress_level)
	_top_button("‹  กลับเมนูหลัก", show_home).name = "ProgressBack"

func show_progress_level(level: int) -> void:
	_page("ด่าน %d  ·  %s" % [level, TITLES[level - 1]], "คะแนนแต่ละครั้ง ผลครั้งล่าสุด และจุดที่ผิดพลาด", 980)
	_screen = "progress_level"
	ProgressDashboard.build_level(_body, level)
	_top_button("‹  กลับหน้าความคืบหน้า", show_progress).name = "ProgressLevelBack"
	if is_level_unlocked(level):
		var play := _button("เล่นด่านนี้", start_level.bind(level), false, true)
		play.name = "ProgressPlayLevel"

## A back button in the bar above the page: it stays in view while the page
## scrolls.
func _top_button(text: String, action: Callable) -> Button:
	var button := _button(text, action, false, false, _top_bar)
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Room around the words: sized to its text, it looked cramped (2026-11-19).
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := button.get_theme_stylebox(state).duplicate() as StyleBox
		box.content_margin_left = TOP_BUTTON_PAD
		box.content_margin_right = TOP_BUTTON_PAD + 4
		button.add_theme_stylebox_override(state, box)
	button.set_meta("sound", "back")
	_top_bar.show()
	return button

func show_levels() -> void:
	_show_art(LEVELS_TH if L10n.locale == "th" else LEVELS_EN, "levels")
	for level in range(1, 7):
		var hint: String = TITLES[level - 1] if L10n.locale == "th" else TITLES_EN[level - 1]
		if not level in AVAILABLE:
			hint = "กำลังพัฒนา" if L10n.locale == "th" else "In development"
		elif not is_level_unlocked(level):
			hint = "ผ่านด่านก่อนหน้าเพื่อปลดล็อก" if L10n.locale == "th" else "Complete the previous level to unlock"
		var x: float = [312.0, 660.0, 1007.0][(level - 1) % 3]
		var y := 368.0 if level <= 3 else 598.0
		_art_button("Level%d" % level, Rect2(x, y, 326, 211), choose_level.bind(level), not is_level_unlocked(level), hint)
	_art_button("Back", Rect2(265, 829, 204, 58), show_home)


## A level picked from the list (or "next level"): with a mid-level save the
## player chooses to go on from it or to start again.
func choose_level(level: int) -> void:
	if not LevelSave.exists(level):
		start_level(level)
		return
	_page("ด่าน %d มีเกมที่บันทึกไว้" % level, "เล่นต่อจากที่บันทึกไว้ หรือเริ่มด่านนี้ใหม่ตั้งแต่ต้น", SMALL_CARD_WIDTH)
	_button("เล่นต่อจากที่บันทึกไว้", func(): start_level(level, true)).grab_focus()
	_quiet_button(_button("เริ่มใหม่", func(): start_level(level), false, false))
	_quiet_button(_button("ยกเลิก", show_levels, false, false))


## Built and (outside the editor) unlocked by passing the previous built level.
func is_level_unlocked(level: int) -> bool:
	if not level in AVAILABLE:
		return false
	return OS.has_feature("editor") or GameProgress.is_unlocked(level, AVAILABLE)


## The next built level after `level` that the player may start (0 = none).
func next_level(level: int) -> int:
	for candidate in AVAILABLE:
		if candidate > level and is_level_unlocked(candidate):
			return candidate
	return 0


func next_level_available(level: int) -> bool:
	return next_level(level) != 0

func show_settings() -> void:
	_show_art(SETTINGS_TH if L10n.locale == "th" else SETTINGS_EN, "settings")
	# One row in the artwork holds two settings: language beside its painted
	# label, graphics quality (drawn here) on the right half.
	var thai := L10n.locale == "th"
	_segment("Language_", ["th", "en"], ["ไทย", "ENG"], L10n.locale, Vector2(450, 318), 154,
		func(code: String): L10n.set_locale(code))
	var divider := ColorRect.new()
	divider.color = Color("20364c33")
	divider.position = Vector2(800, 310)
	divider.size = Vector2(2, 78)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_canvas.add_child(divider)
	var quality_label := Label.new()
	quality_label.name = "QualityLabel"
	quality_label.text = "คุณภาพภาพ" if thai else "Graphics"
	quality_label.position = Vector2(838, 318)
	quality_label.size = Vector2(190, 62)
	quality_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quality_label.add_theme_font_override("font", BODY_FONT)
	quality_label.add_theme_font_size_override("font_size", 34)
	quality_label.add_theme_color_override("font_color", INK)
	_art_canvas.add_child(quality_label)
	var quality_names := ["ต่ำ", "กลาง", "สูง"] if thai else ["Low", "Med", "High"]
	var quality_buttons := _segment("Quality_", QUALITY_ORDER, quality_names, quality, Vector2(1040, 318), 146, _pick_quality)
	var hints := ["ลดความละเอียดภาพ 3 มิติและปิดเงาแดด สำหรับเครื่องช้า", "ภาพมาตรฐาน (ค่าเริ่มต้น)", "แสงแบบภาพยนตร์ แดดส่องผ่านหน้าต่าง มีเงาในห้อง สำหรับเครื่องแรง"] if thai \
		else ["Lower 3D resolution and no sun shadows, for slower computers", "Standard picture (default)", "Film-style light, sun through the windows, room shadows, for faster computers"]
	for index in quality_buttons.size():
		quality_buttons[index].tooltip_text = hints[index]
	for index in range(AUDIO.size()):
		var bus: String = AUDIO.keys()[index]
		var y: float = [515.0, 591.0, 670.0][index]
		var slider := ArtworkSlider.new()
		slider.name = bus + "Slider"
		slider.position = Vector2(557, y - 18)
		slider.size = Vector2(794, 36)
		slider.tooltip_text = AUDIO[bus]
		_art_canvas.add_child(slider)
		slider.value = volumes[bus]
		var percent := Label.new()
		percent.position = Vector2(1380, y - 26)
		percent.size = Vector2(100, 52)
		percent.text = "%d%%" % slider.value
		percent.add_theme_font_override("font", BODY_FONT)
		percent.add_theme_font_size_override("font_size", 32)
		percent.add_theme_color_override("font_color", INK)
		percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_art_canvas.add_child(percent)
		slider.value_changed.connect(func(value: float):
			set_volume(bus, value)
			percent.text = "%d%%" % value)
	_art_button("Back", Rect2(201, 750, 1270, 78), show_pause if paused_menu else show_home)

func _pick_quality(level: String) -> void:
	set_quality(level)
	show_settings() # redraw so the chosen level is lit

## A rounded pill of equal buttons on the settings artwork; `current` is lit.
## The lit part is its own blue "thumb" that slides to a new choice (asked by
## the user 2026-11-18). Picking redraws the page, so the last shown choice per
## segment is remembered and the new thumb starts there and glides over.
func _segment(prefix: String, codes: Array, labels: Array, current: String, at: Vector2, width: float, pick: Callable) -> Array[Button]:
	var back := Panel.new()
	back.position = at
	back.size = Vector2(width * codes.size(), 62)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", _panel(Color("fffaf1"), 31, Color.WHITE))
	_art_canvas.add_child(back)
	var to_index := maxi(codes.find(current), 0)
	var from_index: int = codes.find(_segment_shown.get(prefix, current))
	if from_index < 0:
		from_index = to_index
	_segment_shown[prefix] = current
	var thumb := Panel.new()
	thumb.name = prefix + "Thumb"
	thumb.position = at + Vector2(from_index * width, 0)
	thumb.size = Vector2(width, 62)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_theme_stylebox_override("panel", _panel(Color("078ee4"), 31, Color.WHITE))
	_art_canvas.add_child(thumb)
	var buttons: Array[Button] = []
	for index in codes.size():
		var code: String = codes[index]
		var button := Button.new()
		button.name = prefix + code
		button.text = labels[index]
		button.position = at + Vector2(index * width, 0)
		button.size = Vector2(width, 62)
		button.add_theme_font_override("font", BODY_FONT)
		button.add_theme_font_size_override("font_size", 33)
		var selected := index == to_index
		_segment_ink(Color.WHITE if index == from_index else INK, button)
		button.add_theme_stylebox_override("normal", _panel(Color.TRANSPARENT, 31))
		button.add_theme_stylebox_override("pressed", _panel(Color.TRANSPARENT, 31))
		# The thumb shows through the chosen one; the others light up softly.
		button.add_theme_stylebox_override("hover", _panel(Color("ffffff22") if selected else Color("e9f6ff"), 31))
		button.add_theme_stylebox_override("focus", _panel(Color.TRANSPARENT, 31, BLUE))
		button.pressed.connect(pick.bind(code))
		_art_canvas.add_child(button)
		buttons.append(button)
	if from_index != to_index:
		# Each label turns white as much as the thumb lies under it, so the
		# words stay readable all the way (a plain cross-fade went grey on blue).
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(_slide_thumb.bind(thumb, buttons), thumb.position.x, at.x + to_index * width, SEGMENT_SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# A slight stretch while it travels, so it feels like it glides.
		thumb.pivot_offset = thumb.size / 2.0
		var squash := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		squash.tween_property(thumb, "scale", Vector2(1.06, 0.9), SEGMENT_SLIDE * 0.4).set_trans(Tween.TRANS_SINE)
		squash.tween_property(thumb, "scale", Vector2.ONE, SEGMENT_SLIDE * 0.6).set_trans(Tween.TRANS_SINE)
		# Changing quality or language makes this frame slow; started now, the
		# slide would spend most of its time in that one frame and look like a jump.
		_play_after_hitch([tween, squash])
	_slide_thumb(thumb.position.x, thumb, buttons)
	return buttons

## Moves the thumb to `x` and colours each label by how much of it is covered.
func _slide_thumb(x: float, thumb: Panel, buttons: Array[Button]) -> void:
	if not is_instance_valid(thumb):
		return
	thumb.position.x = x
	for button in buttons:
		var covered := clampf(1.0 - absf(button.position.x - x) / button.size.x, 0.0, 1.0)
		# Short switch around half-covered: mixed shades are grey on both backgrounds.
		_segment_ink(INK.lerp(Color.WHITE, smoothstep(0.35, 0.65, covered)), button)

## Holds `tweens` for two frames (the slow one and the next, whose time step
## still includes it), then plays them.
func _play_after_hitch(tweens: Array) -> void:
	for tween: Tween in tweens:
		tween.pause()
	for i in 2:
		await get_tree().process_frame
	for tween: Tween in tweens:
		if tween.is_valid():
			tween.play()

## Text colour of a segment button in every state (tweened when the thumb moves).
func _segment_ink(colour: Color, button: Button) -> void:
	if not is_instance_valid(button):
		return
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, colour)

func configure_level(world: Node, level: int) -> void:
	if not loading:
		Sound.music("level")
	# Before _ready: don't start another mission's phone or install its apps.
	var computers := world.get_node("Computers")
	computers.netplan_edu_hosts = PackedStringArray(["IT-PC-01"]) if level == 1 else PackedStringArray()
	computers.windows_security_hosts = PackedStringArray(["PC-R3-L2"]) if level == 5 else PackedStringArray()
	computers.teamviewer_hosts = PackedStringArray(["IT-PC-01"]) if level == 6 else PackedStringArray()
	computers.browser_hosts = PackedStringArray(["STAFF-PC-01", "STAFF-PC-03"]) if level == 4 else PackedStringArray()
	computers.mail_hosts = PackedStringArray(["IT-PC-01"]) if level == 6 else PackedStringArray()
	# Installed equipment follows the story: empty in Level 1, installed but not
	# cabled in Level 2, cabled from Level 3 on.
	var rack := world.get_node_or_null("ComputerRoomRack")
	if rack:
		rack.stage = WallRack9U.Stage.EMPTY if level == 1 else (WallRack9U.Stage.INSTALLED if level == 2 else WallRack9U.Stage.CABLED)
	var access_point := world.get_node_or_null("ComputerRoomAccessPoint")
	if access_point:
		access_point.installed = level >= 2
	# The teachers work in the teachers' room when the level's mission does not
	# need them (the male teacher stands in the computer room in Levels 3, 5).
	StaffRoomLife.setup(world, level)
	# ครูแสตมป์ at the laptop in the science room, in every level.
	load("res://scripts/npc/science_teacher.gd").call("setup", world, level)
	if level == 1:
		var mission: Node = load("res://missions/mission_01/scripts/mission_01_controller.gd").new()
		mission.name = "Mission01"
		world.add_child(mission)
		_connect_level_end(mission, level)
	if level == 2:
		# Tools and cable on the spare desk in the IT Support room.
		world.add_child(load("res://missions/mission_02/scripts/mission_02_props.gd").new())
		var mission_02: Node = load("res://missions/mission_02/scripts/mission_02_controller.gd").new()
		mission_02.name = "Mission02"
		world.add_child(mission_02)
		_connect_level_end(mission_02, level)
	if level == 3:
		# Inspect three sample computers in the computer room with ipconfig / ping.
		var mission_03_script: GDScript = load("res://missions/mission_03/scripts/mission_03_controller.gd")
		# The male teacher works at TEACHER-PC until the player talks to him
		# (a resumed game where he had left: at his desk in the teachers' room).
		if bool(mission_03_script.call("teacher_left", _resume.get("mission", {}))):
			mission_03_script.call("seat_teacher_away", world)
		else:
			mission_03_script.call("seat_teacher", world)
		var mission_03: Node = mission_03_script.new()
		mission_03.name = "Mission03"
		world.add_child(mission_03)
		_connect_level_end(mission_03, level)
	if level == 4:
		# The female teacher's PC has a broken network card (NIC).
		var mission_04: Node = load("res://missions/mission_04/scripts/mission_04_controller.gd").new()
		mission_04.name = "Mission04"
		world.add_child(mission_04)
		_connect_level_end(mission_04, level)
	if level == 5:
		# Windows Security on PC-R3-L2; the male teacher works at TEACHER-PC
		# in the computer room (seated as in Level 3) and phones the player.
		load("res://missions/mission_03/scripts/mission_03_controller.gd").call("seat_teacher", world)
		# The class works at the student PCs (no students in the corridor);
		# PC-R3-L2's owner stands beside it until it is fixed.
		ClassroomStudents.setup(world)
		var mission_05: Node = load("res://missions/mission_05/scripts/mission_05_controller.gd").new()
		mission_05.name = "Mission05"
		world.add_child(mission_05)
		_connect_level_end(mission_05, level)
	if level == 6:
		# The female teacher is in the small meeting room (not at her desk);
		# the desk phone in the Data Center rings (Mission06Controller).
		_connect_level_end(world.get_node("Mission06"), level)
	if level != 6:
		var controller := world.get_node("Mission06")
		world.remove_child(controller)
		controller.free()
		world.get_node("DeskPhone").ringing = false

## Summary buttons of a mission controller: replay / main menu / next level.
func _connect_level_end(mission: Node, level: int) -> void:
	mission.connect("replay_requested", func(): start_level(level))
	mission.connect("menu_requested", return_to_menu)
	mission.connect("next_requested", func():
		var next := next_level(level)
		if next != 0:
			choose_level(next))
	# The summary is on screen: this play is over, its save goes.
	mission.connect("finished", func(_score: MissionScore):
		_level_finished = true
		LevelSave.clear(level))


## `resume`: go on from the level's mid-level save; otherwise the level starts
## from the beginning and an old save of it is removed.
func start_level(level: int, resume := false) -> void:
	if loading or not is_level_unlocked(level):
		return
	_resume = LevelSave.read(level) if resume else {}
	if _resume.is_empty():
		LevelSave.clear(level)
	_level_finished = false
	_autosave_clock = 0.0
	current_level = level
	Sound.music("menu")
	_controls_help.hide()
	_awaiting_start = false
	_load_target = 0.0
	_display_progress = 0.0
	_load_instantiating = false
	_world_prepared = false
	get_tree().paused = true
	_page("Level %d  /  กำลังโหลด" % level, TITLES[level - 1])
	_loading_visual = LoadingDelivery.new()
	_body.add_child(_loading_visual)
	# No progress bar (removed 2026-11-19 at the user's request): the mail
	# travelling between the computers and the percentage show the progress.
	_load_percent = 0
	_status = _label("กำลังโหลด . . . 0%", 32, INK, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading = true
	_load_clock = 0.0
	var error := ResourceLoader.load_threaded_request(MAP)
	if error != OK:
		_load_failed(error_string(error))

func _process(delta: float) -> void:
	# The player's _ready() captures the cursor when the world enters the tree.
	# The loading/start screen owns it until the player chooses to enter.
	if _controls_help.visible or ((loading or _awaiting_start) and _layer.visible):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Autosave while playing (game time: not while paused or on a menu).
	if current_level != 0 and not loading and not _awaiting_start and not get_tree().paused:
		_autosave_clock += delta
		if _autosave_clock >= AUTOSAVE_SEC:
			_autosave_clock = 0.0
			save_level()
	if not loading:
		return
	_load_clock += delta
	if not _load_instantiating:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(MAP, progress)
		if not progress.is_empty():
			# Display never gets ahead of real progress. Reserve 100% for scene readiness.
			_load_target = maxf(_load_target, minf(float(progress[0]) * 100.0, 99.0))
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_load_failed("ไม่สามารถโหลดฉากโรงเรียนได้")
			return
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			_load_instantiating = true
			call_deferred("_enter_loaded_level")
	_display_progress = move_toward(_display_progress, _load_target, delta * 75.0)
	_set_load_progress(int(_display_progress))
	if _world_prepared and _display_progress >= 100.0:
		loading = false
		_awaiting_start = true
		_page_title.text = "Level %d  /  พร้อมแล้ว" % current_level
		_status.hide()
		Sound.play("load_complete")
		_show_start_prompt(_load_saved)

func _set_load_progress(percent: int) -> void:
	_load_percent = percent
	_loading_visual.set_percent(percent)
	_status.text = "กำลังโหลด . . . %d%%" % percent

func _load_failed(message: String) -> void:
	loading = false
	_awaiting_start = false
	current_level = 0
	_page("โหลดไม่สำเร็จ", message)
	_button("กลับเมนู", show_home)

func _enter_loaded_level() -> void:
	var packed := ResourceLoader.load_threaded_get(MAP) as PackedScene
	if packed == null:
		_load_failed("ไม่พบฉากเกม")
		return
	var world := packed.instantiate()
	configure_level(world, current_level)
	var old := get_tree().current_scene
	get_tree().root.add_child(world)
	apply_world_quality(world)
	if not _resume.is_empty():
		_restore_level(world)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().current_scene = world
	if old:
		old.queue_free()
	last_level = current_level
	_config.set_value("session", "last_level", last_level)
	_load_saved = _save_preferences()
	get_tree().paused = true
	_world_prepared = true
	_load_target = 100.0


## The level's controller ("Mission0N" in the world), or null.
func _mission(world: Node = null) -> Node:
	var root := world if world else get_tree().current_scene
	if root == null or current_level == 0:
		return null
	var node := root.get_node_or_null("Mission%02d" % current_level)
	return node if node and node.has_method("save_snapshot") else null


## Puts the saved game back once the controller is ready (the tree is still
## paused behind the start page).
func _restore_level(world: Node) -> void:
	var mission := _mission(world)
	if mission == null:
		_resume = {}
		return
	mission.call("restore_snapshot", _resume.get("mission", {}))
	# Time per step goes on from where it was.
	var hud := mission.get("hud") as ObjectiveHUD
	var saved_steps: Variant = _resume.get("step_seconds", [])
	if hud and saved_steps is Array:
		for i in (saved_steps as Array).size():
			if i < hud.step_seconds.size():
				hud.step_seconds[i] = float(saved_steps[i])
			else:
				hud.step_seconds.append(float(saved_steps[i]))
	# When the mistakes so far happened (and which lines were there from the start).
	if hud and _resume.get("mistake_seen") is Dictionary:
		hud.mistake_seen = (_resume["mistake_seen"] as Dictionary).duplicate(true)
		hud.mistake_baseline = (_resume.get("mistake_baseline", {}) as Dictionary).duplicate()
		hud._mistakes_started = true
	LevelSave.place_player(world.get_node_or_null("ITSupportPlayer") as Node3D, _resume.get("player", {}))


## Writes the level in progress to its save. False when nothing was saved
## (no level, the summary is up, or the file could not be written).
func save_level() -> bool:
	if current_level == 0 or loading or _awaiting_start or _level_finished:
		return false
	var mission := _mission()
	if mission == null or not bool(mission.call("can_save")):
		return false
	var world := get_tree().current_scene
	var hud := mission.get("hud") as ObjectiveHUD
	return LevelSave.write(current_level, {
		"player": LevelSave.player_snapshot(world.get_node_or_null("ITSupportPlayer") as Node3D),
		"mission": mission.call("save_snapshot"),
		"step_seconds": hud.step_seconds.duplicate() if hud else [],
		"mistake_seen": hud.mistake_seen.duplicate(true) if hud else {},
		"mistake_baseline": hud.mistake_baseline.duplicate() if hud else {},
	})


func _show_start_prompt(saved: bool) -> void:
	if not saved:
		_label("บันทึกด่านล่าสุดไม่ได้ — Continue อาจใช้ไม่ได้เมื่อปิดเกม", 14)
	var start := _button("เริ่มด่าน", _begin_level)
	start.name = "StartButton"
	start.add_theme_stylebox_override("normal", _panel(Color("ed6657"), 15, Color("ffd4b5")))
	start.add_theme_stylebox_override("hover", _panel(Color("d54e4b"), 15, Color.WHITE))
	start.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _begin_level() -> void:
	if not _awaiting_start:
		return
	get_viewport().set_input_as_handled()
	_awaiting_start = false
	paused_menu = false
	_layer.hide()
	Sound.music("level")
	var hints := {4: "รับโทรศัพท์ที่โต๊ะของคุณในห้อง IT Support แล้วไปช่วยครูสาวที่ห้องพักครู", 1: "เริ่มจากคุยกับหัวหน้างาน Data Center ในห้อง IT Support", 2: "เริ่มจากคุยกับหัวหน้างาน Data Center ในห้อง IT Support แล้วอ่านใบงาน", 3: "เริ่มจากคุยกับหัวหน้างาน Data Center ในห้อง IT Support แล้วไปตรวจเครื่องในห้องคอมพิวเตอร์",5: "ใช้ Windows Security บนคอม PC-R3-L2 ในห้องเรียน", 6: "รับโทรศัพท์ที่โต๊ะในห้อง IT Support แล้วใช้ TeamViewer"}
	if not _resume.is_empty():
		_controls_help.open("เล่นต่อจากที่บันทึกไว้ — ดูขั้นตอนที่ต้องทำต่อในแท็บภารกิจ (Tab)")
		_resume = {}
		return
	_controls_help.open(String(hints.get(current_level, "")))

func _input(event: InputEvent) -> void:
	if loading or _awaiting_start or _controls_help.visible or current_level == 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# F1, or P for the web (browsers keep F1 for their help page). P is a
		# letter: not while the player types in a text box (e.g. ping in Level 3).
		if event.keycode == KEY_F1 or (event.keycode == KEY_P and not _typing()):
			get_viewport().set_input_as_handled()
			if paused_menu:
				resume_game()
			elif not get_tree().paused:
				pause_game()

func _typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

## Web: while the mouse is captured the browser keeps Esc for itself — it only
## releases the pointer lock and the game never sees the key. So a release the
## game did not ask for (Esc, Alt+Tab) opens the pause menu. Godot's own
## releases go through document.exitPointerLock, which is marked as intended.
var _browser_unlock_callback: JavaScriptObject

func _hook_browser_unlock() -> void:
	if not OS.has_feature("web"):
		return
	_browser_unlock_callback = JavaScriptBridge.create_callback(_on_browser_unlock)
	JavaScriptBridge.get_interface("window").netsimOnBrowserUnlock = _browser_unlock_callback
	JavaScriptBridge.eval("""
(function () {
	if (window.netsimUnlockHooked) return;
	window.netsimUnlockHooked = true;
	var intended = false;
	var exitLock = document.exitPointerLock.bind(document);
	document.exitPointerLock = function () { intended = true; return exitLock(); };
	document.addEventListener('pointerlockchange', function () {
		if (document.pointerLockElement) { intended = false; return; }
		var byBrowser = !intended;
		intended = false;
		if (byBrowser && window.netsimOnBrowserUnlock) window.netsimOnBrowserUnlock();
	});
})();
""", true)

## Web: the tab is hidden or the page is closing (closing the browser, going
## back to the lobby by the address bar): save the level, like the window
## close on desktop. Best effort: the browser may not wait for it.
var _browser_hide_callback: JavaScriptObject

func _hook_browser_hide() -> void:
	if not OS.has_feature("web"):
		return
	_browser_hide_callback = JavaScriptBridge.create_callback(func(_args: Array): save_level())
	JavaScriptBridge.get_interface("window").netsimOnPageHide = _browser_hide_callback
	JavaScriptBridge.eval("""
(function () {
	if (window.netsimHideHooked) return;
	window.netsimHideHooked = true;
	var save = function () { if (window.netsimOnPageHide) window.netsimOnPageHide(); };
	document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'hidden') save(); });
	window.addEventListener('pagehide', save);
})();
""", true)

func _on_browser_unlock(_args: Array) -> void:
	call_deferred("_pause_after_unlock")

func _pause_after_unlock() -> void:
	if loading or _awaiting_start or _controls_help.visible or current_level == 0:
		return
	if paused_menu or get_tree().paused:
		return
	pause_game()
	_previous_mouse = Input.MOUSE_MODE_CAPTURED # "เล่นต่อ" captures the mouse again

func pause_game() -> void:
	_previous_mouse = Input.mouse_mode
	paused_menu = true
	get_tree().paused = true
	show_pause()

func show_pause() -> void:
	_page("พักเกม / ด่าน %d" % current_level, "พักเกม • ภารกิจจะหยุดระหว่างเปิดเมนู", SMALL_CARD_WIDTH)
	# Only "play on" is blue; the rest are grey-white (user 2026-11-18). The
	# lobby is reached from the main menu, so it is not offered here.
	# "บันทึกและออก" (teacher's request 2026-11-24) saves the level and goes
	# to the main menu, where "เล่นต่อ" comes back to it.
	_button("เล่นต่อ", resume_game).grab_focus()
	_quiet_button(_button("ตั้งค่า", show_settings, false, false))
	var save_quit := _button("บันทึกและออก", save_and_quit, false, false)
	save_quit.name = "SaveAndQuit"
	_quiet_button(save_quit)

## Grey-white look for a secondary menu button.
func _quiet_button(button: Button) -> void:
	var normal := _panel(Color("f1f4f8"), 15, Color("d3dce6"))
	normal.shadow_color = Color("193a6122")
	normal.shadow_size = 4
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _panel(Color("e4ebf2"), 15, Color("b9c7d6")))
	button.add_theme_stylebox_override("pressed", _panel(Color("d6e0ea"), 15, Color("a9b9ca")))
	button.add_theme_color_override("font_pressed_color", INK)

func resume_game() -> void:
	if _awaiting_start:
		_begin_level()
		return
	var mode := _previous_mouse if paused_menu else Input.MOUSE_MODE_CAPTURED
	paused_menu = false
	_layer.hide()
	get_tree().paused = false
	Input.mouse_mode = mode

## Pause page: save the level and leave to the main menu. After the summary
## there is nothing to save; it just leaves. If writing fails the player
## chooses to leave anyway or stay.
func save_and_quit() -> void:
	if _level_finished or _mission() == null or not bool(_mission().call("can_save")):
		return_to_menu()
		return
	if save_level():
		return_to_menu()
		return
	_page("บันทึกไม่สำเร็จ", "ถ้าออกตอนนี้ ความคืบหน้าในด่านนี้จะหายไป", SMALL_CARD_WIDTH)
	_button("ลองอีกครั้ง", save_and_quit).grab_focus()
	_quiet_button(_button("ออกโดยไม่บันทึก", return_to_menu, false, false))
	_quiet_button(_button("ยกเลิก", show_pause, false, false))


## Closing the window (desktop) saves the level first.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_level()


func confirm_menu() -> void:
	_page("กลับเมนูหลัก?", "เก็บเฉพาะความคืบหน้าที่ระบบภารกิจบันทึกไว้\nตำแหน่งยืนและหน้าต่างที่เปิดจะไม่ถูกเก็บ", SMALL_CARD_WIDTH)
	_button("กลับเมนูหลัก", return_to_menu)
	_button("ยกเลิก", show_pause)

func return_to_menu() -> void:
	_controls_help.hide()
	_awaiting_start = false
	paused_menu = false
	current_level = 0
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU)
	show_home()

## The logged-in student's results arrived from the website (ServerSync). Redraw the
## menu page on screen so stars, unlocking and Continue match them. After a change
## of student on a shared computer, Continue no longer points at the previous
## student's level.
func on_progress_synced(account_changed: bool) -> void:
	if account_changed:
		last_level = 0
		_config.set_value("session", "last_level", 0)
		_save_preferences()
	if current_level != 0 or loading:
		return
	match _screen:
		"home":
			show_home()
		"levels":
			show_levels()
		"progress":
			show_progress()

func confirm_exit() -> void:
	_page("กลับหน้า Lobby?", "ออกจากเกม • เก็บเฉพาะความคืบหน้าที่ภารกิจบันทึกไว้", SMALL_CARD_WIDTH)
	_button("Exit to Lobby", exit_to_lobby)
	_button("ยกเลิก", show_pause if paused_menu else show_home)

func exit_to_lobby() -> void:
	_save_preferences()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.has_feature("web"):
		# Deployment setting, never read an arbitrary redirect from the query string.
		var url := str(ProjectSettings.get_setting("application/web_lobby_url", "../"))
		JavaScriptBridge.eval("window.location.assign(%s);" % JSON.stringify(url))
	else:
		# Native Godot has no web lobby to return to.
		return_to_menu()
