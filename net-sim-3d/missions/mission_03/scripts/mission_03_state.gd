class_name Mission03State
extends RefCounted

## What the player did in Mission 3 and the score (ภารกิจ/ด่าน_03/README.md).
## Three sample computers in the computer room; the player runs ipconfig and
## ping on each, types what was seen into the checklist and attaches it once.
##   correctness 30: 10 per computer whose whole row is right
##   process 50:     per computer 15 (pinged its Default Gateway 5, typed
##                   IP / Subnet Mask / Gateway right 5, status right 5)
##                   + 5 for never trying to change the system
##   time 20:        measured for real

const TARGETS := ["TEACHER-PC", "PC-R1-L1", "PC-R5-R2"]
const TITLES := {"TEACHER-PC": "คอมพิวเตอร์ครู", "PC-R1-L1": "คอมพิวเตอร์นักเรียนหน้าห้อง", "PC-R5-R2": "คอมพิวเตอร์นักเรียนหลังห้อง"}
## The back computer: bad crimp, link up but every ping times out.
const FAULTY := "PC-R5-R2"
const REPLY := "reply"
const TIMEOUT := "timeout"
const NORMAL := "normal"
const ABNORMAL := "abnormal"
const ROW_POINTS := 10
const STEP_POINTS := 5
const SAFE_POINTS := 5

## host -> {"ip", "mask", "gateway", "reply": bool} (what the computer really shows)
var expected := {}
## host -> commands seen on that computer: {"ipconfig": bool, "ping": bool,
## "ping_gateway": bool}
var activity := {}
## host -> the attached row {"ip", "mask", "gateway", "ping", "status"}
var records := {}
## True once the player tried to change the system (first try costs 5).
var altered := false
## What was tried (for the teacher report), e.g. "ipconfig /release".
var harm_attempts := PackedStringArray()
var report_confirmed := false


func set_expected(host: String, ip: String, mask: String, gateway: String, reply: bool) -> void:
	expected[host] = {"ip": ip, "mask": mask, "gateway": gateway, "reply": reply}


func _act(host: String) -> Dictionary:
	if not activity.has(host):
		activity[host] = {"ipconfig": false, "ping": false, "ping_gateway": false}
	return activity[host]


func note_ipconfig(host: String) -> void:
	if host in TARGETS and not records.has(host):
		_act(host)["ipconfig"] = true


## A finished ping on `host` to `target` (as typed).
func note_ping(host: String, target: String) -> void:
	if not host in TARGETS or records.has(host):
		return
	var act := _act(host)
	act["ping"] = true
	if expected.has(host) and target.strip_edges() == String(expected[host]["gateway"]):
		act["ping_gateway"] = true


## Both commands were run here, so the row may be attached.
func ready_to_attach(host: String) -> bool:
	var act: Dictionary = activity.get(host, {})
	return bool(act.get("ipconfig", false)) and bool(act.get("ping", false)) and not records.has(host)


## Attaches the row once. Values are compared without spaces.
func attach(host: String, ip: String, mask: String, gateway: String, ping: String, status: String) -> bool:
	if not host in TARGETS or records.has(host) or not ping in [REPLY, TIMEOUT] or not status in [NORMAL, ABNORMAL]:
		return false
	records[host] = {"ip": _clean(ip), "mask": _clean(mask), "gateway": _clean(gateway), "ping": ping, "status": status}
	return true


static func _clean(text: String) -> String:
	return text.strip_edges().replace(" ", "")


func all_attached() -> bool:
	return records.size() == TARGETS.size()


## Records the first try to change the system. Returns true the first time.
func note_harm(what: String) -> bool:
	harm_attempts.append(what)
	if altered:
		return false
	altered = true
	return true


func values_right(host: String) -> bool:
	var r: Dictionary = records.get(host, {})
	var e: Dictionary = expected.get(host, {})
	return not r.is_empty() and not e.is_empty() and r["ip"] == e["ip"] and r["mask"] == e["mask"] and r["gateway"] == e["gateway"]


func ping_right(host: String) -> bool:
	var r: Dictionary = records.get(host, {})
	return not r.is_empty() and r["ping"] == (REPLY if bool(expected[host]["reply"]) else TIMEOUT)


func status_right(host: String) -> bool:
	var r: Dictionary = records.get(host, {})
	return not r.is_empty() and r["status"] == (NORMAL if bool(expected[host]["reply"]) else ABNORMAL)


func pinged_gateway(host: String) -> bool:
	return bool(activity.get(host, {}).get("ping_gateway", false))


func row_right(host: String) -> bool:
	return values_right(host) and ping_right(host) and status_right(host)


func correctness_points() -> int:
	var total := 0
	for host: String in TARGETS:
		if row_right(host):
			total += ROW_POINTS
	return total


## Right decisions / all decisions: per computer the gateway ping, the values
## and the status (3 x 3), plus not changing the system: 10 x 5 points.
func decision_counts() -> Vector2i:
	var ok := 0
	for host: String in TARGETS:
		if pinged_gateway(host):
			ok += 1
		if values_right(host):
			ok += 1
		if status_right(host):
			ok += 1
	if not altered:
		ok += 1
	return Vector2i(ok, TARGETS.size() * 3 + 1)


func process_points() -> int:
	return decision_counts().x * STEP_POINTS


func mission_score(elapsed_sec: float, time_full_sec: float, time_zero_sec: float) -> MissionScore:
	var counts := decision_counts()
	var score := MissionScore.compute(correctness_points(), counts.x, counts.y, elapsed_sec, time_full_sec, time_zero_sec)
	score.mistakes = mistakes()
	return score


## Short Thai lines for the summary's "จุดที่ผิดพลาด".
func mistakes() -> PackedStringArray:
	var out := PackedStringArray()
	for host: String in TARGETS:
		var name := "%s (%s)" % [TITLES[host], host]
		if not records.has(host):
			out.append("%s: ยังไม่ได้แนบผลการตรวจ" % name)
			continue
		var e: Dictionary = expected[host]
		if not pinged_gateway(host):
			out.append("%s: ไม่ได้ ping ไปที่ Default Gateway (%s) ที่อ่านได้จาก ipconfig" % [name, e["gateway"]])
		var r: Dictionary = records[host]
		for field: Array in [["ip", "IP Address"], ["mask", "Subnet Mask"], ["gateway", "Default Gateway"]]:
			if r[field[0]] != e[field[0]]:
				out.append("%s: บันทึก %s เป็น \"%s\" แต่ผลคำสั่งคือ %s" % [name, field[1], r[field[0]], e[field[0]]])
		if not ping_right(host):
			out.append("%s: บันทึกผล ping ผิด — ผลจริงคือ %s" % [name, "ได้รับการตอบกลับ (Reply)" if bool(e["reply"]) else "หมดเวลา (Request timed out)"])
		if not status_right(host):
			out.append("%s: เลือกสถานะผิด — เครื่องนี้%s" % [name, "ปกติ ติดต่อ Default Gateway ได้" if bool(e["reply"]) else "ผิดปกติ ติดต่อ Default Gateway ไม่ได้"])
	if altered:
		out.append("พยายามเปลี่ยนแปลงระบบ (%s) — ภารกิจนี้ให้ตรวจและบันทึกเท่านั้น" % harm_attempts[0])
	return out
