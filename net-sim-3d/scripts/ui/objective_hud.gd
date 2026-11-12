class_name ObjectiveHUD
extends CanvasLayer

## Top-left "current objective" panel plus a short toast at the top centre
## (e.g. "ได้รับภารกิจ: ..."). Missions call set_objective() as the story moves on.
## The panel folds to a small "ภารกิจ" tab with Tab or its arrow button, and
## missions can fold it automatically while the player uses a computer.
##
## The standard for every level is set_steps(): the whole mission as numbered
## steps in order — done = green with ✓, the current step = blue (with a short
## hint below it), steps not reached yet = faint grey.

signal collapsed_changed(collapsed: bool)

const PANEL_WIDTH := 330.0
const STEP_DONE := "done"
const STEP_ACTIVE := "active"
const STEP_TODO := "todo"
const COLOR_DONE := Color(0.5, 0.88, 0.6)
const COLOR_ACTIVE := Color(0.5, 0.76, 1.0)
const COLOR_TODO := Color(1, 1, 1, 0.38)
const COLOR_HINT := Color(0.82, 0.87, 0.95)

## Space kept free on the right (e.g. for a SidePanel), so the panel moves left of it.
var right_inset := 0.0:
	set(value):
		right_inset = value
		_refresh()
## The steps shown now: [[text, STEP_DONE / STEP_ACTIVE / STEP_TODO], ...]
var steps: Array = []
var _heading: Label
var _steps_box: VBoxContainer

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


func _ready() -> void:
	layer = 12
	_objective_panel = PanelContainer.new()
	_objective_panel.name = "ObjectivePanel"
	_objective_panel.position = Vector2(20, 20)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_theme_stylebox_override("panel", GameUI.box(Color(0.06, 0.08, 0.12, 0.78), Color(0.4, 0.6, 0.95, 0.6), 8, 12, 8))
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
	_objective_title = GameUI.label("", 14, Color(0.6, 0.78, 1.0), true)
	title_row.add_child(_objective_title)
	_objective_hint = GameUI.label("", 13, Color(0.62, 0.65, 0.7))
	_objective_hint.name = "HintLabel"
	title_row.add_child(_objective_hint)
	_objective_label = GameUI.label("", 18, Color.WHITE)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 0)
	col.add_child(_objective_label)
	_heading = GameUI.label("", 16, Color.WHITE, true)
	_heading.name = "Heading"
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 0)
	col.add_child(_heading)
	_steps_box = VBoxContainer.new()
	_steps_box.name = "Steps"
	_steps_box.add_theme_constant_override("separation", 3)
	_steps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_steps_box)
	_toggle = Button.new()
	_toggle.name = "ToggleButton"
	_toggle.set_meta("sound", "") # toggle() plays the fold sound
	_toggle.custom_minimum_size = Vector2(26, 26)
	_toggle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.tooltip_text = "ซ่อน/แสดงภารกิจ (Tab)"
	_toggle.add_theme_stylebox_override("normal", GameUI.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 6, 0, 0))
	_toggle.add_theme_stylebox_override("hover", GameUI.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 6, 0, 0))
	_toggle.add_theme_stylebox_override("pressed", GameUI.box(Color(1, 1, 1, 0.28), Color(0, 0, 0, 0), 6, 0, 0))
	# Chevron drawn (no font glyph needed). The panel sits on the right edge:
	# open -> points right (fold away), folded -> points left (open out).
	_toggle.draw.connect(func():
		var c := _toggle.size * 0.5
		var d := -5.0 if collapsed else 5.0
		_toggle.draw_polyline(PackedVector2Array([c + Vector2(-d * 0.6, -7), c + Vector2(d * 0.6, 0), c + Vector2(-d * 0.6, 7)]), Color(0.85, 0.9, 1.0), 2.5, true))
	_toggle.pressed.connect(toggle)
	row.add_child(_toggle)
	_objective_panel.visible = false

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	# Shifted left to stay clear of the objective panel (top-right) on a 1280 px screen.
	_toast_panel.offset_left = -340
	_toast_panel.offset_right = 240
	_toast_panel.offset_top = 24
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", GameUI.box(Color(0.06, 0.32, 0.18, 0.94), Color(0.4, 0.85, 0.55), 8, 20, 12))
	add_child(_toast_panel)
	_toast_label = GameUI.label("", 20, Color.WHITE, true)
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
	for i in step_list.size():
		var state: String = step_list[i][1]
		var color := COLOR_DONE if state == STEP_DONE else (COLOR_ACTIVE if state == STEP_ACTIVE else COLOR_TODO)
		var row := HBoxContainer.new()
		row.name = "Step%d" % (i + 1)
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_steps_box.add_child(row)
		var mark := GameUI.label("✓" if state == STEP_DONE else ("▸" if state == STEP_ACTIVE else ""), 16, color, true)
		mark.custom_minimum_size = Vector2(16, 0)
		row.add_child(mark)
		var label := GameUI.label("%d. %s" % [i + 1, DialogueBox.keep_together(String(step_list[i][0])).replace("-", "-⁠")], 16, color, state == STEP_ACTIVE)
		label.name = "Text"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(PANEL_WIDTH - 82, 0)
		row.add_child(label)
		if state == STEP_ACTIVE and hint != "":
			var hint_label := GameUI.label(DialogueBox.keep_together(hint).replace("-", "-⁠"), 14, COLOR_HINT)
			hint_label.name = "Hint"
			hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint_label.custom_minimum_size = Vector2(PANEL_WIDTH - 82, 0)
			var indent := MarginContainer.new()
			indent.add_theme_constant_override("margin_left", 40)
			indent.add_theme_constant_override("margin_bottom", 3)
			indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			indent.add_child(hint_label)
			_steps_box.add_child(indent)
	_refresh()
	# Wrapped lines know their height only after layout: fit the panel again.
	_refit_later()


func _refit_later() -> void:
	await get_tree().process_frame
	_refresh()


func _clear_steps() -> void:
	if _steps_box == null:
		return
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
	_objective_hint.text = "(กด Tab เพื่อเปิด)" if collapsed else "(กด Tab เพื่อซ่อน)"
	_objective_label.visible = not collapsed and steps.is_empty()
	_heading.visible = not collapsed and _heading.text != ""
	_steps_box.visible = not collapsed and not steps.is_empty()
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
	_toast_panel.offset_left = -340 - right_inset * 0.5
	_toast_panel.offset_right = 240 - right_inset * 0.5


func _input(event: InputEvent) -> void:
	if not _objective_panel.visible or not event is InputEventKey:
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
