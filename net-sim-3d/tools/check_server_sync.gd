extends SceneTree
## Headless check that the game talks to the NetSim website correctly (server_sync.gd).
## Needs the website running with DEV_LOGIN=true (web-portal: docker compose up -d).
## Run: godot --headless --path net-sim-3d -s res://tools/check_server_sync.gd -- http://localhost:8080
## Uses two throw-away test students and its own folder; never touches a player's saves.
## Prints one line per check and SERVER_SYNC_VALID / SERVER_SYNC_INVALID at the end.

const TEST_DIR := "user://server_sync_test"

var _base := "http://localhost:8080"
var _failures := 0
var _checks := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_base = args[0].trim_suffix("/")
	_run.call_deferred()


func _run() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	GameProgress.save_path = TEST_DIR.path_join("progress.json")
	LevelSave.folder = TEST_DIR
	Mission01SaveStore.save_path = TEST_DIR.path_join("mission_01_save.json")

	var stamp := str(Time.get_ticks_usec()).right(6)
	var first := await _student("sync-a-%s@test.local" % stamp, "69000%s01" % stamp.right(6))
	var second := await _student("sync-b-%s@test.local" % stamp, "69000%s02" % stamp.right(6))
	_check(first != "" and second != "", "two test students logged in (website up with DEV_LOGIN=true?)")
	if first == "" or second == "":
		_finish()
		return

	# The real autoload, pointed at the test folder and the first student's login.
	var sync: Node = root.get_node("ServerSync")
	sync.api_base = _base + "/api"
	sync.extra_headers = PackedStringArray(["Cookie: " + first])
	sync.storage_dir = TEST_DIR
	sync.notify_flow = false

	await sync.start()
	_check(sync.state == "no_class", "start(): logged-in student without a class -> no_class (got %s)" % sync.state)
	_check(String(sync.me.get("firstName", "")) == "ทดสอบ", "start(): knows the student's name")

	# Offline: the attempt waits in the queue.
	sync.api_base = "http://127.0.0.1:9/api"
	GameProgress.record_attempt(1, MissionScore.compute(30, 9, 10, 100.0, 300.0, 900.0), {"step_times": [{"step": 1, "name": "ทดสอบ", "sec": 12.5}], "mistake_log": [], "check_count": 2})
	await sync.flushed
	_check(sync.pending_count() == 1, "offline: attempt kept in the queue (pending=%d)" % sync.pending_count())

	# Back online: the queue empties and the server has it once.
	sync.api_base = _base + "/api"
	sync._flush(false)
	await sync.flushed
	_check(sync.pending_count() == 0, "online again: queue sent (pending=%d)" % sync.pending_count())
	var progress := await _progress(first)
	_check(int(progress.get("1", {}).get("attempts", 0)) == 1, "server has level 1 once")

	# A resend of something the server already has is stored once.
	var copy: Array = sync._load_pending()
	copy.append({"client_id": "resend-%s" % stamp, "user_id": sync.me.id, "level": 2, "finished_unix": int(Time.get_unix_time_from_system()) - 120,
		"result": MissionScore.compute(20, 5, 10, 100.0, 300.0, 900.0).to_dict()})
	sync._save_pending(copy)
	sync._flush(false)
	await sync.flushed
	sync._save_pending(copy)
	sync._flush(false)
	await sync.flushed
	progress = await _progress(first)
	_check(int(progress.get("2", {}).get("attempts", 0)) == 1, "same attempt sent twice -> stored once")

	# The game's own hook: record_attempt sends straight away when online.
	GameProgress.record_attempt(1, MissionScore.compute(10, 2, 10, 950.0, 300.0, 900.0))
	await sync.flushed
	progress = await _progress(first)
	_check(int(progress.get("1", {}).get("attempts", 0)) == 2, "record_attempt() sends to the class")

	# start() replaces local progress with the server copy.
	GameProgress.replace_all({})
	await sync.start()
	_check(GameProgress.level_record(1).get("attempts", 0) == 2.0 and GameProgress.best_score(1) == 95, "start(): local progress = server copy (level 1 best %d)" % GameProgress.best_score(1))
	_check(GameProgress.is_unlocked(2, [1, 2, 3, 4, 5, 6]), "level 2 unlocked from the server copy")

	# Another student on the same computer: the first one's local saves go away,
	# and the first one's queued attempt is never sent under the second login.
	LevelSave.write(1, {"step": 3})
	var queued: Array = [{"client_id": "left-behind-%s" % stamp, "user_id": sync.me.id, "level": 3, "finished_unix": int(Time.get_unix_time_from_system()),
		"result": MissionScore.compute(30, 10, 10, 100.0, 300.0, 900.0).to_dict()}]
	sync._save_pending(queued)
	sync.extra_headers = PackedStringArray(["Cookie: " + second])
	await sync.start()
	_check(GameProgress.load_all().is_empty(), "student switch: previous progress cleared")
	_check(not LevelSave.exists(1), "student switch: previous mid-level save cleared")
	_check(sync._load_pending().size() == 1, "student switch: previous student's queued attempt kept")
	progress = await _progress(second)
	_check(not progress.has("3"), "previous student's attempt was not sent under the new login")

	# Guest: no login cookie.
	sync.extra_headers = PackedStringArray()
	await sync.start()
	_check(sync.state == "guest", "no login -> guest (got %s)" % sync.state)
	_finish()


func _finish() -> void:
	_clean()
	print("SERVER_SYNC_%s checks=%d failures=%d" % ["VALID" if _failures == 0 else "INVALID", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("%s  %s" % ["OK  " if ok else "FAIL", label])


func _clean() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(TEST_DIR)


## Logs in a test student with a complete profile; returns the session cookie ("" on failure).
func _student(email: String, student_id: String) -> String:
	var login := await _http(HTTPClient.METHOD_POST, "/api/auth/dev-login", {"email": email}, "")
	var cookie := ""
	for header: String in login.headers:
		if header.to_lower().begins_with("set-cookie:") and header.contains("netsim_session="):
			cookie = header.substr(header.find("netsim_session=")).get_slice(";", 0)
	if cookie == "":
		return ""
	await _http(HTTPClient.METHOD_POST, "/api/me/role", {"role": "student"}, cookie)
	var profile := await _http(HTTPClient.METHOD_PATCH, "/api/me/profile", {"firstName": "ทดสอบ", "lastName": "ระบบเกม", "studentId": student_id}, cookie)
	return cookie if profile.code == 200 else ""


func _progress(cookie: String) -> Dictionary:
	var res := await _http(HTTPClient.METHOD_GET, "/api/game/progress", null, cookie)
	var body: Variant = res.body
	return (body as Dictionary).get("progress", {}) if body is Dictionary else {}


func _http(method: int, path: String, payload: Variant, cookie: String) -> Dictionary:
	var http := HTTPRequest.new()
	root.add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if cookie != "":
		headers.append("Cookie: " + cookie)
	http.request(_base + path, headers, method, "" if payload == null else JSON.stringify(payload))
	var reply: Array = await http.request_completed
	http.queue_free()
	var text := (reply[3] as PackedByteArray).get_string_from_utf8()
	return {"code": reply[1], "headers": reply[2], "body": JSON.parse_string(text) if text.begins_with("{") else null}
