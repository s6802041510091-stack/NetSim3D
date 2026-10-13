class_name CallDialog
extends CanvasLayer

## Phone-call subtitles (Mission 6): shows the call one line at a time.
## Click, E, Space or Enter goes to the next line; `finished` fires after the last.

signal finished

const INPUT_GRACE_MS := 250

var lines: PackedStringArray = PackedStringArray()
var index := -1
var _opened_at := 0
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _hint: Label
var _header: Label


func _ready() -> void:
	layer = 20
	visible = false
	_panel = PanelContainer.new()
	_panel.name = "CallPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -440
	_panel.offset_right = 440
	_panel.offset_top = -230
	_panel.offset_bottom = -40
	_panel.theme = RemoteTheme.build()
	_panel.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.08, 0.09, 0.12, 0.94), Color(0.35, 0.55, 0.95, 0.8), 10, 24, 16))
	_panel.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: advance())
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_header = _label("", 14, Color(0.6, 0.75, 1.0), false)
	col.add_child(_header)
	_speaker = _label("", 20, Color(1.0, 0.85, 0.45), true)
	col.add_child(_speaker)
	_text = _label("", 19, Color.WHITE, false)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)
	_hint = _label("คลิก หรือกด E / Space เพื่อไปต่อ", 13, Color(0.7, 0.74, 0.8), false)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)


## Starts the call. Each line is "ผู้พูด|ข้อความ".
func show_call(call_lines: PackedStringArray, header: String = "") -> void:
	lines = call_lines
	_header.text = header
	index = -1
	visible = true
	_opened_at = Time.get_ticks_msec()
	advance(true)


func advance(force: bool = false) -> void:
	if not visible:
		return
	if not force and Time.get_ticks_msec() - _opened_at < INPUT_GRACE_MS:
		return # Ignore the same E press that answered the phone.
	index += 1
	if index >= lines.size():
		visible = false
		finished.emit()
		return
	var parts := lines[index].split("|", true, 1)
	_speaker.text = parts[0] if parts.size() > 1 else ""
	_text.text = parts[1] if parts.size() > 1 else parts[0]
	_hint.text = "คลิก หรือกด E / Space เพื่อวางสาย" if index == lines.size() - 1 else "คลิก หรือกด E / Space เพื่อไปต่อ"


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var go := false
	if event.is_action_pressed("interact") and not event.is_echo():
		go = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		advance()


func _label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", RemoteTheme.FONT_BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
