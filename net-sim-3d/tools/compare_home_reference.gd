extends SceneTree

func _initialize() -> void:
	var reference := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/home_reference_exact.png"))
	var actual := Image.load_from_file("D:/NetSim3D/tmp/menu_home.png")
	assert(reference != null and actual != null)
	reference.resize(actual.get_width(), actual.get_height(), Image.INTERPOLATE_LANCZOS)
	var total := 0.0
	var samples := 0
	for y in range(0, actual.get_height(), 3):
		for x in range(0, actual.get_width(), 3):
			var a := reference.get_pixel(x, y)
			var b := actual.get_pixel(x, y)
			total += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			samples += 1
	print("HOME_REFERENCE_MEAN_RGB_DIFFERENCE=", snappedf(total / samples * 100.0, 0.01), "% across ", samples, " samples; moving petals account for some difference")
	quit()
