class_name Mission06Controller
extends Node

## Runs Level 6 v2 in the school map (the "Mission06" node of main.tscn, kept
## only in Level 6), ภารกิจ/ด่าน_06/README.md "ร่างด่าน 6 v2", agreed with the
## user on 2026-11-15:
##   1. the desk phone in the Data Center (IT Support room) rings: the female
##      teacher is in the small meeting room, her clip has no sound; the
##      player suggests TeamViewer and asks for the ID / Password by e-mail
##   2. the e-mail arrives in the Mail app of IT-PC-01 -> read it
##   3. open TeamViewer
##   4. connect to MEETING-PC (Partner ID -> Connect -> Password -> Log On)
##   5. fix the sound (muted, 25 %) on the remote desktop
##   6. ask the teacher in the chat to play the clip; she confirms
##   7. End Session -> Disconnect
##   8. close TeamViewer, then switch IT-PC-01 off
##   -> score (Mission06State, 30/50/20) -> summary
## Restarting / shutting down MEETING-PC drops the session; the teacher starts
## TeamViewer again and e-mails the new password. Nothing is carried over
## between plays. The hints, the arrow and the step tracker work as in the
## other levels (user 2026-11-14).

signal call_answered
signal finished(score: MissionScore)
signal replay_requested
signal menu_requested
signal next_requested

const LEVEL := 6
const HOST := "IT-PC-01"
const SUMMARY_TITLE := "ด่านที่ 6  ·  ช่วยเหลือผู้ใช้ด้วยซอฟต์แวร์ควบคุมเครื่องระยะไกล"
## Time score (placeholder until play-testing, user 2026-11-15): full up to
## 5 min, 0 at 15 min, from the end of the call.
const TIME_FULL_SEC := 300.0
const TIME_ZERO_SEC := 900.0

const HEADING := "ช่วยครูสาวแก้ปัญหาเสียงจากระยะไกล"
const STEPS := [
	"รับสายโทรศัพท์ที่โต๊ะทำงานใน Data Center",
	"อ่านอีเมลจากครูสาว",
	"เปิดโปรแกรม TeamViewer",
	"เชื่อมต่อเครื่องห้องประชุมเล็ก",
	"แก้ไขปัญหาเสียงบนเครื่องปลายทาง",
	"ให้ครูลองฟังเสียงผ่านแชท และรอครูยืนยัน",
	"จบ Remote Session",
	"ปิดโปรแกรม TeamViewer แล้วปิดคอมพิวเตอร์ของคุณ",
]

enum Stage { CALL, MAIL, OPEN, CONNECT, FIX, CONFIRM, END, CLOSE, DONE }

@export var data: Mission06Data
@export var phone_path: NodePath = ^"../DeskPhone"

var stage := Stage.CALL
var elapsed_sec := 0.0
var state := Mission06State.new()
var score: MissionScore
var hud: ObjectiveHUD
var dialogue: DialogueBox
var summary: MissionSummary
var marker: ObjectiveMarker
var manager: ComputerManager
var station: ComputerStation
var phone: DeskPhone
## The TeamViewer window now open (null when closed).
var app: TeamViewerSim
var _player: Node
var _timing := false
var _busy := false


func _ready() -> void:
	if data == null:
		data = load(TeamViewerSim.DATA_PATH) as Mission06Data
	state.reset(data)
	TeamViewerSim.shared_state = state
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
	var world := get_parent()
	manager = world.get_node_or_null("Computers") as ComputerManager
	if manager:
		station = manager.find_host(HOST)
		var desktop := manager.desktop
		if desktop:
			desktop.app_opened.connect(_on_app_opened)
			desktop.mail_opened.connect(_on_mail_opened)
			desktop.shutdown_requested.connect(_on_shutdown)
			desktop.visibility_changed.connect(_refresh_marker)
	phone = get_node_or_null(phone_path) as DeskPhone
	if phone:
		phone.ringing = true
		phone.answered.connect(_on_phone)
	_enter(Stage.CALL)


func _exit_tree() -> void:
	if TeamViewerSim.shared_state == state:
		TeamViewerSim.shared_state = null


func _process(delta: float) -> void:
	if _timing:
		elapsed_sec += delta
	var desktop_on := manager != null and manager.desktop != null and manager.desktop.visible
	hud.set_auto_collapsed(desktop_on)


# ---------------------------------------------------------------- stages

func _enter(next: Stage) -> void:
	stage = next
	# IT-PC-01 is the player's own desk computer: usable all the time.
	_show_steps()
	_refresh_marker()


func _sync() -> void:
	if stage == Stage.CALL or stage == Stage.DONE:
		return
	var next := Stage.MAIL
	if state.mail_read:
		next = Stage.CONNECT if state.tv_opened else Stage.OPEN
	if state.session_active:
		next = Stage.CONFIRM if state.sound_result(data) == "ok" else Stage.FIX
		if state.teacher_confirmed:
			next = Stage.END
	if state.work_done():
		next = Stage.CLOSE
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
			hint = "โทรศัพท์บนโต๊ะทำงานของคุณใน Data Center กำลังดัง มองที่โทรศัพท์แล้วกด F"
		Stage.MAIL:
			hint = "รออีเมลจากครูสาว แล้วเปิดอ่านในแอป Mail ของคอม IT-PC-01" if state.mails_delivered == 0 or _away_from_computer() else "เปิดแอป Mail แล้วอ่านอีเมลจากครูสาว"
		Stage.OPEN:
			hint = "เปิดโปรแกรม TeamViewer จาก Desktop"
		Stage.CONNECT:
			hint = "รอครูสาวเปิด TeamViewer ใหม่และส่งรหัสมาทางอีเมล" if not state.partner_online else "กรอก Partner ID แล้วกด Connect จากนั้นกรอก Password แล้วกด Log On"
		Stage.FIX:
			hint = "หาสาเหตุที่เครื่องห้องประชุมไม่มีเสียง แล้วแก้ไขบนเครื่องปลายทาง"
		Stage.CONFIRM:
			hint = "พิมพ์ในแชท (Chat) ให้ครูลองเปิดคลิปฟังเสียง แล้วรอครูตอบ"
		Stage.END:
			hint = "จบ Remote Session ให้ถูกวิธี"
		Stage.CLOSE:
			hint = "ปิดโปรแกรม TeamViewer แล้วปิดคอมพิวเตอร์ของคุณ (เริ่ม › ปิดเครื่อง)"
	if _away_from_computer() and stage >= Stage.MAIL and stage <= Stage.CLOSE:
		hint = "กลับไปที่ IT-PC-01 (กด F ที่คอมพิวเตอร์) • " + hint
	hud.set_steps(ObjectiveHUD.sequence(STEPS, int(stage)), hint, HEADING, "ภารกิจที่ 6")


func _away_from_computer() -> bool:
	return manager == null or manager.desktop == null or not manager.desktop.visible or manager.desktop.station != station


func _refresh_marker() -> void:
	if not _away_from_computer():
		marker.clear()
		_show_steps()
		return
	match stage:
		Stage.CALL:
			if phone:
				marker.point_at_position(phone.global_position, 0.35)
		Stage.DONE:
			marker.clear()
		_:
			if station:
				marker.point_at_position(station.global_position, 0.4)
	_show_steps()


# ---------------------------------------------------------------- the call and the e-mails

func _on_phone(player: Node) -> void:
	if stage != Stage.CALL or _busy:
		return
	phone.ringing = false
	_player = player
	_busy = true
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	# The call with three of the player's choices (objective ก, user 2026-11-15).
	await _lines(PackedStringArray(data.call_lines))
	await ask_call_question("program")
	await ask_call_question("request")
	await _lines(PackedStringArray(data.call_lines_after_request))
	await ask_call_question("keep_open")
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_busy = false
	state.call_answered = true
	_timing = true
	hud.show_toast(data.mission_received_text)
	call_answered.emit()
	_enter(Stage.MAIL)
	_send_mail_later(data.mail_delay, false)


func _send_mail_later(seconds: float, after_restart: bool) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if stage == Stage.DONE or not is_inside_tree():
		return
	send_mail(after_restart)


## The teacher (re)starts TeamViewer and e-mails the ID and Password.
func send_mail(after_restart: bool = false) -> void:
	state.partner_online = true
	if app != null and is_instance_valid(app):
		app.partner_back_online()
	state.mails_delivered += 1
	state.mail_read = false
	if manager and manager.desktop and station:
		manager.desktop.deliver_mail(station, {
			"from": data.mail_from, "to": data.mail_to,
			"subject": data.mail_subject_after_restart if after_restart else data.mail_subject,
			"body": data.mail_text(data.mail_body_after_restart if after_restart else data.mail_body, state.partner_password),
		})
	_sync()


func _on_mail_opened(index: int) -> void:
	if station and manager.desktop.station == station and index == station.mail.size() - 1:
		state.mail_read = true
		_sync()


# ---------------------------------------------------------------- the computer

func _on_app_opened(app_id: String, node: Node) -> void:
	if app_id != "teamviewer" or not node is TeamViewerSim:
		return
	app = node as TeamViewerSim
	for sig in ["connect_attempted", "login_attempted", "session_started", "sound_changed", "teacher_replied", "private_file_opened", "mistake_made", "close_requested"]:
		if not app.is_connected(sig, _on_app_changed):
			app.connect(sig, _on_app_changed)
	if not app.session_ended.is_connected(_on_session_ended):
		app.session_ended.connect(_on_session_ended)
	app.tree_exiting.connect(func(): app = null, CONNECT_ONE_SHOT)
	_sync()


## Any change in the program (the signals carry different arguments).
func _on_app_changed(_a: Variant = null, _b: Variant = null) -> void:
	_sync()


func _on_session_ended(reason: String) -> void:
	_sync()
	if reason == "restart" or reason == "shutdown":
		# MEETING-PC is starting again; the teacher sends the new password.
		_send_mail_later(data.restart_mail_delay * (1.5 if reason == "shutdown" else 1.0), true)


## IT-PC-01 switched off (TeamViewer did not stop it, so it is closed).
func _on_shutdown() -> void:
	if stage == Stage.DONE or manager.desktop.station != station or not state.ready_to_finish():
		return
	state.computer_off = true
	_timing = false
	await get_tree().create_timer(manager.zoom_time + 0.3, false).timeout
	hud.show_toast(data.mission_complete_text)
	finish(manager.active_player if manager.active_player else _player)


# ---------------------------------------------------------------- end

func finish(player: Node = null) -> MissionScore:
	_timing = false
	score = state.mission_score(elapsed_sec, TIME_FULL_SEC, TIME_ZERO_SEC)
	var record := GameProgress.record_attempt(LEVEL, score, {
		"wrong_id": state.wrong_id_count, "wrong_password": state.wrong_password_count,
		"opened_private_file": state.opened_private_file, "disruptive": Array(state.disruptive),
		"ended_before_confirm": state.ended_before_confirm,
		"close_in_session": state.close_in_session_count, "shutdown_with_tv": state.shutdown_with_tv_count})
	_enter(Stage.DONE)
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var next_available: bool = flow != null and flow.call("next_level_available", LEVEL)
	var d := state.process_decisions()
	var rows := [
		["เชื่อมต่อ %s" % data.partner_name, "สำเร็จ" if state.connected_once else "-"],
		["แก้ปัญหาเสียง", "ครูยืนยันว่าได้ยินแล้ว" if state.teacher_confirmed else "-"],
		["จบ Remote Session", "End Session › Disconnect" if state.last_end == "disconnect" else "-"],
		["กรอก Partner ID / Password", "ถูกทุกครั้ง" if d["first_try"] else "ผิด %d ครั้ง" % (state.wrong_id_count + state.wrong_password_count)],
		["ไม่เปิดไฟล์ส่วนตัวของครู", "ถูก" if d["privacy"] else "เปิดไฟล์คะแนนสอบ"],
		["ไม่รบกวนผู้ใช้ (Restart / ปิดเครื่อง)", "ถูก" if d["no_disruption"] else "สั่ง " + ", ".join(state.disruptive)],
		["รอครูยืนยันก่อนจบ Session", "ถูก" if d["confirmed_first"] else "จบก่อนครูยืนยัน"],
		["ปิดโปรแกรมถูกลำดับ", "ถูก" if d["close_order"] else "ปิดกลาง Session หรือปิดเครื่องตอนโปรแกรมยังเปิด"],
		["คำถาม: ใช้โปรแกรมอะไร", _first_text(d["program"])],
		["คำถาม: ขอข้อมูลอะไรจากครู", _first_text(d["request"])],
		["คำถาม: ปิดหน้าต่าง TeamViewer ได้ไหม", _first_text(d["keep_open"])],
		["คำถาม: แก้อุปกรณ์ที่เสียจากระยะไกลได้ไหม", _first_text(d["limits"])],
		["คำถาม: รหัสยังใช้ได้ไหมหลังปิดโปรแกรม", _first_text(d["password"])],
	]
	for line: String in data.knowledge_rows:
		var parts := line.split("|", true, 1)
		if parts.size() == 2:
			rows.append(["ความรู้: " + parts[0], parts[1]])
	summary.show_result(SUMMARY_TITLE, score, record, next_available, rows)
	finished.emit(score)
	return score


# ---------------------------------------------------------------- helpers

## The question on screen during the call ("" when none) and the data
## indexes of its buttons (tests answer through them).
var asking := ""
var ask_order: Array[int] = []


## One choice in the call: 4 answers, stacked and shuffled. The player's line
## is said, the teacher reacts; a wrong answer gets her reaction and the
## question comes back. Only the first answer counts.
func ask_call_question(id: String) -> void:
	var q := data.get_question(id)
	if q == null:
		return
	while true:
		asking = id
		ask_order.clear()
		for i in q.options.size():
			ask_order.append(i)
		ask_order.shuffle()
		var answers := PackedStringArray()
		for i in ask_order:
			answers.append(q.options[i])
		dialogue.ask(q.prompt, answers, PackedStringArray(), 0.0, data.call_header, true)
		var pick: int = await dialogue.chosen
		var option: int = ask_order[clampi(pick, 0, ask_order.size() - 1)]
		asking = ""
		var right := q.is_correct(option)
		state.note_question(id, option, right)
		Sound.play("correct" if right else "wrong")
		await _lines(PackedStringArray(["คุณ|" + q.options[option], q.reactions[option]]))
		if right:
			return


func _lines(lines: PackedStringArray) -> void:
	dialogue.show_lines(lines, data.call_header)
	await dialogue.finished


static func _first_text(ok: bool) -> String:
	return "ถูกตั้งแต่ครั้งแรก" if ok else "ผิดในครั้งแรก / ไม่ได้ตอบ"
