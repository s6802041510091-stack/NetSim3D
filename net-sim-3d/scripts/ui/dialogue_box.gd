class_name DialogueBox
extends CanvasLayer

## Subtitles for talking with an NPC: one line at a time at the bottom of the
## screen. Each line is "ผู้พูด|ข้อความ". Click, F, Space or Enter goes to the
## next line; `finished` fires after the last one.

signal finished

## Ignore the same key press that opened the dialogue.
const INPUT_GRACE_MS := 250
## Colour of "**highlighted**" words (same gold as the objective arrow).
const HIGHLIGHT := Color(1.0, 0.78, 0.2)
## Typewriter: characters per second; a soft tick every few characters.
const CHARS_PER_SEC := 45.0
const TICK_EVERY := 2

var lines: PackedStringArray = PackedStringArray()
var index := -1
var _opened_at := 0
var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _hint: Label
var _header: Label
var _reveal := -1.0 # characters shown so far while typing, -1 = whole line shown


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
	_panel.offset_left = -500
	_panel.offset_right = 500
	_panel.offset_top = -200
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
	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("bold_font_size", 19)
	_text.add_theme_font_override("bold_font", GameUI.FONT_BOLD)
	_text.add_theme_color_override("default_color", Color.WHITE)
	col.add_child(_text)
	_hint = GameUI.label("", 13, Color(0.7, 0.74, 0.8))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_hint)


## `header` is an optional small line above the speaker (hidden when empty).
func show_lines(dialogue_lines: PackedStringArray, header: String = "") -> void:
	lines = dialogue_lines
	_header.text = header
	_header.visible = header != ""
	index = -1
	visible = true
	_opened_at = Time.get_ticks_msec()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	advance(true)


## Next line. While a line is still typing, the first press shows all of it.
func advance(force: bool = false) -> void:
	if not visible:
		return
	if not force and Time.get_ticks_msec() - _opened_at < INPUT_GRACE_MS:
		return
	if is_typing():
		_finish_typing()
		return
	index += 1
	if index >= lines.size():
		visible = false
		finished.emit()
		return
	if index > 0:
		Sound.play("click")
	var parts := lines[index].split("|", true, 1)
	_speaker.text = parts[0] if parts.size() > 1 else ""
	_text.text = highlight(keep_together(parts[1] if parts.size() > 1 else parts[0]))
	_hint.text = "คลิก หรือกด F / Space เพื่อ" + ("จบบทสนทนา" if index == lines.size() - 1 else "ไปต่อ")
	_reveal = 0.0
	_text.visible_characters = 0


## True while the current line is still appearing letter by letter.
func is_typing() -> bool:
	return _reveal >= 0.0


func _finish_typing() -> void:
	_reveal = -1.0
	_text.visible_characters = -1


func _process(delta: float) -> void:
	if not visible or _reveal < 0.0:
		return
	var before := int(_reveal)
	_reveal += delta * CHARS_PER_SEC
	var shown := int(_reveal)
	if shown >= _text.get_total_character_count():
		_finish_typing()
		return
	_text.visible_characters = shown
	if shown / TICK_EVERY != before / TICK_EVERY:
		Sound.play("type_tick")


## Thai line breaking may leave "1" at the end of a line and "เครื่อง" alone on
## the next. A no-break space keeps a number with the word after it.
static func keep_together(text: String) -> String:
	var re := RegEx.create_from_string("(\\d) ")
	return re.sub(text, "$1 ", true)


## "**สำคัญ**" in a line becomes bold gold text. Square brackets in the line are
## escaped first, so only this markup is interpreted as BBCode.
static func highlight(text: String) -> String:
	var safe := text.replace("[", "[lb]")
	var re := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	return re.sub(safe, "[b][color=#%s]$1[/color][/b]" % HIGHLIGHT.to_html(false), true)


## Plain text of the line on screen (tests, accessibility).
func current_text() -> String:
	return _text.get_parsed_text()


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
