class_name Mission06Data
extends Resource

## Everything Mission 6 needs that is not code: the made-up TeamViewer ID and
## password, every message, the phone call, the score rules and the summary.
## Saved as missions/mission_06/data/mission_06_data.tres (edit in the Inspector).
## The ID and password are game data only — they belong to no real computer.

@export var mission_id: String = "mission_06"
@export var mission_title: String = "ภารกิจที่ 6: ช่วยเหลือผู้ใช้ด้วยซอฟต์แวร์ควบคุมเครื่องระยะไกล"
@export var mission_received_text: String = "ได้รับภารกิจ: เชื่อมต่อเครื่องครูสาวด้วย TeamViewer และแก้ไขปัญหาเสียง"
@export var mission_complete_text: String = "ภารกิจสำเร็จ: ช่วยเหลือผู้ใช้ด้วยซอฟต์แวร์ควบคุมเครื่องระยะไกล"
@export var app_name: String = "TeamViewer"
@export var app_note: String = "จำลองเพื่อการศึกษา"
@export_multiline var disclaimer: String = "โปรแกรมจำลองภายในเกมเพื่อการศึกษาเท่านั้น ไม่ใช่ TeamViewer จริง ไม่เชื่อมต่อคอมพิวเตอร์จริง ไม่ส่งข้อมูลออกจากเกม และไม่เกี่ยวข้องกับเจ้าของเครื่องหมายการค้า"

@export_group("Computers")
## Partner (the teacher's computer) — the player must type these.
@export var partner_id: String = "482 731 965"
@export var partner_password: String = "N7q4P2"
@export var partner_name: String = "TEACHER-PC"
## This computer (Data Center) — shown in "Allow Remote Control" only.
@export var own_id: String = "615 204 883"
@export var own_password: String = "k3Vd9m"

@export_group("Messages")
@export var msg_empty_id: String = "กรุณาพิมพ์ Partner ID ก่อนกด Connect"
@export var msg_wrong_id: String = "ไม่พบเครื่องปลายทาง กรุณาตรวจสอบ TeamViewer ID แล้วลองอีกครั้ง"
@export var msg_partner_not_ready: String = "ยังเชื่อมต่อไม่ได้ เครื่องปลายทางยังไม่ได้เปิด TeamViewer หรือยังไม่ได้อนุญาต (รับสายโทรศัพท์จากครูสาวก่อน)"
@export var msg_empty_password: String = "กรุณาพิมพ์ Password ก่อนกด Log On"
@export var msg_wrong_password: String = "รหัสผ่านไม่ถูกต้อง กรุณาตรวจสอบข้อมูลจากผู้ใช้ปลายทาง"
@export var msg_connected: String = "Connection established"
@export var msg_close_without_end: String = "ยังอยู่ใน Remote Session — กด End Session แล้วเลือก Disconnect ก่อนปิดโปรแกรม"
@export var msg_close_teamviewer_first: String = "ปิดโปรแกรม TeamViewer ก่อนปิดคอมพิวเตอร์"
@export var msg_end_confirm: String = "ต้องการยุติการควบคุมเครื่องปลายทางหรือไม่"
@export var msg_still_muted: String = "ยังปิดเสียงอยู่ (Mute) กดปุ่มลำโพงเพื่อเปิดเสียงก่อนทดสอบ"
@export var msg_volume_low: String = "เปิดเสียงแล้ว แต่ระดับเสียงยังเบาเกินไป กรุณาปรับให้อยู่ในระดับที่เหมาะสม"
@export var msg_volume_high: String = "ระดับเสียงดังเกินความจำเป็น กรุณาปรับให้อยู่ในช่วงที่กำหนด"
@export var teacher_confirm_line: String = "ได้ยินเสียงแล้วค่ะ ตอนนี้ใช้งานได้ตามปกติ ขอบคุณค่ะ"

@export_group("Sound problem")
@export var start_volume: int = 25
@export var volume_min: int = 50
@export var volume_max: int = 70

@export_group("Score")
@export var start_score: int = 100
@export var penalty_wrong_id: int = 5
@export var penalty_wrong_password: int = 5
@export var penalty_close_without_end: int = 10

@export_group("Phone call")
## One line per message: "ผู้พูด|ข้อความ".
@export var call_lines: PackedStringArray = PackedStringArray()

@export_group("Summary")
## One block per section: first line is the heading, the rest are bullet points.
@export var summary_sections: PackedStringArray = PackedStringArray()


static func normalize_id(text: String) -> String:
	return text.replace(" ", "").replace("-", "").strip_edges()


## IDs match with or without spaces, e.g. "482 731 965" or "482731965".
func is_partner_id(text: String) -> bool:
	var typed := normalize_id(text)
	return typed != "" and typed == normalize_id(partner_id)


## Case-sensitive, exactly as the teacher read it out.
func is_partner_password(text: String) -> bool:
	return text == partner_password


func validate_data() -> String:
	if normalize_id(partner_id).length() < 9:
		return "partner_id must have 9 digits"
	if partner_password == "":
		return "partner_password is empty"
	if volume_min >= volume_max:
		return "volume_min must be lower than volume_max"
	if call_lines.is_empty():
		return "call_lines is empty"
	return ""
