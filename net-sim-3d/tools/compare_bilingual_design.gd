extends SceneTree

func _initialize() -> void:
	var directory := "D:/NetSim3D/Preview/UI_เลือกด่าน_สองภาษา/"
	var pairs := {
		"levels-th": "select-level-th-draft.png",
		"levels-en": "select-level-en-draft.png",
		"settings-th": "settings-language-th-draft.png",
	}
	var report := {}
	for page: String in pairs:
		var reference := Image.load_from_file(directory + pairs[page])
		var actual := Image.load_from_file(directory + "actual/" + page + ".png")
		reference.resize(actual.get_width(), actual.get_height(), Image.INTERPOLATE_LANCZOS)
		var total := 0.0
		var samples := 0
		for y in range(0, actual.get_height(), 3):
			for x in range(0, actual.get_width(), 3):
				var a := reference.get_pixel(x, y)
				var b := actual.get_pixel(x, y)
				total += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
				samples += 1
		var difference := snappedf(total / samples * 100.0, 0.01)
		report[page] = {"mean_rgb_difference_percent": difference, "sampled_pixels": samples}
		print("DESIGN_COMPARE ", page, " average color difference ", difference, "%")
	var file := FileAccess.open(directory + "actual/comparison.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit()
