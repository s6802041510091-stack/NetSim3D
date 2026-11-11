extends CanvasLayer
class_name ControlsHelpPopup

signal dismissed
var close_button: Button
var _hint: Label

func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.1, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	shade.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	panel.add_theme_stylebox_override("panel", GameUI.box(Color("f9fbfffa"), Color("d9eaff"), 24, 28, 24))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(GameUI.label("วิธีควบคุม", 28, GameUI.INK, true))
	col.add_child(GameUI.label("พร้อมสำรวจโรงเรียนแล้ว", 17, GameUI.INK_SOFT))
	col.add_child(HSeparator.new())
	var keys := [["W A S D", "เดิน"], ["Mouse", "มองรอบตัว"], ["Shift", "วิ่ง"], ["F", "โต้ตอบ / ใช้อุปกรณ์ / เปิดประตู"], ["E", "เปิด–ปิดกระเป๋า"], ["F1", "เปิดเมนูพัก / ตั้งค่า"], ["Esc", "แสดงเมาส์"]]
	for pair in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var key := GameUI.label(pair[0], 19, Color("237db1"), true)
		key.custom_minimum_size.x = 126
		row.add_child(key)
		row.add_child(GameUI.label(pair[1], 18))
		col.add_child(row)
	col.add_child(HSeparator.new())
	_hint = GameUI.label("", 16, GameUI.INK_SOFT)
	_hint.custom_minimum_size.x = 500
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	close_button = GameUI.button("เข้าใจแล้ว เริ่มเล่น", true)
	close_button.name = "DismissControlsHelp"
	close_button.pressed.connect(dismiss)
	col.add_child(close_button)
	hide()

func open(hint: String) -> void:
	_hint.text = hint
	_hint.visible = hint != ""
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	close_button.grab_focus()

func dismiss() -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	hide()
	dismissed.emit()
