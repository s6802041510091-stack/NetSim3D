class_name NetworkDesigner
extends VBoxContainer

## "Network Designer" — the program used in Mission 1 (design the network).
##
##   1. Brief: read the problem and pick a topology (Bus / Ring / Star / Mesh).
##      Only Star is accepted; every wrong pick shows why and costs points.
##   2. Design: drag devices into the dashed slots, then click two ports to
##      run a cable. Internet -> Router (WAN) -> Switch (Uplink) -> PCs.
##      Wrong device, wrong place or wrong port is rejected, explained and
##      costs points.
##   3. Check: verifies device types, count, positions and every cable, then
##      shows the score, the time used and "ภารกิจสำเร็จ".
##
## The mission system can listen to the signals below; this script does not
## decide what the mission does with the result.

signal topology_answered(topology: String, correct: bool)
signal mistake_made(reason: String, penalty: int)
signal design_checked(problems: PackedStringArray)
signal completed(score: int, seconds: float, mistakes: int)
signal close_requested

const START_SCORE := 100
const PENALTY_TOPOLOGY := 10
const PENALTY_PLACEMENT := 5
const PENALTY_LINK := 5
const PENALTY_FAILED_CHECK := 5
const STUDENT_COUNT := 4
const CANVAS_SIZE := Vector2(840, 400)

enum Stage { BRIEF, DESIGN, DONE }

const DEVICES := {
	"internet": {"name": "Internet (ISP)", "color": Color(0.55, 0.78, 0.98), "size": Vector2(130, 56)},
	"router": {"name": "Router", "color": Color(0.98, 0.72, 0.35), "size": Vector2(130, 60)},
	"switch": {"name": "Switch 8 พอร์ต", "color": Color(0.45, 0.82, 0.62), "size": Vector2(320, 66)},
	"hub": {"name": "Hub", "color": Color(0.8, 0.8, 0.55), "size": Vector2(130, 60)},
	"teacher_pc": {"name": "เครื่องครู", "color": Color(0.72, 0.62, 0.95), "size": Vector2(130, 60)},
	"student_pc": {"name": "เครื่องนักเรียน", "color": Color(0.6, 0.75, 0.95), "size": Vector2(130, 60)},
	"server": {"name": "Server", "color": Color(0.7, 0.7, 0.74), "size": Vector2(130, 60)},
	"access_point": {"name": "Access Point", "color": Color(0.95, 0.6, 0.7), "size": Vector2(130, 60)},
}
const PALETTE := ["router", "switch", "hub", "teacher_pc", "student_pc", "server", "access_point"]

## Ports: top edge / bottom edge of each device box.
const PORTS := {
	"internet": {"top": [], "bottom": ["ISP"]},
	"router": {"top": ["WAN"], "bottom": ["LAN1", "LAN2"]},
	"switch": {"top": ["Uplink"], "bottom": ["1", "2", "3", "4", "5", "6", "7"]},
	"teacher_pc": {"top": ["LAN"], "bottom": []},
	"student_pc": {"top": ["LAN"], "bottom": []},
	"hub": {"top": [], "bottom": ["1", "2", "3", "4"]},
	"server": {"top": ["LAN"], "bottom": []},
	"access_point": {"top": ["LAN"], "bottom": []},
}

const TOPOLOGIES := [
	{"id": "bus", "name": "Bus Topology", "desc": "ทุกเครื่องต่อกับสายหลักเส้นเดียว",
		"why": "Bus ใช้สายหลักเส้นเดียว ถ้าสายหลักขาดทั้งห้องจะใช้งานไม่ได้ และข้อมูลชนกันบ่อยเมื่อมีหลายเครื่อง"},
	{"id": "ring", "name": "Ring Topology", "desc": "เครื่องต่อกันเป็นวงกลม ส่งข้อมูลวนไป",
		"why": "Ring ส่งข้อมูลวนต่อกันเป็นวง ถ้าเครื่องหรือสายจุดใดเสีย ทั้งวงอาจหยุดทำงาน และเพิ่มเครื่องได้ยาก"},
	{"id": "star", "name": "Star Topology", "desc": "ทุกเครื่องต่อเข้าอุปกรณ์ศูนย์กลาง (Switch)",
		"why": "ถูกต้อง! Star ใช้ Switch เป็นศูนย์กลาง ดูแลง่าย เพิ่มหรือถอดเครื่องสะดวก และถ้าสายเครื่องหนึ่งเสีย เครื่องอื่นยังใช้งานได้"},
	{"id": "mesh", "name": "Mesh Topology", "desc": "ทุกเครื่องต่อถึงกันหมดทุกคู่",
		"why": "Mesh ต้องเดินสายจากทุกเครื่องถึงกันทุกคู่ ใช้สายและพอร์ตจำนวนมาก ค่าใช้จ่ายสูงเกินไปสำหรับห้องเรียน"},
]

const PROBLEM_TEXT := "โจทย์: ห้องปฏิบัติการคอมพิวเตอร์มีเครื่องครู 1 เครื่อง และเครื่องนักเรียนหลายเครื่อง ทุกเครื่องต้องออกอินเทอร์เน็ตผ่าน Router ได้ ต้องดูแลรักษาง่าย เพิ่มเครื่องได้สะดวก และถ้าสายของเครื่องใดเครื่องหนึ่งเสีย เครื่องอื่นต้องยังใช้งานได้\n\nควรเลือกโครงสร้างเครือข่าย (Topology) แบบใด?"

const COLOR_BAD := Color(0.86, 0.2, 0.2)
const COLOR_GOOD := Color(0.16, 0.6, 0.3)
const COLOR_INFO := Color(0.2, 0.42, 0.75)
const COLOR_INK := Color(0.1, 0.12, 0.16)

var stage := Stage.BRIEF
var score := START_SCORE
var mistakes := 0
var elapsed_seconds := 0.0
var slots: Array[Dictionary] = []
var links: Array[Dictionary] = []
var internet_node: Panel

var _start_msec := 0
var _finish_msec := 0
var _pending := {}
var _score_label: Label
var _time_label: Label
var _mistake_label: Label
var _banner: PanelContainer
var _banner_label: Label
var _pages: Control
var _brief_page: Control
var _design_page: Control
var _result_page: Control
var _canvas: Control
var _result_text: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_start_msec = Time.get_ticks_msec()
	_build_header()
	_build_banner()
	_pages = Control.new()
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pages.custom_minimum_size = Vector2(1060, 450)
	add_child(_pages)
	_build_brief_page()
	_build_design_page()
	_build_result_page()
	_show_page(_brief_page)
	_info("อ่านโจทย์ แล้วเลือกโครงสร้างเครือข่ายที่เหมาะกับห้องคอมพิวเตอร์")


func _process(_delta: float) -> void:
	var end := _finish_msec if stage == Stage.DONE else Time.get_ticks_msec()
	elapsed_seconds = (end - _start_msec) / 1000.0
	_time_label.text = "เวลา " + format_time(elapsed_seconds)
	if not _pending.is_empty():
		_canvas.queue_redraw()


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]


# ================================================================ header / feedback

func _build_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	add_child(row)
	var title := _label("Network Designer — ออกแบบโครงสร้างเครือข่าย", 20, COLOR_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_score_label = _label("", 18, COLOR_INFO)
	row.add_child(_score_label)
	_mistake_label = _label("", 18, COLOR_BAD)
	row.add_child(_mistake_label)
	_time_label = _label("เวลา 00:00", 18, COLOR_INK)
	row.add_child(_time_label)
	_update_header()


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.custom_minimum_size = Vector2(0, 46)
	add_child(_banner)
	_banner_label = _label("", 16, Color.WHITE)
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)


func _set_banner(text: String, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_banner.add_theme_stylebox_override("panel", style)
	_banner_label.text = text


func _info(text: String) -> void:
	_set_banner(text, COLOR_INFO)


func _mistake(reason: String, penalty: int) -> void:
	score = maxi(0, score - penalty)
	mistakes += 1
	_update_header()
	_set_banner("ผิด: %s  (−%d คะแนน)" % [reason, penalty], COLOR_BAD)
	mistake_made.emit(reason, penalty)


func _update_header() -> void:
	_score_label.text = "คะแนน %d" % score
	_mistake_label.text = "ผิด %d ครั้ง" % mistakes


func _show_page(page: Control) -> void:
	for p in [_brief_page, _design_page, _result_page]:
		p.visible = p == page


# ================================================================ stage 1: topology

func _build_brief_page() -> void:
	_brief_page = VBoxContainer.new()
	_brief_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brief_page.add_theme_constant_override("separation", 16)
	_pages.add_child(_brief_page)

	var problem := _label(PROBLEM_TEXT, 18, COLOR_INK)
	problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	problem.custom_minimum_size = Vector2(1000, 0)
	_brief_page.add_child(problem)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_brief_page.add_child(cards)
	for topology in TOPOLOGIES:
		cards.add_child(_topology_card(topology))


func _topology_card(topology: Dictionary) -> Button:
	var card := Button.new()
	card.name = "Topology_" + topology.id
	card.custom_minimum_size = Vector2(240, 230)
	card.pressed.connect(func(): choose_topology(topology.id))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 10
	box.offset_bottom = -10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var diagram := Control.new()
	diagram.custom_minimum_size = Vector2(200, 120)
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram.draw.connect(func(): _draw_topology(diagram, topology.id))
	box.add_child(diagram)
	var name_label := _label(topology.name, 18, Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var desc := _label(topology.desc, 14, Color(0.85, 0.88, 0.92))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	return card


func _draw_topology(c: Control, id: String) -> void:
	var w := c.size.x
	var line := Color(0.75, 0.85, 1.0)
	var node := Color(0.45, 0.75, 1.0)
	var center := Vector2(w * 0.5, 60)
	var points: Array[Vector2] = []
	match id:
		"bus":
			c.draw_line(Vector2(w * 0.08, 60), Vector2(w * 0.92, 60), line, 3.0)
			for i in 5:
				var x := w * (0.16 + i * 0.17)
				var y := 28.0 if i % 2 == 0 else 92.0
				c.draw_line(Vector2(x, 60), Vector2(x, y), line, 2.0)
				points.append(Vector2(x, y))
		"ring":
			for i in 6:
				points.append(center + Vector2.from_angle(TAU * i / 6.0 - PI / 2) * 46.0)
			for i in 6:
				c.draw_line(points[i], points[(i + 1) % 6], line, 2.0)
		"star":
			for i in 6:
				var p := center + Vector2.from_angle(TAU * i / 6.0 - PI / 2) * 50.0
				c.draw_line(center, p, line, 2.0)
				points.append(p)
			c.draw_rect(Rect2(center - Vector2(16, 10), Vector2(32, 20)), Color(0.45, 0.82, 0.62))
		"mesh":
			for i in 5:
				points.append(center + Vector2.from_angle(TAU * i / 5.0 - PI / 2) * 48.0)
			for i in 5:
				for j in range(i + 1, 5):
					c.draw_line(points[i], points[j], line, 1.5)
	for p in points:
		c.draw_circle(p, 8.0, node)


## Player picks a topology. Returns true when it is the right one (Star).
func choose_topology(id: String) -> bool:
	if stage != Stage.BRIEF:
		return false
	var topology: Dictionary = {}
	for t in TOPOLOGIES:
		if t.id == id:
			topology = t
	var correct := id == "star"
	topology_answered.emit(id, correct)
	if not correct:
		_mistake("%s ไม่เหมาะกับห้องคอมพิวเตอร์ — %s" % [topology.get("name", id), topology.get("why", "")], PENALTY_TOPOLOGY)
		return false
	stage = Stage.DESIGN
	_show_page(_design_page)
	_set_banner(topology.why + "  ต่อไป: ลากอุปกรณ์ลงช่องเส้นประ แล้วเชื่อมสาย", COLOR_GOOD)
	return true


# ================================================================ stage 2: design

func _build_design_page() -> void:
	_design_page = HBoxContainer.new()
	_design_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_design_page.add_theme_constant_override("separation", 12)
	_pages.add_child(_design_page)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(200, 0)
	side.add_theme_constant_override("separation", 6)
	_design_page.add_child(side)
	side.add_child(_label("อุปกรณ์ (ลากไปวาง)", 16, COLOR_INK))
	for type in PALETTE:
		side.add_child(_palette_item(type))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var check := Button.new()
	check.name = "CheckButton"
	check.text = "ตรวจคำตอบ"
	check.custom_minimum_size = Vector2(200, 44)
	check.add_theme_font_size_override("font_size", 18)
	check.pressed.connect(check_answer)
	side.add_child(check)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	_design_page.add_child(right)
	_canvas = Control.new()
	_canvas.name = "DesignCanvas"
	_canvas.custom_minimum_size = CANVAS_SIZE
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.set_drag_forwarding(Callable(), _can_drop, _drop)
	right.add_child(_canvas)
	var help := _label("คลิกพอร์ต 2 จุดเพื่อเชื่อมสาย • คลิกพอร์ตที่มีสายเพื่อถอดสาย • คลิกขวาที่อุปกรณ์เพื่อนำออก", 13, Color(0.35, 0.4, 0.48))
	right.add_child(help)

	_make_slots()
	internet_node = _create_device("internet", Vector2((CANVAS_SIZE.x - 130) * 0.5, 10))


func _make_slots() -> void:
	var mid := CANVAS_SIZE.x * 0.5
	slots.append(_slot("router", "router", "ช่อง Router", Rect2(mid - 65, 100, 130, 60)))
	slots.append(_slot("switch", "switch", "ช่อง Switch (ศูนย์กลาง)", Rect2(mid - 160, 196, 320, 66)))
	var count := 1 + STUDENT_COUNT
	var gap := (CANVAS_SIZE.x - count * 130.0) / (count + 1)
	for i in count:
		var rect := Rect2(gap + i * (130 + gap), 318, 130, 60)
		if i == 0:
			slots.append(_slot("teacher", "teacher_pc", "ช่องเครื่องครู", rect))
		else:
			slots.append(_slot("student%d" % i, "student_pc", "ช่องเครื่องนักเรียน %d" % i, rect))


func _slot(id: String, type: String, label: String, rect: Rect2) -> Dictionary:
	return {"id": id, "type": type, "label": label, "rect": rect, "device": null}


func _palette_item(type: String) -> Button:
	var info: Dictionary = DEVICES[type]
	var item := Button.new()
	item.name = "Palette_" + type
	item.text = info.name
	item.custom_minimum_size = Vector2(200, 36)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var style := StyleBoxFlat.new()
	style.bg_color = info.color.darkened(0.25)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	item.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = info.color.darkened(0.1)
	item.add_theme_stylebox_override("hover", hover)
	item.add_theme_color_override("font_color", Color.WHITE)
	item.tooltip_text = "ลาก %s ไปวางในช่องที่เหมาะสม" % info.name
	item.set_drag_forwarding(func(_pos): return _start_drag(type), Callable(), Callable())
	return item


func _start_drag(type: String) -> Variant:
	if stage != Stage.DESIGN:
		return null
	var preview := Panel.new()
	preview.size = DEVICES[type].size
	preview.add_theme_stylebox_override("panel", _device_style(type, 0.75))
	var text := _label(DEVICES[type].name, 15, COLOR_INK)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(text)
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -preview.size * 0.5
	set_drag_preview(holder)
	return {"device": type}


func _can_drop(_pos: Vector2, data: Variant) -> bool:
	return stage == Stage.DESIGN and data is Dictionary and data.has("device")


func _drop(pos: Vector2, data: Variant) -> void:
	try_place_at(data.device, pos)


func _slot_at(pos: Vector2) -> Dictionary:
	for slot in slots:
		if slot.rect.grow(18).has_point(pos):
			return slot
	return {}


func get_slot(id: String) -> Dictionary:
	for slot in slots:
		if slot.id == id:
			return slot
	return {}


## Drops a device of `type` at a canvas position. Returns true if it was placed.
func try_place_at(type: String, pos: Vector2) -> bool:
	if stage != Stage.DESIGN:
		return false
	var slot := _slot_at(pos)
	if slot.is_empty():
		_mistake("วางผิดตำแหน่ง — ต้องวาง %s ลงในกรอบเส้นประที่กำหนด" % DEVICES[type].name, PENALTY_PLACEMENT)
		return false
	if slot.device != null:
		_info("%s มีอุปกรณ์อยู่แล้ว — คลิกขวาที่อุปกรณ์เพื่อนำออกก่อน" % slot.label)
		return false
	if type != slot.type:
		_mistake(_wrong_device_reason(type, slot), PENALTY_PLACEMENT)
		return false
	slot.device = _create_device(type, slot.rect.position)
	slot.device.set_meta("slot_id", slot.id)
	_info("วาง %s แล้ว" % DEVICES[type].name)
	_canvas.queue_redraw()
	return true


## Same as dragging onto the slot with this id (used by tests and hints).
func try_place(type: String, slot_id: String) -> bool:
	var slot := get_slot(slot_id)
	if slot.is_empty():
		return try_place_at(type, Vector2(-100, -100))
	return try_place_at(type, slot.rect.get_center())


func _wrong_device_reason(type: String, slot: Dictionary) -> String:
	var name: String = DEVICES[type].name
	match type:
		"hub":
			return "Hub ส่งข้อมูลไปทุกพอร์ตพร้อมกัน ทำให้ข้อมูลชนกันและเครือข่ายช้า %s ควรใช้ %s" % [slot.label, DEVICES[slot.type].name]
		"access_point":
			return "Access Point ใช้กระจายสัญญาณ Wi-Fi แต่ผังนี้เป็นเครือข่ายแบบใช้สาย LAN (%s)" % slot.label
		"server":
			return "Server ไม่ได้อยู่ในโจทย์ห้องเรียนนี้ — %s ต้องใช้ %s" % [slot.label, DEVICES[slot.type].name]
	if slot.type == "router" and type == "switch":
		return "Switch เชื่อมเครื่องภายในวง LAN แต่ออกอินเทอร์เน็ตเองไม่ได้ ช่องนี้ต้องใช้ Router"
	if slot.type == "switch" and type == "router":
		return "Router มีพอร์ต LAN น้อย ไม่พอต่อทุกเครื่อง ศูนย์กลางของ Star ต้องใช้ Switch"
	if slot.type in ["teacher_pc", "student_pc"] and type in ["router", "switch"]:
		return "%s เป็นอุปกรณ์เครือข่าย ไม่ใช่เครื่องผู้ใช้ — %s ต้องใช้ %s" % [name, slot.label, DEVICES[slot.type].name]
	return "%s ไม่ถูกต้อง — %s ต้องใช้ %s" % [name, slot.label, DEVICES[slot.type].name]


func _device_style(type: String, alpha: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var color: Color = DEVICES[type].color
	style.bg_color = Color(color, alpha)
	style.border_color = color.darkened(0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18 if type == "internet" else 6)
	return style


func _create_device(type: String, pos: Vector2) -> Panel:
	var device := Panel.new()
	device.name = "Device_%s_%d" % [type, _canvas.get_child_count()]
	device.set_meta("type", type)
	device.position = pos
	device.size = DEVICES[type].size
	device.add_theme_stylebox_override("panel", _device_style(type))
	device.gui_input.connect(func(e): _on_device_input(device, e))
	device.set_drag_forwarding(Callable(), func(p, d): return _can_drop(device.position + p, d), func(p, d): _drop(device.position + p, d))
	_canvas.add_child(device)

	var text := _label(DEVICES[type].name, 15, COLOR_INK)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	device.add_child(text)

	var layout: Dictionary = PORTS[type]
	for edge in ["top", "bottom"]:
		var names: Array = layout[edge]
		for i in names.size():
			var port := Button.new()
			port.name = "Port_" + names[i]
			port.text = names[i]
			port.set_meta("port", names[i])
			port.focus_mode = Control.FOCUS_NONE
			port.add_theme_font_size_override("font_size", 11)
			port.custom_minimum_size = Vector2(38, 18)
			port.size = Vector2(38, 18)
			var x := device.size.x * (i + 1) / (names.size() + 1) - 19.0
			port.position = Vector2(x, -9.0 if edge == "top" else device.size.y - 9.0)
			port.tooltip_text = "พอร์ต %s ของ %s" % [names[i], DEVICES[type].name]
			port.pressed.connect(func(): _on_port_pressed(device, names[i]))
			device.add_child(port)
	_refresh_ports()
	return device


func _on_device_input(device: Panel, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		remove_device(device)


func remove_device(device: Panel) -> void:
	if stage != Stage.DESIGN or device == internet_node:
		return
	for slot in slots:
		if slot.device == device:
			slot.device = null
	for link in links.duplicate():
		if link.a == device or link.b == device:
			links.erase(link)
	if not _pending.is_empty() and _pending.device == device:
		_pending = {}
	device.queue_free()
	_info("นำ %s ออกแล้ว" % DEVICES[device.get_meta("type")].name)
	_refresh_ports()
	_canvas.queue_redraw()


# ---------------------------------------------------------------- cables

func _link_at(device: Control, port: String) -> Dictionary:
	for link in links:
		if (link.a == device and link.pa == port) or (link.b == device and link.pb == port):
			return link
	return {}


func _on_port_pressed(device: Panel, port: String) -> void:
	if stage != Stage.DESIGN:
		return
	if _pending.is_empty():
		var existing := _link_at(device, port)
		if not existing.is_empty():
			links.erase(existing)
			_info("ถอดสายออกจากพอร์ต %s แล้ว" % port)
		else:
			_pending = {"device": device, "port": port}
			_info("เลือกพอร์ต %s ของ %s แล้ว — คลิกพอร์ตปลายทาง (คลิกขวาที่พื้นที่ว่างเพื่อยกเลิก)" % [port, DEVICES[device.get_meta("type")].name])
	else:
		var from: Panel = _pending.device
		var from_port: String = _pending.port
		_pending = {}
		if from == device and from_port == port:
			_info("ยกเลิกการเชื่อมสาย")
		elif not _link_at(device, port).is_empty():
			_info("พอร์ต %s มีสายเสียบอยู่แล้ว" % port)
		else:
			try_link(from, from_port, device, port)
	_refresh_ports()
	_canvas.queue_redraw()


## Runs a cable between two ports. Returns true when the cable is allowed.
func try_link(a: Panel, pa: String, b: Panel, pb: String) -> bool:
	if stage != Stage.DESIGN:
		return false
	if not _link_at(a, pa).is_empty() or not _link_at(b, pb).is_empty():
		_info("พอร์ตนี้มีสายเสียบอยู่แล้ว")
		return false
	var problem := _link_problem(a, pa, b, pb)
	if problem != "":
		_mistake(problem, PENALTY_LINK)
		return false
	links.append({"a": a, "pa": pa, "b": b, "pb": pb})
	_set_banner("เชื่อมสาย %s (%s) ↔ %s (%s) แล้ว" % [DEVICES[a.get_meta("type")].name, pa, DEVICES[b.get_meta("type")].name, pb], COLOR_GOOD)
	_refresh_ports()
	_canvas.queue_redraw()
	return true


## Orders two port ends so the first has type t1; returns [] if the types differ.
func _pair(a: Dictionary, b: Dictionary, t1: String, t2: Array) -> Array:
	if a.t == t1 and b.t in t2:
		return [a, b]
	if b.t == t1 and a.t in t2:
		return [b, a]
	return []


func _link_problem(da: Panel, pa: String, db: Panel, pb: String) -> String:
	if da == db:
		return "ต่อสายจากอุปกรณ์เข้าตัวเองไม่ได้"
	var a := {"t": da.get_meta("type"), "p": pa}
	var b := {"t": db.get_meta("type"), "p": pb}
	var pcs := ["teacher_pc", "student_pc"]

	var p := _pair(a, b, "internet", ["router"])
	if p:
		return "" if p[1].p == "WAN" else "เสียบผิดพอร์ต — สายจากอินเทอร์เน็ต (ISP) ต้องเข้าพอร์ต WAN ของ Router ไม่ใช่พอร์ต LAN"
	if a.t == "internet" or b.t == "internet":
		return "อินเทอร์เน็ตต้องต่อเข้า Router ก่อนเสมอ เพราะ Router ทำหน้าที่เชื่อมเครือข่ายภายในกับภายนอก"
	p = _pair(a, b, "router", ["switch"])
	if p:
		if p[0].p == "WAN":
			return "เสียบผิดพอร์ต — พอร์ต WAN ของ Router ใช้ต่ออินเทอร์เน็ต ให้ใช้พอร์ต LAN ต่อไปยัง Switch"
		if p[1].p != "Uplink":
			return "เสียบผิดพอร์ต — สายจาก Router ต้องเข้าพอร์ต Uplink ของ Switch (พอร์ต 1–7 ใช้ต่อเครื่องคอมพิวเตอร์)"
		return ""
	p = _pair(a, b, "switch", pcs)
	if p:
		if p[0].p == "Uplink":
			return "เสียบผิดพอร์ต — พอร์ต Uplink ใช้ต่อกับ Router ให้เสียบเครื่องคอมพิวเตอร์ที่พอร์ต 1–7"
		return ""
	if _pair(a, b, "router", pcs):
		return "ใน Star Topology เครื่องคอมทุกเครื่องต้องต่อเข้า Switch ซึ่งเป็นศูนย์กลาง ไม่ใช่ต่อตรงเข้า Router"
	if a.t in pcs and b.t in pcs:
		return "การต่อเครื่องคอมถึงกันโดยตรงไม่ใช่ Star Topology — ทุกเครื่องต้องต่อผ่าน Switch"
	return "การเชื่อมต่อนี้ไม่ตรงกับโครงสร้าง Internet → Router → Switch → เครื่องคอมพิวเตอร์"


func _refresh_ports() -> void:
	for device in _canvas.get_children():
		for child in device.get_children():
			if not child is Button:
				continue
			var port: String = child.get_meta("port")
			var color := Color(0.35, 0.38, 0.45)
			if not _link_at(device, port).is_empty():
				color = COLOR_GOOD
			if not _pending.is_empty() and _pending.device == device and _pending.port == port:
				color = Color(0.95, 0.7, 0.1)
			var style := StyleBoxFlat.new()
			style.bg_color = color
			style.set_corner_radius_all(3)
			child.add_theme_stylebox_override("normal", style)
			var hover := style.duplicate()
			hover.bg_color = color.lightened(0.25)
			child.add_theme_stylebox_override("hover", hover)
			child.add_theme_stylebox_override("pressed", hover)
			child.add_theme_color_override("font_color", Color.WHITE)


func _port_point(device: Control, port: String) -> Vector2:
	var button := device.get_node_or_null("Port_" + port) as Control
	if button == null:
		return device.position
	return device.position + button.position + button.size * 0.5


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not _pending.is_empty():
		_pending = {}
		_info("ยกเลิกการเชื่อมสาย")
		_refresh_ports()
		_canvas.queue_redraw()


func _draw_canvas() -> void:
	var c := _canvas
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.93, 0.95, 0.97))
	for x in range(0, int(c.size.x), 24):
		for y in range(0, int(c.size.y), 24):
			c.draw_rect(Rect2(x, y, 1.5, 1.5), Color(0.75, 0.79, 0.85))
	var font := ThemeDB.fallback_font
	for slot in slots:
		var rect: Rect2 = slot.rect
		if slot.device == null:
			_draw_dashed_rect(c, rect, Color(0.45, 0.55, 0.7))
			c.draw_string(font, rect.position + Vector2(6, rect.size.y * 0.5 + 6), slot.label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12, 13, Color(0.4, 0.48, 0.6))
	for i in links.size():
		var link: Dictionary = links[i]
		_draw_cable(c, _port_point(link.a, link.pa), _port_point(link.b, link.pb), Color(0.12, 0.55, 0.28), i)
	if not _pending.is_empty():
		c.draw_line(_port_point(_pending.device, _pending.port), c.get_local_mouse_position(), Color(0.95, 0.65, 0.1), 3.0)


func _draw_cable(c: Control, from: Vector2, to: Vector2, color: Color, index: int = 0) -> void:
	var top := from if from.y < to.y else to
	var bottom := to if from.y < to.y else from
	# Each cable turns at its own height so parallel cables do not overlap.
	var gap := bottom.y - top.y
	var mid_y := top.y + gap * 0.5
	if gap > 30.0:
		mid_y = top.y + 14.0 + float(index % 6) * minf(6.0, (gap - 28.0) / 6.0)
	c.draw_polyline(PackedVector2Array([top, Vector2(top.x, mid_y), Vector2(bottom.x, mid_y), bottom]), color, 3.0, true)


func _draw_dashed_rect(c: Control, rect: Rect2, color: Color) -> void:
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]
	for i in 4:
		c.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 8.0)


# ================================================================ stage 3: check

## Checks the whole design. Returns the list of problems (empty = success).
func check_answer() -> PackedStringArray:
	var problems := PackedStringArray()
	if stage != Stage.DESIGN:
		return problems

	var students := 0
	for slot in slots:
		if slot.device == null:
			problems.append("ยังไม่ได้วาง %s ใน%s" % [DEVICES[slot.type].name, slot.label])
		elif slot.device.get_meta("type") == "student_pc":
			students += 1
	if students != STUDENT_COUNT:
		problems.append("จำนวนเครื่องนักเรียนต้องมี %d เครื่อง (ตอนนี้มี %d)" % [STUDENT_COUNT, students])

	var router: Panel = get_slot("router").device
	var switch: Panel = get_slot("switch").device
	if router and not _connected(internet_node, "ISP", router, "WAN"):
		problems.append("ยังไม่ได้ต่อสายจาก Internet เข้าพอร์ต WAN ของ Router")
	if router and switch and not (_connected(router, "LAN1", switch, "Uplink") or _connected(router, "LAN2", switch, "Uplink")):
		problems.append("ยังไม่ได้ต่อสายจากพอร์ต LAN ของ Router เข้าพอร์ต Uplink ของ Switch")
	for slot in slots:
		if slot.type in ["teacher_pc", "student_pc"] and slot.device and switch:
			var link := _link_at(slot.device, "LAN")
			var other: Variant = null
			if not link.is_empty():
				other = link.b if link.a == slot.device else link.a
			if other != switch:
				problems.append("%s ยังไม่ได้ต่อสายเข้า Switch" % slot.label.replace("ช่อง", ""))

	design_checked.emit(problems)
	if problems.is_empty():
		_finish()
	else:
		score = maxi(0, score - PENALTY_FAILED_CHECK)
		mistakes += 1
		_update_header()
		var shown := problems.slice(0, 3)
		var more := "" if problems.size() <= 3 else " (และอีก %d ข้อ)" % (problems.size() - 3)
		_set_banner("ยังไม่ถูกต้อง (−%d คะแนน): %s%s" % [PENALTY_FAILED_CHECK, " • ".join(shown), more], COLOR_BAD)
		mistake_made.emit("ตรวจคำตอบไม่ผ่าน", PENALTY_FAILED_CHECK)
	return problems


func _connected(a: Control, pa: String, b: Control, pb: String) -> bool:
	for link in links:
		if (link.a == a and link.pa == pa and link.b == b and link.pb == pb) or (link.a == b and link.pa == pb and link.b == a and link.pb == pa):
			return true
	return false


func _finish() -> void:
	stage = Stage.DONE
	_finish_msec = Time.get_ticks_msec()
	elapsed_seconds = (_finish_msec - _start_msec) / 1000.0
	_result_text.text = "คะแนน %d / %d\nเวลาที่ใช้ %s\nทำผิด %d ครั้ง" % [score, START_SCORE, format_time(elapsed_seconds), mistakes]
	_set_banner("ผังเครือข่ายถูกต้อง: Internet → Router → Switch → เครื่องครูและเครื่องนักเรียน", COLOR_GOOD)
	_show_page(_result_page)
	completed.emit(score, elapsed_seconds, mistakes)


func _build_result_page() -> void:
	_result_page = CenterContainer.new()
	_result_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pages.add_child(_result_page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_result_page.add_child(box)
	var title := _label("ภารกิจสำเร็จ", 44, COLOR_GOOD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_result_text = _label("", 22, COLOR_INK)
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_text)
	var close := Button.new()
	close.text = "ปิดโปรแกรม"
	close.custom_minimum_size = Vector2(220, 46)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(func(): close_requested.emit())
	box.add_child(close)
	var hint := _label("กด Esc หรือ เริ่ม → ปิดเครื่อง เพื่อลุกจากคอมพิวเตอร์", 15, Color(0.4, 0.45, 0.52))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


# ================================================================ helpers

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
