class_name Mission05Controller
extends Node

## Runs Level 5 in the school map (added by GameFlow.configure_level),
## ภารกิจ/ด่าน_05/README.md as agreed with the user on 2026-11-13:
##   1. the desk phone in IT Support rings: the computer-room teacher (male)
##      says PC-R3-L2 shows a security warning -> the timer starts
##   2. go to PC-R3-L2 in the computer room (its screen glows red), sit down
##   3. open Windows Security (simulated) from the desktop
##   4. problem 1 -> Firewall, block the unknown connection
##   5. problem 2 -> Anti-Virus, scan
##   6. quarantine the file found
##   7. check the status is Protected, press "ส่งผลการตรวจสอบ"
##   8. tell the teacher (he works at TEACHER-PC in the same room)
##   -> score (Mission05State, 30/50/20) -> summary
## No supervisor report in this level, and nothing is carried over between
## plays: every start is a fresh Mission05State.

signal call_answered
signal finished(score: MissionScore)
signal replay_requested
signal menu_requested
signal next_requested

const LEVEL := 5
const TEACHER := "ครูประจำห้องคอมพิวเตอร์"
const HOST := "PC-R3-L2"
const RECEIVED := "ได้รับภารกิจ: ตรวจสอบความปลอดภัยของคอมพิวเตอร์นักเรียน"
const COMPLETED := "ภารกิจสำเร็จ: ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน"
const SUMMARY_TITLE := "ด่านที่ 5  ·  ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน"
## Time score (placeholder until play-testing): full up to 5 min, 0 at 15 min.
const TIME_FULL_SEC := 300.0
const TIME_ZERO_SEC := 900.0

## "**...**" marks the important words, shown in gold by DialogueBox.
const CALL := [
	"ครูประจำห้องคอมพิวเตอร์|สวัสดีครับ ผมครูประจำห้องคอมนะครับ คอมพิวเตอร์นักเรียนเครื่อง **PC-R3-L2** ขึ้น**ข้อความเตือนด้านความปลอดภัย** ผมยังไม่กล้าให้นักเรียนใช้ ช่วยมาตรวจสอบให้หน่อยได้ไหมครับ",
	"คุณ|ได้ครับ ผมจะไปตรวจสอบให้",
]
const WHERE := [
	"ครูประจำห้องคอมพิวเตอร์|เครื่องที่ขึ้นข้อความเตือนคือ **PC-R3-L2** ครับ อยู่**แถวที่ 3 ฝั่งซ้าย เครื่องที่ 2** จอเป็นสีแดงอยู่",
]
const WAITING := [
	"ครูประจำห้องคอมพิวเตอร์|ตามสบายเลยครับ ตรวจเสร็จแล้วบอกผมด้วยนะครับ",
]
const TELL := [
	"คุณ|ตรวจสอบเรียบร้อยแล้วครับ ผม**ปิดกั้นการเชื่อมต่อ**จากโปรแกรมที่ไม่รู้จัก และ**กักกันไฟล์ต้องสงสัย**ที่ตรวจพบแล้ว เครื่องกลับมาอยู่ในสถานะ**ได้รับการป้องกัน**แล้วครับ",
	"ครูประจำห้องคอมพิวเตอร์|ขอบคุณมากครับ แสดงว่า **Firewall** ช่วยกันการเชื่อมต่อแปลก ๆ ส่วน **Anti-Virus** ช่วยจัดการไฟล์อันตรายใช่ไหมครับ ตอนนี้ให้นักเรียนใช้เครื่องได้แล้ว",
]
const DONE_LINE := [
	"ครูประจำห้องคอมพิวเตอร์|ขอบคุณอีกครั้งนะครับ",
]

## The mission's steps in order (ObjectiveHUD.set_steps, the standard).
const HEADING := "ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน"
const STEPS := [
	"รับสายโทรศัพท์ที่โต๊ะทำงานในห้อง IT Support",
	"ไปที่คอมพิวเตอร์นักเรียน PC-R3-L2 ในห้องคอมพิวเตอร์",
	"เปิดโปรแกรม Windows Security",
	"จัดการการเชื่อมต่อจากโปรแกรมที่ไม่รู้จัก",
	"สแกนหาไฟล์ต้องสงสัย",
	"จัดการไฟล์ที่ตรวจพบ",
	"ตรวจสถานะความปลอดภัย แล้วส่งผลการตรวจสอบ",
	"แจ้งผลให้ครูประจำห้องคอมพิวเตอร์",
]

enum Stage { CALL, GO, OPEN, FIREWALL, SCAN, QUARANTINE, SUBMIT, TELL, DONE }

var stage := Stage.CALL
var elapsed_sec := 0.0
var state := Mission05State.new()
var score: MissionScore
var hud: ObjectiveHUD
var dialogue: DialogueBox
var summary: MissionSummary
var marker: ObjectiveMarker
var manager: ComputerManager
var station: ComputerStation
var phone: DeskPhone
var teacher: Node3D
var teacher_talk: Talkable
## The Windows Security window now open (null when closed).
var app: WindowsSecurity
var _timing := false
var _busy := false


func _ready() -> void:
	var world := get_parent()
	# The program on the desktop works on this play's progress.
	WindowsSecurity.shared_state = state
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
	manager = world.get_node_or_null("Computers") as ComputerManager
	if manager:
		station = manager.find_host(HOST)
		if station == null:
			push_error("Mission 5: computer %s not found" % HOST)
		var desktop := manager.desktop
		if desktop:
			desktop.desktop_ready.connect(_on_desktop_ready)
			desktop.app_opened.connect(_on_app_opened)
			desktop.visibility_changed.connect(_refresh_marker)
	phone = world.get_node_or_null("DeskPhone") as DeskPhone
	if phone:
		phone.ringing = true
		phone.answered.connect(_on_phone)
	teacher = world.get_node_or_null("TeacherMale") as Node3D
	if teacher:
		teacher_talk = Talkable.new()
		teacher_talk.name = "Talk"
		teacher_talk.display_name = TEACHER
		teacher.add_child(teacher_talk)
		teacher_talk.talked.connect(_on_teacher_talked)
	_enter(Stage.CALL)


func _exit_tree() -> void:
	if WindowsSecurity.shared_state == state:
		WindowsSecurity.shared_state = null


func _process(delta: float) -> void:
	if _timing:
		elapsed_sec += delta
	# The objective tab folds while the desktop has the screen.
	var desktop_on := manager != null and manager.desktop != null and manager.desktop.visible
	hud.set_auto_collapsed(desktop_on)


# ---------------------------------------------------------------- stages

func _enter(next: Stage) -> void:
	stage = next
	# The computer can be used once the call is answered (the mission's order).
	if station:
		station.collision_layer = 0 if stage == Stage.CALL else ComputerStation.COLLISION_LAYER
	if teacher_talk:
		match stage:
			Stage.CALL, Stage.DONE:
				teacher_talk.prompt = ""
			Stage.TELL:
				teacher_talk.prompt = "กด F เพื่อแจ้งผลให้" + TEACHER
			_:
				teacher_talk.prompt = "กด F เพื่อคุยกับ" + TEACHER
	_show_steps()
	_refresh_marker()


## Follows the program's progress (the player may close it and open it again).
func _sync() -> void:
	if stage < Stage.OPEN or stage >= Stage.TELL:
		return
	var next := Stage.OPEN
	if state.app_opened:
		next = Stage.FIREWALL
	if state.firewall_blocked:
		next = Stage.SCAN
	if state.scan_status == Mission05State.ScanStatus.SCANNED:
		next = Stage.QUARANTINE
	if state.threat_quarantined:
		next = Stage.SUBMIT
	if state.report_submitted:
		next = Stage.TELL
	if next != stage:
		_enter(next)
	else:
		_show_steps()


func _show_steps() -> void:
	if stage == Stage.DONE:
		hud.set_objective("")
		return
	var hint := ""
	match stage:
		Stage.CALL:
			hint = "โทรศัพท์บนโต๊ะทำงานของคุณในห้อง IT Support กำลังดัง มองที่โทรศัพท์แล้วกด F"
		Stage.GO:
			hint = "ห้องคอมพิวเตอร์ แถวที่ 3 ฝั่งซ้าย เครื่องที่ 2 (จอสีแดง) กด F ที่คอมพิวเตอร์"
		Stage.OPEN:
			hint = "เปิดโปรแกรม Windows Security จากไอคอนบน Desktop"
		Stage.FIREWALL:
			hint = "มีโปรแกรมที่ไม่รู้จักขอเชื่อมต่อผ่านเครือข่าย เลือกส่วนที่ใช้จัดการปัญหานี้จากเมนูด้านซ้าย" if not state.conn_matched else "อ่านหน้าต่าง Windows Security Alert แล้วเลือกวิธีจัดการ"
		Stage.SCAN:
			hint = "ครูพบข้อความเตือนว่าอาจมีไฟล์อันตราย เลือกส่วนที่ใช้ตรวจหาไฟล์อันตรายจากเมนูด้านซ้าย" if not state.file_matched else "กด Quick scan แล้วรอจนสแกนเสร็จ"
		Stage.QUARANTINE:
			hint = "คลิกรายการภัยคุกคามเพื่อดูรายละเอียด เลือกวิธีจัดการ แล้วกด Start actions"
		Stage.SUBMIT:
			hint = "ตรวจสถานะในหน้า Home แล้วกด \"ส่งผลการตรวจสอบ\" (มุมขวาล่าง)"
		Stage.TELL:
			hint = "ครูนั่งที่โต๊ะครูหน้าห้องคอมพิวเตอร์ กด F ที่ครู"
	if _away_from_computer() and stage >= Stage.OPEN and stage <= Stage.SUBMIT:
		hint = "กลับไปที่ PC-R3-L2 (กด F ที่คอมพิวเตอร์) • " + hint
	hud.set_steps(ObjectiveHUD.sequence(STEPS, int(stage)), hint, HEADING, "ภารกิจที่ 5")


func _away_from_computer() -> bool:
	return manager == null or manager.desktop == null or not manager.desktop.visible


func _refresh_marker() -> void:
	if not _away_from_computer():
		marker.clear()
		return
	match stage:
		Stage.CALL:
			if phone:
				marker.point_at_position(phone.global_position, 0.35)
		Stage.TELL:
			if teacher:
				marker.point_at(teacher, 1.75)
		Stage.DONE:
			marker.clear()
		_:
			if station:
				marker.point_at_position(station.global_position, 0.4)
	_show_steps()


# ---------------------------------------------------------------- people

func _on_phone(player: Node) -> void:
	if stage != Stage.CALL or _busy:
		return
	phone.ringing = false
	await _say(player, null, PackedStringArray(CALL), true, "สายเข้า: ครูประจำห้องคอมพิวเตอร์ (ห้องคอมพิวเตอร์)")
	_timing = true
	hud.show_toast(RECEIVED)
	call_answered.emit()
	_enter(Stage.GO)


func _on_teacher_talked(player: Node) -> void:
	if _busy:
		return
	match stage:
		Stage.CALL:
			return
		Stage.TELL:
			state.told_teacher = true
			await _say(player, teacher, PackedStringArray(TELL), false)
			hud.show_toast(COMPLETED)
			finish(player)
		Stage.DONE:
			await _say(player, teacher, PackedStringArray(DONE_LINE))
		Stage.GO:
			await _say(player, teacher, PackedStringArray(WHERE))
		_:
			await _say(player, teacher, PackedStringArray(WAITING))


# ---------------------------------------------------------------- computer

func _on_desktop_ready() -> void:
	if stage == Stage.GO and manager.desktop.station == station:
		_enter(Stage.OPEN)
	_refresh_marker()


func _on_app_opened(app_id: String, node: Node) -> void:
	if app_id != "windows_security" or not node is WindowsSecurity:
		return
	app = node as WindowsSecurity
	for sig in ["section_opened", "firewall_choice_made", "scan_finished", "threat_choice_made", "mistake_made", "protected_reached", "report_submitted"]:
		if not app.is_connected(sig, _on_app_changed):
			app.connect(sig, _on_app_changed)
	app.tree_exiting.connect(func(): app = null, CONNECT_ONE_SHOT)
	_sync()


## Any change in the program (the signals carry different arguments).
func _on_app_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_sync()


# ---------------------------------------------------------------- end

func finish(player: Node = null) -> MissionScore:
	_timing = false
	score = state.mission_score(elapsed_sec, TIME_FULL_SEC, TIME_ZERO_SEC)
	var record := GameProgress.record_attempt(LEVEL, score, {
		"conn_tool_first": state.conn_tool_first, "file_tool_first": state.file_tool_first,
		"firewall_choices": Array(state.firewall_choices), "threat_choices": Array(state.threat_choices),
		"submit_first": state.submit_first})
	_enter(Stage.DONE)
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var next_available: bool = flow != null and flow.call("next_level_available", LEVEL)
	summary.show_result(SUMMARY_TITLE, score, record, next_available, [
		["Firewall: ปิดกั้นการเชื่อมต่อ", _tries_text(Mission05State.tries(state.firewall_choices, Mission05State.FIREWALL_RIGHT))],
		["Anti-Virus: Quarantine", _tries_text(Mission05State.tries(state.threat_choices, Mission05State.THREAT_RIGHT))],
		["ปัญหาการเชื่อมต่อ → Firewall", "ถูกตั้งแต่ครั้งแรก" if state.conn_tool_first == Mission05State.TOOL_FIREWALL else "ผิดในครั้งแรก"],
		["ไม่ปิด Firewall", "ถูก" if not Mission05State.FIREWALL_OFF in state.firewall_choices else "เคยเลือกปิด Firewall"],
		["ไฟล์ต้องสงสัย → Anti-Virus", "ถูกตั้งแต่ครั้งแรก" if state.file_tool_first == Mission05State.TOOL_VIRUS else "ผิดในครั้งแรก"],
		["ไม่ Allow / ไม่ Add Exclusion", "ถูก" if state.threat_choices.size() > 0 and state.threat_choices[0] == Mission05State.THREAT_RIGHT else "เคยเลือกผิด"],
		["ตรวจสถานะก่อนส่งผล", "Protected" if state.submit_first == "protected" else "ส่งก่อนสถานะเป็น Protected"],
	])
	finished.emit(score)
	return score


static func _tries_text(tries: int) -> String:
	return "ถูกในครั้งที่ %d" % tries if tries > 0 else "-"


# ---------------------------------------------------------------- helpers

func _say(player: Node, speaker: Node3D, lines: PackedStringArray, unlock_after: bool = true, header: String = "") -> void:
	_busy = true
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var turns: bool = speaker != null and speaker.has_method("turn_to") and player is Node3D
	if turns:
		await speaker.call("turn_to", player)
	dialogue.show_lines(lines, header)
	await dialogue.finished
	if turns and is_instance_valid(speaker):
		speaker.call("turn_back")
	if unlock_after and player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_busy = false
