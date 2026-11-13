class_name Mission05Data
extends Resource

## Everything Mission 5 needs that is not code: names in the simulated alert
## and scan, the answers and their hints (the score is Mission05State).
## Saved as missions/mission_05/data/mission_05_data.tres (edit in the Inspector).
## All file and program names are made up for the game — nothing real is scanned.
## The program itself is in English like the real Windows 11 (user,
## 2026-11-13); the hints are Thai and shown by the game, not by the program.

@export var mission_id: String = "mission_05"
@export var mission_title: String = "ภารกิจที่ 5: ตรวจสอบความปลอดภัยคอมพิวเตอร์ห้องเรียน"
@export var app_name: String = "Windows Security"
@export_multiline var disclaimer: String = "โปรแกรมจำลองภายในเกมเพื่อการศึกษาเท่านั้น ไม่ใช่ Windows Security จริง ไม่ได้สแกนเครื่องของคุณ และไม่เกี่ยวข้องกับ Microsoft"

@export_group("Firewall")
## The program that asks to connect (Windows Security Alert).
@export var firewall_app: String = "Unknown_Update.exe"
@export var firewall_publisher: String = "Unknown"
@export var firewall_path: String = "C:\\Users\\Student\\Downloads\\Unknown_Update.exe"
## ids: allow (Allow access), block (Cancel — right), disable (switch off).
@export var firewall_choices: Array[SecurityChoice] = []
@export_multiline var firewall_reason: String = ""

@export_group("Anti-Virus")
## Seconds the simulated scan takes (the design asks for 3–5 s).
@export_range(1.0, 10.0, 0.5) var scan_seconds: float = 4.0
@export var threat_file: String = "Student_Game_Crack.exe"
@export var threat_path: String = "C:\\Users\\Student\\Downloads\\Student_Game_Crack.exe"
## Detection name in the style Windows uses (made up).
@export var threat_name: String = "HackTool:Win32/GameCrack.A"
@export var threat_risk: String = "High"
## ids: remove, quarantine (right), allow (on device), exclude (Add an
## exclusion), realtime_off (Real-time protection switched off).
@export var threat_choices: Array[SecurityChoice] = []
@export_multiline var threat_reason: String = ""

@export_group("Report")
@export var submit_button_text: String = "ส่งผลการตรวจสอบ"
@export_multiline var submitted_message: String = "ส่งผลการตรวจสอบแล้ว — ออกจากคอมพิวเตอร์ แล้วแจ้งผลกับครูประจำห้องคอมพิวเตอร์"


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
	var needed := {"Firewall": ["allow", "block", "disable"], "Anti-Virus": ["remove", "quarantine", "allow", "exclude", "realtime_off"]}
	for pair in [["Firewall", firewall_choices], ["Anti-Virus", threat_choices]]:
		var list: Array = pair[1]
		for id in needed[pair[0]]:
			if _find(list, id) == null:
				return "%s needs the choice '%s'" % [pair[0], id]
		var correct := 0
		for c in list:
			if c.is_correct:
				correct += 1
			elif c.hint.strip_edges() == "":
				return "%s choice '%s' needs a hint" % [pair[0], c.choice_id]
		if correct != 1:
			return "%s needs exactly 1 correct choice (found %d)" % [pair[0], correct]
	return ""
