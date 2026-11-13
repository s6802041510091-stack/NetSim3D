extends Node

## Lightweight front door: the school is loaded only after a level is selected.
## Continue restores the last level, not the player's exact position. Mission
## programs retain their existing independent autosave files.
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
var _screen := "home"
var _card: PanelContainer
var _positioner: MarginContainer
var _body: VBoxContainer
var _page_title: Label
var _progress: ProgressBar
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

const INK := Color("20364c")
const MUTED := Color("526b81")
const SKY := Color("e9f6ff")
const BLUE := Color("237db1")
const CORAL := Color("e97775")
const HEADING_FONT := preload("res://assets/fonts/Anuphan-Variable.ttf")
const BODY_FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")
const MENU_BACKGROUND := preload("res://assets/ui/school_spring_background.png")
const HOME_REFERENCE := preload("res://assets/ui/home_reference_exact.png")
const HOME_TH := preload("res://assets/ui/home_th.png")
const LEVELS_TH := preload("res://assets/ui/select_level_th.png")
const LEVELS_EN := preload("res://assets/ui/select_level_en.png")
const SETTINGS_TH := preload("res://assets/ui/settings_th_base.png")
const SETTINGS_EN := preload("res://assets/ui/settings_en_base.png")

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
	# Direct F6/test scene launches must retain their original behavior.
	call_deferred("_show_initial_menu")

func _show_initial_menu() -> void:
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == MENU:
		show_home()

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
	_breeze = MenuBreeze.new()
	_breeze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.add_child(_breeze)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_background.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
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
		padding.add_theme_constant_override("margin_" + side, 25)
	_card.add_child(padding)
	_body = VBoxContainer.new()
	_body.custom_minimum_size.x = 280
	_body.add_theme_constant_override("separation", 10)
	padding.add_child(_body)
	_home_hotspots = Control.new()
	_home_hotspots.name = "HomeHotspots"
	_home_hotspots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home_hotspots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_home_hotspots)
	_home_hotspots.hide()
	_layer.hide()

func _page(title: String, subtitle: String, card_width := 900, right_space := 0, home := false) -> void:
	_screen = "generic"
	_home_hotspots.hide()
	_card.show()
	_background.texture = MENU_BACKGROUND
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_card.custom_minimum_size.x = card_width
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
	_background.texture = texture
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	for child in _home_hotspots.get_children():
		_home_hotspots.remove_child(child)
		child.queue_free()
	_home_hotspots.show()
	_art_canvas = Control.new()
	_art_canvas.size = Vector2(1672, 943)
	_art_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_hotspots.add_child(_art_canvas)
	_scale_art()
	if not _home_hotspots.resized.is_connected(_scale_art):
		_home_hotspots.resized.connect(_scale_art)

func _scale_art() -> void:
	if is_instance_valid(_art_canvas):
		_art_canvas.scale = _home_hotspots.size / Vector2(1672, 943)

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
	_home_hotspot("PLAY", 383, 470, show_levels)
	_home_hotspot("CONTINUE", 484, 570, func(): start_level(last_level), last_level == 0)
	_home_hotspot("SETTINGS", 585, 670, show_settings)
	_home_hotspot("EXIT TO LOBBY", 685, 771, confirm_exit)

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
		_art_button("Level%d" % level, Rect2(x, y, 326, 211), start_level.bind(level), not is_level_unlocked(level), hint)
	_art_button("Back", Rect2(265, 829, 204, 58), show_home)


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
	var segment := Panel.new()
	segment.position = Vector2(1170, 318)
	segment.size = Vector2(308, 62)
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_theme_stylebox_override("panel", _panel(Color("fffaf1"), 31, Color.WHITE))
	_art_canvas.add_child(segment)
	var languages := ["th", "en"]
	for index in range(2):
		var code: String = languages[index]
		var button := Button.new()
		button.name = "Language_" + code
		button.text = "ไทย" if code == "th" else "ENG"
		button.position = Vector2(1170 + index * 154, 318)
		button.size = Vector2(154, 62)
		button.add_theme_font_override("font", BODY_FONT)
		button.add_theme_font_size_override("font_size", 33)
		var selected := L10n.locale == code
		button.add_theme_color_override("font_color", Color.WHITE if selected else INK)
		button.add_theme_color_override("font_hover_color", Color.WHITE if selected else INK)
		button.add_theme_stylebox_override("normal", _panel(Color("078ee4") if selected else Color.TRANSPARENT, 31, Color.WHITE if selected else Color.TRANSPARENT))
		button.add_theme_stylebox_override("hover", _panel(Color("168bce") if selected else Color("e9f6ff"), 31, Color.WHITE))
		button.add_theme_stylebox_override("focus", _panel(Color.TRANSPARENT, 31, BLUE))
		button.pressed.connect(func(): L10n.set_locale(code))
		_art_canvas.add_child(button)
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

func configure_level(world: Node, level: int) -> void:
	if not loading:
		Sound.music("level")
	# Before _ready: don't start another mission's phone or install its apps.
	var computers := world.get_node("Computers")
	computers.netplan_edu_hosts = PackedStringArray(["IT-PC-01"]) if level == 1 else PackedStringArray()
	computers.windows_security_hosts = PackedStringArray(["PC-R3-L2"]) if level == 5 else PackedStringArray()
	computers.teamviewer_hosts = PackedStringArray(["IT-PC-01"]) if level == 6 else PackedStringArray()
	computers.browser_hosts = PackedStringArray(["STAFF-PC-01", "STAFF-PC-03"]) if level == 4 else PackedStringArray()
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
		# The male teacher works at TEACHER-PC until the player talks to him.
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
			start_level(next))


func start_level(level: int) -> void:
	if loading or not is_level_unlocked(level):
		return
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
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 12
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _panel(Color("d7e8ee"), 9))
	_progress.add_theme_stylebox_override("fill", _panel(CORAL, 9))
	_body.add_child(_progress)
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
	_progress.value = percent
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
	_controls_help.open(String(hints.get(current_level, "")))

func _input(event: InputEvent) -> void:
	if loading or _awaiting_start or _controls_help.visible or current_level == 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			if paused_menu:
				resume_game()
			elif not get_tree().paused:
				pause_game()

func pause_game() -> void:
	_previous_mouse = Input.mouse_mode
	paused_menu = true
	get_tree().paused = true
	show_pause()

func show_pause() -> void:
	_page("พักเกม / ด่าน %d" % current_level, "พักเกม • ภารกิจจะหยุดระหว่างเปิดเมนู")
	_button("เล่นต่อ", resume_game).grab_focus()
	_button("ตั้งค่า", show_settings)
	_button("กลับเมนูหลัก", confirm_menu)
	_button("กลับล็อบบี้", confirm_exit)

func resume_game() -> void:
	if _awaiting_start:
		_begin_level()
		return
	var mode := _previous_mouse if paused_menu else Input.MOUSE_MODE_CAPTURED
	paused_menu = false
	_layer.hide()
	get_tree().paused = false
	Input.mouse_mode = mode

func confirm_menu() -> void:
	_page("กลับเมนูหลัก?", "เก็บเฉพาะความคืบหน้าที่ระบบภารกิจบันทึกไว้\nตำแหน่งยืนและหน้าต่างที่เปิดจะไม่ถูกเก็บ")
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

func confirm_exit() -> void:
	_page("กลับหน้า Lobby?", "ออกจากเกม • เก็บเฉพาะความคืบหน้าที่ภารกิจบันทึกไว้")
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
