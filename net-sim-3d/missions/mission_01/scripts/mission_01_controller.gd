class_name Mission01Controller
extends Node

## Runs Level 1 in the school map (added by GameFlow.configure_level):
##   1. talk to the Data Center supervisor -> "ได้รับภารกิจ", the timer starts and
##      NetPlan EDU appears on the player's computer (IT-PC-01)
##   2. pass the design in NetPlan EDU
##   3. leave the computer and report to the supervisor
##   4. score summary (30/50/20, stars) -> replay / menu / next level
## Every level start is a fresh attempt: the old Mission 1 save is cleared.

signal briefed
signal design_passed
signal finished(score: MissionScore)
signal replay_requested
signal menu_requested
signal next_requested

const LEVEL := 1
const PLAYER_COMPUTER := "IT-PC-01"

## "**...**" marks the important words, shown in gold by DialogueBox.
const BRIEFING := [
	"หัวหน้างาน Data Center|มีงานใหม่เข้ามาพอดี โรงเรียนกำลังเตรียมห้องคอมพิวเตอร์ห้องใหม่ มี**เครื่องนักเรียน 20 เครื่อง** และ**เครื่องครูอีก 1 เครื่อง**",
	"หัวหน้างาน Data Center|ตำแหน่งโต๊ะ จุดติดตั้ง และเส้นทางเดินสาย LAN ถูกกำหนดไว้เรียบร้อยแล้ว แต่เรายังต้อง**เลือกอุปกรณ์เครือข่าย**ให้เหมาะสมกับการใช้งาน",
	"หัวหน้างาน Data Center|ช่วยไปที่**คอมพิวเตอร์ของคุณ** เปิดไฟล์ Project ของห้องคอมใหม่ใน **NetPlan EDU** แล้วเลือกอุปกรณ์ให้ถูกต้อง**ทั้ง 3 จุด**ด้วยนะ",
	"คุณ|รับทราบครับ ผมจะตรวจสอบความต้องการและเลือกอุปกรณ์ให้เหมาะสมกับแต่ละจุด",
]
const REPORT := [
	"คุณ|ผมตรวจสอบและเลือกอุปกรณ์สำหรับห้องคอมใหม่เรียบร้อยแล้วครับ",
	"หัวหน้างาน Data Center|ดีมาก **การเลือกอุปกรณ์ให้ตรงกับหน้าที่**เป็นพื้นฐานสำคัญของการวางแผนระบบเครือข่าย แบบที่เลือกสามารถนำไปใช้เตรียมการติดตั้งในขั้นตอนต่อไปได้",
]
const NOT_DONE := [
	"หัวหน้างาน Data Center|ยังเลือกอุปกรณ์ไม่ครบหรือยังไม่ถูกต้องนะ กลับไปตรวจสอบใน **NetPlan EDU** ที่คอมพิวเตอร์ของคุณก่อน",
]
const RECEIVED := "ได้รับภารกิจ: เลือกอุปกรณ์เครือข่ายห้องคอมใหม่"

enum Stage { BRIEFING, DESIGN, REPORT, DONE }

var stage := Stage.BRIEFING
var elapsed_sec := 0.0
var data: Mission01Data
var state: Mission01State
var score: MissionScore
var hud: ObjectiveHUD
var dialogue: DialogueBox
var summary: MissionSummary
var talk: Talkable
var marker: ObjectiveMarker
var supervisor: Node3D
var manager: ComputerManager
var _timing := false


func _ready() -> void:
	data = load(NetPlanEdu.DATA_PATH) as Mission01Data
	Mission01SaveStore.clear()
	var world := get_parent()
	manager = world.get_node_or_null("Computers") as ComputerManager
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
	supervisor = world.get_node_or_null("ITSupportSupervisor") as Node3D
	if supervisor:
		talk = Talkable.new()
		talk.name = "Talk"
		talk.display_name = "หัวหน้างาน Data Center"
		supervisor.add_child(talk)
		talk.talked.connect(_on_talked)
	_set_app_installed(false)
	if manager and manager.desktop:
		manager.desktop.app_opened.connect(_on_app_opened)
		# Fold the objective panel while the player sits at a computer.
		var desktop := manager.desktop
		desktop.visibility_changed.connect(func(): hud.set_auto_collapsed(desktop.visible))
	_enter(Stage.BRIEFING)


func _process(delta: float) -> void:
	if _timing:
		elapsed_sec += delta


func _enter(next: Stage) -> void:
	stage = next
	match stage:
		Stage.BRIEFING:
			hud.set_objective("คุยกับหัวหน้างาน Data Center ในห้อง IT Support (มองที่หัวหน้างานแล้วกด F)")
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน Data Center")
			_point_at_supervisor()
		Stage.DESIGN:
			hud.set_objective("ไปที่คอมพิวเตอร์ของคุณ (%s) เปิด NetPlan EDU แล้วเลือกอุปกรณ์ให้ครบ 3 จุด" % PLAYER_COMPUTER)
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			_point_at_computer()
		Stage.REPORT:
			hud.set_objective("ออกจากคอมพิวเตอร์ แล้วกลับไปรายงานผลกับหัวหน้างาน Data Center")
			_set_prompt("กด F เพื่อรายงานผลกับหัวหน้างาน")
			_point_at_supervisor()
		Stage.DONE:
			hud.set_objective("")
			_set_prompt("")
			marker.clear()


func _point_at_supervisor() -> void:
	if supervisor:
		var seated: bool = supervisor is NpcCharacter and (supervisor as NpcCharacter).seated
		marker.point_at(supervisor, 1.75 if seated else 2.25)
	else:
		marker.clear()


func _point_at_computer() -> void:
	var station := manager.find_host(PLAYER_COMPUTER) if manager else null
	if station == null or station.screen == null:
		marker.clear()
		return
	var screen := station.screen
	marker.point_at_position(screen.global_transform * screen.get_aabb().get_center(), 0.42)


func _set_prompt(text: String) -> void:
	if talk:
		talk.prompt = text


func _set_app_installed(installed: bool) -> void:
	if manager == null:
		return
	var station := manager.find_host(PLAYER_COMPUTER)
	if station == null:
		return
	if installed and not station.has_app("netplan_edu"):
		station.installed_apps.append("netplan_edu")
	elif not installed:
		var i := station.installed_apps.find("netplan_edu")
		if i >= 0:
			station.installed_apps.remove_at(i)


func _on_talked(player: Node) -> void:
	match stage:
		Stage.BRIEFING:
			await _say(player, PackedStringArray(BRIEFING))
			_set_app_installed(true)
			_timing = true
			hud.show_toast(RECEIVED)
			_enter(Stage.DESIGN)
			briefed.emit()
		Stage.DESIGN:
			await _say(player, PackedStringArray(NOT_DONE))
		Stage.REPORT:
			await _say(player, PackedStringArray(REPORT), false)
			finish(player)


func _say(player: Node, lines: PackedStringArray, unlock_after: bool = true) -> void:
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	# The supervisor turns to the player first, then speaks.
	if supervisor is NpcCharacter and player is Node3D:
		await (supervisor as NpcCharacter).turn_to(player)
	dialogue.show_lines(lines)
	await dialogue.finished
	if supervisor is NpcCharacter:
		(supervisor as NpcCharacter).turn_back()
	if unlock_after and player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)


func _on_app_opened(app_id: String, app: Control) -> void:
	if app_id != "netplan_edu" or not app is NetPlanEdu:
		return
	var netplan := app as NetPlanEdu
	state = netplan.state
	if not netplan.mission_completed.is_connected(_on_design_passed):
		netplan.mission_completed.connect(_on_design_passed.bind(netplan))


func _on_design_passed(_final: int, _checks: int, _wrong: int, netplan: NetPlanEdu) -> void:
	state = netplan.state
	if stage == Stage.DESIGN:
		_enter(Stage.REPORT)
		hud.show_toast("แบบผ่านการตรวจสอบแล้ว — กลับไปรายงานหัวหน้างาน")
		design_passed.emit()


## Builds the score, records it and shows the summary. Also used by tests.
func finish(player: Node = null) -> MissionScore:
	_timing = false
	if state == null:
		state = Mission01State.new()
		Mission01SaveStore.load_into(state, data)
	score = Mission01Validator.mission_score(state, data, elapsed_sec)
	var record := GameProgress.record_attempt(LEVEL, score, {"check_count": state.check_count, "scored_reasons": state.scored_reasons.duplicate(true)})
	_enter(Stage.DONE)
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	var flow := get_tree().root.get_node_or_null("GameFlow")
	var next_available: bool = flow != null and flow.call("next_level_available", LEVEL)
	summary.show_result("สรุปผล — ภารกิจที่ 1 เลือกอุปกรณ์เครือข่ายห้องคอมใหม่", score, record, next_available)
	finished.emit(score)
	return score
