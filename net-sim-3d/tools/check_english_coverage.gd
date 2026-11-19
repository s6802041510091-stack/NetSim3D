extends SceneTree

## English mode coverage: collects every Thai string literal in scripts,
## missions and scenes (.gd .tscn .tres .json) and runs it through the game's
## own translator (L10n, localization/en.json) in English mode. Anything that
## still contains Thai after translation is listed in the report.
##   godot --headless --path net-sim-3d -s res://tools/check_english_coverage.gd
## Report: user://english_coverage.txt (path printed at the end).
## Exit code 1 when something is untranslated.

const ROOTS := ["res://scripts", "res://missions", "res://scenes"]
const EXTENSIONS := ["gd", "tscn", "tres", "json"]
## Thai on purpose in English mode: the language button shows its own name,
## the translator's Thai-letter pattern, and a file path that is never shown.
const KEEP_THAI := ["ไทย", "[ก-๙]", "Preview/โถงทางเดิน/corridor-concept-v2.png"]

var _thai := RegEx.create_from_string("[ก-๙]")
var _literal := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var l10n := root.get_node("L10n")
	var previous: String = l10n.locale
	l10n.set_locale("en", false)
	var report := PackedStringArray()
	var missing_total := 0
	var seen := {}
	var files := []
	for dir in ROOTS:
		_collect(dir, files)
	files.sort()
	for path: String in files:
		var missing := PackedStringArray()
		for text in _strings(path):
			if seen.has(text) or text in KEEP_THAI:
				continue
			seen[text] = true
			var english: String = l10n.t(text)
			if _thai.search(english) != null:
				missing.append(text)
		if not missing.is_empty():
			report.append("## %s (%d)" % [path, missing.size()])
			for text in missing:
				report.append(JSON.stringify(text))
			missing_total += missing.size()
	l10n.set_locale(previous, false)
	var out := OS.get_user_data_dir().path_join("english_coverage.txt")
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string("\n".join(report) + "\n")
	file.close()
	print("ENGLISH_COVERAGE strings=%d untranslated=%d report=%s" % [seen.size(), missing_total, out])
	quit(1 if missing_total > 0 else 0)


func _collect(dir: String, files: Array) -> void:
	for name in DirAccess.get_files_at(dir):
		if name.get_extension() in EXTENSIONS:
			files.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), files)


## Thai string literals of a file (GDScript comments skipped).
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
