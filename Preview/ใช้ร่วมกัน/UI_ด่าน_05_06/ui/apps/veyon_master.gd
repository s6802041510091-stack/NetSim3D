extends Control
## Simulated Veyon Master (stage 6, steps 5-6).
## Choose location -> see student screens -> select the computer that asked for help ->
## Remote control -> do the task on the student's desktop -> Exit remote control.
## Tile status comes from NetSim.veyon_status(ip): auth keys / service / firewall must be ready.
## Logged: veyon_master_location / veyon_tile_selected / veyon_feature / remote_control_started /
##         remote_app_opened / remote_task_done / remote_control_ended

const FEATURES := [["Monitoring", "▣"], ["Demo", "▶"], ["Lock", "🔒"], ["Remote view", "◎"],
	["Remote control", "✥"], ["Text message", "✉"], ["Power on", "⏻"], ["Reboot", "↻"], ["Power down", "⏼"]]

var _loc_opt: OptionButton
var _grid: GridContainer
var _banner: PanelContainer
var _banner_label: Label
var _status: Label
var _selected := {}          # ip -> true
var _tiles := {}             # ip -> Control
var _remote_layer: Control
var _remote_pc := ""
var _task_done := false


func _ready() -> void:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.box(Color("f4f6f4"), Color.TRANSPARENT, 0))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UIKit.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	# toolbar
	var tb := UIKit.hbox(2)
	for f in FEATURES:
		tb.add_child(_feature_button(f[0], f[1]))
	var sp := Control.new()
	UIKit.expand(sp, false)
	tb.add_child(sp)
	var lv := UIKit.vbox(2)
	lv.add_child(UIKit.label("Location", 11, UIKit.TEXT_DIM))
	_loc_opt = OptionButton.new()
	_loc_opt.custom_minimum_size.x = 200
	_loc_opt.item_selected.connect(func(_i):
		_selected.clear()
		NetSim.log_action("veyon_master_location", {"location": current_location(), "correct": current_location() == "Computer Lab 1"})
		_rebuild_tiles())
	lv.add_child(_loc_opt)
	tb.add_child(lv)
	var tbp := UIKit.panel(Color.WHITE, UIKit.BORDER, 0)
	tbp.add_child(UIKit.margin(tb, 6))
	v.add_child(tbp)
	# help banner
	_banner = UIKit.panel(Color("fff4ce"), Color("e8c24a"), 0)
	_banner_label = UIKit.label("", 14, Color("6b4e00"))
	_banner.add_child(UIKit.margin(_banner_label, 8))
	_banner.visible = false
	v.add_child(_banner)
	# tiles
	var sc := ScrollContainer.new()
	UIKit.expand(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(UIKit.margin(_grid, 12))
	v.add_child(sc)
	var foot := UIKit.panel(Color.WHITE, UIKit.BORDER, 0)
	_status = UIKit.label("Select a location to show its computers.", 12, UIKit.TEXT_DIM)
	foot.add_child(UIKit.margin(_status, 6))
	v.add_child(foot)
	# remote control overlay (inside this window)
	_remote_layer = Control.new()
	_remote_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_remote_layer.visible = false
	add_child(_remote_layer)
	NetSim.state_changed.connect(_on_state_changed)
	resized.connect(_fit_columns)
	_refresh_locations()


func current_location() -> String:
	if _loc_opt.selected < 0:
		return ""
	return _loc_opt.get_item_text(_loc_opt.selected)


func select_location(n: String) -> void:
	for i in _loc_opt.item_count:
		if _loc_opt.get_item_text(i) == n:
			_loc_opt.select(i)
			_loc_opt.item_selected.emit(i)


func select_computer(ip: String, additive := false) -> void:
	if not additive:
		_selected.clear()
	_selected[ip] = true
	var d := NetSim.find_device(ip)
	NetSim.log_action("veyon_tile_selected", {"ip": ip, "name": d.get("name", ""), "is_help_request": d.get("name", "") == NetSim.help_request.pc})
	_update_tile_styles()


func _refresh_locations() -> void:
	var keep := current_location() if _loc_opt.item_count > 0 else ""
	_loc_opt.clear()
	for n in NetSim.veyon_locations:
		_loc_opt.add_item(n)
	_loc_opt.select(-1)
	for i in _loc_opt.item_count:
		if _loc_opt.get_item_text(i) == keep:
			_loc_opt.select(i)
	if _loc_opt.item_count == 0:
		_status.text = "No locations configured. Use Veyon Configurator > Locations & computers."
	_rebuild_tiles()


func _on_state_changed() -> void:
	if not is_inside_tree():
		return
	var names := []
	for i in _loc_opt.item_count:
		names.append(_loc_opt.get_item_text(i))
	if names != NetSim.veyon_locations.keys():
		_refresh_locations()
	else:
		_rebuild_tiles()


func _rebuild_tiles() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_tiles.clear()
	var loc := current_location()
	_banner.visible = false
	if loc == "":
		return
	var comps: Array = NetSim.veyon_locations.get(loc, [])
	var ok := 0
	for c in comps:
		var t := _make_tile(c)
		_grid.add_child(t)
		_tiles[c.ip] = t
		if NetSim.veyon_status(c.ip) == "":
			ok += 1
	_status.text = "%s: %d computers, %d connected" % [loc, comps.size(), ok]
	var hr: Dictionary = NetSim.help_request
	for c in comps:
		if c.name == hr.pc and NetSim.veyon_status(c.ip) == "":
			_banner_label.text = "✋  %s requests help: \"%s\"" % [hr.pc, hr.message]
			_banner.visible = true
	_update_tile_styles()
	_fit_columns()


func _make_tile(c: Dictionary) -> Control:
	var b := Button.new()
	b.toggle_mode = false
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 128)
	b.set_meta("ip", c.ip)
	var v := UIKit.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6; v.offset_right = -6; v.offset_top = 6; v.offset_bottom = -4
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var screen := _Thumb.new()
	screen.custom_minimum_size = Vector2(148, 90)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := NetSim.find_device(c.ip)
	screen.color = d.get("screen_color", Color.GRAY)
	screen.status = NetSim.veyon_status(c.ip)
	screen.help = c.name == NetSim.help_request.pc
	v.add_child(screen)
	var l := UIKit.label(("✋ " if screen.help and screen.status == "" else "") + c.name, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			select_computer(c.ip, e.ctrl_pressed)
			if e.double_click and screen.status == "":
				start_remote_control(c.ip))
	return b


func _update_tile_styles() -> void:
	for ip in _tiles:
		var t: Button = _tiles[ip]
		var sel := _selected.has(ip)
		var st := UIKit.box(Color("dbeafe") if sel else Color.WHITE, UIKit.ACCENT if sel else UIKit.BORDER, 6, 2 if sel else 1)
		for s in ["normal", "hover", "pressed"]:
			t.add_theme_stylebox_override(s, st)


func _fit_columns() -> void:
	if _grid:
		_grid.columns = maxi(1, int((size.x - 24) / 172.0))


func _feature_button(n: String, glyph: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 58)
	b.add_theme_stylebox_override("hover", UIKit.box(Color("e8f1e8"), Color.TRANSPARENT, 4))
	var v := UIKit.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := UIKit.label(glyph, 20, Color("2e7d32"))
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(g)
	var l := UIKit.label(n, 11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(func(): use_feature(n))
	return b


func use_feature(n: String) -> void:
	var targets := _selected.keys()
	NetSim.log_action("veyon_feature", {"feature": n, "targets": targets.size(), "location": current_location()})
	if n == "Remote control" or n == "Remote view":
		if targets.size() != 1:
			_status.text = "Select exactly one computer for %s." % n
			return
		start_remote_control(targets[0], n == "Remote view")
	else:
		_status.text = "%s: sent to %d computer(s)." % [n, targets.size()] if targets.size() > 0 else "Select one or more computers first."


func start_remote_control(ip: String, view_only := false) -> void:
	var st := NetSim.veyon_status(ip)
	var d := NetSim.find_device(ip)
	if st != "":
		_status.text = "%s: %s" % [d.get("name", ip), st]
		NetSim.log_action("remote_control_failed", {"pc": d.get("name", ip), "reason": st})
		return
	_remote_pc = d.name
	_task_done = false
	NetSim.log_action("remote_control_started", {"pc": d.name, "view_only": view_only, "correct": d.name == NetSim.help_request.pc})
	for c in _remote_layer.get_children():
		c.queue_free()
	_remote_layer.visible = true
	var frame := UIKit.panel(Color("202020"), Color.TRANSPARENT, 0)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_remote_layer.add_child(frame)
	var v := UIKit.vbox(0)
	frame.add_child(v)
	var bar := UIKit.hbox(8)
	bar.add_child(UIKit.label(("Remote view" if view_only else "Remote control") + " – " + d.name, 14, Color.WHITE, true))
	var sp := Control.new()
	UIKit.expand(sp, false)
	bar.add_child(sp)
	var ex := UIKit.button("  Exit  ", true)
	ex.pressed.connect(end_remote_control)
	bar.add_child(ex)
	v.add_child(UIKit.margin(bar, 6))
	var desk := SimDesktop.new()
	desk.machine_name = d.name
	desk.user_name = "Student"
	desk.apps = SimDesktop.STUDENT_APPS
	desk.wallpaper_top = d.screen_color.darkened(0.3)
	desk.wallpaper_bottom = d.screen_color
	UIKit.expand(desk)
	if view_only:
		desk.mouse_filter = Control.MOUSE_FILTER_STOP
		desk.set_meta("view_only", true)
	desk.app_opened.connect(func(app_id, _w):
		NetSim.log_action("remote_app_opened", {"pc": d.name, "app": app_id})
		if d.name == NetSim.help_request.pc and app_id == NetSim.help_request.app and not _task_done:
			_task_done = true
			NetSim.log_action("remote_task_done", {"pc": d.name, "app": app_id}))
	v.add_child(desk)
	if view_only:
		var block := Control.new()
		block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		block.offset_top = 44
		block.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.add_child(block)


func end_remote_control() -> void:
	if not _remote_layer.visible:
		return
	_remote_layer.visible = false
	for c in _remote_layer.get_children():
		c.queue_free()
	NetSim.log_action("remote_control_ended", {"pc": _remote_pc, "task_done": _task_done})
	if _task_done:
		_banner.visible = false


func get_remote_desktop() -> SimDesktop:
	if not _remote_layer.visible:
		return null
	var found := _remote_layer.find_children("*", "SimDesktop", true, false)
	return found[0] if found.size() > 0 else null


## Little "screenshot" of a student screen.
class _Thumb extends Control:
	var color := Color.GRAY
	var status := ""
	var help := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if status != "":
			draw_rect(r, Color("3a3a3a"))
			var f := UIKit.ui_font()
			var lines := ["⚠", status] if status != "Offline" else ["⏻", "Offline"]
			draw_string(f, Vector2(0, size.y * 0.42), lines[0], HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color("ffcc66"))
			draw_string(f, Vector2(0, size.y * 0.72), lines[1], HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color.WHITE)
			return
		draw_rect(r, color)
		draw_rect(Rect2(0, size.y - 8, size.x, 8), Color(0.92, 0.93, 0.95))
		for i in 3:
			draw_rect(Rect2(5, 6 + i * 16, 10, 10), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(size.x * 0.3, size.y * 0.18, size.x * 0.6, size.y * 0.55), Color.WHITE)
		draw_rect(Rect2(size.x * 0.3, size.y * 0.18, size.x * 0.6, 5), Color("dddddd"))
		if help:
			draw_circle(Vector2(size.x - 12, 12), 9, Color("f2b01e"))
			draw_string(UIKit.ui_font(), Vector2(size.x - 21, 17), "?", HORIZONTAL_ALIGNMENT_CENTER, 18, 13, Color.BLACK)
