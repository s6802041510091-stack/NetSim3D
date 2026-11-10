class_name SidePanel
extends PanelContainer

## The step panel on the right of the screen at a work spot (crimping desk,
## cable tester, wall rack). A chevron next to the title folds it into a
## small tab at the top right so it does not cover the 3D view; the choice is
## remembered for the other panels too. Put the panel's contents in `body`.

signal collapsed_changed(collapsed: bool)

const WIDTH := 380.0
const MARGIN := 14.0
const FOLDED_WIDTH := 230.0

## Shared by every side panel: folded once, folded everywhere.
static var collapsed_pref := false

var title: Label
var body: VBoxContainer
var collapsed := false
var _toggle: Button


func _init() -> void:
	add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1, 0.97), Color(0.8, 0.83, 0.88), 12, 18, 14))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)
	title = GameUI.label("", 20, GameUI.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	_toggle = Button.new()
	_toggle.name = "FoldButton"
	_toggle.set_meta("sound", "")
	_toggle.custom_minimum_size = Vector2(30, 30)
	_toggle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.tooltip_text = "ซ่อน / แสดงแผงขั้นตอน"
	_toggle.add_theme_stylebox_override("normal", GameUI.box(Color(0.93, 0.95, 0.98), Color(0.8, 0.83, 0.88), 6, 0, 0))
	_toggle.add_theme_stylebox_override("hover", GameUI.box(Color(0.86, 0.91, 1.0), GameUI.ACCENT.lightened(0.3), 6, 0, 0))
	_toggle.add_theme_stylebox_override("pressed", GameUI.box(Color(0.8, 0.86, 0.96), GameUI.ACCENT, 6, 0, 0))
	# Drawn chevron: open -> points right (fold away), folded -> points left.
	_toggle.draw.connect(func():
		var c := _toggle.size * 0.5
		var d := -5.0 if collapsed else 5.0
		_toggle.draw_polyline(PackedVector2Array([c + Vector2(-d * 0.6, -7), c + Vector2(d * 0.6, 0), c + Vector2(-d * 0.6, 7)]), GameUI.INK_SOFT, 2.5, true))
	_toggle.pressed.connect(toggle)
	header.add_child(_toggle)
	body = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_apply(collapsed_pref)


func _ready() -> void:
	visibility_changed.connect(func():
		if is_visible_in_tree() and collapsed != collapsed_pref:
			_apply(collapsed_pref))


func toggle() -> void:
	Sound.play("toggle_on" if collapsed else "toggle_off")
	set_collapsed(not collapsed)


func set_collapsed(value: bool) -> void:
	collapsed_pref = value
	if value != collapsed:
		_apply(value)
		collapsed_changed.emit(value)


## Width the panel takes on the right of the screen now (for things that keep
## clear of it).
func covered_width() -> float:
	return (FOLDED_WIDTH if collapsed else WIDTH) + MARGIN


func _apply(value: bool) -> void:
	collapsed = value
	body.visible = not value
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_left = -MARGIN - (FOLDED_WIDTH if value else WIDTH)
	if value:
		anchor_bottom = 0.0
		offset_bottom = MARGIN
	else:
		anchor_bottom = 1.0
		offset_bottom = -MARGIN
	if _toggle:
		_toggle.queue_redraw()
