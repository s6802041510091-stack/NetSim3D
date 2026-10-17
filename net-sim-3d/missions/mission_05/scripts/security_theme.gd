class_name SecurityTheme
extends RefCounted

## Colours, fonts and drawing helpers for the simulated Windows Security
## program (Mission 5). Uses the bundled Sarabun font so Thai text also renders
## in the Web export. Sarabun has no check-mark or shield glyphs, so those are drawn.

const FONT_REGULAR := preload("res://assets/fonts/Sarabun-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Sarabun-Bold.ttf")

const INK := Color(0.11, 0.12, 0.15)
const INK_SOFT := Color(0.38, 0.41, 0.47)
const BG := Color(1, 1, 1)
const SIDEBAR := Color(0.95, 0.96, 0.97)
const BORDER := Color(0.84, 0.86, 0.89)
const ACCENT := Color(0.0, 0.37, 0.72)
const DANGER := Color(0.76, 0.15, 0.15)
const DANGER_BG := Color(0.99, 0.93, 0.93)
const WARNING := Color(0.80, 0.47, 0.0)
const WARNING_BG := Color(1.0, 0.96, 0.86)
const OK := Color(0.07, 0.48, 0.23)
const OK_BG := Color(0.91, 0.97, 0.92)
const INFO_BG := Color(0.92, 0.95, 0.99)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_REGULAR
	t.default_font_size = 16
	for type in ["Label", "Button"]:
		t.set_color("font_color", type, INK)
	for c in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_stylebox("normal", "Button", box(Color(0.96, 0.96, 0.97), BORDER, 4, 14, 8))
	t.set_stylebox("hover", "Button", box(Color(0.91, 0.94, 0.98), ACCENT.lightened(0.35), 4, 14, 8))
	t.set_stylebox("pressed", "Button", box(Color(0.86, 0.91, 0.98), ACCENT, 4, 14, 8))
	t.set_stylebox("disabled", "Button", box(Color(0.95, 0.95, 0.96), Color(BORDER, 0.6), 4, 14, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(BG, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("background", "ProgressBar", box(Color(0.88, 0.90, 0.93), Color(0, 0, 0, 0), 3, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 3, 0, 0))
	return t


## Flat box with optional border; `pad_x`/`pad_y` are the content margins.
static func box(bg: Color, border: Color, radius: int = 0, pad_x: int = 12, pad_y: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border.a > 0.0:
		s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## Card with a thick coloured strip on the left (status cards).
static func status_box(bg: Color, strip: Color) -> StyleBoxFlat:
	var s := box(bg, Color(0, 0, 0, 0), 4, 18, 14)
	s.border_color = strip
	s.border_width_left = 5
	return s


static func draw_check(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 2.5) -> void:
	ci.draw_polyline(PackedVector2Array([
		center + Vector2(-0.45, 0.02) * size,
		center + Vector2(-0.12, 0.34) * size,
		center + Vector2(0.48, -0.32) * size,
	]), color, width, true)


static func draw_cross(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 2.0) -> void:
	var h := size * 0.35
	ci.draw_line(center + Vector2(-h, -h), center + Vector2(h, h), color, width, true)
	ci.draw_line(center + Vector2(-h, h), center + Vector2(h, -h), color, width, true)


## Shield outline filled with `color`; `mark` is "check", "alert" or "".
static func draw_shield(ci: CanvasItem, center: Vector2, size: float, color: Color, mark: String = "") -> void:
	var w := size * 0.42
	var h := size * 0.5
	var pts := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, -h * 0.62),
		center + Vector2(w * 0.92, h * 0.15),
		center + Vector2(0, h),
		center + Vector2(-w * 0.92, h * 0.15),
		center + Vector2(-w, -h * 0.62),
	])
	ci.draw_colored_polygon(pts, color)
	match mark:
		"check":
			draw_check(ci, center + Vector2(0, size * 0.02), size * 0.5, Color.WHITE, maxf(2.0, size * 0.08))
		"alert":
			ci.draw_line(center + Vector2(0, -h * 0.5), center + Vector2(0, h * 0.18), Color.WHITE, maxf(2.0, size * 0.09), true)
			ci.draw_circle(center + Vector2(0, h * 0.45), maxf(1.5, size * 0.055), Color.WHITE)


## A small square Control that draws a status icon: "check", "alert", "cross" or "dot".
static func icon(kind: String, color: Color, size: float = 22.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func(): _draw_icon(c, kind, color, size))
	return c


static func _draw_icon(c: Control, kind: String, color: Color, size: float) -> void:
	var mid := c.size * 0.5
	match kind:
		"check":
			c.draw_circle(mid, size * 0.5, color)
			draw_check(c, mid, size * 0.55, Color.WHITE, 2.2)
		"alert":
			c.draw_circle(mid, size * 0.5, color)
			c.draw_line(mid + Vector2(0, -size * 0.25), mid + Vector2(0, size * 0.08), Color.WHITE, 2.4, true)
			c.draw_circle(mid + Vector2(0, size * 0.25), 1.6, Color.WHITE)
		"cross":
			c.draw_circle(mid, size * 0.5, color)
			draw_cross(c, mid, size * 0.8, Color.WHITE, 2.2)
		_:
			c.draw_circle(mid, size * 0.3, color)
