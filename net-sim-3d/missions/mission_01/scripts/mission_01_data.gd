class_name Mission01Data
extends Resource

## Everything Mission 1 needs that is not code: names, texts, rules, the
## three install-point questions and (in a JSON file) the reasoning questions.
## Saved as missions/mission_01/data/mission_01_data.tres.

const DECISION_CHOOSE := "choose"
const DECISION_REJECT := "reject"

@export var mission_id: String = "mission_01"
@export var mission_title: String = "ภารกิจที่ 1"
## Project file name shown in the NetPlan EDU title bar.
@export var project_file_name: String = "ภารกิจที่ 1 — เลือกอุปกรณ์เครือข่ายห้องคอม"
@export_multiline var brief: String = ""
@export var requirements: PackedStringArray = PackedStringArray()
## Correctness part of the shared score (MissionScore.CORRECTNESS_MAX).
@export var start_score: int = 30
## Points taken from a point each time a check finds it wrong.
@export var penalty_per_wrong: int = 5
## Time score: full at or under this many seconds ...
@export var time_full_sec: float = 300.0
## ... and 0 from this many seconds (placeholder until play-testing).
@export var time_zero_sec: float = 900.0
## "point -> device -> choose/reject -> 3 options" (see the file's _note).
@export_file("*.json") var reasons_path: String = "res://missions/mission_01/data/mission_01_reasons.json"
@export var questions: Array[EquipmentQuestion] = []

var _reasons: Dictionary = {}


func get_question(point_id: int) -> EquipmentQuestion:
	for q in questions:
		if q.point_id == point_id:
			return q
	return null


func point_ids() -> Array[int]:
	var ids: Array[int] = []
	for q in questions:
		ids.append(q.point_id)
	return ids


func reasons() -> Dictionary:
	if _reasons.is_empty() and FileAccess.file_exists(reasons_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(reasons_path))
		if parsed is Dictionary:
			_reasons = parsed
	return _reasons


## The 3 reason options ({text, correct?, misconception?}) for one device and decision.
func reason_options(point_id: int, device: String, decision: String) -> Array:
	var point: Variant = reasons().get(str(point_id), {})
	if not point is Dictionary:
		return []
	var sides: Variant = point.get(device, {})
	if not sides is Dictionary:
		return []
	var options: Variant = sides.get(decision, [])
	return options if options is Array else []


## Whether choosing (true) or rejecting (false) `device` is the right decision.
func is_right_decision(point_id: int, device: String, decision: String) -> bool:
	var q := get_question(point_id)
	if q == null:
		return false
	return (decision == DECISION_CHOOSE) == (device == q.correct_option)


## Returns "" when the data is usable, otherwise what is wrong with it.
func validate_data() -> String:
	if questions.size() != 3:
		return "Mission 1 needs exactly 3 points (found %d)" % questions.size()
	var total := 0
	for q in questions:
		if q.options.size() != 4:
			return "Point %d must have 4 options (1 right + 3 distractors)" % q.point_id
		if not q.has_option(q.correct_option):
			return "Point %d: correct_option is not one of the options" % q.point_id
		if q.correct_quantity < 1:
			return "Point %d: correct_quantity must be at least 1" % q.point_id
		for device in q.options:
			for decision in [DECISION_CHOOSE, DECISION_REJECT]:
				var opts := reason_options(q.point_id, device, decision)
				if opts.size() != 3:
					return "Point %d %s %s: needs 3 reason options" % [q.point_id, device, decision]
				var right := 0
				for o in opts:
					if not o is Dictionary or String(o.get("text", "")) == "":
						return "Point %d %s %s: empty reason" % [q.point_id, device, decision]
					if bool(o.get("correct", false)):
						right += 1
					elif String(o.get("misconception", "")) == "":
						return "Point %d %s %s: distractor without a misconception label" % [q.point_id, device, decision]
				var expected := 1 if is_right_decision(q.point_id, device, decision) else 0
				if right != expected:
					return "Point %d %s %s: expected %d correct reason(s), found %d" % [q.point_id, device, decision, expected, right]
		total += q.max_score
	if total != start_score:
		return "Point scores add up to %d, expected %d" % [total, start_score]
	return ""
