class_name ProgressDashboard
extends RefCounted

## "ความคืบหน้า" page of the main menu (added 2026-11-18): a summary of every
## level and a details page per level, built into the menu card of
## game_flow.gd. It reads only GameProgress (progress.json in this browser /
## on this computer), so a learner sees nothing but their own results; there
## are no accounts yet (Supabase is deferred).

const INK := Color("20364c")
const MUTED := Color("526b81")
const BLUE := Color("237db1")
const PASS := Color("1f9a55")
const FAIL := Color("d9584f")
## The step that took longest (time per step card).
const SLOW := Color("e08a1e")
const IDLE := Color("8c9bab")
const HEADING_FONT := preload("res://assets/fonts/Mitr-Medium.ttf")
const BODY_FONT := preload("res://assets/fonts/Mitr-Regular.ttf")
const MONTHS := ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
const MONTHS_EN := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## Attempts drawn in the score chart of a level (newest on the right).
const CHART_ATTEMPTS := 12


# ---------------------------------------------------------------- overview

## Tiles for the whole game, then one row per level. `unlocked(level)` and
## `open_level(level)` come from game_flow.
static func build_overview(body: VBoxContainer, titles: Array, available: Array, unlocked: Callable, open_level: Callable) -> void:
	var played := 0
	var passed := 0
	var stars := 0
	var rainbow := 0
	var best_sum := 0
	var attempts := 0
	for level in range(1, titles.size() + 1):
		var record := GameProgress.level_record(level)
		if record.is_empty():
			continue
		played += 1
		var best := int(record.get("best_total", 0))
		best_sum += best
		attempts += int(record.get("attempts", 0))
		if best >= MissionScore.PASS_SCORE:
			passed += 1
		stars += mini(int(record.get("best_stars", 0)), 3)
		if int(record.get("best_stars", 0)) >= 4:
			rainbow += 1
	var tiles := _tile_row(body)
	_tile(tiles, "%d / %d" % [passed, titles.size()], "ด่านที่ผ่านแล้ว", PASS if passed > 0 else INK)
	_tile(tiles, "%d / %d" % [stars, titles.size() * 3], "ดาวที่ได้" + ("  (สีรุ้ง %d ด่าน)" % rainbow if rainbow > 0 else ""), Color("c98a06"))
	_tile(tiles, str(roundi(float(best_sum) / played)) if played > 0 else "–", "คะแนนสูงสุดเฉลี่ย", BLUE)
	_tile(tiles, str(attempts), "เล่นไปทั้งหมด (ครั้ง)", INK)

	var levels_box := _section(body, "ผลแต่ละด่าน", BLUE, "กด \"ดูรายละเอียด\" เพื่อดูคะแนนแต่ละครั้ง")
	levels_box.name = "LevelsSection"
	for level in range(1, titles.size() + 1):
		_level_row(levels_box, level, String(titles[level - 1]), level in available, bool(unlocked.call(level)), open_level)


static func _level_row(body: VBoxContainer, level: int, title: String, built: bool, is_unlocked: bool, open_level: Callable) -> void:
	var record := GameProgress.level_record(level)
	var best_total := int(record.get("best_total", -1))
	var edge := IDLE if record.is_empty() else (PASS if best_total >= MissionScore.PASS_SCORE else FAIL)
	var card := PanelContainer.new()
	card.name = "Level%dRow" % level
	var card_style := _box(Color("f6f9fd"), edge, 12, 18, 12)
	# Status colour on the left edge only: green passed, red not yet, grey unplayed.
	card_style.set_border_width_all(0)
	card_style.border_width_left = 7
	card.add_theme_stylebox_override("panel", card_style)
	body.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	# Drawn as a real circle: a StyleBoxFlat whose corner radius is half its
	# size leaves a thin seam down the middle in the Compatibility renderer.
	var badge := NumberBadge.new()
	badge.name = "Badge"
	badge.number = str(level)
	badge.colour = edge
	badge.custom_minimum_size = Vector2(46, 46)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)

	var name_box := VBoxContainer.new()
	name_box.custom_minimum_size.x = 220
	name_box.add_theme_constant_override("separation", 0)
	row.add_child(name_box)
	_text(name_box, "ด่าน %d" % level, 15, MUTED)
	_text(name_box, title, 20, INK, true)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 4)
	row.add_child(middle)
	var status: String
	var colour: Color
	if record.is_empty():
		status = "ยังไม่ได้เล่น" if built and is_unlocked else ("ล็อกอยู่ — ผ่านด่านก่อนหน้าก่อน" if built else "กำลังพัฒนา")
		colour = IDLE
		_text(middle, status, 16, MUTED)
	else:
		var best := int(record.get("best_total", 0))
		var best_stars := int(record.get("best_stars", 0))
		status = "ผ่านแล้ว" if best >= MissionScore.PASS_SCORE else "ยังไม่ผ่าน"
		colour = PASS if best >= MissionScore.PASS_SCORE else FAIL
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		middle.add_child(line)
		var bar := _bar(best, 100, colour)
		bar.name = "BestBar"
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(bar)
		_text(line, "%d / 100" % best, 18, INK, true)
		var star := _text(line, _stars(best_stars), 18, Color("c98a06"), true)
		star.custom_minimum_size.x = 92
		var last: Dictionary = record.get("last", {}) if record.get("last", {}) is Dictionary else {}
		_text(middle, "เล่น %d ครั้ง  •  ล่าสุด %s" % [int(record.get("attempts", 0)), thai_date(String(last.get("finished_at", "")))], 15, MUTED)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size.x = 150
	row.add_child(right)
	var chip := _chip(status if not record.is_empty() else ("ยังไม่ได้เล่น" if built and is_unlocked else "ล็อกอยู่"), colour)
	right.add_child(chip)
	var details := _link("ดูรายละเอียด  ›", open_level.bind(level))
	details.name = "Level%dDetails" % level
	details.disabled = record.is_empty()
	details.tooltip_text = "ยังไม่มีผลการเล่นของด่านนี้" if record.is_empty() else "ดูคะแนนแต่ละครั้งและจุดที่ผิดพลาด"
	right.add_child(details)


# ---------------------------------------------------------------- one level

static func build_level(body: VBoxContainer, level: int) -> void:
	var record := GameProgress.level_record(level)
	var attempts := GameProgress.history(level)
	if record.is_empty() or attempts.is_empty():
		_text(body, "ยังไม่มีผลการเล่นของด่านนี้", 18, MUTED)
		return
	var total_attempts := maxi(int(record.get("attempts", attempts.size())), attempts.size())
	var best_time := INF
	var first_pass := ""
	for entry: Dictionary in attempts:
		if bool(entry.get("passed", false)):
			best_time = minf(best_time, float(entry.get("elapsed_sec", INF)))
			if first_pass == "":
				first_pass = String(entry.get("finished_at", ""))
	var tiles := _tile_row(body)
	var best := int(record.get("best_total", 0))
	_tile(tiles, "%d / 100" % best, "คะแนนสูงสุด", PASS if best >= MissionScore.PASS_SCORE else FAIL)
	_tile(tiles, _stars(int(record.get("best_stars", 0))), "ดาวสูงสุด", Color("c98a06"))
	_tile(tiles, str(total_attempts), "เล่นไปแล้ว (ครั้ง)", INK)
	_tile(tiles, clock(best_time) if best_time < INF else "–", "เวลาดีที่สุดที่ผ่าน", BLUE)

	var chart_box := _section(body, "คะแนนแต่ละครั้ง", BLUE, "เส้นแดง = เกณฑ์ผ่าน %d คะแนน" % MissionScore.PASS_SCORE)
	var chart := ScoreChart.new()
	chart.name = "ScoreChart"
	chart.scores = []
	var shown := attempts.slice(maxi(attempts.size() - CHART_ATTEMPTS, 0))
	var first_number := total_attempts - shown.size() + 1
	for entry: Dictionary in shown:
		chart.scores.append(int(entry.get("total", 0)))
	chart.first_number = first_number
	chart.custom_minimum_size = Vector2(0, 190)
	chart_box.add_child(chart)

	# Latest attempt: the three score parts, then time and decisions as two small boxes.
	var last: Dictionary = attempts[attempts.size() - 1]
	var last_ok := bool(last.get("passed", false))
	var result_box := _section(body, "ผลครั้งล่าสุด", PASS if last_ok else FAIL, thai_date(String(last.get("finished_at", ""))))
	_part(result_box, "ความถูกต้องของผลงาน", int(last.get("correctness", 0)), MissionScore.CORRECTNESS_MAX)
	_part(result_box, "กระบวนการทำงาน", int(last.get("process", 0)), MissionScore.PROCESS_MAX)
	_part(result_box, "ประสิทธิภาพด้านเวลา", int(last.get("time", 0)), MissionScore.TIME_MAX)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 12)
	result_box.add_child(facts)
	_fact(facts, "คะแนนรวม", "%d / 100  •  %s" % [int(last.get("total", 0)), "ผ่าน" if last_ok else "ไม่ผ่าน"], PASS if last_ok else FAIL)
	_fact(facts, "เวลาที่ใช้", clock(float(last.get("elapsed_sec", 0.0))), BLUE)
	var decisions := int(last.get("decisions_total", 0))
	if decisions > 0:
		var right := int(last.get("decisions_correct", 0))
		_fact(facts, "การตัดสินใจ", "ถูก %d  •  ผิด %d  จาก %d" % [right, decisions - right, decisions], INK)

	_step_times(body, attempts)

	# Mistakes of the latest attempt, each on its own tinted line.
	var mistakes: Variant = last.get("mistakes", [])
	var clean: bool = not mistakes is Array or mistakes.is_empty()
	var mistakes_box := _section(body, "จุดที่ผิดพลาด", PASS if clean else FAIL, "ครั้งล่าสุด" if clean else "ครั้งล่าสุด  •  %d จุด" % mistakes.size())
	var log: Variant = last.get("mistake_log", [])
	if clean:
		_note(mistakes_box, "ไม่มี ทำได้ถูกต้องทุกขั้นตอน", PASS)
	elif log is Array and (log as Array).size() == mistakes.size():
		# Where, why and when for each one.
		MistakeCards.build(mistakes_box, log, _new_label, INK, MUTED, 600.0)
	else:
		for line in mistakes:
			var mistake := _note(mistakes_box, String(line), FAIL)
			mistake.name = "Mistake"

	# Every attempt, newest first: a header strip and striped rows.
	var history_box := _section(body, "ประวัติการเล่น", Color("7a5cc2"), "ใหม่สุดอยู่บน")
	var table := VBoxContainer.new()
	table.name = "HistoryTable"
	table.add_theme_constant_override("separation", 0)
	history_box.add_child(table)
	_history_row(table, ["ครั้งที่", "วันที่เล่น", "คะแนน", "ดาว", "เวลา", "ผล"], Color("e6f0f9"), true)
	for i in range(attempts.size() - 1, -1, -1):
		var entry: Dictionary = attempts[i]
		var ok := bool(entry.get("passed", false))
		var stripe := Color("ffffff") if (attempts.size() - 1 - i) % 2 == 0 else Color("f3f7fb")
		_history_row(table, [str(total_attempts - (attempts.size() - 1 - i)), thai_date(String(entry.get("finished_at", ""))),
			"%d / 100" % int(entry.get("total", 0)), _stars(int(entry.get("stars", 0))),
			clock(float(entry.get("elapsed_sec", 0.0))), "ผ่าน" if ok else "ไม่ผ่าน"], stripe, false, ok)
	if total_attempts > attempts.size():
		_text(history_box, "แสดง %d ครั้งล่าสุดจากทั้งหมด %d ครั้ง (ผลรายครั้งเริ่มเก็บตั้งแต่ 18 พ.ย. 2569)" % [attempts.size(), total_attempts], 14, MUTED)


## Time on each step of the latest attempt (teacher's request 2026-11-24):
## one bar per step, the longest in orange; under it the average over every
## recorded attempt with the same steps, when there is more than one.
static func _step_times(body: VBoxContainer, attempts: Array) -> void:
	var last: Dictionary = attempts[attempts.size() - 1]
	var steps: Variant = last.get("step_times", [])
	var box := _section(body, "เวลาแต่ละขั้นตอน", SLOW, "ครั้งล่าสุด  •  สีส้ม = ขั้นที่ใช้เวลานานที่สุด")
	box.get_parent().name = "StepTimes"
	if not steps is Array or (steps as Array).is_empty():
		_note(box, "ครั้งนี้ยังไม่มีเวลารายขั้นตอน (เริ่มเก็บตั้งแต่ 24 พ.ย. 2569)", MUTED)
		return
	var list: Array = steps
	# Averages: attempts that recorded the same number of steps.
	var sums := []
	var counted := 0
	for entry: Dictionary in attempts:
		var other: Variant = entry.get("step_times", [])
		if other is Array and (other as Array).size() == list.size():
			counted += 1
			for i in list.size():
				if sums.size() <= i:
					sums.append(0.0)
				sums[i] = float(sums[i]) + float((other as Array)[i].get("sec", 0.0))
	var longest := 0.0
	var total := 0.0
	for step: Dictionary in list:
		longest = maxf(longest, float(step.get("sec", 0.0)))
		total += float(step.get("sec", 0.0))
	for i in list.size():
		var step: Dictionary = list[i]
		var sec := float(step.get("sec", 0.0))
		var slow := sec >= longest and longest > 0.0
		var row := HBoxContainer.new()
		row.name = "StepTime%d" % (i + 1)
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var name_label := _text(row, "%d. %s" % [int(step.get("step", i + 1)), String(step.get("name", ""))], 16, INK, slow)
		name_label.name = "StepName"
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.x = 330
		var bar := _bar(roundi(sec * 10.0), maxi(roundi(longest * 10.0), 1), SLOW if slow else BLUE)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var times := VBoxContainer.new()
		times.add_theme_constant_override("separation", -2)
		times.custom_minimum_size.x = 118
		times.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(times)
		var now := _text(times, clock(sec), 16, SLOW.darkened(0.2) if slow else INK, true)
		now.name = "StepSeconds"
		if counted > 1:
			_text(times, "เฉลี่ย %s" % clock(float(sums[i]) / counted), 13, MUTED)
	var foot := "รวมทุกขั้นตอน %s" % clock(total)
	if counted > 1:
		foot += "  •  ค่าเฉลี่ยจาก %d ครั้งที่เล่น" % counted
	_text(box, foot, 14, MUTED)


# ---------------------------------------------------------------- formatting

## "2026-11-18T19:34:43" -> "18 พ.ย. 2569  19:34" (Buddhist year).
static func thai_date(iso: String) -> String:
	if iso.length() < 16:
		return "–"
	var month := clampi(iso.substr(5, 2).to_int(), 1, 12)
	var year := iso.substr(0, 4).to_int()
	if L10n.locale == "en":
		return "%d %s %d  %s" % [iso.substr(8, 2).to_int(), MONTHS_EN[month - 1], year, iso.substr(11, 5)]
	return "%d %s %d  %s" % [iso.substr(8, 2).to_int(), MONTHS[month - 1], year + 543, iso.substr(11, 5)]


static func clock(seconds: float) -> String:
	var s := roundi(seconds)
	return "%d:%02d นาที" % [s / 60, s % 60]


static func _stars(stars: int) -> String:
	if stars >= 4:
		return "★★★ สีรุ้ง"
	return "★".repeat(stars) + "☆".repeat(3 - clampi(stars, 0, 3))


# ---------------------------------------------------------------- widgets

static func _text(parent: Control, text: String, size: int, colour: Color, heading := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", HEADING_FONT if heading else BODY_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if parent is VBoxContainer:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


## A label in the page's fonts, not yet placed (MistakeCards places it).
static func _new_label(text: String, size: int, colour: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", HEADING_FONT if bold else BODY_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


static func _box(bg: Color, border: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style


## A white card with a coloured bar and title (and a grey note on the right);
## returns the column the section's content goes into.
static func _section(body: VBoxContainer, title: String, accent: Color, note := "") -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = "Section%d" % body.get_child_count()
	var style := _box(Color("ffffff"), Color("dbe6f0"), 16, 20, 14)
	style.shadow_color = Color("1f375c22")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", style)
	body.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(6, 28)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("panel", _box(accent, Color.TRANSPARENT, 3, 0, 0))
	header.add_child(bar)
	var heading := _text(header, title, 21, INK, true)
	heading.name = "SectionTitle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if note != "":
		_text(header, note, 15, MUTED)
	var line := ColorRect.new()
	line.color = Color("e3ebf3")
	line.custom_minimum_size = Vector2(0, 2)
	column.add_child(line)
	return column


## A small tinted box: caption above, value below.
static func _fact(row: HBoxContainer, caption: String, value: String, colour: Color) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _box(Color(colour, 0.08), Color(colour, 0.3), 12, 14, 8))
	row.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	box.add_child(column)
	_text(column, caption, 14, MUTED)
	_text(column, value, 18, colour.darkened(0.1), true)


## One tinted line (a mistake, or the "no mistakes" message).
static func _note(column: VBoxContainer, text: String, colour: Color) -> Label:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(Color(colour, 0.07), Color(colour, 0.25), 10, 14, 7))
	column.add_child(box)
	var holder := VBoxContainer.new()
	box.add_child(holder)
	return _text(holder, text, 16, INK)


const HISTORY_WIDTHS := [70, 230, 120, 140, 120, 0]

## A row of the history table; the last column (result) is a chip.
static func _history_row(table: VBoxContainer, cells: Array, bg: Color, header: bool, ok := false) -> void:
	var panel := PanelContainer.new()
	panel.name = "HistoryHeader" if header else "HistoryRow"
	panel.add_theme_stylebox_override("panel", _box(bg, Color.TRANSPARENT, 8, 14, 7))
	table.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	for i in cells.size():
		if i == cells.size() - 1 and not header:
			var chip := _chip(String(cells[i]), PASS if ok else FAIL)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			row.add_child(chip)
			continue
		var colour := MUTED if header else (Color("c98a06") if i == 3 else INK)
		var label := _text(row, String(cells[i]), 15 if header else 16, colour, header or i == 2)
		label.name = "Cell%d" % i
		if HISTORY_WIDTHS[i] > 0:
			label.custom_minimum_size.x = HISTORY_WIDTHS[i]
		else:
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func _tile_row(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SummaryTiles"
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	return row


static func _tile(row: HBoxContainer, value: String, caption: String, colour: Color) -> void:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _box(Color("ffffff"), colour, 14, 14, 10)
	# A coloured top edge per figure, the rest of the border stays light.
	style.set_border_width_all(0)
	style.border_width_top = 5
	style.shadow_color = Color("1f375c22")
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	tile.add_theme_stylebox_override("panel", style)
	row.add_child(tile)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	tile.add_child(column)
	var big := _text(column, value, 28, colour, true)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var small := _text(column, caption, 15, MUTED)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _bar(value: int, max_value: int, colour: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _box(Color("e3eaf1"), Color.TRANSPARENT, 8, 0, 0))
	bar.add_theme_stylebox_override("fill", _box(colour, Color.TRANSPARENT, 8, 0, 0))
	return bar


static func _part(body: VBoxContainer, name_text: String, points: int, max_points: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var name_label := _text(row, name_text, 16, INK)
	name_label.custom_minimum_size.x = 230
	var bar := _bar(points, max_points, BLUE)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var points_label := _text(row, "%d / %d" % [points, max_points], 16, INK, true)
	points_label.custom_minimum_size.x = 70


static func _pair(body: VBoxContainer, name_text: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var name_label := _text(row, name_text, 16, MUTED)
	name_label.custom_minimum_size.x = 230
	_text(row, value, 16, INK, true)


static func _chip(text: String, colour: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Status"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _box(Color(colour, 0.14), Color(colour, 0.55), 12, 12, 3))
	var label := _text(chip, text, 15, colour.darkened(0.15), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return chip


static func _link(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_override("font", HEADING_FONT)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["font_color", "font_focus_color"]:
		button.add_theme_color_override(state, BLUE)
	button.add_theme_color_override("font_hover_color", BLUE.darkened(0.25))
	button.add_theme_color_override("font_disabled_color", Color(IDLE, 0.6))
	button.pressed.connect(action)
	return button


## Bars of the total score per attempt, with the pass line at 50.
class ScoreChart extends Control:
	var scores: Array = []
	var first_number := 1

	func _draw() -> void:
		var font := ProgressDashboard.BODY_FONT
		var top := 22.0
		var bottom := size.y - 26.0
		var left := 34.0
		var plot_h := bottom - top
		var plot_w := size.x - left - 8.0
		for mark in [0, 50, 100]:
			var y: float = bottom - plot_h * mark / 100.0
			var line_colour: Color = Color(ProgressDashboard.FAIL, 0.7) if mark == MissionScore.PASS_SCORE else Color("c9d6e2")
			draw_line(Vector2(left, y), Vector2(left + plot_w, y), line_colour, 1.0 if mark != MissionScore.PASS_SCORE else 2.0)
			draw_string(font, Vector2(0, y + 5), str(mark), HORIZONTAL_ALIGNMENT_RIGHT, left - 6, 13, ProgressDashboard.MUTED)
		if scores.is_empty():
			return
		var slot := plot_w / maxf(scores.size(), 6)
		var bar_w := minf(slot * 0.6, 46.0)
		for i in scores.size():
			var score: int = scores[i]
			var x := left + slot * i + (slot - bar_w) / 2.0
			var h := plot_h * score / 100.0
			var colour := ProgressDashboard.PASS if score >= MissionScore.PASS_SCORE else ProgressDashboard.FAIL
			draw_rect(Rect2(x, bottom - h, bar_w, maxf(h, 2.0)), colour)
			draw_string(font, Vector2(x - 10, bottom - h - 5), str(score), HORIZONTAL_ALIGNMENT_CENTER, bar_w + 20, 14, ProgressDashboard.INK)
			draw_string(font, Vector2(x - 14, bottom + 18), "#%d" % (first_number + i), HORIZONTAL_ALIGNMENT_CENTER, bar_w + 28, 13, ProgressDashboard.MUTED)


## Level number in a tinted circle with a thin ring.
class NumberBadge extends Control:
	var number := ""
	var colour := Color.GRAY

	func _draw() -> void:
		var centre := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 1.0
		draw_circle(centre, radius, Color(colour, 0.16), true, -1.0, true)
		draw_arc(centre, radius, 0.0, TAU, 64, Color(colour, 0.6), 1.5, true)
		var font: Font = ProgressDashboard.HEADING_FONT
		var font_size := 22
		var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		draw_string(font, Vector2(centre.x - text_size.x / 2.0, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour.darkened(0.2))
