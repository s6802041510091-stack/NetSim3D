class_name GameProgress
extends RefCounted

## Per-level results on this device: best score, attempts and the last result.
## Stored as progress.json in the SavePaths folder (project .saves/ in the
## editor, browser storage on the Web). This file drives the menu (stars,
## unlocking) and the progress page. On the NetSim website, ServerSync also sends
## every attempt to the class and, at start, replaces this file with the
## logged-in student's results from the server (replace_all).
##
## Unlocking: level 1 is always open; a level opens when the previous BUILT level
## was passed (best score >= MissionScore.PASS_SCORE). Levels still under
## construction are skipped so the chain keeps working while they are built.

const LEVEL_COUNT := 6
const FILE_NAME := "progress.json"
## Attempts kept per level for the progress dashboard (oldest dropped first).
const HISTORY_LIMIT := 30
const HISTORY_KEYS := ["total", "stars", "passed", "correctness", "process", "time", "elapsed_sec", "decisions_correct", "decisions_total", "mistakes", "finished_at", "step_times", "mistake_log"]

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


## Finished attempts of `level`, oldest first. Saves from before the log was
## added (2026-11-18) only have their last attempt.
static func history(level: int) -> Array:
	var record := level_record(level)
	var attempt_log: Variant = record.get("history")
	if attempt_log is Array and not attempt_log.is_empty():
		return attempt_log
	var last: Variant = record.get("last")
	return [last] if last is Dictionary else []


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
	# Short per-attempt log for the progress dashboard (newest last).
	var attempt_log: Array = record.get("history", []) if record.get("history", []) is Array else []
	var entry := {}
	for key in HISTORY_KEYS:
		entry[key] = result.get(key)
	attempt_log.append(entry)
	record["history"] = attempt_log.slice(maxi(attempt_log.size() - HISTORY_LIMIT, 0))
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
	# On the NetSim website: send the attempt to the student's class (server_sync.gd).
	var tree := Engine.get_main_loop() as SceneTree
	var sync := tree.root.get_node_or_null("ServerSync") if tree else null
	if sync:
		sync.submit_attempt(level, result)
	return record


## Replaces every level's record (the logged-in student's results from the website).
static func replace_all(all: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Progress could not be saved: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(all, "\t"))
	file.close()


static func clear() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
