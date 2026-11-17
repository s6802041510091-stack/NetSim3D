extends SceneTree
## Phase B / R3: make every character and hand GLB use ONE copy of the shared
## MakeHuman textures (skin, eyes, eyebrows, hair, shirt, shoes) instead of
## embedding the same 2048px PNG in every model. GDScript port of the former
## share_character_textures.cjs, so it runs with the project's Godot (no Node).
##
## Run from the repository root:
##   godot --headless --path net-sim-3d -s res://tools/share_character_textures.gd
## Re-run after re-exporting any of these GLBs from Blender (the exporters
## embed the images again), then delete the PNGs Godot had extracted next to
## the GLB (<glb>_<image>.png) so they are not exported with the game.
##
## For each GLB, embedded images whose name matches a shared texture are written
## once to assets/models/shared_textures/ (if not there yet) and replaced by an
## external "uri"; the binary chunk is then compacted. Godot's glTF importer
## resolves the uri to the same res:// texture, so the export carries one
## texture instead of one per model. An image is shared only when its bytes are
## identical to the shared file; otherwise the tool stops with an error.

const MODELS := "res://assets/models/"
const SHARED_DIR := MODELS + "shared_textures/"
const SHARED := {
	"young_lightskinned_male_diffuse3": "skin_young_lightskinned_male_diffuse3.png",
	"young_lightskinned_female_diffuse3": "skin_young_lightskinned_female_diffuse3.png",
	"ponytail01_diffuse": "hair_ponytail01_diffuse.png",
	"short04_diffuse": "shirt_short04_diffuse.png",
	"shoes04_diffuse": "shoes04_diffuse.png",
	"shoes04_normal": "shoes04_normal.png",
	"brown_eye": "eye_brown.png",
	"eyebrow001": "eyebrow001.png",
}
const GLBS := [
	"it_support_male_180cm.glb",
	"it_support_supervisor_male_170cm.glb",
	"teacher_male_khaki_180cm.glb",
	"teacher_female_khaki_160cm.glb",
	"player_right_arm.glb",
	"player_right_arm_relaxed.glb",
	"tools/hand_cable_stripper.glb",
	"tools/hand_cable_tester.glb",
	"tools/hand_crimping_tool.glb",
	"students/student_female_bob_cut.glb",
	"students/student_female_layer_cut.glb",
	"students/student_female_wendy_cut.glb",
	"students/student_male_mullet.glb",
	"students/student_male_two_block.glb",
	"cleaner/cleaner_female_apron_160cm.glb",
]
const GLB_MAGIC := 0x46546c67
const JSON_CHUNK := 0x4e4f534a
const BIN_CHUNK := 0x004e4942


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHARED_DIR))
	var failed := false
	for rel: String in GLBS:
		var err := _share(MODELS + rel, rel)
		if err != "":
			push_error(err)
			failed = true
			break
	print("SHARE_TEXTURES_FAILED" if failed else "SHARE_TEXTURES_DONE")
	quit(1 if failed else 0)


func _share(file: String, rel: String) -> String:
	var buf := FileAccess.get_file_as_bytes(file)
	if buf.size() < 20 or buf.decode_u32(0) != GLB_MAGIC:
		return "%s is not a GLB" % rel
	var json_len := buf.decode_u32(12)
	var json: Dictionary = JSON.parse_string(buf.slice(20, 20 + json_len).get_string_from_utf8())
	var bin := PackedByteArray()
	var bin_header := 20 + json_len
	if bin_header < buf.size():
		bin = buf.slice(bin_header + 8, bin_header + 8 + buf.decode_u32(bin_header))
	var views: Array = json.get("bufferViews", [])
	var replaced := 0
	for image: Dictionary in json.get("images", []):
		var shared_name: String = SHARED.get(image.get("name", ""), "")
		if shared_name == "" or not image.has("bufferView"):
			continue
		var view: Dictionary = views[int(image.bufferView)]
		var offset := int(view.get("byteOffset", 0))
		var bytes := bin.slice(offset, offset + int(view.byteLength))
		var target := SHARED_DIR + shared_name
		if not FileAccess.file_exists(target):
			var out := FileAccess.open(target, FileAccess.WRITE)
			out.store_buffer(bytes)
			out.close()
		# Refuse to share images that only happen to have the same name.
		if _sha256(FileAccess.get_file_as_bytes(target)) != _sha256(bytes):
			return "%s: %s differs from shared %s" % [rel, image.name, shared_name]
		image.erase("bufferView")
		image.erase("mimeType")
		image["uri"] = _relative(file.get_base_dir(), target)
		replaced += 1
	if replaced == 0:
		print("skip %s (already shared)" % rel)
		return ""
	var new_bin := _compact(json, bin)
	_write_glb(file, json, new_bin)
	print("%s: %d images -> shared, %.2f MB -> %.2f MB" % [rel, replaced, buf.size() / 1048576.0, FileAccess.get_file_as_bytes(file).size() / 1048576.0])
	return ""


## Drop unused bufferViews and rebuild the binary chunk without their bytes.
func _compact(json: Dictionary, bin: PackedByteArray) -> PackedByteArray:
	var used := {}
	for a: Dictionary in json.get("accessors", []):
		if a.has("bufferView"):
			used[int(a.bufferView)] = true
	for i: Dictionary in json.get("images", []):
		if i.has("bufferView"):
			used[int(i.bufferView)] = true
	var new_bin := PackedByteArray()
	var new_views := []
	var new_index := {}
	var views: Array = json.get("bufferViews", [])
	for index in views.size():
		if not used.has(index):
			continue
		var view: Dictionary = views[index].duplicate()
		var start := int(view.get("byteOffset", 0))
		var bytes := bin.slice(start, start + int(view.byteLength))
		while new_bin.size() % 4 != 0:
			new_bin.append(0)
		view["byteOffset"] = new_bin.size()
		new_bin.append_array(bytes)
		new_index[index] = new_views.size()
		new_views.append(view)
	json["bufferViews"] = new_views
	for a: Dictionary in json.get("accessors", []):
		if a.has("bufferView"):
			a["bufferView"] = new_index[int(a.bufferView)]
	for i: Dictionary in json.get("images", []):
		if i.has("bufferView"):
			i["bufferView"] = new_index[int(i.bufferView)]
	json["buffers"] = [{"byteLength": new_bin.size()}]
	return new_bin


func _write_glb(file: String, json: Dictionary, bin: PackedByteArray) -> void:
	var json_buf := _to_json(json).to_utf8_buffer()
	while json_buf.size() % 4 != 0:
		json_buf.append(0x20)
	var bin_buf := bin.duplicate()
	while bin_buf.size() % 4 != 0:
		bin_buf.append(0)
	var out := FileAccess.open(file, FileAccess.WRITE)
	out.store_32(GLB_MAGIC)
	out.store_32(2)
	out.store_32(12 + 8 + json_buf.size() + 8 + bin_buf.size())
	out.store_32(json_buf.size())
	out.store_32(JSON_CHUNK)
	out.store_buffer(json_buf)
	out.store_32(bin_buf.size())
	out.store_32(BIN_CHUNK)
	out.store_buffer(bin_buf)
	out.close()


## JSON.stringify writes every number as a float ("6.0"); glTF indices must be
## integers, so whole numbers are written without a fraction.
func _to_json(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var parts := PackedStringArray()
			for key: String in value:
				parts.append(JSON.stringify(key) + ":" + _to_json(value[key]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for item: Variant in value:
				parts.append(_to_json(item))
			return "[" + ",".join(parts) + "]"
		TYPE_FLOAT:
			var f: float = value
			if is_finite(f) and f == floorf(f) and absf(f) < 9.0e15:
				return str(int(f))
			return JSON.stringify(f, "", false, true)
	return JSON.stringify(value)


func _relative(from_dir: String, to_file: String) -> String:
	var a := from_dir.trim_prefix("res://").split("/", false)
	var b := to_file.trim_prefix("res://").split("/", false)
	var common := 0
	while common < a.size() and common < b.size() - 1 and a[common] == b[common]:
		common += 1
	var parts := PackedStringArray()
	for i in a.size() - common:
		parts.append("..")
	for i in range(common, b.size()):
		parts.append(b[i])
	return "/".join(parts)


func _sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
