class_name Mission05State
extends Resource

## Progress of Mission 5 for one player. Plain data only — WindowsSecurity
## changes it, Mission05SaveStore writes it to disk. to_dict()/from_dict()
## let a future shared save system store it instead.

enum ScanStatus { NOT_SCANNED, SCANNED }

const SAVE_VERSION := 1

@export var app_opened: bool = false
@export var firewall_blocked: bool = false
@export var scan_status: ScanStatus = ScanStatus.NOT_SCANNED
@export var threat_quarantined: bool = false
@export var score: int = 100
## Every wrong choice in order, e.g. ["firewall:allow", "threat:exclude"].
@export var wrong_choices: PackedStringArray = PackedStringArray()
## True after the player pressed "ส่งผลการตรวจสอบ" in the program.
@export var report_submitted: bool = false
## For the mission system: set when the player has reported to the Data Center supervisor.
@export var reported_to_supervisor: bool = false
## For a future reward system: set once the reward for this mission is given.
@export var reward_claimed: bool = false


func reset(data: Mission05Data) -> void:
	app_opened = false
	firewall_blocked = false
	scan_status = ScanStatus.NOT_SCANNED
	threat_quarantined = false
	score = data.start_score
	wrong_choices = PackedStringArray()
	report_submitted = false
	reported_to_supervisor = false
	reward_claimed = false
	emit_changed()


## Security status: Protected (both parts done).
func is_protected() -> bool:
	return firewall_blocked and scan_status == ScanStatus.SCANNED and threat_quarantined


func wrong_count() -> int:
	return wrong_choices.size()


func add_wrong(part: String, choice_id: String, penalty: int) -> void:
	wrong_choices.append("%s:%s" % [part, choice_id])
	score = maxi(0, score - penalty)
	emit_changed()


# ---------------------------------------------------------------- save format

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"app_opened": app_opened,
		"firewall_blocked": firewall_blocked,
		"scan_completed": scan_status == ScanStatus.SCANNED,
		"threat_quarantined": threat_quarantined,
		"score": score,
		"wrong_choices": Array(wrong_choices),
		"protected": is_protected(),
		"report_submitted": report_submitted,
		"reported_to_supervisor": reported_to_supervisor,
		"reward_claimed": reward_claimed,
	}


## Loads values saved by to_dict(). Broken values are ignored, so an old or
## damaged save never crashes the mission.
func from_dict(d: Dictionary, data: Mission05Data) -> void:
	reset(data)
	app_opened = bool(d.get("app_opened", false))
	firewall_blocked = bool(d.get("firewall_blocked", false))
	scan_status = ScanStatus.SCANNED if bool(d.get("scan_completed", false)) else ScanStatus.NOT_SCANNED
	# A file can only be quarantined after a scan found it.
	threat_quarantined = scan_status == ScanStatus.SCANNED and bool(d.get("threat_quarantined", false))
	score = clampi(int(d.get("score", data.start_score)), 0, data.start_score)
	var w: Variant = d.get("wrong_choices", [])
	if w is Array:
		for v in w:
			wrong_choices.append(str(v))
	report_submitted = is_protected() and bool(d.get("report_submitted", false))
	reported_to_supervisor = report_submitted and bool(d.get("reported_to_supervisor", false))
	reward_claimed = bool(d.get("reward_claimed", false))
	emit_changed()
