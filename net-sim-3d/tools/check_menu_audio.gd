extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _energy(capture: AudioEffectCapture) -> float:
	var count := capture.get_frames_available()
	assert(count > 0)
	var total := 0.0
	for frame in capture.get_buffer(count):
		total += frame.length_squared()
	return sqrt(total / count)

func _check() -> void:
	await process_frame
	await process_frame
	var flow := root.get_node("GameFlow")
	var sound := root.get_node("SoundManager")
	var music_bus := AudioServer.get_bus_index("Music")
	var effect_bus := AudioServer.get_bus_index("SoundEffect")
	var music_capture := AudioEffectCapture.new()
	music_capture.buffer_length = 2.0
	var effect_capture := AudioEffectCapture.new()
	effect_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(music_bus, music_capture)
	AudioServer.add_bus_effect(effect_bus, effect_capture)
	flow.show_home()
	assert(sound._active_music != null and sound._active_music.playing)
	assert(sound._active_music.bus == "Music")
	assert(sound._active_music.stream is AudioStreamOggVorbis)
	assert(sound._active_music.stream.loop)
	await create_timer(1.7).timeout
	music_capture.clear_buffer()
	paused = true
	await create_timer(0.3, true).timeout
	var music_energy := _energy(music_capture)
	assert(music_energy > 0.00001)
	assert(sound._active_music.playing)
	paused = false
	effect_capture.clear_buffer()
	sound.history.clear()
	Sound.play("load_complete")
	await create_timer(0.25).timeout
	var notification_energy := _energy(effect_capture)
	assert(notification_energy > 0.00001)
	assert(sound.history.count("load_complete") == 1)
	# Returning to the menu before a fade finishes must not stop its new voice.
	Sound.music("level")
	await create_timer(0.1).timeout
	Sound.music("menu")
	await create_timer(0.1).timeout
	Sound.music("level")
	Sound.music("menu")
	await create_timer(1.7).timeout
	assert(sound._music_id == "menu" and sound._active_music.playing)
	assert(sound._active_music.volume_db > -20)
	AudioServer.remove_bus_effect(music_bus, AudioServer.get_bus_effect_count(music_bus) - 1)
	AudioServer.remove_bus_effect(effect_bus, AudioServer.get_bus_effect_count(effect_bus) - 1)
	print("MENU_AUDIO_OK looping music on Music bus, audible while paused RMS=", music_energy, ", notification on SoundEffect RMS=", notification_energy, ", rapid fades remain playing")
	quit()
