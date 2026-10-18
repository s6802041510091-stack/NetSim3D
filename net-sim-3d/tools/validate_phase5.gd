extends SceneTree

## Regression check for the production school, windows, and exterior district.
## Run with Godot's --headless --path net-sim-3d --script option.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Phase 5: main scene did not load")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	var visual: Node3D = main.get_node("MapVisual")
	var doors: Node3D = main.get_node("Doors")
	var computers: ComputerManager = main.get_node("Computers")
	var colliders: StaticBody3D = main.get_node("MapCollision")
	var exterior: Node3D = main.get_node("ExteriorTown")
	var glass_collision_count := 0
	for collision in colliders.get_children():
		if String(collision.name).begins_with("EW_"):
			glass_collision_count += 1
	var glass_visual_count := 0
	for mesh in visual.get_children():
		if String(mesh.name).begins_with("EW_") and String(mesh.name).contains("Glass"):
			glass_visual_count += 1
	var moving_door_count := 0
	for door in doors.get_children():
		if door.has_node("Swing/Collider"):
			moving_door_count += 1
	var staff_door: InteractiveDoor = doors.get_node("StaffDoor")
	var door_works := staff_door.set_open(true, false) and staff_door.is_open
	door_works = staff_door.set_open(false, false) and not staff_door.is_open and door_works
	var station := computers.find_host("IT-PC-01")
	var screen_works := station != null and station.screen != null
	if screen_works:
		station.set_screen_on(true)
		screen_works = station.screen.material_override != null
		station.set_screen_on(false)
	var passed := visual.get_child_count() >= 8900 \
		and moving_door_count == 8 and door_works \
		and computers.stations.size() == 29 and screen_works \
		and colliders.get_child_count() == 396 \
		and glass_collision_count == 62 and glass_visual_count == 62 \
		and int(exterior.get_meta("building_count", -1)) == 72
	print("PHASE5_VALIDATION visual=", visual.get_child_count(),
		" doors=", moving_door_count, " door_toggle=", door_works,
		" computers=", computers.stations.size(), " screen=", screen_works,
		" collision=", colliders.get_child_count(),
		" glass_collision=", glass_collision_count,
		" glass_visual=", glass_visual_count,
		" buildings=", exterior.get_meta("building_count", -1),
		" passed=", passed)
	quit(0 if passed else 1)
