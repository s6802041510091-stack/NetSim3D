class_name EquipmentPopup
extends Control

## Centre pop-up for one install point (Mission 1):
##   1. four devices (the right one + three distractors, shuffled)
##   2. click a device -> "เลือกอุปกรณ์นี้" or "ไม่เลือกอุปกรณ์นี้"
##   3. answer the reason question for that decision (3 options, shuffled) -> "บันทึกเหตุผล"
##   4. type the quantity for the chosen device -> "ยืนยันจุดนี้"
## Only devices the player clicks are asked about. It never says whether
## anything is right — that only happens on "ตรวจสอบแบบ".
## Built from Control nodes (not a Window), so it works the same in the Web export.

signal equipment_selected(point_id: int, option: String)
signal reason_answered(point_id: int, device: String, decision: String, option_index: int)
signal answer_confirmed(point_id: int, option: String, quantity: int)
signal cancelled

var point_id: int = 0
## The device marked "เลือก" for this point ("" = none yet).
var selected_option: String = ""
## The device whose decision/reason panel is open.
var active_device: String = ""
var active_decision: String = ""
var active_reason: int = -1
var locked: bool = false

var _state: Mission01State
var _data: Mission01Data
var _device_group := ButtonGroup.new()
var _reason_group := ButtonGroup.new()
## Shuffled orders kept for the whole session so options do not jump around.
var _device_order := {}
var _reason_order := {}
var _rng := RandomNumberGenerator.new()

var _devices: GridContainer
var _decision_box: VBoxContainer
var _decision_title: Label
var _choose_button: Button
var _reject_button: Button
var _reason_title: Label
var _reasons: VBoxContainer
var _save_reason: Button
var _quantity_row: HBoxContainer
var _quantity: SpinBox

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
	# Must fit 1280x672 with the reason list open (validate_mission_01 [02]).
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
	_build_parts()


func _build_parts() -> void:
	_devices = GridContainer.new()
	_devices.name = "Devices"
	_devices.columns = 2
	_devices.add_theme_constant_override("h_separation", 10)
	_devices.add_theme_constant_override("v_separation", 8)
	_options.add_child(_devices)

	_decision_box = VBoxContainer.new()
	_decision_box.name = "DecisionBox"
	_decision_box.add_theme_constant_override("separation", 8)
	_options.add_child(_decision_box)
	_decision_title = _small_label("", 16, NetPlanTheme.INK, true)
	_decision_box.add_child(_decision_title)
	var decide := HBoxContainer.new()
	decide.add_theme_constant_override("separation", 10)
	_decision_box.add_child(decide)
	_choose_button = _toggle("เลือกอุปกรณ์นี้", 38, 0)
	_choose_button.custom_minimum_size.x = 220
	_choose_button.name = "ChooseButton"
	_choose_button.pressed.connect(func(): decide(Mission01Data.DECISION_CHOOSE))
	decide.add_child(_choose_button)
	_reject_button = _toggle("ไม่เลือกอุปกรณ์นี้", 38, 0)
	_reject_button.custom_minimum_size.x = 220
	_reject_button.name = "RejectButton"
	_reject_button.pressed.connect(func(): decide(Mission01Data.DECISION_REJECT))
	decide.add_child(_reject_button)
	_reason_title = _small_label("", 16, NetPlanTheme.INK, true)
	_reason_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_decision_box.add_child(_reason_title)
	_reasons = VBoxContainer.new()
	_reasons.name = "Reasons"
	_reasons.add_theme_constant_override("separation", 6)
	_decision_box.add_child(_reasons)
	_save_reason = Button.new()
	_save_reason.name = "SaveReasonButton"
	_save_reason.text = "บันทึกคำตอบ"
	_save_reason.custom_minimum_size = Vector2(170, 36)
	_save_reason.size_flags_horizontal = Control.SIZE_SHRINK_END
	_save_reason.focus_mode = Control.FOCUS_NONE
	_save_reason.pressed.connect(save_reason)
	_style_primary(_save_reason)
	_decision_box.add_child(_save_reason)

	_quantity_row = HBoxContainer.new()
	_quantity_row.name = "QuantityRow"
	_quantity_row.add_theme_constant_override("separation", 10)
	_options.add_child(_quantity_row)
	var q_label := _small_label("จำนวนอุปกรณ์ที่ต้องใช้", 17, NetPlanTheme.INK, true)
	_quantity_row.add_child(q_label)
	_quantity = SpinBox.new()
	_quantity.name = "Quantity"
	_quantity.min_value = 0
	_quantity.max_value = 30
	_quantity.step = 1
	_quantity.custom_minimum_size = Vector2(110, 0)
	_quantity.value_changed.connect(func(_v: float): _refresh_confirm())
	_quantity_row.add_child(_quantity)
	_quantity_row.add_child(_small_label("ตัว", 17, NetPlanTheme.INK, false))


## Shows the pop-up for `question` using the player's saved marks and answer.
## `is_locked` = the point was already checked as correct: show it read-only.
func open_for(question: EquipmentQuestion, state: Mission01State, data: Mission01Data, is_locked: bool = false) -> void:
	_state = state
	_data = data
	point_id = question.point_id
	locked = is_locked
	selected_option = state.get_answer(point_id)
	if selected_option == "":
		for device in question.options:
			if state.get_mark(point_id, device) == Mission01Data.DECISION_CHOOSE:
				selected_option = device
	_title.text = "จุดที่ %d · %s" % [question.point_id, question.title]
	_location.text = "ตำแหน่งติดตั้ง: " + question.location
	_question.text = question.question + " (คลิกอุปกรณ์เพื่อตัดสินใจพร้อมเหตุผล)"
	if not _device_order.has(point_id):
		var order := Array(question.options)
		_shuffle(order)
		_device_order[point_id] = order
	_build_devices()
	_quantity.value = state.get_quantity(point_id) if state.get_answer(point_id) != "" else 0
	_quantity.editable = not locked
	_close_decision()
	if locked:
		_note.text = "จุดนี้ผ่านการตรวจสอบแล้ว เปลี่ยนอุปกรณ์ไม่ได้"
	else:
		_note.text = "ต้องมีอุปกรณ์ที่ \"เลือก\" 1 ชนิด และระบุจำนวน ก่อนกด \"ยืนยันจุดนี้\" (เปลี่ยนภายหลังได้ แต่ระบบนับเหตุผลครั้งแรกของแต่ละอุปกรณ์)"
	_confirm.visible = not locked
	_cancel.text = "ปิด" if locked else "ยกเลิก"
	_refresh_confirm()
	visible = true
	move_to_front()


## Clicks a device (also used by tests).
func choose(option: String) -> void:
	if locked or not option in (_device_order.get(point_id, []) as Array):
		return
	active_device = option
	active_decision = ""
	active_reason = -1
	for b in _devices.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.get_meta("option", "") == option)
			b.queue_redraw()
	_decision_title.text = "คุณจะเลือก %s สำหรับจุดนี้หรือไม่" % option
	_choose_button.set_pressed_no_signal(false)
	_reject_button.set_pressed_no_signal(false)
	_reason_title.visible = false
	_reasons.visible = false
	_save_reason.visible = false
	_decision_box.visible = true
	equipment_selected.emit(point_id, option)


## "เลือกอุปกรณ์นี้" / "ไม่เลือกอุปกรณ์นี้" for the active device.
func decide(decision: String) -> void:
	if locked or active_device == "":
		return
	active_decision = decision
	active_reason = -1
	_choose_button.set_pressed_no_signal(decision == Mission01Data.DECISION_CHOOSE)
	_reject_button.set_pressed_no_signal(decision == Mission01Data.DECISION_REJECT)
	var verb := "เลือก" if decision == Mission01Data.DECISION_CHOOSE else "ไม่เลือก"
	_reason_title.text = "%s %s เพราะ…" % [verb, active_device]
	_reason_title.visible = true
	for child in _reasons.get_children():
		_reasons.remove_child(child)
		child.queue_free()
	_reason_group = ButtonGroup.new()
	var key := "%d|%s|%s" % [point_id, active_device, decision]
	var options := _data.reason_options(point_id, active_device, decision)
	if not _reason_order.has(key):
		var order := range(options.size())
		_shuffle(order)
		_reason_order[key] = order
	for index: int in _reason_order[key]:
		_reasons.add_child(_make_reason(index, String(options[index].get("text", ""))))
	_reasons.visible = true
	_save_reason.visible = true
	_save_reason.disabled = true


## Picks reason `option_index` (index in the data, not on screen). Tests use this.
func pick_reason(option_index: int) -> void:
	for b in _reasons.get_children():
		if b is Button and int(b.get_meta("index", -1)) == option_index:
			b.button_pressed = true


## "บันทึกคำตอบ": records the decision + reason for the active device.
func save_reason() -> void:
	if locked or active_device == "" or active_decision == "" or active_reason < 0:
		return
	var device := active_device
	var decision := active_decision
	if decision == Mission01Data.DECISION_CHOOSE:
		selected_option = device
		if _quantity.value < 1 and _state.get_answer(point_id) == "":
			_quantity.value = 0
	elif selected_option == device:
		selected_option = ""
	reason_answered.emit(point_id, device, decision, active_reason)
	_build_devices()
	_close_decision()
	_refresh_confirm()


func set_quantity(value: int) -> void:
	_quantity.value = value


func confirm() -> void:
	if locked or selected_option == "" or _quantity.value < 1 or not visible:
		return
	var id := point_id
	var option := selected_option
	var amount := int(_quantity.value)
	close()
	answer_confirmed.emit(id, option, amount)


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


func _make_device(option: String) -> Button:
	var b := _toggle(option, 44)
	b.name = "Option_" + option.replace(" ", "_")
	b.set_meta("option", option)
	b.button_group = _device_group
	b.disabled = locked
	b.custom_minimum_size = Vector2(350, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 8, 40, 8))
	# Mark drawn on the left: ✓ chosen, ✗ not chosen, empty = not decided yet.
	b.draw.connect(func():
		var mark := _state.get_mark(point_id, option) if _state else ""
		var c := Vector2(22, b.size.y * 0.5)
		if mark == Mission01Data.DECISION_CHOOSE:
			b.draw_circle(c, 10, NetPlanTheme.ACCENT)
			b.draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(5, -4)]), Color.WHITE, 2.0, true)
		elif mark == Mission01Data.DECISION_REJECT:
			b.draw_arc(c, 10, 0, TAU, 32, NetPlanTheme.INK_SOFT, 2.0, true)
			NetPlanTheme.draw_cross(b, c, 9.0, NetPlanTheme.INK_SOFT, 2.0)
		else:
			b.draw_arc(c, 10, 0, TAU, 32, NetPlanTheme.BORDER, 2.0, true))
	b.pressed.connect(func(): choose(option))
	return b


func _make_reason(index: int, text: String) -> Button:
	var b := _toggle("", 0)
	b.name = "Reason_%d" % index
	b.set_meta("index", index)
	b.button_group = _reason_group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = text
	b.custom_minimum_size = Vector2(710, 0)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 8, 40, 4))
	b.add_theme_stylebox_override("hover", NetPlanTheme.box(Color(0.94, 0.96, 1.0), NetPlanTheme.ACCENT.lightened(0.35), 8, 40, 4))
	var on := NetPlanTheme.box(Color(0.89, 0.94, 1.0), NetPlanTheme.ACCENT, 8, 40, 4)
	on.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.draw.connect(func():
		var c := Vector2(20, b.size.y * 0.5)
		b.draw_arc(c, 9, 0, TAU, 32, NetPlanTheme.ACCENT if b.button_pressed else NetPlanTheme.INK_SOFT, 2.0, true)
		if b.button_pressed:
			b.draw_circle(c, 5.0, NetPlanTheme.ACCENT))
	b.toggled.connect(func(on: bool):
		b.queue_redraw()
		if on:
			active_reason = index
			_save_reason.disabled = false)
	return b


## `pad_left` leaves room for the drawn radio/check mark (0 = plain text button).
func _toggle(text: String, height: float, pad_left: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 18)
	var pad := maxi(pad_left, 16)
	b.add_theme_stylebox_override("normal", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 8, pad, 8))
	b.add_theme_stylebox_override("hover", NetPlanTheme.box(Color(0.94, 0.96, 1.0), NetPlanTheme.ACCENT.lightened(0.35), 8, pad, 8))
	var on := NetPlanTheme.box(Color(0.89, 0.94, 1.0), NetPlanTheme.ACCENT, 8, pad, 8)
	on.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("disabled", NetPlanTheme.box(Color(0.96, 0.96, 0.97), NetPlanTheme.BORDER, 8, pad, 8))
	return b


func _small_label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)
	return l


func _style_primary(b: Button) -> void:
	var primary := NetPlanTheme.box(NetPlanTheme.ACCENT, NetPlanTheme.ACCENT.darkened(0.2), 6, 16, 8)
	b.add_theme_stylebox_override("normal", primary)
	var hover := primary.duplicate() as StyleBoxFlat
	hover.bg_color = NetPlanTheme.ACCENT.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)


func _close_decision() -> void:
	active_device = ""
	active_decision = ""
	active_reason = -1
	_decision_box.visible = false
	for b in _devices.get_children():
		if b is Button:
			b.set_pressed_no_signal(false)


func _refresh_confirm() -> void:
	_quantity_row.visible = selected_option != ""
	_confirm.disabled = locked or selected_option == "" or _quantity.value < 1


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
