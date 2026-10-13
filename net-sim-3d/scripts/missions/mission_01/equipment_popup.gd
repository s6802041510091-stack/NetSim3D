class_name EquipmentPopup
extends Control

## Centre pop-up for one install point: point number, install location,
## question, two options (choose one), "ยืนยันการเลือก" and "ยกเลิก".
## It never says whether a choice is right — that only happens on "ตรวจสอบแบบ".
## Built from Control nodes (not a Window), so it works the same in the Web export.

signal equipment_selected(point_id: int, option: String)
signal answer_confirmed(point_id: int, option: String)
signal cancelled

var point_id: int = 0
var selected_option: String = ""
var locked: bool = false

var _group := ButtonGroup.new()

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
	_card.add_theme_stylebox_override("panel", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 10, 24, 20))
	%Dim.gui_input.connect(_on_dim_input)
	_title.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)
	_confirm.pressed.connect(confirm)
	_cancel.pressed.connect(cancel)
	var primary := NetPlanTheme.box(NetPlanTheme.ACCENT, NetPlanTheme.ACCENT.darkened(0.2), 6, 16, 8)
	_confirm.add_theme_stylebox_override("normal", primary)
	var primary_hover := primary.duplicate() as StyleBoxFlat
	primary_hover.bg_color = NetPlanTheme.ACCENT.lightened(0.12)
	_confirm.add_theme_stylebox_override("hover", primary_hover)
	_confirm.add_theme_stylebox_override("pressed", primary_hover)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_confirm.add_theme_color_override(c, Color.WHITE)


## Shows the pop-up for `question`. `current` is the saved answer ("" = none).
## `is_locked` = the point was already checked as correct: show it read-only.
func open_for(question: EquipmentQuestion, current: String, is_locked: bool = false) -> void:
	point_id = question.point_id
	locked = is_locked
	selected_option = current
	_title.text = "จุดที่ %d · %s" % [question.point_id, question.title]
	_location.text = "ตำแหน่งติดตั้ง: " + question.location
	_question.text = question.question
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	_group = ButtonGroup.new()
	for option in question.options:
		_options.add_child(_make_option(option, option == current))
	if locked:
		_note.text = "จุดนี้ผ่านการตรวจสอบแล้ว เปลี่ยนอุปกรณ์ไม่ได้"
	else:
		_note.text = "เลือกได้ 1 ตัวเลือก แล้วกด \"ยืนยันการเลือก\" (เปลี่ยนคำตอบภายหลังได้)"
	_confirm.visible = not locked
	_cancel.text = "ปิด" if locked else "ยกเลิก"
	_refresh_confirm()
	visible = true
	move_to_front()


## Picks an option as if the player clicked it (also used by tests).
func choose(option: String) -> void:
	if locked:
		return
	for b in _options.get_children():
		if b is Button and b.get_meta("option", "") == option:
			b.button_pressed = true


func confirm() -> void:
	if locked or selected_option == "" or not visible:
		return
	var id := point_id
	var option := selected_option
	close()
	answer_confirmed.emit(id, option)


func cancel() -> void:
	if not visible:
		return
	close()
	cancelled.emit()


func close() -> void:
	visible = false


func _make_option(option: String, is_current: bool) -> Button:
	var b := Button.new()
	b.name = "Option_" + option.replace(" ", "_")
	b.set_meta("option", option)
	b.text = option
	b.toggle_mode = true
	b.button_group = _group
	b.button_pressed = is_current
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_stylebox_override("normal", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 8, 52, 8))
	b.add_theme_stylebox_override("hover", NetPlanTheme.box(Color(0.94, 0.96, 1.0), NetPlanTheme.ACCENT.lightened(0.35), 8, 52, 8))
	var on := NetPlanTheme.box(Color(0.89, 0.94, 1.0), NetPlanTheme.ACCENT, 8, 52, 8)
	on.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("disabled", NetPlanTheme.box(Color(0.96, 0.96, 0.97), NetPlanTheme.BORDER, 8, 52, 8))
	# Radio dot drawn on the left of the text.
	b.draw.connect(func():
		var c := Vector2(26, b.size.y * 0.5)
		b.draw_arc(c, 10, 0, TAU, 32, NetPlanTheme.ACCENT if b.button_pressed else NetPlanTheme.INK_SOFT, 2.0, true)
		if b.button_pressed:
			b.draw_circle(c, 5.5, NetPlanTheme.ACCENT))
	b.toggled.connect(func(on_now: bool):
		b.queue_redraw()
		if on_now:
			selected_option = option
			_refresh_confirm()
			equipment_selected.emit(point_id, option))
	return b


func _refresh_confirm() -> void:
	_confirm.disabled = locked or selected_option == ""


func _on_dim_input(event: InputEvent) -> void:
	# Clicks outside the card do nothing (the plan behind stays locked).
	if event is InputEventMouseButton:
		accept_event()
