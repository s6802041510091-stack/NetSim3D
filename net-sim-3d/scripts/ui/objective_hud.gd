class_name ObjectiveHUD
extends CanvasLayer

## Top-left "current objective" panel plus a short toast at the top centre
## (e.g. "ได้รับภารกิจ: ..."). Missions call set_objective() as the story moves on.

var objective_text: String = ""
var _objective_panel: PanelContainer
var _objective_title: Label
var _objective_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label


func _ready() -> void:
	layer = 12
	_objective_panel = PanelContainer.new()
	_objective_panel.name = "ObjectivePanel"
	_objective_panel.position = Vector2(20, 20)
	_objective_panel.custom_minimum_size = Vector2(300, 0)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_theme_stylebox_override("panel", GameUI.box(Color(0.06, 0.08, 0.12, 0.78), Color(0.4, 0.6, 0.95, 0.6), 8, 14, 10))
	add_child(_objective_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_objective_panel.add_child(col)
	_objective_title = GameUI.label("", 14, Color(0.6, 0.78, 1.0), true)
	col.add_child(_objective_title)
	_objective_label = GameUI.label("", 18, Color.WHITE)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(272, 0)
	col.add_child(_objective_label)
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


func set_objective(text: String, title: String = "ภารกิจตอนนี้") -> void:
	objective_text = text
	_objective_title.text = title
	_objective_label.text = text
	_objective_panel.visible = text != ""


func show_toast(text: String, seconds: float = 4.0) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	get_tree().create_timer(seconds, true).timeout.connect(func():
		if _toast_label.text == text:
			_toast_panel.visible = false)
