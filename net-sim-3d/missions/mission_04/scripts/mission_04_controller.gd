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
	swap_spot.set_prompt("กด F เพื่อเสียบสาย LAN เส้นเดิมเข้าคอมพิวเตอร์เครื่องนี้" if stage == Stage.SWAP else "")
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
			hint = "คอมพิวเตอร์ STAFF-PC-03 โต๊ะว่างแถวเดียวกัน กด F ที่ตัวเครื่อง"
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
			marker.point_at_position(TOWER_3 + Vector3(0, 0.4, 0), 0.4)
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


## The cable comes off both ends into the tester; POWER, TEST, the LEDs
## scan; then the verdict at the bottom of the screen.
func run_tester(player: Node) -> void:
	_busy = true
	tower.port.unplug()
	if _cable:
		_cable.visible = false
	if tester == null:
		tester = CableTester.make()
		tester.name = "CableTester"
		add_child(tester)
		tester.position = TESTER_AT
		tester.rotation.y = -PI * 0.5
	tester.visible = true
	_build_tester_rig()
	var center := tester.global_position + Vector3(0, 0.02, 0)
	var eye := center + Vector3(-0.17, 0.2, 0.0)
	await _camera_to(player, Transform3D(Basis.looking_at(center - eye, Vector3.UP), eye))
	tester.press_power()
	await get_tree().create_timer(0.6, false).timeout
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
	await get_tree().create_timer(1.0, false).timeout
	tester.stop_test()
	tester.set_power(false)
	tester.visible = false
	if _tester_rig:
		_tester_rig.queue_free()
		_tester_rig = null
	tower.port.plug(CABLE_COLOR)
	if _cable:
		_cable.visible = true
	await _camera_back(_player)
	_enter(Stage.SWAP)


func _build_tester_rig() -> void:
	if _tester_rig:
		_tester_rig.queue_free()
	_tester_rig = Node3D.new()
	_tester_rig.name = "TesterCable"
	add_child(_tester_rig)
	var ends := []
	for unit in ["Main", "Remote"]:
		var point := tester.get_plug_point(unit)
		if point == null:
			continue
		var head := PlugBoard.make_head(CABLE_COLOR)
		_tester_rig.add_child(head)
		head.global_transform = point.global_transform
		ends.append(point.global_transform * Vector3(0, 0, 0.034))
	if ends.size() == 2:
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var low := DESK_TOP + 0.006
		var mid := (a + b) * 0.5 + Vector3(-0.16, 0, 0)
		_tester_rig.add_child(CableBuilder.build([a, Vector3(a.x - 0.05, low, a.z), Vector3(mid.x, low, mid.z), Vector3(b.x - 0.05, low, b.z), b], CABLE_COLOR, "Loop", 0.003))


# ---------------------------------------------------------------- swap test

## F at STAFF-PC-03: the same cable goes in, its LED lights and the
## computer is online; then the conclusion.
func use_swap_pc(player: Node) -> void:
	if stage != Stage.SWAP or _busy:
		return
	_busy = true
	_player = player
	_hold(player, true)
	tower.port.unplug()
	if _cable:
		_cable.visible = false
	swap_tower.port.plug(CABLE_COLOR)
	_swap_cable = _draw_cable(swap_tower, "Desk3Cable")
	var port := swap_tower.port.global_position
	var out := swap_tower.port.global_basis.z.normalized()
	var eye := port + out * 0.08 + Vector3.UP * 0.035
	await _camera_to(player, Transform3D(Basis.looking_at(port - eye, Vector3.UP), eye))
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


func _finish_swap() -> void:
	swap_tower.port.set_link(false)
	swap_tower.port.unplug()
	swap_station.network_connected = false
	if _swap_cable:
		_swap_cable.queue_free()
		_swap_cable = null
	tower.port.plug(CABLE_COLOR)
	if _cable:
		_cable.visible = true
	await _camera_back(_player)
	_enter(Stage.ANALYZE)
	_ask_fix()


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

## The agreed animation at her PC case, then the link LED.
func replace_nic(player: Node) -> void:
	_busy = true
	_hold(player, true)
	tower_spot.set_prompt("")
	var center := tower.global_position + Vector3(0, 0.2, 0)
	var side := -tower.global_basis.x.normalized() # the cover's side
	var eye := center + side * 0.55 + Vector3.UP * 0.25 + Vector3(-0.25, 0, 0)
	await _camera_to(player, Transform3D(Basis.looking_at(center - eye, Vector3.UP), eye))
	await tower.replace_nic(func(_i: int, text: String): hud.show_toast(text, Mission04Tower.STEP_TIME * 2.2))
	_take(player, "spare_nic")
	has_spare = false
	station.network_connected = true
	var port := tower.port.global_position
	var out := tower.port.global_basis.z.normalized()
	var rear := port + out * 0.08 + Vector3.UP * 0.035
	await _camera_to(player, Transform3D(Basis.looking_at(port - rear, Vector3.UP), rear))
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
	if speaker and speaker.has_method("turn_to") and player is Node3D:
		await speaker.call("turn_to", player)
	dialogue.show_lines(lines, header)
	await dialogue.finished
	if speaker and speaker.has_method("turn_back"):
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
	# Already away (e.g. the side view, then the rear view): only slide the
	# camera, so the player's eye position saved by move_camera_to is kept.
	if _view_away and player and player.has_method("_tween_camera"):
		await player.call("_tween_camera", view, VIEW_TIME)
		return
	_view_away = true
	if player and player.has_method("move_camera_to"):
		await player.move_camera_to(view, VIEW_TIME)


func _camera_back(player: Node) -> void:
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
			if m and m.resource_name.contains("Book"):
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
