class_name Mission02CableBoxPanel
extends CanvasLayer

## Opens at a cable box in the storage room: "take a cable from this box for
## which connection point?". The two points of the job are shown with their
## devices; each point takes ONE cable, from whichever box the player is at,
## and that choice is final (it is the cable-type decision, score A).

signal cable_taken(point: int, type: String)
signal closed

const DEVICE_ICONS := "res://assets/ui/devices/"
## point -> [from title, from icon, to title, to icon]
const POINTS := {
	1: ["Router", "router", "Switched Hub 24 Port", "switched_hub_24_port"],
	2: ["Switched Hub 24 Port", "switched_hub_24_port", "คอมพิวเตอร์ครู", "computer"],
}

var box_type := ""
## point -> type of the cable already taken (shared with the controller's state).
var taken := {}
var _title: Label
var _ends: Label
var _rows := {}


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
	card.name = "CableBoxCard"
	card.custom_minimum_size = Vector2(760, 0)
	card.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1), Color(0.8, 0.83, 0.88), 14, 28, 20))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	_title = GameUI.label("", 22, GameUI.INK, true)
	col.add_child(_title)
	_ends = GameUI.label("", 16, GameUI.INK_SOFT)
	col.add_child(_ends)
	col.add_child(GameUI.label("หยิบสายจากกล่องนี้ไปใช้กับจุดเชื่อมต่อไหน? (แต่ละจุดหยิบได้ครั้งเดียว เปลี่ยนภายหลังไม่ได้)", 16, GameUI.INK_SOFT))
	for point: int in POINTS:
		col.add_child(_point_row(point))
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(footer)
	var close_button := GameUI.button("ปิด", false, 140)
	close_button.name = "CloseButton"
	close_button.set_meta("sound", "back")
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func open(type: String, already_taken: Dictionary) -> void:
	box_type = type
	taken = already_taken
	var info: Array = Mission02CableBox.TYPES[type]
	_title.text = "กล่องสาย UTP Cat6  ·  %s Cable" % info[0]
	_ends.text = "ป้ายข้างกล่อง:  ปลาย 1  %s   ·   ปลาย 2  %s" % [info[1], info[2]]
	_refresh()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sound.play("popup_open")


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Takes a cable from the open box for `point` (also what the button does).
func take(point: int) -> bool:
	if not visible or not POINTS.has(point) or taken.has(point):
		return false
	cable_taken.emit(point, box_type)
	_refresh()
	return true


func _refresh() -> void:
	for point: int in _rows:
		var button: Button = _rows[point]
		if taken.has(point):
			button.text = "หยิบแล้ว (%s)" % String(Mission02CableBox.TYPES[taken[point]][0])
			button.disabled = true
		else:
			button.text = "หยิบสายไปใช้จุดนี้"
			button.disabled = false


func _point_row(point: int) -> Control:
	var info: Array = POINTS[point]
	var row := PanelContainer.new()
	row.name = "Point%d" % point
	row.add_theme_stylebox_override("panel", GameUI.box(Color(0.97, 0.98, 1.0), Color(0.86, 0.89, 0.94), 10, 14, 10))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var button := GameUI.button("หยิบสายไปใช้จุดนี้", true, 230)
	button.name = "Take%d" % point
	button.set_meta("sound", "select")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func(): take(point))
	line.add_child(button)
	_rows[point] = button
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
	else:
		# No picture file for a desktop computer: draw one.
		var drawn := Control.new()
		drawn.name = "ComputerPicture"
		drawn.custom_minimum_size = picture.custom_minimum_size
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drawn.draw.connect(draw_computer.bind(drawn))
		box.add_child(drawn)
	var name_label := GameUI.label(title, 14, GameUI.INK, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	return box


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## A desktop computer (monitor, keyboard, tower) in the grey-and-blue look of
## the device pictures, fitted into `canvas`.
static func draw_computer(canvas: Control) -> void:
	var h := canvas.size.y
	var unit := h / 56.0
	var o := Vector2((canvas.size.x - 104.0 * unit) * 0.5, 0)
	var r := func(x: float, y: float, w: float, hh: float) -> Rect2: return Rect2(o + Vector2(x, y) * unit, Vector2(w, hh) * unit)
	var dark := Color(0.2, 0.22, 0.26)
	var edge := Color(0.42, 0.45, 0.5)
	# Monitor: bezel, screen with a soft highlight, stand and foot.
	canvas.draw_rect(r.call(6, 4, 62, 38), dark)
	canvas.draw_rect(r.call(9, 7, 56, 30), Color(0.2, 0.45, 0.78))
	canvas.draw_rect(r.call(9, 7, 56, 12), Color(0.33, 0.58, 0.88))
	canvas.draw_rect(r.call(6, 4, 62, 38), edge, false, 1.0)
	canvas.draw_rect(r.call(33, 42, 8, 6), Color(0.32, 0.34, 0.38))
	canvas.draw_rect(r.call(24, 48, 26, 3), Color(0.32, 0.34, 0.38))
	# Keyboard.
	canvas.draw_rect(r.call(12, 51, 50, 4), Color(0.55, 0.58, 0.63))
	# Tower: case, front panel line, power button, drive slot.
	canvas.draw_rect(r.call(76, 8, 24, 47), dark)
	canvas.draw_rect(r.call(76, 8, 24, 47), edge, false, 1.0)
	canvas.draw_rect(r.call(80, 14, 16, 3), Color(0.35, 0.38, 0.43))
	canvas.draw_circle(o + Vector2(88, 24) * unit, 2.2 * unit, Color(0.3, 0.8, 1.0))
	canvas.draw_rect(r.call(80, 44, 16, 1.5), Color(0.35, 0.38, 0.43))
