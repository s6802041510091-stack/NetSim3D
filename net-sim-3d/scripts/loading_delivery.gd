extends Control
class_name LoadingDelivery

## Visual-only network transfer. GameFlow supplies the real ResourceLoader progress.
signal delivery_finished

const INK := Color("20364c")
const MUTED := Color("526b81")
const OUTLINE := Color("577181")
const GOLD := Color("f5bd58")
const BODY_FONT := preload("res://assets/fonts/Sarabun-Regular.ttf")

var mail_progress := 0.0:
	set(value):
		mail_progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(490, 190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(queue_redraw)
	get_node("/root/L10n").language_changed.connect(queue_redraw)


func set_percent(percent: float) -> void:
	var previous := mail_progress
	mail_progress = percent / 100.0
	if previous < 1.0 and mail_progress >= 1.0:
		delivery_finished.emit()

func deliver() -> void:
	# Compatibility for preview scenes: no independent animation clock.
	set_percent(100.0)


func _draw() -> void:
	var width := size.x
	var left := Vector2(25.0, 31.0)
	var right := Vector2(width - 139.0, 31.0)
	var route_y := 79.0
	var route_start := left.x + 122.0
	var route_end := right.x - 12.0
	# A simple flat illustration stays readable at small browser window sizes.
	_computer(left)
	_computer(right)
	for x in range(int(route_start), int(route_end), 20):
		draw_line(Vector2(x, route_y), Vector2(minf(x + 10.0, route_end), route_y), OUTLINE, 3.0)
	for endpoint in [route_start, route_end]:
		draw_circle(Vector2(endpoint, route_y), 6.0, OUTLINE)
		draw_circle(Vector2(endpoint, route_y), 3.0, Color.WHITE)
	_mail(Vector2(lerpf(route_start + 17.0, route_end - 28.0, mail_progress), route_y - 21.0))
	draw_string(BODY_FONT, Vector2(left.x - 2.0, 180.0), GameLocale.text("เครื่องต้นทาง"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	draw_string(BODY_FONT, Vector2(right.x - 2.0, 180.0), GameLocale.text("เครื่องปลายทาง"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)


func _computer(at: Vector2) -> void:
	# Monitor, screen, pedestal, keyboard, and a small system unit.
	_draw_box(Rect2(at + Vector2(8, 2), Vector2(94, 77)), Color("dbe7e9"), OUTLINE, 5)
	_draw_box(Rect2(at + Vector2(16, 10), Vector2(78, 58)), Color("224557"), Color.TRANSPARENT, 2)
	draw_line(at + Vector2(35, 35), at + Vector2(75, 35), Color("83b2bc"), 2)
	draw_line(at + Vector2(35, 43), at + Vector2(65, 43), Color("83b2bc"), 2)
	draw_rect(Rect2(at + Vector2(51, 79), Vector2(8, 16)), OUTLINE)
	_draw_box(Rect2(at + Vector2(28, 93), Vector2(54, 6)), Color("9db3b8"), Color.TRANSPARENT, 2)
	_draw_box(Rect2(at + Vector2(2, 109), Vector2(110, 25)), Color("d3e2e3"), OUTLINE, 3)
	for key_x in range(14, 105, 14):
		draw_line(at + Vector2(key_x, 117), at + Vector2(key_x + 7, 117), Color("91aeb3"), 1)
	_draw_box(Rect2(at + Vector2(113, 91), Vector2(22, 43)), Color("b7cdd0"), OUTLINE, 3)
	draw_rect(Rect2(at + Vector2(119, 120), Vector2(10, 3)), Color("e3ad56"))


func _mail(at: Vector2) -> void:
	_draw_box(Rect2(at, Vector2(49, 37)), GOLD, Color("c48c43"), 5)
	draw_polyline(PackedVector2Array([at + Vector2(3, 6), at + Vector2(24, 22), at + Vector2(46, 6)]), Color("fff0cd"), 3.0)
	draw_line(at + Vector2(3, 33), at + Vector2(17, 20), Color("d79b46"), 2)
	draw_line(at + Vector2(46, 33), at + Vector2(32, 20), Color("d79b46"), 2)
	draw_circle(at + Vector2(49, -2), 10.0, Color("cf6255"))
	draw_string(BODY_FONT, at + Vector2(45, 4), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _draw_box(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(2)
	draw_style_box(style, rect)
