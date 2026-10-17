class_name EquipmentPoint
extends Button

## A clickable install point (1, 2, 3) on the room plan. It cannot be dragged,
## moved or deleted — clicking only asks the program to open the choice pop-up.
##   orange          = no device chosen yet
##   green + check   = device chosen, not checked yet
##   red             = wrong after "ตรวจสอบแบบ"
##   dark green      = correct after "ตรวจสอบแบบ"

signal equipment_point_opened(point_id: int)

const MARKER_RADIUS := 21.0

@export var point_id: int = 1

var status: Mission01State.PointStatus = Mission01State.PointStatus.EMPTY
var _pulse := 0.0

@onready var _caption: Label = %Caption


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_caption.add_theme_stylebox_override("normal", NetPlanTheme.box(Color(1, 1, 1, 0.88), Color(0, 0, 0, 0), 4, 3, 0))
	pressed.connect(func(): equipment_point_opened.emit(point_id))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_process(true)


## Updates colour, caption and tooltip. `device` is "" when nothing is chosen.
func set_status(new_status: Mission01State.PointStatus, title: String, device: String) -> void:
	status = new_status
	var second := device if device != "" else "ยังไม่เลือก"
	if _caption:
		_caption.text = "จุดที่ %d\n%s" % [point_id, second]
		_caption.add_theme_color_override("font_color", NetPlanTheme.status_color(status).darkened(0.3))
		# Fit the caption to its text and centre it under the marker.
		_caption.size = _caption.get_minimum_size()
		_caption.position = Vector2((size.x - _caption.size.x) * 0.5, size.y - 2.0)
	tooltip_text = "จุดที่ %d: %s\nคลิกเพื่อเลือกอุปกรณ์" % [point_id, title]
	queue_redraw()


func _process(delta: float) -> void:
	if status == Mission01State.PointStatus.EMPTY:
		_pulse = fmod(_pulse + delta * 0.9, 1.0)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var color := NetPlanTheme.status_color(status)
	if is_hovered():
		color = color.lightened(0.12)
	if status == Mission01State.PointStatus.EMPTY:
		draw_arc(c, MARKER_RADIUS + 3.0 + _pulse * 9.0, 0, TAU, 40, Color(color, 0.55 * (1.0 - _pulse)), 3.0, true)
	if status == Mission01State.PointStatus.CORRECT:
		draw_arc(c, MARKER_RADIUS + 3.5, 0, TAU, 40, color, 2.5, true)
	draw_circle(c, MARKER_RADIUS + 1.5, Color(0, 0, 0, 0.18))
	draw_circle(c, MARKER_RADIUS, color)
	draw_arc(c, MARKER_RADIUS - 1.0, 0, TAU, 40, Color(1, 1, 1, 0.9), 2.0, true)

	var font := get_theme_font("font", "Label")
	var text := str(point_id)
	var fs := 20
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# Badge: check mark = chosen (not checked yet), cross = wrong, check = correct.
	var badge := c + Vector2(MARKER_RADIUS * 0.78, -MARKER_RADIUS * 0.78)
	match status:
		Mission01State.PointStatus.SELECTED, Mission01State.PointStatus.CORRECT:
			draw_circle(badge, 9.0, Color.WHITE)
			NetPlanTheme.draw_check(self, badge, 12.0, color, 2.5)
		Mission01State.PointStatus.WRONG:
			draw_circle(badge, 9.0, Color.WHITE)
			NetPlanTheme.draw_cross(self, badge, 12.0, color, 2.5)
