class_name SavePaths
extends RefCounted

## Where NetSim3D keeps local progress (mission saves, menu settings).
## - Run from the Godot editor: <project>/.saves/ (git-ignored), so development
##   saves stay with the project instead of AppData on drive C.
## - Exported builds: user://netsim3d/. On the Web this is the player's
##   browser storage (IndexedDB), so it survives a page refresh.

const EXPORTED_DIR := "user://netsim3d"
const EDITOR_DIR := "res://.saves"


static func dir() -> String:
	if not OS.has_feature("editor"):
		return EXPORTED_DIR
	var path := ProjectSettings.globalize_path(EDITOR_DIR)
	# Keep the editor from importing save files as project resources.
	if not FileAccess.file_exists(path.path_join(".gdignore")):
		DirAccess.make_dir_recursive_absolute(path)
		var marker := FileAccess.open(path.path_join(".gdignore"), FileAccess.WRITE)
		if marker:
			marker.close()
	return path


static func file(file_name: String) -> String:
	return dir().path_join(file_name)
