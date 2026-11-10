class_name Mission02WorkOrder
extends CanvasLayer

## The work order the supervisor hands over: pick the cable type for the two
## connection points. Each option shows the wire order at both ends (T568B-B
## or T568A-B) but never says which devices it is for. One answer per point;
## "ยืนยันใบงาน" saves both and closes (no changes afterwards).

signal confirmed(answers: Dictionary)

const DEVICE_ICONS := "res://assets/ui/devices/"
## point -> [from title, from icon, to title, to icon]
const POINTS := {
	1: ["Router", "router", "Switched Hub 24 Port", "switched_hub_24_port"],
	2: ["Switched Hub 24 Port", "switched_hub_24_port", "คอมพิวเตอร์ครู", ""],
}
const OPTIONS := {
	Mission02State.STRAIGHT: ["Straight-Through Cable", "T568B", "T568B"],
	Mission02State.CROSSOVER: ["Crossover Cable", "T568A", "T568B"],
}

var answers := {} # point -> type
var _groups := {}
var _confirm: Button


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.name = "WorkOrderCard"
	card.custom_minimum_size = Vector2(900, 0)
	card.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1), Color(0.8, 0.83, 0.88), 14, 28, 20))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	col.add_child(GameUI.label("ใบงาน  ·  เตรียมสาย LAN ห้องคอมพิวเตอร์ใหม่", 22, GameUI.INK, true))
	col.add_child(GameUI.label("เลือกชนิดสายให้เหมาะกับแต่ละจุดเชื่อมต่อ แล้วกด \"ยืนยันใบงาน\" (ตอบได้ครั้งเดียว)", 16, GameUI.INK_SOFT))
	for point: int in POINTS:
		col.add_child(_point_row(point))
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(footer)
	_confirm = GameUI.button("ยืนยันใบงาน", true, 200)
	_confirm.name = "ConfirmButton"
	_confirm.set_meta("sound", "confirm")
	_confirm.disabled = true
	_confirm.pressed.connect(confirm)
	footer.add_child(_confirm)


func open() -> void:
	answers.clear()
	for group: ButtonGroup in _groups.values():
		for b in group.get_buttons():
			b.set_pressed_no_signal(false)
	_confirm.disabled = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sound.play("popup_open")


func is_open() -> bool:
	return visible


## Picks `type` for `point` (also what clicking an option does).
func choose(point: int, type: String) -> void:
	if not POINTS.has(point) or not OPTIONS.has(type):
		return
	answers[point] = type
	for b in (_groups[point] as ButtonGroup).get_buttons():
		b.set_pressed_no_signal(b.get_meta("type") == type)
	_confirm.disabled = answers.size() < POINTS.size()


func confirm() -> void:
	if answers.size() < POINTS.size() or not visible:
		return
	visible = false
	confirmed.emit(answers.duplicate())


func _point_row(point: int) -> Control:
	var info: Array = POINTS[point]
	var row := PanelContainer.new()
	row.name = "Point%d" % point
	row.add_theme_stylebox_override("panel", GameUI.box(Color(0.97, 0.98, 1.0), Color(0.86, 0.89, 0.94), 10, 14, 10))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 4)
	line.add_child(left)
	left.add_child(GameUI.label("จุดเชื่อมต่อที่ %d" % point, 15, GameUI.INK_SOFT, true))
	var devices := HBoxContainer.new()
	devices.add_theme_constant_override("separation", 6)
	left.add_child(devices)
	devices.add_child(_device(info[0], info[1]))
	var arrow := GameUI.label("→", 22, GameUI.INK_SOFT, true)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	devices.add_child(arrow)
	devices.add_child(_device(info[2], info[3]))
	var group := ButtonGroup.new()
	group.allow_unpress = false
	_groups[point] = group
	for type: String in OPTIONS:
		line.add_child(_option(point, type, group))
	return row


func _device(title: String, icon: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(130, 0)
	box.add_theme_constant_override("separation", 2)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(120, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := DEVICE_ICONS + icon + ".png"
	if icon != "" and ResourceLoader.exists(path):
		picture.texture = load(path)
	box.add_child(picture)
	var name_label := GameUI.label(title, 14, GameUI.INK, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	return box


func _option(point: int, type: String, group: ButtonGroup) -> Button:
	var info: Array = OPTIONS[type]
	var b := Button.new()
	b.name = "Option_%d_%s" % [point, type]
	b.set_meta("type", type)
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(225, 128)
	b.add_theme_stylebox_override("normal", GameUI.box(Color(1, 1, 1), Color(0.82, 0.85, 0.9), 8, 10, 8))
	b.add_theme_stylebox_override("hover", GameUI.box(Color(0.94, 0.96, 1.0), GameUI.ACCENT.lightened(0.35), 8, 10, 8))
	var on := GameUI.box(Color(0.89, 0.94, 1.0), GameUI.ACCENT, 8, 10, 8)
	on.set_border_width_all(3)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_right = -10
	content.offset_top = 8
	content.offset_bottom = -8
	content.add_theme_constant_override("separation", 4)
	b.add_child(content)
	var title := GameUI.label(info[0], 16, GameUI.INK, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	for i in 2:
		var end := HBoxContainer.new()
		end.mouse_filter = Control.MOUSE_FILTER_IGNORE
		end.add_theme_constant_override("separation", 6)
		content.add_child(end)
		var tag := GameUI.label("ปลาย %d  %s" % [i + 1, info[1 + i]], 13, GameUI.INK_SOFT)
		tag.custom_minimum_size = Vector2(92, 0)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		end.add_child(tag)
		var strip := WireStrip.new()
		strip.order = WireColors.T568B if info[1 + i] == "T568B" else WireColors.T568A
		strip.custom_minimum_size = Vector2(104, 26)
		end.add_child(strip)
	b.pressed.connect(func(): choose(point, type))
	return b


## Eight wires side by side, pin 1 on the left.
class WireStrip:
	extends Control

	var order: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x / 8.0
		for i in mini(order.size(), 8):
			WireColors.draw_wire(self, Rect2(Vector2(i * w + 1, 0), Vector2(w - 2, size.y)), order[i])
