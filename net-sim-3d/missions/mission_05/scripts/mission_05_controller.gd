class_name Mission05Controller
extends Node

## Runs Level 5 in the school map (added by GameFlow.configure_level),
## ภารกิจ/ด่าน_05/README.md — v2.1 agreed with the user on 2026-11-15:
##   1. the desk phone in IT Support rings: the computer-room teacher (male)
##      says PC-R3-L2 shows a security warning and that the class needs the
##      school's SchoolLab Classroom -> the timer starts
##   2. go to PC-R3-L2 in the computer room (its monitor shows a Windows
##      Security warning: SecurityWarningScreen), sit down
##   3. open Windows Security (simulated) from the desktop
##   4. Firewall & network protection: the two "Windows Security Alert"
##      dialogs come up — SchoolLab Classroom (allow on Private) then
##      Unknown_Update.exe (Cancel); checking "Allow an app through firewall"
##      afterwards is a process point
##   5. Virus & threat protection: Quick scan
##   6. quarantine the threat (two affected files)
##   7. check the status (Protection history is a process point), press
##      "ส่งผลการตรวจสอบ"
##   8. tell the teacher (he works at TEACHER-PC in the same room) and answer
##      his "how do we stop this happening again?"
##   -> score (Mission05State, 30/50/20) -> summary
## No quiz pop-ups on the desktop (user 2026-11-15): what the player checks in
## the program is the evidence. No supervisor report in this level, and
## nothing is carried over between plays. The hints, the arrow and the step
## tracker stay as in the other levels (user 2026-11-14).

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
## Time score (placeholder until play-testing, user 2026-11-15): full up to
## 7 min, 0 at 17 min.
const TIME_FULL_SEC := 420.0
const TIME_ZERO_SEC := 1020.0
## Pause after a wrong answer before the question comes back with its hint.
const RETRY_DELAY := 0.6

## "**...**" marks the important words, shown in gold by DialogueBox.
const CALL := [
	"ครูประจำห้องคอมพิวเตอร์|สวัสดีครับ ผมครูประจำห้องคอมนะครับ คอมพิวเตอร์นักเรียนเครื่อง **PC-R3-L2** ขึ้น**ข้อความเตือนด้านความปลอดภัย** ผมยังไม่กล้าให้นักเรียนใช้",
	"ครูประจำห้องคอมพิวเตอร์|อ้อ เมื่อเช้าผมเพิ่งลงโปรแกรม **SchoolLab Classroom** ของโรงเรียนไว้ทุกเครื่อง คาบนี้**ต้องใช้ส่งหน้าจอผมไปที่เครื่องนักเรียน** ช่วยมาดูให้หน่อยได้ไหมครับ",
	"คุณ|ได้ครับ ผมจะไปตรวจสอบให้",
]
## The moment the player walks into the computer room (user 2026-11-15).
const GREET := [
	"ครูประจำห้องคอมพิวเตอร์|อ้าว คุณช่างมาพอดีเลย คอมที่เสียคือ**คอมเครื่องนี้**ครับ",
]
## The computer room (x from its door at -3.11, z between its end walls).
const ROOM_MIN := Vector2(-2.7, -11.5)
const ROOM_MAX := Vector2(10.0, 10.0)
## The watching student looks at the player within this distance (m).
const WATCHER_LOOK := 2.4
const WHERE := [
	"ครูประจำห้องคอมพิวเตอร์|เครื่องที่ขึ้นข้อความเตือนคือ **PC-R3-L2** ครับ อยู่**แถวที่ 3 ฝั่งซ้าย เครื่องที่ 2** หน้าจอขึ้น**กล่องเตือนสีแดงของ Windows Security** อยู่ครับ",
]
const WAITING := [
	"ครูประจำห้องคอมพิวเตอร์|ตามสบายเลยครับ ตรวจเสร็จแล้วบอกผมด้วยนะครับ คาบนี้ผมต้องใช้ **SchoolLab Classroom** ด้วยนะครับ",
]
## The teacher asks; the player then CHOOSES what to report (user 2026-11-15).
const TELL := [
	"ครูประจำห้องคอมพิวเตอร์|ตรวจเสร็จแล้วเหรอครับ เครื่อง **PC-R3-L2** เป็นอย่างไรบ้างครับ",
]
## After the right report (the player's chosen words are said first).
const THANKS := [
	"ครูประจำห้องคอมพิวเตอร์|เข้าใจแล้วครับ ต่อไปนี้ผมจะดูแลและเตือนนักเรียนเกี่ยวกับการ**ดาวน์โหลดโปรแกรมภายนอก**นะครับ",
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
	"จัดการโปรแกรมที่ขอรับการเชื่อมต่อจากเครือข่าย",
	"สแกนหาไฟล์ต้องสงสัย",
	"จัดการไฟล์ที่ตรวจพบ",
	"ตรวจสถานะความปลอดภัย แล้วส่งผลการตรวจสอบ",
	"แจ้งผลให้ครูประจำห้องคอมพิวเตอร์",
]

enum Stage { CALL, GO, OPEN, FIREWALL, SCAN, QUARANTINE, SUBMIT, TELL, DONE }

var stage := Stage.CALL
var elapsed_sec := 0.0
var state := Mission05State.new()
var data: Mission05Data
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
## The question on screen ("" when none) and the data indexes of its buttons.
var asking := ""
var _order: Array[int] = []
var _player: Node
var _timing := false
var _busy := false
var player_node: Node3D
## The owner of PC-R3-L2 (ClassroomStudents.WATCHER), null without one.
var watcher: NpcCharacter
## "moving" (stepping aside / back), "watching", "looking" (at the player),
## "seated" (back at his PC after the fix).
var watcher_state := ""
var greeted := false


func _ready() -> void:
	var world := get_parent()
	data = load(WindowsSecurity.DATA_PATH) as Mission05Data
	# The program on the desktop works on this play's progress.
	WindowsSecurity.shared_state = state
	hud = ObjectiveHUD.new()
	hud.name = "ObjectiveHUD"
	add_child(hud)
	dialogue = DialogueBox.new()
	dialogue.name = "DialogueBox"
	add_child(dialogue)
	dialogue.chosen.connect(_on_chosen)
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
	player_node = world.get_node_or_null("ITSupportPlayer") as Node3D
	watcher = ClassroomStudents.watcher(world)
	if watcher:
		_watcher_step_aside.call_deferred()
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
	if player_node == null:
		return
	if stage == Stage.GO and not greeted and not _busy and in_computer_room(player_node.global_position):
		greeted = true
		_greet()
	_watcher_watch(desktop_on)


static func in_computer_room(p: Vector3) -> bool:
	return p.x > ROOM_MIN.x and p.x < ROOM_MAX.x and p.z > ROOM_MIN.y and p.z < ROOM_MAX.y


# ---------------------------------------------------------------- stages

func _enter(next: Stage) -> void:
	stage = next
	# The computer can be used once the call is answered (the mission's order);
	# after the report its owner sits back down at it.
	if station:
		station.collision_layer = 0 if stage == Stage.CALL or stage >= Stage.TELL else ComputerStation.COLLISION_LAYER
	if stage == Stage.TELL and watcher:
		_watcher_sit()
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
	if state.alerts_done():
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
			hint = "ห้องคอมพิวเตอร์ แถวที่ 3 ฝั่งซ้าย เครื่องที่ 2 (หน้าจอขึ้นกล่องเตือน Threats found) กด F ที่คอมพิวเตอร์"
		Stage.OPEN:
			hint = "เปิดโปรแกรม Windows Security จากไอคอนบน Desktop"
		Stage.FIREWALL:
			if not state.conn_matched:
				hint = "มีโปรแกรมขอรับการเชื่อมต่อจากเครือข่ายเข้ามาที่เครื่องนี้ (Incoming connection) เลือกส่วนที่ใช้จัดการปัญหานี้จากเมนูด้านซ้าย"
			else:
				hint = "อ่านข้อมูลในหน้าต่าง Windows Security Alert แล้วเลือกวิธีจัดการให้เหมาะกับแต่ละโปรแกรม"
		Stage.SCAN:
			hint = "ครูพบข้อความเตือนว่าอาจมีไฟล์อันตราย เลือกส่วนที่ใช้ตรวจหาไฟล์อันตรายจากเมนูด้านซ้าย" if not state.file_matched else "กด Quick scan แล้วรอจนสแกนเสร็จ"
		Stage.QUARANTINE:
			hint = "คลิกรายการภัยคุกคามเพื่อดูรายละเอียด เลือกวิธีจัดการ แล้วกด Start actions"
		Stage.SUBMIT:
			hint = "ตรวจสถานะความปลอดภัยของเครื่อง แล้วกด \"ส่งผลการตรวจสอบ\" (มุมขวาล่าง)"
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
		_show_steps()
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


## Walking into the computer room: the teacher greets the player at once and
## points out the broken computer (the arrow is already on it).
func _greet() -> void:
	_busy = true
	if player_node.has_method("set_controls_locked"):
		player_node.set_controls_locked(true)
	# The line shows straight away; the teacher turns his head meanwhile.
	if teacher and teacher.has_method("turn_to"):
		teacher.call("turn_to", player_node)
	dialogue.show_lines(PackedStringArray(GREET))
	await dialogue.finished
	if teacher and teacher.has_method("turn_back"):
		teacher.call("turn_back")
	if player_node.has_method("set_controls_locked"):
		player_node.set_controls_locked(false)
	_busy = false


## At the start: the owner of PC-R3-L2 gets up and stands beside it.
func _watcher_step_aside() -> void:
	watcher_state = "moving"
	await get_tree().process_frame
	if not is_instance_valid(watcher):
		return
	await watcher.stand_up()
	await watcher.walk_path([ClassroomStudents.WATCH_SPOT])
	await watcher.face_yaw(_watcher_yaw())
	if watcher_state == "moving":
		watcher_state = "watching"


## Facing the screen of PC-R3-L2 from the watching spot.
static func _watcher_yaw() -> float:
	var to := ClassroomStudents.screen_of(ClassroomStudents.WATCHER_HOST) - ClassroomStudents.WATCH_SPOT
	return atan2(to.x, to.z)


## Standing by the desk: he looks at the player when the player comes close,
## and back at the screen while the player works at the computer.
func _watcher_watch(desktop_on: bool) -> void:
	if watcher == null or not is_instance_valid(watcher):
		return
	var near := not desktop_on and player_node.global_position.distance_to(watcher.global_position) < WATCHER_LOOK
	if watcher_state == "watching" and near:
		watcher_state = "looking"
		watcher.turn_to(player_node)
	elif watcher_state == "looking" and not near:
		watcher_state = "watching"
		watcher.turn_back()


## The computer is fixed and the player has left it: back to his seat.
func _watcher_sit() -> void:
	if watcher_state == "seated" or watcher_state == "returning":
		return
	while watcher_state == "moving":
		await get_tree().process_frame
	watcher_state = "returning"
	watcher.turn_back()
	await get_tree().create_timer(watcher.turn_time + 0.1, false).timeout
	var seat := ClassroomStudents.seat_of(ClassroomStudents.WATCHER_HOST)
	await watcher.walk_path([seat + Vector3(0.0, 0.0, NpcCharacter.STAND_BACK)])
	await watcher.sit_down()
	watcher_state = "seated"


func _on_teacher_talked(player: Node) -> void:
	if _busy or asking != "":
		return
	match stage:
		Stage.CALL:
			return
		Stage.TELL:
			state.told_teacher = true
			_player = player
			await _say(player, teacher, PackedStringArray(TELL), false)
			# Controls stay locked: the player chooses what to report.
			_busy = true
			ask_question("report")
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


# ---------------------------------------------------------------- the teacher's question

## Shows a question with its 4 answers shuffled, one per row; `hint` (after a
## wrong answer) goes in the small line above it.
func ask_question(id: String, hint: String = "") -> void:
	var q := data.get_question(id)
	if q == null:
		return
	asking = id
	_order.clear()
	for i in q.options.size():
		_order.append(i)
	_order.shuffle()
	var answers := PackedStringArray()
	for i in _order:
		answers.append(q.options[i])
	dialogue.ask(q.speaker + "|" + q.text, answers, PackedStringArray(), 0.0, ("คำใบ้: " + hint) if hint != "" else "", true)


## The player picked button `pick` of the question on screen.
func _on_chosen(pick: int) -> void:
	if asking == "" or pick < 0 or pick >= _order.size():
		return
	var id := asking
	asking = ""
	var q := data.get_question(id)
	var right := q.is_correct(_order[pick])
	state.note_question(id, _order[pick], right)
	if not right:
		Sound.play("wrong")
		await get_tree().create_timer(RETRY_DELAY, false).timeout
		ask_question(id, q.hint)
		return
	Sound.play("correct")
	# The player says the chosen report, then the teacher answers.
	var lines := PackedStringArray(["คุณ|" + q.options[q.correct_index]])
	lines.append_array(PackedStringArray(THANKS))
	await _say(_player, teacher, lines, false)
	hud.show_toast(COMPLETED)
	finish(_player)


# ---------------------------------------------------------------- end

func finish(player: Node = null) -> MissionScore:
	_timing = false
	_busy = false
	score = state.mission_score(elapsed_sec, TIME_FULL_SEC, TIME_ZERO_SEC)
	var record := GameProgress.record_attempt(LEVEL, score, {
		"alert_answers": state.alert_answers.duplicate(true),
		"conn_tool_first": state.conn_tool_first, "file_tool_first": state.file_tool_first,
		"rules_checked": state.rules_checked,
		"firewall_off_count": state.firewall_off_count,
		"threat_choices": Array(state.threat_choices),
		"history_checked": state.history_checked,
		"submit_first": state.submit_first,
		"report_answers": state.question_answers["report"].duplicate()})
	_enter(Stage.DONE)
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var next_available: bool = flow != null and flow.call("next_level_available", LEVEL)
	var d := state.process_decisions()
	summary.show_result(SUMMARY_TITLE, score, record, next_available, [
		["SchoolLab Classroom: Allow (Private)", _tries_text(state.alert_tries(Mission05State.ALERT_SCHOOL))],
		["Unknown_Update.exe: Cancel", _tries_text(state.alert_tries(Mission05State.ALERT_UNKNOWN))],
		["Anti-Virus: Quarantine", _tries_text(Mission05State.tries(state.threat_choices, Mission05State.THREAT_RIGHT))],
		["ปัญหาการเชื่อมต่อ → Firewall", _first_text(d["firewall_first"])],
		["ตรวจกฎใน Allow an app through firewall", "ตรวจแล้ว" if d["checked_rules"] else "ไม่ได้ตรวจ"],
		["ไฟล์ต้องสงสัย → Anti-Virus", _first_text(d["virus_first"])],
		["ไม่ลดระดับการป้องกัน", "ถูก" if d["kept_protection"] else "เคยปิดหรือยกเว้นการป้องกัน"],
		["ยืนยันที่ Protection history ก่อนส่งผล", "ถูก" if d["checked_history"] else "ไม่ได้ตรวจก่อนส่งผล"],
		["รายงานผลให้ครู", _first_text(d["report"])],
	])
	finished.emit(score)
	return score


static func _tries_text(tries: int) -> String:
	return "ถูกในครั้งที่ %d" % tries if tries > 0 else "-"


static func _first_text(ok: bool) -> String:
	return "ถูกตั้งแต่ครั้งแรก" if ok else "ผิดในครั้งแรก"


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
