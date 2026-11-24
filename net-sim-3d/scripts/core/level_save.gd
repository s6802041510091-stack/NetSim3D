class_name LevelSave
extends RefCounted

## Mid-level save (teacher's request 2026-11-24): leave a level part-way
## ("บันทึกและออก" on the pause page, closing the window, or the 30 s autosave)
## and "เล่นต่อ" on the home page comes back to it.
##
## One file per level in SavePaths (level_<n>.save), written with var_to_str
## so Godot types (PackedStringArray, typed arrays, enums) come back as they
## were. It holds:
##   level, version, saved_unix
##   player   {pos: Vector3, yaw, pitch}
##   mission  what the level's controller returns from save_snapshot()
##
## The game resumes at the start of the step the player was on: everything
## finished before it (answers, mistakes, results, the score timer) is kept;
## work half-done inside that step (an open window, a cable half plugged)
## starts that step again. Each controller decides what that means for its
## level in restore_snapshot(). The file is removed when the level ends
## (summary) or is started again from the beginning.

const VERSION := 1

## Tests can point saves somewhere else.
static var folder := ""


static func path(level: int) -> String:
	var dir := folder if folder != "" else SavePaths.dir()
	return dir.path_join("level_%d.save" % level)


static func exists(level: int) -> bool:
	return level > 0 and FileAccess.file_exists(path(level))


static func write(level: int, snapshot: Dictionary) -> bool:
	var file_path := path(level)
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var data := snapshot.duplicate()
	data["level"] = level
	data["version"] = VERSION
	data["saved_unix"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("Level %d: cannot write save (%s)" % [level, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(var_to_str(data))
	file.close()
	return true


## The saved snapshot, or {} when there is none or it cannot be read.
static func read(level: int) -> Dictionary:
	if not exists(level):
		return {}
	var parsed: Variant = str_to_var(FileAccess.get_file_as_string(path(level)))
	if not parsed is Dictionary or int((parsed as Dictionary).get("level", 0)) != level or int((parsed as Dictionary).get("version", 0)) != VERSION:
		push_warning("Level %d: save file unreadable, starting fresh" % level)
		return {}
	return parsed


static func clear(level: int) -> void:
	if exists(level):
		DirAccess.remove_absolute(path(level))


## The script variables of a state object (no node / resource references).
static func pack(object: Object) -> Dictionary:
	var out := {}
	if object == null:
		return out
	for prop in object.get_property_list():
		if not int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value: Variant = object.get(prop["name"])
		if _plain(value):
			out[prop["name"]] = _copy(value)
	return out


## Puts values from pack() back (unknown names are ignored).
static func unpack(object: Object, values: Dictionary) -> void:
	if object == null:
		return
	var known := {}
	for prop in object.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			known[prop["name"]] = true
	for key: String in values:
		if known.has(key):
			object.set(key, _copy(values[key]))


static func _plain(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			for item in value:
				if not _plain(item):
					return false
		TYPE_DICTIONARY:
			for key in value:
				if not _plain(key) or not _plain(value[key]):
					return false
	return true


static func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


## Where the player stands and looks.
static func player_snapshot(player: Node3D) -> Dictionary:
	if player == null:
		return {}
	var camera := player.get("camera") as Node3D
	return {"pos": player.global_position, "yaw": player.rotation.y, "pitch": camera.rotation.x if camera else 0.0}


static func place_player(player: Node3D, snap: Dictionary) -> void:
	if player == null or snap.is_empty():
		return
	player.global_position = snap.get("pos", player.global_position)
	player.rotation.y = float(snap.get("yaw", player.rotation.y))
	var camera := player.get("camera") as Node3D
	if camera:
		camera.rotation.x = float(snap.get("pitch", 0.0))
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
