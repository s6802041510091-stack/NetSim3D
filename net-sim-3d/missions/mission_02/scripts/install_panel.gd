class_name InstallPanel
extends CanvasLayer

## Installing the two cables at the open wall rack (right side of the screen):
##   1. cable 1 into a Router port: WAN or LAN 1-4 (decision E, once)
##   2. its other end into Switched Hub port 1
##   3. cable 2 into Switched Hub port 2
##   4. run cable 2 along the cable route to the teacher's PC
## and later, after plugging the PC, looking at the switch's port LEDs.
## Plugging is by hand (PlugBoard): for each step one RJ45 head waits in
## front of the rack with its cable coming up from below; the player drags
## it into a port. Only the ports the step allows take it (any Router port
## for cable 1 - that is the decision; switch port 1, then 2). Q / E: the
## whole rack, the Router close up, switch ports 1-12 close up. Running
## cable 2 down to the teacher's PC follows by itself.
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
	"router": "สายเส้นที่ 1 (Router → Switched Hub) — ลากหัวสายไปเสียบพอร์ตของ Router ที่ถูกต้อง (เสียบได้ครั้งเดียว)\nกด Q / E เพื่อเปลี่ยนมุมมอง",
	"switch1": "ลากหัวอีกด้านของสายเส้นที่ 1 ไปเสียบพอร์ต 1 ของ Switched Hub 24 Port ตามใบงาน\nกด Q / E เพื่อเปลี่ยนมุมมอง",
	"switch2": "ลากหัวด้านหนึ่งของสายเส้นที่ 2 (Switched Hub → คอมพิวเตอร์ครู) ไปเสียบพอร์ต 2\nกด Q / E เพื่อเปลี่ยนมุมมอง",
	"route": "กำลังเดินสายเส้นที่ 2 ลงตามผนังและใต้โต๊ะครู ไปยังด้านหลังคอมพิวเตอร์ครู",
}
const ROUTER_PORTS := [["router_wan", "WAN"], ["router_lan1", "LAN 1"], ["router_lan2", "LAN 2"], ["router_lan3", "LAN 3"], ["router_lan4", "LAN 4"]]

var step_index := 0
var mode := "rack" # "rack" or "leds"
var rack: WallRack9U
## Dragging the heads into the rack's ports.
var board: PlugBoard
## Where the dragged heads move: this far in front of the rack's back (m).
const DRAG_Z := 0.18
const CABLE_COLOR := Color(0.16, 0.42, 0.85)
## Seconds before cable 2 is run down to the PC after it is plugged.
const ROUTE_DELAY := 0.6
var router_port := ""
var _temp: Node3D
var _head: Node3D

var _title: Label
## The step panel on the right (foldable).
var side_panel: SidePanel
var _steps_box: VBoxContainer
var _action_box: VBoxContainer


func _ready() -> void:
	layer = 22
	visible = false
	# Narrow and foldable, so it covers less of the view (SidePanel).
	side_panel = SidePanel.new()
	side_panel.name = "InstallPanel"
	add_child(side_panel)
	var col := side_panel.body
	_title = side_panel.title
	_title.text = "ติดตั้งสาย LAN ที่ Wall Rack"
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


func setup(wall_rack: WallRack9U) -> void:
	rack = wall_rack
	board = PlugBoard.new()
	board.name = "RackPlugBoard"
	board.glow_size = Vector3(0.016, 0.013, 0.008)
	add_child(board)
	board.plugged.connect(_on_head_in)
	board.plug_moved.connect(func(_id: String): _rebuild_tail())
	board.all_plugged.connect(_on_head_done)


func open(new_mode: String) -> void:
	mode = new_mode
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	if mode == "rack":
		_start_step(false)


func close() -> void:
	visible = false
	if board:
		board.end()
	_clear_head()


## Q / E views at the rack.
func rack_views() -> Array:
	var routers := ["router_wan", "router_lan1", "router_lan2", "router_lan3", "router_lan4"]
	var switches := []
	for i in 12:
		switches.append("switch_%02d" % (i + 1))
	return [
		{"name": "ภาพรวมตู้ Rack", "xform": rack.view_transform()},
		{"name": "Router (WAN / LAN 1–4)", "xform": rack.close_view(routers, 0.17)},
		{"name": "Switched Hub พอร์ต 1–12", "xform": rack.close_view(switches, 0.15)},
	]


## Ports the current step's head may go into.
func allowed_ports() -> PackedStringArray:
	match current_step():
		"router":
			return PackedStringArray(["router_wan", "router_lan1", "router_lan2", "router_lan3", "router_lan4"])
		"switch1":
			return PackedStringArray(["switch_01"])
		"switch2":
			return PackedStringArray(["switch_02"])
	return PackedStringArray()


## The head of this step waiting in front of the rack (rack space).
func _home() -> Vector3:
	match current_step():
		"router":
			# Beside the router on the left, level with its ports (below it the shelf hides it).
			return Vector3(rack.port_local("router_wan").x - 0.03, WallRack9U.ROUTER_Y, DRAG_Z)
		"switch1":
			return Vector3(rack.port_local("switch_01").x - 0.015, WallRack9U.SWITCH_Y - 0.038, DRAG_Z)
		_:
			return Vector3(rack.port_local("switch_02").x + 0.025, WallRack9U.SWITCH_Y - 0.038, DRAG_Z)


func _start_step(keep_view: bool) -> void:
	if rack == null or not visible or not current_step() in ["router", "switch1", "switch2"]:
		return
	_clear_head()
	_temp = Node3D.new()
	_temp.name = "InstallTemp"
	rack.add_child(_temp)
	_head = PlugBoard.make_head(CABLE_COLOR)
	_head.name = "Head"
	_head.position = _home()
	_temp.add_child(_head)
	var sockets := {}
	for id in allowed_ports():
		sockets[id] = rack.port_socket(id)
	board.drag_plane = Plane(rack.global_basis.z.normalized(), rack.global_transform * Vector3(0, 0, DRAG_Z))
	board.hint = "ลากหัว RJ45 ไปเสียบที่พอร์ต" + ("ของ Router" if current_step() == "router" else " %d ของ Switched Hub" % (1 if current_step() == "switch1" else 2))
	board.begin(get_viewport().get_camera_3d(), rack_views(), {"head": _head}, sockets, PackedStringArray(), keep_view)
	_rebuild_tail()


## The cable behind the waiting head: from below the rack (cable 1's first
## end, cable 2), or from the Router port cable 1 went into.
func _rebuild_tail() -> void:
	if _temp == null or _head == null:
		return
	var old := _temp.get_node_or_null("Tail")
	if old:
		old.free()
	var h := _head.transform
	var points := [h * Vector3(0, 0, 0.033), h * Vector3(0, -0.01, 0.07)]
	match current_step():
		"router":
			points.append_array([Vector3(h.origin.x, -0.2, DRAG_Z + 0.03), Vector3(h.origin.x, -0.6, DRAG_Z + 0.03)])
		"switch1":
			var r := rack.port_local(router_port)
			points.append_array([r + Vector3(0, -0.012, 0.06), r + Vector3(0, 0, 0.034)])
		_:
			points.append_array([Vector3(0.262, WallRack9U.SWITCH_Y - 0.04, 0.19), Vector3(0.262, -0.2, 0.12), Vector3(0.262, -0.6, 0.12)])
	_temp.add_child(CableBuilder.build(points, CABLE_COLOR, "Tail", 0.003))


func _clear_head() -> void:
	if _temp:
		_temp.queue_free()
	_temp = null
	_head = null


## The Internet line pops out the moment a head is pushed into WAN.
func _on_head_in(_plug: String, socket: String) -> void:
	if socket == "router_wan" and rack.is_internet_connected():
		rack.disconnect_internet()


## The head is in (and a second has passed): the rack draws the real plug.
func _on_head_done() -> void:
	var port: String = board.connected.keys()[0] if not board.connected.is_empty() else ""
	board.end(true)
	_clear_head()
	if current_step() == "router":
		router_port = port
		_finish_step(port)
	else:
		_finish_step("")
	if current_step() == "route":
		await get_tree().create_timer(ROUTE_DELAY).timeout
		if current_step() == "route":
			_finish_step("")
	else:
		_start_step(true)


func rack_finished() -> bool:
	return step_index >= RACK_STEPS.size()


func current_step() -> String:
	return "" if rack_finished() else RACK_STEPS[step_index]


## Pushes the waiting head into `port_id` (what a drop on it does; tests).
func plug_head(port_id: String) -> bool:
	return board != null and board.active and board.plug_into("head", port_id)


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


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		leave_requested.emit()
