class_name NetPlanTheme
extends RefCounted

## Colours, fonts and the Theme used by the NetPlan EDU program.
## Uses the bundled Sarabun font so Thai text also renders in the Web export
## (browsers give Godot no system fonts to fall back on).

const FONT_REGULAR := preload("res://assets/fonts/Sarabun-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Sarabun-Bold.ttf")

const INK := Color(0.10, 0.13, 0.19)
const INK_SOFT := Color(0.33, 0.38, 0.47)
const ACCENT := Color(0.13, 0.42, 0.78)
const TITLE_BAR := Color(0.09, 0.19, 0.35)
const MENU_BAR := Color(0.93, 0.94, 0.96)
const TOOLBAR := Color(0.98, 0.98, 0.99)
const PANEL := Color(0.95, 0.96, 0.98)
const BORDER := Color(0.78, 0.81, 0.86)
const PLAN_BG := Color(0.975, 0.985, 1.0)

const EMPTY := Color(0.95, 0.52, 0.10)     ## orange: not chosen yet
const SELECTED := Color(0.27, 0.66, 0.38)  ## green with a check mark: chosen, not checked
const CORRECT := Color(0.09, 0.50, 0.24)   ## green: correct after a check
const WRONG := Color(0.85, 0.18, 0.17)     ## red: wrong after a check
const LAN := Color(0.16, 0.45, 0.82)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_REGULAR
	t.default_font_size = 16

	for type in ["Label", "Button", "MenuButton", "CheckBox", "PopupMenu", "TooltipLabel"]:
		t.set_color("font_color", type, INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.38))
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "MenuButton", Color(INK, 0.38))
	t.set_color("font_hover_color", "MenuButton", INK)
	t.set_color("font_pressed_color", "MenuButton", INK)

	t.set_stylebox("normal", "Button", box(Color(1, 1, 1), BORDER, 6))
	t.set_stylebox("hover", "Button", box(Color(0.92, 0.95, 1.0), ACCENT.lightened(0.3), 6))
	t.set_stylebox("pressed", "Button", box(Color(0.85, 0.90, 0.98), ACCENT, 6))
	t.set_stylebox("disabled", "Button", box(Color(0.95, 0.95, 0.96), Color(BORDER, 0.6), 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	t.set_stylebox("normal", "MenuButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 10, 4))
	t.set_stylebox("hover", "MenuButton", box(Color(0.85, 0.89, 0.95), Color(0, 0, 0, 0), 4, 10, 4))
	t.set_stylebox("pressed", "MenuButton", box(Color(0.80, 0.86, 0.95), Color(0, 0, 0, 0), 4, 10, 4))
	t.set_stylebox("focus", "MenuButton", StyleBoxEmpty.new())

	t.set_stylebox("panel", "PopupMenu", box(Color(1, 1, 1), BORDER, 4, 6, 6))
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_color("font_disabled_color", "PopupMenu", Color(INK, 0.38))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.88, 0.92, 0.99), Color(0, 0, 0, 0), 3))
	t.set_font_size("font_size", "PopupMenu", 16)

	t.set_stylebox("panel", "TooltipPanel", box(Color(1, 1, 0.94), BORDER, 4, 8, 4))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(0, 0, 0, 0), 0, 0, 0))

	var bar_bg := box(Color(0.86, 0.88, 0.92), Color(0, 0, 0, 0), 4, 0, 0)
	var bar_fill := box(SELECTED, Color(0, 0, 0, 0), 4, 0, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


## Flat box with optional border; `pad_x`/`pad_y` are the content margins.
static func box(bg: Color, border: Color, radius: int = 0, pad_x: int = 10, pad_y: int = 6) -> StyleBoxFlat:
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


static func status_color(status: Mission01State.PointStatus) -> Color:
	match status:
		Mission01State.PointStatus.SELECTED:
			return SELECTED
		Mission01State.PointStatus.CORRECT:
			return CORRECT
		Mission01State.PointStatus.WRONG:
			return WRONG
	return EMPTY


## Small vector check mark (the Sarabun font has no ✓ glyph).
static func draw_check(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 2.5) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-0.45, 0.02) * size,
		center + Vector2(-0.12, 0.34) * size,
		center + Vector2(0.48, -0.32) * size,
	])
	ci.draw_polyline(pts, color, width, true)


## Small vector cross.
static func draw_cross(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 2.0) -> void:
	var h := size * 0.35
	ci.draw_line(center + Vector2(-h, -h), center + Vector2(h, h), color, width, true)
	ci.draw_line(center + Vector2(-h, h), center + Vector2(h, -h), color, width, true)
