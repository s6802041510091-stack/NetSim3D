class_name Mission01Data
extends Resource

## Everything Mission 1 needs that is not code: names, texts, rules, the
## three install-point questions and (in a JSON file) the reasoning questions.
## Saved as missions/mission_01/data/mission_01_data.tres.

const REASON_COUNT := 4
const ICON_DIR := "res://assets/ui/devices/"

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
## "point -> device -> 4 options" (see the file's _note).
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


## The "why choose it?" options ({text, correct?, misconception?}) for one device.
func reason_options(point_id: int, device: String) -> Array:
	var point: Variant = reasons().get(str(point_id), {})
	if not point is Dictionary:
		return []
	var options: Variant = point.get(device, [])
	return options if options is Array else []


## Index of the right reason for the right device (-1 for a wrong device).
func correct_reason(point_id: int, device: String) -> int:
	var options := reason_options(point_id, device)
	for i in options.size():
		if bool(options[i].get("correct", false)):
			return i
	return -1


## Picture of a device for the choice cards, e.g. "Switched Hub 24 Port" ->
## res://assets/ui/devices/switched_hub_24_port.png, rendered from the 3D models
## by 3Dmodel/scripts/render_device_thumbnails.py (null when missing).
static func device_icon(device: String) -> Texture2D:
	var path := ICON_DIR + device.to_lower().replace(" ", "_") + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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
		for device in q.options:
			var opts := reason_options(q.point_id, device)
			if opts.size() != REASON_COUNT:
				return "Point %d %s: needs %d reason options" % [q.point_id, device, REASON_COUNT]
			var right := 0
			for o in opts:
				if not o is Dictionary or String(o.get("text", "")) == "":
					return "Point %d %s: empty reason" % [q.point_id, device]
				if bool(o.get("correct", false)):
					right += 1
				elif String(o.get("misconception", "")) == "":
					return "Point %d %s: distractor without a misconception label" % [q.point_id, device]
			var expected := 1 if device == q.correct_option else 0
			if right != expected:
				return "Point %d %s: expected %d correct reason(s), found %d" % [q.point_id, device, expected, right]
			if device_icon(device) == null:
				return "Point %d %s: no picture in %s" % [q.point_id, device, ICON_DIR]
		total += q.max_score
	if total != start_score:
		return "Point scores add up to %d, expected %d" % [total, start_score]
	return ""
