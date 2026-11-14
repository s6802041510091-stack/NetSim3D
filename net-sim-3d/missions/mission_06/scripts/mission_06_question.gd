class_name Mission06Question
extends Resource

## One choice the player makes while talking with the teacher in Mission 6
## (objective ก: what remote-control software can do and what it needs —
## user 2026-11-15). Three are asked during the phone call (DialogueBox), two
## in the TeamViewer chat (reply buttons). The four answers are shown in a
## shuffled order; a wrong one gets the teacher's natural reaction and the
## player chooses again. Only the first answer counts for the score.

## "program", "request", "keep_open" (call) or "limits", "password" (chat).
@export var question_id: String = ""
## "call" or "chat".
@export var where: String = "call"
## The line on screen while choosing: "ผู้พูด|ข้อความ" (call) or the
## teacher's chat message (chat).
@export_multiline var prompt: String = ""
## Four answers in the player's own words, the right one included.
@export var options: PackedStringArray = PackedStringArray()
@export var correct_index: int = 0
## The teacher's answer to each option, same order ("ผู้พูด|ข้อความ" in the
## call, plain text in the chat). The right option's line moves the story on.
@export var reactions: PackedStringArray = PackedStringArray()


func is_correct(option_index: int) -> bool:
	return option_index == correct_index


## "" when usable, otherwise what is wrong.
func problem() -> String:
	if question_id == "" or prompt.strip_edges() == "":
		return "a question needs an id and a prompt"
	if options.size() != 4 or reactions.size() != 4:
		return "question '%s' needs 4 options and 4 reactions" % question_id
	if correct_index < 0 or correct_index > 3:
		return "question '%s' has no valid correct_index" % question_id
	return ""
