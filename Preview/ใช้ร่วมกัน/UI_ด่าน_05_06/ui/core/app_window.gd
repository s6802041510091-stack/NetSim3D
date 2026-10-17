extends PanelContainer
class_name AppWindow
## Windows-style window frame: title bar (drag to move), maximize, close, and a content area.

signal closed
signal focused

var title := ""
var content: Control
var _title_label: Label
var _drag := false
var _drag_off := Vector2.ZERO
var _maximized := false
var _restore_rect := Rect2()


func _init(window_title := "Window", icon_glyph := "", icon_color := UIKit.ACCENT, win_size := Vector2(820, 520)) -> void:
	title = window_title
	theme = UIKit.theme()
	size = win_size
	custom_minimum_size = Vector2(320, 200)
	add_theme_stylebox_override("panel", _frame_style())
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UIKit.vbox(0)
	add_child(v)
	# title bar
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIKit.box(Color("eeeeee"), Color.TRANSPARENT, 0, 0))
	bar.custom_minimum_size.y = 34
	bar.gui_input.connect(_on_bar_input)
	v.add_child(bar)
	var h := UIKit.hbox(8)
	bar.add_child(UIKit.margin(h, 0))
	var sp := Control.new()
	sp.custom_minimum_size.x = 4
	h.add_child(sp)
	if icon_glyph != "":
		var ic := UIKit.icon(icon_glyph, icon_color, 20)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	_title_label = UIKit.label(window_title, 13)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_title_label)
	h.add_child(_caption_button("—", minimize))
	h.add_child(_caption_button("☐", toggle_maximize))
	var x := _caption_button("✕", close)
	x.add_theme_stylebox_override("hover", UIKit.box(Color("c42b1c"), Color.TRANSPARENT, 0))
	x.add_theme_color_override("font_hover_color", Color.WHITE)
	h.add_child(x)
	# content holder
	content = Control.new()
	content.clip_contents = true
	UIKit.expand(content)
	v.add_child(content)


func set_content(c: Control) -> void:
	for ch in content.get_children():
		ch.queue_free()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(c)


func set_title(t: String) -> void:
	title = t
	_title_label.text = t


func minimize() -> void:
	hide()


func restore() -> void:
	show()
	move_to_front()
	focused.emit()


func close() -> void:
	closed.emit()
	queue_free()


func toggle_maximize() -> void:
	var parent_rect := Rect2(Vector2.ZERO, get_parent_area_size())
	if _maximized:
		position = _restore_rect.position
		size = _restore_rect.size
	else:
		_restore_rect = Rect2(position, size)
		position = Vector2.ZERO
		size = parent_rect.size
	_maximized = not _maximized


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		move_to_front()
		focused.emit()


func _on_bar_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.double_click:
			toggle_maximize()
			return
		_drag = e.pressed
		_drag_off = get_global_mouse_position() - global_position
		if e.pressed:
			move_to_front()
			focused.emit()
	elif e is InputEventMouseMotion and _drag and not _maximized:
		var p := get_global_mouse_position() - _drag_off - get_parent_control_origin()
		var area := get_parent_area_size()
		p.x = clampf(p.x, -size.x + 80, area.x - 80)
		p.y = clampf(p.y, 0, area.y - 40)
		position = p


func get_parent_control_origin() -> Vector2:
	var pc := get_parent_control()
	return pc.global_position if pc else Vector2.ZERO


func _caption_button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 32)
	b.add_theme_stylebox_override("hover", UIKit.box(Color("dddddd"), Color.TRANSPARENT, 0))
	b.add_theme_stylebox_override("pressed", UIKit.box(Color("cccccc"), Color.TRANSPARENT, 0))
	b.add_theme_color_override("font_color", UIKit.TEXT)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	return b


func _frame_style() -> StyleBoxFlat:
	var s := UIKit.box(UIKit.BG, Color("b8b8b8"), 8, 1)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 4)
	return s
