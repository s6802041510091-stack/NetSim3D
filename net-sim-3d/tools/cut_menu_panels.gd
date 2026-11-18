extends SceneTree
## Cuts the menu panels out of the full menu artwork (agreed with the user
## 2026-11-18): the screen is now a full-bleed background
## (school_spring_background-new.png, 21:9) with the panel on top, so every
## window shape is filled without stretching or blurred side bands.
##
## Each panel keeps the 1672x941 canvas of its source picture with everything
## outside the rounded card transparent, so the click areas in game_flow.gd
## (artwork coordinates) still sit on the painted buttons. Thai and English
## use the same frame: the panels are the same size in both languages.
##
## The source pictures stay in assets/ui as the originals and are excluded
## from the web export (export_presets.cfg exclude_filter).
##
## Run: godot --headless --path net-sim-3d -s res://tools/cut_menu_panels.gd

## Card frame per page (x, y, w, h) in artwork pixels, measured on the
## originals 2026-11-18, plus the corner radius.
const FRAMES := {
	"home": [Rect2i(67, 82, 821, 807), 56.0],
	"levels": [Rect2i(232, 80, 1186, 826), 62.0],
	"settings": [Rect2i(147, 70, 1378, 799), 52.0],
}
const SOURCES := {
	"menu_panel_home_th": ["home_th", "home"],
	"menu_panel_home_en": ["home_reference_exact", "home"],
	"menu_panel_levels_th": ["select_level_th", "levels"],
	"menu_panel_levels_en": ["select_level_en", "levels"],
	"menu_panel_settings_th": ["settings_th_base", "settings"],
	"menu_panel_settings_en": ["settings_en_base", "settings"],
}
## Width of the anti-aliased edge (pixels).
const FEATHER := 1.5


func _initialize() -> void:
	for target: String in SOURCES:
		var source: String = SOURCES[target][0]
		var frame: Rect2i = FRAMES[SOURCES[target][1]][0]
		var radius: float = FRAMES[SOURCES[target][1]][1]
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/%s.png" % source))
		image.convert(Image.FORMAT_RGBA8)
		var kept := 0
		for y in image.get_height():
			for x in image.get_width():
				var alpha := _coverage(Vector2(x + 0.5, y + 0.5), frame, radius)
				# Fully transparent pixels are cleared so the PNG compresses well.
				var colour := image.get_pixel(x, y) if alpha > 0.0 else Color(0, 0, 0, 0)
				colour.a = alpha
				image.set_pixel(x, y, colour)
				if alpha > 0.0:
					kept += 1
		var path := ProjectSettings.globalize_path("res://assets/ui/%s.png" % target)
		image.save_png(path)
		print("PANEL %s <- %s frame=%s kept=%d px" % [target, source, frame, kept])
	quit()


## 1 inside the rounded rectangle, 0 outside, a soft ramp on the edge.
func _coverage(p: Vector2, frame: Rect2i, radius: float) -> float:
	var half := Vector2(frame.size) / 2.0
	var centre := Vector2(frame.position) + half
	var q := (p - centre).abs() - (half - Vector2(radius, radius))
	var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
	return clampf(0.5 - outside / FEATHER, 0.0, 1.0)
