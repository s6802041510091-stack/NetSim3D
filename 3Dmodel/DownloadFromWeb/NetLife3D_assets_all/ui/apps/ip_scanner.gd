extends Control
## Simulated "Advanced IP Scanner" (stage 5).
## Steps the player performs: type the IP range -> Scan -> classify each device in the "Type" column
## -> "Save to Network Inventory". Inventory goes to NetSim.inventory (used by Veyon in stage 6).
## Logged actions: scan_started / scan_invalid_range / scan_finished / device_classified / inventory_saved

const TYPES := ["—", "Student PC", "Teacher PC", "Router", "Printer", "Other"]
const TYPE_KEYS := ["", "student", "teacher", "router", "printer", "other"]

var range_edit: LineEdit
var tree: Tree
var progress: ProgressBar
var status_label: Label
var save_button: Button
var scan_button: Button
var _scanning := false
var _found: Array[Dictionary] = []


func _ready() -> void:
	var v := UIKit.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	# menu
	var menu := UIKit.hbox(16)
	for m in ["File", "View", "Settings", "Help"]:
		menu.add_child(UIKit.label(m, 13))
	v.add_child(UIKit.margin(menu, 6))
	# toolbar
	var tb := UIKit.hbox(10)
	scan_button = UIKit.button("  ▶  Scan  ", true)
	scan_button.add_theme_stylebox_override("normal", UIKit.box(Color("2e9d47"), Color.TRANSPARENT, 4, 1, 8))
	scan_button.add_theme_stylebox_override("hover", UIKit.box(Color("35ad51"), Color.TRANSPARENT, 4, 1, 8))
	scan_button.add_theme_font_size_override("font_size", 16)
	scan_button.pressed.connect(start_scan)
	tb.add_child(scan_button)
	var pause := UIKit.button(" ❚❚ ")
	pause.disabled = true
	tb.add_child(pause)
	var sep := VSeparator.new()
	tb.add_child(sep)
	tb.add_child(UIKit.label("IP", 13, UIKit.TEXT_DIM))
	range_edit = LineEdit.new()
	range_edit.placeholder_text = "Example: 192.168.0.1-100, 192.168.0.200"
	range_edit.custom_minimum_size.x = 380
	range_edit.text_submitted.connect(func(_t): start_scan())
	tb.add_child(range_edit)
	var search := LineEdit.new()
	search.placeholder_text = "Search"
	search.text_changed.connect(_filter)
	UIKit.expand(search, false)
	tb.add_child(search)
	v.add_child(UIKit.margin(tb, 8))
	# tabs
	var tabs := TabBar.new()
	tabs.add_tab("Results")
	tabs.add_tab("Favorites")
	v.add_child(UIKit.margin(tabs, 0))
	# results table
	tree = Tree.new()
	UIKit.expand(tree)
	tree.columns = 6
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	var titles := ["Status", "Name", "IP", "Manufacturer", "MAC address", "Type (classify)"]
	var widths := [70, 170, 130, 160, 170, 150]
	for i in titles.size():
		tree.set_column_title(i, titles[i])
		tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
		tree.set_column_custom_minimum_width(i, widths[i])
		tree.set_column_expand(i, i in [1, 3])
	tree.item_edited.connect(_on_item_edited)
	tree.create_item()
	v.add_child(tree)
	# footer
	var foot := UIKit.hbox(12)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(200, 16)
	progress.show_percentage = false
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(progress)
	status_label = UIKit.label("Ready", 12, UIKit.TEXT_DIM)
	UIKit.expand(status_label, false)
	foot.add_child(status_label)
	save_button = UIKit.button("Save student PCs to Network Inventory", true)
	save_button.disabled = true
	save_button.pressed.connect(save_inventory)
	foot.add_child(save_button)
	v.add_child(UIKit.margin(foot, 8))


## Parse "a.b.c.d-e", "a.b.c.d - a.b.c.e", "a.b.c.0/24" or a single IP. Returns [from, to] or [].
static func parse_range(text: String) -> PackedStringArray:
	var t := text.strip_edges().replace(" ", "")
	if t.contains("/"):
		var p := t.split("/")
		if p.size() == 2 and p[1] == "24" and NetSim.ip_to_int(p[0]) >= 0:
			var base := p[0].substr(0, p[0].rfind("."))
			return PackedStringArray([base + ".1", base + ".254"])
		return PackedStringArray()
	if t.contains("-"):
		var p := t.split("-")
		if p.size() != 2 or NetSim.ip_to_int(p[0]) < 0:
			return PackedStringArray()
		var to := p[1]
		if to.is_valid_int():
			to = p[0].substr(0, p[0].rfind(".")) + "." + to
		if NetSim.ip_to_int(to) < NetSim.ip_to_int(p[0]):
			return PackedStringArray()
		return PackedStringArray([p[0], to])
	if NetSim.ip_to_int(t) >= 0:
		return PackedStringArray([t, t])
	return PackedStringArray()


func start_scan() -> void:
	if _scanning:
		return
	var r := parse_range(range_edit.text)
	if r.is_empty():
		status_label.text = "Invalid IP address range"
		status_label.add_theme_color_override("font_color", UIKit.BAD)
		NetSim.log_action("scan_invalid_range", {"text": range_edit.text})
		return
	status_label.remove_theme_color_override("font_color")
	var covers_subnet := NetSim.ip_to_int(r[0]) <= NetSim.ip_to_int(NetSim.SUBNET + ".1") \
		and NetSim.ip_to_int(r[1]) >= NetSim.ip_to_int(NetSim.SUBNET + ".254")
	NetSim.log_action("scan_started", {"text": range_edit.text, "from": r[0], "to": r[1], "covers_subnet": covers_subnet})
	_scanning = true
	scan_button.disabled = true
	save_button.disabled = true
	tree.clear()
	tree.create_item()
	_found = NetSim.scan(r[0], r[1])
	var total := NetSim.ip_to_int(r[1]) - NetSim.ip_to_int(r[0]) + 1
	var steps := 30
	var shown := 0
	for s in steps + 1:
		if not is_inside_tree():
			return
		progress.value = 100.0 * s / steps
		status_label.text = "Scanning... %d / %d" % [int(total * s / float(steps)), total]
		var upto := int(ceil(_found.size() * s / float(steps)))
		while shown < upto:
			_add_row(_found[shown])
			shown += 1
		await get_tree().create_timer(0.08).timeout
	_scanning = false
	scan_button.disabled = false
	save_button.disabled = _found.is_empty()
	status_label.text = "%d alive, 0 dead, %d unknown" % [_found.size(), total - _found.size()]
	NetSim.log_action("scan_finished", {"found": _found.size(), "scanned": total})


func _add_row(d: Dictionary) -> void:
	var it := tree.create_item()
	it.set_text(0, "●")
	it.set_custom_color(0, UIKit.OK)
	it.set_text(1, d.name)
	it.set_text(2, d.ip)
	it.set_text(3, d.vendor)
	it.set_text(4, d.mac)
	it.set_cell_mode(5, TreeItem.CELL_MODE_RANGE)
	it.set_text(5, ",".join(TYPES))
	it.set_range(5, 0)
	it.set_editable(5, true)
	it.set_metadata(0, d)


func _filter(q: String) -> void:
	q = q.strip_edges().to_lower()
	var it := tree.get_root().get_first_child()
	while it:
		var d: Dictionary = it.get_metadata(0)
		it.visible = q == "" or String(d.name).to_lower().contains(q) or String(d.ip).contains(q) or String(d.mac).to_lower().contains(q)
		it = it.get_next()


func _on_item_edited() -> void:
	var it := tree.get_edited()
	if it == null:
		return
	var d: Dictionary = it.get_metadata(0)
	var k: String = TYPE_KEYS[int(it.get_range(5))]
	NetSim.log_action("device_classified", {"ip": d.ip, "name": d.name, "as": k, "correct": k == d.type})


## Set the classification from code (tests / auto-fill for teachers).
func classify(ip: String, type_key: String) -> void:
	var it := tree.get_root().get_first_child()
	while it:
		if (it.get_metadata(0) as Dictionary).ip == ip:
			it.set_range(5, TYPE_KEYS.find(type_key))
		it = it.get_next()


func save_inventory() -> void:
	var saved: Array[Dictionary] = []
	var wrong := 0
	var it := tree.get_root().get_first_child()
	while it:
		var d: Dictionary = it.get_metadata(0)
		if TYPE_KEYS[int(it.get_range(5))] == "student":
			saved.append({"name": d.name, "ip": d.ip, "mac": d.mac})
			if d.type != "student":
				wrong += 1
		it = it.get_next()
	var expected := 0
	for d in NetSim.students():
		if d.online:
			expected += 1
	NetSim.inventory = saved
	var correct := saved.size() - wrong
	NetSim.log_action("inventory_saved", {"saved": saved.size(), "correct": correct, "wrong": wrong,
		"missing": expected - correct, "expected": expected})
	status_label.text = "Saved %d computers to Network Inventory" % saved.size()
	NetSim.state_changed.emit()
