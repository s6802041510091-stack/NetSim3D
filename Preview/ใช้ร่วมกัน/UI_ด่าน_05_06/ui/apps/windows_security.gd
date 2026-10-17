extends Control
## Simulated Windows Security > Firewall & network protection > Allow an app through firewall.
## The "Veyon Service" rule is linked to NetSim.firewall_veyon_allowed (same flag as Veyon Configurator).
## Logged: security_page / firewall_change_settings / firewall_rule_changed

var _holder: MarginContainer
var _nav: ItemList
const PAGES := ["Home", "Virus & threat protection", "Firewall & network protection", "App & browser control", "Device security"]
const GLYPH := ["⌂", "◈", "≋", "▤", "▭"]


func _ready() -> void:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.box(Color("f3f3f3"), Color.TRANSPARENT, 0))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var h := UIKit.hbox(0)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(h)
	_nav = ItemList.new()
	_nav.custom_minimum_size.x = 250
	_nav.add_theme_stylebox_override("panel", UIKit.box(Color("ebebeb"), Color.TRANSPARENT, 0, 0, 8))
	_nav.add_theme_constant_override("v_separation", 12)
	for i in PAGES.size():
		_nav.add_item("  %s   %s" % [GLYPH[i], PAGES[i]])
	_nav.item_selected.connect(func(i): show_page(PAGES[i]))
	h.add_child(_nav)
	_holder = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_holder.add_theme_constant_override("margin_" + side, 24)
	UIKit.expand(_holder)
	h.add_child(_holder)
	show_page("Firewall & network protection")


func show_page(p: String) -> void:
	for c in _holder.get_children():
		c.queue_free()
	_nav.select(PAGES.find(p))
	NetSim.log_action("security_page", {"page": p})
	if p == "Firewall & network protection":
		_holder.add_child(_firewall_home())
	else:
		var v := UIKit.vbox(10)
		v.add_child(UIKit.label(p, 24, UIKit.TEXT))
		v.add_child(UIKit.label("No actions needed.", 14, UIKit.TEXT_DIM))
		_holder.add_child(v)


func _firewall_home() -> Control:
	var v := UIKit.vbox(14)
	v.add_child(UIKit.label("Firewall & network protection", 24))
	v.add_child(UIKit.label("Who and what can access your networks.", 13, UIKit.TEXT_DIM))
	for prof in [["Domain network", false], ["Private network (active)", true], ["Public network", false]]:
		var card := UIKit.panel(Color.WHITE, UIKit.BORDER, 6)
		var row := UIKit.hbox(12)
		row.add_child(UIKit.label("≋", 20, UIKit.ACCENT))
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label(prof[0], 14, UIKit.TEXT, true))
		col.add_child(UIKit.label("Firewall is on.", 13, UIKit.OK))
		row.add_child(col)
		card.add_child(UIKit.margin(row, 12))
		v.add_child(card)
	var link := LinkButton.new()
	link.text = "Allow an app through firewall"
	link.add_theme_color_override("font_color", UIKit.ACCENT)
	link.add_theme_color_override("font_hover_color", UIKit.ACCENT_HOVER)
	link.pressed.connect(func(): _open_allowed_apps())
	v.add_child(link)
	var l2 := LinkButton.new()
	l2.text = "Advanced settings"
	l2.add_theme_color_override("font_color", UIKit.ACCENT)
	v.add_child(l2)
	return v


func _open_allowed_apps() -> void:
	for c in _holder.get_children():
		c.queue_free()
	NetSim.log_action("security_page", {"page": "Allowed apps"})
	var v := UIKit.vbox(10)
	_holder.add_child(v)
	var back := LinkButton.new()
	back.text = "← Back"
	back.add_theme_color_override("font_color", UIKit.ACCENT)
	back.pressed.connect(func(): show_page("Firewall & network protection"))
	v.add_child(back)
	v.add_child(UIKit.label("Allow apps to communicate through Windows Defender Firewall", 18))
	v.add_child(UIKit.label("To add, change, or remove allowed apps and ports, click Change settings.", 13, UIKit.TEXT_DIM))
	var row := UIKit.hbox(8)
	var sp := Control.new()
	UIKit.expand(sp, false)
	row.add_child(sp)
	var change := UIKit.button("Change settings")
	row.add_child(change)
	v.add_child(row)
	var t := Tree.new()
	t.columns = 3
	t.column_titles_visible = true
	t.hide_root = true
	UIKit.expand(t)
	t.set_column_title(0, "Allowed apps and features:")
	t.set_column_title(1, "Private")
	t.set_column_title(2, "Public")
	t.set_column_expand(1, false)
	t.set_column_expand(2, false)
	t.set_column_custom_minimum_width(1, 80)
	t.set_column_custom_minimum_width(2, 80)
	t.set_column_title_alignment(0, HORIZONTAL_ALIGNMENT_LEFT)
	var r := t.create_item()
	var rules := [
		["Core Networking", true, true, ""],
		["File and Printer Sharing", true, false, ""],
		["File and Printer Sharing (Echo Request - ICMPv4-In)", true, false, ""],
		["Microsoft Edge", true, true, ""],
		["Remote Desktop", false, false, ""],
		["Veyon Service (TCP 11100)", NetSim.firewall_veyon_allowed, false, "veyon"],
	]
	for rule in rules:
		var it := t.create_item(r)
		it.set_text(0, rule[0])
		for col in [1, 2]:
			it.set_cell_mode(col, TreeItem.CELL_MODE_CHECK)
			it.set_checked(col, rule[col])
			it.set_editable(col, false)
			it.set_text_alignment(col, HORIZONTAL_ALIGNMENT_CENTER)
		it.set_metadata(0, rule[3])
	t.item_edited.connect(func():
		var it := t.get_edited()
		var col := t.get_edited_column()
		NetSim.log_action("firewall_rule_changed", {"rule": it.get_text(0), "profile": "private" if col == 1 else "public", "allowed": it.is_checked(col)})
		if it.get_metadata(0) == "veyon" and col == 1:
			NetSim.firewall_veyon_allowed = it.is_checked(1)
			NetSim.state_changed.emit())
	change.pressed.connect(func():
		NetSim.log_action("firewall_change_settings", {})
		change.disabled = true
		var it := r.get_first_child()
		while it:
			it.set_editable(1, true)
			it.set_editable(2, true)
			it = it.get_next())
	v.add_child(t)
	var foot := UIKit.hbox(8)
	var sp2 := Control.new()
	UIKit.expand(sp2, false)
	foot.add_child(sp2)
	var ok := UIKit.button("   OK   ", true)
	ok.pressed.connect(func(): show_page("Firewall & network protection"))
	foot.add_child(ok)
	v.add_child(foot)
