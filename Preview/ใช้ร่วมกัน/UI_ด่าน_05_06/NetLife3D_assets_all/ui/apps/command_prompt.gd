extends Control
## Simulated Command Prompt. Supported: ipconfig, ipconfig /all, ping, hostname, cls, help, exit.
## Results come from NetSim, so they match the IP scanner and Veyon.
## Every command is logged: NetSim.log_action("cmd", {"command": ..., "machine": ...})

const FG := Color("cccccc")
const BG := Color("0c0c0c")

var machine := "TEACHER-PC"
var _out: Label
var _input: LineEdit
var _prompt: Label
var _scroll: ScrollContainer
var _history: PackedStringArray = []
var _hist_i := 0
var _busy := false


func _ready() -> void:
	if has_meta("desktop"):
		machine = get_meta("desktop").machine_name
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.box(BG, Color.TRANSPARENT, 0))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var v := UIKit.vbox(0)
	UIKit.expand(v, false)
	var m := UIKit.margin(v, 8)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(m)
	_out = _mono_label("")
	_out.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	UIKit.expand(_out, false)
	v.add_child(_out)
	var row := UIKit.hbox(0)
	v.add_child(row)
	_prompt = _mono_label(_prompt_text())
	row.add_child(_prompt)
	_input = LineEdit.new()
	UIKit.expand(_input, false)
	_input.add_theme_font_override("font", UIKit.mono_font())
	_input.add_theme_font_size_override("font_size", 15)
	_input.add_theme_color_override("font_color", FG)
	_input.add_theme_color_override("caret_color", FG)
	for s in ["normal", "focus", "read_only"]:
		_input.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_input.caret_blink = true
	_input.context_menu_enabled = false
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_key)
	row.add_child(_input)
	_out.text = "Microsoft Windows [Version 10.0.22631.4317]\n(c) Microsoft Corporation. All rights reserved.\n\n"
	gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _input.grab_focus())
	_input.call_deferred("grab_focus")


## Run a command as if typed (also used by tests / tutorials).
func run(cmd: String) -> void:
	_on_submit(cmd)


func get_output() -> String:
	return _out.text


func _prompt_text() -> String:
	return "C:\\Users\\%s>" % _user()


func _user() -> String:
	return get_meta("desktop").user_name if has_meta("desktop") else "Teacher"


func _on_submit(text: String) -> void:
	if _busy:
		return
	_input.clear()
	_print(_prompt_text() + text + "\n")
	var cmd := text.strip_edges()
	if cmd != "":
		_history.append(cmd)
		_hist_i = _history.size()
	if cmd == "":
		return
	NetSim.log_action("cmd", {"command": cmd, "machine": machine})
	var parts := cmd.split(" ", false)
	var cmd_name := parts[0].to_lower()
	var args := parts.slice(1)
	match cmd_name:
		"ipconfig":
			_ipconfig(args)
		"ping":
			_ping(args)
		"hostname":
			_print(machine + "\n\n")
		"cls":
			_out.text = ""
		"help":
			_print("Supported commands in this simulation:\n  IPCONFIG [/all]\n  PING host [-n count]\n  HOSTNAME\n  CLS\n  EXIT\n\n")
		"exit":
			var w := _find_window()
			if w:
				w.close()
		_:
			_print("'%s' is not recognized as an internal or external command,\noperable program or batch file.\n\n" % parts[0])


func _ipconfig(args: PackedStringArray) -> void:
	var me := NetSim.find_device(machine)
	var all := args.size() > 0 and args[0].to_lower() == "/all"
	if args.size() > 0 and not all:
		_print("Error: unrecognized or incomplete command line.\n\nUSAGE:\n    ipconfig [/all]\n\n")
		return
	var s := "\nWindows IP Configuration\n\n"
	if all:
		s += "   Host Name . . . . . . . . . . . . : %s\n" % machine
		s += "   Primary Dns Suffix  . . . . . . . : \n"
		s += "   Node Type . . . . . . . . . . . . : Hybrid\n"
		s += "   IP Routing Enabled. . . . . . . . : No\n\n"
	s += "Ethernet adapter Ethernet:\n\n"
	if me.is_empty() or not me.online:
		s += "   Media State . . . . . . . . . . . : Media disconnected\n"
		s += "   Connection-specific DNS Suffix  . : \n\n"
		_print(s)
		return
	s += "   Connection-specific DNS Suffix  . : \n"
	if all:
		s += "   Description . . . . . . . . . . . : Realtek PCIe GbE Family Controller\n"
		s += "   Physical Address. . . . . . . . . : %s\n" % String(me.mac).replace(":", "-")
		s += "   DHCP Enabled. . . . . . . . . . . : No\n"
		s += "   Autoconfiguration Enabled . . . . : Yes\n"
	s += "   Link-local IPv6 Address . . . . . : fe80::%s%%12\n" % _ipv6_tail(me.mac)
	s += "   IPv4 Address. . . . . . . . . . . : %s%s\n" % [me.ip, "(Preferred) " if all else ""]
	s += "   Subnet Mask . . . . . . . . . . . : %s\n" % NetSim.MASK
	s += "   Default Gateway . . . . . . . . . : %s\n" % NetSim.GATEWAY
	if all:
		s += "   DNS Servers . . . . . . . . . . . : %s\n" % NetSim.DNS
		s += "   NetBIOS over Tcpip. . . . . . . . : Enabled\n"
	_print(s + "\n")


func _ping(args: PackedStringArray) -> void:
	var count := 4
	var target := ""
	var i := 0
	while i < args.size():
		var a := args[i].to_lower()
		if a == "-n" and i + 1 < args.size() and args[i + 1].is_valid_int():
			count = clampi(args[i + 1].to_int(), 1, 10)
			i += 1
		elif not a.begins_with("-"):
			target = args[i]
		i += 1
	if target == "":
		_print("\nUsage: ping [-n count] target_name\n\n")
		return
	var me := NetSim.find_device(machine)
	var external := target in ["8.8.8.8", "google.com", "www.google.com", "1.1.1.1"]
	var dev := NetSim.find_device(target)
	var ip := target
	if not dev.is_empty():
		ip = dev.ip
	elif not external and NetSim.ip_to_int(target) < 0:
		_print("Ping request could not find host %s. Please check the name and try again.\n\n" % target)
		NetSim.log_action("ping_result", {"target": target, "ok": false, "reason": "unknown_host"})
		return
	if external and NetSim.ip_to_int(target) < 0:
		ip = "142.250.199.36"
	var header := "\nPinging %s with 32 bytes of data:\n" % (("%s [%s]" % [target, ip]) if ip != target else ip)
	_print(header)
	var me_ok: bool = not me.is_empty() and me.online
	var router := NetSim.find_device(NetSim.GATEWAY)
	var reachable := false
	var ttl := 128
	if external:
		reachable = me_ok and router.online
		ttl = 117
	elif not dev.is_empty():
		reachable = me_ok and dev.online
		ttl = 64 if dev.type == "router" else 128
	_busy = true
	var got := 0
	var times: Array[int] = []
	for n in count:
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return
		if not me_ok:
			_print("PING: transmit failed. General failure.\n")
		elif reachable:
			var t := randi_range(12, 35) if external else randi_range(1, 3)
			times.append(t)
			got += 1
			_print("Reply from %s: bytes=32 time%s TTL=%d\n" % [ip, ("=%dms" % t) if t > 1 else "<1ms", ttl])
		elif NetSim.ip_to_int(ip) >= 0 and ip.begins_with(NetSim.SUBNET + "."):
			_print("Reply from %s: Destination host unreachable.\n" % me.ip)
		else:
			_print("Request timed out.\n")
	# like real Windows: "Destination host unreachable" replies still count as received
	var received := got
	if me_ok and not reachable and ip.begins_with(NetSim.SUBNET + "."):
		received = count
	var lost := count - received
	var s := "\nPing statistics for %s:\n    Packets: Sent = %d, Received = %d, Lost = %d (%d%% loss),\n" % [ip, count, received, lost, int(100.0 * lost / count)]
	if times.size() > 0:
		var mn: int = times.min()
		var mx: int = times.max()
		var avg := 0
		for t in times:
			avg += t
		s += "Approximate round trip times in milli-seconds:\n    Minimum = %dms, Maximum = %dms, Average = %dms\n" % [mn, mx, roundi(float(avg) / times.size())]
	_print(s + "\n")
	_busy = false
	NetSim.log_action("ping_result", {"target": target, "ip": ip, "ok": reachable, "machine": machine})


func _print(s: String) -> void:
	_out.text += s
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _on_input_key(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and _history.size() > 0:
		if e.keycode == KEY_UP:
			_hist_i = maxi(0, _hist_i - 1)
			_input.text = _history[_hist_i]
			_input.caret_column = _input.text.length()
			accept_event()
		elif e.keycode == KEY_DOWN:
			_hist_i = mini(_history.size(), _hist_i + 1)
			_input.text = "" if _hist_i >= _history.size() else _history[_hist_i]
			_input.caret_column = _input.text.length()
			accept_event()


func _mono_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", UIKit.mono_font())
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", FG)
	return l


func _find_window() -> AppWindow:
	var p := get_parent()
	while p and not (p is AppWindow):
		p = p.get_parent()
	return p


func _ipv6_tail(mac: String) -> String:
	var h := mac.replace(":", "").to_lower()
	return "%s:%sff:fe%s:%s" % [h.substr(0, 4), h.substr(4, 2), h.substr(6, 2), h.substr(8, 4)]
