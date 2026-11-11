extends SceneTree

func _initialize() -> void:
	var sources := {"sheet": DesktopArt.SYSTEM_ICONS.get_image(), "netplan": DesktopArt.NETPLAN.get_image()}
	for key: String in sources:
		var source: Image = sources[key]
		var count := 4 if key == "sheet" else 1
		var cell := Vector2i(source.get_size()) / (2 if count == 4 else 1)
		for index in range(count):
			var offset := Vector2i(index % 2, index / 2) * cell if count == 4 else Vector2i.ZERO
			var lo := cell
			var hi := Vector2i.ZERO
			for y in range(cell.y):
				for x in range(cell.x):
					if source.get_pixelv(offset + Vector2i(x, y)).a > 0.5:
						lo = lo.min(Vector2i(x, y))
						hi = hi.max(Vector2i(x, y))
			print("ICON_BOUNDS ", key, " ", index, " ", Rect2i(lo + offset, hi - lo + Vector2i.ONE))
	quit()
