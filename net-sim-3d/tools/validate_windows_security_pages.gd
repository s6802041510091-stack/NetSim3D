extends SceneTree

## The look-around pages of Mission 5's Windows Security (2026-11-19): every
## page opens and goes back to its parent, their links lead somewhere, Scan
## options runs quick / full / custom scans (only one that reaches the threat
## moves the mission on; the offline scan asks for a restart and stops), the
## protection switches stay on and count as a wrong decision, and the free
## settings change without counting. Run headless:
## godot --headless --path net-sim-3d -s res://tools/validate_windows_security_pages.gd
## With a window and `-- <out_dir>` it also saves pictures of the new pages.
const SCENE := "res://missions/mission_05/scenes/windows_security.tscn"
## Links this round did not wire up (the user chose the pages to add).
const STILL_PLAIN := ["Link_Protectionupdates", "Link_NetworkandInternettroubleshooter", "Link_Firewallnotificationsettings", "Link_Advancedsettings", "Link_Restorefirewallstodefault"]

var failures := 0
var out_dir := ""
var app: WindowsSecurity


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, note: String) -> void:
	print("  ok   " if ok else "  FAIL ", note)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if out_dir == "":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _fresh() -> WindowsSecurity:
	if app:
		app.queue_free()
		await _frames(2)
	WindowsSecurity.shared_state = null
	app = (load(SCENE) as PackedScene).instantiate() as WindowsSecurity
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await _frames(2)
	return app


func _alerts_done() -> void:
	app.state.note_alert(Mission05State.ALERT_SCHOOL, "allow_private")
	app.state.note_alert(Mission05State.ALERT_UNKNOWN, "block")
	app.refresh()


func _press_switch(node_name: String) -> void:
	(app.find_child(node_name, true, false).get_node("Switch") as Button).pressed.emit()
	await _frames(2)


func _wait_scan() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while app.scanning and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames(2)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 800)
	await _fresh()

	# Every new page opens, has content, and goes back to its parent.
	var new_pages := [WindowsSecurity.Page.SCAN_OPTIONS, WindowsSecurity.Page.ALLOWED_THREATS, WindowsSecurity.Page.RANSOMWARE,
		WindowsSecurity.Page.ACCOUNT_INFO, WindowsSecurity.Page.SIGN_IN, WindowsSecurity.Page.DYNAMIC_LOCK,
		WindowsSecurity.Page.SMART_APP, WindowsSecurity.Page.REPUTATION, WindowsSecurity.Page.EXPLOIT,
		WindowsSecurity.Page.CORE_ISOLATION, WindowsSecurity.Page.SECURITY_PROCESSOR, WindowsSecurity.Page.FAMILY_GROUP,
		WindowsSecurity.Page.NOTIFICATIONS, WindowsSecurity.Page.PROVIDERS]
	for p in new_pages:
		app.open_page(p)
		await _frames(1)
		var key: String = WindowsSecurity.Page.keys()[p]
		check(app._content.get_child_count() > 3, key + " has content")
		app._go_back()
		await _frames(1)
		check(app.page == WindowsSecurity.PARENT[p], key + " goes back to " + String(WindowsSecurity.Page.keys()[app.page]))
		if out_dir != "":
			app.open_page(p)
			await _shot("page_" + key.to_lower())

	# No dead links left on the pages this round covers.
	var dead := PackedStringArray()
	for p in [WindowsSecurity.Page.VIRUS, WindowsSecurity.Page.ACCOUNT, WindowsSecurity.Page.APP, WindowsSecurity.Page.DEVICE,
			WindowsSecurity.Page.FAMILY, WindowsSecurity.Page.SETTINGS, WindowsSecurity.Page.AV_SETTINGS] + new_pages:
		app.open_page(p)
		await _frames(1)
		for link in app._content.find_children("Link_*", "Button", true, false):
			if (link as Button).pressed.get_connections().is_empty() and not String(link.name) in STILL_PLAIN:
				dead.append("%s:%s" % [WindowsSecurity.Page.keys()[p], link.name])
	check(dead.is_empty(), "every link opens something: dead %s" % [dead])

	# Scan options before the alerts: Scan now waits.
	app.open_page(WindowsSecurity.Page.SCAN_OPTIONS)
	await _frames(1)
	var now := app.find_child("ScanNowButton", true, false) as Button
	check(now != null and now.disabled and app.find_child("QuickScanButton", true, false) == null, "Scan now waits for the firewall alerts; no second Quick scan button")
	_alerts_done()
	await _frames(1)

	# Custom scan of Documents: runs, finds nothing, the mission does not move.
	var mission_scans := [0]
	app.scan_started.connect(func(): mission_scans[0] += 1)
	(app.find_child("ScanKind_custom", true, false) as CheckBox).button_pressed = true
	(app.find_child("ScanNowButton", true, false) as Button).pressed.emit()
	await _frames(1)
	check(app.picker_visible() and app.find_child("Folder_Documents", true, false) != null, "Custom scan asks for a folder")
	(app.find_child("Folder_Documents", true, false) as Button).pressed.emit()
	await _frames(1)
	(app.find_child("PickerOpen", true, false) as Button).pressed.emit()
	await _frames(1)
	check(app.scanning and app.scan_kind == "custom" and not app.picker_visible(), "custom scan of Documents runs")
	await _shot("scan_running_custom")
	await _wait_scan()
	check(app.state.scan_status == Mission05State.ScanStatus.NOT_SCANNED and mission_scans[0] == 0, "Documents: no threat, the mission scan still to do")
	app.open_page(WindowsSecurity.Page.VIRUS)
	await _frames(1)
	check(_text(app).contains("No current threats.") and _text(app).contains("(custom scan)"), "Virus page shows the custom scan's result")

	# Offline scan: needs a restart, which the lab does not allow.
	app.open_page(WindowsSecurity.Page.SCAN_OPTIONS)
	await _frames(1)
	(app.find_child("ScanKind_offline", true, false) as CheckBox).button_pressed = true
	(app.find_child("ScanNowButton", true, false) as Button).pressed.emit()
	await _frames(1)
	check(app.dialog_visible() and _text(app).contains("restart"), "offline scan: restart dialog")
	await _shot("offline_dialog")
	(app.find_child("Dialog_Scan", true, false) as Button).pressed.emit()
	await _frames(2)
	check(app.dialog_visible() and _text(app).contains("isn't allowed during the lab"), "the lab does not allow the restart")
	(app.find_child("Dialog_OK", true, false) as Button).pressed.emit()
	await _frames(2)
	check(not app.dialog_visible() and not app.scanning, "dialog closed, no scan")

	# Full scan: longer, reaches the threat, moves the mission on.
	(app.find_child("ScanKind_full", true, false) as CheckBox).button_pressed = true
	(app.find_child("ScanNowButton", true, false) as Button).pressed.emit()
	await _frames(1)
	check(app.scanning and app.scan_kind == "full" and mission_scans[0] == 1 and app._scan_seconds > app.data.scan_seconds, "full scan runs longer and counts")
	await _wait_scan()
	check(app.state.scan_status == Mission05State.ScanStatus.SCANNED and app.mission_scan_kind == "full", "full scan found the threat")
	app.open_page(WindowsSecurity.Page.VIRUS)
	await _frames(1)
	check(_text(app).contains("(full scan)") and _text(app).contains(app.data.threat_name), "result names the full scan and the threat")
	check(not app.start_scan("quick"), "no new scan while the threat waits for an action")
	app.choose_threat("quarantine")
	await _frames(1)
	check(app.state.threat_quarantined, "quarantined")
	check(app.start_scan("quick") and not app._scan_for_mission, "after the quarantine a quick scan runs again, outside the mission")
	await _wait_scan()
	check(mission_scans[0] == 1 and _text(app).contains("0 threats found."), "the re-scan finds nothing and is not counted")

	# Protection switches: off is wrong, recorded, not applied.
	check(app.state.kept_protection(), "protection kept so far")
	app.open_page(WindowsSecurity.Page.AV_SETTINGS)
	await _frames(1)
	await _press_switch("Protect_cloud")
	check("cloud" in app.state.protection_off and app.current_hint() == Mission05State.protection_hint("cloud"), "Cloud-delivered protection off: recorded, hint")
	check(app.find_child("Protect_cloud", true, false).get_node("Switch").get_meta("on") == true, "the switch is back on")
	await _shot("hint_cloud")
	app.open_page(WindowsSecurity.Page.REPUTATION)
	await _frames(1)
	await _press_switch("Protect_pua")
	app.open_page(WindowsSecurity.Page.SMART_APP)
	await _frames(1)
	(app.find_child("SmartApp_Off", true, false) as CheckBox).pressed.emit()
	await _frames(2)
	check((app.find_child("SmartApp_Evaluation", true, false) as CheckBox).button_pressed, "Smart App Control stays on Evaluation")
	app.open_page(WindowsSecurity.Page.EXPLOIT)
	await _frames(1)
	var cfg := app.find_child("Exploit_Controlflowguard", true, false) as OptionButton
	cfg.item_selected.emit(2)
	await _frames(2)
	check((app.find_child("Exploit_Controlflowguard", true, false) as OptionButton).selected == 0, "Exploit protection setting back to default")
	check(Array(app.state.protection_off) == ["cloud", "pua", "smart_app", "exploit"], "four protection mistakes: %s" % [app.state.protection_off])
	check(not app.state.kept_protection(), "kept_protection lost")
	var lines := app.state.mistakes()
	check(Mission05State.protection_mistake("cloud") in lines and Mission05State.protection_mistake("exploit") in lines, "the summary lists them")
	var l10n := root.get_node("L10n")
	var locale_was: String = l10n.locale
	l10n.set_locale("en", false) # not saved: the player's language stays
	for text in [Mission05State.protection_hint("pua"), Mission05State.protection_mistake("lsa")]:
		var english: String = l10n.t(text)
		check(not RegEx.create_from_string("[ก-๙]").search(english), "in English mode: " + english)
	l10n.set_locale(locale_was, false)

	# Free settings: change without counting.
	var before := app.state.wrong_count()
	app.open_page(WindowsSecurity.Page.RANSOMWARE)
	await _frames(1)
	await _press_switch("Pref_controlled_folder")
	check(app._prefs["controlled_folder"] and _text(app).contains("Protected folders"), "Controlled folder access on: protected folders listed")
	app.open_page(WindowsSecurity.Page.NOTIFICATIONS)
	await _frames(1)
	await _press_switch("Pref_notify_firewall")
	check(not app._prefs["notify_firewall"] and app.state.wrong_count() == before, "notification settings change freely")
	await _shot("notifications")

	app.queue_free()
	WindowsSecurity.shared_state = null
	print("WINDOWS_SECURITY_PAGES_VALID" if failures == 0 else "WINDOWS_SECURITY_PAGES_INVALID failures=%d" % failures)
	quit(1 if failures else 0)


func _text(node: Node) -> String:
	var out := ""
	for l in node.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out += (l as Label).text + "\n"
	for b in node.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			out += (b as Button).text + "\n"
	return out
