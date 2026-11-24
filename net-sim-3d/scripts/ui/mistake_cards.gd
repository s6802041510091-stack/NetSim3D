class_name MistakeCards
extends RefCounted

## The mistakes of an attempt as cards (teacher's request 2026-11-24: where
## the student went wrong, why it is wrong, and when). Used by the mission
## summary and the progress page. Each entry of the log (ObjectiveHUD.
## mistake_report) gives the line, the step and the level time:
##   เวลา       นาทีที่ 2:41  •  ขั้นที่ 3: <step>   (or "ตอนส่งงาน ..." when it
##              only counted as a mistake at the end)
##   จุดที่ผิด   the part of the line before " — "
##   เหตุผล     the part after it
## The whole line is translated first and then split, so English shows the
## same three rows (the halves alone are not in the catalog).

const FAIL := Color("d9584f")
const CAPTION_WIDTH := 92.0


## `label`: Callable(text: String, size: int, colour: Color, bold: bool) -> Label,
## so each screen keeps its own fonts. `width`: the text column's width.
static func build(parent: Control, log: Array, label: Callable, ink: Color, muted: Color, width: float) -> void:
	for i in log.size():
		if not log[i] is Dictionary:
			continue
		var e: Dictionary = log[i]
		var card := PanelContainer.new()
		card.name = "MistakeCard%d" % (i + 1)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(FAIL, 0.06)
		style.border_color = FAIL
		style.border_width_left = 4
		style.set_corner_radius_all(8)
		style.corner_radius_top_left = 0
		style.corner_radius_bottom_left = 0
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		parent.add_child(card)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 3)
		card.add_child(grid)
		var full := GameLocale.text(String(e.get("text", "")))
		var parts := full.split(" — ", true, 1)
		_row(grid, "เวลา", when_text(e), label, muted, FAIL.darkened(0.15), false, width, "MistakeWhen")
		_row(grid, "จุดที่ผิด", parts[0], label, muted, ink, true, width, "MistakeWhat")
		if parts.size() > 1 and parts[1].strip_edges() != "":
			_row(grid, "เหตุผล", parts[1], label, muted, ink, false, width, "MistakeWhy")


## "นาทีที่ 2:41  •  ขั้นที่ 3: <step>" in the current language.
static func when_text(e: Dictionary) -> String:
	var sec := roundi(float(e.get("at_sec", 0.0)))
	var at := "%d:%02d" % [sec / 60, sec % 60]
	var step := int(e.get("step", 0))
	var step_name := GameLocale.text(String(e.get("step_name", "")))
	var key := "ตอนส่งงาน นาทีที่ %s  •  ขั้นที่ %d: %s" if bool(e.get("at_end", false)) else "นาทีที่ %s  •  ขั้นที่ %d: %s"
	if step <= 0:
		key = "ตอนส่งงาน นาทีที่ %s" if bool(e.get("at_end", false)) else "นาทีที่ %s"
		return GameLocale.text(key) % at
	return GameLocale.text(key) % [at, step, step_name]


static func _row(grid: GridContainer, caption: String, value: String, label: Callable, muted: Color, colour: Color, bold: bool, width: float, value_name: String) -> void:
	var c: Label = label.call(caption, 14, muted, false)
	c.custom_minimum_size.x = CAPTION_WIDTH
	c.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	grid.add_child(c)
	var v: Label = label.call(value, 15, colour, bold)
	v.name = value_name
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.custom_minimum_size.x = width
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)
