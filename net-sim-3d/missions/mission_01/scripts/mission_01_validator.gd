class_name Mission01Validator
extends RefCounted

## "ตรวจสอบแบบ" — checks all three points at once and applies the scoring rules:
##   * every point must have a device (with its reason) first, otherwise nothing is checked
##   * a point is right only when the chosen device AND its reason are right;
##     a wrong point is marked "wrong" (device) or "wrong_reason" (right device)
##   * each wrong point loses `penalty_per_wrong` (5) on every check while it stays wrong
##   * point scores and the total never go below 0
##   * all correct = design passed, the correctness score is final
## The whole mission score (30/50/20) is built by Mission01Validator.mission_score().


## Result of one check.
class Result:
	## false when some points have no answer yet (nothing was checked).
	var checked: bool = false
	var missing: Array[int] = []
	var correct: Array[int] = []
	var wrong: Array[int] = []
	## Wrong points where the device was right and only the reason was wrong.
	var wrong_reason: Array[int] = []
	var completed: bool = false
	var total_score: int = 0


static func is_device_correct(state: Mission01State, q: EquipmentQuestion) -> bool:
	return q.is_correct(state.get_answer(q.point_id))


## Right device with its right reason.
static func is_point_correct(state: Mission01State, q: EquipmentQuestion, data: Mission01Data) -> bool:
	var device := state.get_answer(q.point_id)
	return q.is_correct(device) and state.get_reason(q.point_id) == data.correct_reason(q.point_id, device)


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
		if state.get_status(id) == Mission01State.PointStatus.CORRECT:
			result.correct.append(id)
			continue
		if is_point_correct(state, q, data):
			state.point_results[id] = "correct"
			result.correct.append(id)
		else:
			var reason_only := is_device_correct(state, q)
			state.point_results[id] = "wrong_reason" if reason_only else "wrong"
			if reason_only:
				result.wrong_reason.append(id)
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


## The 100-point mission score after the design was passed, plus the mistakes list.
static func mission_score(state: Mission01State, data: Mission01Data, elapsed_sec: float) -> MissionScore:
	var counts := state.decision_counts()
	var score := MissionScore.compute(state.total_score(), counts.x, counts.y, elapsed_sec, data.time_full_sec, data.time_zero_sec)
	score.mistakes = mistakes(state, data)
	return score


## Each line: where (the point and its name), what was chosen — why it is
## wrong (the right device, the misconception behind the reason picked).
static func mistakes(state: Mission01State, data: Mission01Data) -> PackedStringArray:
	var out := PackedStringArray()
	for q in data.questions:
		var id := q.point_id
		# Kept in Thai (it goes into the history); en_patterns.json translates it.
		var where := "จุดที่ %d (%s)" % [id, q.title]
		if id in state.ever_wrong:
			out.append("%s: กดตรวจแบบตอนที่จุดนี้ยังไม่ถูกต้อง — ถูกหักคะแนนความถูกต้องทุกครั้งที่ตรวจแล้วผิด" % where)
		var point_scored: Dictionary = state.scored_reasons.get(id, {})
		for device in point_scored:
			var entry: Dictionary = point_scored[device]
			if bool(entry.get("correct", false)):
				continue
			var line := "%s: เลือก %s" % [where, device]
			if device != q.correct_option:
				line += " — จุดนี้ต้องใช้ %s" % q.correct_option
			else:
				line += " — อุปกรณ์ถูก แต่เหตุผลไม่ถูก"
			var misconception := String(entry.get("misconception", ""))
			if misconception != "":
				line += " (เข้าใจผิดว่า: %s)" % misconception
			out.append(line)
	return out
