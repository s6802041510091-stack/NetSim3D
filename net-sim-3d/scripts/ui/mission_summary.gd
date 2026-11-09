class_name MissionSummary
extends CanvasLayer

## End-of-level summary shared by every mission: total score, stars, the three
## score parts (30/50/20), best score and the list of mistakes, with
## "เล่นอีกครั้ง", "กลับเมนูหลัก" and "ด่านถัดไป".

signal replay_requested
signal menu_requested
signal next_requested

var _body: VBoxContainer
var next_button: Button
var replay_button: Button
var menu_button: Button


func _ready() -> void:
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card := PanelContainer.new()
	card.name = "SummaryCard"
	card.custom_minimum_size = Vector2(760, 0)
	card.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1), Color(0.8, 0.83, 0.88), 12, 30, 24))
	center.add_child(card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	card.add_child(_body)


## `record` is GameProgress.record_attempt()'s result (best score, attempts).
func show_result(title: String, score: MissionScore, record: Dictionary, next_available: bool) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(GameUI.label(title, 16, GameUI.INK_SOFT, true))
	var total := score.total()
	_body.add_child(GameUI.label("คะแนนรวม %d / 100" % total, 34, GameUI.INK, true))
	var stars := GameUI.label(MissionScore.star_text(score.stars()), 28, GameUI.GOLD if score.passed() else GameUI.BAD, true)
	stars.name = "StarsLabel"
	_body.add_child(stars)
	_body.add_child(GameUI.label("ผ่านด่าน (ต้องได้ %d คะแนนขึ้นไป)" % MissionScore.PASS_SCORE if score.passed() else "ยังไม่ผ่าน ต้องได้ %d คะแนนขึ้นไป" % MissionScore.PASS_SCORE, 16, GameUI.OK if score.passed() else GameUI.BAD))
	_body.add_child(HSeparator.new())
	_part("ความถูกต้องของผลงาน", score.correctness, MissionScore.CORRECTNESS_MAX, "")
	_part("กระบวนการทำงาน", score.process, MissionScore.PROCESS_MAX, "ตัดสินใจถูก %d จาก %d ครั้ง" % [score.decisions_correct, score.decisions_total])
	_part("ประสิทธิภาพด้านเวลา", score.time, MissionScore.TIME_MAX, "ใช้เวลา %s" % _clock(score.elapsed_sec))
	_body.add_child(HSeparator.new())
	_body.add_child(GameUI.label("คะแนนสูงสุดของด่านนี้ %d  •  เล่นมาแล้ว %d ครั้ง" % [int(record.get("best_total", total)), int(record.get("attempts", 1))], 15, GameUI.INK_SOFT))
	_body.add_child(GameUI.label("จุดที่ผิดพลาด", 18, GameUI.INK, true))
	if score.mistakes.is_empty():
		_body.add_child(GameUI.label("ไม่มี ทำได้ถูกต้องทุกขั้นตอน", 15, GameUI.OK))
	for line in score.mistakes:
		var l := GameUI.label("•  " + line, 15, GameUI.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(690, 0)
		_body.add_child(l)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_body.add_child(buttons)
	replay_button = GameUI.button("เล่นอีกครั้ง")
	replay_button.name = "ReplayButton"
	replay_button.pressed.connect(func(): replay_requested.emit())
	buttons.add_child(replay_button)
	menu_button = GameUI.button("กลับเมนูหลัก")
	menu_button.name = "MenuButton"
	menu_button.pressed.connect(func(): menu_requested.emit())
	buttons.add_child(menu_button)
	next_button = GameUI.button("ด่านถัดไป", true)
	next_button.name = "NextButton"
	next_button.disabled = not next_available
	next_button.pressed.connect(func(): next_requested.emit())
	buttons.add_child(next_button)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(next_button if next_available else replay_button).grab_focus()
	_play_result(score)


## Pass / fail jingle, then a rising chime for each star.
func _play_result(score: MissionScore) -> void:
	Sound.play("jingle_pass" if score.passed() else "jingle_fail")
	for i in mini(score.stars(), 4):
		var pitch := 1.0 + i * 0.12
		get_tree().create_timer(0.9 + i * 0.28, true).timeout.connect(func(): Sound.play("star", null, 0.0, pitch))


func _part(name_text: String, points: int, max_points: int, detail: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := GameUI.label(name_text, 18, GameUI.INK)
	name_label.custom_minimum_size = Vector2(250, 0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.max_value = max_points
	bar.value = points
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(GameUI.label("%d / %d" % [points, max_points], 18, GameUI.INK, true))
	if detail != "":
		row.add_child(GameUI.label(detail, 14, GameUI.INK_SOFT))
	_body.add_child(row)


static func _clock(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d นาที" % [s / 60, s % 60]
