class_name SecurityQuestion
extends Resource

## A question someone asks in Mission 5 (ภารกิจ/ด่าน_05/README.md, v2.1 of
## 2026-11-15): only "report": what the player tells the teacher — the quiz
## questions on the desktop were dropped. Asked in the dialogue box with 4
## stacked answers in a shuffled order. Only the first answer counts for the
## process score; a wrong one shows `hint` (it must not give the answer away)
## and the question is asked again.

## "report".
@export var question_id: String = ""
## Who asks: "ผู้พูด" part of the dialogue line, e.g. "คุณ" or the teacher.
@export var speaker: String = ""
@export_multiline var text: String = ""
## Four answers, the right one included. Shown shuffled.
@export var options: PackedStringArray = PackedStringArray()
## Index of the right answer in `options` (before shuffling).
@export var correct_index: int = 0
@export_multiline var hint: String = ""


func is_correct(option_index: int) -> bool:
	return option_index == correct_index


## "" when usable, otherwise what is wrong.
func problem() -> String:
	if question_id == "" or text.strip_edges() == "":
		return "a question needs an id and a text"
	if options.size() != 4:
		return "question '%s' needs 4 options (found %d)" % [question_id, options.size()]
	if correct_index < 0 or correct_index >= options.size():
		return "question '%s' has no valid correct_index" % question_id
	if hint.strip_edges() == "":
		return "question '%s' needs a hint" % question_id
	return ""
