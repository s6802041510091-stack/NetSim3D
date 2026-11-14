class_name Mission06State
extends RefCounted

## What the player did in Mission 6 and the score — v2 (ภารกิจ/ด่าน_06/README.md,
## "ร่างด่าน 6 v2", agreed with the user on 2026-11-15). A fresh state every
## time the level starts (nothing carried over), like Levels 1–5.
##
##   correctness 30:
##     connected to MEETING-PC                                         10
##     the sound works (the teacher confirmed in the chat)             10
##     the last session ended properly (End Session -> Disconnect)     10
##   process 50 (10 points x 5, user 2026-11-15):
##     the five choices with the teacher, right first time (objective ก):
##       program (TeamViewer), request (ID + Password), keep_open (do not
##       close TeamViewer), limits (software only), password (changes)
##     Partner ID and Password right every time
##     did not open the teacher's private file
##     did not disturb the user (no Restart / Shut down of MEETING-PC)
##     waited for the teacher's confirmation before ending a session
##     closed in the right order: never during a session, and before
##       switching IT-PC-01 off
##   time 20: full up to 5 min, 0 at 15 min (placeholder until play-testing)
## Wrong steps are not applied (a message says why) and the player carries on.

const PART_POINTS := 10
const PROCESS_POINTS := 5
const PROCESS_ORDER := ["program", "request", "keep_open", "limits", "password", "first_try", "privacy", "no_disruption", "confirmed_first", "close_order"]
## The five choices, in the order they come (three in the call, two in the chat).
const QUESTION_ORDER := ["program", "request", "keep_open", "limits", "password"]
const CALL_QUESTIONS := ["program", "request", "keep_open"]
const CHAT_QUESTIONS := ["limits", "password"]

var call_answered := false
## E-mails delivered to the player's computer and whether the newest was read.
var mails_delivered := 0
var mail_read := false
var tv_opened := false
## The partner's TeamViewer is running (false after a Restart / Shut down,
## until the teacher sends the new password).
var partner_online := false
var partner_password := ""
var connected_once := false
var session_active := false
## How the last session ended: "" (none yet), "disconnect", "restart", "shutdown".
var last_end := ""
var remote_muted := true
var remote_volume := 25
var teacher_confirmed := false
## A session was ended with Disconnect before the teacher had confirmed.
var ended_before_confirm := false
var opened_private_file := false
## "restart" / "shutdown" of MEETING-PC, in order.
var disruptive := PackedStringArray()
var wrong_id_count := 0
var wrong_password_count := 0
## The close button / Esc pressed in TeamViewer during a Remote Session.
var close_in_session_count := 0
## Tried to switch IT-PC-01 off at the end while TeamViewer was still open.
var shutdown_with_tv_count := 0
var question_answers := {"program": [], "request": [], "keep_open": [], "limits": [], "password": []}
var question_done := {"program": false, "request": false, "keep_open": false, "limits": false, "password": false}
var tv_closed := false
var computer_off := false


func reset(data: Mission06Data) -> void:
	partner_password = data.partner_password
	remote_volume = data.start_volume


## The sound as the teacher hears it: "muted", "low", "high" or "ok".
func sound_result(data: Mission06Data) -> String:
	if remote_muted:
		return "muted"
	if remote_volume < data.volume_min:
		return "low"
	if remote_volume > data.volume_max:
		return "high"
	return "ok"


## Everything inside TeamViewer is done; closing it and switching off is left.
func work_done() -> bool:
	return teacher_confirmed and last_end == "disconnect" and not session_active


func ready_to_finish() -> bool:
	return work_done() and tv_closed


# ---------------------------------------------------------------- questions

func note_question(id: String, option_index: int, right: bool) -> bool:
	if not question_answers.has(id) or question_done[id]:
		return false
	question_answers[id].append(option_index)
	question_done[id] = right
	return right


func question_first_right(id: String) -> bool:
	return question_done.get(id, false) and question_answers[id].size() == 1


## The next chat question still to answer ("" when none).
func next_chat_question() -> String:
	for id: String in CHAT_QUESTIONS:
		if not question_done[id]:
			return id
	return ""


# ---------------------------------------------------------------- score

func process_decisions() -> Dictionary:
	var d := {}
	for id: String in QUESTION_ORDER:
		d[id] = question_first_right(id)
	d["first_try"] = wrong_id_count == 0 and wrong_password_count == 0
	d["privacy"] = not opened_private_file
	d["no_disruption"] = disruptive.is_empty()
	d["confirmed_first"] = not ended_before_confirm
	d["close_order"] = close_in_session_count == 0 and shutdown_with_tv_count == 0 and computer_off
	return d


func correctness_points() -> int:
	return PART_POINTS * (int(connected_once) + int(teacher_confirmed) + int(last_end == "disconnect"))


func process_points() -> int:
	var points := 0
	for v in process_decisions().values():
		points += PROCESS_POINTS * int(v)
	return points


func mission_score(elapsed_sec: float, time_full_sec: float, time_zero_sec: float) -> MissionScore:
	var d := process_decisions()
	var ok := 0
	for v in d.values():
		ok += int(v)
	var score := MissionScore.compute(correctness_points(), ok, PROCESS_ORDER.size(), elapsed_sec, time_full_sec, time_zero_sec)
	score.process = clampi(process_points(), 0, MissionScore.PROCESS_MAX)
	score.mistakes = mistakes()
	return score


func wrong_count() -> int:
	return wrong_id_count + wrong_password_count + int(opened_private_file) + disruptive.size() \
		+ int(ended_before_confirm) + close_in_session_count + shutdown_with_tv_count + _question_wrongs()


func _question_wrongs() -> int:
	var n := 0
	for id: String in QUESTION_ORDER:
		n += question_answers[id].size() - int(question_done[id])
	return n


## Short Thai lines for the summary's "จุดที่ผิดพลาด".
func mistakes() -> PackedStringArray:
	var out := PackedStringArray()
	if wrong_id_count > 0:
		out.append("กรอก Partner ID ผิด %d ครั้ง — ตรวจ ID จากอีเมลของครูก่อนกด Connect" % wrong_id_count)
	if wrong_password_count > 0:
		out.append("กรอก Password ผิด %d ครั้ง — Password แยกตัวพิมพ์เล็ก-ใหญ่ และเปลี่ยนใหม่ทุกครั้งที่เครื่องปลายทางเปิด TeamViewer ใหม่" % wrong_password_count)
	if opened_private_file:
		out.append("เปิดไฟล์คะแนนสอบของครูระหว่าง Remote Session — ฝ่าย IT ต้องไม่เปิดไฟล์ส่วนตัวของผู้ใช้ ทำเฉพาะงานที่ได้รับอนุญาต")
	if "restart" in disruptive:
		out.append("สั่ง Restart เครื่องห้องประชุม — Session หลุด ครูต้องส่งรหัสใหม่ และรบกวนครูที่ใกล้ถึงเวลานำเสนอ")
	if "shutdown" in disruptive:
		out.append("สั่งปิดเครื่องห้องประชุม — Session หลุด ครูต้องเปิดเครื่องและส่งรหัสใหม่ และรบกวนครูที่ใกล้ถึงเวลานำเสนอ")
	if ended_before_confirm:
		out.append("จบ Session ก่อนครูยืนยันว่าได้ยินเสียง — ควรให้ผู้ใช้ทดสอบและยืนยันผลก่อนยุติการเชื่อมต่อ")
	if close_in_session_count > 0:
		out.append("พยายามปิดโปรแกรมระหว่าง Remote Session — ต้องกด End Session แล้วเลือก Disconnect ก่อน")
	if shutdown_with_tv_count > 0:
		out.append("สั่งปิดคอมพิวเตอร์ขณะ TeamViewer ยังเปิดอยู่ — ควรปิดโปรแกรมก่อนแล้วจึงปิดเครื่อง")
	var lessons := {
		"program": "เลือกโปรแกรมเชื่อมต่อระยะไกลผิด — TeamViewer ใช้ควบคุมเครื่องระยะไกล ส่วน TeamSpeak ใช้คุยเสียง และโปรแกรมของ Adobe ใช้ทำงานกราฟิก/วิดีโอ",
		"request": "ขอข้อมูลจากครูผิด — TeamViewer ใช้ Your ID และ Password ของเครื่องปลายทาง ไม่ใช้ IP Address หรือรหัสผ่าน Windows",
		"keep_open": "ตอบผิดเรื่องปิดหน้าต่าง TeamViewer — เครื่องปลายทางต้องเปิดโปรแกรมและต่อเครือข่ายไว้ จึงจะเชื่อมต่อได้",
		"limits": "ตอบผิดเรื่องข้อจำกัด — ควบคุมระยะไกลแก้ได้เฉพาะด้านซอฟต์แวร์ อุปกรณ์ที่เสียต้องไปแก้ที่เครื่อง",
		"password": "ตอบผิดเรื่องรหัส — Password ของ TeamViewer เปลี่ยนใหม่ทุกครั้งที่เปิดโปรแกรม รหัสเก่าใช้ไม่ได้แล้ว",
	}
	for id: String in QUESTION_ORDER:
		if question_answers[id].is_empty() and id in CHAT_QUESTIONS and computer_off:
			out.append("จบ Session ก่อนตอบคำถามของครูในแชท (%s)" % lessons[id].split(" — ")[1])
		elif not question_answers[id].is_empty() and not question_first_right(id):
			out.append(lessons[id])
	return out
