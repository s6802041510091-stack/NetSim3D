extends SceneTree

## Screenshots of the summary with every red-pen word (2026-11-24), each at a
## score of its own group, plus one sheet with all of them. Also checks that
## praise_for() puts each score in the group its word belongs to.
## Run WITH a window (it draws text):
##   godot --path net-sim-3d -s res://tools/capture_pen_marks.gd -- <out_dir>
## Default out_dir: Preview/หน้าสรุป_คำชม/

const CASES := [
	# [word, correctness, process, time] -> total
	["ยอดเยี่ยม", 30, 50, 20], # 100, rainbow
	["2/10", 30, 40, 15], # 85, rainbow
	["ปังมากแม่", 28, 34, 12], # 74, 3 stars
	["ยินดีด้วย", 25, 30, 10], # 65, 2 stars
	["เก่งมาก", 22, 30, 10], # 62, 2 stars
	["ครั้งหน้าพยายามให้มากขึ้นนะ", 20, 28, 7], # 55, 1 star
	["พยายามต่อไปนะ", 20, 25, 7], # 52, 1 star
	["ควรพยายามให้มากกว่านี้นะ", 6, 10, 5], # 21, not passed
]
## The summary card on a 1280 x 720 window.
const CARD := Rect2i(232, 114, 816, 492)

var out_dir := ""
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://../Preview/หน้าสรุป_คำชม")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	await process_frame
	var flow := root.get_node_or_null("GameFlow")
	if flow:
		flow._layer.hide()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.32, 0.36, 0.42)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var shots: Array[Image] = []
	for i in CASES.size():
		var c: Array = CASES[i]
		var score := MissionScore.new()
		score.correctness = c[1]
		score.process = c[2]
		score.time = c[3]
		score.elapsed_sec = 300.0
		var group: Array = MissionSummary.PRAISE_TRY
		if score.stars() >= 3:
			group = MissionSummary.PRAISE_TOP
		elif score.stars() == 2:
			group = MissionSummary.PRAISE_PASS
		elif score.stars() == 1:
			group = MissionSummary.PRAISE_ONE
		var ok: bool = String(c[0]) in group
		print("%s %d คะแนน (%d ดาว) -> %s" % ["ok  " if ok else "FAIL", score.total(), score.stars(), c[0]])
		if not ok:
			failures += 1
		var summary := MissionSummary.new()
		root.add_child(summary)
		summary.show_result("ด่านที่ 1  ·  ออกแบบเครือข่าย — เลือกอุปกรณ์เครือข่ายห้องคอม", score, {"best_total": score.total(), "attempts": 1}, score.passed())
		summary.pen_mark.word = String(c[0])
		await create_timer(2.8).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var name := "%d_%d_คะแนน" % [i + 1, score.total()]
		image.save_png(out_dir.path_join(name + ".png"))
		shots.append(image.get_region(CARD))
		print("SHOT ", name)
		summary.queue_free()
		await process_frame
	# One sheet: two columns, a little smaller.
	var scale := 0.62
	var w := int(CARD.size.x * scale)
	var h := int(CARD.size.y * scale)
	var pad := 16
	var cols := 2
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(cols * w + (cols + 1) * pad, rows * h + (rows + 1) * pad, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.93, 0.94, 0.96))
	for i in shots.size():
		var small := shots[i].duplicate() as Image
		small.convert(Image.FORMAT_RGBA8)
		small.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(pad + (i % cols) * (w + pad), pad + (i / cols) * (h + pad)))
	sheet.save_png(out_dir.path_join("all_praise.png"))
	print("SHEET ", out_dir.path_join("all_praise.png"))
	print("PEN_MARKS_DONE failures=%d" % failures)
	quit(1 if failures else 0)
