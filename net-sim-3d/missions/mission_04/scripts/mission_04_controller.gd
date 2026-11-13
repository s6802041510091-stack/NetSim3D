class_name Mission04Controller
extends Node

## Runs Level 4 in the school map (added by GameFlow.configure_level),
## ภารกิจ/ด่าน_04/README.md as agreed on 2026-11-12:
##   1. the desk phone in IT Support rings: the female teacher (ครูสาว) has no
##      Internet in the teachers' room -> the timer starts
##   2. talk to her: she stands up and waits beside her desk
##   3. symptoms: her screen shows LAN ✗, the NIC port at the back has no LED
##   4. test the cable: pick the tool, the LAN Cable Tester shows all 8 wires
##      match -> the player's verdict
##   5. plug the same cable into STAFF-PC-03: it works -> the conclusion
##   6. the evidence and "what next?" (5 shuffled options, hints, choose again)
##   7. the spare part from the storage room, 8. the replace animation
##   9. ping the Default Gateway and open the website, 10. tell her,
##   11. report to the supervisor -> score (Mission04State) -> summary

signal call_answered
## The player clicked the thing a close-up asked for (_wait_click).
signal clicked
## A key hold (_wait_hold) or a mouse drag (_wait_drag) is done.
signal held
signal dragged
signal finished(score: MissionScore)
signal replay_requested
signal menu_requested
signal next_requested

const LEVEL := 4
const TEACHER := "ครูสาว"
const SUPERVISOR := "หัวหน้างาน Data Center"
const HOST := "STAFF-PC-01"
const SWAP_HOST := "STAFF-PC-03"
const RECEIVED := "ได้รับภารกิจ: ตรวจสอบคอมพิวเตอร์ในห้องพักครูที่ไม่สามารถเชื่อมต่อเครือข่ายได้"
const SUMMARY_TITLE := "ด่านที่ 4  ·  วิเคราะห์และแก้ปัญหาการ์ดเครือข่าย"
## Time score (placeholder until play-testing): full up to 10 min, 0 at 25 min.
const TIME_FULL_SEC := 600.0
const TIME_ZERO_SEC := 1500.0
const VIEW_TIME := 0.6

## Where things are (desk 1 = STAFF-PC-01, desk 3 = STAFF-PC-03; both desks
## run along the east wall, the user sits on the -X side facing +X).
const DESK_TOP := 0.75
const TOWER_1 := Vector3(8.6, DESK_TOP, -28.53)
const TOWER_3 := Vector3(8.6, DESK_TOP, -17.33)
## The binders at the end of her desk make room for the PC case.
const DESK_1_ITEMS := "TR_Desk_Items_1"
const DESK_3_ITEMS := "TR_Desk_Items_3"
const TESTER_AT := Vector3(8.33, DESK_TOP + 0.002, -27.5)
## She waits here (the guest chair's old place) while the player works.
const TEACHER_WAIT := Vector3(7.45, 0.02, -26.8)
## The spare-parts box on the storage room's drawer island.
const PARTS_BOX := Vector3(-16.4, 0.88, -33.75)
const CABLE_COLOR := Color(0.16, 0.42, 0.85)

const CALL := [
	"ครูสาว|สวัสดีค่ะ ฝ่าย IT ใช่ไหมคะ คอมพิวเตอร์ที่**ห้องพักครู**ใช้**อินเทอร์เน็ตไม่ได้**ค่ะ ช่วยมาตรวจสอบให้หน่อยได้ไหมคะ",
	"คุณ|ได้ครับ ผมจะไปตรวจสอบให้",
]
const MEET := [
	"ครูสาว|มาแล้วเหรอคะ เครื่องนี้แหละค่ะ เมื่อเช้ายังใช้ได้อยู่เลย ตอนนี้เปิดเว็บไม่ขึ้นเลยค่ะ",
	"คุณ|เดี๋ยวผมขอตรวจสอบที่เครื่องก่อนนะครับ เริ่มจากสาย LAN และพอร์ตเครือข่ายครับ",
	"ครูสาว|ได้ค่ะ งั้นครูลุกให้ ตามสบายเลยนะคะ",
]
const WAITING := ["ครูสาว|ตามสบายเลยค่ะ ครูรออยู่ตรงนี้นะคะ"]
const TELL := [
	"คุณ|ตรวจสอบแล้วพบว่า **Network Interface Card** มีปัญหาครับ ตอนนี้เปลี่ยนอุปกรณ์และทดสอบการเชื่อมต่อเรียบร้อยแล้ว",
	"ครูสาว|ขอบคุณค่ะ เดี๋ยวครูลองใช้ดูนะคะ",
]
const THANKS := ["ครูสาว|ตอนนี้ใช้งานอินเทอร์เน็ตได้แล้วค่ะ ขอบคุณมากนะคะ"]
const REPORT := [
	"คุณ|เครื่องในห้องพักครูเชื่อมต่อเครือข่ายไม่ได้ครับ ผมตรวจสาย LAN และทดลองกับเครื่องอื่นแล้วสายปกติ จึงเปลี่ยน Network Interface Card ตอนนี้ใช้งานได้แล้วครับ",
	"หัวหน้างาน Data Center|ทำได้ดี คุณตรวจสอบจาก**สาย LAN** ก่อน แล้วจึงใช้**หลักฐานตัดสาเหตุ**จนพบว่า Network Interface Card มีปัญหา",
]
const SUPERVISOR_BUSY := ["หัวหน้างาน Data Center|งานที่ห้องพักครูเรียบร้อยแล้วค่อยมารายงานนะ"]

## Pictures for the tool and part cards (rendered by GPT, 512 px).
const ICONS := "res://assets/ui/mission_04/"
const TOOLS := [
	["cable_tester", "LAN Cable Tester (เครื่องทดสอบสาย LAN)", ICONS + "tool_cable_tester.png"],
	["crimper", "คีมเข้าหัว RJ45", ICONS + "tool_crimper.png"],
	["stripper", "คีมปอกสาย LAN", ICONS + "tool_stripper.png"],
	["screwdriver", "ไขควง", ICONS + "tool_screwdriver.png"],
]
const TOOL_WRONG := "เครื่องมือนี้ไม่ได้ใช้ตรวจว่าสาย LAN ส่งสัญญาณได้ครบทุกเส้น ลองเลือกใหม่"
const VERDICTS := [["cable_ok", "สายปกติ ใช้งานได้"], ["cable_bad", "สายเสีย ต้องเปลี่ยนสายใหม่"]]
const VERDICT_WRONG := "ลองดูไฟอีกครั้ง: ไฟของตัวแม่ (MAIN) และตัวลูก (REMOTE) ติดเรียงกันตรงกันครบ 1–8 แปลว่าอย่างไร"
const SWAPS := [
	["nic_suspect", "สาย LAN และพอร์ตบน Switched Hub ปกติ ปัญหาน่าจะอยู่ที่เครื่องของครูสาว"],
	["cable_bad", "สาย LAN เส้นนี้เสีย"],
	["switch_bad", "Switched Hub เสีย คอมพิวเตอร์ทุกเครื่องใช้งานไม่ได้"],
	["internet_down", "อินเทอร์เน็ตของโรงเรียนล่ม"],
]
const SWAP_WRONG := {
	"cable_bad": "ถ้าสายเสีย เครื่องอีกเครื่องที่ใช้สายเส้นเดียวกันจะใช้งานได้หรือไม่",
	"switch_bad": "คอมพิวเตอร์อีกเครื่องใช้งานเครือข่ายได้ตามปกติ",
	"internet_down": "ถ้าอินเทอร์เน็ตล่ม เครื่องอีกเครื่องจะเชื่อมต่อได้หรือไม่",
}
const PARTS := [
	["nic", "การ์ดเครือข่าย (Network Interface Card: NIC)", ICONS + "part_nic.png"],
	["ram", "หน่วยความจำ RAM", ICONS + "part_ram.png"],
	["gpu", "การ์ดจอ (Graphics Card)", ICONS + "part_gpu.png"],
	["usb_wifi", "USB Wi-Fi Adapter", ICONS + "part_usb_wifi.png"],
]
const PART_WRONG := "ชิ้นนี้ไม่ใช่อุปกรณ์ที่ต้องเปลี่ยน ลองดูผลการวิเคราะห์อีกครั้ง"

## The mission's steps in order (ObjectiveHUD.set_steps, the standard).
const HEADING := "วิเคราะห์และแก้ปัญหาการ์ดเครือข่าย"
const STEPS := [
	"รับสายโทรศัพท์ที่โต๊ะทำงานในห้อง IT Support",
	"ไปพบครูสาวที่ห้องพักครู",
	"ตรวจอาการ: หน้าจอ และไฟพอร์ตการ์ดเครือข่าย",
	"ตรวจสาย LAN ด้วยเครื่องมือที่เหมาะสม",
	"ทดลองสายเส้นเดิมกับคอมพิวเตอร์อีกเครื่อง (STAFF-PC-03)",
	"วิเคราะห์หลักฐานและเลือกวิธีแก้ไข",
	"หยิบอะไหล่สำรองจากห้องเก็บอุปกรณ์",
	"เปลี่ยนอะไหล่ที่เครื่องของครูสาว",
	"ทดสอบ: ping ไปที่ Default Gateway และเปิดเว็บไซต์",
	"แจ้งผลให้ครูสาว",
	"รายงานหัวหน้างาน Data Center",
]

enum Stage { CALL, MEET, INSPECT, TEST, SWAP, ANALYZE, FETCH, REPLACE, VERIFY, TELL, REPORT, DONE }

var stage := Stage.CALL
var elapsed_sec := 0.0
var state := Mission04State.new()
var score: MissionScore
var hud: ObjectiveHUD
var dialogue: DialogueBox
var summary: MissionSummary
var marker: ObjectiveMarker
var choice: Mission04Choice
var manager: ComputerManager
var station: ComputerStation
var swap_station: ComputerStation
var phone: DeskPhone
var teacher: NpcCharacter
var teacher_talk: Talkable
var supervisor: Node3D
var talk: Talkable
var tower: Mission04Tower
var swap_tower: Mission04Tower
var tower_spot: InteractSpot
var swap_spot: InteractSpot
var parts_spot: InteractSpot
var parts_box: Node3D
var tester: CableTester
## Symptoms seen: the screen (LAN ✗) and the port (no LED).
var saw_screen := false
var saw_port := false
var has_spare := false
## What the choice window is asking now: "tool", "swap", "fix", "part".
var asking := ""
var _cable: Node3D
var _swap_cable: Node3D
var _tester_rig: Node3D
var _timing := false
var _busy := false
var _player: Node
## True while the camera is away from the player's eyes (a close-up).
var _view_away := false
## Plugging by hand (Level 2's PlugBoard, used as is) and clicks on parts.
var board: PlugBoard
const CLICK_PX := 45.0
var _click_waiting := false
var _click_point := Vector3.ZERO
var _click_layer: CanvasLayer
var _click_hint: Label
## The cable was pulled out of STAFF-PC-03 and goes back to her PC.
var cable_home_pending := false
## Turning a screw by holding a key.
const HOLD_TIME := 1.6
var _hold_waiting := false
var _hold_key: Key = KEY_A
var _hold_wrong: Key = KEY_D
var _hold_wrong_text := ""
var _hold_apply: Callable
var _hold_progress := 0.0
var _progress_bar: ProgressBar
## Dragging a part with the mouse.
var _drag_waiting := false
var _drag_active := false
var _drag_start := Vector3.ZERO
var _drag_end := Vector3.ZERO
var _drag_apply: Callable
var _drag_k := 0.0
var _drag_from := Vector2.ZERO
var _drag_text := ""
var _drag_slant_text := ""
## Free look during the NIC repair (user, 2026-11-13): around the part the
## step is about — right-drag orbits, wheel zooms, middle-drag pans, R resets.
var _repair_cam := false
var _orbit_on := false
var _orbit_target := Vector3.ZERO
var _orbit_base := Transform3D.IDENTITY
var _orbit_yaw := 0.0
var _orbit_pitch := 0.0
var _orbit_zoom := 1.0
var _orbit_pan := Vector3.ZERO
var _orbit_turning := false
var _orbit_panning := false
var _orbit_help: Label
const ORBIT_YAW_MAX := 1.0
const ORBIT_PITCH_MAX := 0.6
const ORBIT_ZOOM := Vector2(0.4, 1.8)
const ORBIT_PAN_MAX := 0.1


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
	choice = Mission04Choice.new()
	choice.name = "Choice"
	add_child(choice)
	choice.picked.connect(_on_picked)
	choice.closed.connect(_on_choice_closed)
	board = PlugBoard.new()
	board.name = "PlugBoard"
	add_child(board)
	board.plug_moved.connect(func(_id: String): _rebuild_tester_loop())
	_click_layer = CanvasLayer.new()
	_click_layer.layer = 23
	_click_layer.visible = false
	add_child(_click_layer)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", GameUI.box(Color(0.07, 0.09, 0.13, 0.9), Color(0.4, 0.6, 0.95, 0.6), 8, 16, 8))
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_top = -70
	bar.offset_bottom = -24
	bar.offset_left = -300
	bar.offset_right = 300
	_click_layer.add_child(bar)
	_click_hint = GameUI.label("", 17, Color.WHITE)
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar_col := VBoxContainer.new()
	bar.add_child(bar_col)
	bar_col.add_child(_click_hint)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 10)
	_progress_bar.show_percentage = false
	_progress_bar.visible = false
	bar_col.add_child(_progress_bar)
	_orbit_help = GameUI.label("คลิกขวาค้างแล้วลาก = หมุนมุมมอง  ·  ล้อเมาส์ = ซูม  ·  คลิกกลางลาก = เลื่อน  ·  R = มุมเดิม", 13, Color(0.75, 0.82, 0.95))
	_orbit_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_orbit_help.visible = false
	bar_col.add_child(_orbit_help)
	manager = world.get_node_or_null("Computers") as ComputerManager
	if manager:
		station = manager.find_host(HOST)
		swap_station = manager.find_host(SWAP_HOST)
		# The broken NIC: no link. The empty desk 3 has no cable yet.
		if station:
			station.network_connected = false
		if swap_station:
			swap_station.network_connected = false
		var desktop := manager.desktop
		desktop.desktop_ready.connect(_on_desktop_ready)
		desktop.visibility_changed.connect(_refresh_marker)
		desktop.ping_done.connect(_on_ping_done)
		desktop.page_opened.connect(_on_page_opened)
	var items := world.get_node_or_null("MapVisual/" + DESK_1_ITEMS) as Node3D
	if items:
		items.visible = false
	_hide_books(world.get_node_or_null("MapVisual/" + DESK_3_ITEMS))
	tower = Mission04Tower.new()
	tower.name = "TeacherPcTower"
	add_child(tower)
	tower.position = TOWER_1
	tower.rotation.y = -PI * 0.5
	# Her PC: the Blender model (realistic inside); the simple boxes only if it is missing.
	if not tower.use_model():
		tower.add_details()
	swap_tower = Mission04Tower.new()
	swap_tower.name = "SpareDeskPcTower"
	add_child(swap_tower)
	swap_tower.position = TOWER_3
	swap_tower.rotation.y = -PI * 0.5
	tower.port.plug(CABLE_COLOR)
	tower.port.set_link(false)
	_cable = _draw_cable(tower, "Desk1Cable")
	tower_spot = _spot("TowerSpot", TOWER_1 + Vector3(0, 0.2, 0), Vector3(0.45, 0.45, 0.3))
	tower_spot.used.connect(use_tower)
	swap_spot = _spot("SwapSpot", TOWER_3 + Vector3(0, 0.2, 0), Vector3(0.45, 0.45, 0.3))
	swap_spot.used.connect(use_swap_pc)
	parts_box = _make_parts_box()
	add_child(parts_box)
	parts_box.position = PARTS_BOX
	parts_spot = _spot("PartsSpot", PARTS_BOX + Vector3(0, 0.1, 0), Vector3(0.4, 0.3, 0.35))
	parts_spot.used.connect(open_parts)
	phone = world.get_node_or_null("DeskPhone") as DeskPhone
	if phone:
		phone.ringing = true
		phone.answered.connect(_on_phone)
	teacher = world.get_node_or_null("TeacherFemale") as NpcCharacter
	if teacher:
		teacher_talk = Talkable.new()
		teacher_talk.name = "Talk"
		teacher_talk.display_name = TEACHER
		teacher.add_child(teacher_talk)
		teacher_talk.talked.connect(_on_teacher_talked)
	supervisor = world.get_node_or_null("ITSupportSupervisor") as Node3D
	if supervisor:
		talk = Talkable.new()
		talk.name = "Talk"
		talk.display_name = SUPERVISOR
		supervisor.add_child(talk)
		talk.talked.connect(_on_supervisor_talked)
	_enter(Stage.CALL)


func _process(delta: float) -> void:
	if _timing:
		elapsed_sec += delta
	_process_hold(delta)
	# The objective tab folds while a window, the desktop or a close-up has the screen.
	var desktop_on := manager != null and manager.desktop != null and manager.desktop.visible
	hud.set_auto_collapsed(choice.is_open() or _view_away or desktop_on)


func _spot(spot_name: String, at: Vector3, size: Vector3) -> InteractSpot:
	var spot := InteractSpot.new()
	spot.name = spot_name
	spot.size = size
	add_child(spot)
	spot.global_position = at
	return spot


# ---------------------------------------------------------------- stages

func _enter(next: Stage) -> void:
	stage = next
	if teacher_talk:
		teacher_talk.prompt = ""
	if talk:
		talk.prompt = "กด F เพื่อคุยกับหัวหน้างาน" if stage != Stage.REPORT else "กด F เพื่อรายงานผลกับหัวหน้างาน"
	match stage:
		Stage.MEET:
			teacher_talk.prompt = "กด F เพื่อคุยกับ" + TEACHER
		Stage.TELL:
			teacher_talk.prompt = "กด F เพื่อแจ้งผลให้" + TEACHER
		Stage.DONE:
			if talk:
				talk.prompt = ""
		_:
			if teacher_talk and stage > Stage.MEET and stage < Stage.TELL:
				teacher_talk.prompt = "กด F เพื่อคุยกับ" + TEACHER
	_refresh_spots()
	_show_steps()
	_refresh_marker()


func _refresh_spots() -> void:
	var tower_prompt := ""
	match stage:
		Stage.INSPECT:
			if not saw_port:
				tower_prompt = "กด F เพื่อดูพอร์ตการ์ดเครือข่ายด้านหลังเครื่อง"
		Stage.TEST:
			tower_prompt = "กด F เพื่อตรวจสาย LAN (เลือกเครื่องมือ)"
		Stage.REPLACE:
			tower_prompt = "กด F เพื่อเปลี่ยนการ์ดเครือข่าย (NIC)" if has_spare else ""
	tower_spot.set_prompt(tower_prompt)
	if stage == Stage.SWAP and cable_home_pending:
		tower_spot.set_prompt("กด F เพื่อเสียบสาย LAN กลับเข้าเครื่องครูสาว")
	swap_spot.set_prompt("กด F เพื่อเสียบสาย LAN เส้นเดิมเข้าคอมพิวเตอร์เครื่องนี้" if stage == Stage.SWAP and not cable_home_pending else "")
	parts_spot.set_prompt("กด F เพื่อเปิดกล่องอะไหล่คอมพิวเตอร์" if stage == Stage.FETCH else "")


func _show_steps() -> void:
	if stage == Stage.DONE:
		hud.set_objective("")
		return
	var current := int(stage)
	var hint := ""
	match stage:
		Stage.CALL:
			hint = "โทรศัพท์บนโต๊ะทำงานของคุณในห้อง IT Support กำลังดัง มองที่โทรศัพท์แล้วกด F"
		Stage.MEET:
			hint = "ห้องพักครู โต๊ะของครูสาวอยู่หลังฉากกั้นยาว กด F ที่ครูสาว"
		Stage.INSPECT:
			var left := PackedStringArray()
			if not saw_screen:
				left.append("นั่งที่คอมพิวเตอร์ (F) ดูสัญลักษณ์เครือข่าย")
			if not saw_port:
				left.append("ดูไฟพอร์ตการ์ดเครือข่ายด้านหลังเครื่อง (F ที่ตัวเครื่อง)")
			hint = " • ".join(left)
		Stage.TEST:
			hint = "กด F ที่ตัวเครื่อง แล้วเลือกเครื่องมือตรวจสาย"
		Stage.SWAP:
			hint = "นำสาย LAN กลับไปเสียบที่เครื่องครูสาว (F ที่ตัวเครื่อง)" if cable_home_pending else "คอมพิวเตอร์ STAFF-PC-03 โต๊ะว่างแถวเดียวกัน กด F ที่ตัวเครื่อง"
		Stage.ANALYZE:
			hint = "อ่านหลักฐาน แล้วเลือกวิธีแก้ไข"
		Stage.FETCH:
			hint = "ห้องเก็บอุปกรณ์ข้างห้อง IT Support กล่องอะไหล่บนโต๊ะกลางห้อง"
		Stage.REPLACE:
			hint = "กลับไปที่เครื่องของครูสาว กด F ที่ตัวเครื่อง"
		Stage.VERIFY:
			var todo := PackedStringArray()
			if not state.verified_ping:
				todo.append("Command Prompt: ping ไปที่ Default Gateway")
			if not state.verified_web:
				todo.append("เปิด Web Browser")
			hint = "นั่งที่คอมพิวเตอร์ของครูสาว • " + " • ".join(todo)
		Stage.TELL:
			hint = "กด F ที่ครูสาว"
		Stage.REPORT:
			hint = "กลับไปห้อง IT Support มองที่หัวหน้างานแล้วกด F"
	hud.set_steps(ObjectiveHUD.sequence(STEPS, current), hint, HEADING, "ภารกิจที่ 4")


func _refresh_marker() -> void:
	if manager and manager.desktop and manager.desktop.visible:
		marker.clear()
		return
	match stage:
		Stage.CALL:
			if phone:
				marker.point_at_position(phone.global_position, 0.35)
		Stage.MEET, Stage.TELL:
			if teacher:
				marker.point_at(teacher, 1.75 if teacher.seated else 2.1)
		Stage.INSPECT:
			marker.point_at_position(station.global_position if not saw_screen else TOWER_1 + Vector3(0, 0.4, 0), 0.4)
		Stage.TEST, Stage.REPLACE:
			marker.point_at_position(TOWER_1 + Vector3(0, 0.4, 0), 0.4)
		Stage.SWAP:
			marker.point_at_position((TOWER_1 if cable_home_pending else TOWER_3) + Vector3(0, 0.4, 0), 0.4)
		Stage.FETCH:
			marker.point_at_position(PARTS_BOX, 0.5)
		Stage.VERIFY:
			marker.point_at_position(station.global_position, 0.4)
		Stage.REPORT:
			if supervisor:
				marker.point_at(supervisor, 1.75)
		_:
			marker.clear()


# ---------------------------------------------------------------- people

func _on_phone(player: Node) -> void:
	if stage != Stage.CALL or _busy:
		return
	phone.ringing = false
	await _say(player, null, PackedStringArray(CALL), true, "สายเข้า: ครูสาว (ห้องพักครู)")
	_timing = true
	hud.show_toast(RECEIVED)
	call_answered.emit()
	_enter(Stage.MEET)


func _on_teacher_talked(player: Node) -> void:
	if _busy:
		return
	match stage:
		Stage.MEET:
			await _say(player, teacher, PackedStringArray(MEET))
			_enter(Stage.INSPECT)
			_teacher_step_aside()
		Stage.TELL:
			await _say(player, teacher, PackedStringArray(TELL))
			await _teacher_sit_back()
			await _say(player, teacher, PackedStringArray(THANKS))
			_enter(Stage.REPORT)
		_:
			await _say(player, teacher, PackedStringArray(WAITING))


func _on_supervisor_talked(player: Node) -> void:
	if _busy:
		return
	if stage == Stage.REPORT:
		await _say(player, supervisor, PackedStringArray(REPORT), false)
		hud.show_toast("ภารกิจสำเร็จ: วิเคราะห์และแก้ปัญหาการ์ดเครือข่าย")
		finish(player)
	else:
		await _say(player, supervisor, PackedStringArray(SUPERVISOR_BUSY))


## She gets up and waits a step away; her computer is free for the player.
func _teacher_step_aside() -> void:
	if teacher == null:
		return
	await teacher.stand_up()
	if station:
		station.collision_layer = ComputerStation.COLLISION_LAYER
	await teacher.walk_path([TEACHER_WAIT])
	var to_desk := TOWER_1 - teacher.global_position
	await teacher.face_yaw(atan2(to_desk.x, to_desk.z))


func _teacher_sit_back() -> void:
	if teacher == null or teacher.seated:
		return
	if station:
		station.collision_layer = 0
	var seat := StaffRoomLife.seat_of("female")
	await teacher.walk_path([seat - Vector3(NpcCharacter.STAND_BACK, 0, 0)])
	await teacher.face_yaw(PI * 0.5)
	await teacher.sit_down()


# ---------------------------------------------------------------- computer

func _on_desktop_ready() -> void:
	var host := manager.desktop.station.hostname if manager.desktop.station else ""
	if host == HOST and stage == Stage.INSPECT and not saw_screen:
		saw_screen = true
		hud.show_toast("สัญลักษณ์เครือข่ายแสดง LAN ✗ — เครื่องไม่ได้เชื่อมต่อเครือข่าย", 4.0)
		_after_symptom()


func _on_ping_done(target: String, _address: String, received: int) -> void:
	if stage != Stage.VERIFY or manager.desktop.station != station:
		return
	state.note_ping(target, station.gateway, received)
	_check_verified()


func _on_page_opened(_url: String, ok: bool) -> void:
	if stage == Stage.VERIFY and manager.desktop.station == station and ok:
		state.verified_web = true
		_check_verified()


func _check_verified() -> void:
	_show_steps()
	if state.verified_ping and state.verified_web:
		hud.show_toast("ทดสอบผ่าน: ping ได้รับการตอบกลับ และเปิดเว็บไซต์ได้", 4.0)
		_enter(Stage.TELL)


# ---------------------------------------------------------------- the PC

## F at the PC case: look at the port (symptoms), test the cable or replace
## the card, depending on the stage.
func use_tower(player: Node) -> void:
	if _busy:
		return
	_player = player
	match stage:
		Stage.SWAP:
			if cable_home_pending:
				await plug_back(player)
		Stage.INSPECT:
			if not saw_port:
				await look_at_port(player)
		Stage.TEST:
			_hold(player, true)
			asking = "tool"
			var options := TOOLS.duplicate()
			options.shuffle()
			choice.open("ตรวจสาย LAN", "ในกระเป๋าช่างมีเครื่องมือดังนี้ ควรใช้เครื่องมือใดตรวจว่าสาย LAN ส่งสัญญาณได้ครบทุกเส้น", options)
		Stage.REPLACE:
			if has_spare:
				await replace_nic(player)


## Close-up of the NIC port at the back of the case: no link LED.
func look_at_port(player: Node) -> void:
	_busy = true
	_hold(player, true)
	var port := tower.port.global_position
	var out := tower.port.global_basis.z.normalized()
	var eye := port + out * 0.08 + Vector3.UP * 0.035
	await _camera_to(player, Transform3D(Basis.looking_at(port - eye, Vector3.UP), eye))
	hud.show_toast("พอร์ตของการ์ดเครือข่าย (NIC) ไม่มีไฟสถานะ", 3.5)
	await get_tree().create_timer(2.2, false).timeout
	saw_port = true
	await _camera_back(player)
	_busy = false
	_after_symptom()


func _after_symptom() -> void:
	if saw_screen and saw_port and stage == Stage.INSPECT:
		_enter(Stage.TEST)
	else:
		_refresh_spots()
		_show_steps()
		_refresh_marker()


## The cable comes off her PC by hand (click the plug), both heads go into
## the tester by hand (drag, PlugBoard), POWER and TEST are clicked on the
## tester itself, the LEDs scan, then the verdict.
func run_tester(player: Node) -> void:
	_busy = true
	await _camera_to(player, _port_view(tower))
	await _wait_click(tower.port.global_position, "คลิกที่หัวสาย LAN เพื่อถอดออกจากการ์ดเครือข่าย")
	await _pull_head(tower.port)
	if _cable:
		_cable.visible = false
	hud.show_toast("ถอดปลายสายอีกด้านออกจากเต้ารับ LAN ที่ผนังแล้ว", 3.0)
	if tester == null:
		tester = CableTester.make()
		tester.name = "CableTester"
		add_child(tester)
		tester.position = TESTER_AT
		tester.rotation.y = -PI * 0.5
	tester.visible = true
	tester.set_power(false)
	_rig_clear()
	_tester_rig = Node3D.new()
	_tester_rig.name = "TesterCable"
	add_child(_tester_rig)
	# One head waits on the desk in front of each socket (like Level 2).
	var heads := {}
	var views := []
	var center := tester.global_position + Vector3(0, 0.02, 0)
	var eye := center + Vector3(-0.26, 0.24, 0.0)
	var view := Transform3D(Basis.looking_at(center - eye, Vector3.UP), eye)
	views.append({"name": "เครื่องทดสอบทั้งหมด", "xform": view, "drag": true})
	var units := [["Main", "ช่อง MAIN (ตัวแม่) ระยะใกล้"], ["Remote", "ช่อง REMOTE (ตัวลูก) ระยะใกล้"]]
	for i in 2:
		var point := tester.get_plug_point(units[i][0])
		var out := point.global_basis.z.normalized()
		var head := PlugBoard.make_head(CABLE_COLOR)
		head.name = "Head%d" % i
		_tester_rig.add_child(head)
		var at := point.global_position + out * 0.07
		at.y = DESK_TOP + 0.006
		head.global_transform = Transform3D(Basis.looking_at(-out, Vector3.UP), at)
		heads["end%d" % (i + 1)] = head
		var near := point.global_position + out * 0.03
		var near_eye := near + out * 0.11 + Vector3.UP * 0.08
		views.append({"name": units[i][1], "xform": Transform3D(Basis.looking_at(near - near_eye, Vector3.UP), near_eye), "drag": true})
	_rebuild_tester_loop()
	await _camera_to(player, view)
	board.drag_plane = Plane(Vector3.ZERO, 0.0)
	board.hint = "ลากหัว RJ45 ด้านหนึ่งไปเสียบช่อง MAIN อีกด้านเสียบช่อง REMOTE  ·  กด Q / E เพื่อดูช่องใกล้ ๆ"
	board.begin(_camera_of(player), views, heads,
		{"MAIN": tester.get_plug_point("Main"), "REMOTE": tester.get_plug_point("Remote")}, PackedStringArray(["MAIN", "REMOTE"]))
	await board.all_plugged
	board.end(true)
	# Close over the buttons and both rows of LEDs.
	var top := tester.global_position + Vector3(0, 0.02, 0)
	var top_eye := top + Vector3(-0.1, 0.16, 0.0)
	await _camera_to(player, Transform3D(Basis.looking_at(top - top_eye, Vector3.UP), top_eye))
	await _wait_click(tester.button("power").global_position, "คลิกปุ่ม POWER (สีแดง) บนเครื่องทดสอบ")
	tester.press_power()
	await get_tree().create_timer(0.4, false).timeout
	await _wait_click(tester.button("test").global_position, "คลิกปุ่ม TEST (สีเหลือง) แล้วสังเกตไฟของตัวแม่และตัวลูก")
	tester.press_test(CableTester.STRAIGHT)
	await get_tree().create_timer(tester.step_time * 9 + 0.4, false).timeout
	_busy = false
	ask_verdict()


func ask_verdict() -> void:
	dialogue.ask("คุณ|ไฟของตัวแม่ (MAIN) กับตัวลูก (REMOTE) ขึ้นแบบนี้ สาย LAN เส้นนี้เป็นอย่างไร?", PackedStringArray([VERDICTS[0][1], VERDICTS[1][1]]))
	var picked: int = await dialogue.chosen
	var id: String = VERDICTS[picked][0]
	state.note_verdict(id)
	if id != Mission04State.VERDICT_RIGHT:
		Sound.play("wrong")
		hud.show_toast(VERDICT_WRONG, 4.5)
		await get_tree().create_timer(1.2, false).timeout
		ask_verdict()
		return
	Sound.play("correct")
	hud.show_toast("สาย LAN ผ่านการตรวจสอบด้วย LAN Cable Tester", 3.5)
	_busy = true
	tester.stop_test()
	tester.set_power(false)
	# Both heads come out by hand; the cable goes in the tool case.
	for end_id in ["end1", "end2"]:
		var head: Node3D = board.plugs.get(end_id)
		if head:
			await _wait_click(head.global_position, "คลิกที่หัวสายเพื่อถอดออกจากเครื่องทดสอบ")
			await _slide(head, head.global_basis.z.normalized() * 0.05)
			head.visible = false
			_rebuild_tester_loop()
	tester.visible = false
	_rig_clear()
	_give(_player, "lan_cable_teacher", "สาย LAN ของเครื่องครูสาว")
	await _camera_back(_player)
	_busy = false
	_enter(Stage.SWAP)


func _rig_clear() -> void:
	if _tester_rig:
		_tester_rig.queue_free()
		_tester_rig = null


## The cable between the two heads on the desk (redrawn as they move).
func _rebuild_tester_loop() -> void:
	if _tester_rig == null or not is_instance_valid(_tester_rig):
		return
	var old := _tester_rig.get_node_or_null("Loop")
	if old:
		old.free()
	var a_head := _tester_rig.get_node_or_null("Head0") as Node3D
	var b_head := _tester_rig.get_node_or_null("Head1") as Node3D
	if a_head == null or b_head == null or not a_head.visible or not b_head.visible:
		return
	# The cable leaves each boot straight back, then runs round the side of
	# the tester on the desk (never under or over it).
	var low := DESK_TOP + 0.005
	var a := a_head.global_transform * Vector3(0, 0, 0.034)
	var b := b_head.global_transform * Vector3(0, 0, 0.034)
	var a_out := a + a_head.global_basis.z.normalized() * 0.025
	var b_out := b + b_head.global_basis.z.normalized() * 0.025
	a_out.y = low
	b_out.y = low
	# Sideways = across the line MAIN-REMOTE (the sockets face along it).
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	if side.dot(Vector3(-1, 0, 0)) < 0.0:
		side = -side # toward the player's side of the desk
	var clear := 0.07
	var c := tester.global_position if tester else (a + b) * 0.5
	var a_side := a_out + side * ((c - a_out).dot(-side) + clear)
	var b_side := b_out + side * ((c - b_out).dot(-side) + clear)
	a_side.y = low
	b_side.y = low
	# Rounded corners (a cable bends, it does not fold).
	var pts := [a, a_out, a_out.lerp(a_side, 0.6), a_side.lerp(b_side, 0.12), a_side.lerp(b_side, 0.88), b_out.lerp(b_side, 0.6), b_out, b]
	_tester_rig.add_child(CableBuilder.build(pts, CABLE_COLOR, "Loop", 0.003))


# ---------------------------------------------------------------- swap test

## F at STAFF-PC-03: the player plugs the same cable in by hand; its LED
## lights and the computer is online; then the conclusion.
func use_swap_pc(player: Node) -> void:
	if stage != Stage.SWAP or _busy or cable_home_pending:
		return
	_busy = true
	_player = player
	_hold(player, true)
	await _plug_by_hand(player, swap_tower, "ด้านหลังคอมพิวเตอร์ STAFF-PC-03")
	_take(player, "lan_cable_teacher")
	_swap_cable = _draw_cable(swap_tower, "Desk3Cable")
	await get_tree().create_timer(0.8, false).timeout
	swap_tower.port.set_link(true)
	swap_station.network_connected = true
	hud.show_toast("STAFF-PC-03: ไฟพอร์ตติด และเชื่อมต่อเครือข่ายได้ตามปกติ", 4.0)
	await get_tree().create_timer(2.0, false).timeout
	_busy = false
	asking = "swap"
	var options := SWAPS.duplicate()
	options.shuffle()
	choice.open("ผลการทดลองสลับสาย", "นำสาย LAN เส้นเดิมของเครื่องครูสาวมาต่อกับ STAFF-PC-03 แล้ว [b]เครื่องนี้ใช้งานเครือข่ายได้ตามปกติ[/b] ผลนี้บอกอะไร?", options, false)


## After the conclusion: pull the cable out here, carry it back to her PC.
func _finish_swap() -> void:
	_busy = true
	await _wait_click(swap_tower.port.global_position, "คลิกที่หัวสายเพื่อถอดออก แล้วนำกลับไปเสียบที่เครื่องครูสาว")
	await _pull_head(swap_tower.port)
	swap_tower.port.set_link(false)
	swap_station.network_connected = false
	if _swap_cable:
		_swap_cable.queue_free()
		_swap_cable = null
	_give(_player, "lan_cable_teacher", "สาย LAN ของเครื่องครูสาว")
	cable_home_pending = true
	await _camera_back(_player)
	_busy = false
	_refresh_spots()
	_show_steps()
	_refresh_marker()


## Back at her PC: plug the cable in by hand, then the analysis.
func plug_back(player: Node) -> void:
	_busy = true
	_player = player
	_hold(player, true)
	await _plug_by_hand(player, tower, "ด้านหลังคอมพิวเตอร์ครูสาว")
	_take(player, "lan_cable_teacher")
	if _cable:
		_cable.visible = true
	hud.show_toast("เสียบสายกลับแล้ว — ไฟสถานะของการ์ดเครือข่ายยังไม่ติด", 3.5)
	await get_tree().create_timer(1.6, false).timeout
	cable_home_pending = false
	await _camera_back(player)
	_busy = false
	_enter(Stage.ANALYZE)
	_ask_fix()


# ---------------------------------------------------------------- by hand

## Close view of a case's NIC port (from behind the PC).
func _port_view(case: Mission04Tower) -> Transform3D:
	var port := case.port.global_position
	var out := case.port.global_basis.z.normalized()
	var eye := port + out * 0.08 + Vector3.UP * 0.035
	return Transform3D(Basis.looking_at(port - eye, Vector3.UP), eye)


## A wider view of the port for plugging by hand: the port and the head
## waiting in front of it.
func _plug_view(case: Mission04Tower) -> Transform3D:
	var port := case.port.global_position
	var out := case.port.global_basis.z.normalized()
	var side := case.port.global_basis.x.normalized()
	var target := port + out * 0.02 - side * 0.015
	# Little room behind the case (the wall): look down at it from above.
	var eye := target + out * 0.12 + Vector3.UP * 0.13
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


func _camera_of(player: Node) -> Camera3D:
	return player.camera if player and "camera" in player else get_viewport().get_camera_3d()


## The player drags an RJ45 head into the case's NIC port (PlugBoard);
## returns when it is in. The port then shows the plug.
func _plug_by_hand(player: Node, case: Mission04Tower, view_name: String) -> void:
	var port := case.port
	var out := port.global_basis.z.normalized()
	var side := port.global_basis.x.normalized()
	var temp := Node3D.new()
	temp.name = "HandCable"
	add_child(temp)
	var head := PlugBoard.make_head(CABLE_COLOR)
	head.name = "Head"
	temp.add_child(head)
	head.global_transform = Transform3D(port.global_basis.orthonormalized(), port.global_position + out * 0.045 - side * 0.045 + Vector3.DOWN * 0.03)
	var tail := func():
		var old := temp.get_node_or_null("Tail")
		if old:
			old.free()
		var h := head.global_transform
		var hang := h * Vector3(0, -0.015, 0.075)
		temp.add_child(CableBuilder.build([h * Vector3(0, 0, 0.033), hang, Vector3(hang.x, DESK_TOP + 0.004, hang.z)], CABLE_COLOR, "Tail", 0.003))
	tail.call()
	var moved := func(_id: String): tail.call()
	board.plug_moved.connect(moved)
	await _camera_to(player, _plug_view(case))
	board.drag_plane = Plane(out, port.global_position + out * 0.035)
	board.hint = "ลากหัว RJ45 ไปเสียบช่อง LAN ของการ์ดเครือข่าย"
	board.begin(_camera_of(player), [{"name": view_name, "xform": _plug_view(case), "drag": true}], {"cable": head}, {"nic": port}, PackedStringArray(["nic"]))
	await board.all_plugged
	board.end(true)
	board.plug_moved.disconnect(moved)
	temp.queue_free()
	port.plug(CABLE_COLOR)


## A plug comes out of its port (a short slide), the port is free.
func _pull_head(port: NetworkPort) -> void:
	var head := PlugBoard.make_head(CABLE_COLOR)
	add_child(head)
	head.global_transform = Transform3D(port.global_basis.orthonormalized(), port.global_position)
	port.unplug()
	Sound.play("crimp")
	await _slide(head, port.global_basis.z.normalized() * 0.06)
	head.queue_free()


func _slide(node: Node3D, by: Vector3) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "global_position", node.global_position + by, 0.35)
	await t.finished


## Waits until the player clicks near `world_point` (the camera is in a
## close-up, the mouse is free). Tests call click_now().
func _wait_click(world_point: Vector3, text: String) -> void:
	_click_point = world_point
	_click_waiting = true
	_click_hint.text = text
	_click_layer.visible = true
	# A soft pulsing glow on the thing to click.
	var glow := MeshInstance3D.new()
	glow.name = "ClickGlow"
	var ball := SphereMesh.new()
	ball.radius = 0.012
	ball.height = 0.024
	glow.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.82, 0.2, 0.55)
	mat.no_depth_test = true
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	glow.global_position = world_point
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector3.ONE * 1.6, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	await clicked
	pulse.kill()
	glow.queue_free()
	_click_layer.visible = false


func click_now() -> void:
	if _click_waiting:
		_click_waiting = false
		clicked.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _orbit_input(event):
		get_viewport().set_input_as_handled()
		return
	if _drag_input(event):
		get_viewport().set_input_as_handled()
		return
	if not _click_waiting or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.unproject_position(_click_point).distance_to(mb.position) < CLICK_PX:
		get_viewport().set_input_as_handled()
		Sound.play("click")
		click_now()


func _ask_fix() -> void:
	_hold(_player, true)
	asking = "fix"
	var options := []
	for id: String in Mission04State.FIXES:
		options.append([id, Mission04State.FIXES[id][0]])
	options.shuffle()
	var evidence := "[b]ผลการตรวจสอบ[/b]\n[color=#1e8a4c]✓ สาย LAN ผ่านการตรวจสอบด้วย LAN Cable Tester[/color]\n[color=#1e8a4c]✓ เมื่อนำสาย LAN เส้นเดิมไปต่อกับคอมพิวเตอร์อีกเครื่อง เครื่องนั้นใช้งานเครือข่ายได้ตามปกติ[/color]\n[color=#c0392b]✗ พอร์ตของ Network Interface Card (NIC) ในเครื่องครูสาวไม่มีไฟสถานะ[/color]"
	choice.open("จากผลการตรวจสอบ ควรดำเนินการอย่างไรต่อไป", evidence, options, false)


# ---------------------------------------------------------------- answers

func _on_picked(id: String) -> void:
	match asking:
		"tool":
			state.note_tool(id)
			if id != Mission04State.TOOL_RIGHT:
				choice.reject(id, TOOL_WRONG)
				return
			asking = ""
			choice.close()
			run_tester(_player)
		"swap":
			state.note_swap(id)
			if id != Mission04State.SWAP_RIGHT:
				choice.reject(id, SWAP_WRONG.get(id, ""))
				return
			asking = ""
			Sound.play("correct")
			choice.close()
			_finish_swap()
		"fix":
			if not state.note_fix(id):
				choice.reject(id, String(Mission04State.FIXES[id][1]))
				return
			asking = ""
			Sound.play("correct")
			choice.close()
			hud.show_toast("ไปหยิบ Network Interface Card (NIC) สำรองที่ห้องเก็บอุปกรณ์", 4.0)
			_release(_player)
			_enter(Stage.FETCH)
		"part":
			state.note_part(id)
			if id != Mission04State.PART_RIGHT:
				choice.reject(id, PART_WRONG)
				return
			asking = ""
			choice.close()
			has_spare = true
			_give(_player, "spare_nic", "การ์ดเครือข่าย (NIC) สำรอง")
			hud.show_toast("หยิบ NIC สำรองแล้ว — นำไปเปลี่ยนที่เครื่องของครูสาว", 3.5)
			_release(_player)
			_enter(Stage.REPLACE)


## Esc on a window that may be closed (the tool list, the parts box): the
## player walks away and comes back later.
func _on_choice_closed() -> void:
	if asking in ["tool", "part"]:
		asking = ""
		_release(_player)


func open_parts(player: Node) -> void:
	if stage != Stage.FETCH or _busy or choice.is_open():
		return
	_player = player
	_hold(player, true)
	asking = "part"
	var options := PARTS.duplicate()
	options.shuffle()
	choice.open("กล่องอะไหล่คอมพิวเตอร์", "เลือกอะไหล่สำรองที่ต้องนำไปเปลี่ยน", options)


# ---------------------------------------------------------------- repair

## The repair at her PC, all by hand (agreed 2026-11-13): click Power off;
## drag the power cord and the LAN plug out; hold A (counter-clockwise) to
## loosen the two cover screws; drag the cover off; touch the metal frame
## (anti-static, no score); hold A for the card's screw; drag the old card
## straight out of its slot; drag the new card in; hold D (clockwise) to
## tighten; drag the cover on; hold D for its screws; drag the power cord
## in; plug the LAN cable by hand; click Power on. The simple case (no model)
## falls back to the automatic animation.
func replace_nic(player: Node) -> void:
	_busy = true
	_hold(player, true)
	tower_spot.set_prompt("")
	if not tower.has_service():
		await _replace_auto(player)
		return
	var t := tower
	_repair_cam = true
	var back := -t.global_basis.z # out of the case's rear (world)
	var side := -t.global_basis.x # the cover's side (world)
	var to_board := -side
	# Power off at the front.
	await _look_at(player, t.rest_position("Power_Button"), t.global_basis.z, 0.22, 0.06)
	await _wait_click(t.rest_position("Power_Button"), "กดปุ่ม Power ปิดเครื่องก่อนซ่อม")
	await t.press_power_button()
	t.set_power(false)
	t.port.set_link(false)
	# Cables out at the back (drag them away from the case).
	var plug_at := t.rest_position("Power_Cable_Plug")
	await _look_at(player, plug_at, back, 0.1, 0.07)
	await _wait_drag(plug_at, plug_at + back * 0.045, func(k: float): t.set_power_plug(k), "ลากหัวปลั๊กไฟออกจาก Power Supply (ดึงตรงออกด้านหลัง)")
	var lan_at := t.port.global_position
	await _look_at(player, lan_at, back, 0.1, 0.05)
	var lan_head := PlugBoard.make_head(CABLE_COLOR)
	add_child(lan_head)
	lan_head.global_transform = Transform3D(t.port.global_basis.orthonormalized(), lan_at)
	t.port.unplug()
	if _cable:
		_cable.visible = false
	await _wait_drag(lan_at, lan_at + back * 0.05, func(k: float): lan_head.global_position = lan_at + back * 0.05 * k, "ลากหัวสาย LAN ออกจากการ์ดเครือข่าย")
	lan_head.queue_free()
	hud.show_toast("หยิบไขควงจากกระเป๋าช่าง", 2.5)
	for i in 2:
		var screw := "Cover_Screw_%d" % (i + 1)
		await _look_at(player, t.rest_position(screw), back, 0.09, 0.05)
		await _wait_hold(t.rest_position(screw), KEY_A, KEY_D, "กด A ค้างไว้ หมุนไขควงทวนเข็มนาฬิกาเพื่อคลายน็อตฝาข้าง (%d/2)" % (i + 1),
			"หมุนผิดทาง — คลายน็อตต้องหมุนทวนเข็มนาฬิกา (กด A)", func(k: float): t.set_screw(screw, k))
		t.take_screw(screw)
	# The cover side: closer views of the parts inside.
	var cover_at := t.cover.global_position
	await _look_at(player, cover_at, side, 0.42, 0.18)
	await _wait_drag(cover_at, cover_at + side * 0.12, func(k: float): t.set_cover(k), "ลากฝาข้างออก (เลื่อนออกด้านข้าง)")
	t.cover_removed()
	var frame_at := t.frame_point()
	await _look_at(player, frame_at, side, 0.2, 0.08)
	await _wait_click(frame_at, "แตะโครงเคสที่เป็นโลหะก่อน เพื่อคายประจุไฟฟ้าสถิตออกจากตัว")
	hud.show_toast("คายประจุไฟฟ้าสถิตแล้ว — ป้องกันอุปกรณ์เสียหายจากไฟฟ้าสถิต", 3.0)
	var screw_at := t.rest_position("NIC_Bracket_Screw")
	await _look_at(player, screw_at, side, 0.16, 0.08)
	await _wait_hold(screw_at, KEY_A, KEY_D, "กด A ค้างไว้ คลายน็อตยึดแผ่นเหล็กของการ์ดเครือข่าย",
		"หมุนผิดทาง — คลายน็อตต้องหมุนทวนเข็มนาฬิกา (กด A)", func(k: float): t.set_screw("NIC_Bracket_Screw", k))
	t.take_screw("NIC_Bracket_Screw")
	var card_at := t.nic.global_position
	await _look_at(player, card_at, side, 0.2, 0.1)
	await _wait_drag(card_at, card_at + side * 0.06, func(k: float): t.set_card_out(k), "ลากการ์ดเครือข่ายตัวเก่าออกจากช่อง PCIe (ดึงตรงขึ้นจากเมนบอร์ด)",
		"ต้องดึงการ์ดตรงๆ ออกจากช่อง ห้ามงัดเอียง")
	await t.card_away()
	var tray_at := t.spare_start()
	_take(player, "spare_nic")
	has_spare = false
	t.show_spare()
	await _wait_drag(tray_at, t.rest_position("PCIe_Slot_Target"), func(k: float): t.set_card_in(k), "ลากการ์ดเครือข่ายตัวใหม่ลงช่อง PCIe ให้ตรงช่อง",
		"วางการ์ดให้ตรงกับช่อง PCIe แล้วกดลงตรงๆ")
	t.card_seated()
	await _look_at(player, screw_at, side, 0.16, 0.08)
	t.return_screw("NIC_Bracket_Screw")
	await _wait_hold(screw_at, KEY_D, KEY_A, "กด D ค้างไว้ หมุนไขควงตามเข็มนาฬิกาเพื่อขันน็อตยึดการ์ด",
		"หมุนผิดทาง — ขันน็อตต้องหมุนตามเข็มนาฬิกา (กด D)", func(k: float): t.set_screw("NIC_Bracket_Screw", 1.0 - k))
	await _look_at(player, cover_at, side, 0.42, 0.18)
	t.cover_back()
	await _wait_drag(cover_at + side * 0.12, cover_at, func(k: float): t.set_cover(1.0 - k), "ลากฝาข้างกลับเข้าที่")
	t.cover_closed()
	for i in 2:
		var screw := "Cover_Screw_%d" % (i + 1)
		await _look_at(player, t.rest_position(screw), back, 0.09, 0.05)
		t.return_screw(screw)
		await _wait_hold(t.rest_position(screw), KEY_D, KEY_A, "กด D ค้างไว้ ขันน็อตยึดฝาข้างกลับ (%d/2)" % (i + 1),
			"หมุนผิดทาง — ขันน็อตต้องหมุนตามเข็มนาฬิกา (กด D)", func(k: float): t.set_screw(screw, 1.0 - k))
	await _look_at(player, plug_at, back, 0.1, 0.07)
	await _wait_drag(plug_at + back * 0.045, plug_at, func(k: float): t.set_power_plug(1.0 - k), "ลากหัวปลั๊กไฟเสียบกลับเข้า Power Supply")
	await _plug_by_hand(player, t, "ด้านหลังคอมพิวเตอร์ครูสาว")
	if _cable:
		_cable.visible = true
	await _look_at(player, t.rest_position("Power_Button"), t.global_basis.z, 0.22, 0.06)
	await _wait_click(t.rest_position("Power_Button"), "กดปุ่ม Power เปิดเครื่อง")
	await t.press_power_button()
	t.set_power(true)
	station.network_connected = true
	await get_tree().create_timer(0.6, false).timeout
	t.port.set_link(true)
	_repair_cam = false
	await _camera_to(player, _port_view(t))
	hud.show_toast("ไฟสถานะของการ์ดเครือข่ายตัวใหม่ติดแล้ว", 3.0)
	await get_tree().create_timer(1.8, false).timeout
	await _camera_back(player)
	_busy = false
	_enter(Stage.VERIFY)


# ---------------------------------------------------------------- hold / drag

## Holds until the player keeps `key` down long enough (HOLD_TIME); the
## other key shows `wrong_text`. `apply(k)` moves the part (0..1). Tests:
## hold_now().
func _wait_hold(world_point: Vector3, key: Key, wrong_key: Key, text: String, wrong_text: String, apply: Callable) -> void:
	_hold_key = key
	_hold_wrong = wrong_key
	_hold_wrong_text = wrong_text
	_hold_apply = apply
	_hold_progress = 0.0
	_hold_waiting = true
	_click_hint.text = text
	_progress_bar.value = 0.0
	_progress_bar.visible = true
	_click_layer.visible = true
	var glow := _make_glow(world_point)
	await held
	glow.queue_free()
	_progress_bar.visible = false
	_click_layer.visible = false


func hold_now() -> void:
	if _hold_waiting:
		_hold_waiting = false
		if _hold_apply.is_valid():
			_hold_apply.call(1.0)
		held.emit()


func _process_hold(delta: float) -> void:
	if not _hold_waiting:
		return
	if Input.is_key_pressed(_hold_key):
		_hold_progress = minf(_hold_progress + delta / HOLD_TIME, 1.0)
		if _hold_apply.is_valid():
			_hold_apply.call(_hold_progress)
		_progress_bar.value = _hold_progress * 100.0
		if int(_hold_progress * 12.0) != int((_hold_progress - delta / HOLD_TIME) * 12.0):
			Sound.play("snip")
		if _hold_progress >= 1.0:
			hold_now()
	elif Input.is_key_pressed(_hold_wrong):
		if _click_hint.text != _hold_wrong_text:
			Sound.play("wrong")
			_click_hint.text = _hold_wrong_text


## Waits until the player drags from `start` to `end` (world points, seen on
## screen). `apply(k)` moves the part (0..1); letting go early puts it back.
## With `slant_text`, dragging far off the line shows it and does not move.
## Tests: drag_now().
func _wait_drag(start: Vector3, end: Vector3, apply: Callable, text: String, slant_text: String = "") -> void:
	_drag_start = start
	_drag_end = end
	_drag_apply = apply
	_drag_slant_text = slant_text
	_drag_text = text
	_drag_active = false
	_drag_k = 0.0
	_drag_waiting = true
	_click_hint.text = text
	_click_layer.visible = true
	var glow := _make_glow(start)
	await dragged
	glow.queue_free()
	_click_layer.visible = false


func drag_now() -> void:
	if _drag_waiting:
		_drag_waiting = false
		_drag_active = false
		if _drag_apply.is_valid():
			_drag_apply.call(1.0)
		dragged.emit()


func _drag_input(event: InputEvent) -> bool:
	if not _drag_waiting:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var a := cam.unproject_position(_drag_start)
	var b := cam.unproject_position(_drag_end)
	var line := b - a
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var at := a.lerp(b, _drag_k)
			if at.distance_to(mb.position) < CLICK_PX:
				_drag_active = true
				_drag_from = mb.position - line * _drag_k
				return true
		elif _drag_active:
			_drag_active = false
			if _drag_k >= 0.9:
				drag_now()
			else:
				_drag_k = 0.0
				if _drag_apply.is_valid():
					_drag_apply.call(0.0)
			return true
	elif event is InputEventMouseMotion and _drag_active and line.length() > 1.0:
		var moved := (event as InputEventMouseMotion).position - _drag_from
		var along := moved.dot(line) / line.length_squared()
		var off := absf(moved.cross(line)) / line.length()
		if _drag_slant_text != "" and off > maxf(40.0, line.length() * 0.6):
			if _click_hint.text != _drag_slant_text:
				Sound.play("wrong")
				_click_hint.text = _drag_slant_text
			return true
		_click_hint.text = _drag_text
		_drag_k = clampf(along, 0.0, 1.0)
		if _drag_apply.is_valid():
			_drag_apply.call(_drag_k)
		return true
	return false


func _make_glow(world_point: Vector3) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = "ClickGlow"
	var ball := SphereMesh.new()
	ball.radius = 0.005
	ball.height = 0.01
	glow.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.82, 0.2, 0.55)
	mat.no_depth_test = true
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	glow.global_position = world_point
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector3.ONE * 1.6, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	return glow


## A close look at a point: "back" points out of the case's rear (world);
## the camera stands "dist" out and "up" above (the wall leaves little room).
func _look_at(player: Node, point: Vector3, back: Vector3, dist: float, up: float) -> void:
	var out := back.normalized()
	var eye := point + out * dist + Vector3.UP * up
	_orbit_on = false
	await _camera_to(player, Transform3D(Basis.looking_at(point - eye, Vector3.UP), eye))
	if _repair_cam:
		_orbit_target = point
		_orbit_base = Transform3D(Basis.looking_at(point - eye, Vector3.UP), eye)
		_orbit_reset()
		_orbit_on = true
		_orbit_help.visible = true


func _orbit_reset() -> void:
	_orbit_yaw = 0.0
	_orbit_pitch = 0.0
	_orbit_zoom = 1.0
	_orbit_pan = Vector3.ZERO


## Puts the camera where the free look says (around the step's part).
func _orbit_apply() -> void:
	var cam := _camera_of(_player)
	if cam == null:
		return
	var offset := _orbit_base.origin - _orbit_target
	offset = offset.rotated(Vector3.UP, _orbit_yaw)
	var right := offset.cross(Vector3.UP).normalized()
	if right.length() > 0.5:
		offset = offset.rotated(right, _orbit_pitch)
	var look := _orbit_target + _orbit_pan
	var eye := look + offset * _orbit_zoom
	cam.global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


## Free-look input; true when the event was used.
func _orbit_input(event: InputEvent) -> bool:
	if not _orbit_on:
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbit_turning = mb.pressed
				return true
			MOUSE_BUTTON_MIDDLE:
				_orbit_panning = mb.pressed
				return true
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_orbit_zoom = clampf(_orbit_zoom * (0.9 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), ORBIT_ZOOM.x, ORBIT_ZOOM.y)
					_orbit_apply()
				return true
	elif event is InputEventMouseMotion and (_orbit_turning or _orbit_panning):
		var rel := (event as InputEventMouseMotion).relative
		if _orbit_turning:
			_orbit_yaw = clampf(_orbit_yaw - rel.x * 0.006, -ORBIT_YAW_MAX, ORBIT_YAW_MAX)
			_orbit_pitch = clampf(_orbit_pitch - rel.y * 0.006, -ORBIT_PITCH_MAX, ORBIT_PITCH_MAX)
		else:
			var cam := _camera_of(_player)
			if cam:
				var dist := (_orbit_base.origin - _orbit_target).length() * _orbit_zoom
				_orbit_pan += (-cam.global_basis.x * rel.x + cam.global_basis.y * rel.y) * dist * 0.0015
				_orbit_pan = _orbit_pan.limit_length(ORBIT_PAN_MAX)
		_orbit_apply()
		return true
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
		_orbit_reset()
		_orbit_apply()
		return true
	return false


func _orbit_stop() -> void:
	_orbit_on = false
	_orbit_turning = false
	_orbit_panning = false
	if _orbit_help:
		_orbit_help.visible = false


## The simple case (no model): the automatic animation.
func _replace_auto(player: Node) -> void:
	var center := tower.global_position + Vector3(0, 0.2, 0)
	var side := -tower.global_basis.x.normalized()
	var eye := center + side * 0.55 + Vector3.UP * 0.25 + Vector3(-0.25, 0, 0)
	await _camera_to(player, Transform3D(Basis.looking_at(center - eye, Vector3.UP), eye))
	await tower.replace_nic(func(_i: int, text: String): hud.show_toast(text, Mission04Tower.STEP_TIME * 2.2))
	_take(player, "spare_nic")
	has_spare = false
	station.network_connected = true
	await _camera_to(player, _port_view(tower))
	hud.show_toast("ไฟสถานะของการ์ดเครือข่ายตัวใหม่ติดแล้ว", 3.0)
	await get_tree().create_timer(1.8, false).timeout
	await _camera_back(player)
	_busy = false
	_enter(Stage.VERIFY)


# ---------------------------------------------------------------- finish

## Builds the score, records it and shows the summary. Also used by tests.
func finish(player: Node = null) -> MissionScore:
	_timing = false
	score = state.mission_score(elapsed_sec, TIME_FULL_SEC, TIME_ZERO_SEC)
	var record := GameProgress.record_attempt(LEVEL, score, {
		"tool_first": state.tool_first, "verdict_first": state.verdict_first,
		"swap_first": state.swap_first, "fix_choices": Array(state.fix_choices),
		"part_first": state.part_first, "ping_target": state.ping_target})
	_enter(Stage.DONE)
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var next_available: bool = flow != null and flow.call("next_level_available", LEVEL)
	var tries := state.fix_choices.find(Mission04State.FIX_RIGHT) + 1
	summary.show_result(SUMMARY_TITLE, score, record, next_available, [
		["วิเคราะห์ถูก (เปลี่ยน NIC)", "เลือกถูกในครั้งที่ %d" % tries],
		["เลือกเครื่องมือตรวจสาย", "ถูกตั้งแต่ครั้งแรก" if state.tool_first == Mission04State.TOOL_RIGHT else "ผิดในครั้งแรก"],
		["อ่านผล LAN Cable Tester", "ถูก" if state.verdict_first == Mission04State.VERDICT_RIGHT else "ผิดในครั้งแรก"],
		["สรุปผลการสลับสาย", "ถูก" if state.swap_first == Mission04State.SWAP_RIGHT else "ผิดในครั้งแรก"],
		["หยิบอะไหล่", "ถูกตั้งแต่ครั้งแรก" if state.part_first == Mission04State.PART_RIGHT else "ผิดในครั้งแรก"],
		["ping หลังแก้ไข", state.ping_target + (" (Default Gateway)" if state.ping_right else "")],
	])
	finished.emit(score)
	return score


# ---------------------------------------------------------------- helpers

func _say(player: Node, speaker: Node3D, lines: PackedStringArray, unlock_after: bool = true, header: String = "") -> void:
	_busy = true
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	# Seated, she does not twist round to a player behind her chair (it
	# looked frightening); she answers while working.
	var turns: bool = speaker != null and speaker.has_method("turn_to") and player is Node3D and not (speaker == teacher and teacher.seated)
	if turns:
		await speaker.call("turn_to", player)
	dialogue.show_lines(lines, header)
	await dialogue.finished
	if turns:
		speaker.call("turn_back")
	if unlock_after and player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_busy = false


func _hold(player: Node, locked: bool) -> void:
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(locked)
	if locked:
		marker.clear()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _release(player: Node) -> void:
	_hold(player, false)
	_refresh_marker()


func _camera_to(player: Node, view: Transform3D) -> void:
	_orbit_stop()
	# Already away (e.g. the side view, then the rear view): only slide the
	# camera, so the player's eye position saved by move_camera_to is kept.
	if _view_away and player and player.has_method("_tween_camera"):
		await player.call("_tween_camera", view, VIEW_TIME)
		return
	_view_away = true
	if player and player.has_method("move_camera_to"):
		await player.move_camera_to(view, VIEW_TIME)


func _camera_back(player: Node) -> void:
	_orbit_stop()
	if player and player.has_method("return_camera"):
		await player.return_camera(VIEW_TIME)
	_view_away = false
	_release(player)


func _give(player: Node, id: String, title: String) -> void:
	var presentation: Node = player.get_node_or_null("Presentation") if player else null
	if presentation and presentation.has_method("add_item"):
		presentation.call("add_item", id, title)


func _take(player: Node, id: String) -> void:
	var presentation: Node = player.get_node_or_null("Presentation") if player else null
	if presentation and presentation.has_method("remove_item"):
		presentation.call("remove_item", id)


## The LAN cable from a case's NIC port, back over the desk edge and down
## the wall to the floor.
func _draw_cable(case: Mission04Tower, cable_name: String) -> Node3D:
	var port := case.port.global_position
	var out := case.port.global_basis.z.normalized()
	var a := port + out * 0.035
	var b := a + out * 0.05 + Vector3.DOWN * 0.04
	var wall_x := 8.93
	var points := [a, b, Vector3(wall_x, DESK_TOP - 0.01, b.z), Vector3(wall_x, 0.05, b.z + 0.05), Vector3(wall_x, 0.02, b.z + 0.4)]
	var cable := CableBuilder.build(points, CABLE_COLOR, cable_name, 0.003)
	add_child(cable)
	return cable


## The standing books at the end of desk 3 (one mesh with the cup and the
## note) stood where the PC case is: hide just the books and their label.
func _hide_books(items: Node) -> void:
	if items == null:
		return
	var invisible := StandardMaterial3D.new()
	invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	invisible.albedo_color = Color(0, 0, 0, 0)
	for node in items.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if String(mi.name).begins_with("P4_Print"):
			mi.visible = false
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m and (m.resource_name.contains("Book") or m.resource_name.contains("note") or m.resource_name.contains("frame")):
				mi.set_surface_override_material(i, invisible)


## A small labelled box of spare parts (simple boxes, no model file).
func _make_parts_box() -> Node3D:
	var root := Node3D.new()
	root.name = "SparePartsBox"
	var bin := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.36, 0.14, 0.26)
	bin.mesh = mesh
	bin.position = Vector3(0, 0.07, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.36, 0.62)
	bin.material_override = mat
	root.add_child(bin)
	var card := Mission04Tower.make_nic(false)
	root.add_child(card)
	card.position = Vector3(-0.07, 0.15, 0)
	var label := Label3D.new()
	label.text = "อะไหล่คอมพิวเตอร์"
	label.font = GameUI.FONT_BOLD
	label.font_size = 40
	label.pixel_size = 0.0009
	label.modulate = Color.WHITE
	label.outline_size = 8
	label.position = Vector3(0, 0.08, 0.131)
	root.add_child(label)
	return root
