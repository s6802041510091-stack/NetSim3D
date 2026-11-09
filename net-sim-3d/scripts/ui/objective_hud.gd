class_name ObjectiveHUD
extends CanvasLayer

## Top-left "current objective" panel plus a short toast at the top centre
## (e.g. "ได้รับภารกิจ: ..."). Missions call set_objective() as the story moves on.
## The panel folds to a small "ภารกิจ" tab with Tab or its arrow button, and
## missions can fold it automatically while the player uses a computer.

signal collapsed_changed(collapsed: bool)

const PANEL_WIDTH := 300.0

var objective_text: String = ""
var collapsed := false
## True while folded automatically (e.g. at a computer); restores on release.
var auto_collapsed := false
var _collapsed_before_auto := false
var _objective_panel: PanelContainer
var _objective_title: Label
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
	_objective_title = GameUI.label("", 14, Color(0.6, 0.78, 1.0), true)
	col.add_child(_objective_title)
	_objective_label = GameUI.label("", 18, Color.WHITE)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 0)
	col.add_child(_objective_label)
	_toggle = Button.new()
	_toggle.name = "ToggleButton"
	_toggle.custom_minimum_size = Vector2(26, 26)
	_toggle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.tooltip_text = "ซ่อน/แสดงภารกิจ (Tab)"
	_toggle.add_theme_stylebox_override("normal", GameUI.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 6, 0, 0))
	_toggle.add_theme_stylebox_override("hover", GameUI.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 6, 0, 0))
	_toggle.add_theme_stylebox_override("pressed", GameUI.box(Color(1, 1, 1, 0.28), Color(0, 0, 0, 0), 6, 0, 0))
	# Chevron drawn (no font glyph needed): points left = fold, right = open.
	_toggle.draw.connect(func():
		var c := _toggle.size * 0.5
		var d := 5.0 if collapsed else -5.0
		_toggle.draw_polyline(PackedVector2Array([c + Vector2(-d * 0.6, -7), c + Vector2(d * 0.6, 0), c + Vector2(-d * 0.6, 7)]), Color(0.85, 0.9, 1.0), 2.5, true))
	_toggle.pressed.connect(toggle)
	row.add_child(_toggle)
	_objective_panel.visible = false

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	# Narrow enough to stay clear of the objective panel on a 1280 px screen.
	_toast_panel.offset_left = -240
	_toast_panel.offset_right = 340
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
	objective_text = text
	_objective_title.set_meta("title", title)
	# Keep names such as "IT-PC-01" on one line (word joiner after each hyphen).
	_objective_label.text = DialogueBox.keep_together(text).replace("-", "-⁠")
	_refresh()


func toggle() -> void:
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
		if _toast_label.text == text:
			_toast_panel.visible = false)


func _refresh() -> void:
	if _objective_panel == null:
		return
	var title := String(_objective_title.get_meta("title", "ภารกิจตอนนี้"))
	_objective_title.text = ("ภารกิจ  (Tab เปิด)" if collapsed else title + "  (Tab ซ่อน)")
	_objective_label.visible = not collapsed
	_objective_panel.custom_minimum_size = Vector2(0 if collapsed else PANEL_WIDTH, 0)
	# Folded: a small tab in the top-right corner, clear of desktop icons.
	# Open: the full panel in the top-left corner.
	_objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT if collapsed else Control.PRESET_TOP_LEFT)
	_objective_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if collapsed else Control.GROW_DIRECTION_END
	_objective_panel.size = Vector2.ZERO # Shrink to fit when folding.
	_objective_panel.offset_top = 20
	if collapsed:
		_objective_panel.offset_right = -20
		_objective_panel.offset_left = -20 - _objective_panel.get_combined_minimum_size().x
	else:
		_objective_panel.offset_left = 20
		_objective_panel.offset_right = 20 + _objective_panel.get_combined_minimum_size().x
	_objective_panel.visible = objective_text != ""
	_toggle.queue_redraw()


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
