extends Node

## Connects the Web build to the NetSim website (web-portal/ in this repository).
## Only active when the game runs in a browser next to the website's API at /api/;
## in the editor, native builds and the standalone web/serve.ps1 it does nothing.
##
## - Every finished level (GameProgress.record_attempt) is sent to POST /api/game/attempts.
##   Each attempt carries its own id, so a resend after a lost connection is stored once.
##   Attempts wait in pending_attempts.json until the server has them, tagged with the
##   student who played, and are only ever sent under that student's login.
## - At start the logged-in student's results come from GET /api/game/progress and
##   replace progress.json, so stars, unlocking and the progress page show that
##   student's own results on any computer. When a different student logs in on a
##   shared computer, the previous student's local saves are cleared first.
## - A small badge on the menu says who is logged in and whether scores reach the teacher.

signal state_changed
## After each try to send waiting attempts (tools/check_server_sync.gd waits on it).
signal flushed

const PENDING_FILE := "pending_attempts.json"
const ACCOUNT_FILE := "account.json"
const RETRY_SEC := 60.0

## "off": not in a browser next to the API. "checking", "student", "no_class",
## "no_profile", "teacher", "guest" (not logged in), "offline" (API unreachable).
var state := "off"
var me: Dictionary = {}
## Where the API is ("" = inactive). Set from the page address on the Web.
var api_base := ""
## Test settings (tools/check_server_sync.gd): extra request headers such as a
## Cookie, another folder for this script's files, and no menu redraw.
var extra_headers := PackedStringArray()
var storage_dir := ""
var notify_flow := true
var _flushing := false
var _badge_layer: CanvasLayer
var _badge: PanelContainer
var _badge_text: Label
var _badge_login: Button
var _badge_room := 0.0 # space last asked of GameFlow above its page card
var _toast: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web") or OS.has_feature("editor"):
		return
	var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
	if not origin is String or not String(origin).begins_with("http"):
		return
	api_base = String(origin) + "/api"
	_build_badge()
	L10n.language_changed.connect(_show_state)
	var timer := Timer.new()
	timer.wait_time = RETRY_SEC
	timer.autostart = true
	timer.timeout.connect(_retry)
	add_child(timer)
	_set_state("checking")
	start()


## Called by GameProgress.record_attempt after the result is saved on this device.
func submit_attempt(level: int, result: Dictionary) -> void:
	if api_base == "":
		return
	var owner_id := String(me.get("id", "")) if state in ["student", "no_class"] else ""
	if owner_id == "" and state == "offline":
		owner_id = _last_account() # API unreachable: keep it for whoever was logged in last
	if owner_id == "":
		return # guest, teacher or not set up: nothing goes to a class
	var pending := _load_pending()
	pending.append({
		"client_id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"user_id": owner_id,
		"level": level,
		"finished_unix": int(Time.get_unix_time_from_system()),
		"result": result,
	})
	_save_pending(pending)
	_show_state()
	_flush(true)


func pending_count() -> int:
	var mine := String(me.get("id", _last_account()))
	return _load_pending().filter(func(item): return String(item.get("user_id", "")) == mine).size()


## True while results come from (and go to) the class system rather than this device only.
func is_student_synced() -> bool:
	return state in ["student", "no_class"]


# ---------- start-up ----------

## Finds out who is logged in, sends their waiting attempts and loads their results.
func start() -> void:
	var res := await _request(HTTPClient.METHOD_GET, "/me")
	if res.code == 404:
		_set_state("off") # served without the website (e.g. web/serve.ps1)
		return
	if res.code == 0:
		_set_state("offline")
		return
	var data: Variant = res.body
	if not data is Dictionary:
		_set_state("off")
		return
	var user: Variant = (data as Dictionary).get("me")
	if not user is Dictionary:
		me = {}
		_set_state("guest")
		return
	me = user
	if me.get("role") == "teacher":
		_set_state("teacher")
		return
	if me.get("role") != "student" or bool(me.get("needsProfile", false)):
		_set_state("no_profile")
		return
	var changed := _switch_account(String(me.get("id", "")))
	await _flush(false)
	var progress := await _request(HTTPClient.METHOD_GET, "/game/progress")
	if progress.code == 200 and progress.body is Dictionary and (progress.body as Dictionary).get("progress") is Dictionary:
		GameProgress.replace_all((progress.body as Dictionary).get("progress"))
	_set_state("student" if me.get("activeClass") is Dictionary else "no_class")
	var flow := get_node_or_null("/root/GameFlow")
	if notify_flow and flow:
		flow.on_progress_synced(changed)


## A different student than last time on this computer: their predecessor's local
## saves (progress, mid-level saves) must not show up for them.
func _switch_account(user_id: String) -> bool:
	var previous := _last_account()
	if previous == user_id:
		return false
	if previous != "" or FileAccess.file_exists(GameProgress.save_path):
		GameProgress.clear()
		for level in range(1, GameProgress.LEVEL_COUNT + 1):
			LevelSave.clear(level)
		Mission01SaveStore.clear()
	_write_json(_file(ACCOUNT_FILE), {"user_id": user_id})
	return true


func _last_account() -> String:
	var data: Variant = _read_json(_file(ACCOUNT_FILE))
	return String((data as Dictionary).get("user_id", "")) if data is Dictionary else ""


# ---------- sending ----------

func _retry() -> void:
	if state in ["student", "no_class", "offline"] and pending_count() > 0:
		if state == "offline":
			start()
		else:
			_flush(false)


## Sends this student's waiting attempts, oldest first.
func _flush(announce: bool) -> void:
	if _flushing or not state in ["student", "no_class"]:
		flushed.emit()
		return
	_flushing = true
	var user_id := String(me.get("id", ""))
	var sent_any := false
	var failed := false
	for item: Dictionary in _load_pending():
		if String(item.get("user_id", "")) != user_id:
			continue # someone else's attempt: wait until they log in here again
		var age := maxi(0, int(Time.get_unix_time_from_system()) - int(item.get("finished_unix", 0)))
		var res := await _request(HTTPClient.METHOD_POST, "/game/attempts", {
			"clientId": item.get("client_id"), "level": int(item.get("level", 0)), "ageSec": age, "result": item.get("result"),
		})
		if res.code in [200, 201] or res.code == 400:
			if res.code == 400:
				push_warning("Server refused a game attempt: %s" % JSON.stringify(res.body))
			_remove_pending(String(item.get("client_id")))
			sent_any = sent_any or res.code != 400
		else:
			failed = true
			if res.code in [401, 403]:
				me = {}
				_set_state("guest")
			break
	_flushing = false
	_show_state()
	flushed.emit()
	if announce:
		_show_toast("ยังส่งคะแนนไม่ได้ จะลองส่งอีกครั้งอัตโนมัติ" if failed else "ส่งคะแนนให้ครูแล้ว" if sent_any else "")


func _load_pending() -> Array:
	var data: Variant = _read_json(_file(PENDING_FILE))
	return data if data is Array else []


func _save_pending(items: Array) -> void:
	_write_json(_file(PENDING_FILE), items)


func _remove_pending(client_id: String) -> void:
	_save_pending(_load_pending().filter(func(item): return String(item.get("client_id", "")) != client_id))


# ---------- HTTP ----------

## {code, body, network_error}: code 0 when the request never got an answer.
func _request(method: int, path: String, payload: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	# In the browser, fetch() already un-gzips the reply; Godot doing it again fails.
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	headers.append_array(extra_headers)
	var body := ""
	if payload != null:
		headers.append("Content-Type: application/json")
		body = JSON.stringify(payload)
	var started := http.request(api_base + path, headers, method, body)
	if started != OK:
		http.queue_free()
		return {"code": 0, "body": null, "network_error": true}
	var reply: Array = await http.request_completed
	http.queue_free()
	var result: int = reply[0]
	var code: int = reply[1]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null, "network_error": true}
	var text := (reply[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text.strip_edges().begins_with("{") else null
	return {"code": code, "body": parsed, "network_error": false}


# ---------- files ----------

func _file(file_name: String) -> String:
	return (storage_dir if storage_dir != "" else SavePaths.dir()).path_join(file_name)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write_json(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(value))
		file.close()


# ---------- badge on the menu ----------

func _set_state(value: String) -> void:
	state = value
	_show_state()
	state_changed.emit()


func _build_badge() -> void:
	_badge_layer = CanvasLayer.new()
	_badge_layer.layer = 102 # above the menu (GameFlow 100) and the controls popup (101)
	add_child(_badge_layer)
	_badge = PanelContainer.new()
	_badge.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.88)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.08, 0.14, 0.31, 0.18)
	style.shadow_size = 8
	_badge.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_badge.add_child(row)
	_badge_text = Label.new()
	_badge_text.add_theme_color_override("font_color", Color("14234f"))
	_badge_text.add_theme_font_size_override("font_size", 17)
	_badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_badge_text)
	_badge_login = Button.new()
	_badge_login.text = "เข้าสู่ระบบ"
	_badge_login.add_theme_font_size_override("font_size", 16)
	_badge_login.pressed.connect(func(): GameFlow.exit_to_lobby())
	row.add_child(_badge_login)
	_badge_layer.add_child(_badge)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color("14234f"))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 18
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.hide()
	_badge_layer.add_child(_toast)
	var visibility := Timer.new()
	visibility.wait_time = 0.3
	visibility.autostart = true
	visibility.timeout.connect(_update_badge_visibility)
	add_child(visibility)


func _show_state() -> void:
	if _badge_text == null:
		return
	var who := ("%s %s" % [me.get("firstName", ""), me.get("lastName", "")]).strip_edges()
	var cls: Variant = me.get("activeClass")
	var text := ""
	match state:
		"student":
			text = "%s  •  %s" % [who, (cls as Dictionary).get("name", "") if cls is Dictionary else ""]
		"no_class":
			text = "%s  •  %s" % [who, GameLocale.text("ยังไม่ได้เลือกคลาส • เลือกคลาสที่หน้าเว็บก่อน")]
		"no_profile":
			text = GameLocale.text("กรอกข้อมูลนักเรียนที่หน้าเว็บก่อน")
		"teacher":
			text = GameLocale.text("ครู • ทดลองเล่น ไม่ส่งคะแนน")
		"guest":
			text = GameLocale.text("ยังไม่ได้เข้าสู่ระบบ • คะแนนจะไม่ถูกส่งให้ครู")
		"offline":
			text = GameLocale.text("เชื่อมต่อระบบไม่ได้ • คะแนนเก็บไว้ในเครื่องก่อน")
	var waiting := pending_count() if state in ["student", "no_class", "offline"] else 0
	if waiting > 0:
		text += "  •  " + GameLocale.text("รอส่งคะแนน %d ครั้ง") % waiting
	_badge_text.text = text
	_badge_login.visible = state in ["guest", "no_profile"]
	_update_badge_visibility()


func _update_badge_visibility() -> void:
	if _badge == null:
		return
	var scene := get_tree().current_scene
	var on_menu := scene != null and scene.scene_file_path == GameFlow.MENU and not GameFlow.loading
	_badge.visible = on_menu and not state in ["off", "checking"]
	# The menu's page card starts below the badge, so the badge never covers
	# the card's back button (it did on the progress page, 2026-11-25).
	var bottom := _badge.position.y + _badge.get_combined_minimum_size().y if _badge.visible else 0.0
	if bottom != _badge_room:
		_badge_room = bottom
		GameFlow.make_room_at_top(bottom)


func _show_toast(message: String) -> void:
	if _toast == null or message == "":
		return
	_toast.text = GameLocale.text(message)
	_toast.show()
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_toast.hide)
