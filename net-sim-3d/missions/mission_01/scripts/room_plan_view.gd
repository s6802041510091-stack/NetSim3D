class_name RoomPlanView
extends Control

## Top-down plan of the computer room, drawn in code and scaled to fit.
## Everything here is fixed: room, teacher desk, 10 student desks (20 PCs),
## the teacher PC, Wall Rack 9U, the external network and the LAN cable routes.
## Only the install-point markers (EquipmentPoint children) can be clicked.

## Plan units; all positions below use this space.
const DESIGN_SIZE := Vector2(1000, 700)
## Pixels kept at the bottom for the legend (drawn unscaled so it stays readable).
const LEGEND_HEIGHT := 30.0

const ROOM := Rect2(20, 40, 840, 640)
const WHITEBOARD := Rect2(200, 42, 330, 16)
const RACK := Rect2(690, 44, 80, 48)
const EXTERNAL := Rect2(915, 110, 82, 80)
const TEACHER_DESK := Rect2(712, 262, 136, 40)
const DOOR_Y := Vector2(110, 175)
const ROW_Y := [295.0, 370.0, 445.0, 520.0, 595.0]
const LEFT_DESK_X := Vector2(100, 320)
const RIGHT_DESK_X := Vector2(450, 670)
const DESK_DEPTH := 30.0
const LEFT_TRUNK_X := 60.0
const RIGHT_TRUNK_X := 690.0
const TOP_TRUNK_Y := 80.0
const AISLE_X := 385.0

## Fixed LAN cable routes (polylines in plan units). View only.
const LAN_ROUTES := [
	# External network -> point 1 (wall) -> Wall Rack 9U
	[Vector2(915, 150), Vector2(800, 150), Vector2(800, 68), Vector2(770, 68)],
	# Wall Rack -> cable trunk along the front wall -> left wall
	[Vector2(690, 80), Vector2(60, 80), Vector2(60, 595)],
	# Trunk -> right column of desks (and the teacher desk)
	[Vector2(690, 92), Vector2(690, 595)],
	# Trunk -> ceiling install point in the middle of the room
	[Vector2(385, 80), Vector2(385, 410)],
	# Right trunk -> teacher PC
	[Vector2(690, 282), Vector2(712, 282)],
]

var lan_highlight: bool = false:
	set(value):
		lan_highlight = value
		queue_redraw()

var _scale := 1.0
var _origin := Vector2.ZERO
var _points := {}


func _ready() -> void:
	clip_contents = true
	resized.connect(_relayout)
	_relayout()


## Adds a marker at its question's plan position.
func add_point(point: EquipmentPoint, plan_position: Vector2) -> void:
	point.set_meta("plan_position", plan_position)
	_points[point.point_id] = point
	add_child(point)
	_relayout()


func get_point(point_id: int) -> EquipmentPoint:
	return _points.get(point_id) as EquipmentPoint


func plan_to_local(p: Vector2) -> Vector2:
	return _origin + p * _scale


func _relayout() -> void:
	if size.x <= 0.0 or size.y <= LEGEND_HEIGHT:
		return
	var area := Vector2(size.x - 16.0, size.y - LEGEND_HEIGHT - 8.0)
	_scale = minf(area.x / DESIGN_SIZE.x, area.y / DESIGN_SIZE.y)
	_origin = Vector2((size.x - DESIGN_SIZE.x * _scale) * 0.5, 6.0)
	for id in _points:
		var point: EquipmentPoint = _points[id]
		var p: Vector2 = point.get_meta("plan_position")
		point.position = plan_to_local(p) - point.size * 0.5
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _r(rect: Rect2) -> Rect2:
	return Rect2(plan_to_local(rect.position), rect.size * _scale)


## Text in plan units. `align` is relative to `at`: centre, left edge or right edge.
func _text(text: String, at: Vector2, font_size: float, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, bold := false) -> void:
	var font: Font = NetPlanTheme.FONT_BOLD if bold else NetPlanTheme.FONT_REGULAR
	var fs := maxi(11, int(round(font_size * _scale)))
	var pos := plan_to_local(at)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= w
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NetPlanTheme.PLAN_BG)
	var grid := 20.0 * _scale
	if grid >= 6.0:
		var x := fmod(_origin.x, grid)
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.84, 0.89, 0.96, 0.55), 1.0)
			x += grid
		var y := fmod(_origin.y, grid)
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.84, 0.89, 0.96, 0.55), 1.0)
			y += grid

	_draw_room()
	_draw_external()
	_draw_rack_and_teacher()
	_draw_student_desks()
	_draw_lan()
	_draw_legend()


func _draw_room() -> void:
	var wall := Color(0.30, 0.35, 0.44)
	var room := _r(ROOM)
	draw_rect(room, Color(1, 1, 1, 0.8))
	draw_rect(room, wall, false, maxf(3.0, 6.0 * _scale))
	# Door gap on the left wall.
	var d0 := plan_to_local(Vector2(ROOM.position.x, DOOR_Y.x))
	var d1 := plan_to_local(Vector2(ROOM.position.x, DOOR_Y.y))
	draw_line(d0, d1, Color(1, 1, 1), maxf(5.0, 8.0 * _scale))
	draw_arc(d0, d1.y - d0.y, 0, PI * 0.5, 16, Color(wall, 0.5), 1.5, true)
	_text("ประตู", Vector2(ROOM.position.x + 34, DOOR_Y.y + 22), 15, NetPlanTheme.INK_SOFT)
	# Whiteboard on the front wall.
	draw_rect(_r(WHITEBOARD), Color(0.50, 0.57, 0.68))
	_text("กระดาน (หน้าห้อง)", WHITEBOARD.get_center() + Vector2(0, 6), 13, Color.WHITE)
	_text("ห้องปฏิบัติการคอมพิวเตอร์ · คอมพิวเตอร์ครู 1 เครื่อง · คอมพิวเตอร์นักเรียน 20 เครื่อง", Vector2(ROOM.get_center().x, ROOM.end.y - 14), 16, NetPlanTheme.INK_SOFT)


func _draw_external() -> void:
	draw_style_box(NetPlanTheme.box(Color(0.90, 0.95, 1.0), NetPlanTheme.LAN, int(14 * _scale)), _r(EXTERNAL))
	_text("เครือข่าย", EXTERNAL.get_center() + Vector2(0, -12), 15, NetPlanTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text("ภายนอก", EXTERNAL.get_center() + Vector2(0, 8), 15, NetPlanTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text("(Internet)", EXTERNAL.get_center() + Vector2(0, 28), 13, NetPlanTheme.INK_SOFT)


func _draw_rack_and_teacher() -> void:
	# Wall Rack 9U on the wall behind the teacher desk.
	var rack := _r(RACK)
	draw_rect(rack, Color(0.17, 0.19, 0.23))
	for i in 9:
		var y := RACK.position.y + 4 + i * 4.8
		draw_line(plan_to_local(Vector2(RACK.position.x + 5, y)), plan_to_local(Vector2(RACK.end.x - 5, y)), Color(0.36, 0.39, 0.45), 1.0)
	draw_rect(rack, Color(0.55, 0.6, 0.68), false, 1.5)
	_text("Wall Rack 9U", Vector2(RACK.position.x - 40, RACK.position.y + 17), 16, NetPlanTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_text("หลังโต๊ะครู", Vector2(RACK.position.x - 40, RACK.position.y + 35), 13, NetPlanTheme.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)

	# Teacher desk, teacher PC and chair.
	draw_rect(_r(TEACHER_DESK), Color(0.80, 0.68, 0.52))
	draw_rect(_r(TEACHER_DESK), Color(0.55, 0.43, 0.30), false, 1.5)
	_draw_pc(TEACHER_DESK.position + Vector2(36, 12), Color(0.35, 0.25, 0.60))
	draw_circle(plan_to_local(TEACHER_DESK.get_center() + Vector2(0, 34)), 9 * _scale, Color(0.45, 0.48, 0.55))
	_text("โต๊ะครู", TEACHER_DESK.position + Vector2(100, 30), 14, NetPlanTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text("คอมพิวเตอร์ครู", TEACHER_DESK.get_center() + Vector2(0, 68), 13, NetPlanTheme.INK_SOFT)


func _draw_pc(center_plan: Vector2, color: Color) -> void:
	var r := _r(Rect2(center_plan - Vector2(15, 5), Vector2(30, 10)))
	draw_rect(r, color)
	draw_rect(r.grow(-1.5 * _scale), color.lightened(0.45))


func _draw_student_desks() -> void:
	for row in ROW_Y.size():
		var y: float = ROW_Y[row]
		_text("แถว %d" % (row + 1), Vector2(LEFT_DESK_X.x - 8, y - 20), 12, NetPlanTheme.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
		for side in 2:
			var span: Vector2 = LEFT_DESK_X if side == 0 else RIGHT_DESK_X
			var desk := Rect2(span.x, y - DESK_DEPTH * 0.5, span.y - span.x, DESK_DEPTH)
			draw_rect(_r(desk), Color(0.86, 0.80, 0.70))
			draw_rect(_r(desk), Color(0.62, 0.55, 0.45), false, 1.2)
			for seat in 2:
				var cx := span.x + (span.y - span.x) * (0.27 + seat * 0.46)
				_draw_pc(Vector2(cx, y - 4), Color(0.18, 0.35, 0.62))
				draw_circle(plan_to_local(Vector2(cx, y + DESK_DEPTH * 0.5 + 10)), 7 * _scale, Color(0.55, 0.58, 0.64))


func _draw_lan() -> void:
	var color := NetPlanTheme.LAN if not lan_highlight else Color(0.0, 0.55, 0.95)
	var width := maxf(2.0, (5.0 if lan_highlight else 3.0) * _scale)
	var routes: Array = LAN_ROUTES.duplicate()
	for y in ROW_Y:
		routes.append([Vector2(LEFT_TRUNK_X, y), Vector2(LEFT_DESK_X.x, y)])
		routes.append([Vector2(RIGHT_TRUNK_X, y), Vector2(RIGHT_DESK_X.y, y)])
	if lan_highlight:
		for route in routes:
			draw_polyline(_local_line(route), Color(0.3, 0.7, 1.0, 0.28), width * 3.2, true)
	for route in routes:
		draw_polyline(_local_line(route), color, width, true)
	for y in ROW_Y:
		draw_circle(plan_to_local(Vector2(LEFT_DESK_X.x, y)), 3.5 * _scale + 1.0, color)
		draw_circle(plan_to_local(Vector2(RIGHT_DESK_X.y, y)), 3.5 * _scale + 1.0, color)
	draw_circle(plan_to_local(Vector2(712, 282)), 3.5 * _scale + 1.0, color)


func _local_line(route: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in route:
		out.append(plan_to_local(p))
	return out


## Legend in screen pixels along the bottom edge.
func _draw_legend() -> void:
	var font := NetPlanTheme.FONT_REGULAR
	var fs := 14
	var y := size.y - LEGEND_HEIGHT * 0.5
	draw_rect(Rect2(0, size.y - LEGEND_HEIGHT, size.x, LEGEND_HEIGHT), Color(0.93, 0.95, 0.98))
	draw_line(Vector2(0, size.y - LEGEND_HEIGHT), Vector2(size.x, size.y - LEGEND_HEIGHT), NetPlanTheme.BORDER, 1.0)
	var items := [
		[NetPlanTheme.EMPTY, "ยังไม่เลือก"],
		[NetPlanTheme.SELECTED, "เลือกแล้ว"],
		[NetPlanTheme.WRONG, "ต้องแก้ไข"],
		[NetPlanTheme.CORRECT, "ถูกต้อง"],
	]
	var x := 12.0
	for item in items:
		draw_circle(Vector2(x + 7, y), 7, item[0])
		draw_string(font, Vector2(x + 18, y + fs * 0.36), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, NetPlanTheme.INK)
		x += 26.0 + font.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
	draw_line(Vector2(x, y), Vector2(x + 20, y), NetPlanTheme.LAN, 3.0)
	var lan_text := "สาย LAN (ล็อกไว้ แก้ไขไม่ได้)"
	draw_string(font, Vector2(x + 26, y + fs * 0.36), lan_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, NetPlanTheme.INK)
