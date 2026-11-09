class_name DialogueBox
extends CanvasLayer

## Subtitles for talking with an NPC: one line at a time at the bottom of the
## screen. Each line is "ผู้พูด|ข้อความ". Click, F, Space or Enter goes to the
## next line; `finished` fires after the last one.

signal finished

## Ignore the same key press that opened the dialogue.
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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -460
	_panel.offset_right = 460
	_panel.offset_top = -230
	_panel.offset_bottom = -40
	_panel.add_theme_stylebox_override("panel", GameUI.box(GameUI.PANEL_DARK, Color(0.35, 0.55, 0.95, 0.8), 10, 24, 16))
	_panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			advance())
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_header = GameUI.label("", 14, Color(0.6, 0.75, 1.0))
	col.add_child(_header)
	_speaker = GameUI.label("", 20, Color(1.0, 0.85, 0.45), true)
	col.add_child(_speaker)
	_text = GameUI.label("", 19, Color.WHITE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)
	_hint = GameUI.label("", 13, Color(0.7, 0.74, 0.8))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)


func show_lines(dialogue_lines: PackedStringArray, header: String = "") -> void:
	lines = dialogue_lines
	_header.text = header
	index = -1
	visible = true
	_opened_at = Time.get_ticks_msec()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	advance(true)


func advance(force: bool = false) -> void:
	if not visible:
		return
	if not force and Time.get_ticks_msec() - _opened_at < INPUT_GRACE_MS:
		return
	index += 1
	if index >= lines.size():
		visible = false
		finished.emit()
		return
	var parts := lines[index].split("|", true, 1)
	_speaker.text = parts[0] if parts.size() > 1 else ""
	_text.text = parts[1] if parts.size() > 1 else parts[0]
	_hint.text = "คลิก หรือกด F / Space เพื่อ" + ("จบบทสนทนา" if index == lines.size() - 1 else "ไปต่อ")


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var go := event.is_action_pressed("interact") and not event.is_echo()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		advance()
