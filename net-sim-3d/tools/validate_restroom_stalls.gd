extends SceneTree

var failures:=0
func _initialize() -> void:call_deferred("_run")
func check(ok:bool,note:String) -> void:
	if not ok:
		failures+=1
		push_error("STALL: "+note)

func wait_frames(count:int) -> void:
	for i in count:await physics_frame

func look(player:CharacterBody3D,at:Vector3) -> void:
	player.look_at(Vector3(at.x,player.global_position.y,at.z),Vector3.UP)
	var camera:Camera3D=player.get_node("Camera3D")
	var to:=at-camera.global_position
	camera.rotation=Vector3(atan2(to.y,Vector2(to.x,to.z).length()),0,0)

func walk(player:CharacterBody3D,to:Vector3) -> bool:
	Input.action_press("move_forward")
	for i in 160:
		var gap:=Vector2(to.x-player.global_position.x,to.z-player.global_position.z).length()
		if gap<.09:
			Input.action_release("move_forward")
			player.velocity=Vector3.ZERO
			return true
		look(player,to+Vector3(0,1.63,0))
		await physics_frame
	Input.action_release("move_forward")
	return false

func _run() -> void:
	var map:Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	await wait_frames(4)
	for student in map.get_node("CorridorStudents").students:
		student.process_mode=Node.PROCESS_MODE_DISABLED
	var player:CharacterBody3D=map.get_node("ITSupportPlayer")
	player.require_mouse_capture=false
	var rooms:Restrooms=map.get_node("Restrooms")
	check(rooms.stall_doors.size()==12,"twelve cubicle doors")
	Engine.physics_ticks_per_second=120
	Engine.time_scale=4
	for door in rooms.stall_doors:
		var initial_failures:=failures
		player.global_position=Vector3(-6.15,.02,-12)
		player.velocity=Vector3.ZERO
		await wait_frames(3)
		check(door.set_open(false,false),door.name+" can close initially")
		var centre:=door.global_transform*Vector3(door.width/2,0,0)
		var inward:=door.global_basis.z
		var outside:=centre-inward*.72+Vector3(0,.02,0)
		var inside:=centre+inward*1.18+Vector3(0,.02,0)
		player.global_position=outside;player.velocity=Vector3.ZERO
		look(player,centre+Vector3(0,1.5,0))
		await wait_frames(4)
		Input.action_press("move_forward")
		await wait_frames(20)
		Input.action_release("move_forward")
		check((player.global_position-centre).dot(inward)<-.20,door.name+" closed door is solid")
		check(player.focused_interactable==door,door.name+" F focus outside")
		player.interact()
		await wait_frames(20)
		check(door.is_open and not door.is_moving,door.name+" F opens from outside")
		check(await walk(player,inside),door.name+" can walk inside")
		# Aim at the actual open leaf, on the side wall, from inside the cubicle.
		var handle:=door.swing.global_transform*Vector3(door.width*.8,1.05,-.02)
		look(player,handle)
		await wait_frames(5)
		check(player.focused_interactable==door,door.name+" F focus inside")
		player.interact()
		await wait_frames(20)
		check(not door.is_open and not door.is_moving,door.name+" can close while inside")
		look(player,centre+Vector3(0,1.3,0))
		await wait_frames(5)
		check(player.focused_interactable==door,door.name+" closed door focus inside")
		player.interact()
		await wait_frames(20)
		check(door.is_open and not door.is_moving,door.name+" F opens from inside")
		check(await walk(player,outside),door.name+" can walk back out")
		player.global_position=centre+inward*.40+Vector3(0,.02,0)
		player.velocity=Vector3.ZERO
		await wait_frames(4)
		check(not door.set_open(false,false),door.name+" refuses to close through player")
		check(door.is_open,door.name+" stays open while blocked")
		player.global_position=outside;await wait_frames(3)
		check(door.set_open(false),door.name+" closes when clear")
		await wait_frames(20)
		print("STALL_VALIDATED " if failures==initial_failures else "STALL_FAILED ",door.name," walks=2 interaction_cycles=complete")
	var locale=root.get_node("L10n")
	var saved:String=locale.locale
	locale.locale="th"
	check(rooms.stall_doors[0].get_prompt_text().contains("คอก"),"Thai cubicle prompt")
	locale.locale="en"
	check(rooms.stall_doors[0].get_prompt_text().contains("Cubicle"),"English cubicle prompt")
	locale.locale=saved
	Engine.time_scale=1;Engine.physics_ticks_per_second=60
	print("RESTROOM_STALLS_VALID doors=12 walks=24 interaction=F language=th/en" if failures==0 else "RESTROOM_STALLS_INVALID failures="+str(failures))
	quit(1 if failures else 0)
