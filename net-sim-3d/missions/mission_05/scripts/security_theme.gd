class_name SecurityTheme
extends RefCounted

## Colours, fonts and drawing helpers for the simulated Windows Security
## program (Mission 5), styled after Windows 11 (user, 2026-11-13). Every icon
## is drawn here with lines — no Microsoft artwork is used. The bundled
## Sarabun font renders in the Web export (Thai and Latin).

const FONT_REGULAR := preload("res://assets/fonts/Sarabun-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Sarabun-Bold.ttf")

## Windows 11 light theme.
const INK := Color(0.10, 0.10, 0.10)
const INK_SOFT := Color(0.37, 0.37, 0.37)
const BG := Color(0.953, 0.953, 0.953) # window / Mica
const CONTENT := Color(0.976, 0.976, 0.976)
const CARD := Color(1, 1, 1)
const SIDEBAR := Color(0.953, 0.953, 0.953)
const BORDER := Color(0.898, 0.898, 0.898)
const HOVER := Color(0, 0, 0, 0.04)
const SELECTED := Color(0, 0, 0, 0.06)
const ACCENT := Color(0.0, 0.373, 0.722) # #005FB8
const LINK := Color(0.0, 0.373, 0.722)
const OK := Color(0.063, 0.486, 0.063) # #107C10
const WARNING := Color(1.0, 0.725, 0.0) # #FFB900
const WARNING_INK := Color(0.62, 0.36, 0.0)
const DANGER := Color(0.769, 0.169, 0.110) # #C42B1C
const DANGER_BG := Color(0.992, 0.906, 0.914)
const WARNING_BG := Color(1.0, 0.957, 0.808)
const OK_BG := Color(0.875, 0.965, 0.867)
const INFO_BG := Color(0.906, 0.949, 0.988)
const OK_BG_SOFT := OK_BG
## Kept for older callers.
const OK_DARK := OK


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_REGULAR
	t.default_font_size = 15
	for type in ["Label", "Button", "CheckBox"]:
		t.set_color("font_color", type, INK)
	for c in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
		t.set_color(c, "CheckBox", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.38))
	t.set_stylebox("normal", "Button", box(Color(0.984, 0.984, 0.984), Color(0.85, 0.85, 0.85), 4, 14, 6))
	t.set_stylebox("hover", "Button", box(Color(0.965, 0.965, 0.965), Color(0.85, 0.85, 0.85), 4, 14, 6))
	t.set_stylebox("pressed", "Button", box(Color(0.945, 0.945, 0.945), Color(0.88, 0.88, 0.88), 4, 14, 6))
	t.set_stylebox("disabled", "Button", box(Color(0.96, 0.96, 0.96), Color(0.9, 0.9, 0.9), 4, 14, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(s, "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(CARD, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("background", "ProgressBar", box(Color(0.82, 0.82, 0.82), Color(0, 0, 0, 0), 2, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 2, 0, 0))
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
	s.anti_aliasing = true
	return s


## Accent (blue) button like "Quick scan" / "Start actions".
static func style_accent(b: Button) -> void:
	var s := box(ACCENT, ACCENT, 4, 16, 6)
	var h := box(ACCENT.lightened(0.1), ACCENT.lightened(0.1), 4, 16, 6)
	var p := box(ACCENT.darkened(0.1), ACCENT.darkened(0.1), 4, 16, 6)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", box(Color(0.75, 0.75, 0.75), Color(0.75, 0.75, 0.75), 4, 16, 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color.WHITE)


## A text button drawn as a blue link ("Scan options", "Manage settings").
static func style_link(b: Button) -> void:
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", LINK)
	b.add_theme_color_override("font_hover_color", LINK.darkened(0.2))
	b.add_theme_color_override("font_pressed_color", LINK.darkened(0.35))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT


static func draw_check(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 2.0) -> void:
	ci.draw_polyline(PackedVector2Array([
		center + Vector2(-0.42, 0.02) * size,
		center + Vector2(-0.12, 0.3) * size,
		center + Vector2(0.44, -0.3) * size,
	]), color, width, true)


static func draw_cross(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 2.0) -> void:
	var h := size * 0.3
	ci.draw_line(center + Vector2(-h, -h), center + Vector2(h, h), color, width, true)
	ci.draw_line(center + Vector2(-h, h), center + Vector2(h, -h), color, width, true)


## Filled shield (kept for the desktop icon look); `mark` is "check", "alert" or "".
static func draw_shield(ci: CanvasItem, center: Vector2, size: float, color: Color, mark: String = "") -> void:
	ci.draw_colored_polygon(_shield_points(center, size), color)
	match mark:
		"check":
			draw_check(ci, center + Vector2(0, size * 0.02), size * 0.5, Color.WHITE, maxf(2.0, size * 0.08))
		"alert":
			ci.draw_line(center + Vector2(0, -size * 0.25), center + Vector2(0, size * 0.09), Color.WHITE, maxf(2.0, size * 0.09), true)
			ci.draw_circle(center + Vector2(0, size * 0.23), maxf(1.5, size * 0.055), Color.WHITE)


static func _shield_points(center: Vector2, size: float) -> PackedVector2Array:
	var w := size * 0.4
	var h := size * 0.48
	return PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, -h * 0.66),
		center + Vector2(w * 0.95, h * 0.1),
		center + Vector2(w * 0.55, h * 0.62),
		center + Vector2(0, h),
		center + Vector2(-w * 0.55, h * 0.62),
		center + Vector2(-w * 0.95, h * 0.1),
		center + Vector2(-w, -h * 0.66),
	])


## Line icon of a Windows Security section, drawn inside `size` x `size`
## around `c`. kinds: home, virus, account, firewall, app, device, health,
## family, history, settings, menu, back, folder, file.
static func draw_glyph(ci: CanvasItem, kind: String, c: Vector2, size: float, color: Color) -> void:
	var s := size / 16.0
	var w := maxf(1.2, 1.25 * s)
	var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * s
	match kind:
		"home":
			ci.draw_polyline(PackedVector2Array([p.call(-6, -0.5), p.call(0, -6.5), p.call(6, -0.5)]), color, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(-4.5, -1.5), p.call(-4.5, 6), p.call(4.5, 6), p.call(4.5, -1.5)]), color, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(-1.5, 6), p.call(-1.5, 2), p.call(1.5, 2), p.call(1.5, 6)]), color, w, true)
		"virus":
			var pts := _shield_points(c, 14.0 * s)
			pts.append(pts[0])
			ci.draw_polyline(pts, color, w, true)
		"account":
			ci.draw_arc(p.call(0, -2.5), 3.0 * s, 0, TAU, 24, color, w, true)
			ci.draw_arc(p.call(0, 7.5), 6.0 * s, PI * 1.08, PI * 1.92, 20, color, w, true)
		"firewall":
			ci.draw_line(p.call(0, -1), p.call(0, 6.5), color, w, true)
			ci.draw_circle(p.call(0, -1.5), 1.3 * s, color)
			for r in [3.5, 6.5]:
				ci.draw_arc(p.call(0, -1.5), r * s, -PI * 0.78, -PI * 0.22, 12, color, w, true)
				ci.draw_arc(p.call(0, -1.5), r * s, PI * 0.22 - PI, -PI * 1.22 + PI, 12, color, w, true)
		"app":
			ci.draw_rect(Rect2(p.call(-6.5, -5.5), Vector2(13, 11) * s), color, false, w)
			ci.draw_line(p.call(-6.5, -2.5), p.call(6.5, -2.5), color, w, true)
			ci.draw_line(p.call(-2, 0.5), p.call(-4, 2.5), color, w, true)
			ci.draw_line(p.call(2, 0.5), p.call(4, 2.5), color, w, true)
		"device":
			ci.draw_rect(Rect2(p.call(-5.5, -5), Vector2(11, 8) * s), color, false, w)
			ci.draw_line(p.call(-7.5, 5), p.call(7.5, 5), color, w, true)
			ci.draw_rect(Rect2(p.call(-1.8, -2.8), Vector2(3.6, 3.6) * s), color, false, w)
		"health":
			ci.draw_polyline(PackedVector2Array([p.call(0, 6), p.call(-6, 0), p.call(-6.5, -3), p.call(-4.5, -5.5), p.call(-1.8, -5.5), p.call(0, -3), p.call(1.8, -5.5), p.call(4.5, -5.5), p.call(6.5, -3), p.call(6, 0), p.call(0, 6)]), color, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(-5, -0.5), p.call(-2, -0.5), p.call(-0.8, -2.5), p.call(0.8, 1.5), p.call(2, -0.5), p.call(5, -0.5)]), color, w * 0.9, true)
		"family":
			for x in [-4.0, 4.0]:
				ci.draw_arc(p.call(x, -3), 2.2 * s, 0, TAU, 18, color, w, true)
				ci.draw_arc(p.call(x, 5.5), 3.8 * s, PI * 1.1, PI * 1.9, 14, color, w, true)
			ci.draw_arc(p.call(0, 0.5), 1.6 * s, 0, TAU, 14, color, w, true)
		"history":
			ci.draw_arc(c, 6.5 * s, -PI * 0.75, PI * 1.05, 32, color, w, true)
			ci.draw_line(p.call(-4.6, -4.6), p.call(-4.6, -1.6), color, w, true)
			ci.draw_line(p.call(-4.6, -4.6), p.call(-7.4, -4.6), color, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(0, -3.5), p.call(0, 0), p.call(2.6, 1.8)]), color, w, true)
		"settings":
			ci.draw_arc(c, 2.4 * s, 0, TAU, 20, color, w, true)
			ci.draw_arc(c, 5.0 * s, 0, TAU, 32, color, w, true)
			for i in 8:
				var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
				ci.draw_line(c + d * 5.0 * s, c + d * 7.0 * s, color, w * 1.6, true)
		"menu":
			for y in [-4.0, 0.0, 4.0]:
				ci.draw_line(p.call(-6, y), p.call(6, y), color, w, true)
		"back":
			ci.draw_line(p.call(-6, 0), p.call(6, 0), color, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(-1, -5), p.call(-6, 0), p.call(-1, 5)]), color, w, true)
		"folder":
			ci.draw_colored_polygon(PackedVector2Array([p.call(-7, -5), p.call(-2, -5), p.call(0, -3), p.call(7, -3), p.call(7, 5), p.call(-7, 5)]), Color(0.98, 0.78, 0.3))
		"file":
			ci.draw_polyline(PackedVector2Array([p.call(-4.5, -6.5), p.call(2, -6.5), p.call(4.5, -4), p.call(4.5, 6.5), p.call(-4.5, 6.5), p.call(-4.5, -6.5)]), color, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(2, -6.5), p.call(2, -4), p.call(4.5, -4)]), color, w, true)


## Status badge: "ok" (green check), "warn" (yellow triangle !), "bad" (red X).
static func draw_badge(ci: CanvasItem, kind: String, c: Vector2, size: float) -> void:
	match kind:
		"ok":
			ci.draw_circle(c, size * 0.5, OK)
			draw_check(ci, c, size * 0.55, Color.WHITE, maxf(1.6, size * 0.11))
		"warn":
			var h := size * 0.5
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 1.05, h * 0.85), c + Vector2(-h * 1.05, h * 0.85)]), WARNING)
			ci.draw_line(c + Vector2(0, -h * 0.35), c + Vector2(0, h * 0.28), INK, maxf(1.4, size * 0.1), true)
			ci.draw_circle(c + Vector2(0, h * 0.58), maxf(0.9, size * 0.06), INK)
		"bad":
			ci.draw_circle(c, size * 0.5, DANGER)
			draw_cross(ci, c, size * 0.9, Color.WHITE, maxf(1.6, size * 0.11))
		"info":
			ci.draw_circle(c, size * 0.5, ACCENT)
			ci.draw_line(c + Vector2(0, -size * 0.05), c + Vector2(0, size * 0.25), Color.WHITE, maxf(1.4, size * 0.1), true)
			ci.draw_circle(c + Vector2(0, -size * 0.22), maxf(0.9, size * 0.06), Color.WHITE)


## A Control that draws a status badge ("ok", "warn", "bad", "info").
static func icon(kind: String, _color: Color = Color.WHITE, size: float = 18.0) -> Control:
	var map := {"check": "ok", "alert": "warn", "cross": "bad"}
	var badge: String = map.get(kind, kind)
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func(): draw_badge(c, badge, c.size * 0.5, size))
	return c


## A Control that draws a section glyph, optionally with a status badge at
## its lower right (the Home tiles).
static func glyph(kind: String, size: float, color: Color = INK, badge: String = "") -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		draw_glyph(c, kind, c.size * 0.5, size * 0.85, color)
		if badge != "":
			var b := size * 0.42
			var at := c.size * 0.5 + Vector2(size * 0.32, size * 0.3)
			c.draw_circle(at, b * 0.62, CONTENT)
			draw_badge(c, badge, at, b))
	return c


## Windows 11 toggle switch with "On"/"Off" beside it. `changed` gets the new value.
static func toggle(on: bool, changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var sw := Button.new()
	sw.name = "Switch"
	sw.custom_minimum_size = Vector2(40, 20)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.focus_mode = Control.FOCUS_NONE
	sw.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s in ["normal", "hover", "pressed", "focus"]:
		sw.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	sw.set_meta("on", on)
	sw.draw.connect(func():
		var is_on: bool = sw.get_meta("on")
		var r := Rect2(Vector2.ZERO, sw.size)
		var sb := box(ACCENT if is_on else Color(0, 0, 0, 0), ACCENT if is_on else INK_SOFT, int(sw.size.y * 0.5), 0, 0)
		sw.draw_style_box(sb, r)
		var knob := Vector2(sw.size.x - sw.size.y * 0.5 if is_on else sw.size.y * 0.5, sw.size.y * 0.5)
		sw.draw_circle(knob, sw.size.y * 0.28, Color.WHITE if is_on else INK_SOFT))
	row.add_child(sw)
	var l := Label.new()
	l.name = "State"
	l.text = "On" if on else "Off"
	row.add_child(l)
	sw.pressed.connect(func():
		var now: bool = not sw.get_meta("on")
		sw.set_meta("on", now)
		l.text = "On" if now else "Off"
		sw.queue_redraw()
		changed.call(now))
	return row
