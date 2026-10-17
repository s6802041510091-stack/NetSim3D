extends Control
class_name SimDesktop
## Simulated Windows desktop: wallpaper, app icons, taskbar, windows.
## Put it inside a SubViewport (shown on the 3D monitor) or full-screen on a CanvasLayer.
##
##   desktop.user_name = "Teacher"
##   desktop.apps = SimDesktop.TEACHER_APPS     # which programs are installed
##   desktop.open_app("cmd")
## Opening a program is logged: NetSim.log_action("app_opened", {"app": id, "machine": machine_name})

signal app_opened(app_id: String, window: AppWindow)
signal app_closed(app_id: String)

## id -> [title, glyph, colour, script path, window size]
const APP_DEFS := {
	"cmd": ["Command Prompt", ">_", Color("1e1e1e"), "res://ui/apps/command_prompt.gd", Vector2(780, 460)],
	"ipscanner": ["Advanced IP Scanner", "IP", Color("2b7bd6"), "res://ui/apps/ip_scanner.gd", Vector2(980, 600)],
	"veyon_configurator": ["Veyon Configurator", "VC", Color("3e8e41"), "res://ui/apps/veyon_configurator.gd", Vector2(1000, 620)],
	"veyon_master": ["Veyon Master", "VM", Color("2e7d32"), "res://ui/apps/veyon_master.gd", Vector2(1120, 680)],
	"security": ["Windows Security", "◈", Color("0063b1"), "res://ui/apps/windows_security.gd", Vector2(900, 600)],
	"notepad": ["Notepad", "N", Color("3a7bd5"), "res://ui/apps/notepad.gd", Vector2(640, 420)],
	"paint": ["Paint", "P", Color("d0661b"), "res://ui/apps/placeholder_app.gd", Vector2(640, 420)],
	"browser": ["Web Browser", "W", Color("1f8f8f"), "res://ui/apps/placeholder_app.gd", Vector2(760, 480)],
	"calculator": ["Calculator", "=", Color("555c66"), "res://ui/apps/placeholder_app.gd", Vector2(340, 460)],
}
const TEACHER_APPS: Array[String] = ["cmd", "ipscanner", "veyon_configurator", "veyon_master", "security", "notepad", "paint", "browser"]
const STUDENT_APPS: Array[String] = ["notepad", "calculator", "paint", "browser"]

@export var machine_name := "TEACHER-PC"
@export var user_name := "Teacher"
@export var apps: Array[String] = TEACHER_APPS
@export var single_click_open := false     ## easier for gameplay; default behaves like Windows
@export var wallpaper_top := Color("1d4f91")
@export var wallpaper_bottom := Color("6aa8e8")

var windows := {}     # app id -> AppWindow
var _window_layer: Control
var _taskbar_items: HBoxContainer
var _clock: Label
var _icon_area: VBoxContainer


func _ready() -> void:
	theme = UIKit.theme()
	clip_contents = true
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var wall := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, wallpaper_top)
	g.set_color(1, wallpaper_bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.4, 1)
	wall.texture = gt
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wall)

	_icon_area = UIKit.vbox(6)
	_icon_area.position = Vector2(14, 14)
	add_child(_icon_area)
	for id in apps:
		_icon_area.add_child(_desktop_icon(id))

	_window_layer = Control.new()
	_window_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window_layer.offset_bottom = -48
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window_layer)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIKit.box(Color(0.93, 0.94, 0.96, 0.96), Color("cfcfcf"), 0, 0))
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -48
	add_child(bar)
	var h := UIKit.hbox(6)
	bar.add_child(UIKit.margin(h, 6))
	var start := UIKit.icon("⊞", UIKit.ACCENT, 34)
	h.add_child(start)
	_taskbar_items = UIKit.hbox(4)
	UIKit.expand(_taskbar_items, false)
	h.add_child(_taskbar_items)
	var who := UIKit.label("%s  |  %s" % [user_name, machine_name], 12, UIKit.TEXT_DIM)
	h.add_child(who)
	_clock = UIKit.label("", 12)
	h.add_child(_clock)
	_update_clock()


func open_app(id: String) -> AppWindow:
	if windows.has(id) and is_instance_valid(windows[id]):
		windows[id].restore()
		return windows[id]
	var def: Array = APP_DEFS[id]
	var w := AppWindow.new(def[0], def[1], def[2], def[4])
	var app: Control = load(def[3]).new()
	app.set_meta("app_id", id)
	app.set_meta("desktop", self)
	if "app_title" in app:
		app.app_title = def[0]
	w.set_content(app)
	_window_layer.add_child(w)
	var area := _window_layer.size if _window_layer.size.x > 0 else size
	w.size = Vector2(minf(w.size.x, area.x - 20), minf(w.size.y, area.y - 20))
	w.position = ((area - w.size) / 2 + Vector2(24, 18) * windows.size()).max(Vector2(4, 4))
	windows[id] = w
	w.closed.connect(func():
		windows.erase(id)
		_refresh_taskbar()
		app_closed.emit(id)
		NetSim.log_action("app_closed", {"app": id, "machine": machine_name}))
	_refresh_taskbar()
	NetSim.log_action("app_opened", {"app": id, "machine": machine_name})
	app_opened.emit(id, w)
	return w


func close_all() -> void:
	for w in windows.values():
		if is_instance_valid(w):
			w.queue_free()
	windows.clear()
	_refresh_taskbar()


func get_app(id: String) -> Control:
	if not windows.has(id):
		return null
	return windows[id].content.get_child(0)


func _desktop_icon(id: String) -> Control:
	var def: Array = APP_DEFS[id]
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(84, 78)
	b.tooltip_text = def[0]
	b.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.3), 4))
	b.add_theme_stylebox_override("pressed", UIKit.box(Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.4), 4))
	var v := UIKit.vbox(3)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIKit.icon(def[1], def[2], 36)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UIKit.label(def[0], 11, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 80
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.add_child(v)
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if e.double_click or single_click_open:
				open_app(id))
	return b


func _refresh_taskbar() -> void:
	if _taskbar_items == null:
		return
	for c in _taskbar_items.get_children():
		c.queue_free()
	for id in windows:
		var def: Array = APP_DEFS[id]
		var b := UIKit.button(def[0])
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func():
			var w: AppWindow = windows.get(id)
			if is_instance_valid(w):
				if w.visible and w.get_index() == w.get_parent().get_child_count() - 1:
					w.minimize()
				else:
					w.restore())
		_taskbar_items.add_child(b)


func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	_clock.text = "%02d:%02d" % [t.hour, t.minute]


func _process(_d: float) -> void:
	if Engine.get_process_frames() % 120 == 0 and _clock:
		_update_clock()
