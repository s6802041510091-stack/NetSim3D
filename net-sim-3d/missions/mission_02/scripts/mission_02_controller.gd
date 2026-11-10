class_name Mission02Controller
extends Node

## Runs Level 2 in the school map (added by GameFlow.configure_level):
##   1. talk to the Data Center supervisor -> "ได้รับภารกิจ", the timer starts
##   2. the work order: cable type for the 2 connection points (once)
##   3. pick up the 5 items on the spare desk in the IT Support room
##   4. crimp 4 ends at the desk (CrimpPanel), test both cables (TesterPanel)
##   5. install at the wall rack and the teacher PC, check the port LEDs
##   6. report to the supervisor -> score (Mission02State) -> summary
## Rules (ภารกิจ/ด่าน_02/README.md): every step once, no retries.

signal briefed
signal cable_types_chosen
signal tools_gathered
signal installed
signal finished(score: MissionScore)
signal replay_requested
signal menu_requested
signal next_requested

const LEVEL := 2
const SUPERVISOR := "หัวหน้างาน Data Center"

## "**...**" marks the important words, shown in gold by DialogueBox.
const BRIEFING := [
	"หัวหน้างาน Data Center|แบบอุปกรณ์ของห้องคอมใหม่ผ่านแล้ว ทีมติดตั้ง**Router** กับ **Switched Hub 24 Port** ไว้ใน Wall Rack ให้แล้ว ขั้นต่อไปเราต้อง**เตรียมสาย LAN**สำหรับติดตั้ง",
	"หัวหน้างาน Data Center|ใบงานนี้มีจุดเชื่อมต่อ **2 จุด** คือ **Router กับ Switched Hub** และ **Switched Hub กับคอมพิวเตอร์ครู** เลือกชนิดสายให้เหมาะกับแต่ละจุด แล้วเข้าหัวสายตามมาตรฐาน **T568B**",
	"หัวหน้างาน Data Center|อุปกรณ์อยู่บน**โต๊ะว่างในห้องนี้** หยิบให้ครบ แล้วตรวจสายด้วย **LAN Cable Tester** ให้เรียบร้อยก่อนนำไปติดตั้งที่ห้องคอม",
	"หัวหน้างาน Data Center|สายกับหัว RJ45 มีจำกัด งานนี้**ทำได้ครั้งเดียว** ค่อย ๆ ทำให้ถูกตั้งแต่แรกนะ",
	"คุณ|รับทราบครับ ผมจะเลือกสาย เข้าหัว ตรวจสอบ และนำสายไปเชื่อมต่อให้ถูกต้อง",
]
const GATHER_REMINDER := [
	"หัวหน้างาน Data Center|อุปกรณ์อยู่บน**โต๊ะว่างในห้องนี้** หยิบให้ครบ **5 อย่าง**ก่อนนะ",
]
const NEXT_REMINDER := [
	"หัวหน้างาน Data Center|อุปกรณ์ครบแล้ว ทำงานตามใบงานต่อได้เลย",
]
const RECEIVED := "ได้รับภารกิจ: เข้าหัวและเชื่อมต่อสาย LAN"
const SUMMARY_TITLE := "ด่านที่ 2  ·  ประกอบและเชื่อมต่อสาย LAN — เข้าหัวและติดตั้งสาย"
## Time score (placeholder until play-testing): full up to 12 min, 0 at 30 min.
const TIME_FULL_SEC := 720.0
const TIME_ZERO_SEC := 1800.0

enum Stage { BRIEFING, CABLE_TYPE, GATHER, CRIMP, TEST, INSTALL, REPORT, DONE }

## Seconds for the camera to move to / from the crimping desk.
const DESK_ZOOM_TIME := 0.6
## Seconds to read the result of the last cable before standing up.
const TESTING_DONE_PAUSE := 2.5
## Seconds the camera stays on the teacher PC's port after plugging it.
const PC_LED_LOOK := 1.6

var stage := Stage.BRIEFING
var elapsed_sec := 0.0
var state := Mission02State.new()
var score: MissionScore
var work_order: Mission02WorkOrder
var hud: ObjectiveHUD
var dialogue: DialogueBox
var summary: MissionSummary
var talk: Talkable
var marker: ObjectiveMarker
var supervisor: Node3D
var props: Mission02Props
var crimp_panel: CrimpPanel
var tester_panel: TesterPanel
var install_panel: InstallPanel
var rack: WallRack9U
var pc_port: NetworkPort
var rack_spot: InteractSpot
var pc_spot: InteractSpot
## Where the install stage is: "rack" (plug at the rack), "pc" (plug the
## teacher PC), "leds" (look at the switch LEDs).
var install_step := ""
## True while the player sits at the crimping desk.
var at_desk := false
var _timing := false
var _player: Node
var _desk_busy := false


func _ready() -> void:
	var world := get_parent()
	hud = ObjectiveHUD.new()
	hud.name = "ObjectiveHUD"
	add_child(hud)
	dialogue = DialogueBox.new()
	dialogue.name = "DialogueBox"
	add_child(dialogue)
	summary = MissionSummary.new()
	summary.name = "MissionSummary"
	add_child(summary)
	summary.replay_requested.connect(func(): replay_requested.emit())
	summary.menu_requested.connect(func(): menu_requested.emit())
	summary.next_requested.connect(func(): next_requested.emit())
	marker = ObjectiveMarker.new()
	marker.name = "ObjectiveMarker"
	add_child(marker)
	work_order = Mission02WorkOrder.new()
	work_order.name = "WorkOrder"
	add_child(work_order)
	work_order.confirmed.connect(_on_work_order_confirmed)
	crimp_panel = CrimpPanel.new()
	crimp_panel.name = "CrimpPanel"
	add_child(crimp_panel)
	crimp_panel.leave_requested.connect(leave_desk)
	crimp_panel.end_finished.connect(func(_key: String): _refresh_crimp_objective())
	crimp_panel.all_done.connect(_on_crimping_done)
	tester_panel = TesterPanel.new()
	tester_panel.name = "TesterPanel"
	add_child(tester_panel)
	tester_panel.leave_requested.connect(leave_desk)
	tester_panel.cable_judged.connect(_on_cable_judged)
	tester_panel.all_done.connect(_on_testing_done)
	install_panel = InstallPanel.new()
	install_panel.name = "InstallPanel"
	add_child(install_panel)
	install_panel.leave_requested.connect(leave_desk)
	install_panel.step_done.connect(_on_install_step)
	install_panel.rack_done.connect(_on_rack_done)
	install_panel.leds_checked.connect(_on_leds_checked)
	rack = world.get_node_or_null("ComputerRoomRack") as WallRack9U
	pc_port = world.get_node_or_null("TeacherPcPort") as NetworkPort
	rack_spot = InteractSpot.new()
	rack_spot.name = "RackSpot"
	rack_spot.size = Vector3(0.7, 0.6, 0.4)
	add_child(rack_spot)
	if rack:
		rack_spot.global_position = rack.global_position + rack.global_basis.z * 0.25
	rack_spot.used.connect(open_rack)
	pc_spot = InteractSpot.new()
	pc_spot.name = "PcSpot"
	pc_spot.size = Vector3(0.3, 0.4, 0.3)
	add_child(pc_spot)
	if pc_port:
		pc_spot.global_position = pc_port.global_position + Vector3(0, -0.06, 0.08)
	pc_spot.used.connect(plug_pc)
	props = world.get_node_or_null("Mission02Props") as Mission02Props
	if props:
		props.set_items_available(false)
		for item: PickupItem in props.items.values():
			item.picked_up.connect(_on_item_picked)
		crimp_panel.setup(props.crimp_station.bench, state)
		tester_panel.setup(props.crimp_station, state)
		props.crimp_station.used.connect(sit_at_desk)
	supervisor = world.get_node_or_null("ITSupportSupervisor") as Node3D
	if supervisor:
		talk = Talkable.new()
		talk.name = "Talk"
		talk.display_name = SUPERVISOR
		supervisor.add_child(talk)
		talk.talked.connect(_on_talked)
	var manager := world.get_node_or_null("Computers") as ComputerManager
	if manager and manager.desktop:
		var desktop := manager.desktop
		desktop.visibility_changed.connect(func(): hud.set_auto_collapsed(desktop.visible))
	_enter(Stage.BRIEFING)


func _process(delta: float) -> void:
	if _timing:
		elapsed_sec += delta


func _enter(next: Stage) -> void:
	stage = next
	match stage:
		Stage.BRIEFING:
			hud.set_objective("คุยกับหัวหน้างาน Data Center ในห้อง IT Support (มองที่หัวหน้างานแล้วกด F)")
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน Data Center")
			_point_at_supervisor()
		Stage.CABLE_TYPE:
			hud.set_objective("อ่านใบงาน แล้วเลือกชนิดสายให้ครบทั้ง 2 จุดเชื่อมต่อ")
			_set_prompt("")
			marker.clear()
			work_order.open()
		Stage.GATHER:
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			_refresh_gather()
		Stage.CRIMP:
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			if props:
				props.crimp_station.set_prompt("กด F เพื่อนั่งเข้าหัวสาย LAN")
				marker.point_at_position(props.crimp_station.global_position, 0.45)
			_refresh_crimp_objective()
		Stage.TEST:
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			if props:
				props.crimp_station.set_prompt("กด F เพื่อตรวจสายด้วย LAN Cable Tester")
				marker.point_at_position(props.crimp_station.global_position, 0.45)
			_refresh_test_objective()
		Stage.INSTALL:
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			if props:
				props.crimp_station.set_prompt("")
			_set_install_step("rack")
		Stage.REPORT:
			hud.set_objective("กลับไปรายงานผลกับหัวหน้างาน Data Center ในห้อง IT Support")
			_set_prompt("กด F เพื่อรายงานผลกับหัวหน้างาน")
			rack_spot.set_prompt("")
			pc_spot.set_prompt("")
			_point_at_supervisor()
		Stage.DONE:
			hud.set_objective("")
			_set_prompt("")
			marker.clear()


## Objective "หยิบอุปกรณ์ (n/5)" with what is still on the desk, the arrow on the next item.
func _refresh_gather() -> void:
	if props == null:
		return
	var missing := props.missing_items()
	var total := props.items.size()
	hud.set_objective("หยิบอุปกรณ์บนโต๊ะว่างในห้อง IT Support (%d/%d)\nยังขาด: %s" % [total - missing.size(), total, ", ".join(missing)])
	for id: String in Mission02Props.ITEMS:
		var item: PickupItem = props.items[id]
		if not item.taken:
			marker.point_at_position(item.global_position, 0.3)
			return
	marker.clear()


func _point_at_supervisor() -> void:
	if supervisor:
		var seated: bool = supervisor is NpcCharacter and (supervisor as NpcCharacter).seated
		marker.point_at(supervisor, 1.75 if seated else 2.25)
	else:
		marker.clear()


func _set_prompt(text: String) -> void:
	if talk:
		talk.prompt = text


func _on_talked(player: Node) -> void:
	match stage:
		Stage.BRIEFING:
			_player = player
			# Stay seated in the conversation: the work order comes next.
			await _say(player, PackedStringArray(BRIEFING), false)
			_timing = true
			hud.show_toast(RECEIVED)
			briefed.emit()
			_enter(Stage.CABLE_TYPE)
		Stage.GATHER:
			await _say(player, PackedStringArray(GATHER_REMINDER))
		Stage.REPORT:
			await _say(player, report_lines(), false)
			hud.show_toast("ภารกิจที่ 2 เสร็จสิ้น")
			finish(player)
		Stage.DONE:
			pass
		_:
			await _say(player, PackedStringArray(NEXT_REMINDER))


## What the player reports and what the supervisor answers, from the real result.
func report_lines() -> PackedStringArray:
	var both_lit := rack != null and pc_port != null and rack.is_link_on("switch_01") and rack.is_link_on("switch_02") and pc_port.link_on
	var lines := PackedStringArray()
	lines.append("คุณ|ผมเข้าหัว ตรวจสอบ และติดตั้งสาย LAN ทั้ง 2 เส้นตามใบงานแล้วครับ " + ("ไฟสถานะพอร์ตติดทั้งสองจุดครับ" if both_lit else "แต่ไฟสถานะพอร์ตบางจุดไม่ติดครับ"))
	if state.job_works():
		lines.append("หัวหน้างาน Data Center|ดีมาก **การเลือกชนิดสาย การเรียงสี การย้ำหัว และการตรวจสอบสายก่อนติดตั้ง**เป็นขั้นตอนสำคัญ ถ้าสายมีปัญหาจะทำให้เสียเวลาในการตรวจสอบระบบภายหลัง")
		return lines
	if state.router_port == "router_wan":
		lines.append("หัวหน้างาน Data Center|สายเส้นที่ 1 ไปเสียบที่**พอร์ต WAN** ซึ่งเป็นช่องของ**สายอินเทอร์เน็ต** ตอนนี้ห้องคอมเลยออกอินเทอร์เน็ตไม่ได้")
	if not state.spare_cables.is_empty():
		lines.append("หัวหน้างาน Data Center|ดีที่ตรวจเจอสายเสียก่อนติดตั้ง แต่สายที่เข้าหัวเอง**ยังใช้งานไม่ได้** ต้องใช้**สายสำรอง**แทน")
	if not both_lit:
		lines.append("หัวหน้างาน Data Center|ไฟสถานะไม่ติดแสดงว่า**สายยังมีปัญหา** ควรตรวจด้วย Tester ให้ดีก่อนนำไปติดตั้งทุกครั้ง")
	lines.append("หัวหน้างาน Data Center|งานนี้ยังใช้งานไม่ได้จริง ลองดู**จุดที่ผิดพลาด**ในสรุปผล แล้วฝึกเรียงสี **T568B** ให้คล่องนะ")
	return lines


## Builds the score, records it and shows the summary. Also used by tests.
func finish(player: Node = null) -> MissionScore:
	_timing = false
	score = state.mission_score(elapsed_sec, TIME_FULL_SEC, TIME_ZERO_SEC)
	var record := GameProgress.record_attempt(LEVEL, score, {
		"cable_types": state.cable_types.duplicate(), "ends": state.ends.duplicate(true),
		"tester_verdicts": state.tester_verdicts.duplicate(), "router_port": state.router_port,
		"spare_cables": Array(state.spare_cables), "job_works": state.job_works()})
	_enter(Stage.DONE)
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var next_available: bool = flow != null and flow.call("next_level_available", LEVEL)
	var colours_ok := 0
	for key: String in ["1A", "1B", "2A", "2B"]:
		colours_ok += 8 - state.wrong_pins(key).size()
	var tester_ok := 0
	for cable in [1, 2]:
		if state.tester_verdicts.has(cable) and bool(state.tester_verdicts[cable]) == state.cable_good(cable):
			tester_ok += 1
	var types_ok := 0
	for point in Mission02State.POINTS:
		if state.cable_types.get(point, "") == Mission02State.STRAIGHT:
			types_ok += 1
	summary.show_result(SUMMARY_TITLE, score, record, next_available, [
		["ผลงานใช้งานได้จริง", "ใช่" if state.job_works() else "ไม่ใช่ (สายเรียงสีผิด หรือเสียบพอร์ตผิด)"],
		["เลือกชนิดสาย", "ถูก %d จาก 2 จุด" % types_ok],
		["เรียงสี T568B", "ถูก %d จาก 32 ตำแหน่ง (4 ปลาย)" % colours_ok],
		["อ่านผล LAN Cable Tester", "ถูก %d จาก 2 เส้น" % tester_ok],
		["พอร์ตของ Router", state.router_port.replace("router_lan", "LAN ").replace("router_wan", "WAN")],
		["ใช้สายสำรอง", "%d เส้น" % state.spare_cables.size()],
	])
	finished.emit(score)
	return score


func _refresh_crimp_objective() -> void:
	if stage != Stage.CRIMP:
		return
	var done := crimp_panel.end_index
	hud.set_objective("เข้าหัวสาย LAN ที่โต๊ะว่างในห้อง IT Support (เสร็จ %d/4 ปลาย)\nสายเส้นละ 2 ปลาย มาตรฐาน T568B ทั้งสองปลาย" % done)


func _refresh_test_objective() -> void:
	if stage != Stage.TEST:
		return
	hud.set_objective("ตรวจสายทั้ง 2 เส้นด้วย LAN Cable Tester ที่โต๊ะว่าง (ตรวจแล้ว %d/2)" % mini(tester_panel.cable - 1, 2))


## Sits at the desk: crimping (the cable end) or testing (the tester),
## depending on the stage. The camera moves there and the step panel opens.
func sit_at_desk(player: Node) -> void:
	if not stage in [Stage.CRIMP, Stage.TEST] or at_desk or _desk_busy or props == null:
		return
	_desk_busy = true
	_player = player
	at_desk = true
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	hud.set_auto_collapsed(true)
	marker.clear()
	Sound.play("chair")
	var station := props.crimp_station
	if stage == Stage.TEST:
		station.show_tester()
	var view := station.tester_view_transform() if stage == Stage.TEST else station.bench.view_transform()
	if player.has_method("move_camera_to"):
		await player.move_camera_to(view, DESK_ZOOM_TIME)
	if stage == Stage.TEST:
		tester_panel.open()
	else:
		crimp_panel.open()
	_desk_busy = false


## Stands up from the desk; the work stays where it was.
func leave_desk() -> void:
	if not at_desk or _desk_busy:
		return
	_desk_busy = true
	crimp_panel.close()
	tester_panel.close()
	install_panel.close()
	if rack:
		rack.set_door_open(false)
	if props and props.crimp_station.tester:
		# Off while away; sitting down again restores the step (TesterPanel._sync_desk).
		props.crimp_station.tester.set_power(false)
	Sound.play("chair")
	if _player and _player.has_method("return_camera"):
		await _player.return_camera(DESK_ZOOM_TIME)
	at_desk = false
	hud.set_auto_collapsed(false)
	if _player and _player.has_method("set_controls_locked"):
		_player.set_controls_locked(false)
	_desk_busy = false
	if stage in [Stage.CRIMP, Stage.TEST] and props:
		marker.point_at_position(props.crimp_station.global_position, 0.45)
	elif stage == Stage.INSTALL:
		_set_install_step(install_step)


func _on_crimping_done() -> void:
	hud.show_toast("เข้าหัวครบทั้ง 2 เส้นแล้ว — ต่อไปตรวจด้วย LAN Cable Tester")
	await leave_desk()
	_enter(Stage.TEST)


func _on_cable_judged(_cable: int, _passes: bool) -> void:
	_refresh_test_objective()


# ---------------------------------------------------------------- installing

func _set_install_step(step: String) -> void:
	install_step = step
	rack_spot.set_prompt("")
	pc_spot.set_prompt("")
	match step:
		"rack":
			hud.set_objective("นำสายทั้ง 2 เส้นไปติดตั้งที่ Wall Rack ในห้องคอมพิวเตอร์ (หลังโต๊ะครู)")
			rack_spot.set_prompt("กด F เพื่อเปิดตู้ Wall Rack และติดตั้งสาย")
			if rack:
				marker.point_at_position(rack.global_position, 0.45)
		"pc":
			hud.set_objective("เสียบสายเส้นที่ 2 เข้าการ์ดเครือข่ายด้านหลังคอมพิวเตอร์ครู")
			pc_spot.set_prompt("กด F เพื่อเสียบสายเข้าการ์ดเครือข่าย")
			if pc_port:
				marker.point_at_position(pc_port.global_position, 0.35)
		"leds":
			hud.set_objective("กลับไปที่ Wall Rack แล้วตรวจไฟสถานะพอร์ตของ Switched Hub")
			rack_spot.set_prompt("กด F เพื่อดูไฟสถานะพอร์ตที่ Wall Rack")
			if rack:
				marker.point_at_position(rack.global_position, 0.45)


## Opens the rack: plugging the cables (rack step) or looking at the LEDs.
func open_rack(player: Node) -> void:
	if stage != Stage.INSTALL or not install_step in ["rack", "leds"] or at_desk or _desk_busy or rack == null:
		return
	_desk_busy = true
	_player = player
	at_desk = true
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	hud.set_auto_collapsed(true)
	marker.clear()
	rack.set_door_open(true)
	Sound.play("door_open", rack)
	if player.has_method("move_camera_to"):
		await player.move_camera_to(rack.view_transform(), DESK_ZOOM_TIME)
	install_panel.open(install_step)
	_desk_busy = false


func _on_install_step(step: String, value: String) -> void:
	match step:
		"router":
			if state.router_port == "":
				state.router_port = value
			if value == "router_wan":
				# The Internet line comes out of WAN to make room.
				rack.disconnect_internet()
			rack.plug(value)
		"switch1":
			rack.patch(state.router_port, "switch_01")
			var works := state.installed_cable_works(1)
			rack.set_link(state.router_port, works)
			rack.set_link("switch_01", works)
		"switch2":
			rack.plug("switch_02")
		"route":
			rack.drop_to_pc("switch_02", pc_port, false)


func _on_rack_done() -> void:
	await get_tree().create_timer(0.8).timeout
	await leave_desk()
	_set_install_step("pc")


## Plugs cable 2 into the teacher PC's network card and shows its LED.
func plug_pc(player: Node) -> void:
	if stage != Stage.INSTALL or install_step != "pc" or at_desk or _desk_busy or pc_port == null:
		return
	_desk_busy = true
	_player = player
	at_desk = true
	pc_spot.set_prompt("")
	marker.clear()
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	rack.drop_to_pc("switch_02", pc_port, true)
	var works := state.installed_cable_works(2)
	pc_port.set_link(works)
	rack.set_link("switch_02", works)
	Sound.play("crimp", pc_port)
	# A close look at the port: is its link LED on?
	var eye := pc_port.global_position + Vector3(0.05, 0.05, 0.26)
	if player.has_method("move_camera_to"):
		await player.move_camera_to(Transform3D(Basis.looking_at(pc_port.global_position - eye, Vector3.UP), eye), DESK_ZOOM_TIME)
		await get_tree().create_timer(PC_LED_LOOK).timeout
		await player.return_camera(DESK_ZOOM_TIME)
	at_desk = false
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_desk_busy = false
	_set_install_step("leds")


func _on_leds_checked() -> void:
	await leave_desk()
	installed.emit()
	_enter(Stage.REPORT)


## Both cables judged: give the player time to read the last message, then go.
func _on_testing_done() -> void:
	if tester_panel.message != "":
		hud.show_toast(tester_panel.message, 5.0)
	await get_tree().create_timer(TESTING_DONE_PAUSE).timeout
	await leave_desk()
	if props:
		props.crimp_station.hide_tester()
	_enter(Stage.INSTALL)


func _on_work_order_confirmed(answers: Dictionary) -> void:
	if stage != Stage.CABLE_TYPE:
		return
	for point: int in answers:
		state.set_cable_type(point, answers[point])
	if _player and _player.has_method("set_controls_locked"):
		_player.set_controls_locked(false)
	hud.show_toast("บันทึกใบงานแล้ว — ไปหยิบอุปกรณ์บนโต๊ะว่าง")
	if props:
		props.set_items_available(true)
	cable_types_chosen.emit()
	_enter(Stage.GATHER)


func _on_item_picked(_item_id: String) -> void:
	if stage != Stage.GATHER:
		return
	if props.missing_items().is_empty():
		hud.show_toast("หยิบอุปกรณ์ครบแล้ว")
		_enter(Stage.CRIMP)
		tools_gathered.emit()
	else:
		_refresh_gather()


func _say(player: Node, lines: PackedStringArray, unlock_after: bool = true) -> void:
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	if supervisor is NpcCharacter and player is Node3D:
		await (supervisor as NpcCharacter).turn_to(player)
	dialogue.show_lines(lines)
	await dialogue.finished
	if supervisor is NpcCharacter:
		(supervisor as NpcCharacter).turn_back()
	if unlock_after and player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
