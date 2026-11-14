class_name Mission05State
extends RefCounted

## What the player did in Mission 5 and the score — v2.1 (ภารกิจ/ด่าน_05/README.md,
## "ร่างข้อเสนอปรับปรุงด่าน 5 (v2)" + the user's changes of 2026-11-15: no quiz
## pop-ups on the desktop — understanding is measured by what the player
## checks inside Windows Security, which is more realistic; the firewall alerts
## show when the Firewall page is opened). A fresh state every time the level
## starts (nothing carried over).
##
##   correctness 30: 3 main decisions x 10 — right on the 1st try 10, 2nd 5, later 0
##     1. SchoolLab Classroom alert: Allow access with Private networks ticked
##        (Private + Public is accepted the same, only a note: user 2026-11-15)
##     2. Unknown_Update.exe alert: Cancel (keep it blocked)
##     3. GameCrack threat: Quarantine
##   process 50 (weighted):
##     1. the connection problem: the first section opened is
##        Firewall & network protection                                    10
##     2. checked the rules: opened "Allow an app through firewall" after
##        answering the alerts (SchoolLab allowed, Unknown_Update blocked)   10
##     3. the suspicious file: after the firewall is fixed, the first other
##        section opened is Virus & threat protection (a firewall does not
##        remove files)                                                    10
##     4. never lowered the protection: Firewall off, Real-time protection
##        off, Add an exclusion, Allow on device                           10
##     5. opened Protection history before submitting AND everything was
##        green when "ส่งผลการตรวจสอบ" was first pressed                      5
##     6. what the player tells the teacher (the report, a choice: what was
##        done + asking him to warn the students), right first time        5
##   time 20: full up to 7 min, 0 at 17 min (placeholder until play-testing)
##
## Wrong answers are never applied: the game shows a Thai hint and the player
## tries again (the hints/arrow/steps stay as they are — user 2026-11-14).

enum ScanStatus { NOT_SCANNED, SCANNED }

const PART_POINTS := 10
const PART_POINTS_2ND := 5
## Process points per decision (they add up to MissionScore.PROCESS_MAX).
const PROCESS_WEIGHTS := {
	"firewall_first": 10, "checked_rules": 10, "virus_first": 10, "kept_protection": 10,
	"checked_history": 5, "report": 5,
}
## Order of the process decisions on the summary.
const PROCESS_ORDER := ["firewall_first", "checked_rules", "virus_first", "kept_protection", "checked_history", "report"]

## The two firewall alerts, in the order they are shown (user: SchoolLab first).
const ALERT_SCHOOL := "school"
const ALERT_UNKNOWN := "unknown"
const ALERT_ORDER := [ALERT_SCHOOL, ALERT_UNKNOWN]
## Answers to an alert: allow_private / allow_both / allow_public / allow_none / block.
const SCHOOL_RIGHT := ["allow_private", "allow_both"]
const UNKNOWN_RIGHT := "block"
## The firewall switch on a network profile page (always wrong).
const FIREWALL_OFF := "disable"
## Anti-Virus answers: quarantine / remove / allow (on device) / exclude
## (Add an exclusion) / realtime_off (Real-time protection switched off).
const THREAT_RIGHT := "quarantine"
const LOWERING_THREAT := ["allow", "exclude", "realtime_off"]
## The one choice left: how to report to the teacher, in the room (user
## 2026-11-15; not on the desktop).
const QUESTION_ORDER := ["report"]
## Sections of Windows Security (the sidebar).
const TOOL_FIREWALL := "firewall"
const TOOL_VIRUS := "virus"
const TOOL_HISTORY := "history"
## "Allow an app through firewall" (a page inside the Firewall section).
const TOOL_RULES := "firewall_rules"

var app_opened := false
## Every answer to each alert, in order (plain Arrays: a packed array inside a
## Dictionary would be copied on append).
var alert_answers := {ALERT_SCHOOL: [], ALERT_UNKNOWN: []}
## How many times the firewall switch was turned off.
var firewall_off_count := 0
## The player has opened the right section for each problem.
var conn_matched := false
var file_matched := false
## The first section opened for each problem ("" = none yet).
var conn_tool_first := ""
var file_tool_first := ""
## "Allow an app through firewall" opened after both alerts (before the report).
var rules_checked := false
## Every answer to the teacher's question (option indexes in the data).
var question_answers := {"report": []}
var question_done := {"report": false}
var scan_status: ScanStatus = ScanStatus.NOT_SCANNED
var threat_quarantined := false
var threat_choices := PackedStringArray()
## Protection history opened after the quarantine and before the report.
var history_checked := false
## Status when "ส่งผลการตรวจสอบ" was first pressed: "protected" / "early".
var submit_first := ""
var report_submitted := false
var told_teacher := false


# ---------------------------------------------------------------- firewall

func alert_done(key: String) -> bool:
	return is_alert_right(key, _last(alert_answers[key]))


func alerts_done() -> bool:
	return alert_done(ALERT_SCHOOL) and alert_done(ALERT_UNKNOWN)


## The alert to answer now ("" when both are done). SchoolLab comes first.
func next_alert() -> String:
	for key: String in ALERT_ORDER:
		if not alert_done(key):
			return key
	return ""


## The unknown program is blocked (the program's wording).
var firewall_blocked: bool:
	get:
		return alert_done(ALERT_UNKNOWN)


static func is_alert_right(key: String, answer: String) -> bool:
	if key == ALERT_SCHOOL:
		return answer in SCHOOL_RIGHT
	return answer == UNKNOWN_RIGHT


## The answer id for an alert from the button and the two network boxes.
static func alert_answer(allow: bool, private_on: bool, public_on: bool) -> String:
	if not allow:
		return "block"
	if private_on and public_on:
		return "allow_both"
	if private_on:
		return "allow_private"
	if public_on:
		return "allow_public"
	return "allow_none"


## Records an answer to the alert in front. Returns true when it is right.
func note_alert(key: String, answer: String) -> bool:
	# Only the alert in front can be answered (SchoolLab first).
	if not alert_answers.has(key) or key != next_alert():
		return false
	alert_answers[key].append(answer)
	return is_alert_right(key, answer)


func note_firewall_off() -> void:
	firewall_off_count += 1


## A section or page of the program was opened (Home does not count). Before
## the alerts are answered the first one is process 1; after them, the first
## one other than the Firewall is process 3. The rules page and Protection
## history are the two checks (process 2 and 5).
func note_section(section: String) -> void:
	if section == "" or section == "home":
		return
	if section == TOOL_RULES:
		if alerts_done() and not report_submitted:
			rules_checked = true
		section = TOOL_FIREWALL
	if not alerts_done():
		if conn_tool_first == "":
			conn_tool_first = section
		if section == TOOL_FIREWALL:
			conn_matched = true
	elif not threat_quarantined and section != TOOL_FIREWALL:
		if file_tool_first == "":
			file_tool_first = section
		if section == TOOL_VIRUS:
			file_matched = true
	if section == TOOL_HISTORY and threat_quarantined and not report_submitted:
		history_checked = true


# ---------------------------------------------------------------- the teacher's question

## "report" once the report is given to the teacher, otherwise "".
func pending_question() -> String:
	if told_teacher and not question_done["report"]:
		return "report"
	return ""


func note_question(id: String, option_index: int, right: bool) -> bool:
	if not question_answers.has(id) or question_done[id]:
		return false
	question_answers[id].append(option_index)
	question_done[id] = right
	return right


func question_first_right(id: String) -> bool:
	return question_done.get(id, false) and question_answers[id].size() == 1


# ---------------------------------------------------------------- anti-virus

## Quick scan opens once both firewall alerts are answered.
func can_scan() -> bool:
	return alerts_done()


func note_threat(id: String) -> bool:
	threat_choices.append(id)
	threat_quarantined = threat_quarantined or id == THREAT_RIGHT
	return id == THREAT_RIGHT


# ---------------------------------------------------------------- report

## Security status: Protected (both alerts answered right, scanned, quarantined).
func is_protected() -> bool:
	return alerts_done() and scan_status == ScanStatus.SCANNED and threat_quarantined


## "ส่งผลการตรวจสอบ" pressed. True when the report is accepted (Protected).
func note_submit() -> bool:
	if submit_first == "":
		submit_first = "protected" if is_protected() else "early"
	if is_protected():
		report_submitted = true
	return report_submitted


# ---------------------------------------------------------------- score

static func _part_points(tries: int) -> int:
	match tries:
		1:
			return PART_POINTS
		2:
			return PART_POINTS_2ND
	return 0


## How many tries the right answer took (0 = not answered right yet).
func alert_tries(key: String) -> int:
	var list: Array = alert_answers[key]
	for i in list.size():
		if is_alert_right(key, list[i]):
			return i + 1
	return 0


static func tries(choices: PackedStringArray, right: String) -> int:
	return choices.find(right) + 1


func correctness_points() -> int:
	return _part_points(alert_tries(ALERT_SCHOOL)) + _part_points(alert_tries(ALERT_UNKNOWN)) + _part_points(tries(threat_choices, THREAT_RIGHT))


## Process 4. Allowing Unknown_Update.exe is scored in correctness, not here.
func kept_protection() -> bool:
	for id in LOWERING_THREAT:
		if id in threat_choices:
			return false
	return threat_quarantined and firewall_off_count == 0


## Which process decisions were right: id -> bool (PROCESS_ORDER).
func process_decisions() -> Dictionary:
	return {
		"firewall_first": conn_tool_first == TOOL_FIREWALL,
		"checked_rules": rules_checked,
		"virus_first": file_tool_first == TOOL_VIRUS,
		"kept_protection": kept_protection(),
		"checked_history": history_checked and submit_first == "protected",
		"report": question_first_right("report"),
	}


func process_points() -> int:
	var points := 0
	var d := process_decisions()
	for id: String in PROCESS_ORDER:
		if d[id]:
			points += PROCESS_WEIGHTS[id]
	return points


func decision_counts() -> Vector2i:
	var ok := 0
	for v in process_decisions().values():
		ok += int(v)
	return Vector2i(ok, PROCESS_ORDER.size())


func mission_score(elapsed_sec: float, time_full_sec: float, time_zero_sec: float) -> MissionScore:
	var counts := decision_counts()
	var score := MissionScore.compute(correctness_points(), counts.x, counts.y, elapsed_sec, time_full_sec, time_zero_sec)
	# The decisions are weighted (10/10/10/10/5/5), not equal shares.
	score.process = clampi(process_points(), 0, MissionScore.PROCESS_MAX)
	score.mistakes = mistakes()
	return score


## Every wrong pick (sections, alerts, firewall switch, threat, early submit, report).
func wrong_count() -> int:
	var n := 0
	for key: String in ALERT_ORDER:
		var t := alert_tries(key)
		n += (t - 1) if t > 0 else alert_answers[key].size()
	n += int(conn_tool_first != "" and conn_tool_first != TOOL_FIREWALL)
	n += int(file_tool_first != "" and file_tool_first != TOOL_VIRUS)
	n += firewall_off_count
	n += threat_choices.size() - int(THREAT_RIGHT in threat_choices)
	n += int(submit_first == "early")
	n += question_answers["report"].size() - int(question_done["report"])
	return n


## Short Thai lines for the summary's "จุดที่ผิดพลาด".
func mistakes() -> PackedStringArray:
	var out := PackedStringArray()
	if conn_tool_first != "" and conn_tool_first != TOOL_FIREWALL:
		out.append("เปิดส่วนอื่นก่อน Firewall & network protection — การควบคุมการเชื่อมต่อผ่านเครือข่ายเป็นหน้าที่ของ Firewall")
	var school: Array = alert_answers[ALERT_SCHOOL]
	if "block" in school:
		out.append("ปิดกั้น SchoolLab Classroom ที่ครูต้องใช้สอน — Firewall มีหน้าที่ควบคุมการเชื่อมต่อ ควรอนุญาตโปรแกรมที่ทราบผู้ผลิตและจำเป็นต้องใช้")
	if "allow_public" in school or "allow_none" in school:
		out.append("อนุญาต SchoolLab โดยไม่ได้เลือก Private networks — เครือข่ายของโรงเรียนเป็น Private โปรแกรมจึงใช้งานไม่ได้")
	for a: String in alert_answers[ALERT_UNKNOWN]:
		if a.begins_with("allow"):
			out.append("กด Allow access ให้ Unknown_Update.exe ที่ไม่ทราบผู้ผลิต — ควรกด Cancel ให้การเชื่อมต่อยังถูกปิดกั้นไว้")
			break
	if firewall_off_count > 0:
		out.append("ปิด Microsoft Defender Firewall — การปิด Firewall ทำให้เครื่องไม่มีการป้องกันการเชื่อมต่อ")
	if report_submitted and not rules_checked:
		out.append("ไม่ได้เปิด Allow an app through firewall ตรวจว่ากฎของ Firewall เป็นไปตามที่ตั้งใจ")
	if file_tool_first != "" and file_tool_first != TOOL_VIRUS:
		out.append("เปิดส่วนอื่นก่อน Virus & threat protection — Firewall ไม่ได้กำจัดไฟล์อันตราย การตรวจหาไฟล์เป็นหน้าที่ของ Anti-Virus")
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
	if report_submitted and not history_checked:
		out.append("ไม่ได้เปิด Protection history ยืนยันว่ากักกันไฟล์แล้วก่อนส่งผล")
	if question_answers["report"].size() > 0 and not question_first_right("report"):
		out.append("รายงานผลให้ครูไม่ตรงกับสิ่งที่ทำ — ควรบอกสิ่งที่ทำจริง (อนุญาต SchoolLab, ปิดกั้นโปรแกรมแปลก, กักกันไฟล์) และฝากครูเตือนนักเรียนเรื่องโปรแกรมเถื่อน")
	return out


static func _last(list: Array) -> String:
	return String(list[list.size() - 1]) if list.size() > 0 else ""
