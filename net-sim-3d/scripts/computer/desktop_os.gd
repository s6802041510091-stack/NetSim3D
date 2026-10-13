class_name DesktopOS
extends CanvasLayer

## The simulated computer screen: a 2-second set-up (boot) screen, then a
## desktop with icons, windows, a taskbar and a Command Prompt that knows
## ipconfig, ping and hostname. Built in code so it needs no extra assets.

signal shutdown_requested
signal desktop_ready
## Emitted when a program window opens, e.g. ("network_designer", NetworkDesigner).
## The mission system connects here to follow the player's progress.
signal app_opened(app_id: String, app: Node)

const BOOT_TIME := 2.0
## Mission 1 program (NetPlan EDU). Shown only on computers that have "netplan_edu" installed.
const NETPLAN_EDU_SCENE := "res://scenes/missions/mission_01/netplan_edu.tscn"
## Mission 5 program: Windows Security (simulated). Shown only on computers that have "windows_security".
const WINDOWS_SECURITY_SCENE := "res://scenes/missions/mission_05/windows_security.tscn"
## Mission 6 program: TeamViewer (simulated). Shown only on computers that have "teamviewer".
const TEAMVIEWER_SCENE := "res://scenes/missions/mission_06/teamviewer.tscn"
const OS_NAME := "NetSim OS"
const COLOR_TASKBAR := Color(0.07, 0.09, 0.13, 0.95)
const COLOR_WINDOW := Color(0.96, 0.97, 0.98)
const COLOR_TITLE := Color(0.13, 0.33, 0.62)
const COLOR_TEXT := Color(0.1, 0.12, 0.16)

var manager: Node
var station: ComputerStation
var is_booting := false

var _root: Control
var _boot: Control
var _boot_bar: ProgressBar
var _boot_status: Label
var _desktop: Control
var _window_layer: Control
var _start_menu: PanelContainer
var _clock: Label
var _tray_network: Label
var _windows := {}
var _cmd_output: RichTextLabel
var _cmd_input: LineEdit
var _icons: VBoxContainer
var _designer_icon: Control
var _netplan_icon: Control
var _netplan: Control
var _winsec_icon: Control
var _winsec: Control
var _security_toast: PanelContainer
var _teamviewer_icon: Control
var _teamviewer: Control
var _session := 0
var _tween: Tween


func _ready() -> void:
	layer = 10
	visible = false
	_build()


# ---------------------------------------------------------------- power

func power_on(target: ComputerStation) -> void:
	station = target
	_session += 1
	visible = true
	_close_all_windows()
	_start_menu.visible = false
	_desktop.visible = false
	_boot.visible = true
	is_booting = true
	_boot_bar.value = 0.0
	_boot_status.text = "กำลังตั้งค่าระบบ (Set-up)..."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if _tween:
		_tween.kill()
	_root.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_boot_bar, "value", 100.0, BOOT_TIME)
	_tween.parallel().tween_callback(func(): _boot_status.text = "กำลังโหลดไดรเวอร์เครือข่าย...").set_delay(BOOT_TIME * 0.45)
	_tween.parallel().tween_callback(func(): _boot_status.text = "ยินดีต้อนรับ").set_delay(BOOT_TIME * 0.85)
	_tween.tween_callback(_show_desktop)


func power_off() -> void:
	_session += 1
	if _tween:
		_tween.kill()
	is_booting = false
	_close_all_windows()
	visible = false


func _show_desktop() -> void:
	is_booting = false
	_boot.visible = false
	_desktop.visible = true
	_update_clock()
	_tray_network.text = "LAN ✓" if station.network_connected else "LAN ✗"
	_designer_icon.visible = station.has_app("network_designer")
	_netplan_icon.visible = station.has_app("netplan_edu")
	_winsec_icon.visible = station.has_app("windows_security")
	_teamviewer_icon.visible = station.has_app("teamviewer")
	# The security warning the teacher saw (Mission 5) pops up until the computer is fixed.
	_security_toast.visible = station.has_app("windows_security") and station.screen_alert
	desktop_ready.emit()


func _process(_delta: float) -> void:
	if visible and _desktop.visible:
		_update_clock()


func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	_clock.text = "%02d:%02d" % [t.hour, t.minute]


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_booting:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		# NetPlan EDU first: Esc closes its pop-up, then the program itself.
		if _netplan != null and is_instance_valid(_netplan) and _netplan.call("handle_escape"):
			return
		if _winsec != null and is_instance_valid(_winsec) and _winsec.visible and _winsec.call("handle_escape"):
			return
		if _teamviewer != null and is_instance_valid(_teamviewer) and _teamviewer.visible and _teamviewer.call("handle_escape"):
			return
		if _start_menu.visible:
			_start_menu.visible = false
		else:
			request_shutdown()


# ---------------------------------------------------------------- building

func _build() -> void:
	_root = Control.new()
	_root.name = "Screen"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_build_boot()
	_build_desktop()


func _build_boot() -> void:
	_boot = ColorRect.new()
	_boot.color = Color(0.02, 0.03, 0.06)
	_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_boot)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -90)
	box.add_theme_constant_override("separation", 18)
	_boot.add_child(box)

	var logo := _label(OS_NAME, 54, Color(0.45, 0.75, 1.0))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(logo)

	_boot_bar = ProgressBar.new()
	_boot_bar.custom_minimum_size = Vector2(420, 10)
	_boot_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.65, 1.0)
	_boot_bar.add_theme_stylebox_override("background", bg)
	_boot_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_boot_bar)

	_boot_status = _label("", 18, Color(0.8, 0.85, 0.9))
	_boot_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_boot_status)


func _build_desktop() -> void:
	_desktop = Control.new()
	_desktop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_desktop)

	var wallpaper := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.22, 0.42))
	gradient.set_color(1, Color(0.02, 0.55, 0.62))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 1)
	wallpaper.texture = texture
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_SCALE
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _start_menu.visible = false)
	_desktop.add_child(wallpaper)

	var icons := VBoxContainer.new()
	icons.position = Vector2(24, 24)
	icons.add_theme_constant_override("separation", 14)
	_desktop.add_child(icons)
	_icons = icons
	icons.add_child(_desktop_icon("PC", Color(0.35, 0.6, 0.95), "This PC", _open_this_pc))
	icons.add_child(_desktop_icon("NET", Color(0.2, 0.75, 0.5), "Network", _open_network))
	icons.add_child(_desktop_icon(">_", Color(0.15, 0.15, 0.18), "Command Prompt", _open_cmd))
	_designer_icon = _desktop_icon("ND", Color(0.95, 0.55, 0.15), "Network Designer", open_network_designer)
	icons.add_child(_designer_icon)
	_netplan_icon = _desktop_icon("NP", Color(0.2, 0.6, 0.95), "NetPlan EDU", open_netplan_edu)
	_netplan_icon.name = "NetPlanEduIcon"
	icons.add_child(_netplan_icon)
	_winsec_icon = _desktop_icon("WS", Color(0.0, 0.37, 0.72), "Windows Security", open_windows_security)
	_winsec_icon.name = "WindowsSecurityIcon"
	icons.add_child(_winsec_icon)
	_teamviewer_icon = _desktop_icon("TV", Color(0.05, 0.39, 0.82), "TeamViewer", open_teamviewer)
	_teamviewer_icon.name = "TeamViewerIcon"
	icons.add_child(_teamviewer_icon)
	icons.add_child(_desktop_icon("BIN", Color(0.55, 0.6, 0.65), "Recycle Bin", _open_recycle_bin))

	_window_layer = Control.new()
	_window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.add_child(_window_layer)

	_build_taskbar()
	_build_security_toast()


func _build_taskbar() -> void:
	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -48.0
	bar.add_theme_stylebox_override("panel", _flat(COLOR_TASKBAR))
	_desktop.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	var start := Button.new()
	start.text = "  เริ่ม  "
	start.custom_minimum_size = Vector2(90, 40)
	start.pressed.connect(func(): _start_menu.visible = not _start_menu.visible)
	row.add_child(start)

	var hint := _label("Esc = ลุกจากเครื่อง", 15, Color(0.75, 0.8, 0.88))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	_tray_network = _label("LAN ✓", 16, Color(0.7, 0.95, 0.75))
	_tray_network.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_tray_network)
	_clock = _label("00:00", 18, Color.WHITE)
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.custom_minimum_size = Vector2(70, 0)
	row.add_child(_clock)

	_start_menu = PanelContainer.new()
	_start_menu.anchor_top = 1.0
	_start_menu.anchor_bottom = 1.0
	_start_menu.offset_left = 4.0
	_start_menu.offset_top = -48.0 - 210.0
	_start_menu.offset_right = 264.0
	_start_menu.offset_bottom = -52.0
	_start_menu.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.14, 0.2, 0.97), 8))
	_start_menu.visible = false
	_desktop.add_child(_start_menu)
	var menu := VBoxContainer.new()
	_start_menu.add_child(menu)
	menu.add_child(_label("  " + OS_NAME, 20, Color(0.55, 0.8, 1.0)))
	for item in [["This PC", _open_this_pc], ["Network", _open_network], ["Command Prompt", _open_cmd], ["Network Designer", open_network_designer], ["NetPlan EDU", open_netplan_edu], ["Windows Security", open_windows_security], ["TeamViewer", open_teamviewer]]:
		menu.add_child(_menu_button(item[0], item[1]))
	menu.add_child(HSeparator.new())
	menu.add_child(_menu_button("ปิดเครื่อง (Shut down)", request_shutdown))


func _desktop_icon(glyph: String, color: Color, title: String, action: Callable) -> Control:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(96, 86)
	button.tooltip_text = title
	button.pressed.connect(action)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(box)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(46, 40)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", _flat(color, 6))
	var g := _label(glyph, 15, Color.WHITE)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(g)
	box.add_child(tile)
	var caption := _label(title, 14, Color.WHITE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	caption.add_theme_constant_override("outline_size", 3)
	box.add_child(caption)
	return button


func _menu_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(250, 36)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(func():
		_start_menu.visible = false
		action.call())
	return b


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _flat(color: Color, radius: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


# ---------------------------------------------------------------- windows

func _open_window(id: String, title: String, size: Vector2, build_content: Callable, maximized: bool = false) -> PanelContainer:
	if _windows.has(id):
		var existing: PanelContainer = _windows[id]
		existing.move_to_front()
		return existing

	var window := PanelContainer.new()
	window.name = id
	var style := _flat(COLOR_WINDOW, 6)
	style.border_color = Color(0, 0, 0, 0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	window.add_theme_stylebox_override("panel", style)
	var view := _root.get_viewport_rect().size
	if maximized:
		# Fill the desktop above the taskbar.
		size = Vector2(view.x - 16.0, view.y - 48.0 - 16.0)
		window.position = Vector2(8, 8)
	else:
		var offset := _windows.size() * 28.0
		window.position = Vector2(maxf(140.0, (view.x - size.x) * 0.5 + offset), maxf(20.0, (view.y - size.y) * 0.4 + offset))
	window.custom_minimum_size = size
	_window_layer.add_child(window)
	_windows[id] = window
	window.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: window.move_to_front())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	window.add_child(column)

	var title_bar := PanelContainer.new()
	var title_style := _flat(COLOR_TITLE)
	title_style.corner_radius_top_left = 6
	title_style.corner_radius_top_right = 6
	title_bar.add_theme_stylebox_override("panel", title_style)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			window.move_to_front()
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			window.position += e.relative)
	column.add_child(title_bar)
	var title_row := HBoxContainer.new()
	title_bar.add_child(title_row)
	var title_label := _label(title, 16, Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title_label)
	var close := Button.new()
	close.text = " ✕ "
	close.flat = true
	close.add_theme_color_override("font_color", Color.WHITE)
	close.pressed.connect(func(): _close_window(id))
	title_row.add_child(close)

	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 8 if maximized else 14)
	column.add_child(body)
	build_content.call(body)
	return window


func _close_window(id: String) -> void:
	if _windows.has(id):
		_windows[id].queue_free()
		_windows.erase(id)
	if id == "netplan_edu":
		_netplan = null
	if id == "windows_security":
		_winsec = null
	if id == "teamviewer":
		_teamviewer = null
	if id == "cmd":
		_cmd_output = null
		_cmd_input = null


func _close_all_windows() -> void:
	for id in _windows.keys():
		_close_window(id)


func _info_rows(parent: Control, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for row in rows:
		grid.add_child(_label(row[0], 16, Color(0.35, 0.4, 0.48)))
		grid.add_child(_label(row[1], 16, COLOR_TEXT))


func _open_this_pc() -> void:
	_open_window("this_pc", "This PC", Vector2(460, 260), func(body):
		_info_rows(body, [
			["ชื่อเครื่อง", station.hostname],
			["ระบบปฏิบัติการ", OS_NAME + " 1.0"],
			["ซีพียู", "Intel Core i5-12400 2.5 GHz"],
			["หน่วยความจำ (RAM)", "8 GB"],
			["ไดรฟ์ C:", "ว่าง 182 GB จาก 237 GB"],
		]))


func _open_network() -> void:
	_open_window("network", "Network Settings — Ethernet", Vector2(480, 320), func(body):
		var ok := station.network_connected
		_info_rows(body, [
			["สถานะ", "เชื่อมต่อแล้ว (1.0 Gbps)" if ok else "ไม่ได้เสียบสาย LAN"],
			["IPv4 Address", station.ip_address if ok else "-"],
			["Subnet Mask", station.subnet_mask if ok else "-"],
			["Default Gateway", station.gateway if ok else "-"],
			["DNS Server", station.dns_server if ok else "-"],
			["MAC Address", station.mac_address],
		]))


## Opens the Network Designer program (Mission 1). Returns the program node.
func open_network_designer() -> NetworkDesigner:
	if not station.has_app("network_designer"):
		return null
	if _windows.has("network_designer"):
		_windows["network_designer"].move_to_front()
		return _windows["network_designer"].find_child("NetworkDesigner", true, false)
	var app := NetworkDesigner.new()
	app.name = "NetworkDesigner"
	app.close_requested.connect(func(): _close_window("network_designer"))
	_open_window("network_designer", "Network Designer", Vector2.ZERO, func(body): body.add_child(app), true)
	app_opened.emit("network_designer", app)
	return app


func _build_security_toast() -> void:
	_security_toast = PanelContainer.new()
	_security_toast.name = "SecurityToast"
	_security_toast.anchor_left = 1.0
	_security_toast.anchor_right = 1.0
	_security_toast.anchor_top = 1.0
	_security_toast.anchor_bottom = 1.0
	_security_toast.offset_left = -380.0
	_security_toast.offset_right = -12.0
	_security_toast.offset_top = -48.0 - 12.0 - 118.0
	_security_toast.offset_bottom = -48.0 - 12.0
	var style := _flat(Color(0.13, 0.14, 0.18, 0.97), 6)
	style.border_color = Color(0.85, 0.2, 0.2)
	style.border_width_left = 5
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_security_toast.add_theme_stylebox_override("panel", style)
	_security_toast.visible = false
	_desktop.add_child(_security_toast)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_security_toast.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := _label("Windows Security", 16, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var dismiss := Button.new()
	dismiss.text = " x "
	dismiss.flat = true
	dismiss.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	dismiss.pressed.connect(func(): _security_toast.visible = false)
	head.add_child(dismiss)
	column.add_child(_label("พบปัญหาด้านความปลอดภัย — ต้องดำเนินการ", 15, Color(1.0, 0.72, 0.72)))
	var open := Button.new()
	open.name = "OpenSecurityButton"
	open.text = "เปิด Windows Security"
	open.pressed.connect(func():
		_security_toast.visible = false
		open_windows_security())
	column.add_child(open)


## Switch the computer off (Start -> ปิดเครื่อง, or Esc on the desktop).
## An open program may refuse, e.g. TeamViewer during a Remote Session (Mission 6).
func request_shutdown() -> void:
	if _teamviewer != null and is_instance_valid(_teamviewer) and _teamviewer.call("block_shutdown"):
		if not _teamviewer.visible:
			_teamviewer.visible = true # Bring it back from minimised so the message is seen.
		_teamviewer.move_to_front()
		return
	shutdown_requested.emit()


## Opens TeamViewer (Mission 6) full screen above the taskbar. Returns the program
## node (a TeamViewerSim). Loaded by path so the desktop still works without the mission files.
func open_teamviewer() -> Control:
	if station == null or not station.has_app("teamviewer"):
		return null
	if _teamviewer != null and is_instance_valid(_teamviewer):
		_teamviewer.visible = true # It may be minimised.
		_teamviewer.move_to_front()
		return _teamviewer
	var scene := load(TEAMVIEWER_SCENE) as PackedScene
	if scene == null:
		push_error("DesktopOS: cannot load " + TEAMVIEWER_SCENE)
		return null
	var app := scene.instantiate() as Control
	app.name = "TeamViewer"
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.offset_bottom = -48.0 # Keep the taskbar visible.
	_window_layer.add_child(app)
	_windows["teamviewer"] = app
	_teamviewer = app
	app.connect("close_requested", func(): _close_window("teamviewer"))
	app.connect("minimize_requested", func(): app.visible = false)
	app_opened.emit("teamviewer", app)
	return app


## Opens Windows Security (Mission 5) full screen above the taskbar. Returns the
## program node (a WindowsSecurity). Loaded by path so the desktop still works
## without the mission files.
func open_windows_security() -> Control:
	if station == null or not station.has_app("windows_security"):
		return null
	if _winsec != null and is_instance_valid(_winsec):
		_winsec.visible = true # It may be minimised.
		_winsec.move_to_front()
		return _winsec
	var scene := load(WINDOWS_SECURITY_SCENE) as PackedScene
	if scene == null:
		push_error("DesktopOS: cannot load " + WINDOWS_SECURITY_SCENE)
		return null
	var app := scene.instantiate() as Control
	app.name = "WindowsSecurity"
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.offset_bottom = -48.0 # Keep the taskbar visible.
	_window_layer.add_child(app)
	_windows["windows_security"] = app
	_winsec = app
	_security_toast.visible = false
	var target := station
	app.connect("close_requested", func(): _close_window("windows_security"))
	app.connect("minimize_requested", func(): app.visible = false)
	app.connect("computer_exit_requested", func(): shutdown_requested.emit())
	app.connect("protected_reached", func(): target.set_screen_alert(false))
	app_opened.emit("windows_security", app)
	return app


## Opens NetPlan EDU (Mission 1) full screen above the taskbar. Returns the program
## node (a NetPlanEdu). Loaded by path so the desktop still works without the mission files.
func open_netplan_edu() -> Control:
	if station == null or not station.has_app("netplan_edu"):
		return null
	if _netplan != null and is_instance_valid(_netplan):
		_netplan.visible = true # It may be minimised.
		_netplan.move_to_front()
		return _netplan
	var scene := load(NETPLAN_EDU_SCENE) as PackedScene
	if scene == null:
		push_error("DesktopOS: cannot load " + NETPLAN_EDU_SCENE)
		return null
	var app := scene.instantiate() as Control
	app.name = "NetPlanEdu"
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.offset_bottom = -48.0 # Keep the taskbar visible.
	_window_layer.add_child(app)
	_windows["netplan_edu"] = app
	_netplan = app
	app.connect("close_requested", func(): _close_window("netplan_edu"))
	app.connect("minimize_requested", func(): app.visible = false)
	app.connect("computer_exit_requested", func(): shutdown_requested.emit())
	app_opened.emit("netplan_edu", app)
	return app


func _open_recycle_bin() -> void:
	_open_window("bin", "Recycle Bin", Vector2(360, 140), func(body):
		body.add_child(_label("ถังขยะว่างเปล่า", 16, COLOR_TEXT)))


# ---------------------------------------------------------------- command prompt

func _open_cmd() -> void:
	var existed := _windows.has("cmd")
	var window := _open_window("cmd", "Command Prompt", Vector2(640, 380), func(body):
		var column := VBoxContainer.new()
		body.add_child(column)
		var console_style := _flat(Color(0.05, 0.05, 0.07), 2)
		_cmd_output = RichTextLabel.new()
		_cmd_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_cmd_output.custom_minimum_size = Vector2(600, 270)
		_cmd_output.scroll_following = true
		_cmd_output.selection_enabled = true
		_cmd_output.add_theme_stylebox_override("normal", console_style)
		_cmd_output.add_theme_color_override("default_color", Color(0.85, 0.9, 0.85))
		_cmd_output.add_theme_font_size_override("normal_font_size", 15)
		var mono := SystemFont.new()
		mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
		_cmd_output.add_theme_font_override("normal_font", mono)
		column.add_child(_cmd_output)
		_cmd_input = LineEdit.new()
		_cmd_input.placeholder_text = "พิมพ์คำสั่ง เช่น ipconfig, ping 192.168.1.1, help"
		_cmd_input.text_submitted.connect(_on_cmd_submitted)
		column.add_child(_cmd_input))
	if not existed:
		_cmd_print("%s [Version 1.0]\nพิมพ์ help เพื่อดูคำสั่งทั้งหมด\n" % OS_NAME)
	window.move_to_front()
	_cmd_input.grab_focus()


func _cmd_print(text: String) -> void:
	if _cmd_output:
		_cmd_output.add_text(text + "\n")


func _on_cmd_submitted(line: String) -> void:
	_cmd_input.clear()
	_cmd_print("C:\\Users\\%s> %s" % [station.hostname, line])
	run_command(line)


## Runs one Command Prompt line. Public so tests and missions can drive it.
func run_command(line: String) -> void:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var command := parts[0].to_lower()
	var args := parts.slice(1)
	match command:
		"help":
			_cmd_print("คำสั่งที่ใช้ได้:\n  ipconfig [/all]   ดูการตั้งค่า IP\n  ping <IP|ชื่อเครื่อง>  ทดสอบการเชื่อมต่อ\n  hostname          ดูชื่อเครื่อง\n  cls               ล้างหน้าจอ\n  exit              ปิดหน้าต่าง\n")
		"ipconfig":
			_cmd_ipconfig(args.size() > 0 and args[0].to_lower() == "/all")
		"hostname":
			_cmd_print(station.hostname + "\n")
		"cls":
			_cmd_output.clear()
		"exit":
			_close_window("cmd")
		"ping":
			if args.is_empty():
				_cmd_print("วิธีใช้: ping <IP address หรือ ชื่อเครื่อง>\n")
			else:
				_cmd_ping(args[0])
		_:
			_cmd_print("'%s' is not recognized as an internal or external command.\n" % parts[0])


func _cmd_ipconfig(all: bool) -> void:
	var lines := "\n%s IP Configuration\n" % OS_NAME
	if all:
		lines += "\n   Host Name . . . . . . . . . : %s\n" % station.hostname
	lines += "\nEthernet adapter Ethernet:\n\n"
	if not station.network_connected:
		lines += "   Media State . . . . . . . . : Media disconnected\n"
		if all:
			lines += "   Physical Address. . . . . . : %s\n" % station.mac_address
	else:
		if all:
			lines += "   Physical Address. . . . . . : %s\n" % station.mac_address
			lines += "   DHCP Enabled. . . . . . . . : No\n"
		lines += "   IPv4 Address. . . . . . . . : %s\n" % station.ip_address
		lines += "   Subnet Mask . . . . . . . . : %s\n" % station.subnet_mask
		lines += "   Default Gateway . . . . . . : %s\n" % station.gateway
		if all:
			lines += "   DNS Servers . . . . . . . . : %s\n" % station.dns_server
	_cmd_print(lines)


func _cmd_ping(target: String) -> void:
	var session := _session
	var address := target
	var reachable := false
	var host: ComputerStation = manager.find_host(target) if manager else null
	if target == "127.0.0.1" or target.to_lower() == "localhost":
		address = "127.0.0.1"
		reachable = true
	elif host != null:
		address = host.ip_address
		reachable = station.network_connected and host.network_connected
	elif target == station.gateway or target == "8.8.8.8" or target == station.dns_server:
		reachable = station.network_connected
	elif target.to_lower() in ["google.com", "www.google.com"]:
		address = "142.250.199.14"
		reachable = station.network_connected
	elif not target.is_valid_ip_address():
		_cmd_print("Ping request could not find host %s. Please check the name and try again.\n" % target)
		return

	if not station.network_connected and address != "127.0.0.1":
		_cmd_print("\nPinging %s with 32 bytes of data:\nPING: transmit failed. General failure.\n" % address)
		return

	_cmd_print("\nPinging %s with 32 bytes of data:" % address)
	var received := 0
	for i in 4:
		await get_tree().create_timer(0.45).timeout
		if session != _session or _cmd_output == null:
			return
		if reachable:
			received += 1
			var ms := 1 if address.begins_with("192.168.") or address == "127.0.0.1" else randi_range(18, 32)
			_cmd_print("Reply from %s: bytes=32 time=%dms TTL=%d" % [address, ms, 128 if address.begins_with("192.168.") or address == "127.0.0.1" else 117])
		else:
			_cmd_print("Request timed out.")
	_cmd_print("\nPing statistics for %s:\n    Packets: Sent = 4, Received = %d, Lost = %d (%d%% loss)\n" % [address, received, 4 - received, (4 - received) * 25])
