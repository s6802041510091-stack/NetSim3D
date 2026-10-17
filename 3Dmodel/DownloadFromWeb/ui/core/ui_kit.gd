class_name UIKit
## Small helpers so every simulated program looks consistent (Windows 11-like light theme).

const ACCENT := Color("0067c0")
const ACCENT_HOVER := Color("1975c5")
const BG := Color("f3f3f3")
const PANEL := Color("ffffff")
const BORDER := Color("d6d6d6")
const TEXT := Color("1b1b1b")
const TEXT_DIM := Color("5f5f5f")
const OK := Color("0f7b0f")
const BAD := Color("c42b1c")
const WARN := Color("9d5d00")

static var _ui_font: Font
static var _mono_font: Font
static var _theme: Theme


static func ui_font() -> Font:
	if _ui_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Tahoma", "Leelawadee UI", "Noto Sans", "DejaVu Sans", "sans-serif"])
		_ui_font = f
	return _ui_font


static func mono_font() -> Font:
	if _mono_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "DejaVu Sans Mono", "monospace"])
		_mono_font = f
	return _mono_font


static func box(bg: Color, border := Color.TRANSPARENT, radius := 4, border_w := 1, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.set_content_margin_all(pad)
	return s


## Shared theme: light Windows-like controls.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 14
	for c in ["Label", "Button", "LineEdit", "CheckBox", "OptionButton", "Tree", "ItemList", "TabBar", "PopupMenu"]:
		t.set_color("font_color", c, TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("a0a0a0"))
	t.set_stylebox("normal", "Button", box(Color("fdfdfd"), BORDER, 4, 1, 6))
	t.set_stylebox("hover", "Button", box(Color("f5f5f5"), BORDER, 4, 1, 6))
	t.set_stylebox("pressed", "Button", box(Color("ebebeb"), BORDER, 4, 1, 6))
	t.set_stylebox("disabled", "Button", box(Color("f5f5f5"), Color("e5e5e5"), 4, 1, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", box(Color.WHITE, Color("bdbdbd"), 4, 1, 6))
	t.set_stylebox("focus", "LineEdit", box(Color.WHITE, ACCENT, 4, 1, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color("8a8a8a"))
	t.set_stylebox("normal", "OptionButton", box(Color("fdfdfd"), BORDER, 4, 1, 6))
	t.set_stylebox("hover", "OptionButton", box(Color("f5f5f5"), BORDER, 4, 1, 6))
	t.set_stylebox("pressed", "OptionButton", box(Color("ebebeb"), BORDER, 4, 1, 6))
	t.set_stylebox("panel", "PopupMenu", box(Color.WHITE, BORDER, 4, 1, 4))
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_stylebox("hover", "PopupMenu", box(Color("e8f1fb"), Color.TRANSPARENT, 3))
	t.set_stylebox("panel", "Tree", box(Color.WHITE, BORDER, 0, 1, 0))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", box(Color("cce4f7")))
	t.set_stylebox("selected_focus", "Tree", box(Color("cce4f7")))
	t.set_stylebox("title_button_normal", "Tree", box(Color("f7f7f7"), BORDER, 0, 1, 4))
	t.set_stylebox("title_button_hover", "Tree", box(Color("efefef"), BORDER, 0, 1, 4))
	t.set_stylebox("title_button_pressed", "Tree", box(Color("e5e5e5"), BORDER, 0, 1, 4))
	t.set_color("title_button_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", TEXT)
	t.set_color("guide_color", "Tree", Color("eeeeee"))
	t.set_constant("draw_guides", "Tree", 1)
	t.set_stylebox("panel", "ItemList", box(Color.WHITE, BORDER, 0, 1, 2))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(Color("cce4f7")))
	t.set_stylebox("selected_focus", "ItemList", box(Color("cce4f7")))
	t.set_color("font_selected_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", TEXT)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("tab_selected", "TabBar", box(Color.WHITE, BORDER, 0, 1, 8))
	t.set_stylebox("tab_unselected", "TabBar", box(Color("ececec"), BORDER, 0, 1, 8))
	t.set_stylebox("tab_hovered", "TabBar", box(Color("f6f6f6"), BORDER, 0, 1, 8))
	t.set_color("font_selected_color", "TabBar", TEXT)
	t.set_color("font_unselected_color", "TabBar", TEXT_DIM)
	t.set_color("font_hovered_color", "TabBar", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color("e6e6e6"), Color.TRANSPARENT, 3))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color.TRANSPARENT, 3))
	t.set_color("font_color", "ProgressBar", TEXT)
	_theme = t
	return t


static func label(text: String, size := 14, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		var f := FontVariation.new()
		f.base_font = ui_font()
		f.variation_embolden = 0.8
		l.add_theme_font_override("font", f)
	return l


static func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", box(ACCENT, Color.TRANSPARENT, 4, 1, 6))
		b.add_theme_stylebox_override("hover", box(ACCENT_HOVER, Color.TRANSPARENT, 4, 1, 6))
		b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.15), Color.TRANSPARENT, 4, 1, 6))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Color.WHITE)
	return b


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func margin(child: Control, all := 12) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	m.add_child(child)
	return m


static func panel(bg := PANEL, border := BORDER, radius := 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius))
	return p


static func expand(c: Control, v := true, h := true) -> Control:
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Simple generic app icon: rounded square with a glyph (no real logos).
static func icon(glyph: String, bg: Color, size := 40) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", box(bg, Color.TRANSPARENT, int(size * 0.22)))
	var l := Label.new()
	l.text = glyph
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size * 0.42))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_font_override("font", mono_font() if glyph.length() > 2 else ui_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
