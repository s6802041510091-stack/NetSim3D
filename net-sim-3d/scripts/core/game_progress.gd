class_name GameProgress
extends RefCounted

## Per-level results on this device: best score, attempts and the last result.
## Stored as progress.json in the SavePaths folder (project .saves/ in the
## editor, browser storage on the Web). Accounts and the teacher report will come
## from Supabase later; this file only drives the menu (stars, unlocking).
##
## Unlocking: level 1 is always open; a level opens when the previous BUILT level
## was passed (best score >= MissionScore.PASS_SCORE). Levels still under
## construction are skipped so the chain keeps working while they are built.

const LEVEL_COUNT := 6
const FILE_NAME := "progress.json"

## Tests point this somewhere else so they never touch real progress.
static var save_path: String = SavePaths.file(FILE_NAME)


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return parsed if parsed is Dictionary else {}


static func level_record(level: int) -> Dictionary:
	var record: Variant = load_all().get(str(level), {})
	return record if record is Dictionary else {}


static func best_score(level: int) -> int:
	return int(level_record(level).get("best_total", -1))


static func is_passed(level: int) -> bool:
	return best_score(level) >= MissionScore.PASS_SCORE


static func is_unlocked(level: int, built_levels: Array) -> bool:
	if level <= 1:
		return true
	for previous in range(level - 1, 0, -1):
		if previous in built_levels:
			return is_passed(previous)
	return true


## Records one finished attempt and returns the updated record.
static func record_attempt(level: int, score: MissionScore, extra: Dictionary = {}) -> Dictionary:
	var all := load_all()
	var record: Dictionary = all.get(str(level), {}) if all.get(str(level), {}) is Dictionary else {}
	var result := score.to_dict()
	result.merge(extra)
	result["finished_at"] = Time.get_datetime_string_from_system()
	record["attempts"] = int(record.get("attempts", 0)) + 1
	record["last"] = result
	if score.total() > int(record.get("best_total", -1)):
		record["best_total"] = score.total()
		record["best_stars"] = score.stars()
	all[str(level)] = record
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Progress could not be saved: " + error_string(FileAccess.get_open_error()))
	else:
		file.store_string(JSON.stringify(all, "\t"))
		file.close()
	return record


static func clear() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
