class_name MissionScore
extends RefCounted

## The shared 100-point score of every mission (proposal section "ระบบประเมินผล"):
##   correctness of the work  30
##   working process          50  (share of the player's decisions that were right)
##   time efficiency          20  (full up to `time_full_sec`, falls to 0 at `time_zero_sec`)
## Pass at 50+. Stars: 1 at 50, 2 at 60, 3 at 70, rainbow 3 stars (4) at 80.

const CORRECTNESS_MAX := 30
const PROCESS_MAX := 50
const TIME_MAX := 20
const PASS_SCORE := 50
const STAR_THRESHOLDS := [50, 60, 70, 80]

var correctness: int = 0
var process: int = 0
var time: int = 0
var elapsed_sec: float = 0.0
## Decisions counted for the process score.
var decisions_total: int = 0
var decisions_correct: int = 0
## Short Thai lines shown on the summary ("จุดที่ผิดพลาด").
var mistakes: PackedStringArray = PackedStringArray()


static func compute(correctness_points: int, decisions_ok: int, decisions_all: int, seconds: float, time_full_sec: float, time_zero_sec: float) -> MissionScore:
	var s := MissionScore.new()
	s.correctness = clampi(correctness_points, 0, CORRECTNESS_MAX)
	s.decisions_correct = maxi(decisions_ok, 0)
	s.decisions_total = maxi(decisions_all, 0)
	s.process = roundi(PROCESS_MAX * float(s.decisions_correct) / s.decisions_total) if s.decisions_total > 0 else 0
	s.process = clampi(s.process, 0, PROCESS_MAX)
	s.elapsed_sec = maxf(seconds, 0.0)
	s.time = time_points(s.elapsed_sec, time_full_sec, time_zero_sec)
	return s


static func time_points(seconds: float, full_sec: float, zero_sec: float) -> int:
	if seconds <= full_sec:
		return TIME_MAX
	if seconds >= zero_sec or zero_sec <= full_sec:
		return 0
	return roundi(TIME_MAX * (zero_sec - seconds) / (zero_sec - full_sec))


static func stars_for(total_score: int) -> int:
	var stars := 0
	for threshold: int in STAR_THRESHOLDS:
		if total_score >= threshold:
			stars += 1
	return stars


static func star_text(stars: int) -> String:
	match stars:
		0:
			return "ยังไม่ผ่าน"
		4:
			return "★★★ ดาวสีรุ้ง"
	return "★".repeat(stars) + "☆".repeat(3 - stars)


func total() -> int:
	return correctness + process + time


func passed() -> bool:
	return total() >= PASS_SCORE


func stars() -> int:
	return stars_for(total())


func to_dict() -> Dictionary:
	return {
		"correctness": correctness, "process": process, "time": time, "total": total(),
		"passed": passed(), "stars": stars(), "elapsed_sec": snappedf(elapsed_sec, 0.1),
		"decisions_correct": decisions_correct, "decisions_total": decisions_total,
		"mistakes": Array(mistakes),
	}
