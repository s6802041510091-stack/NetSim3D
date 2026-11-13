class_name Mission04State
extends RefCounted

## What the player did in Mission 4 and the score (ภารกิจ/ด่าน_04/README.md,
## agreed 2026-11-12):
##   correctness 30: the diagnosis — "replace the NIC" on the 1st choice 30,
##                   on the 2nd 15, later 0 (the player may choose again)
##   process 50:     5 decisions x 10, the first answer counts:
##                   tool (LAN Cable Tester), tester verdict (cable OK),
##                   swap-test conclusion (cable + switch port OK),
##                   spare part (the NIC), ping target after the fix (the
##                   Default Gateway)
##   time 20:        measured for real

const DECISION_POINTS := 10
const TOOL_RIGHT := "cable_tester"
const PART_RIGHT := "nic"
const FIX_RIGHT := "replace_nic"
const VERDICT_RIGHT := "cable_ok"
const SWAP_RIGHT := "nic_suspect"

## Options of the analysis question: id -> [text, hint when chosen wrong].
const FIXES := {
	"new_cable": ["เปลี่ยนสาย LAN เส้นใหม่", "ผลจาก LAN Cable Tester บอกอะไรเกี่ยวกับสายเส้นนี้"],
	"restart_network": ["Restart Router และ Switched Hub", "ลองพิจารณาว่าคอมพิวเตอร์เครื่องอื่นได้รับผลกระทบด้วยหรือไม่"],
	"other_switch_port": ["ย้ายไปเสียบพอร์ตอื่นบน Switched Hub", "เมื่อนำสายเส้นเดิมไปต่อกับคอมพิวเตอร์อีกเครื่อง ผลเป็นอย่างไร"],
	"reinstall_windows": ["ติดตั้ง Windows ใหม่", "ลองพิจารณาก่อนว่าปัญหาเกิดในระดับซอฟต์แวร์ หรือระดับการเชื่อมต่อทางกายภาพ"],
	"replace_nic": ["ทดลองเปลี่ยน Network Interface Card (NIC) ด้วยอุปกรณ์สำรอง", ""],
}

## First answers (one each). "" = not answered yet.
var tool_first := ""
var verdict_first := ""
var swap_first := ""
var part_first := ""
## Every analysis choice in order (the last one is the right one).
var fix_choices := PackedStringArray()
## The first ping after the fix: what the player typed, and whether it was
## the computer's Default Gateway.
var ping_target := ""
var ping_right := false
## Checks done after the fix.
var verified_ping := false
var verified_web := false


func note_tool(id: String) -> void:
	if tool_first == "":
		tool_first = id


func note_verdict(id: String) -> void:
	if verdict_first == "":
		verdict_first = id


func note_swap(id: String) -> void:
	if swap_first == "":
		swap_first = id


func note_part(id: String) -> void:
	if part_first == "":
		part_first = id


## Returns true when `id` is the right fix.
func note_fix(id: String) -> bool:
	fix_choices.append(id)
	return id == FIX_RIGHT


func fix_found() -> bool:
	return FIX_RIGHT in fix_choices


## A finished ping after the fix. The first one decides the process point.
func note_ping(target: String, gateway: String, replies: int) -> void:
	if ping_target == "":
		ping_target = target.strip_edges()
		ping_right = ping_target == gateway
	if target.strip_edges() == gateway and replies > 0:
		verified_ping = true


func correctness_points() -> int:
	var index := fix_choices.find(FIX_RIGHT)
	match index:
		0:
			return 30
		1:
			return 15
	return 0


func decision_counts() -> Vector2i:
	var ok := 0
	ok += int(tool_first == TOOL_RIGHT)
	ok += int(verdict_first == VERDICT_RIGHT)
	ok += int(swap_first == SWAP_RIGHT)
	ok += int(part_first == PART_RIGHT)
	ok += int(ping_right)
	return Vector2i(ok, 5)


func process_points() -> int:
	return decision_counts().x * DECISION_POINTS


func mission_score(elapsed_sec: float, time_full_sec: float, time_zero_sec: float) -> MissionScore:
	var counts := decision_counts()
	var score := MissionScore.compute(correctness_points(), counts.x, counts.y, elapsed_sec, time_full_sec, time_zero_sec)
	score.mistakes = mistakes()
	return score


## Short Thai lines for the summary's "จุดที่ผิดพลาด".
func mistakes() -> PackedStringArray:
	var out := PackedStringArray()
	if tool_first != "" and tool_first != TOOL_RIGHT:
		out.append("เลือกเครื่องมือตรวจสายผิดในครั้งแรก — การตรวจว่าสาย LAN ส่งสัญญาณได้ครบต้องใช้ LAN Cable Tester")
	if verdict_first != "" and verdict_first != VERDICT_RIGHT:
		out.append("อ่านผล LAN Cable Tester ผิด — ไฟตัวแม่และตัวลูกติดตรงกันครบ 1–8 แปลว่าสายใช้งานได้")
	if swap_first != "" and swap_first != SWAP_RIGHT:
		out.append("สรุปผลการทดลองสลับสายผิด — เครื่องอื่นใช้สายเส้นเดิมได้ แปลว่าสายและพอร์ตปกติ ปัญหาอยู่ที่เครื่องครู")
	var wrong := PackedStringArray()
	for id in fix_choices:
		if id != FIX_RIGHT:
			wrong.append(String(FIXES[id][0]))
	if not wrong.is_empty():
		out.append("เลือกวิธีแก้ไขที่ไม่สอดคล้องกับหลักฐานก่อน: " + ", ".join(wrong))
	if part_first != "" and part_first != PART_RIGHT:
		out.append("หยิบอะไหล่ผิดในครั้งแรก — อุปกรณ์ที่ต้องเปลี่ยนคือ Network Interface Card (NIC)")
	if ping_target != "" and not ping_right:
		out.append("ทดสอบหลังแก้ไขด้วยการ ping \"%s\" — ควร ping ไปที่ Default Gateway ของเครื่อง" % ping_target)
	return out
