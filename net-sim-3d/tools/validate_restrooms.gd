extends SceneTree

## Restrooms (scripts/props/restrooms.gd): built, light (few meshes), and a
## player can walk in through each door, round the privacy screen and to the
## basins, the stalls and the urinals without getting stuck.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_restrooms.gd
## With a window and `-- <out_dir>` it also saves screenshots.

var failures := 0
var out_dir := ""

const WALKS := {
	"women": [Vector3(-8.5, 0.0, -15.01), Vector3(-10.5, 0.0, -15.01), Vector3(-10.5, 0.0, -13.3), Vector3(-11.9, 0.0, -13.3),
		Vector3(-14.0, 0.0, -13.2), Vector3(-13.0, 0.0, -15.9), Vector3(-15.6, 0.0, -14.5), Vector3(-18.0, 0.0, -12.3)],
	"men": [Vector3(-8.5, 0.0, -22.8), Vector3(-10.5, 0.0, -22.8), Vector3(-10.5, 0.0, -21.2), Vector3(-11.9, 0.0, -21.2),
		Vector3(-15.0, 0.0, -19.2), Vector3(-14.2, 0.0, -18.3), Vector3(-18.6, 0.0, -21.0), Vector3(-17.0, 0.0, -22.8), Vector3(-13.2, 0.0, -22.9)],
}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print("  ok   " if ok else "  FAIL ", message)
	if not ok:
		failures += 1


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 4:
		await physics_frame
	var rooms := map.get_node_or_null("Restrooms") as Restrooms
	_check(rooms != null, "restrooms in the school scene")
	if rooms == null:
		quit(1)
		return
	var meshes := rooms.find_children("Mesh_*", "MeshInstance3D", false, false)
	var colliders := rooms.get_node("Colliders").get_child_count()
	_check(meshes.size() <= 16, "merged into %d meshes (one per material)" % meshes.size())
	_check(colliders > 40, "%d colliders for stalls, fixtures and screens" % colliders)
	for door_name in ["FemaleWCDoor", "MaleWCDoor"]:
		(map.get_node("Doors/" + door_name) as InteractiveDoor).set_open(true)
	await create_timer(1.0).timeout
	for i in 3:
		await physics_frame

	# A player-sized capsule along each walk must not hit anything.
	var space := map.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.6
	for room: String in WALKS:
		var points: Array = WALKS[room]
		for i in points.size() - 1:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY, (points[i] as Vector3) + Vector3(0, 0.9, 0))
			query.motion = (points[i + 1] as Vector3) - (points[i] as Vector3)
			var hit := space.cast_motion(query)
			_check(hit[0] >= 1.0, "%s: walk leg %d clear (%.2f)" % [room, i + 1, hit[0]])

	if out_dir != "":
		var camera := Camera3D.new()
		camera.fov = 70.0
		map.add_child(camera)
		camera.make_current()
		for view in [
				["wc_women_entry", Vector3(-10.6, 1.6, -13.2), Vector3(-15.0, 1.0, -13.0)],
				["wc_women_stalls", Vector3(-13.6, 1.6, -15.4), Vector3(-18.5, 0.8, -10.6)],
				["wc_women_basins", Vector3(-12.6, 1.6, -12.4), Vector3(-13.0, 1.0, -16.9)],
				["wc_women_stall_inside", Vector3(-17.66, 1.55, -12.1), Vector3(-17.66, 0.5, -10.0)],
				["wc_men_urinals", Vector3(-13.0, 1.6, -21.6), Vector3(-15.0, 0.9, -17.1)],
				["wc_men_stalls", Vector3(-15.0, 1.6, -19.6), Vector3(-20.4, 0.8, -22.5)],
				["wc_men_basins", Vector3(-13.6, 1.6, -19.8), Vector3(-13.2, 1.0, -24.0)],
				["wc_corridor_door", Vector3(-7.4, 1.6, -13.6), Vector3(-10.5, 1.2, -15.0)]]:
			camera.global_position = view[1]
			camera.look_at(view[2])
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir.path_join(view[0] + ".png"))
			print("SHOT ", view[0])
	print("RESTROOMS_VALID" if failures == 0 else "RESTROOMS_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
