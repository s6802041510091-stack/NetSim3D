extends Control
## Simulated Veyon Configurator (stage 6, steps 1-4 + security settings).
## Pages: General (authentication method) · Service (service check, firewall exception)
##        Locations & computers (create "Computer Lab 1", import from Network Inventory)
##        Authentication keys (create key pair, distribute public key)
## Logged: veyon_page / veyon_auth_method / veyon_service_checked / veyon_firewall_exception /
##         veyon_location_created / veyon_location_removed / veyon_computers_added / veyon_computer_removed /
##         veyon_key_created / veyon_key_deleted / veyon_key_distributed / veyon_applied

const PAGES := ["General", "Service", "Locations & computers", "Authentication keys"]
const PAGE_GLYPH := ["⚙", "▶", "▦", "🔑"]

var _nav: ItemList
var _page_holder: Control
var _status: Label
var _loc_list: ItemList
var _comp_tree: Tree
var _keys_tree: Tree
var _overlay: Control
var _current := ""


func _ready() -> void:
	var v := UIKit.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var h := UIKit.hbox(0)
	UIKit.expand(h)
	v.add_child(h)
	_nav = ItemList.new()
	_nav.custom_minimum_size.x = 220
	_nav.add_theme_font_size_override("font_size", 14)
	_nav.add_theme_constant_override("v_separation", 10)
	_nav.add_theme_stylebox_override("panel", UIKit.box(Color("eef3ee"), Color.TRANSPARENT, 0, 0, 8))
	for i in PAGES.size():
		_nav.add_item("  %s   %s" % [PAGE_GLYPH[i], PAGES[i]])
	_nav.item_selected.connect(func(i): show_page(PAGES[i]))
	h.add_child(_nav)
	_page_holder = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_page_holder.add_theme_constant_override("margin_" + side, 16)
	UIKit.expand(_page_holder)
	h.add_child(_page_holder)
	# bottom bar
	var foot := UIKit.hbox(8)
	_status = UIKit.label("", 12, UIKit.TEXT_DIM)
	UIKit.expand(_status, false)
	foot.add_child(_status)
	var apply := UIKit.button("  Apply  ", true)
	apply.pressed.connect(func():
		NetSim.log_action("veyon_applied", _snapshot())
		_set_status("Settings applied successfully.", UIKit.OK))
	foot.add_child(apply)
	var bar := UIKit.panel(Color("f7f7f7"), UIKit.BORDER, 0)
	bar.add_child(UIKit.margin(foot, 8))
	v.add_child(bar)
	_nav.select(0)
	show_page("General")


func show_page(p: String) -> void:
	_current = p
	for c in _page_holder.get_children():
		c.queue_free()
	var page: Control
	match p:
		"General": page = _page_general()
		"Service": page = _page_service()
		"Locations & computers": page = _page_locations()
		"Authentication keys": page = _page_keys()
	_page_holder.add_child(page)
	_nav.select(PAGES.find(p))
	NetSim.log_action("veyon_page", {"page": p})


# ---------------------------------------------------------------- General
func _page_general() -> Control:
	var v := UIKit.vbox(14)
	v.add_child(UIKit.label("General", 20, UIKit.TEXT, true))
	var g := _group("Authentication")
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("Authentication method", 14))
	var opt := OptionButton.new()
	opt.add_item("Logon authentication")
	opt.add_item("Key file authentication")
	opt.select(1 if NetSim.veyon_auth_method == "keyfile" else 0)
	opt.custom_minimum_size.x = 260
	opt.item_selected.connect(func(i):
		NetSim.veyon_auth_method = "keyfile" if i == 1 else "logon"
		NetSim.log_action("veyon_auth_method", {"method": NetSim.veyon_auth_method})
		NetSim.state_changed.emit())
	row.add_child(opt)
	var test := UIKit.button("Test")
	test.pressed.connect(func():
		if NetSim.veyon_auth_method == "keyfile":
			if NetSim.veyon_keys.is_empty():
				_set_status("Key file authentication: no key pair found. Create one on the 'Authentication keys' page.", UIKit.BAD)
			else:
				_set_status("Key file authentication is set up correctly on this computer.", UIKit.OK)
		else:
			_set_status("Logon authentication: every connection will ask for a username and password.", UIKit.WARN))
	row.add_child(test)
	g.get_child(0).add_child(row)
	g.get_child(0).add_child(UIKit.label("Key file authentication uses a key pair: the private key stays on the teacher computer,\nthe public key must be copied to every student computer.", 12, UIKit.TEXT_DIM))
	v.add_child(g)
	var g2 := _group("Network object directory")
	var row2 := UIKit.hbox(10)
	row2.add_child(UIKit.label("Backend", 14))
	var be := OptionButton.new()
	be.add_item("Default (store objects in local configuration)")
	be.custom_minimum_size.x = 380
	row2.add_child(be)
	g2.get_child(0).add_child(row2)
	v.add_child(g2)
	return v


# ---------------------------------------------------------------- Service
func _page_service() -> Control:
	var v := UIKit.vbox(14)
	v.add_child(UIKit.label("Service", 20, UIKit.TEXT, true))
	var g := _group("Veyon Service on this computer")
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("State:", 14))
	row.add_child(UIKit.label("Running", 14, UIKit.OK, true))
	var sp := Control.new()
	UIKit.expand(sp, false)
	row.add_child(sp)
	g.get_child(0).add_child(row)
	var fw := CheckBox.new()
	fw.text = "Enable firewall exception (TCP 11100)"
	fw.button_pressed = NetSim.firewall_veyon_allowed
	fw.toggled.connect(func(on):
		NetSim.firewall_veyon_allowed = on
		NetSim.log_action("veyon_firewall_exception", {"enabled": on, "from": "configurator"})
		NetSim.state_changed.emit())
	g.get_child(0).add_child(fw)
	v.add_child(g)
	var g2 := _group("Student computers")
	var row2 := UIKit.hbox(10)
	row2.add_child(UIKit.label("Check that Veyon Service is running on the student computers.", 13, UIKit.TEXT_DIM))
	var sp2 := Control.new()
	UIKit.expand(sp2, false)
	row2.add_child(sp2)
	var check := UIKit.button("Check status", true)
	row2.add_child(check)
	g2.get_child(0).add_child(row2)
	var t := Tree.new()
	t.columns = 3
	t.column_titles_visible = true
	t.hide_root = true
	t.custom_minimum_size.y = 260
	for i in 3:
		t.set_column_title(i, ["Computer", "IP address", "Veyon Service"][i])
		t.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
	t.create_item()
	check.pressed.connect(func():
		t.clear()
		var r := t.create_item()
		var running := 0
		var total := 0
		for d in NetSim.students():
			total += 1
			var it := t.create_item(r)
			it.set_text(0, d.name)
			it.set_text(1, d.ip)
			var ok: bool = d.online and d.veyon_service
			if ok:
				running += 1
			it.set_text(2, "Running" if ok else ("Offline" if not d.online else "Stopped"))
			it.set_custom_color(2, UIKit.OK if ok else UIKit.BAD)
		_set_status("%d of %d student computers are ready." % [running, total], UIKit.OK if running == total else UIKit.WARN)
		NetSim.log_action("veyon_service_checked", {"running": running, "total": total}))
	g2.get_child(0).add_child(t)
	v.add_child(g2)
	return v


# ---------------------------------------------------------------- Locations & computers
func _page_locations() -> Control:
	var root := Control.new()
	var v := UIKit.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(v)
	v.add_child(UIKit.label("Locations & computers", 20, UIKit.TEXT, true))
	var h := UIKit.hbox(14)
	UIKit.expand(h)
	v.add_child(h)
	# locations
	var lv := UIKit.vbox(6)
	lv.custom_minimum_size.x = 230
	lv.add_child(UIKit.label("Locations", 14, UIKit.TEXT, true))
	_loc_list = ItemList.new()
	UIKit.expand(_loc_list)
	_loc_list.item_selected.connect(func(_i): _refresh_computers())
	lv.add_child(_loc_list)
	var lrow := UIKit.hbox(6)
	var loc_name := LineEdit.new()
	loc_name.placeholder_text = "New location name"
	UIKit.expand(loc_name, false)
	lrow.add_child(loc_name)
	var add_loc := UIKit.button("+")
	add_loc.tooltip_text = "Add location"
	add_loc.pressed.connect(func(): add_location(loc_name.text); loc_name.clear())
	loc_name.text_submitted.connect(func(t): add_location(t); loc_name.clear())
	lrow.add_child(add_loc)
	var del_loc := UIKit.button("−")
	del_loc.tooltip_text = "Remove location"
	del_loc.pressed.connect(func():
		var n := selected_location()
		if n != "":
			NetSim.veyon_locations.erase(n)
			NetSim.log_action("veyon_location_removed", {"name": n})
			_refresh_locations())
	lrow.add_child(del_loc)
	lv.add_child(lrow)
	h.add_child(lv)
	# computers
	var cv := UIKit.vbox(6)
	UIKit.expand(cv)
	cv.add_child(UIKit.label("Computers", 14, UIKit.TEXT, true))
	_comp_tree = Tree.new()
	_comp_tree.columns = 3
	_comp_tree.column_titles_visible = true
	_comp_tree.hide_root = true
	UIKit.expand(_comp_tree)
	for i in 3:
		_comp_tree.set_column_title(i, ["Name", "Host address/IP", "MAC address"][i])
		_comp_tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
	cv.add_child(_comp_tree)
	var crow := UIKit.hbox(6)
	var cname := LineEdit.new()
	cname.placeholder_text = "Name"
	cname.custom_minimum_size.x = 110
	crow.add_child(cname)
	var chost := LineEdit.new()
	chost.placeholder_text = "Host address/IP"
	chost.custom_minimum_size.x = 150
	crow.add_child(chost)
	var add_c := UIKit.button("+ Add computer")
	add_c.pressed.connect(func():
		var d := NetSim.find_device(chost.text)
		add_computers([{"name": cname.text.strip_edges(), "ip": chost.text.strip_edges(), "mac": d.get("mac", "")}], "manual")
		cname.clear(); chost.clear())
	crow.add_child(add_c)
	cv.add_child(crow)
	crow = UIKit.hbox(6)
	var imp := UIKit.button("Import from Network Inventory…", true)
	imp.pressed.connect(open_import)
	crow.add_child(imp)
	var rem := UIKit.button("Remove")
	rem.pressed.connect(func():
		var it := _comp_tree.get_selected()
		var loc := selected_location()
		if it and loc != "":
			var arr: Array = NetSim.veyon_locations[loc]
			arr.remove_at(it.get_index())
			NetSim.log_action("veyon_computer_removed", {"location": loc, "name": it.get_text(0)})
			_refresh_computers())
	crow.add_child(rem)
	cv.add_child(crow)
	h.add_child(cv)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)
	_refresh_locations()
	return root


func add_location(n: String) -> void:
	n = n.strip_edges()
	if n == "" or NetSim.veyon_locations.has(n):
		_set_status("Enter a new, unique location name.", UIKit.BAD)
		return
	NetSim.veyon_locations[n] = []
	NetSim.log_action("veyon_location_created", {"name": n, "correct": n == "Computer Lab 1"})
	_refresh_locations(n)
	NetSim.state_changed.emit()


func selected_location() -> String:
	if _loc_list == null or not _loc_list.is_anything_selected():
		return ""
	return _loc_list.get_item_text(_loc_list.get_selected_items()[0])


## Adds computers to the selected location; checks the name <-> IP pairing against NetSim.
func add_computers(list: Array, source: String) -> void:
	var loc := selected_location()
	if loc == "":
		_set_status("Select a location first.", UIKit.BAD)
		return
	var arr: Array = NetSim.veyon_locations[loc]
	var added := 0
	var mismatched := 0
	for c in list:
		if c.name == "" or NetSim.ip_to_int(c.ip) < 0:
			continue
		var exists := false
		for e in arr:
			if e.ip == c.ip:
				exists = true
		if exists:
			continue
		var real := NetSim.find_device(c.ip)
		if real.is_empty() or real.name != c.name:
			mismatched += 1
		arr.append({"name": c.name, "ip": c.ip, "mac": c.get("mac", "")})
		added += 1
	NetSim.log_action("veyon_computers_added", {"location": loc, "added": added, "mismatched": mismatched,
		"source": source, "total_in_location": arr.size()})
	_set_status("%d computer(s) added to %s." % [added, loc], UIKit.OK if mismatched == 0 else UIKit.WARN)
	_refresh_computers()
	NetSim.state_changed.emit()


func open_import() -> void:
	if selected_location() == "":
		_set_status("Select a location first.", UIKit.BAD)
		return
	for c in _overlay.get_children():
		c.queue_free()
	_overlay.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var p := UIKit.panel(Color.WHITE, Color("a0a0a0"), 8)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(520, 420)
	p.position = -p.custom_minimum_size / 2
	_overlay.add_child(p)
	var v := UIKit.vbox(8)
	p.add_child(UIKit.margin(v, 14))
	v.add_child(UIKit.label("Import from Network Inventory", 16, UIKit.TEXT, true))
	if NetSim.inventory.is_empty():
		v.add_child(UIKit.label("Network Inventory is empty.\nScan the network with Advanced IP Scanner and save the student computers first.", 13, UIKit.BAD))
	var t := Tree.new()
	t.columns = 3
	t.column_titles_visible = true
	t.hide_root = true
	UIKit.expand(t)
	for i in 3:
		t.set_column_title(i, ["Computer", "IP address", "MAC address"][i])
		t.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
	var r := t.create_item()
	for d in NetSim.inventory:
		var it := t.create_item(r)
		it.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		it.set_editable(0, true)
		it.set_text(0, d.name)
		it.set_text(1, d.ip)
		it.set_text(2, d.mac)
		it.set_metadata(0, d)
	v.add_child(t)
	var row := UIKit.hbox(8)
	var all := UIKit.button("Select all")
	all.pressed.connect(func():
		var it := r.get_first_child()
		while it:
			it.set_checked(0, true)
			it = it.get_next())
	row.add_child(all)
	var sp := Control.new()
	UIKit.expand(sp, false)
	row.add_child(sp)
	var cancel := UIKit.button("Cancel")
	cancel.pressed.connect(func(): _overlay.visible = false)
	row.add_child(cancel)
	var ok := UIKit.button("  Add selected  ", true)
	ok.pressed.connect(func():
		var picked := []
		var it := r.get_first_child()
		while it:
			if it.is_checked(0):
				picked.append(it.get_metadata(0))
			it = it.get_next()
		_overlay.visible = false
		add_computers(picked, "inventory"))
	row.add_child(ok)
	v.add_child(row)


func _refresh_locations(select := "") -> void:
	if _loc_list == null:
		return
	var keep := select if select != "" else selected_location()
	_loc_list.clear()
	for n in NetSim.veyon_locations:
		var i := _loc_list.add_item(n)
		if n == keep:
			_loc_list.select(i)
	if not _loc_list.is_anything_selected() and _loc_list.item_count > 0:
		_loc_list.select(0)
	_refresh_computers()


func _refresh_computers() -> void:
	if _comp_tree == null:
		return
	_comp_tree.clear()
	var r := _comp_tree.create_item()
	var loc := selected_location()
	if loc == "":
		return
	for c in NetSim.veyon_locations[loc]:
		var it := _comp_tree.create_item(r)
		it.set_text(0, c.name)
		it.set_text(1, c.ip)
		it.set_text(2, c.mac)


# ---------------------------------------------------------------- Authentication keys
func _page_keys() -> Control:
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("Authentication keys", 20, UIKit.TEXT, true))
	var hint := UIKit.label("1. Create a key pair  →  2. Distribute the public key to the student computers  →  3. Select 'Key file authentication' on the General page", 12, UIKit.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 200
	v.add_child(hint)
	_keys_tree = Tree.new()
	_keys_tree.columns = 3
	_keys_tree.column_titles_visible = true
	_keys_tree.hide_root = true
	_keys_tree.custom_minimum_size.y = 200
	for i in 3:
		_keys_tree.set_column_title(i, ["Name", "Type", "Access group"][i])
		_keys_tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(_keys_tree)
	var row := UIKit.hbox(8)
	var kname := LineEdit.new()
	kname.placeholder_text = "Key name, e.g. teacher"
	kname.custom_minimum_size.x = 200
	row.add_child(kname)
	var create := UIKit.button("Create key pair", true)
	create.pressed.connect(func():
		var n := kname.text.strip_edges().to_lower()
		if n == "" or not n.is_valid_identifier():
			_set_status("Enter a key name using letters, numbers or _ only.", UIKit.BAD)
			return
		if not n in NetSim.veyon_keys:
			NetSim.veyon_keys.append(n)
			NetSim.veyon_keys_distributed = false
			NetSim.log_action("veyon_key_created", {"name": n})
			_set_status("Key pair '%s' created." % n, UIKit.OK)
		kname.clear()
		_refresh_keys()
		NetSim.state_changed.emit())
	row.add_child(create)
	var del := UIKit.button("Delete key")
	del.pressed.connect(func():
		var it := _keys_tree.get_selected()
		if it:
			var n := it.get_text(0)
			NetSim.veyon_keys.erase(n)
			if NetSim.veyon_keys.is_empty():
				NetSim.veyon_keys_distributed = false
			NetSim.log_action("veyon_key_deleted", {"name": n})
			_refresh_keys()
			NetSim.state_changed.emit())
	row.add_child(del)
	v.add_child(row)
	row = UIKit.hbox(8)
	var dist := UIKit.button("Distribute public key to student computers", true)
	dist.pressed.connect(func():
		if NetSim.veyon_keys.is_empty():
			_set_status("Create a key pair first.", UIKit.BAD)
			return
		NetSim.veyon_keys_distributed = true
		var n := 0
		for d in NetSim.students():
			if d.online:
				n += 1
		NetSim.log_action("veyon_key_distributed", {"computers": n})
		_set_status("Public key imported on %d student computers." % n, UIKit.OK)
		_refresh_keys()
		NetSim.state_changed.emit())
	row.add_child(dist)
	v.add_child(row)
	_refresh_keys()
	return v


func _refresh_keys() -> void:
	_keys_tree.clear()
	var r := _keys_tree.create_item()
	for k in NetSim.veyon_keys:
		for kind in ["private", "public"]:
			var it := _keys_tree.create_item(r)
			it.set_text(0, k)
			it.set_text(1, kind + ("  ✓ on student PCs" if kind == "public" and NetSim.veyon_keys_distributed else ""))
			it.set_text(2, "")


# ---------------------------------------------------------------- helpers
func _group(title: String) -> PanelContainer:
	## Card with a title. get_child(0) is the VBoxContainer to add rows to.
	var p := PanelContainer.new()
	var st := UIKit.box(Color.WHITE, UIKit.BORDER, 6)
	st.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", st)
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label(title, 14, UIKit.ACCENT, true))
	p.add_child(v)
	return p


func _set_status(t: String, c := UIKit.TEXT_DIM) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", c)


func _snapshot() -> Dictionary:
	var locs := {}
	for n in NetSim.veyon_locations:
		locs[n] = NetSim.veyon_locations[n].size()
	return {"auth_method": NetSim.veyon_auth_method, "keys": NetSim.veyon_keys.duplicate(),
		"keys_distributed": NetSim.veyon_keys_distributed, "firewall": NetSim.firewall_veyon_allowed, "locations": locs}
