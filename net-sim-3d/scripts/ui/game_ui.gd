class_name GameUI
extends RefCounted

## Small shared look for in-world game UI (dialogue, objectives, summaries).
## Mission programs (NetPlan EDU, Windows Security, TeamViewer) keep their own themes.

const FONT_BOLD := preload("res://assets/fonts/Sarabun-Bold.ttf")
const INK := Color(0.11, 0.13, 0.18)
const INK_SOFT := Color(0.36, 0.40, 0.48)
const ACCENT := Color(0.16, 0.47, 0.86)
const OK := Color(0.12, 0.58, 0.32)
const BAD := Color(0.80, 0.22, 0.20)
const GOLD := Color(0.96, 0.72, 0.14)
const PANEL_DARK := Color(0.07, 0.09, 0.13, 0.94)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, pad_x: int = 16, pad_y: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func label(text: String, size: int = 18, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", FONT_BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, primary: bool = false, min_width: float = 180.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 46)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 18)
	var bg := ACCENT if primary else Color(0.93, 0.95, 0.98)
	var fg := Color.WHITE if primary else INK
	b.add_theme_stylebox_override("normal", box(bg, bg.darkened(0.15), 8, 16, 8))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.1), bg.darkened(0.2), 8, 16, 8))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.08), bg.darkened(0.25), 8, 16, 8))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), ACCENT.lightened(0.3), 8, 16, 8))
	b.add_theme_stylebox_override("disabled", box(Color(0.88, 0.89, 0.91), Color(0.8, 0.81, 0.84), 8, 16, 8))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", INK_SOFT)
	if primary:
		b.add_theme_font_override("font", FONT_BOLD)
	return b
