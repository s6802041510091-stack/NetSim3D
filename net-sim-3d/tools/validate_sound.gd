extends SceneTree

## Every sound loads, loops where it should, and each action in Level 1 plays
## its sound (checked through SoundManager.history).
## Run: godot --headless --path net-sim-3d -s res://tools/validate_sound.gd

var failures := 0
var sound: Sound


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		print("  ok   ", message)
	else:
		failures += 1
		print("  FAIL ", message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## Clears the history, runs `action`, waits `seconds` and says whether `id` played.
func _played_after(id: String, action: Callable, seconds := 0.2) -> bool:
	sound.history.clear()
	sound._last_play.clear()
	await action.call()
	if seconds > 0.0:
		await create_timer(seconds).timeout
	return id in sound.history


func _run() -> void:
	sound = root.get_node_or_null("SoundManager")
	_check(sound != null, "SoundManager autoload")
	if sound == null:
		quit(1)
		return
	for bus in ["Music", "SoundEffect", "Sound"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "bus " + bus)
	for id: String in Sound.BANK:
		for file: String in Sound.BANK[id]["files"]:
			var path: String = (Sound.GENERATED + file.substr(1)) if file.begins_with("@") else (Sound.KENNEY + file)
			_check(ResourceLoader.exists(path) and load(path) is AudioStream, "%s: %s" % [id, path.get_file()])
	for loop in ["amb_outdoor", "amb_aircon", "amb_pc_fans"]:
		var wav := load(Sound.GENERATED + loop + ".wav") as AudioStreamWAV
		_check(wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED, loop + " loops")
	for id: String in Sound.MUSIC:
		var path: String = Sound.MUSIC_DIR + String(Sound.MUSIC[id]["file"])
		if not ResourceLoader.exists(path):
			print("  note music file not added yet: ", path)

	# The level.
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 3:
		await physics_frame
	_check(sound._music_id == "level", "level music selected")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.require_mouse_capture = false
	var mission: Mission01Controller = map.get_node("Mission01")

	# Walking.
	player.global_position = Vector3(-6.15, 0.05, -20.0)
	player.rotation = Vector3.ZERO
	for i in 4:
		await physics_frame
	var walk := func():
		Input.action_press("move_forward")
		await create_timer(1.2).timeout
		Input.action_release("move_forward")
	_check(await _played_after("step", walk, 0.0), "footsteps while walking")

	# Ambience follows the room the camera is in.
	var fans: AmbienceZone = map.get_node("Ambience/ComputerRoomFans")
	var outdoors: AmbienceZone = map.get_node("Ambience/Outdoors")
	_check(outdoors.is_inside() and not fans.is_inside(), "corridor: outside sound, no computer fans")
	player.global_position = Vector3(3.0, 0.05, 0.0)
	await create_timer(1.5).timeout
	_check(fans.is_inside() and fans.volume_db > -20.0 and outdoors.volume_db < -20.0, "computer room: fans %.0f dB, outside %.0f dB" % [fans.volume_db, outdoors.volume_db])

	# Doors.
	var door: InteractiveDoor = map.get_node("Doors/ClassroomDoor")
	player.global_position = Vector3(-6.15, 0.05, 6.0)
	await physics_frame
	door.set_open(false, false)
	_check(await _played_after("door_open", func(): door.set_open(true)), "door opens with a sound")
	await create_timer(door.swing_time + 0.1).timeout
	_check(await _played_after("door_close", func(): door.set_open(false), door.swing_time + 0.2), "door closes with a sound")

	# Talking: the line types out with ticks; advancing clicks.
	var dialogue: DialogueBox = mission.dialogue
	_check(await _played_after("type_tick", func(): dialogue.show_lines(PackedStringArray(["ทดสอบ|ข้อความทดสอบเสียงพิมพ์ตามตัวอักษร"])), 0.3), "dialogue typing ticks")
	_check(dialogue.is_typing(), "the line is still typing")
	dialogue.advance(true)
	_check(not dialogue.is_typing() and dialogue.is_open(), "first press shows the whole line")
	dialogue.advance(true)
	_check(not dialogue.is_open(), "second press closes")

	# Objective panel.
	_check(await _played_after("objective", func(): mission.hud.set_objective("ทดสอบเป้าหมายใหม่")), "new objective chime")
	_check(await _played_after("toggle_off", func(): mission.hud.toggle()) or "toggle_on" in sound.history, "objective panel fold sound")
	mission.hud.toggle()

	# Buttons click by themselves; meta "sound" picks another or none.
	var button := Button.new()
	root.add_child(button)
	await process_frame
	_check(await _played_after("click", func(): button.pressed.emit()), "a plain button clicks")
	button.set_meta("sound", "confirm")
	_check(await _played_after("confirm", func(): button.pressed.emit()), "meta sound overrides the click")
	button.set_meta("sound", "")
	sound.history.clear()
	button.pressed.emit()
	_check(sound.history.is_empty(), "meta sound \"\" is silent")
	button.queue_free()

	# Computer: chair, boot, windows, shutdown.
	var manager: ComputerManager = map.get_node("Computers")
	var pc := manager.find_host("IT-PC-01")
	player.global_position = pc.global_position + Vector3(0, 0, 1.0)
	_check(await _played_after("pc_boot", func(): manager.open_computer(pc, player), manager.zoom_time + 0.3) and "chair" in sound.history, "sitting down and booting")
	await create_timer(DesktopOS.BOOT_TIME + 0.3).timeout
	_check(await _played_after("window_open", func(): manager.desktop._open_this_pc()), "window opens")
	_check(await _played_after("window_close", func(): manager.desktop._close_window("this_pc")) or manager.desktop._windows.is_empty(), "window closes")
	_check(await _played_after("pc_off", func(): manager.close_computer(), manager.zoom_time + 0.3), "computer shuts down")

	# NetPlan EDU.
	var app: NetPlanEdu = (load("res://missions/mission_01/scenes/netplan_edu.tscn") as PackedScene).instantiate()
	app.use_save_file = false
	root.add_child(app)
	await _frames(2)
	_check(await _played_after("popup_open", func(): app.open_point(1)), "install point opens the pop-up")
	app._popup.cancel()
	_check(await _played_after("back", func(): app.request_validation()), "checking an unfinished plan")
	app.choose_answer(1, "Router")
	app.choose_answer(2, "Shared Hub 24 Port")
	app.choose_answer(3, "Wireless Access Point")
	_check(await _played_after("wrong", func(): app.request_validation()), "a wrong plan sounds an error")
	app.choose_answer(2, "Switched Hub 24 Port")
	_check(await _played_after("correct", func(): app.request_validation()), "the right plan sounds correct")
	app.queue_free()

	# Summary.
	var summary := MissionSummary.new()
	root.add_child(summary)
	await process_frame
	var score := MissionScore.compute(30, 3, 3, 120.0, 300.0, 900.0)
	_check(await _played_after("jingle_pass", func(): summary.show_result("ทดสอบ", score, {}, false), 1.6) and "star" in sound.history, "pass jingle and stars")
	score = MissionScore.compute(0, 0, 3, 900.0, 300.0, 900.0)
	_check(await _played_after("jingle_fail", func(): summary.show_result("ทดสอบ", score, {}, false)), "fail jingle")
	summary.queue_free()

	# The supervisor types and clicks while the player is near.
	var supervisor: NpcCharacter = map.get_node("ITSupportSupervisor")
	player.global_position = supervisor.global_position + Vector3(2.0, 0, 0.8)
	sound.history.clear()
	await create_timer(5.0).timeout
	_check("key_tap" in sound.history or "mouse_click" in sound.history, "supervisor keyboard / mouse sounds")

	map.queue_free()
	await _frames(2)
	print("SOUND_VALID" if failures == 0 else "SOUND_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
