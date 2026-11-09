class_name Mission01State
extends Resource

## Progress of Mission 1 for one player. Plain data only — the UI reads it,
## Mission01Validator changes the score, Mission01SaveStore writes it to disk.
## to_dict()/from_dict() let another save system store it later.
##
## A point is answered by choosing a device AND the reason for choosing it.
## Scoring data (see MissionScore):
##   point_scores    correctness, 10 per point, -5 per wrong check
##   scored_reasons  the FIRST device+reason confirmed for each device at each
##                   point (later changes are allowed but not re-scored)

enum PointStatus { EMPTY, SELECTED, WRONG, CORRECT }

const SAVE_VERSION := 3

## point_id -> chosen device (full name). Missing = not chosen.
@export var answers: Dictionary = {}
## point_id -> index of the chosen reason (into the data's options for that device).
@export var reasons: Dictionary = {}
## point_id -> { device -> {option, correct, misconception, text} }: first answer, scored.
@export var scored_reasons: Dictionary = {}
## point_id -> current correctness score of that point.
@export var point_scores: Dictionary = {}
## point_id -> result of the last check for the current answer: "correct" or "wrong".
## Cleared when the player changes that answer.
@export var point_results: Dictionary = {}
@export var check_count: int = 0
## Every point that was ever found wrong by a check.
@export var ever_wrong: Array[int] = []
@export var passed: bool = false
## Correctness score when the design was passed (out of 30).
@export var final_score: int = 0
## For a future reward system: set once the reward for this mission is given.
@export var reward_claimed: bool = false


## Fresh start: every point at full score, nothing chosen.
func reset(data: Mission01Data) -> void:
	answers.clear()
	reasons.clear()
	scored_reasons.clear()
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


func is_locked(point_id: int) -> bool:
	return passed or get_status(point_id) == PointStatus.CORRECT


## Stores the chosen device and the reason (index into the data's options).
## The first reason given for a device at a point is the scored one.
## Changing an answer is free (no penalty). Returns false when locked or invalid.
func set_answer(point_id: int, device: String, reason_index: int, data: Mission01Data) -> bool:
	if is_locked(point_id):
		return false
	var q := data.get_question(point_id)
	var options := data.reason_options(point_id, device)
	if q == null or not q.has_option(device) or reason_index < 0 or reason_index >= options.size():
		return false
	answers[point_id] = device
	reasons[point_id] = reason_index
	point_results.erase(point_id)
	var point_scored: Dictionary = scored_reasons.get(point_id, {})
	if not point_scored.has(device):
		var option: Dictionary = options[reason_index]
		point_scored[device] = {
			"option": reason_index,
			"correct": device == q.correct_option and bool(option.get("correct", false)),
			"misconception": String(option.get("misconception", "")),
			"text": String(option.get("text", "")),
		}
		scored_reasons[point_id] = point_scored
	emit_changed()
	return true


func get_answer(point_id: int) -> String:
	return String(answers.get(point_id, ""))


func get_reason(point_id: int) -> int:
	return int(reasons.get(point_id, -1))


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


## Decisions for the process score: every scored device+reason.
func decision_counts() -> Vector2i:
	var ok := 0
	var all := 0
	for id in scored_reasons:
		for device in scored_reasons[id]:
			all += 1
			if bool(scored_reasons[id][device].get("correct", false)):
				ok += 1
	return Vector2i(ok, all)


# ---------------------------------------------------------------- save format

func to_dict() -> Dictionary:
	var keyed := func(source: Dictionary) -> Dictionary:
		var out := {}
		for id in source:
			out[str(id)] = source[id]
		return out
	return {
		"version": SAVE_VERSION,
		"answers": keyed.call(answers),
		"reasons": keyed.call(reasons),
		"scored_reasons": keyed.call(scored_reasons),
		"point_scores": keyed.call(point_scores),
		"point_results": keyed.call(point_results),
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
	if int(d.get("version", 1)) != SAVE_VERSION:
		return # Saves from earlier versions of the mission start fresh.
	var valid_ids := data.point_ids()
	for key in _dict(d, "scored_reasons"):
		var id := str(key).to_int()
		var q := data.get_question(id)
		var point_scored: Variant = d.scored_reasons[key]
		if q == null or not point_scored is Dictionary:
			continue
		var clean := {}
		for device in point_scored:
			var entry: Variant = point_scored[device]
			if q.has_option(str(device)) and entry is Dictionary:
				# JSON gives floats back; keep the same types as set_answer().
				clean[str(device)] = {
					"option": int(entry.get("option", 0)),
					"correct": bool(entry.get("correct", false)),
					"misconception": str(entry.get("misconception", "")),
					"text": str(entry.get("text", "")),
				}
		scored_reasons[id] = clean
	for key in _dict(d, "answers"):
		var id := str(key).to_int()
		var q := data.get_question(id)
		if q != null and q.has_option(str(d.answers[key])):
			answers[id] = str(d.answers[key])
	for key in _dict(d, "reasons"):
		var id := str(key).to_int()
		if id in valid_ids and answers.has(id):
			reasons[id] = clampi(int(d.reasons[key]), 0, Mission01Data.REASON_COUNT - 1)
	for key in _dict(d, "point_scores"):
		var id := str(key).to_int()
		var q := data.get_question(id)
		if q != null:
			point_scores[id] = clampi(int(d.point_scores[key]), 0, q.max_score)
	for key in _dict(d, "point_results"):
		var id := str(key).to_int()
		var value := str(d.point_results[key])
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


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var value: Variant = d.get(key, {})
	return value if value is Dictionary else {}
