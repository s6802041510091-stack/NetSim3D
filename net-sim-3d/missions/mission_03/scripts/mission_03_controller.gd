class_name Mission03Controller
extends Node

## Runs Level 3 in the school map (added by GameFlow.configure_level):
##   1. talk to the Data Center supervisor -> "ได้รับภารกิจ", the timer starts
##   2. computer room: on each of the three sample computers run ipconfig and
##      ping the Default Gateway, type the values into the checklist and
##      attach the row once (Mission03Checklist)
##   3. all three attached -> Network Inspection Report -> confirm
##   4. take the report back to the supervisor -> score (Mission03State) -> summary
## Inspect only (ภารกิจ/ด่าน_03/README.md): trying to change the system
## costs 5 points the first time and is always blocked; commands outside the
## task (tracert, netstat, ...) only get a notice.

signal briefed
signal row_attached(host: String)
signal report_done
signal finished(score: MissionScore)
signal replay_requested
signal menu_requested
signal next_requested

const LEVEL := 3
const SUPERVISOR := "หัวหน้างาน Data Center"
const TEACHER := "ครูประจำห้องคอมพิวเตอร์"

## "**...**" marks the important words, shown in gold by DialogueBox.
## The Default Gateway's number is never said: the player reads it from ipconfig.
const BRIEFING := [
	"หัวหน้างาน Data Center|การติดตั้งเครือข่ายในห้องคอมพิวเตอร์เสร็จเรียบร้อยแล้ว ก่อนเปิดให้ครูและนักเรียนใช้งาน เราต้อง**ตรวจรับการเชื่อมต่อ**ก่อน",
	"หัวหน้างาน Data Center|ให้คุณสุ่มตรวจคอมพิวเตอร์ตัวอย่าง **3 เครื่อง** ในห้องคอม คือ**เครื่องครู** **เครื่องนักเรียนหน้าห้อง** และ**เครื่องนักเรียนหลังห้อง**",
	"หัวหน้างาน Data Center|ใช้คำสั่ง **ipconfig** ดูข้อมูลเครือข่าย แล้วใช้ **ping** ตรวจว่าเครื่องติดต่อ **Default Gateway** ของเครื่องนั้นได้ไหม จากนั้นบันทึกผลลง**ใบตรวจ**ตามที่พบจริง",
	"หัวหน้างาน Data Center|ถ้าพบความผิดปกติให้**บันทึกไว้ก่อน** **ห้ามเปลี่ยนค่า ถอดสาย หรือรีสตาร์ต**อุปกรณ์ เพราะเราจะนำผลไปวิเคราะห์ในขั้นตอนถัดไป",
	"คุณ|รับทราบครับ ผมจะตรวจสอบและบันทึกผลโดยไม่เปลี่ยนแปลงระบบ",
]
const INSPECT_REMINDER := [
	"หัวหน้างาน Data Center|ตรวจเครื่องตัวอย่างในห้องคอมให้ครบ **3 เครื่อง** แนบผลลงใบตรวจ แล้วค่อยนำรายงานมาส่งนะ",
]
const TEACHER_FIRST := [
	"ครูประจำห้องคอมพิวเตอร์|สวัสดีครับ อ้าว ฝ่าย IT มาพอดีเลย",
	"ครูประจำห้องคอมพิวเตอร์|ได้ข่าวว่าวันนี้จะมาตรวจระบบเครือข่ายห้องนี้ก่อนเปิดให้นักเรียนใช้ใช่ไหมครับ ผมเลยยังไม่ให้นักเรียนเข้าห้อง",
	"คุณ|ใช่ครับ ต้องขอใช้**เครื่องครู**ตรวจด้วยครับ",
	"ครูประจำห้องคอมพิวเตอร์|ได้เลยครับ ผมเตรียมใบงานเสร็จพอดี เดี๋ยวผมลุกให้ แล้วไปรอที่**ห้องพักครู**นะครับ",
	"ครูประจำห้องคอมพิวเตอร์|ฝากเรื่องตรวจสอบระบบด้วยนะครับ ขอบคุณครับ",
	"คุณ|ยินดีครับ ผมจะตรวจให้เรียบร้อยครับ",
]
const TEACHER_AGAIN := [
	"ครูประจำห้องคอมพิวเตอร์|ตามสบายเลยครับ ฝากด้วยนะครับ",
]
## Level 3: the male teacher works at TEACHER-PC (same hand layout as his
## desk in the teachers' room: the computer 0.95 m ahead, seat 6 cm right).
const TEACHER_SEAT := Vector3(6.78, 0.02, -8.88)
## Facing the students (+Z).
const TEACHER_YAW := 0.0
const TEACHER_CHAIR := "Chair_TeacherDesk_1"
## From where he stands up (0.38 m behind the chair) to his desk in the
## teachers' room, through the computer-room door, the corridor and the
## teachers'-room door (swept against the map in tools/validate_mission_03.gd).
const WALK_TO_DOOR := [Vector3(-2.3, 0.02, -9.26), Vector3(-2.3, 0.02, -8.45)]
const WALK_CORRIDOR := [Vector3(-4.4, 0.02, -8.45), Vector3(-4.4, 0.02, -25.7)]
const WALK_STAFF_ROOM := [Vector3(-2.2, 0.02, -25.7), Vector3(5.4, 0.02, -25.0), Vector3(6.6, 0.02, -24.8), Vector3(6.6, 0.02, -21.39), Vector3(7.38, 0.02, -21.39)]
const ROOM_DOOR := "ClassroomDoor"
const STAFF_DOOR := "StaffDoor"
const HARM_MESSAGE := "ภารกิจนี้เป็นขั้นตอนการตรวจสอบ กรุณาบันทึกผลโดยไม่เปลี่ยนแปลงระบบ"
const OFF_TASK_MESSAGE := "คำสั่งนี้ไม่ใช่ภารกิจของคุณ"
## Commands that change the system (always blocked, the first try costs 5).
const HARM_COMMANDS := ["netsh", "shutdown", "network_edit", "unplug_cable"]
const HARM_IPCONFIG := ["/release", "/release6", "/renew", "/renew6"]
## Real commands that are not part of this task: a notice only.
const OFF_TASK_COMMANDS := ["tracert", "pathping", "netstat", "nslookup", "arp", "route", "getmac", "telnet", "ftp", "nbtstat"]
const RECEIVED := "ได้รับภารกิจ: ตรวจรับการเชื่อมต่อเครือข่ายห้องคอมพิวเตอร์"
const SUMMARY_TITLE := "ด่านที่ 3  ·  ตรวจรับการเชื่อมต่อเครือข่าย — ipconfig และ ping"
## Time score (placeholder until play-testing): full up to 8 min, 0 at 20 min.
const TIME_FULL_SEC := 480.0
const TIME_ZERO_SEC := 1200.0

enum Stage { BRIEFING, INSPECT, RETURN, DONE }

var stage := Stage.BRIEFING
var elapsed_sec := 0.0
var state := Mission03State.new()
var score: MissionScore
var hud: ObjectiveHUD
var dialogue: DialogueBox
var summary: MissionSummary
var marker: ObjectiveMarker
var checklist: Mission03Checklist
var report: Mission03Report
var talk: Talkable
var teacher_talk: Talkable
var supervisor: Node3D
var teacher: Node3D
var manager: ComputerManager
## Behind the back computer: pulling its LAN cable (forbidden).
var unplug_spot: InteractSpot
## host -> ComputerStation of the three sample computers.
var stations := {}
var _timing := false
var _teacher_met := false
var _speaking := false
## Where the teacher is: "desk" (at TEACHER-PC), "leaving", "staff_room".
var teacher_place := "desk"


## Seats the male teacher at TEACHER-PC, working (called by
## GameFlow.configure_level before the world enters the tree). TEACHER-PC is
## his until the player talks to him and he leaves for the teachers' room.
static func seat_teacher(world: Node) -> void:
	var person := world.get_node_or_null("TeacherMale") as CharacterBody3D
	if person == null:
		return
	var info: Dictionary = StaffRoomLife.TEACHERS["male"].duplicate(true)
	info["seat"] = TEACHER_SEAT
	info["host"] = "TEACHER-PC"
	info.erase("chair")
	StaffRoomLife._seat(world, person, info)
	person.rotation = Vector3(0.0, TEACHER_YAW, 0.0)
	StaffRoomLife.align_chair(world, TEACHER_CHAIR, TEACHER_SEAT, TEACHER_YAW)
	# His own chair in the teachers' room, ready for when he gets back.
	StaffRoomLife.align_chair(world, String(StaffRoomLife.TEACHERS["male"]["chair"]), StaffRoomLife.seat_of("male"), PI * 0.5)


func _ready() -> void:
	var world := get_parent()
	hud = ObjectiveHUD.new()
	hud.name = "ObjectiveHUD"
	add_child(hud)
	dialogue = DialogueBox.new()
	dialogue.name = "DialogueBox"
	add_child(dialogue)
	summary = MissionSummary.new()
	summary.name = "MissionSummary"
	add_child(summary)
	summary.replay_requested.connect(func(): replay_requested.emit())
	summary.menu_requested.connect(func(): menu_requested.emit())
	summary.next_requested.connect(func(): next_requested.emit())
	marker = ObjectiveMarker.new()
	marker.name = "ObjectiveMarker"
	add_child(marker)
	checklist = Mission03Checklist.new()
	checklist.name = "Checklist"
	add_child(checklist)
	checklist.setup(state)
	checklist.attached.connect(_on_attached)
	checklist.side_panel.collapsed_changed.connect(func(_folded: bool):
		if checklist.is_open():
			hud.right_inset = checklist.side_panel.covered_width())
	report = Mission03Report.new()
	report.name = "Report"
	add_child(report)
	report.confirmed.connect(_on_report_confirmed)
	manager = world.get_node_or_null("Computers") as ComputerManager
	if manager:
		for host: String in Mission03State.TARGETS:
			var station := manager.find_host(host)
			if station == null:
				push_error("Mission 3: computer %s not found" % host)
				continue
			stations[host] = station
			# The bad crimp exists only in this level.
			station.link_fault = host == Mission03State.FAULTY
			state.set_expected(host, station.ip_address, station.subnet_mask, station.gateway, not station.link_fault)
		if manager.desktop:
			var desktop := manager.desktop
			desktop.command_guard = guard
			desktop.command_run.connect(_on_command_run)
			desktop.ping_done.connect(_on_ping_done)
			desktop.desktop_ready.connect(_on_desktop_ready)
			desktop.visibility_changed.connect(_on_desktop_visibility)
	unplug_spot = InteractSpot.new()
	unplug_spot.name = "UnplugSpot"
	unplug_spot.size = Vector3(0.4, 0.35, 0.3)
	add_child(unplug_spot)
	var faulty: ComputerStation = stations.get(Mission03State.FAULTY)
	if faulty:
		var back := -faulty.global_basis.z.normalized()
		unplug_spot.global_position = faulty.global_position + back * 0.25 + Vector3.DOWN * 0.2
	unplug_spot.used.connect(func(_player: Node): try_unplug())
	supervisor = world.get_node_or_null("ITSupportSupervisor") as Node3D
	if supervisor:
		talk = Talkable.new()
		talk.name = "Talk"
		talk.display_name = SUPERVISOR
		supervisor.add_child(talk)
		talk.talked.connect(_on_talked)
	teacher = world.get_node_or_null("TeacherMale") as Node3D
	if teacher:
		teacher_talk = Talkable.new()
		teacher_talk.name = "Talk"
		teacher_talk.display_name = TEACHER
		teacher_talk.prompt = "กด F เพื่อคุยกับ" + TEACHER
		teacher.add_child(teacher_talk)
		teacher_talk.talked.connect(_on_teacher_talked)
	_enter(Stage.BRIEFING)


func _exit_tree() -> void:
	if manager and manager.desktop and manager.desktop.command_guard == Callable(self, "guard"):
		manager.desktop.command_guard = Callable()


func _process(delta: float) -> void:
	if _timing:
		elapsed_sec += delta


## The mission's steps in order (ObjectiveHUD.set_steps, the same in every level).
const HEADING := "ตรวจรับการเชื่อมต่อเครือข่ายห้องคอมพิวเตอร์"
const STEP_TITLE := "ภารกิจที่ 3"
const STEPS := [
	"รับภารกิจจากหัวหน้างาน Data Center",
	"ขอใช้เครื่องครูจากครูประจำห้องคอมพิวเตอร์",
	"ตรวจคอมพิวเตอร์ครู (TEACHER-PC)",
	"ตรวจคอมพิวเตอร์นักเรียนหน้าห้อง (PC-R1-L1)",
	"ตรวจคอมพิวเตอร์นักเรียนหลังห้อง (PC-R5-R2)",
	"ยืนยัน Network Inspection Report",
	"ส่งรายงานให้หัวหน้างาน Data Center",
]


func _enter(next: Stage) -> void:
	stage = next
	match stage:
		Stage.BRIEFING:
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน Data Center")
			unplug_spot.set_prompt("")
			_point_at_supervisor()
		Stage.INSPECT:
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			unplug_spot.set_prompt("กด F เพื่อถอดสาย LAN ของเครื่องนี้")
			_refresh_inspect()
		Stage.RETURN:
			_set_prompt("กด F เพื่อส่งรายงานให้หัวหน้างาน")
			unplug_spot.set_prompt("")
			_point_at_supervisor()
		Stage.DONE:
			_set_prompt("")
			unplug_spot.set_prompt("")
			marker.clear()
	_show_steps()


## The step tracker: which step is current and what to do there.
## The teacher may be met before the briefing, so steps are marked by what
## is finished (the first unfinished one is current).
const STEP_HINTS := [
	"ไปที่ห้อง IT Support มองที่หัวหน้างานแล้วกด F",
	"ครูประจำห้องกำลังใช้เครื่องครูอยู่ ไปที่ห้องคอมพิวเตอร์ มองที่ครูแล้วกด F",
	"ไปที่เครื่องในห้องคอมพิวเตอร์ กด F เพื่อนั่ง ใช้ ipconfig และ ping แล้วกรอกใบตรวจ",
	"ไปที่เครื่องในห้องคอมพิวเตอร์ กด F เพื่อนั่ง ใช้ ipconfig และ ping แล้วกรอกใบตรวจ",
	"ไปที่เครื่องในห้องคอมพิวเตอร์ กด F เพื่อนั่ง ใช้ ipconfig และ ping แล้วกรอกใบตรวจ",
	"ตรวจความครบถ้วนของรายงาน แล้วกดยืนยันรายงาน",
	"กลับไปห้อง IT Support มองที่หัวหน้างานแล้วกด F",
]


func _show_steps() -> void:
	if stage == Stage.DONE:
		hud.set_objective("")
		return
	var done := [stage != Stage.BRIEFING, _teacher_met]
	for host: String in Mission03State.TARGETS:
		done.append(state.records.has(host))
	done.append(state.report_confirmed)
	done.append(false)
	var step_list := ObjectiveHUD.from_done(STEPS, done)
	var hint := ""
	for i in step_list.size():
		if step_list[i][1] == ObjectiveHUD.STEP_ACTIVE:
			hint = STEP_HINTS[i]
	hud.set_steps(step_list, hint, HEADING, STEP_TITLE)


## Objective and arrow: the next sample computer not attached yet.
func _refresh_inspect() -> void:
	if stage != Stage.INSPECT:
		return
	_show_steps()
	var next := next_target()
	if manager and manager.desktop and manager.desktop.visible:
		marker.clear()
	elif next == "TEACHER-PC" and teacher_place == "desk" and teacher:
		# The teacher still works at it: talk to him first.
		marker.point_at(teacher, 1.75)
	elif next != "" and stations.has(next):
		marker.point_at_position((stations[next] as ComputerStation).global_position, 0.45)
	else:
		marker.clear()


func next_target() -> String:
	for host: String in Mission03State.TARGETS:
		if not state.records.has(host):
			return host
	return ""


func _point_at_supervisor() -> void:
	if supervisor:
		var seated: bool = supervisor is NpcCharacter and (supervisor as NpcCharacter).seated
		marker.point_at(supervisor, 1.75 if seated else 2.25)
	else:
		marker.clear()


func _set_prompt(text: String) -> void:
	if talk:
		talk.prompt = text


# ---------------------------------------------------------------- guard

## DesktopOS.command_guard: "" lets the action run, otherwise the notice.
func guard(action: String, args: PackedStringArray) -> String:
	var first := args[0].to_lower() if args.size() > 0 else ""
	if action in HARM_COMMANDS or (action == "ipconfig" and first in HARM_IPCONFIG):
		var what := action if args.is_empty() else "%s %s" % [action, " ".join(args)]
		if action == "network_edit":
			what = "แก้ไขการตั้งค่า IP"
		elif action == "unplug_cable":
			what = "ถอดสาย LAN"
		_harm(what)
		return HARM_MESSAGE
	if action in OFF_TASK_COMMANDS or (action == "ipconfig" and first != "" and first != "/all"):
		return OFF_TASK_MESSAGE
	return ""


func _harm(what: String) -> void:
	state.note_harm(what)
	Sound.play("wrong")
	hud.show_toast(HARM_MESSAGE, 4.0)


## Pulling the back computer's LAN cable: refused like the commands.
func try_unplug() -> void:
	if stage == Stage.INSPECT:
		guard("unplug_cable", PackedStringArray())


# ---------------------------------------------------------------- computers

func _current_host() -> String:
	if manager and manager.desktop and manager.desktop.station:
		return manager.desktop.station.hostname
	return ""


## The checklist opens only at the computer whose turn it is (strict order:
## teacher -> front -> back); another sample computer gets a reminder.
func _on_desktop_ready() -> void:
	var host := _current_host()
	marker.clear()
	if stage != Stage.INSPECT or not host in Mission03State.TARGETS or state.records.has(host):
		return
	var next := next_target()
	if host != next:
		Sound.play("wrong")
		hud.show_toast("ตรวจตามลำดับ: ตรวจ%s (%s) ก่อน" % [Mission03State.TITLES[next], next], 4.0)
		return
	checklist.open(host)
	# Keep the objective tab and new windows clear of the checklist.
	hud.right_inset = checklist.side_panel.covered_width()
	manager.desktop.reserved_right = checklist.side_panel.covered_width()


func _on_desktop_visibility() -> void:
	var on := manager.desktop.visible
	hud.set_auto_collapsed(on)
	if not on:
		checklist.close()
		hud.right_inset = 0.0
		manager.desktop.reserved_right = 0.0
		if stage == Stage.INSPECT:
			_refresh_inspect()
		elif stage == Stage.RETURN:
			_point_at_supervisor()
	else:
		marker.clear()


func _on_command_run(line: String) -> void:
	if stage != Stage.INSPECT:
		return
	if line.to_lower().begins_with("ipconfig") and _current_host() == next_target():
		state.note_ipconfig(_current_host())
		checklist.refresh()


func _on_ping_done(target: String, _address: String, _received: int) -> void:
	if stage != Stage.INSPECT or _current_host() != next_target():
		return
	state.note_ping(_current_host(), target)
	checklist.refresh()


func _on_attached(host: String) -> void:
	row_attached.emit(host)
	hud.show_toast("แนบผลการตรวจ %s แล้ว (%d/3)" % [host, state.records.size()], 3.0)
	_refresh_inspect()
	if state.all_attached():
		checklist.close()
		hud.right_inset = 0.0
		report.open(state)


func _on_report_confirmed() -> void:
	report_done.emit()
	hud.show_toast("ยืนยันรายงานแล้ว — นำไปส่งหัวหน้างาน Data Center", 4.0)
	_enter(Stage.RETURN)
	if manager and manager.active_station != null:
		manager.close_computer()


## Esc must not close the computer while the report waits for confirming.
func _input(event: InputEvent) -> void:
	if report.is_open() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- people

func _on_talked(player: Node) -> void:
	if _speaking:
		return
	match stage:
		Stage.BRIEFING:
			await _say(player, supervisor, PackedStringArray(BRIEFING))
			_timing = true
			hud.show_toast(RECEIVED)
			Sound.play("objective")
			briefed.emit()
			_enter(Stage.INSPECT)
		Stage.INSPECT:
			await _say(player, supervisor, PackedStringArray(INSPECT_REMINDER))
		Stage.RETURN:
			await _say(player, supervisor, report_lines(), false)
			hud.show_toast("ภารกิจที่ 3 เสร็จสิ้น")
			finish(player)


func _on_teacher_talked(player: Node) -> void:
	if _speaking or teacher_place == "leaving":
		return
	var first := not _teacher_met
	_teacher_met = true
	await _say(player, teacher, PackedStringArray(TEACHER_FIRST if first else TEACHER_AGAIN))
	if first and teacher_place == "desk":
		teacher_leave()


## After the first talk: he stands up (TEACHER-PC is free from then on),
## walks out through the corridor to the teachers' room and sits at his own
## desk (STAFF-PC-02), where F gives a short line again.
func teacher_leave() -> void:
	if teacher_place != "desk" or not teacher is NpcCharacter:
		return
	var person := teacher as NpcCharacter
	teacher_place = "leaving"
	teacher_talk.prompt = ""
	_show_steps()
	await person.stand_up()
	var pc: ComputerStation = stations.get("TEACHER-PC")
	if pc:
		pc.collision_layer = ComputerStation.COLLISION_LAYER
	if stage == Stage.INSPECT:
		_refresh_inspect()
	await person.walk_path(WALK_TO_DOOR)
	await _through_door(person, ROOM_DOOR, WALK_CORRIDOR)
	await _through_door(person, STAFF_DOOR, WALK_STAFF_ROOM)
	if not is_inside_tree():
		return
	await person.face_yaw(PI * 0.5)
	# Sits at his own desk now (the pose is the one he stood up from).
	person._seat_xform = Transform3D(Basis(Vector3.UP, PI * 0.5), StaffRoomLife.seat_of("male"))
	await person.sit_down()
	if manager:
		var staff_pc := manager.find_host(String(StaffRoomLife.TEACHERS["male"]["host"]))
		if staff_pc:
			staff_pc.collision_layer = 0
	teacher_place = "staff_room"
	teacher_talk.prompt = "กด F เพื่อทักทาย" + TEACHER


## Opens `door_name`, walks `path` through it, closes it behind him.
func _through_door(person: NpcCharacter, door_name: String, path: Array) -> void:
	var door := get_parent().get_node_or_null("Doors/" + door_name) as InteractiveDoor
	if door:
		door.set_open(true)
		await get_tree().create_timer(door.swing_time, false).timeout
	await person.walk_path([path[0]])
	if door:
		_close_when_clear(door)
	await person.walk_path(path.slice(1))


## Shuts the door as soon as nobody stands in its swing (tries for 8 s).
func _close_when_clear(door: InteractiveDoor) -> void:
	for i in 32:
		if not is_inside_tree() or not door.is_open:
			return
		if not door.is_moving and door.set_open(false):
			return
		await get_tree().create_timer(0.25, false).timeout


## What the player reports (from the report as written) and the supervisor's answer.
func report_lines() -> PackedStringArray:
	var normal := PackedStringArray()
	var abnormal := PackedStringArray()
	for host: String in Mission03State.TARGETS:
		var r: Dictionary = state.records.get(host, {})
		var name := String(Mission03State.TITLES[host]).replace("คอมพิวเตอร์", "เครื่อง")
		if r.get("status", "") == Mission03State.ABNORMAL:
			abnormal.append(name)
		else:
			normal.append(name)
	var said := "ผมตรวจสอบเครื่องตัวอย่างครบทั้งสามเครื่องแล้วครับ "
	if abnormal.is_empty():
		said += "ทุกเครื่องทำงานปกติครับ"
	elif normal.is_empty():
		said += "ทุกเครื่องไม่สามารถติดต่อ Default Gateway ได้ครับ"
	else:
		said += "%sทำงานปกติ แต่%sไม่สามารถติดต่อ Default Gateway ได้ครับ" % [" และ".join(normal), " และ".join(abnormal)]
	var lines := PackedStringArray(["คุณ|" + said])
	var all_right := true
	for host: String in Mission03State.TARGETS:
		all_right = all_right and state.row_right(host)
	if all_right:
		lines.append("หัวหน้างาน Data Center|รับทราบ ตอนนี้เราทราบแล้วว่าเกิด**ความผิดปกติที่เครื่องใด** ขั้นตอนต่อไปต้อง**วิเคราะห์หาสาเหตุและแก้ไข**ให้กลับมาใช้งานได้")
	else:
		lines.append("หัวหน้างาน Data Center|ขอบคุณ แต่รายงานบางส่วน**ไม่ตรงกับผลคำสั่งจริง** ถ้ารายงานผิด การวิเคราะห์ขั้นต่อไปก็จะผิดตามไปด้วย ลองดู**จุดที่ผิดพลาด**ในสรุปผลนะ")
	if state.altered:
		lines.append("หัวหน้างาน Data Center|อีกเรื่องหนึ่ง งานนี้เป็น**การตรวจสอบเท่านั้น** ครั้งหน้าอย่าพยายามเปลี่ยนค่าหรือถอดสายระหว่างตรวจนะ")
	return lines


## Builds the score, records it and shows the summary. Also used by tests.
func finish(player: Node = null) -> MissionScore:
	_timing = false
	score = state.mission_score(elapsed_sec, TIME_FULL_SEC, TIME_ZERO_SEC)
	var record := GameProgress.record_attempt(LEVEL, score, {
		"records": state.records.duplicate(true), "activity": state.activity.duplicate(true),
		"altered": state.altered, "harm_attempts": Array(state.harm_attempts)})
	_enter(Stage.DONE)
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var next_available: bool = flow != null and flow.call("next_level_available", LEVEL)
	var rows_ok := 0
	var pings_ok := 0
	var values_ok := 0
	var status_ok := 0
	for host: String in Mission03State.TARGETS:
		rows_ok += int(state.row_right(host))
		pings_ok += int(state.pinged_gateway(host))
		values_ok += int(state.values_right(host))
		status_ok += int(state.status_right(host))
	summary.show_result(SUMMARY_TITLE, score, record, next_available, [
		["รายงานถูกต้องทั้งแถว", "%d จาก 3 เครื่อง" % rows_ok],
		["ping ไปที่ Default Gateway", "%d จาก 3 เครื่อง" % pings_ok],
		["บันทึก IP / Subnet Mask / Gateway", "ถูก %d จาก 3 เครื่อง" % values_ok],
		["ตัดสินสถานะปกติ / ผิดปกติ", "ถูก %d จาก 3 เครื่อง" % status_ok],
		["เปลี่ยนแปลงระบบระหว่างตรวจ", "ไม่มี" if not state.altered else "มี (%s)" % state.harm_attempts[0]],
	])
	finished.emit(score)
	return score


func _say(player: Node, speaker: Node3D, lines: PackedStringArray, unlock_after: bool = true) -> void:
	_speaking = true
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	if speaker and speaker.has_method("turn_to") and player is Node3D:
		await speaker.call("turn_to", player)
	dialogue.show_lines(lines)
	await dialogue.finished
	if speaker and speaker.has_method("turn_back"):
		speaker.call("turn_back")
	if unlock_after and player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_speaking = false
