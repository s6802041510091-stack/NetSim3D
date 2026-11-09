class_name EquipmentPopup
extends Control

## Centre pop-up for one install point (Mission 1):
##   1. four device cards (picture + name; the right one + three distractors, shuffled)
##   2. click a card = choose that device -> "เลือก ... เพราะ…" with 4 reasons (shuffled)
##   3. pick a reason -> "ยืนยันจุดนี้"
## It never says whether anything is right — that only happens on "ตรวจสอบแบบ".
## Built from Control nodes (not a Window), so it works the same in the Web export.

signal equipment_selected(point_id: int, option: String)
signal answer_confirmed(point_id: int, option: String, reason_index: int)
signal cancelled

const CARD_SIZE := Vector2(350, 90)
const ICON_SIZE := Vector2(130, 78)

var point_id: int = 0
## The device chosen in this pop-up ("" = none yet).
var selected_option: String = ""
## Index of the chosen reason in the data (-1 = none yet).
var selected_reason: int = -1
var locked: bool = false

var _data: Mission01Data
var _device_group := ButtonGroup.new()
var _reason_group := ButtonGroup.new()
## Shuffled orders kept for the whole session so options do not jump around.
var _device_order := {}
var _reason_order := {}
var _rng := RandomNumberGenerator.new()

var _devices: GridContainer
var _reason_title: Label
var _reasons: VBoxContainer

@onready var _title: Label = %PopupTitle
@onready var _location: Label = %LocationLabel
@onready var _question: Label = %QuestionLabel
@onready var _options: VBoxContainer = %Options
@onready var _note: Label = %NoteLabel
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton
@onready var _card: PanelContainer = %Card


func _ready() -> void:
	visible = false
	_rng.randomize()
	_card.custom_minimum_size.x = 760
	_card.add_theme_stylebox_override("panel", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 10, 22, 12))
	# Must fit 1280x672 with the reasons open (validate_mission_01 [02]).
	(_card.get_child(0) as VBoxContainer).add_theme_constant_override("separation", 6)
	_title.add_theme_font_size_override("font_size", 21)
	_location.add_theme_font_size_override("font_size", 15)
	_question.add_theme_font_size_override("font_size", 17)
	_note.add_theme_font_size_override("font_size", 13)
	%Dim.gui_input.connect(_on_dim_input)
	_title.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)
	_confirm.text = "ยืนยันจุดนี้"
	_confirm.pressed.connect(confirm)
	_cancel.pressed.connect(cancel)
	_style_primary(_confirm)
	_devices = GridContainer.new()
	_devices.name = "Devices"
	_devices.columns = 2
	_devices.add_theme_constant_override("h_separation", 10)
	_devices.add_theme_constant_override("v_separation", 8)
	_options.add_child(_devices)
	_reason_title = Label.new()
	_reason_title.name = "ReasonTitle"
	_reason_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_title.add_theme_font_size_override("font_size", 16)
	_reason_title.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)
	_options.add_child(_reason_title)
	_reasons = VBoxContainer.new()
	_reasons.name = "Reasons"
	_reasons.add_theme_constant_override("separation", 5)
	_options.add_child(_reasons)


## Shows the pop-up for `question` with the player's saved answer (if any).
## `is_locked` = the point was already checked as correct: show it read-only.
func open_for(question: EquipmentQuestion, state: Mission01State, data: Mission01Data, is_locked: bool = false) -> void:
	_data = data
	point_id = question.point_id
	locked = is_locked
	_title.text = "จุดที่ %d · %s" % [question.point_id, question.title]
	_location.text = "ตำแหน่งติดตั้ง: " + question.location
	_question.text = question.question + " — คลิกอุปกรณ์ที่ต้องการเลือก แล้วตอบว่าเลือกเพราะอะไร"
	if not _device_order.has(point_id):
		var order := Array(question.options)
		_shuffle(order)
		_device_order[point_id] = order
	_build_devices()
	selected_option = ""
	selected_reason = -1
	_reason_title.visible = false
	_reasons.visible = false
	var saved := state.get_answer(point_id)
	if saved != "":
		choose(saved, true)
		pick_reason(state.get_reason(point_id))
	if locked:
		_note.text = "จุดนี้ผ่านการตรวจสอบแล้ว เปลี่ยนอุปกรณ์ไม่ได้"
	else:
		_note.text = "เปลี่ยนอุปกรณ์หรือเหตุผลภายหลังได้ แต่ระบบนับเหตุผลครั้งแรกที่ยืนยันของแต่ละอุปกรณ์"
	_confirm.visible = not locked
	_cancel.text = "ปิด" if locked else "ยกเลิก"
	_refresh_confirm()
	visible = true
	move_to_front()


## Clicks a device card = chooses that device (also used by tests).
func choose(option: String, force: bool = false) -> void:
	if (locked and not force) or not option in (_device_order.get(point_id, []) as Array):
		return
	selected_option = option
	selected_reason = -1
	for b in _devices.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.get_meta("option", "") == option)
	_reason_title.text = "เลือก %s เพราะ…" % option
	_reason_title.visible = true
	for child in _reasons.get_children():
		_reasons.remove_child(child)
		child.queue_free()
	_reason_group = ButtonGroup.new()
	var key := "%d|%s" % [point_id, option]
	var options := _data.reason_options(point_id, option)
	if not _reason_order.has(key):
		var order := range(options.size())
		_shuffle(order)
		_reason_order[key] = order
	for index: int in _reason_order[key]:
		_reasons.add_child(_make_reason(index, String(options[index].get("text", ""))))
	_reasons.visible = true
	_refresh_confirm()
	if not force:
		equipment_selected.emit(point_id, option)


## Picks reason `index` (index in the data, not on screen). Tests use this.
func pick_reason(index: int) -> void:
	for b in _reasons.get_children():
		if b is Button and int(b.get_meta("index", -1)) == index:
			b.button_pressed = true


func confirm() -> void:
	if locked or selected_option == "" or selected_reason < 0 or not visible:
		return
	var id := point_id
	var option := selected_option
	var reason := selected_reason
	close()
	answer_confirmed.emit(id, option, reason)


func cancel() -> void:
	if not visible:
		return
	close()
	cancelled.emit()


func close() -> void:
	visible = false


# ---------------------------------------------------------------- building

func _build_devices() -> void:
	for child in _devices.get_children():
		_devices.remove_child(child)
		child.queue_free()
	_device_group = ButtonGroup.new()
	for option: String in _device_order.get(point_id, []):
		_devices.add_child(_make_device(option))


## A card with the device picture on the left and its full name on the right.
func _make_device(option: String) -> Button:
	var b := Button.new()
	b.name = "Option_" + option.replace(" ", "_")
	b.set_meta("option", option)
	b.toggle_mode = true
	b.button_group = _device_group
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_SIZE
	_style_toggle(b, 8)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	b.add_child(row)
	var icon := TextureRect.new()
	icon.name = "Picture"
	icon.texture = Mission01Data.device_icon(option)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = option
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", NetPlanTheme.INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	b.pressed.connect(func(): choose(option))
	return b


func _make_reason(index: int, text: String) -> Button:
	var b := Button.new()
	b.name = "Reason_%d" % index
	b.set_meta("index", index)
	b.toggle_mode = true
	b.button_group = _reason_group
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = locked
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = text
	b.custom_minimum_size = Vector2(710, 0)
	b.add_theme_font_size_override("font_size", 15)
	_style_toggle(b, 4, 40)
	b.draw.connect(func():
		var c := Vector2(20, b.size.y * 0.5)
		b.draw_arc(c, 9, 0, TAU, 32, NetPlanTheme.ACCENT if b.button_pressed else NetPlanTheme.INK_SOFT, 2.0, true)
		if b.button_pressed:
			b.draw_circle(c, 5.0, NetPlanTheme.ACCENT))
	b.toggled.connect(func(on: bool):
		b.queue_redraw()
		if on:
			selected_reason = index
			_refresh_confirm())
	return b


func _style_toggle(b: Button, pad_y: int, pad_x: int = 10) -> void:
	b.add_theme_stylebox_override("normal", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 8, pad_x, pad_y))
	b.add_theme_stylebox_override("hover", NetPlanTheme.box(Color(0.94, 0.96, 1.0), NetPlanTheme.ACCENT.lightened(0.35), 8, pad_x, pad_y))
	var on := NetPlanTheme.box(Color(0.89, 0.94, 1.0), NetPlanTheme.ACCENT, 8, pad_x, pad_y)
	on.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("disabled", NetPlanTheme.box(Color(0.96, 0.96, 0.97), NetPlanTheme.BORDER, 8, pad_x, pad_y))


func _style_primary(b: Button) -> void:
	var primary := NetPlanTheme.box(NetPlanTheme.ACCENT, NetPlanTheme.ACCENT.darkened(0.2), 6, 16, 8)
	b.add_theme_stylebox_override("normal", primary)
	var hover := primary.duplicate() as StyleBoxFlat
	hover.bg_color = NetPlanTheme.ACCENT.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)


func _refresh_confirm() -> void:
	_confirm.disabled = locked or selected_option == "" or selected_reason < 0


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


func _on_dim_input(event: InputEvent) -> void:
	# Clicks outside the card do nothing (the plan behind stays locked).
	if event is InputEventMouseButton:
		accept_event()
