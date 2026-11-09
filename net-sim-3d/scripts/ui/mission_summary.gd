class_name MissionSummary
extends CanvasLayer

## End-of-level summary shared by every mission.
##   Main card: level name (top left, small), three big stars that pop in one
##   by one (rainbow at 80+), the total score and pass/fail, then
##   Exit / Play again / Next Level and "ดูรายละเอียด" at the bottom right.
##   Details card (a separate window): the 30/50/20 parts, time, how many
##   times things went wrong, best score and every mistake; "ย้อนกลับ"
##   returns to the main card.

signal replay_requested
signal menu_requested
signal next_requested

const CARD_BG := Color(1, 1, 1)
const CARD_BORDER := Color(0.8, 0.83, 0.88)
## When each star pops in (seconds after showing); the chime plays with it.
const STAR_DELAY := 0.9
const STAR_STEP := 0.28

var next_button: Button
var replay_button: Button
var menu_button: Button
var details_button: Button
var back_button: Button
var stars: SummaryStars

var _main: PanelContainer
var _details: PanelContainer
var _details_body: VBoxContainer


func _ready() -> void:
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_main = _card("SummaryCard", Vector2(720, 0))
	center.add_child(_main)
	_details = _card("DetailsCard", Vector2(760, 0))
	_details.visible = false
	center.add_child(_details)


func _card(card_name: String, min_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	card.custom_minimum_size = min_size
	card.add_theme_stylebox_override("panel", GameUI.box(CARD_BG, CARD_BORDER, 14, 30, 22))
	return card


## `title` is the level name. `record` is GameProgress.record_attempt()'s result
## (best score, attempts). `extra` adds mission rows to the details page:
## [[label, value], ...], e.g. how many checks were made.
func show_result(title: String, score: MissionScore, record: Dictionary, next_available: bool, extra: Array = []) -> void:
	_build_main(title, score, next_available)
	_build_details(title, score, record, extra)
	show_main()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(next_button if next_available else replay_button).grab_focus()
	_play_result(score)


func show_main() -> void:
	_details.visible = false
	_main.visible = true


func show_details() -> void:
	_main.visible = false
	_details.visible = true
	back_button.grab_focus()


func is_details_shown() -> bool:
	return visible and _details.visible


# ---------------------------------------------------------------- main card

func _build_main(title: String, score: MissionScore, next_available: bool) -> void:
	_clear(_main)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_main.add_child(col)
	var name_label := GameUI.label(title, 15, GameUI.INK_SOFT)
	name_label.name = "LevelName"
	col.add_child(name_label)

	stars = SummaryStars.new()
	stars.name = "Stars"
	stars.custom_minimum_size = Vector2(0, 150)
	stars.earned = score.stars()
	col.add_child(stars)

	var total := GameUI.label("%d คะแนน" % score.total(), 32, GameUI.INK, true)
	total.name = "TotalLabel"
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(total)
	var verdict := "ผ่านด่าน" if score.passed() else "ยังไม่ผ่าน — ต้องได้ %d คะแนนขึ้นไป" % MissionScore.PASS_SCORE
	if score.stars() >= 4:
		verdict += "  •  ดาวสีรุ้ง!"
	var pass_label := GameUI.label(verdict, 18, GameUI.OK if score.passed() else GameUI.BAD, true)
	pass_label.name = "PassLabel"
	pass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pass_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	col.add_child(buttons)
	menu_button = GameUI.button("Exit", false, 170)
	menu_button.name = "MenuButton"
	menu_button.tooltip_text = "กลับเมนูหลัก"
	menu_button.pressed.connect(func(): menu_requested.emit())
	buttons.add_child(menu_button)
	replay_button = GameUI.button("Play again", false, 170)
	replay_button.name = "ReplayButton"
	replay_button.tooltip_text = "เล่นด่านนี้อีกครั้ง"
	replay_button.pressed.connect(func(): replay_requested.emit())
	buttons.add_child(replay_button)
	next_button = GameUI.button("Next Level", true, 170)
	next_button.name = "NextButton"
	next_button.disabled = not next_available
	next_button.tooltip_text = "ไปด่านถัดไป" if next_available else "ต้องผ่านด่านนี้ก่อน หรือด่านถัดไปยังไม่เปิด"
	next_button.pressed.connect(func(): next_requested.emit())
	buttons.add_child(next_button)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(footer)
	details_button = _link_button("ดูรายละเอียด  ›")
	details_button.name = "DetailsButton"
	details_button.pressed.connect(show_details)
	footer.add_child(details_button)


# ---------------------------------------------------------------- details card

func _build_details(title: String, score: MissionScore, record: Dictionary, extra: Array) -> void:
	_clear(_details)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_details.add_child(col)
	col.add_child(GameUI.label(title, 15, GameUI.INK_SOFT))
	col.add_child(GameUI.label("รายละเอียดคะแนน", 24, GameUI.INK, true))

	var scroll := ScrollContainer.new()
	scroll.name = "DetailsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 440)
	col.add_child(scroll)
	_details_body = VBoxContainer.new()
	_details_body.name = "DetailsBody"
	_details_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_details_body)

	var star_word := "ดาวสีรุ้ง" if score.stars() >= 4 else "%d ดาว" % score.stars()
	_details_body.add_child(GameUI.label("คะแนนรวม %d / 100  •  %s  •  %s" % [score.total(), "ผ่าน" if score.passed() else "ยังไม่ผ่าน", star_word], 20, GameUI.INK, true))
	_details_body.add_child(HSeparator.new())
	_part("ความถูกต้องของผลงาน", score.correctness, MissionScore.CORRECTNESS_MAX)
	_part("กระบวนการทำงาน", score.process, MissionScore.PROCESS_MAX)
	_part("ประสิทธิภาพด้านเวลา", score.time, MissionScore.TIME_MAX)
	_details_body.add_child(HSeparator.new())
	_row("เวลาที่ใช้", _clock(score.elapsed_sec))
	for item in extra:
		if item is Array and item.size() >= 2:
			_row(String(item[0]), String(item[1]))
	if score.decisions_total > 0:
		_row("การตัดสินใจ (อุปกรณ์ + เหตุผล)", "ถูก %d  •  ผิด %d  จาก %d ครั้ง" % [score.decisions_correct, score.decisions_total - score.decisions_correct, score.decisions_total])
	_row("คะแนนสูงสุดของด่านนี้", "%d คะแนน" % int(record.get("best_total", score.total())))
	_row("เล่นมาแล้ว", "%d ครั้ง" % int(record.get("attempts", 1)))
	_details_body.add_child(HSeparator.new())
	_details_body.add_child(GameUI.label("จุดที่ผิดพลาด", 18, GameUI.INK, true))
	if score.mistakes.is_empty():
		_details_body.add_child(GameUI.label("ไม่มี ทำได้ถูกต้องทุกขั้นตอน", 15, GameUI.OK))
	for line in score.mistakes:
		var l := GameUI.label("•  " + line, 15, GameUI.INK)
		l.name = "Mistake"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(660, 0)
		_details_body.add_child(l)

	var footer := HBoxContainer.new()
	col.add_child(footer)
	back_button = GameUI.button("‹  ย้อนกลับ", false, 160)
	back_button.name = "BackButton"
	back_button.set_meta("sound", "back")
	back_button.pressed.connect(show_main)
	footer.add_child(back_button)


func _part(name_text: String, points: int, max_points: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := GameUI.label(name_text, 17, GameUI.INK)
	name_label.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.max_value = max_points
	bar.value = points
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(260, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", GameUI.box(Color(0.9, 0.92, 0.95), Color(0, 0, 0, 0), 9, 0, 0))
	bar.add_theme_stylebox_override("fill", GameUI.box(GameUI.ACCENT, Color(0, 0, 0, 0), 9, 0, 0))
	row.add_child(bar)
	row.add_child(GameUI.label("%d / %d" % [points, max_points], 17, GameUI.INK, true))
	_details_body.add_child(row)


func _row(name_text: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := GameUI.label(name_text, 16, GameUI.INK_SOFT)
	name_label.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_label)
	row.add_child(GameUI.label(value, 16, GameUI.INK, true))
	_details_body.add_child(row)


func _link_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 16)
	for c in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(c, GameUI.ACCENT)
	b.add_theme_color_override("font_hover_color", GameUI.ACCENT.darkened(0.2))
	b.add_theme_color_override("font_pressed_color", GameUI.ACCENT.darkened(0.3))
	return b


func _clear(card: Control) -> void:
	for child in card.get_children():
		card.remove_child(child)
		child.queue_free()


## Pass / fail jingle, then a rising chime as each star pops in.
func _play_result(score: MissionScore) -> void:
	Sound.play("jingle_pass" if score.passed() else "jingle_fail")
	for i in mini(score.stars(), 4):
		var pitch := 1.0 + i * 0.12
		get_tree().create_timer(STAR_DELAY + i * STAR_STEP, true).timeout.connect(func(): Sound.play("star", null, 0.0, pitch))
	stars.animate(STAR_DELAY, STAR_STEP)


static func _clock(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d นาที" % [s / 60, s % 60]


## Three big stars drawn as shapes (the game fonts have no star glyph).
## `earned` 0-3 gold stars; 4 = all three in rainbow colours.
class SummaryStars:
	extends Control

	const EMPTY_FILL := Color(0.86, 0.88, 0.92)
	const EMPTY_EDGE := Color(0.74, 0.77, 0.83)
	const GOLD_EDGE := Color(0.85, 0.55, 0.05)
	const RADIUS := 52.0
	const SIDE_DROP := 12.0 # outer stars sit a little lower

	var earned := 0
	## 0..1 per star: how far it has popped in (1 = shown).
	var shown: Array[float] = [1.0, 1.0, 1.0]
	var _time := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func animate(delay: float, step: float) -> void:
		shown = [0.0, 0.0, 0.0]
		if earned <= 0:
			shown = [1.0, 1.0, 1.0]
			queue_redraw()
			return
		var tween := create_tween().set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		for i in 3:
			if i >= earned:
				shown[i] = 1.0 # empty slots are there from the start
				continue
			tween.tween_method(_set_shown.bind(i), 0.0, 1.0, 0.35) \
				.set_delay(delay + i * step).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func _set_shown(value: float, index: int) -> void:
		shown[index] = value
		queue_redraw()

	func is_rainbow() -> bool:
		return earned >= 4

	func _process(delta: float) -> void:
		if is_rainbow():
			_time += delta
			queue_redraw()

	func _draw() -> void:
		var mid := size * 0.5
		var gap := RADIUS * 2.3
		for i in 3:
			var center := mid + Vector2((i - 1) * gap, SIDE_DROP if i != 1 else -4.0)
			var radius := RADIUS * (1.12 if i == 1 else 1.0)
			# Empty slot underneath, earned star pops in on top.
			_star(center, radius, EMPTY_FILL, EMPTY_EDGE, false)
			if i < mini(earned, 3) or is_rainbow():
				var s := shown[i]
				if s > 0.0:
					_star(center, radius * s, GameUI.GOLD, GOLD_EDGE, is_rainbow(), i)

	func _star(center: Vector2, radius: float, fill: Color, edge: Color, rainbow: bool, index: int = 0) -> void:
		var points := PackedVector2Array()
		for k in 10:
			var r := radius if k % 2 == 0 else radius * 0.47
			var a := -PI / 2.0 + k * PI / 5.0
			points.append(center + Vector2(cos(a), sin(a)) * r)
		if rainbow:
			var colors := PackedColorArray()
			for k in 10:
				colors.append(Color.from_hsv(fmod(k / 10.0 + index * 0.18 + _time * 0.25, 1.0), 0.65, 1.0))
			draw_polygon(points, colors)
		else:
			draw_colored_polygon(points, fill)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color.WHITE if rainbow else edge, 3.0, true)
