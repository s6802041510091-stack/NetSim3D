class_name Mission01State
extends Resource

## Progress of Mission 1 for one player. Plain data only — the UI reads it,
## Mission01Validator changes the score, Mission01SaveStore writes it to disk.
## to_dict()/from_dict() let another save system store it later.

enum PointStatus { EMPTY, SELECTED, WRONG, CORRECT }

const SAVE_VERSION := 1

## point_id -> chosen option (full device name). Missing = not chosen.
@export var answers: Dictionary = {}
## point_id -> current score of that point (starts at the point's max score).
@export var point_scores: Dictionary = {}
## point_id -> result of the last check for the current answer: "correct" or "wrong".
## Cleared when the player changes that answer.
@export var point_results: Dictionary = {}
@export var check_count: int = 0
## Every point that was ever found wrong by a check.
@export var ever_wrong: Array[int] = []
@export var passed: bool = false
@export var final_score: int = 0
## For a future reward system: set once the reward for this mission is given.
@export var reward_claimed: bool = false


## Fresh start: every point at full score, nothing chosen.
func reset(data: Mission01Data) -> void:
	answers.clear()
	point_results.clear()
	point_scores.clear()
	for q in data.questions:
		point_scores[q.point_id] = q.max_score
	check_count = 0
	ever_wrong.clear()
	passed = false
	final_score = 0
	reward_claimed = false
	emit_changed()


## Stores the player's choice. Changing an answer is free (no penalty).
## Returns false when the point is locked (already correct or mission passed).
func set_answer(point_id: int, option: String) -> bool:
	if passed or get_status(point_id) == PointStatus.CORRECT:
		return false
	answers[point_id] = option
	point_results.erase(point_id)
	emit_changed()
	return true


func get_answer(point_id: int) -> String:
	return String(answers.get(point_id, ""))


func get_status(point_id: int) -> PointStatus:
	if not answers.has(point_id) or String(answers[point_id]) == "":
		return PointStatus.EMPTY
	match String(point_results.get(point_id, "")):
		"correct":
			return PointStatus.CORRECT
		"wrong":
			return PointStatus.WRONG
	return PointStatus.SELECTED


func answered_count(data: Mission01Data) -> int:
	var n := 0
	for q in data.questions:
		if get_status(q.point_id) != PointStatus.EMPTY:
			n += 1
	return n


func missing_points(data: Mission01Data) -> Array[int]:
	var out: Array[int] = []
	for q in data.questions:
		if get_status(q.point_id) == PointStatus.EMPTY:
			out.append(q.point_id)
	return out


func get_point_score(point_id: int) -> int:
	return int(point_scores.get(point_id, 0))


func total_score() -> int:
	var total := 0
	for id in point_scores:
		total += maxi(0, int(point_scores[id]))
	return maxi(0, total)


func ever_wrong_count() -> int:
	return ever_wrong.size()


# ---------------------------------------------------------------- save format

func to_dict() -> Dictionary:
	var a := {}
	for id in answers:
		a[str(id)] = String(answers[id])
	var s := {}
	for id in point_scores:
		s[str(id)] = int(point_scores[id])
	var r := {}
	for id in point_results:
		r[str(id)] = String(point_results[id])
	return {
		"version": SAVE_VERSION,
		"answers": a,
		"point_scores": s,
		"point_results": r,
		"current_score": total_score(),
		"check_count": check_count,
		"ever_wrong": ever_wrong.duplicate(),
		"passed": passed,
		"final_score": final_score,
		"reward_claimed": reward_claimed,
	}


## Loads values saved by to_dict(). Unknown or broken values are ignored,
## so an old or damaged save never crashes the mission.
func from_dict(d: Dictionary, data: Mission01Data) -> void:
	reset(data)
	var valid_ids := data.point_ids()
	var a: Variant = d.get("answers", {})
	if a is Dictionary:
		for key in a:
			var id := str(key).to_int()
			var q := data.get_question(id)
			if q != null and q.has_option(str(a[key])):
				answers[id] = str(a[key])
	var s: Variant = d.get("point_scores", {})
	if s is Dictionary:
		for key in s:
			var id := str(key).to_int()
			var q := data.get_question(id)
			if q != null:
				point_scores[id] = clampi(int(s[key]), 0, q.max_score)
	var r: Variant = d.get("point_results", {})
	if r is Dictionary:
		for key in r:
			var id := str(key).to_int()
			var value := str(r[key])
			if id in valid_ids and answers.has(id) and value in ["correct", "wrong"]:
				point_results[id] = value
	check_count = maxi(0, int(d.get("check_count", 0)))
	var w: Variant = d.get("ever_wrong", [])
	if w is Array:
		for v in w:
			var id := int(v)
			if id in valid_ids and not id in ever_wrong:
				ever_wrong.append(id)
	passed = bool(d.get("passed", false))
	final_score = clampi(int(d.get("final_score", 0)), 0, data.start_score)
	reward_claimed = bool(d.get("reward_claimed", false))
	emit_changed()
