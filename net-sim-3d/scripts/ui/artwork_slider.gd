extends HSlider
class_name ArtworkSlider

## Native mouse/keyboard slider, drawn to match the approved 1672 x 943 artwork.
func _ready() -> void:
	min_value = 0
	max_value = 100
	step = 1
	var blank := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	blank.fill(Color.TRANSPARENT)
	var icon := ImageTexture.create_from_image(blank)
	for key in ["grabber", "grabber_highlight", "grabber_disabled"]:
		add_theme_icon_override(key, icon)
	for key in ["slider", "grabber_area", "grabber_area_highlight"]:
		add_theme_stylebox_override(key, StyleBoxEmpty.new())
	value_changed.connect(func(_v: float): queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	var y := size.y * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = Color("eeeded")
	track.border_color = Color("d0d1d3")
	track.set_border_width_all(1)
	track.set_corner_radius_all(7)
	draw_style_box(track, Rect2(0, y - 7, size.x, 14))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ee7a7c")
	fill.set_corner_radius_all(7)
	var x := 8.0 + (size.x - 16.0) * value / 100.0
	draw_style_box(fill, Rect2(0, y - 7, x, 14))
	draw_circle(Vector2(x + 1, y + 2), 9, Color("20364c25"))
	draw_circle(Vector2(x, y), 8, Color("fffffb"))
	if has_focus():
		draw_arc(Vector2(x, y), 11, 0, TAU, 32, Color("237db1"), 2, true)
