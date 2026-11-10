class_name TesterPanel
extends CanvasLayer

## Testing the two crimped cables with the LAN cable tester (right side of the
## screen, the tester in close-up on the left). For each cable: plug both
## ends into the main and remote units -> power on -> TEST (the LEDs scan
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
	"plug": "เสียบหัวสายด้านหนึ่งเข้าตัวแม่ (MAIN) และอีกด้านเข้าตัวลูก (REMOTE)",
	"power": "กดปุ่ม POWER เพื่อเปิดเครื่องทดสอบ",
	"test": "กดปุ่ม TEST แล้วสังเกตไฟของตัวแม่และตัวลูก",
	"verdict": "ดูไฟของตัวแม่ (MAIN) เทียบกับตัวลูก (REMOTE) ให้ครบทุกดวง แล้วตัดสินว่าสายเส้นนี้ใช้งานได้หรือไม่ (ตัดสินได้ครั้งเดียว)",
}

var station: CrimpStation
var state: Mission02State
var cable := 1
var step_index := 0
var message := ""

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


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	station.show_tester()
	_sync_desk()
	_refresh()


func close() -> void:
	visible = false


func is_done() -> bool:
	return cable > 2


func current_step() -> String:
	return "" if is_done() else STEPS[step_index]


## Plug / power / test (the one-button steps).
func do_step() -> void:
	var step := current_step()
	var tester := station.tester
	match step:
		"plug":
			station.plug_test_cable(true)
			Sound.play("select")
		"power":
			tester.set_power(true)
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


func _sync_desk() -> void:
	# Coming back mid-way: show the cable / power as they were left.
	var tester := station.tester
	station.plug_test_cable(step_index >= 1 and not is_done())
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
	else:
		var go := GameUI.button(STEP_TITLES[step], true, 240)
		go.name = "StepButton"
		go.set_meta("sound", "")
		go.pressed.connect(do_step)
		_action_box.add_child(go)


func _message_label() -> Label:
	var l := GameUI.label(message, 15, GameUI.ACCENT.darkened(0.2), true)
	l.name = "Message"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		leave_requested.emit()
