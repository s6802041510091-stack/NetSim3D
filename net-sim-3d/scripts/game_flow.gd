extends Node

## Lightweight front door: the school is loaded only after a level is selected.
## Continue restores the last level, not the player's exact position. Mission
## programs retain their existing independent autosave files.
const MAP := "res://scenes/main.tscn"
const MENU := "res://scenes/start_menu.tscn"
var save_file := SavePaths.file("menu.cfg")
const AVAILABLE := [1, 2, 5, 6]
const TITLES := ["ออกแบบเครือข่าย", "ประกอบและเชื่อมต่อสาย LAN", "ตรวจรับระบบเครือข่าย", "ตรวจสอบและเปลี่ยนการ์ดเครือข่าย", "ความปลอดภัยของคอมพิวเตอร์", "ช่วยเหลือผ่าน Remote Desktop"]
const AUDIO := {"Music": "เสียงเพลงประกอบ", "SoundEffect": "เสียงภารกิจ / โทรศัพท์ / คอมพิวเตอร์ / เสียงพูด", "Sound": "เสียงบรรยากาศ / เดิน / เปิด–ปิดประตู"}

var current_level := 0
var last_level := 0
var volumes := {"Music": 80.0, "SoundEffect": 80.0, "Sound": 80.0}
var loading := false
var paused_menu := false
var _previous_mouse := Input.MOUSE_MODE_VISIBLE
var _layer: CanvasLayer
var _background: ColorRect
var _body: VBoxContainer
var _progress: ProgressBar
var _status: Label
var _config := ConfigFile.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_preferences()
	_build_shell()
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
	_background = ColorRect.new()
	_background.color = Color("101f35")
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_background.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_body = VBoxContainer.new()
	_body.custom_minimum_size.x = 280
	_body.add_theme_constant_override("separation", 12)
	center.add_child(_body)
	_layer.hide()

func _page(title: String, subtitle: String) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_layer.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_label("NETSIM / SCHOOL NETWORK LAB", 14, Color("77d7e0"))
	_label(title, 34)
	_label(subtitle, 16, Color("b3c5db"))
	_body.add_child(HSeparator.new())

func _label(text: String, size := 18, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)
	return label

func _button(text: String, action: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	button.disabled = disabled
	button.pressed.connect(action)
	_body.add_child(button)
	return button

func show_home() -> void:
	Sound.music("menu")
	_page("NetSim3D", "เรียนรู้เครือข่าย ผ่านภารกิจในโรงเรียน")
	_button("Play  /  เลือกด่าน", show_levels).grab_focus()
	_button("Continue  /  Level %d" % last_level if last_level else "Continue  /  ยังไม่มีด่านล่าสุด", func(): start_level(last_level), last_level == 0)
	_button("Setting  /  ตั้งค่าเสียง", show_settings)
	_button("Exit  /  กลับ Lobby", confirm_exit)
	_label("Continue: เริ่มที่จุดเกิดของด่านล่าสุด\nใช้ความคืบหน้าภารกิจที่บันทึกไว้ ไม่ใช่ตำแหน่งยืนล่าสุด", 14, Color("b3c5db"))

func show_levels() -> void:
	_page("Play", "เลือกด่าน • ผ่านด่าน (50 คะแนนขึ้นไป) เพื่อปลดล็อกด่านถัดไป")
	for level in range(1, 7):
		var suffix := ""
		if not level in AVAILABLE:
			suffix = "  [กำลังพัฒนา]"
		elif not is_level_unlocked(level):
			suffix = "  [ล็อก — ผ่านด่านก่อนหน้าก่อน]"
		else:
			var best := GameProgress.best_score(level)
			if best >= 0:
				suffix = "  %s  สูงสุด %d" % [MissionScore.star_text(MissionScore.stars_for(best)), best]
		_button("Level %d  —  %s%s" % [level, TITLES[level - 1], suffix], start_level.bind(level), not is_level_unlocked(level))
	if OS.has_feature("editor"):
		_label("โหมดทดสอบใน Editor: เปิดทุกด่านที่สร้างแล้ว (บนเว็บต้องผ่านด่านก่อนหน้า)", 13, Color("b3c5db"))
	_button("← Back", show_home)


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
	_page("Sound Volume", "แยกระดับเสียงแต่ละกลุ่ม • บันทึกอัตโนมัติ")
	for bus: String in AUDIO:
		_label(bus + "  ·  " + AUDIO[bus], 16)
		var row := HBoxContainer.new()
		_body.add_child(row)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = volumes[bus]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(220, 36)
		row.add_child(slider)
		var percent := Label.new()
		percent.custom_minimum_size.x = 58
		percent.text = "%d%%" % slider.value
		row.add_child(percent)
		slider.value_changed.connect(func(value: float):
			set_volume(bus, value)
			percent.text = "%d%%" % value)
	_label("เสียงประกอบ: Kenney.nl (CC0) และเสียงที่สร้างในโปรแกรม • เพลง: OpenGameArt.org (CC0)", 14, Color("b3c5db"))
	_button("← Back", show_pause if paused_menu else show_home)

func configure_level(world: Node, level: int) -> void:
	Sound.music("level")
	# Before _ready: don't start another mission's phone or install its apps.
	var computers := world.get_node("Computers")
	computers.netplan_edu_hosts = PackedStringArray(["IT-PC-01"]) if level == 1 else PackedStringArray()
	computers.windows_security_hosts = PackedStringArray(["PC-R3-L2"]) if level == 5 else PackedStringArray()
	computers.teamviewer_hosts = PackedStringArray(["IT-PC-01"]) if level == 6 else PackedStringArray()
	# Installed equipment follows the story: empty in Level 1, installed but not
	# cabled in Level 2, cabled from Level 3 on.
	var rack := world.get_node_or_null("ComputerRoomRack")
	if rack:
		rack.stage = WallRack9U.Stage.EMPTY if level == 1 else (WallRack9U.Stage.INSTALLED if level == 2 else WallRack9U.Stage.CABLED)
	var access_point := world.get_node_or_null("ComputerRoomAccessPoint")
	if access_point:
		access_point.installed = level >= 2
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
	_page("Level %d" % level, "กำลังโหลดโรงเรียน… ครั้งแรกอาจใช้เวลาสักครู่")
	_progress = ProgressBar.new()
	_body.add_child(_progress)
	_status = _label("0%", 16)
	loading = true
	var error := ResourceLoader.load_threaded_request(MAP)
	if error != OK:
		_load_failed(error_string(error))

func _process(_delta: float) -> void:
	if not loading:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAP, progress)
	if not progress.is_empty():
		_progress.value = float(progress[0]) * 100.0
		_status.text = "%d%%" % _progress.value
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_load_failed("ไม่สามารถโหลดฉากโรงเรียนได้")
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		loading = false
		_status.text = "กำลังเตรียมฉาก…"
		call_deferred("_enter_loaded_level")

func _load_failed(message: String) -> void:
	loading = false
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
	get_tree().current_scene = world
	if old:
		old.queue_free()
	last_level = current_level
	_config.set_value("session", "last_level", last_level)
	var saved := _save_preferences()
	get_tree().paused = true
	_page("Level %d  /  พร้อมแล้ว" % current_level, TITLES[current_level - 1])
	var hints := {1: "เริ่มจากคุยกับหัวหน้างาน Data Center ในห้อง IT Support", 2: "เริ่มจากคุยกับหัวหน้างาน Data Center ในห้อง IT Support แล้วอ่านใบงาน", 5: "ใช้ Windows Security บนคอม PC-R3-L2 ในห้องเรียน", 6: "รับโทรศัพท์ที่โต๊ะในห้อง IT Support แล้วใช้ TeamViewer"}
	_label(String(hints.get(current_level, "")), 16)
	_label("WASD เดิน • เมาส์มอง • F โต้ตอบ\nE กระเป๋า • F1 เปิดเมนูพักได้ทุกเวลา", 16)
	if not saved:
		_label("บันทึกด่านล่าสุดไม่ได้ — Continue อาจใช้ไม่ได้เมื่อปิดเกม", 14)
	_button("เข้าเล่น  /  Click to start", resume_game).grab_focus()

func _input(event: InputEvent) -> void:
	if loading or current_level == 0:
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
	_page("Paused  /  Level %d" % current_level, "พักเกม • ภารกิจจะหยุดระหว่างเปิดเมนู")
	_button("Resume  /  เล่นต่อ", resume_game).grab_focus()
	_button("Setting  /  ตั้งค่าเสียง", show_settings)
	_button("Main Menu  /  กลับเมนูหลัก", confirm_menu)
	_button("Exit  /  กลับ Lobby", confirm_exit)

func resume_game() -> void:
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
