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
## Marker fill: gold for the next point, grey while waiting, status colours after.
var color := NetPlanTheme.EMPTY
var _pulse := 0.0

@onready var _caption: Label = %Caption


func _ready() -> void:
	set_meta("sound", "") # opening the pop-up plays its own sound
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
## The caption only appears once a device is chosen (the number is on the marker).
func set_status(new_status: Mission01State.PointStatus, title: String, device: String, fill: Color = NetPlanTheme.EMPTY) -> void:
	status = new_status
	color = fill
	if _caption:
		_caption.visible = device != ""
		_caption.text = device
		_caption.add_theme_color_override("font_color", color.darkened(0.35))
		# Fit the caption to its text and centre it under the marker.
		_caption.size = _caption.get_minimum_size()
		_caption.position = Vector2((size.x - _caption.size.x) * 0.5, size.y - 2.0)
	tooltip_text = "จุดที่ %d: %s\nคลิกเพื่อเลือกอุปกรณ์" % [point_id, title]
	queue_redraw()


## Only the gold "next" point pulses, so the eye goes to one place.
func is_pulsing() -> bool:
	return status == Mission01State.PointStatus.EMPTY and color == NetPlanTheme.NEXT


func _process(delta: float) -> void:
	if is_pulsing():
		_pulse = fmod(_pulse + delta * 0.9, 1.0)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var fill := color
	if is_hovered():
		fill = fill.lightened(0.12)
	if is_pulsing():
		draw_arc(c, MARKER_RADIUS + 3.0 + _pulse * 11.0, 0, TAU, 40, Color(fill, 0.7 * (1.0 - _pulse)), 3.5, true)
	if status == Mission01State.PointStatus.CORRECT:
		draw_arc(c, MARKER_RADIUS + 3.5, 0, TAU, 40, fill, 2.5, true)
	draw_circle(c, MARKER_RADIUS + 1.5, Color(0, 0, 0, 0.18))
	draw_circle(c, MARKER_RADIUS, fill)
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
			NetPlanTheme.draw_check(self, badge, 12.0, fill, 2.5)
		Mission01State.PointStatus.WRONG:
			draw_circle(badge, 9.0, Color.WHITE)
			NetPlanTheme.draw_cross(self, badge, 12.0, fill, 2.5)
