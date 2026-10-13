class_name Mission06State
extends Resource

## Progress of Mission 6 for one player. Plain data only — TeamViewerSim and
## Mission06Controller change it, Mission06SaveStore writes it to disk.

const SAVE_VERSION := 1

@export var call_answered: bool = false
@export var id_accepted_once: bool = false
@export var connected_once: bool = false
## The teacher's computer (remote side).
@export var remote_muted: bool = true
@export var remote_volume: int = 25
@export var teacher_confirmed: bool = false
@export var session_ended: bool = false
@export var teamviewer_closed: bool = false
@export var computer_off: bool = false
@export var completed: bool = false
@export var score: int = 100
@export var wrong_id_count: int = 0
@export var wrong_password_count: int = 0
@export var close_without_end_count: int = 0
## For a future reward system.
@export var reward_claimed: bool = false


func reset(data: Mission06Data) -> void:
	call_answered = false
	id_accepted_once = false
	connected_once = false
	remote_muted = true
	remote_volume = data.start_volume
	teacher_confirmed = false
	session_ended = false
	teamviewer_closed = false
	computer_off = false
	completed = false
	score = data.start_score
	wrong_id_count = 0
	wrong_password_count = 0
	close_without_end_count = 0
	reward_claimed = false
	emit_changed()


func penalise(points: int) -> void:
	score = maxi(0, score - points)
	emit_changed()


## Everything inside TeamViewer is done; only switching the computer off is left.
func ready_to_finish() -> bool:
	return teacher_confirmed and session_ended and teamviewer_closed


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"call_answered": call_answered,
		"id_accepted_once": id_accepted_once,
		"connected_once": connected_once,
		"remote_muted": remote_muted,
		"remote_volume": remote_volume,
		"teacher_confirmed": teacher_confirmed,
		"session_ended": session_ended,
		"teamviewer_closed": teamviewer_closed,
		"computer_off": computer_off,
		"completed": completed,
		"score": score,
		"wrong_id_count": wrong_id_count,
		"wrong_password_count": wrong_password_count,
		"close_without_end_count": close_without_end_count,
		"reward_claimed": reward_claimed,
	}


func from_dict(d: Dictionary, data: Mission06Data) -> void:
	reset(data)
	call_answered = bool(d.get("call_answered", false))
	id_accepted_once = bool(d.get("id_accepted_once", false))
	connected_once = call_answered and bool(d.get("connected_once", false))
	remote_muted = bool(d.get("remote_muted", true))
	remote_volume = clampi(int(d.get("remote_volume", data.start_volume)), 0, 100)
	teacher_confirmed = connected_once and bool(d.get("teacher_confirmed", false))
	session_ended = connected_once and bool(d.get("session_ended", false))
	teamviewer_closed = session_ended and bool(d.get("teamviewer_closed", false))
	computer_off = bool(d.get("computer_off", false))
	completed = ready_to_finish() and bool(d.get("completed", false))
	score = clampi(int(d.get("score", data.start_score)), 0, data.start_score)
	wrong_id_count = maxi(0, int(d.get("wrong_id_count", 0)))
	wrong_password_count = maxi(0, int(d.get("wrong_password_count", 0)))
	close_without_end_count = maxi(0, int(d.get("close_without_end_count", 0)))
	reward_claimed = bool(d.get("reward_claimed", false))
	emit_changed()
