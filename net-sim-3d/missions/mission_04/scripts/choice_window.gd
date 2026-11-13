class_name Mission04Choice
extends CanvasLayer

## A centred window with a question, optional evidence text and one button
## per answer (Mission 4: the tool to use, the swap-test conclusion, the
## analysis with 5 options, the spare part). The controller decides what an
## answer means: it may show a hint and keep the window open (choose again)
## or close it.

signal picked(id: String)
signal closed

var ids: PackedStringArray = PackedStringArray()
var buttons := {}
var _title: Label
var _body: RichTextLabel
var _list: GridContainer
var _card: PanelContainer
## Picture cards (tools, parts): 2 columns, picture left, name right.
const CARD_SIZE := Vector2(340, 104)
const PICTURE_SIZE := Vector2(96, 96)
var _feedback: Label
var _close: Button
var _cancellable := true


func _ready() -> void:
	layer = 24
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	_card = card
	card.name = "ChoiceCard"
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1, 0.98), Color(0.8, 0.83, 0.88), 14, 26, 20))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	_title = GameUI.label("", 22, GameUI.INK, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 588
	col.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size.x = 588
	_body.add_theme_font_size_override("normal_font_size", 16)
	_body.add_theme_font_override("bold_font", GameUI.FONT_BOLD)
	_body.add_theme_font_size_override("bold_font_size", 16)
	_body.add_theme_color_override("default_color", GameUI.INK)
	col.add_child(_body)
	_list = GridContainer.new()
	_list.columns = 1
	_list.add_theme_constant_override("h_separation", 10)
	_list.add_theme_constant_override("v_separation", 8)
	col.add_child(_list)
	_feedback = GameUI.label("", 15, GameUI.BAD)
	_feedback.name = "Feedback"
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.x = 588
	col.add_child(_feedback)
	_close = GameUI.button("ปิด (Esc)", false, 140)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(close)
	col.add_child(_close)


## options: [[id, text], ...] or [[id, text, picture_path], ...] (picture
## cards in 2 columns). `body` may use [b]...[/b] / [color=...].
func open(title: String, body: String, options: Array, cancellable := true) -> void:
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	_feedback.text = ""
	_cancellable = cancellable
	_close.visible = cancellable
	ids = PackedStringArray()
	buttons.clear()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var pictures := not options.is_empty()
	for option: Array in options:
		pictures = pictures and option.size() > 2
	_list.columns = 2 if pictures else 1
	var width := CARD_SIZE.x * 2 + 10 if pictures else 588.0
	_card.custom_minimum_size.x = width + 52
	for label: Control in [_title, _body, _feedback]:
		label.custom_minimum_size.x = width
	for option: Array in options:
		var id := String(option[0])
		var b := _picture_button(String(option[1]), String(option[2])) if pictures else GameUI.button(String(option[1]), false, 588)
		b.name = "Choice_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(pick.bind(id))
		_list.add_child(b)
		ids.append(id)
		buttons[id] = b
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sound.play("popup_open")


## A card with the item's picture on the left and its name on the right.
func _picture_button(text: String, path: String) -> Button:
	var b := GameUI.button("", false, CARD_SIZE.x)
	b.custom_minimum_size = CARD_SIZE
	b.tooltip_text = text
	b.add_theme_stylebox_override("normal", GameUI.box(Color.WHITE, Color(0.8, 0.83, 0.88), 10, 8, 6))
	b.add_theme_stylebox_override("hover", GameUI.box(Color(0.93, 0.96, 1.0), GameUI.ACCENT.lightened(0.3), 10, 8, 6))
	b.add_theme_stylebox_override("disabled", GameUI.box(Color(0.94, 0.94, 0.95), Color(0.85, 0.86, 0.88), 10, 8, 6))
	var row := HBoxContainer.new()
	row.name = "Content"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	b.add_child(row)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	picture.custom_minimum_size = PICTURE_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var label := GameUI.label(text, 17, GameUI.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return b


func pick(id: String) -> void:
	if visible and id in ids and not (buttons[id] as Button).disabled:
		Sound.play("click")
		picked.emit(id)


## A wrong answer: show why and grey that option out (choose again).
func reject(id: String, message: String) -> void:
	Sound.play("wrong")
	_feedback.text = message
	if buttons.has(id):
		var b := buttons[id] as Button
		b.disabled = true
		var content := b.get_node_or_null("Content") as Control
		if content:
			content.modulate = Color(1, 1, 1, 0.4)


func close() -> void:
	if not visible:
		return
	visible = false
	Sound.play("popup_close")
	closed.emit()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if visible and _cancellable and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
