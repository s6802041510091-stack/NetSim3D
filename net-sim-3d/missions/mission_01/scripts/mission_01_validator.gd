class_name Mission01Validator
extends RefCounted

## "ตรวจสอบแบบ" — checks all three points at once and applies the scoring rules:
##   * every point must have an answer first (otherwise nothing is checked or scored)
##   * each wrong point loses `penalty_per_wrong` (5) on every check while it stays wrong
##   * point scores and the total never go below 0
##   * all correct = mission passed, the score is final


## Result of one check.
class Result:
	## false when some points have no answer yet (nothing was checked).
	var checked: bool = false
	var missing: Array[int] = []
	var correct: Array[int] = []
	var wrong: Array[int] = []
	var completed: bool = false
	var total_score: int = 0


static func check(state: Mission01State, data: Mission01Data) -> Result:
	var result := Result.new()
	result.total_score = state.total_score()
	if state.passed:
		result.checked = true
		result.completed = true
		for q in data.questions:
			result.correct.append(q.point_id)
		return result

	result.missing = state.missing_points(data)
	if not result.missing.is_empty():
		return result

	result.checked = true
	state.check_count += 1
	for q in data.questions:
		var id := q.point_id
		if q.is_correct(state.get_answer(id)):
			state.point_results[id] = "correct"
			result.correct.append(id)
		else:
			state.point_results[id] = "wrong"
			state.point_scores[id] = maxi(0, state.get_point_score(id) - data.penalty_per_wrong)
			if not id in state.ever_wrong:
				state.ever_wrong.append(id)
			result.wrong.append(id)

	result.total_score = state.total_score()
	if result.wrong.is_empty():
		state.passed = true
		state.final_score = result.total_score
		result.completed = true
	state.emit_changed()
	return result
