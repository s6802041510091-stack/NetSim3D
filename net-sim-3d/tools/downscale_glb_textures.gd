extends SceneTree

## Phase B / R4: shrink the textures embedded in a GLB (used for the distant
## town buildings, which are only seen from far away through the windows).
## Run: godot --headless --path net-sim-3d -s res://tools/downscale_glb_textures.gd -- <res://file.glb> <max_px>
## Images larger than max_px on either side are resized (Lanczos) and re-encoded
## in their original format; the binary chunk is rebuilt without the old bytes.
## The GLB is overwritten in place, so keep a copy of the original first.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("usage: -- <res://file.glb> <max_px>")
		quit(1)
		return
	quit(_run(args[0], int(args[1])))


func _run(path: String, max_px: int) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20 or bytes.decode_u32(0) != 0x46546C67:
		push_error("not a GLB: " + path)
		return 1
	var json_len := bytes.decode_u32(12)
	var gltf: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	var bin_start := 20 + json_len + 8
	var bin := bytes.slice(bin_start, bin_start + bytes.decode_u32(20 + json_len))
	var views: Array = gltf.bufferViews
	var replaced := {}
	var resized := 0
	for image: Dictionary in gltf.get("images", []):
		if not image.has("bufferView"):
			continue
		var view: Dictionary = views[int(image.bufferView)]
		var offset := int(view.get("byteOffset", 0))
		var data := bin.slice(offset, offset + int(view.byteLength))
		var img := Image.new()
		var jpeg := String(image.get("mimeType", "")) == "image/jpeg"
		var err := img.load_jpg_from_buffer(data) if jpeg else img.load_png_from_buffer(data)
		if err != OK or maxi(img.get_width(), img.get_height()) <= max_px:
			continue
		var scale := float(max_px) / maxi(img.get_width(), img.get_height())
		img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		replaced[int(image.bufferView)] = img.save_jpg_to_buffer(0.85) if jpeg else img.save_png_to_buffer()
		resized += 1
	# Rebuild the binary chunk, 4-byte aligned, with the new image bytes.
	var out := PackedByteArray()
	for i in views.size():
		var view: Dictionary = views[i]
		var offset := int(view.get("byteOffset", 0))
		var chunk: PackedByteArray = replaced.get(i, bin.slice(offset, offset + int(view.byteLength)))
		while out.size() % 4 != 0:
			out.append(0)
		view.byteOffset = out.size()
		view.byteLength = chunk.size()
		out.append_array(chunk)
	while out.size() % 4 != 0:
		out.append(0)
	gltf.buffers = [{"byteLength": out.size()}]
	var json_bytes := JSON.stringify(gltf).to_utf8_buffer()
	while json_bytes.size() % 4 != 0:
		json_bytes.append(0x20)
	var glb := PackedByteArray()
	glb.resize(12)
	glb.encode_u32(0, 0x46546C67)
	glb.encode_u32(4, 2)
	glb.encode_u32(8, 12 + 8 + json_bytes.size() + 8 + out.size())
	var head := PackedByteArray()
	head.resize(8)
	head.encode_u32(0, json_bytes.size())
	head.encode_u32(4, 0x4E4F534A)
	glb.append_array(head)
	glb.append_array(json_bytes)
	head.encode_u32(0, out.size())
	head.encode_u32(4, 0x004E4942)
	glb.append_array(head)
	glb.append_array(out)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(glb)
	file.close()
	print("DOWNSCALED ", path, " images=", resized, " bytes ", bytes.size(), " -> ", glb.size())
	return 0
