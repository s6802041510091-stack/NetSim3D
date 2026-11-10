class_name InstallPanel
extends CanvasLayer

## Installing the two cables at the open wall rack (right side of the screen):
##   1. cable 1 into a Router port: WAN or LAN 1-4 (decision E, once)
##   2. its other end into Switched Hub port 1
##   3. cable 2 into Switched Hub port 2
##   4. run cable 2 along the cable route to the teacher's PC
## and later, after plugging the PC, looking at the switch's port LEDs.
## The controller does the wiring when `step_done` fires.

signal step_done(step: String, value: String)
signal rack_done
signal leds_checked
signal leave_requested

const RACK_STEPS := ["router", "switch1", "switch2", "route"]
const TITLES := {
	"router": "เสียบสายเส้นที่ 1 เข้า Router",
	"switch1": "เสียบปลายอีกด้านเข้า Switched Hub พอร์ต 1",
	"switch2": "เสียบสายเส้นที่ 2 เข้า Switched Hub พอร์ต 2",
	"route": "เดินสายเส้นที่ 2 ไปยังคอมพิวเตอร์ครู",
}
const HELP := {
	"router": "สายเส้นที่ 1 (Router → Switched Hub) — เลือกพอร์ตของ Router ที่จะเสียบ (เลือกได้ครั้งเดียว)",
	"switch1": "เสียบหัวอีกด้านของสายเส้นที่ 1 เข้าพอร์ต 1 ของ Switched Hub 24 Port ตามใบงาน",
	"switch2": "เสียบหัวด้านหนึ่งของสายเส้นที่ 2 (Switched Hub → คอมพิวเตอร์ครู) เข้าพอร์ต 2",
	"route": "เดินสายเส้นที่ 2 ลงตามผนังและใต้โต๊ะครู ตามเส้นทางเดินสายที่กำหนดไว้ ไปยังด้านหลังคอมพิวเตอร์ครู",
}
const ROUTER_PORTS := [["router_wan", "WAN"], ["router_lan1", "LAN 1"], ["router_lan2", "LAN 2"], ["router_lan3", "LAN 3"], ["router_lan4", "LAN 4"]]

var step_index := 0
var mode := "rack" # "rack" or "leds"

var _title: Label
var _steps_box: VBoxContainer
var _action_box: VBoxContainer


func _ready() -> void:
	layer = 22
	visible = false
	var panel := PanelContainer.new()
	panel.name = "InstallPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470
	panel.offset_right = -14
	panel.offset_top = 14
	panel.offset_bottom = -14
	panel.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1, 0.97), Color(0.8, 0.83, 0.88), 12, 20, 16))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_title = GameUI.label("ติดตั้งสาย LAN ที่ Wall Rack", 21, GameUI.INK, true)
	col.add_child(_title)
	col.add_child(HSeparator.new())
	_steps_box = VBoxContainer.new()
	_steps_box.add_theme_constant_override("separation", 2)
	col.add_child(_steps_box)
	col.add_child(HSeparator.new())
	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 10)
	_action_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_action_box)
	var leave := GameUI.button("ออกจากตู้ (Esc)", false, 200)
	leave.name = "LeaveButton"
	leave.set_meta("sound", "back")
	leave.pressed.connect(func(): leave_requested.emit())
	col.add_child(leave)


func open(new_mode: String) -> void:
	mode = new_mode
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false


func rack_finished() -> bool:
	return step_index >= RACK_STEPS.size()


func current_step() -> String:
	return "" if rack_finished() else RACK_STEPS[step_index]


## Router port for cable 1 (the decision).
func choose_router_port(port_id: String) -> void:
	if current_step() != "router":
		return
	_finish_step(port_id)


## The one-button rack steps.
func do_step() -> void:
	var step := current_step()
	if step == "" or step == "router":
		return
	_finish_step("")


func confirm_leds() -> void:
	if mode != "leds":
		return
	Sound.play("confirm")
	leds_checked.emit()


func _finish_step(value: String) -> void:
	var step := current_step()
	Sound.play("crimp" if step != "route" else "click")
	step_done.emit(step, value)
	step_index += 1
	_refresh()
	if rack_finished():
		rack_done.emit()


func _refresh() -> void:
	for child in _steps_box.get_children():
		child.queue_free()
	for child in _action_box.get_children():
		child.queue_free()
	if mode == "leds":
		_title.text = "ตรวจไฟสถานะพอร์ต"
		_steps_box.add_child(GameUI.label("ดูไฟ Link ของพอร์ตที่ใช้งาน", 15, GameUI.ACCENT, true))
		var help := GameUI.label("สังเกตไฟสถานะ (Link) ของ Switched Hub พอร์ต 1 และ 2 และพอร์ตของ Router ที่เสียบสายไว้ ไฟเขียวติดแสดงว่ามีการเชื่อมต่อ", 16, GameUI.INK)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action_box.add_child(help)
		var ok := GameUI.button("ตรวจแล้ว", true, 240)
		ok.name = "LedsCheckedButton"
		ok.set_meta("sound", "")
		ok.pressed.connect(confirm_leds)
		_action_box.add_child(ok)
		return
	_title.text = "ติดตั้งสาย LAN ที่ Wall Rack"
	for i in RACK_STEPS.size():
		var color := GameUI.OK if i < step_index else (GameUI.ACCENT if i == step_index else GameUI.INK_SOFT)
		_steps_box.add_child(GameUI.label(("%d. " % (i + 1)) + TITLES[RACK_STEPS[i]] + ("  (เสร็จ)" if i < step_index else ""), 15, color, i == step_index))
	var step := current_step()
	if step == "":
		_action_box.add_child(GameUI.label("ติดตั้งที่ตู้เรียบร้อยแล้ว ต่อไปไปเสียบสายที่คอมพิวเตอร์ครู", 16, GameUI.OK, true))
		return
	var help := GameUI.label(HELP[step], 16, GameUI.INK)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_box.add_child(help)
	if step == "router":
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_action_box.add_child(grid)
		for entry in ROUTER_PORTS:
			var b := GameUI.button(entry[1], false, 128)
			b.name = "Port_" + entry[0]
			b.set_meta("sound", "")
			b.pressed.connect(choose_router_port.bind(entry[0]))
			grid.add_child(b)
	else:
		var go := GameUI.button(TITLES[step], true, 380)
		go.name = "StepButton"
		go.set_meta("sound", "")
		go.pressed.connect(do_step)
		_action_box.add_child(go)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		leave_requested.emit()
