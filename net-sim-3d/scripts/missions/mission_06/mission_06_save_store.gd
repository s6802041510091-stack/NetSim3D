class_name Mission06SaveStore
extends RefCounted

## Saves Mission 6 progress as JSON in user:// (desktop and Web export —
## in the browser user:// lives in IndexedDB). Same approach as Mission01SaveStore;
## when the project gets a shared save system, use Mission06State.to_dict()/from_dict().

const DEFAULT_PATH := "user://netsim3d/mission_06_save.json"

## Tests point this somewhere else so they never touch real progress.
static var save_path: String = DEFAULT_PATH


static func save(state: Mission06State) -> bool:
	var dir := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Mission 6: cannot write save file %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(state.to_dict(), "\t"))
	file.close()
	return true


## Fills `state` from the save file. Returns false (fresh state) when there is
## no save yet or it cannot be read.
static func load_into(state: Mission06State, data: Mission06Data) -> bool:
	if not FileAccess.file_exists(save_path):
		state.reset(data)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_warning("Mission 6: save file is damaged, starting fresh")
		state.reset(data)
		return false
	state.from_dict(parsed, data)
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func clear() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
