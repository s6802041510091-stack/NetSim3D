class_name TesterPanel
extends CanvasLayer

## Testing the two crimped cables with the LAN cable tester (right side of the
## screen, the tester in close-up on the left). For each cable: plug both
## ends into the main and remote units by hand (drag each RJ45 head into a
## socket; Q / E switch between the whole tester and each socket close up;
## PlugBoard) -> click POWER on the tester itself -> click TEST on it (the LEDs scan
## pins 1-8 and G for as long as the player watches) -> decide once:
## "ผ่าน" (use it) or "ใช้ไม่ได้" (discard). The LEDs follow the real wire
## order of both ends (Mission02State.tester_mapping).
## Feedback after the decision (ภารกิจ/ด่าน_02/README.md):
##   bad + discard -> the supervisor sends a ready-made spare cable
##   good + discard -> "the LEDs all match, this cable works", keep it
##   either + pass -> recorded, go on

signal leave_requested
signal cable_judged(cable: int, passes: bool)
signal all_done

const STEPS := ["plug", "power", "test", "verdict"]
const STEP_TITLES := {"plug": "เสียบสาย", "power": "เปิดเครื่อง", "test": "กดปุ่ม TEST", "verdict": "ตัดสินผล"}
const STEP_HELP := {
	"plug": "ลากหัว RJ45 ด้านหนึ่งไปเสียบช่องตัวแม่ (MAIN) และอีกด้านเสียบช่องตัวลูก (REMOTE)\nกด Q / E เพื่อเปลี่ยนมุมมองไปดูช่องใกล้ ๆ",
	"power": "คลิกปุ่ม POWER (สีแดง) บนตัวเครื่องเพื่อเปิดเครื่องทดสอบ",
	"test": "คลิกปุ่ม TEST (สีเหลือง) บนตัวเครื่อง แล้วสังเกตไฟของตัวแม่และตัวลูก",
	"verdict": "ดูไฟของตัวแม่ (MAIN) เทียบกับตัวลูก (REMOTE) ให้ครบทุกดวง แล้วตัดสินว่าสายเส้นนี้ใช้งานได้หรือไม่ (ตัดสินได้ครั้งเดียว)",
}

var station: CrimpStation
var state: Mission02State
var cable := 1
var step_index := 0
var message := ""
## Clicking the tester's own buttons: how close (px) the mouse must be to a
## button's centre, and which one it is over now.
const BUTTON_PX := 26.0
var hovered_button := ""

var _title: Label
var _subtitle: Label
var _steps_box: VBoxContainer
var _action_box: VBoxContainer
var _leave: Button


func _ready() -> void:
	layer = 22
	visible = false
	var panel := PanelContainer.new()
	panel.name = "TesterPanel"
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
	_title = GameUI.label("ตรวจสายด้วย LAN Cable Tester", 21, GameUI.INK, true)
	col.add_child(_title)
	_subtitle = GameUI.label("", 15, GameUI.INK_SOFT)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_subtitle)
	col.add_child(HSeparator.new())
	_steps_box = VBoxContainer.new()
	_steps_box.add_theme_constant_override("separation", 2)
	col.add_child(_steps_box)
	col.add_child(HSeparator.new())
	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 10)
	_action_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_action_box)
	_leave = GameUI.button("ลุกจากโต๊ะ (Esc)", false, 200)
	_leave.name = "LeaveButton"
	_leave.set_meta("sound", "back")
	_leave.pressed.connect(func(): leave_requested.emit())
	col.add_child(_leave)


func setup(desk: CrimpStation, mission_state: Mission02State) -> void:
	station = desk
	state = mission_state
	station.plug_board.all_plugged.connect(_on_all_plugged)


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	station.show_tester()
	_sync_desk()
	_refresh()


func close() -> void:
	visible = false
	if station and station.tester:
		_set_hover("")
	if station:
		station.plug_board.end()


func is_done() -> bool:
	return cable > 2


func current_step() -> String:
	return "" if is_done() else STEPS[step_index]


## Power / test (plugging is done by hand, see _start_plugging).
func do_step() -> void:
	var step := current_step()
	var tester := station.tester
	match step:
		"power":
			tester.press_power()
			Sound.play("toggle_on")
		"test":
			tester.press_test(state.tester_mapping(cable))
			Sound.play("click")
		_:
			return
	message = ""
	step_index += 1
	_refresh()


## The one decision per cable.
func judge(passes: bool) -> void:
	if current_step() != "verdict" or not state.set_verdict(cable, passes):
		return
	var good := state.cable_good(cable)
	if not passes and not good:
		message = "สายเส้นที่ %d ถูกทิ้งไป — หัวหน้างานส่งสายสำเร็จรูปสำรองมาให้แทน เพื่อนำไปติดตั้งให้เสร็จ" % cable
	elif not passes and good:
		message = "ตรวจดูอีกครั้ง: ไฟของตัวแม่กับตัวลูกติดตรงกันครบทุกดวง สายเส้นที่ %d ใช้งานได้ จึงใช้สายเส้นนี้ต่อ" % cable
	else:
		message = "บันทึกผล: สายเส้นที่ %d ผ่าน" % cable
	Sound.play("confirm")
	cable_judged.emit(cable, passes)
	station.tester.set_power(false)
	station.plug_test_cable(false)
	cable += 1
	step_index = 0
	_refresh()
	if is_done():
		all_done.emit()
	else:
		_start_plugging()


## The plug step: the heads lie on the mat, the player drags them in.
func _start_plugging() -> void:
	if current_step() != "plug" or not visible:
		return
	station.plug_test_cable(true, false)
	var camera := get_viewport().get_camera_3d()
	station.plug_board.begin(camera, station.tester_views(), station.test_heads(), station.tester_sockets())


## Both heads in (and a second to look at them): back to the whole tester.
func _on_all_plugged() -> void:
	if current_step() != "plug":
		return
	station.plug_board.go_to_view(0)
	station.plug_board.end(true)
	message = ""
	step_index += 1
	_refresh()


func _sync_desk() -> void:
	# Coming back mid-way: show the cable / power as they were left.
	var tester := station.tester
	station.plug_test_cable(step_index >= 1 and not is_done())
	if step_index == 0 and not is_done():
		_start_plugging()
	tester.set_power(step_index >= 2 and not is_done())
	if step_index >= 3 and not is_done():
		tester.press_test(state.tester_mapping(cable))


func _refresh() -> void:
	for child in _steps_box.get_children():
		child.queue_free()
	for child in _action_box.get_children():
		child.queue_free()
	if is_done():
		_subtitle.text = "ตรวจครบทั้ง 2 เส้นแล้ว"
		if message != "":
			_action_box.add_child(_message_label())
		return
	_subtitle.text = "สายเส้นที่ %d จาก 2: %s" % [cable, CrimpPanel.CABLES[cable][0]]
	for i in STEPS.size():
		var color := GameUI.OK if i < step_index else (GameUI.ACCENT if i == step_index else GameUI.INK_SOFT)
		_steps_box.add_child(GameUI.label(("%d. " % (i + 1)) + STEP_TITLES[STEPS[i]] + ("  (เสร็จ)" if i < step_index else ""), 15, color, i == step_index))
	if message != "":
		_action_box.add_child(_message_label())
	var step := current_step()
	var help := GameUI.label(STEP_HELP[step], 16, GameUI.INK)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_box.add_child(help)
	if step == "verdict":
		var pass_button := GameUI.button("ผ่าน — ใช้งานได้", true, 300)
		pass_button.name = "PassButton"
		pass_button.set_meta("sound", "")
		pass_button.pressed.connect(judge.bind(true))
		_action_box.add_child(pass_button)
		var fail_button := GameUI.button("ไม่ผ่าน — ใช้ไม่ได้ ต้องทิ้ง", false, 300)
		fail_button.name = "DiscardButton"
		fail_button.set_meta("sound", "")
		fail_button.pressed.connect(judge.bind(false))
		_action_box.add_child(fail_button)


func _message_label() -> Label:
	var l := GameUI.label(message, 15, GameUI.ACCENT.darkened(0.2), true)
	l.name = "Message"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		leave_requested.emit()
		return
	if current_step() in ["", "plug"] or station == null or station.tester == null:
		return
	if event is InputEventMouseMotion:
		_set_hover(button_at((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var which := button_at((event as InputEventMouseButton).position)
		if which != "":
			get_viewport().set_input_as_handled()
			press_button(which)


## The tester button ("power" / "test") at screen point `at`, "" if none.
func button_at(at: Vector2) -> String:
	var camera := get_viewport().get_camera_3d()
	if camera == null or station.tester == null:
		return ""
	for which in ["power", "test"]:
		var mesh := station.tester.button(which)
		if mesh and not camera.is_position_behind(mesh.global_position) and camera.unproject_position(mesh.global_position).distance_to(at) <= BUTTON_PX:
			return which
	return ""


## What clicking a button on the tester does. The right button for the step
## moves on; TEST with the power off only clicks (no lights, like the real
## device) and says why; POWER once it is on does nothing more.
func press_button(which: String) -> void:
	var step := current_step()
	if (which == "power" and step == "power") or (which == "test" and step in ["test", "verdict"]):
		if step == "verdict":
			station.tester.press_test(state.tester_mapping(cable))
			Sound.play("click")
		else:
			do_step()
		return
	station.tester.tap(which)
	Sound.play("click")
	if which == "test" and not station.tester.is_on:
		message = "กด TEST แล้วไม่มีไฟขึ้น — เครื่องยังไม่ได้เปิด"
		_refresh()


func _set_hover(which: String) -> void:
	if which == hovered_button:
		return
	hovered_button = which
	station.tester.set_button_hover(which)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if which != "" else Input.CURSOR_ARROW)
