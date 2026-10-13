class_name Mission01Data
extends Resource

## Everything Mission 1 needs that is not code: names, texts, rules and the
## three install-point questions. Saved as data/missions/mission_01/mission_01_data.tres.

@export var mission_id: String = "mission_01"
@export var mission_title: String = "ภารกิจที่ 1"
## Project file name shown in the NetPlan EDU title bar.
@export var project_file_name: String = "ภารกิจที่ 1 — เลือกอุปกรณ์เครือข่ายห้องคอม"
@export_multiline var brief: String = ""
@export var requirements: PackedStringArray = PackedStringArray()
@export var start_score: int = 100
## Points taken from a point each time a check finds it wrong.
@export var penalty_per_wrong: int = 5
@export var questions: Array[EquipmentQuestion] = []


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


## Returns "" when the data is usable, otherwise what is wrong with it.
func validate_data() -> String:
	if questions.size() != 3:
		return "Mission 1 needs exactly 3 points (found %d)" % questions.size()
	var total := 0
	for q in questions:
		if q.options.size() != 2:
			return "Point %d must have 2 options" % q.point_id
		if not q.has_option(q.correct_option):
			return "Point %d: correct_option is not one of the options" % q.point_id
		total += q.max_score
	if total != start_score:
		return "Point scores add up to %d, expected %d" % [total, start_score]
	return ""
