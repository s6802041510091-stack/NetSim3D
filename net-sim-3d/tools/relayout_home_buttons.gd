extends SceneTree
## Turns the 4-button home artwork into a 5-button one (agreed with the user
## 2026-11-18): Play / Continue / Settings / Progress / Exit to Lobby.
##
## The painted buttons are scaled to fit five in the same space, widened back
## to their original width by stretching the plain part of each pill, and
## pasted onto a rebuilt frosted card: the card is the school picture
## (school_spring_background.png, aligned pixel for pixel with the artwork)
## blurred and fitted to the painted card colours with least squares, so the
## area behind the old buttons can be repainted. The new "Progress" pill is
## the Settings pill with its words replaced, written with Anuphan Bold.
##
## Output: assets/ui/home_{th,en}_five.png (full 1672x941 artwork, sources
## for tools/cut_menu_panels.gd, excluded from the web export).
##
## Needs a renderer for the text, so run it WITHOUT --headless:
##   godot --path net-sim-3d -s res://tools/relayout_home_buttons.gd

const SOURCES := {
	"home_th_five": ["home_th", "ความคืบหน้า"],
	"home_en_five": ["home_reference_exact", "PROGRESS"],
}
const BACKGROUND := "school_spring_background"
const HEADING_FONT := "res://assets/fonts/Anuphan-Variable.ttf"

## Painted pills in the original artwork (x, top, bottom), same in both languages.
const PILL_X := 193
const PILL_W := 566
const PILLS := [[383, 470], [484, 570], [585, 670], [685, 771]]
## Margin cut around each pill (keeps its soft shadow) and blended away.
const CUT_PAD := Vector2i(10, 12)
const FEATHER := 8.0

## New layout: five pills, Play keeps its top, the last ends above the slogan.
const SCALE := 0.82
const GAP := 12
const TOP := 383
## Words sit between these columns of an original pill (relative to PILL_X);
## columns outside them are plain pill and are stretched to restore the width.
const PLAIN_LEFT := 110
const PLAIN_RIGHT := 460
## Order of the painted pills in the new layout; -1 = the new Progress pill.
const ORDER := [0, 1, 2, -1, 3]
const PROGRESS_TEMPLATE := 2

## Area rebuilt from the blurred school picture (inside the card).
const PATCH := Rect2i(176, 368, 600, 432)
## Card areas used to fit the frosted look (no buttons, no text).
const FIT_AREAS := [Rect2i(78, 372, 100, 420), Rect2i(774, 372, 104, 420)]
const INK := Color("0f1942")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bg := _load(BACKGROUND)
	var blur_small := _blur(bg, 3)
	var blur_large := _blur(bg, 4)
	for target: String in SOURCES:
		var art := _load(SOURCES[target][0])
		var frosted := _fit_frosted(art, blur_small, blur_large)
		var out := art.duplicate() as Image
		_paste_patch(out, frosted)
		var pills := []
		for i in PILLS.size():
			pills.append(_pill(art, i))
		var progress := await _progress_pill(pills[PROGRESS_TEMPLATE], SOURCES[target][1])
		var y := TOP
		for slot in ORDER:
			var pill: Image = progress if slot == -1 else pills[slot]
			_blend(out, pill, Vector2i(PILL_X - CUT_PAD.x, y - roundi(CUT_PAD.y * SCALE)))
			print("PILL %s slot=%d y=%d..%d" % [target, slot, y, y + _pill_height()])
			y += _pill_height() + GAP
		out.convert(Image.FORMAT_RGBA8)
		out.save_png(ProjectSettings.globalize_path("res://assets/ui/%s.png" % target))
		print("SAVED %s" % target)
	quit()


func _load(name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/%s.png" % name))
	image.convert(Image.FORMAT_RGBAF)
	return image


func _pill_height() -> int:
	return roundi((PILLS[0][1] - PILLS[0][0]) * SCALE)


## Soft blur: halve the picture `steps` times, then scale back up smoothly.
func _blur(source: Image, steps: int) -> Image:
	var image := source.duplicate() as Image
	var size := image.get_size()
	for i in steps:
		image.resize(maxi(image.get_width() / 2, 1), maxi(image.get_height() / 2, 1), Image.INTERPOLATE_BILINEAR)
	image.resize(size.x, size.y, Image.INTERPOLATE_CUBIC)
	return image


## card ≈ a·blur_small + b·blur_large + c·x + d·y + e per colour channel,
## solved on FIT_AREAS; returns the rebuilt card for PATCH (and reports the error).
func _fit_frosted(art: Image, blur_small: Image, blur_large: Image) -> Image:
	var coefficients := []
	var residual := 0.0
	var samples := 0
	for channel in 3:
		var ata := []
		var atb := []
		for i in 5:
			ata.append([0.0, 0.0, 0.0, 0.0, 0.0])
			atb.append(0.0)
		for area: Rect2i in FIT_AREAS:
			for y in range(area.position.y, area.end.y, 2):
				for x in range(area.position.x, area.end.x, 2):
					var f := _features(blur_small, blur_large, x, y, channel)
					var t: float = art.get_pixel(x, y)[channel]
					for i in 5:
						atb[i] += f[i] * t
						for j in 5:
							ata[i][j] += f[i] * f[j]
		var k := _solve(ata, atb)
		coefficients.append(k)
		for area: Rect2i in FIT_AREAS:
			for y in range(area.position.y, area.end.y, 4):
				for x in range(area.position.x, area.end.x, 4):
					var e: float = _apply(k, _features(blur_small, blur_large, x, y, channel)) - art.get_pixel(x, y)[channel]
					residual += e * e
					samples += 1
	print("FROSTED fit rms=%.4f (0..1)" % sqrt(residual / samples))
	var frosted := Image.create_empty(PATCH.size.x, PATCH.size.y, false, Image.FORMAT_RGBAF)
	for y in PATCH.size.y:
		for x in PATCH.size.x:
			var px := PATCH.position.x + x
			var py := PATCH.position.y + y
			var c := Color(0, 0, 0, 1)
			for channel in 3:
				c[channel] = clampf(_apply(coefficients[channel], _features(blur_small, blur_large, px, py, channel)), 0.0, 1.0)
			frosted.set_pixel(x, y, c)
	return frosted


func _features(a: Image, b: Image, x: int, y: int, channel: int) -> Array:
	return [a.get_pixel(x, y)[channel], b.get_pixel(x, y)[channel], x / 1000.0, y / 1000.0, 1.0]


func _apply(k: Array, f: Array) -> float:
	var v := 0.0
	for i in k.size():
		v += k[i] * f[i]
	return v


## Gaussian elimination with partial pivoting (small dense system).
func _solve(m: Array, v: Array) -> Array:
	var n := v.size()
	var a := []
	for i in n:
		var row: Array = m[i].duplicate()
		row.append(v[i])
		a.append(row)
	for col in n:
		var pivot := col
		for r in range(col + 1, n):
			if absf(a[r][col]) > absf(a[pivot][col]):
				pivot = r
		var tmp: Array = a[col]
		a[col] = a[pivot]
		a[pivot] = tmp
		for r in range(col + 1, n):
			var f: float = a[r][col] / a[col][col]
			for c in range(col, n + 1):
				a[r][c] -= f * a[col][c]
	var x := []
	x.resize(n)
	for i in range(n - 1, -1, -1):
		var s: float = a[i][n]
		for j in range(i + 1, n):
			s -= a[i][j] * x[j]
		x[i] = s / a[i][i]
	return x


## Puts the rebuilt card into PATCH, blending into the painted card at its edges.
func _paste_patch(out: Image, frosted: Image) -> void:
	var blend := 14.0
	for y in PATCH.size.y:
		for x in PATCH.size.x:
			var edge := minf(minf(x, PATCH.size.x - 1 - x), minf(y, PATCH.size.y - 1 - y))
			var w := clampf(edge / blend, 0.0, 1.0)
			var p := Vector2i(PATCH.position.x + x, PATCH.position.y + y)
			out.set_pixelv(p, out.get_pixelv(p).lerp(frosted.get_pixel(x, y), w))


## One painted pill (with its shadow margin), scaled and widened back.
func _pill(art: Image, index: int) -> Image:
	var top: int = PILLS[index][0]
	var bottom: int = PILLS[index][1]
	var cut := art.get_region(Rect2i(PILL_X - CUT_PAD.x, top - CUT_PAD.y, PILL_W + CUT_PAD.x * 2, bottom - top + CUT_PAD.y * 2))
	var scaled_w := roundi(cut.get_width() * SCALE)
	var scaled_h := roundi(cut.get_height() * SCALE)
	cut.resize(scaled_w, scaled_h, Image.INTERPOLATE_LANCZOS)
	var left := roundi((CUT_PAD.x + PLAIN_LEFT) * SCALE)
	var right := roundi((CUT_PAD.x + PLAIN_RIGHT) * SCALE)
	var target_w := PILL_W + CUT_PAD.x * 2
	var extra := target_w - scaled_w
	var extra_left := extra / 2
	var out := Image.create_empty(target_w, scaled_h, false, Image.FORMAT_RGBAF)
	for y in scaled_h:
		for x in target_w:
			var sx: int
			if x < left:
				sx = x
			elif x < left + extra_left:
				sx = left
			elif x < right + extra_left:
				sx = x - extra_left
			elif x < right + extra:
				sx = right
			else:
				sx = x - extra
			out.set_pixel(x, y, cut.get_pixel(sx, y))
	return out


## The Settings pill with its words removed (plain pill blended across the
## middle) and `text` written in the painted ink colour.
func _progress_pill(template: Image, text: String) -> Image:
	var pill := template.duplicate() as Image
	var extra := pill.get_width() - roundi((PILL_W + CUT_PAD.x * 2) * SCALE)
	var left := roundi((CUT_PAD.x + PLAIN_LEFT) * SCALE)
	var right := roundi((CUT_PAD.x + PLAIN_RIGHT) * SCALE) + extra
	for y in pill.get_height():
		var a := pill.get_pixel(left, y)
		var b := pill.get_pixel(right, y)
		for x in range(left + 1, right):
			pill.set_pixel(x, y, a.lerp(b, float(x - left) / float(right - left)))
	var words := await _render_text(text, pill.get_size())
	for y in pill.get_height():
		for x in pill.get_width():
			var t := words.get_pixel(x, y)
			if t.a > 0.0:
				pill.set_pixel(x, y, pill.get_pixel(x, y).lerp(INK, t.a))
	return pill


## Renders centred words on a transparent image the size of the pill cut.
func _render_text(text: String, size: Vector2i) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var font := FontVariation.new()
	font.base_font = load(HEADING_FONT)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	font.variation_embolden = 0.3 if text == "PROGRESS" else 0.45
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 34 if text == "PROGRESS" else 38)
	label.add_theme_color_override("font_color", INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(size)
	# The pill's own centre (its shadow margin is larger at the bottom).
	label.position = Vector2(0, -2)
	viewport.add_child(label)
	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBAF)
	viewport.queue_free()
	return image


## Alpha-blends `pill` into `out` at `at`, fading out over its outer FEATHER px.
func _blend(out: Image, pill: Image, at: Vector2i) -> void:
	var w := pill.get_width()
	var h := pill.get_height()
	for y in h:
		for x in w:
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			var k := clampf(edge / FEATHER, 0.0, 1.0)
			var p := at + Vector2i(x, y)
			out.set_pixelv(p, out.get_pixelv(p).lerp(pill.get_pixel(x, y), k))
