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
## The teacher's red-pen word beside the score (user 2026-11-24), by score,
## high to low; one of the group at random.
const PRAISE_TOP := ["ยอดเยี่ยม", "2/10", "ปังมากแม่"] # 3 stars / rainbow (70+)
const PRAISE_PASS := ["ยินดีด้วย", "เก่งมาก"] # 2 stars (60-69)
const PRAISE_ONE := ["ครั้งหน้าพยายามให้มากขึ้นนะ", "พยายามต่อไปนะ"] # 1 star (50-59)
const PRAISE_TRY := ["ควรพยายามให้มากกว่านี้นะ"] # not passed (0 stars)
const PEN_FONT := preload("res://assets/fonts/Charm-Bold.ttf")

var pen_mark: PenMark

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

	# Red pen beside the score, over the whole card (a PanelContainer gives
	# every child the full card, so the mark can sit anywhere).
	pen_mark = PenMark.new()
	pen_mark.name = "PenMark"
	pen_mark.word = praise_for(score)
	pen_mark.score_label = total
	_main.add_child(pen_mark)


## The red-pen word for a score: top group at 3 stars and up, then 2 stars,
## then 1 star, then not passed.
static func praise_for(score: MissionScore) -> String:
	var group: Array = PRAISE_TRY
	if score.stars() >= 3:
		group = PRAISE_TOP
	elif score.stars() == 2:
		group = PRAISE_PASS
	elif score.stars() == 1:
		group = PRAISE_ONE
	return String(group.pick_random())


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
		_row("การตัดสินใจ", "ถูก %d  •  ผิด %d  จาก %d ครั้ง" % [score.decisions_correct, score.decisions_total - score.decisions_correct, score.decisions_total])
	_row("คะแนนสูงสุดของด่านนี้", "%d คะแนน" % int(record.get("best_total", score.total())))
	_row("เล่นมาแล้ว", "%d ครั้ง" % int(record.get("attempts", 1)))
	_details_body.add_child(HSeparator.new())
	_details_body.add_child(GameUI.label("จุดที่ผิดพลาด", 18, GameUI.INK, true))
	if score.mistakes.is_empty():
		_details_body.add_child(GameUI.label("ไม่มี ทำได้ถูกต้องทุกขั้นตอน", 15, GameUI.OK))
	# Where, why and when for each one (the attempt's mistake_log).
	var last: Variant = record.get("last", {})
	var log: Variant = (last as Dictionary).get("mistake_log", []) if last is Dictionary else []
	if log is Array and (log as Array).size() == score.mistakes.size() and not score.mistakes.is_empty():
		MistakeCards.build(_details_body, log, GameUI.label, GameUI.INK, GameUI.INK_SOFT, 540.0)
	else:
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
	# The teacher writes once the stars are in.
	pen_mark.animate(STAR_DELAY + (mini(maxi(score.stars(), 1), 3) - 1) * STAR_STEP + 0.3)


static func _clock(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d นาที" % [s / 60, s % 60]


## The teacher's word in red pen beside the score, a little tilted, like a
## mark on a checked exam paper: it lands with a small stamp after the stars,
## then a swoosh is drawn under it.
class PenMark:
	extends Control

	const INK := Color(0.84, 0.08, 0.12)
	const SIZE := 46
	const MIN_SIZE := 24
	const TILT := -0.17 # radians, up to the right
	const GAP := 22.0 # from the end of the score

	var word := ""
	var score_label: Label
	## 0..1: the word landing (scale and fade), then the underline being drawn.
	var land := 0.0
	var underline := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func animate(delay: float) -> void:
		land = 0.0
		underline = 0.0
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(delay)
		tween.tween_method(_set_land, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_underline, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func _set_land(value: float) -> void:
		land = value
		queue_redraw()

	func _set_underline(value: float) -> void:
		underline = value
		queue_redraw()

	func shown_word() -> String:
		return GameLocale.text(word)

	func _draw() -> void:
		if word == "" or score_label == null or land <= 0.0:
			return
		var text := shown_word()
		# Where the score's text ends (the label is centred across the card).
		var to_local := get_global_transform().affine_inverse()
		var rect := to_local * score_label.get_global_rect()
		var label_font := score_label.get_theme_font("font")
		var score_width := label_font.get_string_size(score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_label.get_theme_font_size("font_size")).x
		var start := Vector2(rect.get_center().x + score_width * 0.5 + GAP, rect.get_center().y + 2.0)
		# One line (user 2026-11-24); a long word gets smaller to stay on the card.
		var room := size.x - start.x - 8.0
		var font_size := SIZE
		while font_size > MIN_SIZE and PEN_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
			font_size -= 2
		var width := PEN_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var scale := lerpf(1.7, 1.0, land)
		var ink := Color(INK, clampf(land * 1.4, 0.0, 0.95))
		draw_set_transform(start + Vector2(width * 0.5, 0), TILT, Vector2(scale, scale))
		draw_string(PEN_FONT, Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		# The swoosh under the word, drawn left to right.
		if underline > 0.0:
			var points := PackedVector2Array()
			var steps := 18
			for i in steps + 1:
				var t := float(i) / steps * underline
				var x := -width * 0.55 + width * 1.15 * t
				var y := font_size * 0.28 + sin(t * PI) * -4.0 + t * t * 6.0
				points.append(Vector2(x, y))
			if points.size() >= 2:
				draw_polyline(points, ink, maxf(2.0, font_size * 0.07), true)
		draw_set_transform(Vector2.ZERO)


## Three big stars drawn as shapes (the game fonts have no star glyph).
## `earned` 0-3 gold stars; 4 = all three in rainbow colours.
## 3D look (user 2026-11-24): each arm is a ridge with a lit and a shaded
## face (light from the top left), a darker rim below shows the thickness, a
## soft shadow sits under it and a shine on the top left. Popping in, a star
## turns round on its vertical axis like a coin.
class SummaryStars:
	extends Control

	const EMPTY_FILL := Color(0.86, 0.88, 0.92)
	const GOLD := Color(0.99, 0.76, 0.16)
	const RADIUS := 52.0
	const SIDE_DROP := 12.0 # outer stars sit a little lower
	const INNER := 0.47 # inner corners, share of the radius
	## Where the light comes from (screen space, towards the light).
	const LIGHT := Vector2(-0.6, -0.8)
	## How thick the star looks (share of the radius).
	const DEPTH := 0.1
	## Half-turns a star makes while popping in.
	const SPIN_TURNS := 1.0

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
			var earned_here := i < mini(earned, 3) or is_rainbow()
			# A grey star in every slot; the earned star pops in on top of it.
			_star3d(center, radius, 1.0, i, true)
			if earned_here:
				var s := shown[i]
				# The pop-in starts from nothing: a star a pixel wide has all
				# its points on top of each other and cannot be filled
				# ("Invalid polygon data, triangulation failed").
				if radius * s >= 1.5:
					# Turning round while it grows: the width follows the turn.
					var turn := cos((1.0 - clampf(s, 0.0, 1.0)) * PI * SPIN_TURNS)
					_star3d(center, radius * s, turn, i)
				if is_rainbow() and s >= 0.99:
					_sparkles(center, radius, i)

	## Rainbow stars twinkle: small four-point glints that come and go around
	## each star, each at its own pace.
	func _sparkles(center: Vector2, radius: float, index: int) -> void:
		for j in 4:
			var phase := _time * 2.4 + j * 1.7 + index * 0.9
			var glow := sin(phase)
			if glow <= 0.0:
				continue
			var angle := -PI * 0.75 + j * PI * 0.5 + index * 0.4 + sin(phase * 0.3) * 0.15
			var at := center + Vector2(cos(angle), sin(angle)) * radius * (1.08 + 0.08 * float(j % 2))
			var arm := radius * 0.22 * glow
			if arm < 1.5:
				continue # too small to fill (triangulation would fail)
			var waist := arm * 0.22
			var colour := Color.from_hsv(fposmod(j * 0.25 + index * 0.11 + _time * 0.12, 1.0), 0.25, 1.0, glow)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -arm), at + Vector2(waist, -waist), at + Vector2(arm, 0), at + Vector2(waist, waist),
				at + Vector2(0, arm), at + Vector2(-waist, waist), at + Vector2(-arm, 0), at + Vector2(-waist, -waist)]), colour)
			draw_circle(at, waist * 0.9, Color(1, 1, 1, glow))

	## The ten corners (tips at even indices), `squash` = width (-1..1) of a
	## star turned round its vertical axis.
	func _corners(center: Vector2, radius: float, squash: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for k in 10:
			var r := radius if k % 2 == 0 else radius * INNER
			var a := -PI / 2.0 + k * PI / 5.0
			points.append(center + Vector2(cos(a) * squash, sin(a)) * r)
		return points

	## Colour of arm `arm` (0..4): gold, or a rainbow hue moving with time.
	func _arm_colour(arm: int, index: int, empty := false) -> Color:
		if empty:
			return EMPTY_FILL
		if is_rainbow():
			return Color.from_hsv(fmod(arm / 5.0 + index * 0.18 + _time * 0.25, 1.0), 0.62, 1.0)
		return GOLD

	## Rainbow colour at point p of a star: the hue follows the angle round
	## the centre (a full rainbow once round) and drifts slowly with time.
	func _hue_at(p: Vector2, center: Vector2, index: int) -> Color:
		var angle := atan2(p.y - center.y, p.x - center.x)
		var hue := fposmod(angle / TAU + index * 0.11 + _time * 0.12, 1.0)
		return Color.from_hsv(hue, 0.58, 1.0)

	## Brighter towards the light (lit > 0), darker away from it.
	static func _shade(colour: Color, lit: float) -> Color:
		return colour.lightened(0.35 * lit) if lit > 0.0 else colour.darkened(-0.32 * lit)

	func _star3d(center: Vector2, radius: float, turn: float, index: int, empty := false) -> void:
		# Edge-on during the turn: too thin to fill (triangulation would fail).
		if radius * absf(turn) < 3.0:
			return
		var squash := maxf(absf(turn), 0.06) * signf(turn if turn != 0.0 else 1.0)
		var light := LIGHT.normalized()
		# Seen from behind (half-way through the turn) the light is on the other side.
		if turn < 0.0:
			light.x = -light.x
		var depth := radius * DEPTH
		# Soft shadow on the card under the star.
		var shadow := PackedVector2Array()
		for k in 24:
			var a := k * TAU / 24.0
			shadow.append(center + Vector2(cos(a) * radius * 0.78 * absf(squash) + 2.0, sin(a) * radius * 0.16 + radius * 0.98))
		draw_colored_polygon(shadow, Color(0.1, 0.12, 0.2, 0.12))
		# The rim: the same star a little lower and darker under the face, and
		# the side walls between them.
		var face := _corners(center, radius, squash)
		var rim := _corners(center + Vector2(0, depth), radius, squash)
		var rainbow := is_rainbow() and not empty
		if rainbow:
			var rim_colours := PackedColorArray()
			for p in rim:
				rim_colours.append(_hue_at(p, center, index).darkened(0.4))
			draw_polygon(rim, rim_colours)
		else:
			draw_colored_polygon(rim, _arm_colour(0, index, empty).darkened(0.2 if empty else 0.45))
		for k in 10:
			var arm := int((k + 1) / 2.0) % 5
			var wall := PackedVector2Array([face[k], face[(k + 1) % 10], rim[(k + 1) % 10], rim[k]])
			if absf((wall[1] - wall[0]).cross(wall[3] - wall[0])) <= 1.0:
				continue
			if rainbow:
				var a := _hue_at(face[k], center, index).darkened(0.32)
				var b := _hue_at(face[(k + 1) % 10], center, index).darkened(0.32)
				draw_polygon(wall, PackedColorArray([a, b, b.darkened(0.15), a.darkened(0.15)]))
			else:
				draw_colored_polygon(wall, _arm_colour(arm, index, empty).darkened(0.18 if empty else 0.42))
		# The face: two facets per arm meeting on the ridge from the centre
		# to the tip. A facet's slope faces out across its outer edge; the
		# more that faces the light, the brighter it is.
		var top := center + Vector2(0, -depth * 0.2)
		for arm in 5:
			var tip := face[arm * 2]
			var base := _arm_colour(arm, index, empty)
			for side in [-1, 1]:
				var inner := face[(arm * 2 + side + 10) % 10]
				var out := ((tip + inner) * 0.5 - center).normalized()
				var lit := out.dot(light)
				var strength := 0.5 if empty else 1.0
				if rainbow:
					# Hues flow round the star corner to corner; the middle is
					# pearl-white, so every facet blends from white into its colours.
					var pearl := _hue_at((tip + inner) * 0.5, center, index).lerp(Color.WHITE, 0.62)
					draw_polygon(PackedVector2Array([top, tip, inner]), PackedColorArray([
						_shade(pearl, lit * 0.6), _shade(_hue_at(tip, center, index), lit), _shade(_hue_at(inner, center, index), lit)]))
					continue
				var colour := _shade(base, lit * strength)
				draw_colored_polygon(PackedVector2Array([top, tip, inner]), colour)
		# Edge and shine.
		var outline := face.duplicate()
		outline.append(face[0])
		if rainbow:
			var edge := PackedColorArray()
			for p in outline:
				edge.append(_hue_at(p, center, index).darkened(0.38))
			draw_polyline_colors(outline, edge, 1.5, true)
		else:
			draw_polyline(outline, _arm_colour(0, index, empty).darkened(0.22 if empty else 0.5), 1.5, true)
		if empty:
			return
		var shine := top + Vector2(-radius * 0.22 * squash, -radius * 0.2)
		var spot := PackedVector2Array()
		for k in 16:
			var a := k * TAU / 16.0
			spot.append(shine + Vector2(cos(a) * radius * 0.09 * absf(squash), sin(a) * radius * 0.05).rotated(-0.6))
		draw_colored_polygon(spot, Color(1, 1, 1, 0.75))
