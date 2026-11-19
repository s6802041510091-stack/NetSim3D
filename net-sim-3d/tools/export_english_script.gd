extends SceneTree

## Exports the game's English script for reading: every Thai string in the
## code and mission data with its English translation (through the game's own
## translator, L10n), grouped by level, plus the sentence patterns the game
## builds while playing (localization/en_patterns.json).
##   godot --headless --path net-sim-3d -s res://tools/export_english_script.gd -- <out.json>

const ROOTS := ["res://missions", "res://scripts", "res://scenes"]
const EXTENSIONS := ["gd", "tscn", "tres", "json"]
## Not text the player reads (the translator's own pattern, a file path).
const SKIP := ["[ก-๙]", "Preview/โถงทางเดิน/corridor-concept-v2.png"]

var _thai := RegEx.create_from_string("[ก-๙]")
var _literal := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var l10n := root.get_node("L10n")
	var previous: String = l10n.locale
	l10n.set_locale("en", false)
	var sections := {}
	var order := []
	var seen := {}
	var files := []
	for dir in ROOTS:
		_collect(dir, files)
	files.sort_custom(_file_order)
	for path: String in files:
		var section := _section(path)
		if not sections.has(section):
			sections[section] = []
			order.append(section)
		for text in _strings(path):
			if seen.has(text) or text in SKIP:
				continue
			seen[text] = true
			sections[section].append(_entry(l10n, text, path))
	# Sentences assembled while playing.
	var patterns: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en_patterns.json"))
	var built := []
	if patterns is Dictionary:
		for key: String in patterns:
			if _thai.search(key) != null and not seen.has(key):
				built.append({"th": key, "en": String(patterns[key]), "file": "localization/en_patterns.json"})
	sections["patterns"] = built
	order.append("patterns")
	l10n.set_locale(previous, false)
	var out := []
	for key in order:
		if not sections[key].is_empty():
			out.append({"id": key, "entries": sections[key]})
	var path := OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	var total := 0
	for s in out:
		total += s.entries.size()
	print("ENGLISH_SCRIPT sections=%d entries=%d -> %s" % [out.size(), total, path])
	quit()


func _entry(l10n: Node, text: String, path: String) -> Dictionary:
	var entry := {"th": text, "en": l10n.t(text), "file": path.trim_prefix("res://")}
	# "Speaker|line": dialogue (the speaker name is translated on its own).
	var parts := text.split("|", true, 1)
	if parts.size() == 2 and _thai.search(parts[1]) != null:
		var english: String = entry.en
		var en_parts := english.split("|", true, 1)
		entry["speaker_th"] = parts[0]
		entry["speaker"] = en_parts[0] if en_parts.size() == 2 else l10n.t(parts[0])
		entry["th"] = parts[1]
		entry["en"] = en_parts[1] if en_parts.size() == 2 else l10n.t(parts[1])
	return entry


func _section(path: String) -> String:
	var m := RegEx.create_from_string("missions/mission_0(\\d)").search(path)
	if m:
		return "level" + m.get_string(1)
	if path.contains("/npc/staff_room"):
		return "staffroom"
	if path.contains("/computer/"):
		return "computer"
	if path.contains("game_flow") or path.contains("/ui/") or path.contains("/core/"):
		return "menu"
	return "other"


## Levels first (controller, then data, then the rest), then the menu, the
## in-game computer, the staff room and anything else.
func _file_order(a: String, b: String) -> bool:
	var ka := _rank(a)
	var kb := _rank(b)
	return ka < kb if ka != kb else a < b


func _rank(path: String) -> String:
	var section := _section(path)
	var group: String = {"level1": "1", "level2": "2", "level3": "3", "level4": "4", "level5": "5", "level6": "6", "menu": "7", "computer": "8", "staffroom": "9"}.get(section, "z")
	var kind := "1" if path.contains("controller") else ("2" if path.contains("/data/") or path.ends_with("_data.gd") else "3")
	return group + kind


func _collect(dir: String, files: Array) -> void:
	for name in DirAccess.get_files_at(dir):
		if name.get_extension() in EXTENSIONS:
			files.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), files)


func _strings(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var gd := path.get_extension() == "gd"
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if gd and line.strip_edges().begins_with("#"):
			continue
		for m in _literal.search_all(line):
			var text := m.get_string(1).c_unescape()
			if _thai.search(text) != null:
				found.append(text)
	return found
