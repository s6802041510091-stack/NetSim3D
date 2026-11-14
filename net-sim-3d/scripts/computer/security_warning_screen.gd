class_name SecurityWarningScreen
extends SubViewport

## The picture on a computer's 3D screen while it shows a security warning
## (Mission 5 target PC-R3-L2) — replaces the plain red glow the user found
## too raw (2026-11-15). A Windows desktop, dimmed, with a red
## "Windows Security — Threats found" box in the middle, readable when the
## player walks up to the desk. Rendered once into a texture; the screen
## material (ComputerStation) maps it onto the monitor and makes it pulse
## gently so it stands out in the room. Everything is drawn in code (no
## Microsoft artwork).

const PIXELS := Vector2i(1024, 576)
const RED := Color(0.77, 0.17, 0.11)
const INK := Color(0.1, 0.1, 0.1)
const INK_SOFT := Color(0.33, 0.33, 0.33)
const ACCENT := Color(0.0, 0.37, 0.72)


func _init() -> void:
	size = PIXELS
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ONCE


func _ready() -> void:
	var root := Control.new()
	root.size = Vector2(PIXELS)
	add_child(root)
	var wallpaper := TextureRect.new()
	wallpaper.texture = DesktopArt.WALLPAPER
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.size = Vector2(PIXELS)
	root.add_child(wallpaper)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(PIXELS)
	root.add_child(dim)
	var taskbar := ColorRect.new()
	taskbar.color = Color(0.83, 0.9, 1.0, 0.95)
	taskbar.position = Vector2(0, PIXELS.y - 40)
	taskbar.size = Vector2(PIXELS.x, 40)
	root.add_child(taskbar)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.97, 0.97)
	style.border_color = RED
	style.border_width_top = 10
	style.set_corner_radius_all(10)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 26
	style.content_margin_bottom = 28
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 24
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(700, 0)
	card.position = Vector2((PIXELS.x - 700) * 0.5, 92)
	root.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	col.add_child(head)
	var shield := Control.new()
	shield.custom_minimum_size = Vector2(96, 110)
	shield.draw.connect(func(): _draw_shield(shield, shield.size * 0.5, 100.0))
	head.add_child(shield)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	titles.add_child(_label("Windows Security", 24, INK_SOFT))
	titles.add_child(_label("Threats found", 52, RED))
	var body := _label("Windows Security found items on this device that need your attention.", 26, INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(632, 0)
	col.add_child(body)
	var status := _label("Status: Actions recommended", 24, RED)
	col.add_child(status)
	var button := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = ACCENT
	bs.set_corner_radius_all(6)
	bs.content_margin_left = 26
	bs.content_margin_right = 26
	bs.content_margin_top = 10
	bs.content_margin_bottom = 10
	button.add_theme_stylebox_override("panel", bs)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_child(_label("Open Windows Security", 24, Color.WHITE))
	col.add_child(button)


static func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## A red shield with a white "!" (drawn, no artwork).
static func _draw_shield(ci: CanvasItem, c: Vector2, size: float) -> void:
	var w := size * 0.4
	var h := size * 0.48
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -h), c + Vector2(w, -h * 0.66), c + Vector2(w * 0.95, h * 0.1),
		c + Vector2(w * 0.55, h * 0.62), c + Vector2(0, h), c + Vector2(-w * 0.55, h * 0.62),
		c + Vector2(-w * 0.95, h * 0.1), c + Vector2(-w, -h * 0.66),
	]), RED)
	ci.draw_line(c + Vector2(0, -size * 0.25), c + Vector2(0, size * 0.09), Color.WHITE, size * 0.1, true)
	ci.draw_circle(c + Vector2(0, size * 0.23), size * 0.06, Color.WHITE)
