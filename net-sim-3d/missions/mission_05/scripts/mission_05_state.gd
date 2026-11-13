class_name Mission05State
extends RefCounted

## What the player did in Mission 5 and the score (ภารกิจ/ด่าน_05/README.md,
## agreed with the user on 2026-11-13). A fresh state every time the level
## starts (no progress is carried over between plays).
##   correctness 30: Firewall 15 + Anti-Virus 15 — the right answer on the 1st
##                   try is full, on the 2nd 8, later 0
##   process 50:     5 decisions x 10:
##                   (a) the connection problem: the first section opened is
##                       Firewall & network protection
##                   (b) never turned the Firewall off
##                   (c) the suspicious file: after the firewall is fixed, the
##                       first other section opened is Virus & threat protection
##                   (d) never Remove / Allow on device / Add exclusion /
##                       real-time protection off — Quarantine first
##                   (e) the status was Protected when "ส่งผลการตรวจสอบ" was first pressed
##   time 20:        measured for real
## Windows Security looks like the real Windows 11 program (user, 2026-11-13),
## so the decisions are made in its own pages: the sidebar/tiles, the firewall
## alert (Allow access / Cancel), the firewall switch, the threat actions
## (Remove / Quarantine / Allow on device), the exclusions page.

enum ScanStatus { NOT_SCANNED, SCANNED }

const DECISION_POINTS := 10
const PART_POINTS := 15
const PART_POINTS_2ND := 8
## Firewall answers: Allow access / Cancel (keeps it blocked) / switch off.
const FIREWALL_RIGHT := "block"
const FIREWALL_OFF := "disable"
## Anti-Virus answers: quarantine / remove / allow (on device) / exclude
## (Add an exclusion) / realtime_off (Real-time protection switched off).
const THREAT_RIGHT := "quarantine"
## Sections of Windows Security (the sidebar).
const TOOL_FIREWALL := "firewall"
const TOOL_VIRUS := "virus"

var app_opened := false
## The player has opened the right section for each problem.
var conn_matched := false
var file_matched := false
## The first section opened for each problem ("" = none yet).
var conn_tool_first := ""
var file_tool_first := ""
var firewall_blocked := false
var scan_status: ScanStatus = ScanStatus.NOT_SCANNED
var threat_quarantined := false
## Every answer in order (the last one is the right one).
var firewall_choices := PackedStringArray()
var threat_choices := PackedStringArray()
## Status when "ส่งผลการตรวจสอบ" was first pressed: "protected" / "early".
var submit_first := ""
var report_submitted := false
var told_teacher := false


## Security status: Protected (both parts done).
func is_protected() -> bool:
	return firewall_blocked and scan_status == ScanStatus.SCANNED and threat_quarantined


## A section of the program was opened (Home does not count). Before the
## firewall is fixed the first one is decision (a); after it, the first one
## other than the Firewall is decision (c).
func note_section(section: String) -> void:
	if section == "" or section == "home":
		return
	if not firewall_blocked:
		if conn_tool_first == "":
			conn_tool_first = section
		if section == TOOL_FIREWALL:
			conn_matched = true
	elif not threat_quarantined and section != TOOL_FIREWALL:
		if file_tool_first == "":
			file_tool_first = section
		if section == TOOL_VIRUS:
			file_matched = true


func note_firewall(id: String) -> bool:
	firewall_choices.append(id)
	firewall_blocked = firewall_blocked or id == FIREWALL_RIGHT
	return id == FIREWALL_RIGHT


func note_threat(id: String) -> bool:
	threat_choices.append(id)
	threat_quarantined = threat_quarantined or id == THREAT_RIGHT
	return id == THREAT_RIGHT


## "ส่งผลการตรวจสอบ" pressed. True when the report is accepted (Protected).
func note_submit() -> bool:
	if submit_first == "":
		submit_first = "protected" if is_protected() else "early"
	if is_protected():
		report_submitted = true
	return report_submitted


## Every wrong pick (sections, answers, early submit).
func wrong_count() -> int:
	var n := 0
	n += firewall_choices.size() - int(FIREWALL_RIGHT in firewall_choices)
	n += threat_choices.size() - int(THREAT_RIGHT in threat_choices)
	n += int(conn_tool_first != "" and conn_tool_first != TOOL_FIREWALL)
	n += int(file_tool_first != "" and file_tool_first != TOOL_VIRUS)
	n += int(submit_first == "early")
	return n


static func _part_points(choices: PackedStringArray, right: String) -> int:
	match choices.find(right):
		0:
			return PART_POINTS
		1:
			return PART_POINTS_2ND
	return 0


func correctness_points() -> int:
	return _part_points(firewall_choices, FIREWALL_RIGHT) + _part_points(threat_choices, THREAT_RIGHT)


func decision_counts() -> Vector2i:
	var ok := 0
	ok += int(conn_tool_first == TOOL_FIREWALL)
	ok += int(firewall_blocked and not FIREWALL_OFF in firewall_choices)
	ok += int(file_tool_first == TOOL_VIRUS)
	ok += int(threat_quarantined and threat_choices.size() > 0 and threat_choices[0] == THREAT_RIGHT)
	ok += int(submit_first == "protected")
	return Vector2i(ok, 5)


func process_points() -> int:
	return decision_counts().x * DECISION_POINTS


func mission_score(elapsed_sec: float, time_full_sec: float, time_zero_sec: float) -> MissionScore:
	var counts := decision_counts()
	var score := MissionScore.compute(correctness_points(), counts.x, counts.y, elapsed_sec, time_full_sec, time_zero_sec)
	score.mistakes = mistakes()
	return score


## How many tries the right answer took (0 = not answered yet).
static func tries(choices: PackedStringArray, right: String) -> int:
	return choices.find(right) + 1


## Short Thai lines for the summary's "จุดที่ผิดพลาด".
func mistakes() -> PackedStringArray:
	var out := PackedStringArray()
	if conn_tool_first != "" and conn_tool_first != TOOL_FIREWALL:
		out.append("เปิดส่วนอื่นก่อน Firewall & network protection — การควบคุมการเชื่อมต่อผ่านเครือข่ายเป็นหน้าที่ของ Firewall")
	if "allow" in firewall_choices:
		out.append("กด Allow access ให้โปรแกรมที่ไม่ทราบผู้ผลิต — ควรกด Cancel ให้การเชื่อมต่อยังถูกปิดกั้นไว้")
	if FIREWALL_OFF in firewall_choices:
		out.append("ปิด Microsoft Defender Firewall — การปิด Firewall ทำให้เครื่องไม่มีการป้องกันการเชื่อมต่อ")
	if file_tool_first != "" and file_tool_first != TOOL_VIRUS:
		out.append("เปิดส่วนอื่นก่อน Virus & threat protection — การตรวจหาและจัดการไฟล์อันตรายเป็นหน้าที่ของ Anti-Virus")
	if "remove" in threat_choices:
		out.append("เลือก Remove ทั้งที่ยังไม่ได้ยืนยันว่าไฟล์อันตราย — ควรกักกัน (Quarantine) ไว้ก่อน เพราะยังกู้คืนได้")
	if "allow" in threat_choices:
		out.append("เลือก Allow on device ให้ไฟล์ความเสี่ยงสูงทำงาน — ควรกักกัน (Quarantine) ไว้ก่อน")
	if "exclude" in threat_choices:
		out.append("เพิ่มไฟล์เป็น Exclusion — ข้อยกเว้นใช้กับไฟล์ที่ยืนยันแล้วว่าปลอดภัยเท่านั้น")
	if "realtime_off" in threat_choices:
		out.append("ปิด Real-time protection — ทำให้ Anti-Virus ไม่เฝ้าระวังไฟล์ในเครื่อง")
	if submit_first == "early":
		out.append("กดส่งผลการตรวจสอบก่อนทุกส่วนเป็นสีเขียว — ควรตรวจสถานะหลังแก้ไขก่อนส่งผล")
	return out
