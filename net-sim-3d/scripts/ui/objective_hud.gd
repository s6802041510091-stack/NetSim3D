class_name ObjectiveHUD
extends CanvasLayer

## Top-left "current objective" panel plus a short toast at the top centre
## (e.g. "ได้รับภารกิจ: ..."). Missions call set_objective() as the story moves on.
## The panel folds to a small "ภารกิจ" tab with Tab or its arrow button, and
## missions can fold it automatically while the player uses a computer.
##
## The standard for every level is set_steps(): the whole mission as numbered
## steps in order — done = ticked box, the current step = amber, steps not
## reached yet = faint grey.
##
## Look (playtest 2026-11-24: the old rounded blue glass card "looked AI-made"):
## a dark work ticket with a square amber edge on the left, the same amber as
## the objective arrow, and drawn check boxes instead of font glyphs.
## The step's how-to hint is held back (playtest: it read like an answer key)
## and only shows after the player has been on the same step for HINT_DELAY.

signal collapsed_changed(collapsed: bool)

const PANEL_WIDTH := 330.0
## Mitr sets Thai lines tall: pull wrapped lines closer in the panel.
const LINE_TIGHTEN := -6
const STEP_DONE := "done"
const STEP_ACTIVE := "active"
const STEP_TODO := "todo"
const COLOR_TICKET := Color(0.98, 0.74, 0.22)
const COLOR_DONE := Color(0.56, 0.74, 0.60)
const COLOR_ACTIVE := Color(1.0, 0.86, 0.55)
const COLOR_TODO := Color(1, 1, 1, 0.36)
const COLOR_HINT := Color(0.80, 0.78, 0.70)
const PANEL_BG := Color(0.075, 0.08, 0.09, 0.93)
## Seconds on one step before its hint appears.
const HINT_DELAY := 75.0
const BOX_SIZE := 13.0

## Space kept free on the right (e.g. for a SidePanel), so the panel moves left of it.
var right_inset := 0.0:
	set(value):
		right_inset = value
		_refresh()
## The steps shown now: [[text, STEP_DONE / STEP_ACTIVE / STEP_TODO], ...]
var steps: Array = []
var _heading: Label
var _steps_box: VBoxContainer
## The step list scrolls (mouse wheel) when it is taller than this.
const STEPS_MAX_HEIGHT := 250.0
const WHEEL_STEP := 36.0
var _steps_scroll: ScrollContainer
var _active_row: Control

var objective_text: String = ""
var collapsed := false
## True while folded automatically (e.g. at a computer); restores on release.
var auto_collapsed := false
var _collapsed_before_auto := false
var _objective_panel: PanelContainer
var _objective_title: Label
var _objective_hint: Label
var _objective_label: Label
var _toggle: Button
var _toast_panel: PanelContainer
var _toast_label: Label
var _rule: ColorRect
## The held-back hint of the current step, and how long the player has been on it.
var _hint_row: Control
var _hint_key := ""
var _step_time := 0.0
## Time on each step (teacher's request 2026-11-24: which step takes a
## student long): seconds of game time while that step was the current one
## (index = step number - 1; a pause menu stops it), and the step's words as
## last shown. Missions put step_report() in the attempt they record.
var step_seconds: Array = []
var step_names := PackedStringArray()
var _active_index := -1

## When each mistake happened (teacher's request 2026-11-24: where, why and
## when). The mission gives `mistake_source` (its current mistake lines, e.g.
## state.mistakes()); twice a second new lines are stamped with the step being
## played and the level time (sum of step_seconds). Lines already there at
## the start ("not attached yet") are not mistakes until the level ends, so
## they get the time of hand-in if they are still there then.
var mistake_source: Callable
## line key -> {step, step_name, at}
var mistake_seen := {}
## Keys present at the first look (line key -> true).
var mistake_baseline := {}
var _mistakes_started := false
var _mistake_clock := 0.0
const MISTAKE_POLL := 0.5
var _digits := RegEx.create_from_string("\\d+")


## The ticket: square corners, a thick coloured edge on the left only.
static func ticket_box(edge: Color, pad_x: int = 14, pad_y: int = 11) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = edge
	s.border_width_left = 4
	s.set_corner_radius_all(2)
	s.content_margin_left = pad_x + 2
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## A small drawn check box for a step (no ✓/▸ glyph needed in the font).
static func _step_box(state: String) -> Control:
	var box := Control.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(BOX_SIZE + 3, BOX_SIZE + 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(_draw_step_box.bind(box, state))
	return box


static func _draw_step_box(box: Control, state: String) -> void:
	var r := Rect2(Vector2(1, 5), Vector2(BOX_SIZE, BOX_SIZE))
	if state == STEP_DONE:
		box.draw_rect(r, COLOR_DONE)
		box.draw_polyline(PackedVector2Array([r.position + Vector2(3, 6.5), r.position + Vector2(5.5, 9.5), r.position + Vector2(10.5, 3.5)]), Color(PANEL_BG, 1.0), 2.0, true)
	elif state == STEP_ACTIVE:
		box.draw_rect(r, COLOR_TICKET, false, 2.0)
		box.draw_rect(r.grow(-3.5), COLOR_TICKET)
	else:
		box.draw_rect(r, COLOR_TODO, false, 1.5)


func _ready() -> void:
	layer = 12
	_objective_panel = PanelContainer.new()
	_objective_panel.name = "ObjectivePanel"
	_objective_panel.position = Vector2(20, 20)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_theme_stylebox_override("panel", ticket_box(COLOR_TICKET))
	add_child(_objective_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_row)
	_objective_title = GameUI.label("", 13, COLOR_TICKET, true)
	title_row.add_child(_objective_title)
	_objective_hint = GameUI.label("", 12, Color(1, 1, 1, 0.38))
	_objective_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_objective_hint.name = "HintLabel"
	title_row.add_child(_objective_hint)
	_objective_label = GameUI.label("", 16, Color.WHITE)
	_objective_label.add_theme_constant_override("line_spacing", LINE_TIGHTEN)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 0)
	col.add_child(_objective_label)
	_heading = GameUI.label("", 15, Color.WHITE, true)
	_heading.add_theme_constant_override("line_spacing", LINE_TIGHTEN)
	_heading.name = "Heading"
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 0)
	col.add_child(_heading)
	# A thin amber rule between the job's name and its steps.
	_rule = ColorRect.new()
	_rule.name = "Rule"
	_rule.color = Color(COLOR_TICKET, 0.28)
	_rule.custom_minimum_size = Vector2(0, 1)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rule_gap := MarginContainer.new()
	rule_gap.add_theme_constant_override("margin_top", 5)
	rule_gap.add_theme_constant_override("margin_bottom", 5)
	rule_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_gap.add_child(_rule)
	col.add_child(rule_gap)
	_steps_box = VBoxContainer.new()
	_steps_box.name = "Steps"
	_steps_box.add_theme_constant_override("separation", 2)
	_steps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_scroll = ScrollContainer.new()
	_steps_scroll.name = "StepsScroll"
	_steps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_steps_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_steps_scroll)
	_steps_scroll.add_child(_steps_box)
	_toggle = Button.new()
	_toggle.name = "ToggleButton"
	_toggle.set_meta("sound", "") # toggle() plays the fold sound
	_toggle.custom_minimum_size = Vector2(26, 26)
	_toggle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.tooltip_text = "ซ่อน/แสดงภารกิจ (Tab)"
	_toggle.add_theme_stylebox_override("normal", GameUI.box(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.14), 2, 0, 0))
	_toggle.add_theme_stylebox_override("hover", GameUI.box(Color(COLOR_TICKET, 0.16), Color(COLOR_TICKET, 0.5), 2, 0, 0))
	_toggle.add_theme_stylebox_override("pressed", GameUI.box(Color(COLOR_TICKET, 0.26), Color(COLOR_TICKET, 0.6), 2, 0, 0))
	# Chevron drawn (no font glyph needed). The panel sits on the right edge:
	# open -> points right (fold away), folded -> points left (open out).
	_toggle.draw.connect(func():
		var c := _toggle.size * 0.5
		var d := -5.0 if collapsed else 5.0
		_toggle.draw_polyline(PackedVector2Array([c + Vector2(-d * 0.6, -6), c + Vector2(d * 0.6, 0), c + Vector2(-d * 0.6, 6)]), Color(1, 1, 1, 0.75), 2.0, true))
	_toggle.pressed.connect(toggle)
	row.add_child(_toggle)
	_objective_panel.visible = false

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	# Shifted left to stay clear of the objective panel (top-right, 330 px + margins) on a 1280 px screen.
	_toast_panel.offset_left = -400
	_toast_panel.offset_right = 180
	_toast_panel.offset_top = 24
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", ticket_box(COLOR_DONE, 20, 12))
	add_child(_toast_panel)
	_toast_label = GameUI.label("", 18, Color.WHITE, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	_refresh()


func set_objective(text: String, title: String = "ภารกิจตอนนี้") -> void:
	if text != objective_text and text != "":
		Sound.play("objective")
	objective_text = text
	steps = []
	_clear_steps()
	_heading.text = ""
	_objective_title.set_meta("title", title)
	# Keep names such as "IT-PC-01" on one line (word joiner after each hyphen).
	_objective_label.text = DialogueBox.keep_together(text).replace("-", "-⁠")
	_refresh()


## Step states for a mission done in order: before `current` done, `current`
## active, after it not reached yet (current >= size: all done).
static func sequence(texts: Array, current: int) -> Array:
	var out := []
	for i in texts.size():
		out.append([texts[i], STEP_DONE if i < current else (STEP_ACTIVE if i == current else STEP_TODO)])
	return out


## Step states from what is finished: done ones green, the first unfinished
## one active, the rest not reached yet.
static func from_done(texts: Array, done: Array) -> Array:
	var out := []
	var active_given := false
	for i in texts.size():
		var finished: bool = i < done.size() and bool(done[i])
		var state := STEP_DONE if finished else (STEP_TODO if active_given else STEP_ACTIVE)
		if state == STEP_ACTIVE:
			active_given = true
		out.append([texts[i], state])
	return out


## The standard tracker: `step_list` = [[text, state], ...] (see sequence()),
## `hint` = what to do now (under the active step), `heading` = the mission's
## name, `title` = the small header ("ภารกิจที่ 3"). objective_text holds the
## same words as plain text.
func set_steps(step_list: Array, hint: String = "", heading: String = "", title: String = "ภารกิจตอนนี้") -> void:
	var plain := PackedStringArray()
	if heading != "":
		plain.append(heading)
	for i in step_list.size():
		var mark := "✓" if step_list[i][1] == STEP_DONE else ("▸" if step_list[i][1] == STEP_ACTIVE else "•")
		plain.append("%s %d. %s" % [mark, i + 1, step_list[i][0]])
		if step_list[i][1] == STEP_ACTIVE and hint != "":
			plain.append(hint)
	var text := "\n".join(plain)
	if text != objective_text:
		Sound.play("objective")
	objective_text = text
	steps = step_list.duplicate(true)
	_objective_title.set_meta("title", title)
	_objective_label.text = ""
	_heading.text = heading
	_clear_steps()
	# A new step (or a new mission) starts the hint's clock again; a changed
	# count on the same step ("(1/2)") does not.
	var active_index := -1
	for i in step_list.size():
		if step_list[i][1] == STEP_ACTIVE:
			active_index = i
			break
	_active_index = active_index
	while step_seconds.size() < step_list.size():
		step_seconds.append(0.0)
	step_names.resize(maxi(step_names.size(), step_list.size()))
	for i in step_list.size():
		step_names[i] = String(step_list[i][0])
	var key := "%s#%d" % [heading, active_index]
	if key != _hint_key:
		_hint_key = key
		_step_time = 0.0
	for i in step_list.size():
		var state: String = step_list[i][1]
		var color := COLOR_DONE if state == STEP_DONE else (COLOR_ACTIVE if state == STEP_ACTIVE else COLOR_TODO)
		var row := HBoxContainer.new()
		row.name = "Step%d" % (i + 1)
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_steps_box.add_child(row)
		if state == STEP_ACTIVE:
			_active_row = row
		row.add_child(_step_box(state))
		var label := GameUI.label("%d. %s" % [i + 1, DialogueBox.keep_together(String(step_list[i][0])).replace("-", "-⁠")], 14, color, state == STEP_ACTIVE)
		label.add_theme_constant_override("line_spacing", LINE_TIGHTEN)
		label.name = "Text"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(PANEL_WIDTH - 86, 0)
		row.add_child(label)
		if state == STEP_ACTIVE and hint != "":
			var hint_label := GameUI.label("คำใบ้ · " + DialogueBox.keep_together(hint).replace("-", "-⁠"), 13, COLOR_HINT)
			hint_label.add_theme_constant_override("line_spacing", LINE_TIGHTEN)
			hint_label.name = "Hint"
			hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint_label.custom_minimum_size = Vector2(PANEL_WIDTH - 86, 0)
			var indent := MarginContainer.new()
			indent.name = "HintRow"
			indent.add_theme_constant_override("margin_left", int(BOX_SIZE) + 11)
			indent.add_theme_constant_override("margin_bottom", 3)
			indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			indent.add_child(hint_label)
			indent.visible = _step_time >= HINT_DELAY
			_steps_box.add_child(indent)
			_hint_row = indent
	_refresh()
	# Wrapped lines know their height only after layout: fit the panel again.
	_refit_later()


func _refit_later() -> void:
	await get_tree().process_frame
	_refresh()
	await get_tree().process_frame
	# Keep the current step in view.
	if is_instance_valid(_active_row) and _active_row.get_parent() == _steps_box:
		_steps_scroll.scroll_vertical = int(maxf(_active_row.position.y - 40.0, 0.0))


## True when the steps do not all fit and the wheel scrolls them.
func steps_scrollable() -> bool:
	return _steps_box != null and _steps_box.get_combined_minimum_size().y > STEPS_MAX_HEIGHT + 1.0


func _clear_steps() -> void:
	if _steps_box == null:
		return
	_active_row = null
	_hint_row = null
	for child in _steps_box.get_children():
		_steps_box.remove_child(child)
		child.queue_free()


func toggle() -> void:
	Sound.play("toggle_on" if collapsed else "toggle_off")
	set_collapsed(not collapsed)


func set_collapsed(value: bool) -> void:
	if collapsed == value:
		return
	collapsed = value
	_refresh()
	collapsed_changed.emit(collapsed)


## Fold while something else needs the screen (e.g. the player sits at a
## computer); unfolding restores what the player had chosen before.
func set_auto_collapsed(value: bool) -> void:
	if value == auto_collapsed:
		return
	auto_collapsed = value
	if value:
		_collapsed_before_auto = collapsed
		set_collapsed(true)
	else:
		set_collapsed(_collapsed_before_auto)


func show_toast(text: String, seconds: float = 4.0) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	get_tree().create_timer(seconds, true).timeout.connect(func():
		if _toast_label.text == text or _toast_label.text == GameLocale.text(text):
			_toast_panel.visible = false)


func _refresh() -> void:
	if _objective_panel == null:
		return
	var title := String(_objective_title.get_meta("title", "ภารกิจตอนนี้"))
	_objective_title.text = "ภารกิจ" if collapsed else title
	_objective_hint.text = "(กด Tab เพื่อเปิด)" if collapsed else ("(Tab ซ่อน • ล้อเมาส์เลื่อน)" if steps_scrollable() else "(กด Tab เพื่อซ่อน)")
	_objective_label.visible = not collapsed and steps.is_empty()
	_heading.visible = not collapsed and _heading.text != ""
	_rule.get_parent().visible = _heading.visible and not steps.is_empty()
	_steps_box.visible = not collapsed and not steps.is_empty()
	_steps_scroll.visible = _steps_box.visible
	_steps_scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 60, minf(_steps_box.get_combined_minimum_size().y, STEPS_MAX_HEIGHT))
	_objective_panel.custom_minimum_size = Vector2(0 if collapsed else PANEL_WIDTH, 0)
	# Always in the top-right corner (clear of desktop icons), open or folded.
	_objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_objective_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_panel.size = Vector2.ZERO # Shrink to fit when folding.
	_objective_panel.offset_top = 20
	_objective_panel.offset_right = -20 - right_inset
	_objective_panel.offset_left = -20 - right_inset - _objective_panel.get_combined_minimum_size().x
	_objective_panel.visible = objective_text != ""
	_toggle.queue_redraw()
	# The toast stays centred in the free part of the screen.
	_toast_panel.offset_left = -400 - right_inset * 0.5
	_toast_panel.offset_right = 180 - right_inset * 0.5


## The held-back hint shows once the player has spent HINT_DELAY on the step
## (game time: a pause menu stops the clock).
func _process(delta: float) -> void:
	if not steps.is_empty() and _active_index >= 0 and _active_index < step_seconds.size():
		step_seconds[_active_index] = float(step_seconds[_active_index]) + delta
	if mistake_source.is_valid() and not steps.is_empty():
		_mistake_clock += delta
		if _mistake_clock >= MISTAKE_POLL or not _mistakes_started:
			_mistake_clock = 0.0
			poll_mistakes()
	if _hint_row == null or not is_instance_valid(_hint_row) or _hint_row.visible:
		return
	_step_time += delta
	if _step_time >= HINT_DELAY:
		_hint_row.visible = true
		_refit_later()


## Time per step for the attempt record: [{step, name, sec}, ...] in order
## (sec rounded to 0.1 s). JSON-friendly, for the progress page now and the
## teacher's report later.
func step_report() -> Array:
	var out := []
	for i in step_seconds.size():
		out.append({"step": i + 1, "name": step_names[i] if i < step_names.size() else "", "sec": snappedf(float(step_seconds[i]), 0.1)})
	return out


## Level time so far: every step's time added up (game time).
func level_seconds() -> float:
	var total := 0.0
	for s in step_seconds:
		total += float(s)
	return total


## A line's shape without its numbers: "ผิด 2 ครั้ง" becoming "ผิด 3 ครั้ง"
## is the same mistake counted again, so it keeps its first time.
func _shape(line: String) -> String:
	return _digits.sub(line, "#", true)


## Looks at the mission's mistakes now: new ones are stamped, ones that went
## away are forgotten (if they come back they count from then). Keys are the
## exact lines.
func poll_mistakes() -> void:
	if not mistake_source.is_valid():
		return
	var lines: Variant = mistake_source.call()
	if not (lines is PackedStringArray or lines is Array):
		return
	var now := {}
	for line in lines:
		now[String(line)] = true
	if not _mistakes_started:
		_mistakes_started = true
		for key in now:
			if not mistake_seen.has(key):
				mistake_baseline[key] = true
		return
	var gone := {}
	for key: String in mistake_seen.keys():
		if not now.has(key):
			gone[_shape(key)] = mistake_seen[key]
			mistake_seen.erase(key)
	for key in mistake_baseline.keys():
		if not now.has(key):
			mistake_baseline.erase(key)
	for key: String in now:
		if mistake_seen.has(key) or mistake_baseline.has(key):
			continue
		var before: Variant = gone.get(_shape(key))
		if before is Dictionary:
			mistake_seen[key] = before
		else:
			mistake_seen[key] = {"step": _active_index + 1, "step_name": step_names[_active_index] if _active_index >= 0 and _active_index < step_names.size() else "", "at": snappedf(level_seconds(), 0.1)}


## The mistakes of the attempt for the record, in the order of `final_lines`
## (score.mistakes): [{text, what, why, step, step_name, at_sec, at_end}].
## "what" is the line before " — " (where and what was done), "why" after it.
func mistake_report(final_lines: PackedStringArray) -> Array:
	poll_mistakes()
	var last_step := _active_index
	if last_step < 0:
		last_step = step_seconds.size() - 1
	var out := []
	for line in final_lines:
		var parts := line.split(" — ", true, 1)
		var entry := {"text": line, "what": parts[0], "why": parts[1] if parts.size() > 1 else ""}
		var seen: Variant = mistake_seen.get(line)
		if seen is Dictionary:
			entry["step"] = int(seen["step"])
			entry["step_name"] = String(seen["step_name"])
			entry["at_sec"] = float(seen["at"])
			entry["at_end"] = false
		else:
			entry["step"] = last_step + 1
			entry["step_name"] = step_names[last_step] if last_step >= 0 and last_step < step_names.size() else ""
			entry["at_sec"] = snappedf(level_seconds(), 0.1)
			entry["at_end"] = true
		out.append(entry)
	return out


## True when the current step's hint is on screen.
func hint_shown() -> bool:
	return _hint_row != null and is_instance_valid(_hint_row) and _hint_row.visible


func _input(event: InputEvent) -> void:
	if not _objective_panel.visible:
		return
	# Mouse wheel: scroll a long step list. With the mouse captured (walking
	# about) any wheel turn does it; with a visible cursor (at a computer,
	# in a dialog) only over the panel, and then the page under the cursor
	# does not scroll as well (user 2026-11-19: the wheel on the computer
	# screen also scrolled this list).
	if event is InputEventMouseButton and event.pressed and not collapsed and steps_scrollable():
		var wheel := (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_UP or wheel == MOUSE_BUTTON_WHEEL_DOWN:
			var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			if not captured and not _objective_panel.get_global_rect().has_point((event as InputEventMouseButton).position):
				return
			_steps_scroll.scroll_vertical += int(WHEEL_STEP * (-1.0 if wheel == MOUSE_BUTTON_WHEEL_UP else 1.0))
			if not captured:
				get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_TAB:
		return
	# Tab still moves between text fields (e.g. TeamViewer ID/password).
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	get_viewport().set_input_as_handled()
	toggle()
