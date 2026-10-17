class_name Mission05Data
extends Resource

## Everything Mission 5 needs that is not code: texts, the simulated alert,
## the scan result, the answer buttons and the score rules.
## Saved as missions/mission_05/data/mission_05_data.tres (edit in the Inspector).
## All file and program names are made up for the game — nothing real is scanned.

@export var mission_id: String = "mission_05"
@export var mission_title: String = "ภารกิจที่ 5: ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน"
@export var app_name: String = "Windows Security"
@export var app_note: String = "จำลองเพื่อการศึกษา"
@export_multiline var disclaimer: String = "โปรแกรมจำลองภายในเกมเพื่อการศึกษาเท่านั้น ไม่ใช่ Windows Security จริง ไม่ได้สแกนเครื่องของคุณ และไม่เกี่ยวข้องกับ Microsoft"

@export_group("Score")
@export var start_score: int = 100
## Points taken for every wrong choice (Firewall or Anti-Virus).
@export var penalty_per_wrong: int = 10

@export_group("Firewall")
@export var firewall_alert: String = "โปรแกรมที่ไม่รู้จักกำลังขออนุญาตเชื่อมต่อผ่านเครือข่าย"
## Rows shown under the alert: label -> value.
@export var firewall_details: Dictionary = {
	"Application": "Unknown_Update.exe",
	"Publisher": "Unknown",
	"Connection": "Incoming connection",
	"Status": "Waiting for permission",
}
@export var firewall_choices: Array[SecurityChoice] = []
@export var firewall_done_message: String = "Unauthorized connection blocked"
@export_multiline var firewall_reason: String = ""

@export_group("Anti-Virus")
## Seconds the simulated scan takes (the design asks for 3–5 s).
@export_range(1.0, 10.0, 0.5) var scan_seconds: float = 4.0
@export var threat_file: String = "Student_Game_Crack.exe"
@export var threat_risk: String = "High"
@export var threat_choices: Array[SecurityChoice] = []
@export var threat_done_message: String = "Threat quarantined"
@export_multiline var threat_reason: String = ""

@export_group("Report")
@export var submit_button_text: String = "ส่งผลการตรวจสอบ"
@export_multiline var submitted_message: String = "ส่งผลการตรวจสอบแล้ว — ออกจากคอมพิวเตอร์ แล้วกลับไปรายงานหัวหน้างานที่ห้อง Data Center"


func get_firewall_choice(id: String) -> SecurityChoice:
	return _find(firewall_choices, id)


func get_threat_choice(id: String) -> SecurityChoice:
	return _find(threat_choices, id)


func _find(list: Array[SecurityChoice], id: String) -> SecurityChoice:
	for c in list:
		if c.choice_id == id:
			return c
	return null


## Returns "" when the data is usable, otherwise what is wrong with it.
func validate_data() -> String:
	for pair in [["Firewall", firewall_choices], ["Anti-Virus", threat_choices]]:
		var list: Array = pair[1]
		if list.size() != 3:
			return "%s needs 3 choices (found %d)" % [pair[0], list.size()]
		var correct := 0
		for c in list:
			if c.is_correct:
				correct += 1
			elif c.hint.strip_edges() == "":
				return "%s choice '%s' needs a hint" % [pair[0], c.choice_id]
		if correct != 1:
			return "%s needs exactly 1 correct choice (found %d)" % [pair[0], correct]
	return ""
