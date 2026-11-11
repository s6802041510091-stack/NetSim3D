extends Node
class_name GameLocale

static func text(source: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var service := tree.root.get_node_or_null("L10n") if tree else null
	return service.t(source) if service else source

signal language_changed
var locale := "th"
var preferences_path := SavePaths.file("language.cfg")
var _catalog: Dictionary = {}
var _phrases: Array[String] = []
var _patterns: Array[Dictionary] = []
var _cache: Dictionary = {}
var _watched: Array[Dictionary] = []
var _config := ConfigFile.new()
var _thai := RegEx.create_from_string("[ก-๙]")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10000
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en.json"))
	if data is Dictionary:
		for key: String in data:
			_add(key, str(data[key]))
			if key.contains("|"):
				var th := key.split("|", true, 1)
				var en := str(data[key]).split("|", true, 1)
				if en.size() == 2:
					_add(th[0], en[0])
					_add(th[1], en[1])
	_phrases.assign(_catalog.keys())
	_phrases.sort_custom(func(a: String, b: String): return a.length() > b.length())
	_patterns.sort_custom(func(a: Dictionary, b: Dictionary): return a.length > b.length)
	_config.load(preferences_path)
	var saved := str(_config.get_value("interface", "language", "th"))
	locale = saved if saved in ["th", "en"] else "th"
	TranslationServer.set_locale(locale)
	get_tree().node_added.connect(_watch)

func _add(source: String, english: String) -> void:
	var key := _normalize(source)
	_catalog[key] = english
	if key.contains("%"):
		var regex := RegEx.new()
		var expression := "^"
		var output := ""
		var placeholder := RegEx.create_from_string("%[-+0-9.]*[dsf]")
		var at := 0
		var index := 0
		for found in placeholder.search_all(key):
			expression += _escape(key.substr(at, found.get_start() - at)) + "([\\s\\S]*?)"
			at = found.get_end()
			index += 1
		expression += _escape(key.substr(at)) + "$"
		if index > 0 and regex.compile(expression) == OK:
			at = 0
			index = 0
			for found in placeholder.search_all(english):
				output += english.substr(at, found.get_start() - at) + "{arg%d}" % index
				at = found.get_end()
				index += 1
			output += english.substr(at)
			output = output.replace("%%", "%")
			_patterns.append({"regex": regex, "output": output, "length": key.length()})

func _escape(value: String) -> String:
	value = value.replace("%%", "%")
	var result := ""
	for c in value:
		result += ("\\" if c in "\\.^$|?*+()[]{}" else "") + c
	return result

func _normalize(value: String) -> String:
	return RegEx.create_from_string("[ \\t]+").sub(value.replace(" ", " ").replace("⁠", ""), " ", true)

func t(source: String) -> String:
	if locale == "th" or source == "" or _thai.search(source) == null:
		return source
	if _cache.has(source):
		return _cache[source]
	var key := _normalize(source)
	# DialogueBox renders **emphasis** as BBCode before assigning the subtitle.
	var rich := RegEx.create_from_string("\\[b\\]\\[color=#[0-9a-fA-F]+\\]([\\s\\S]*?)\\[/color\\]\\[/b\\]")
	var marked := rich.sub(key, "**$1**", true)
	var output := _translate_plain(marked)
	if marked != key:
		var emphasis := RegEx.create_from_string("\\*\\*([\\s\\S]*?)\\*\\*")
		output = emphasis.sub(output, "[b][color=#ffc733]$1[/color][/b]", true)
	if _cache.size() > 4000:
		_cache.clear()
	_cache[source] = output
	return output

func _translate_plain(key: String) -> String:
	if _catalog.has(key):
		return _catalog[key]
	for item in _patterns:
		var found: RegExMatch = item.regex.search(key)
		if found:
			var output: String = item.output
			for index in range(1, found.get_group_count() + 1):
				output = output.replace("{arg%d}" % (index - 1), _translate_plain(found.get_string(index)))
			return output
	var result := key
	for phrase in _phrases:
		if not phrase.contains("%") and result.contains(phrase):
			result = result.replace(phrase, _catalog[phrase])
	return result

func set_locale(value: String, persist := true) -> void:
	if not value in ["th", "en"]:
		return
	locale = value
	_cache.clear()
	TranslationServer.set_locale(value)
	if persist:
		_config.set_value("interface", "language", value)
		DirAccess.make_dir_recursive_absolute(preferences_path.get_base_dir())
		_config.save(preferences_path)
	_refresh()
	language_changed.emit()

func _watch(node: Node) -> void:
	if node is Label or (node is Button and not node is OptionButton) or node is RichTextLabel or node is Label3D:
		_track(node, "text")
	if node is OptionButton or node is PopupMenu:
		_watched.append({"node": weakref(node), "property": "items", "source": [], "last": []})
	if node is Control:
		_track(node, "tooltip_text")
	if node is LineEdit or node is TextEdit:
		_track(node, "placeholder_text")
	if node is Window:
		_track(node, "title")

func _track(node: Node, property: String) -> void:
	var source := str(node.get(property))
	var rendered := t(source)
	_watched.append({"node": weakref(node), "property": property, "source": source, "last": rendered})
	if rendered != source:
		node.set(property, rendered)

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	for index in range(_watched.size() - 1, -1, -1):
		var entry := _watched[index]
		var node: Node = entry.node.get_ref()
		if node == null:
			_watched.remove_at(index)
			continue
		if entry.property == "items":
			_refresh_items(node, entry)
			continue
		var current := str(node.get(entry.property))
		if current != entry.last:
			entry.source = current
		var rendered := t(entry.source)
		if rendered != current:
			node.set(entry.property, rendered)
		entry.last = rendered

func _refresh_items(node: Node, entry: Dictionary) -> void:
	var count: int = node.item_count
	entry.source.resize(count)
	entry.last.resize(count)
	for index in range(count):
		var current: String = node.get_item_text(index)
		if entry.last[index] != current:
			entry.source[index] = current
		var rendered := t(str(entry.source[index]))
		if rendered != current:
			node.set_item_text(index, rendered)
		entry.last[index] = rendered
