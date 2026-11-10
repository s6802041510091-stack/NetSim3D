class_name Mission02Controller
extends Node

## Runs Level 2 in the school map (added by GameFlow.configure_level):
##   1. talk to the Data Center supervisor -> "ได้รับภารกิจ", the timer starts
##   2. pick up the 5 items on the spare desk in the IT Support room
##   3. (next steps of the round) choose cable types, crimp, test, install,
##      check the port LEDs, report -> summary
## Rules (ภารกิจ/ด่าน_02/README.md): every step once, no retries.

signal briefed
signal tools_gathered
signal replay_requested
signal menu_requested
signal next_requested

const LEVEL := 2
const SUPERVISOR := "หัวหน้างาน Data Center"

## "**...**" marks the important words, shown in gold by DialogueBox.
const BRIEFING := [
	"หัวหน้างาน Data Center|แบบอุปกรณ์ของห้องคอมใหม่ผ่านแล้ว ทีมติดตั้ง**Router** กับ **Switched Hub 24 Port** ไว้ใน Wall Rack ให้แล้ว ขั้นต่อไปเราต้อง**เตรียมสาย LAN**สำหรับติดตั้ง",
	"หัวหน้างาน Data Center|ใบงานนี้มีจุดเชื่อมต่อ **2 จุด** คือ **Router กับ Switched Hub** และ **Switched Hub กับคอมพิวเตอร์ครู** เลือกชนิดสายให้เหมาะกับแต่ละจุด แล้วเข้าหัวสายตามมาตรฐาน **T568B**",
	"หัวหน้างาน Data Center|อุปกรณ์อยู่บน**โต๊ะว่างในห้องนี้** หยิบให้ครบ แล้วตรวจสายด้วย **LAN Cable Tester** ให้เรียบร้อยก่อนนำไปติดตั้งที่ห้องคอม",
	"หัวหน้างาน Data Center|สายกับหัว RJ45 มีจำกัด งานนี้**ทำได้ครั้งเดียว** ค่อย ๆ ทำให้ถูกตั้งแต่แรกนะ",
	"คุณ|รับทราบครับ ผมจะเลือกสาย เข้าหัว ตรวจสอบ และนำสายไปเชื่อมต่อให้ถูกต้อง",
]
const GATHER_REMINDER := [
	"หัวหน้างาน Data Center|อุปกรณ์อยู่บน**โต๊ะว่างในห้องนี้** หยิบให้ครบ **5 อย่าง**ก่อนนะ",
]
const NEXT_REMINDER := [
	"หัวหน้างาน Data Center|อุปกรณ์ครบแล้ว ทำงานตามใบงานต่อได้เลย",
]
const RECEIVED := "ได้รับภารกิจ: เข้าหัวและเชื่อมต่อสาย LAN"

enum Stage { BRIEFING, GATHER, CRIMP, DONE }

var stage := Stage.BRIEFING
var elapsed_sec := 0.0
var hud: ObjectiveHUD
var dialogue: DialogueBox
var summary: MissionSummary
var talk: Talkable
var marker: ObjectiveMarker
var supervisor: Node3D
var props: Mission02Props
var _timing := false


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
	props = world.get_node_or_null("Mission02Props") as Mission02Props
	if props:
		props.set_items_available(false)
		for item: PickupItem in props.items.values():
			item.picked_up.connect(_on_item_picked)
	supervisor = world.get_node_or_null("ITSupportSupervisor") as Node3D
	if supervisor:
		talk = Talkable.new()
		talk.name = "Talk"
		talk.display_name = SUPERVISOR
		supervisor.add_child(talk)
		talk.talked.connect(_on_talked)
	var manager := world.get_node_or_null("Computers") as ComputerManager
	if manager and manager.desktop:
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
		Stage.GATHER:
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			_refresh_gather()
		Stage.CRIMP:
			hud.set_objective("นั่งที่โต๊ะว่างในห้อง IT Support เพื่อเข้าหัวสาย LAN (ขั้นตอนนี้กำลังสร้าง)")
			_set_prompt("กด F เพื่อคุยกับหัวหน้างาน")
			if props:
				marker.point_at_position(props.crimp_station.global_position, 0.45)
		Stage.DONE:
			hud.set_objective("")
			_set_prompt("")
			marker.clear()


## Objective "หยิบอุปกรณ์ (n/5)" with what is still on the desk, the arrow on the next item.
func _refresh_gather() -> void:
	if props == null:
		return
	var missing := props.missing_items()
	var total := props.items.size()
	hud.set_objective("หยิบอุปกรณ์บนโต๊ะว่างในห้อง IT Support (%d/%d)\nยังขาด: %s" % [total - missing.size(), total, ", ".join(missing)])
	for id: String in Mission02Props.ITEMS:
		var item: PickupItem = props.items[id]
		if not item.taken:
			marker.point_at_position(item.global_position, 0.3)
			return
	marker.clear()


func _point_at_supervisor() -> void:
	if supervisor:
		var seated: bool = supervisor is NpcCharacter and (supervisor as NpcCharacter).seated
		marker.point_at(supervisor, 1.75 if seated else 2.25)
	else:
		marker.clear()


func _set_prompt(text: String) -> void:
	if talk:
		talk.prompt = text


func _on_talked(player: Node) -> void:
	match stage:
		Stage.BRIEFING:
			await _say(player, PackedStringArray(BRIEFING))
			_timing = true
			hud.show_toast(RECEIVED)
			if props:
				props.set_items_available(true)
			_enter(Stage.GATHER)
			briefed.emit()
		Stage.GATHER:
			await _say(player, PackedStringArray(GATHER_REMINDER))
		_:
			await _say(player, PackedStringArray(NEXT_REMINDER))


func _on_item_picked(_item_id: String) -> void:
	if stage != Stage.GATHER:
		return
	if props.missing_items().is_empty():
		hud.show_toast("หยิบอุปกรณ์ครบแล้ว")
		_enter(Stage.CRIMP)
		tools_gathered.emit()
	else:
		_refresh_gather()


func _say(player: Node, lines: PackedStringArray, unlock_after: bool = true) -> void:
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	if supervisor is NpcCharacter and player is Node3D:
		await (supervisor as NpcCharacter).turn_to(player)
	dialogue.show_lines(lines)
	await dialogue.finished
	if supervisor is NpcCharacter:
		(supervisor as NpcCharacter).turn_back()
	if unlock_after and player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
