extends SceneTree

## Records the desk phone's "handset picked up" sound (assets/audio/
## generated/phone_pickup.wav, variant grab_clunk chosen by the user on
## 2026-11-20 over two other mixes and a synthesised one) mixed from real
## recordings in
## assets/audio/kenney (CC0): a hand rustle as the handset is grabbed, the
## plastic hook switch clicking, the handset settling. The mix is played on a
## bus with AudioEffectRecord and saved as a WAV. Needs a real audio device
## (run WITH a window, not --headless):
##   godot --path net-sim-3d -s res://tools/audio/record_phone_pickup.gd -- <variant> <out.wav>
## Variants: [file, start s, volume dB, pitch] per layer.
const KENNEY := "res://assets/audio/kenney/"
const VARIANTS := {
	"grab_click": [["cloth1.ogg", 0.0, -2.0, 1.15], ["switch_002.ogg", 0.16, 0.0, 0.85]],
	"grab_latch": [["cloth2.ogg", 0.0, -3.0, 1.2], ["click_003.ogg", 0.12, -2.0, 0.7], ["switch_003.ogg", 0.2, -4.0, 0.9]],
	"grab_clunk": [["cloth1.ogg", 0.0, -4.0, 1.3], ["metalLatch.ogg", 0.1, -8.0, 1.6], ["switch_002.ogg", 0.18, -2.0, 0.75]],
}
const LENGTH := 0.9

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var variant: String = args[0]
	var out: String = args[1]
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "PickupRec")
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus, rec)
	await process_frame
	rec.set_recording_active(true)
	var start := Time.get_ticks_msec()
	var players: Array[AudioStreamPlayer] = []
	for layer: Array in VARIANTS[variant]:
		var p := AudioStreamPlayer.new()
		p.stream = load(KENNEY + String(layer[0]))
		p.bus = "PickupRec"
		p.volume_db = layer[2]
		p.pitch_scale = layer[3]
		root.add_child(p)
		players.append(p)
	for i in players.size():
		var at: float = VARIANTS[variant][i][1]
		while (Time.get_ticks_msec() - start) / 1000.0 < at:
			await process_frame
		players[i].play()
	while (Time.get_ticks_msec() - start) / 1000.0 < LENGTH:
		await process_frame
	rec.set_recording_active(false)
	var wav := _tidy(rec.get_recording())
	var error := wav.save_to_wav(out) if wav else FAILED
	print("RECORDED ", variant, " ", error_string(error), " ", out, " ", (wav.get_length() if wav else 0.0))
	quit(0 if error == OK else 1)


## Mono, the silence before and after cut off, and levelled: normalised
## with a soft compression so it is about as loud as the ring.
func _tidy(stereo: AudioStreamWAV) -> AudioStreamWAV:
	if stereo == null:
		return null
	var d := stereo.data
	var frames := d.size() / 4
	var x := PackedFloat32Array()
	x.resize(frames)
	var peak := 0.0
	for i in frames:
		x[i] = (d.decode_s16(i * 4) + d.decode_s16(i * 4 + 2)) / 65536.0
		peak = maxf(peak, absf(x[i]))
	var first := 0
	while first < frames and absf(x[first]) < peak * 0.01:
		first += 1
	var last := frames - 1
	while last > first and absf(x[last]) < peak * 0.01:
		last -= 1
	last = mini(frames - 1, last + int(stereo.mix_rate * 0.02))
	const DRIVE := 1.8
	var data := PackedByteArray()
	data.resize((last - first + 1) * 2)
	for i in range(first, last + 1):
		var s := tanh(DRIVE * x[i] / peak) / tanh(DRIVE)
		data.encode_s16((i - first) * 2, int(clampf(s * 0.9, -1.0, 1.0) * 32767.0))
	var mono := AudioStreamWAV.new()
	mono.format = AudioStreamWAV.FORMAT_16_BITS
	mono.mix_rate = stereo.mix_rate
	mono.stereo = false
	mono.data = data
	return mono
