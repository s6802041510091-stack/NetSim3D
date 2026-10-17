class_name Mission01SaveStore
extends RefCounted

## Saves Mission 1 progress as JSON in user:// (works on desktop and in the
## Web export, where user:// is kept in the browser's IndexedDB).
## The project has no shared save system yet; when one is added, call
## Mission01State.to_dict()/from_dict() from it and stop using this class.

const DEFAULT_PATH := "user://netsim3d/mission_01_save.json"

## Tests and other profiles can point this somewhere else.
static var save_path: String = DEFAULT_PATH


static func save(state: Mission01State) -> bool:
	var dir := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Mission 1: cannot write save file %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(state.to_dict(), "\t"))
	file.close()
	return true


## Fills `state` from the save file. Returns false (and leaves a fresh state)
## when there is no save yet or it cannot be read.
static func load_into(state: Mission01State, data: Mission01Data) -> bool:
	if not FileAccess.file_exists(save_path):
		state.reset(data)
		return false
	var text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Mission 1: save file is damaged, starting fresh")
		state.reset(data)
		return false
	state.from_dict(parsed, data)
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func clear() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
