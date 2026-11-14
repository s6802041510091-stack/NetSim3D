class_name Mission06Data
extends Resource

## Everything Mission 6 needs that is not code (ภารกิจ/ด่าน_06/README.md,
## "ร่างด่าน 6 v2", agreed with the user on 2026-11-15): the phone call, the
## e-mails, the made-up TeamViewer ID and passwords, the remote computer
## (MEETING-PC in the small meeting room), the teacher's chat replies and the
## knowledge summary. Saved as missions/mission_06/data/mission_06_data.tres.
## The ID and passwords are game data only — they belong to no real computer.

@export var mission_id: String = "mission_06"
@export var mission_title: String = "ภารกิจที่ 6: ช่วยเหลือผู้ใช้ด้วยซอฟต์แวร์ควบคุมเครื่องระยะไกล"
@export var mission_received_text: String = "ได้รับภารกิจ: ช่วยครูสาวแก้ปัญหาเสียงของเครื่องห้องประชุมเล็กด้วย TeamViewer"
@export var mission_complete_text: String = "ภารกิจสำเร็จ: ช่วยเหลือผู้ใช้ด้วยซอฟต์แวร์ควบคุมเครื่องระยะไกล"
@export var app_name: String = "TeamViewer"
@export var app_note: String = "จำลองเพื่อการศึกษา"
@export_multiline var disclaimer: String = "Simulated for education. Not affiliated with TeamViewer. Nothing connects to a real computer."

@export_group("Computers")
## Partner (the meeting-room computer). The ID stays the same; TeamViewer
## makes a new random password every time it starts again.
@export var partner_id: String = "482 731 965"
@export var partner_password: String = "N7q4P2"
@export var partner_password_after_restart: String = "Hx5t8R"
@export var partner_name: String = "MEETING-PC"
## This computer (IT-PC-01 in the Data Center) — "Allow Remote Control".
@export var own_id: String = "615 204 883"
@export var own_password: String = "k3Vd9m"

@export_group("Phone call")
@export var call_header: String = "สายเข้า: ครูสาว (ห้องประชุมเล็ก)"
## One line per message: "ผู้พูด|ข้อความ" ("**...**" = gold key words).
## The call: call_lines -> question "program" -> question "request" ->
## call_lines_after_request -> question "keep_open".
@export var call_lines: PackedStringArray = PackedStringArray()
@export var call_lines_after_request: PackedStringArray = PackedStringArray()

@export_group("Questions")
## The five choices of objective ก (user 2026-11-15), see Mission06Question.
@export var questions: Array[Mission06Question] = []

@export_group("E-mail")
@export var mail_from: String = "ครูสาว (ห้องประชุมเล็ก)"
@export var mail_to: String = "ฝ่าย IT Support"
@export var mail_subject: String = "TeamViewer เครื่องห้องประชุมเล็ก"
## {id} and {password} are filled in.
@export_multiline var mail_body: String = ""
@export var mail_subject_after_restart: String = "รหัส TeamViewer ใหม่ (เครื่องห้องประชุมเล็ก)"
@export_multiline var mail_body_after_restart: String = ""
## Seconds after the call / after the restart before the e-mail arrives.
@export_range(0.0, 60.0, 0.5) var mail_delay: float = 10.0
@export_range(0.0, 60.0, 0.5) var restart_mail_delay: float = 12.0

@export_group("Messages")
@export var msg_empty_id: String = "Please enter a Partner ID."
@export var msg_wrong_id: String = "Partner not found. Check the ID and try again."
@export var msg_partner_offline: String = "The partner is not ready (TeamViewer is not running on the remote computer)."
@export var msg_empty_password: String = "Please enter the password."
@export var msg_wrong_password: String = "Wrong password. Please check the password and try again."
@export var msg_connected: String = "Connection established"
@export var msg_partner_restarted: String = "The remote computer restarted. The session was ended."
@export var msg_partner_shut_down: String = "The remote computer was shut down. The session was ended."
@export var msg_end_confirm: String = "Do you want to end the remote control session?"
## Game panel (Thai, outside the program's look).
@export var msg_close_in_session: String = "ยังอยู่ใน Remote Session — กด End Session แล้วเลือก Disconnect ก่อนปิดโปรแกรม"
@export var msg_shutdown_in_session: String = "ยังอยู่ใน Remote Session — จบ Session ก่อนปิดคอมพิวเตอร์"
@export var msg_close_teamviewer_first: String = "ปิดโปรแกรม TeamViewer ก่อนปิดคอมพิวเตอร์"

@export_group("Remote computer")
@export var video_file: String = "คลิปนำเสนอ_กลุ่มสาระฯ.mp4"
## Not the player's business: opening it is a process mistake (privacy).
@export var private_file: String = "คะแนนสอบกลางภาค ม.2.xlsx"
@export var start_volume: int = 25
@export var volume_min: int = 50
@export var volume_max: int = 70

@export_group("Chat")
@export var teacher_name: String = "ครูสาว"
@export var chat_placeholder: String = "Type a message..."
@export var chat_teacher_hello: String = "ต่อเข้ามาได้แล้วใช่ไหมคะ ครูไม่จับเมาส์นะคะ"
## The teacher plays the clip after each message from the player and says what she hears.
@export var chat_reply_muted: String = "ลองเปิดคลิปแล้ว ยังเงียบอยู่เลยค่ะ"
@export var chat_reply_low: String = "ได้ยินแล้วค่ะ แต่เบามาก คนนั่งท้ายห้องคงไม่ได้ยิน"
@export var chat_reply_high: String = "ดังมากเลยค่ะ คนในห้องหันมามองกันหมด ช่วยลดลงหน่อยนะคะ"
@export var chat_reply_ok: String = "ได้ยินแล้วค่ะ เสียงกำลังดีเลย ขอบคุณมากนะคะ"

@export_group("Summary")
## Knowledge rows on the summary: [heading, text] pairs, "|"-separated.
@export var knowledge_rows: PackedStringArray = PackedStringArray()


static func normalize_id(text: String) -> String:
	return text.replace(" ", "").replace("-", "").strip_edges()


## IDs match with or without spaces, e.g. "482 731 965" or "482731965".
func is_partner_id(text: String) -> bool:
	var typed := normalize_id(text)
	return typed != "" and typed == normalize_id(partner_id)


func get_question(id: String) -> Mission06Question:
	for q in questions:
		if q.question_id == id:
			return q
	return null


func mail_text(body: String, password: String) -> String:
	return body.replace("{id}", partner_id).replace("{password}", password)


func validate_data() -> String:
	if normalize_id(partner_id).length() < 9:
		return "partner_id must have 9 digits"
	if partner_password == "" or partner_password_after_restart == "" or partner_password == partner_password_after_restart:
		return "two different partner passwords are needed"
	if volume_min >= volume_max or start_volume >= volume_min:
		return "start_volume < volume_min < volume_max"
	if call_lines.is_empty():
		return "call_lines is empty"
	if not "{password}" in mail_body or not "{password}" in mail_body_after_restart:
		return "both e-mails must contain {password}"
	for id in Mission06State.QUESTION_ORDER:
		var q := get_question(id)
		if q == null:
			return "the question '%s' is missing" % id
		if q.problem() != "":
			return q.problem()
	return ""
