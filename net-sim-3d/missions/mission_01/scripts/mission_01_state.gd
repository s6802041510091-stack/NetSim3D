class_name Mission01State
extends Resource

## Progress of Mission 1 for one player. Plain data only — the UI reads it,
## Mission01Validator changes the score, Mission01SaveStore writes it to disk.
## to_dict()/from_dict() let another save system store it later.
##
## Scoring data (see MissionScore):
##   point_scores      correctness, 10 per point, -5 per wrong check
##   scored_reasons    the FIRST choose/reject + reason the player gave for each
##                     device they clicked (later changes are allowed but not re-scored)
##   quantity_results  whether the quantity of each point was right at its first check

enum PointStatus { EMPTY, SELECTED, WRONG, CORRECT }

const SAVE_VERSION := 2

## point_id -> chosen device (full name). Missing = not chosen.
@export var answers: Dictionary = {}
## point_id -> quantity typed for the chosen device.
@export var quantities: Dictionary = {}
## point_id -> { device -> "choose" | "reject" }: the latest decision per device (UI marks).
@export var marks: Dictionary = {}
## point_id -> { device -> {decision, option, correct, misconception, text} }: first answer, scored.
@export var scored_reasons: Dictionary = {}
## point_id -> true/false: quantity right at the point's first check.
@export var quantity_results: Dictionary = {}
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
	quantities.clear()
	marks.clear()
	scored_reasons.clear()
	quantity_results.clear()
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


## Records "choose"/"reject" + the reason (index into the data's 3 options).
## The first answer for a device is the scored one. Returns false when locked.
func record_reason(point_id: int, device: String, decision: String, option_index: int, data: Mission01Data) -> bool:
	if is_locked(point_id):
		return false
	var options := data.reason_options(point_id, device, decision)
	if option_index < 0 or option_index >= options.size():
		return false
	var point_marks: Dictionary = marks.get(point_id, {})
	point_marks[device] = decision
	if decision == Mission01Data.DECISION_CHOOSE:
		# Only one device can be the chosen one: the others lose their "choose" mark.
		for other in point_marks.keys():
			if other != device and point_marks[other] == Mission01Data.DECISION_CHOOSE:
				point_marks.erase(other)
	elif get_answer(point_id) == device:
		answers.erase(point_id)
		point_results.erase(point_id)
	marks[point_id] = point_marks
	var point_scored: Dictionary = scored_reasons.get(point_id, {})
	if not point_scored.has(device):
		var option: Dictionary = options[option_index]
		point_scored[device] = {
			"decision": decision,
			"option": option_index,
			"correct": data.is_right_decision(point_id, device, decision) and bool(option.get("correct", false)),
			"misconception": String(option.get("misconception", "")),
			"text": String(option.get("text", "")),
		}
		scored_reasons[point_id] = point_scored
	emit_changed()
	return true


func get_mark(point_id: int, device: String) -> String:
	return String((marks.get(point_id, {}) as Dictionary).get(device, ""))


## Stores the chosen device and quantity. The device must already be marked
## "choose". Changing an answer is free (no penalty).
## Returns false when the point is locked (already correct or mission passed).
func set_answer(point_id: int, option: String, quantity: int = 1) -> bool:
	if is_locked(point_id) or get_mark(point_id, option) != Mission01Data.DECISION_CHOOSE:
		return false
	answers[point_id] = option
	quantities[point_id] = maxi(quantity, 0)
	point_results.erase(point_id)
	emit_changed()
	return true


func get_answer(point_id: int) -> String:
	return String(answers.get(point_id, ""))


func get_quantity(point_id: int) -> int:
	return int(quantities.get(point_id, 0))


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


## Decisions for the process score: every scored reason plus each point's quantity.
func decision_counts() -> Vector2i:
	var ok := 0
	var all := 0
	for id in scored_reasons:
		for device in scored_reasons[id]:
			all += 1
			if bool(scored_reasons[id][device].get("correct", false)):
				ok += 1
	for id in quantity_results:
		all += 1
		if bool(quantity_results[id]):
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
		"quantities": keyed.call(quantities),
		"marks": keyed.call(marks),
		"scored_reasons": keyed.call(scored_reasons),
		"quantity_results": keyed.call(quantity_results),
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
		return # Saves from the 2-option version of the mission start fresh.
	var valid_ids := data.point_ids()
	for key in _dict(d, "marks"):
		var id := str(key).to_int()
		var q := data.get_question(id)
		var point_marks: Variant = d.marks[key]
		if q == null or not point_marks is Dictionary:
			continue
		var clean := {}
		for device in point_marks:
			if q.has_option(str(device)) and str(point_marks[device]) in [Mission01Data.DECISION_CHOOSE, Mission01Data.DECISION_REJECT]:
				clean[str(device)] = str(point_marks[device])
		marks[id] = clean
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
				# JSON gives floats back; keep the same types as record_reason().
				clean[str(device)] = {
					"decision": str(entry.get("decision", "")),
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
	for key in _dict(d, "quantities"):
		var id := str(key).to_int()
		if id in valid_ids:
			quantities[id] = clampi(int(d.quantities[key]), 0, 99)
	for key in _dict(d, "quantity_results"):
		var id := str(key).to_int()
		if id in valid_ids:
			quantity_results[id] = bool(d.quantity_results[key])
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
