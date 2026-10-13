class_name RemoteTheme
extends RefCounted

## Colours, fonts and drawing helpers for the simulated TeamViewer program
## (Mission 6). Uses the bundled Sarabun font so Thai renders in the Web export;
## icons are drawn because Sarabun has no symbol glyphs.

const FONT_REGULAR := preload("res://assets/fonts/Sarabun-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Sarabun-Bold.ttf")

const INK := Color(0.12, 0.13, 0.16)
const INK_SOFT := Color(0.40, 0.43, 0.49)
const BG := Color(1, 1, 1)
const PANEL := Color(0.96, 0.97, 0.98)
const BORDER := Color(0.83, 0.85, 0.89)
const ACCENT := Color(0.05, 0.39, 0.82)
const SESSION_BAR := Color(0.11, 0.13, 0.18)
const DANGER := Color(0.78, 0.16, 0.16)
const WARNING := Color(0.82, 0.48, 0.0)
const WARNING_BG := Color(1.0, 0.96, 0.86)
const OK := Color(0.08, 0.50, 0.25)
const OK_BG := Color(0.91, 0.97, 0.92)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_REGULAR
	t.default_font_size = 16
	for type in ["Label", "Button", "LineEdit", "CheckBox"]:
		t.set_color("font_color", type, INK)
	for c in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
		t.set_color(c, "CheckBox", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_color("font_placeholder_color", "LineEdit", Color(INK_SOFT, 0.8))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_stylebox("normal", "Button", box(Color(0.96, 0.96, 0.97), BORDER, 4, 14, 7))
	t.set_stylebox("hover", "Button", box(Color(0.91, 0.94, 0.99), ACCENT.lightened(0.35), 4, 14, 7))
	t.set_stylebox("pressed", "Button", box(Color(0.85, 0.90, 0.98), ACCENT, 4, 14, 7))
	t.set_stylebox("disabled", "Button", box(Color(0.95, 0.95, 0.96), Color(BORDER, 0.6), 4, 14, 7))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", box(Color(1, 1, 1), BORDER, 4, 10, 6))
	t.set_stylebox("focus", "LineEdit", box(Color(1, 1, 1), ACCENT, 4, 10, 6))
	t.set_stylebox("panel", "PanelContainer", box(BG, Color(0, 0, 0, 0), 0, 0, 0))
	return t


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


static func primary(b: Button, color: Color = ACCENT) -> void:
	var s := box(color, color.darkened(0.2), 4, 18, 8)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = color.lightened(0.12)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_font_override("font", FONT_BOLD)


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


## Round app logo: two arrows (remote control).
static func draw_logo(ci: CanvasItem, center: Vector2, size: float) -> void:
	ci.draw_circle(center, size * 0.5, ACCENT)
	var w := size * 0.28
	var c := Color.WHITE
	ci.draw_line(center + Vector2(-w, -size * 0.08), center + Vector2(w, -size * 0.08), c, 2.0, true)
	ci.draw_line(center + Vector2(w * 0.4, -size * 0.2), center + Vector2(w, -size * 0.08), c, 2.0, true)
	ci.draw_line(center + Vector2(-w, size * 0.1), center + Vector2(w, size * 0.1), c, 2.0, true)
	ci.draw_line(center + Vector2(-w * 0.4, size * 0.22), center + Vector2(-w, size * 0.1), c, 2.0, true)


## Speaker icon; `muted` adds a cross, otherwise sound waves.
static func draw_speaker(ci: CanvasItem, center: Vector2, size: float, color: Color, muted: bool) -> void:
	var s := size / 24.0
	var body := PackedVector2Array([
		center + Vector2(-9, -3) * s, center + Vector2(-5, -3) * s, center + Vector2(0, -8) * s,
		center + Vector2(0, 8) * s, center + Vector2(-5, 3) * s, center + Vector2(-9, 3) * s,
	])
	ci.draw_colored_polygon(body, color)
	if muted:
		draw_cross(ci, center + Vector2(6, 0) * s, 14.0 * s, Color(0.85, 0.15, 0.15), 2.2)
	else:
		ci.draw_arc(center + Vector2(1, 0) * s, 5.0 * s, -0.9, 0.9, 10, color, 1.8, true)
		ci.draw_arc(center + Vector2(1, 0) * s, 9.0 * s, -0.9, 0.9, 12, color, 1.8, true)


## Small square Control that draws a check (ok) or a cross (not ok) in a circle.
static func status_icon(ok: bool, size: float = 20.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func(): _draw_status(c, ok, size))
	return c


static func _draw_status(c: Control, ok: bool, size: float) -> void:
	var mid := c.size * 0.5
	c.draw_circle(mid, size * 0.5, OK if ok else DANGER)
	if ok:
		draw_check(c, mid, size * 0.55, Color.WHITE, 2.2)
	else:
		draw_cross(c, mid, size * 0.8, Color.WHITE, 2.2)
