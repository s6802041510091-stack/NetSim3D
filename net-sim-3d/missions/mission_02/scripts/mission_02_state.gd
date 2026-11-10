class_name Mission02State
extends RefCounted

## What the player did in Mission 2 and the score (ภารกิจ/ด่าน_02/README.md).
## Every step is done once, so the first answer is the only answer.
##   correctness 30: the job works (all 4 ends T568B and the Router LAN port)
##   process 50:     A cable type 10, B T568B colours 24, D reading the
##                   tester 10, E Router port 6
##   time 20:        measured for real

const POINTS := [1, 2] # 1 = Router -> Switched Hub, 2 = Switched Hub -> teacher PC
const CABLE_TYPE_POINTS := 5.0 # per connection point
const COLOUR_POINTS := 6.0 # per cable end
const TESTER_POINTS := 5.0 # per cable
const PORT_POINTS := 6.0
const STRAIGHT := "straight_through"
const CROSSOVER := "crossover"

## point -> STRAIGHT / CROSSOVER
var cable_types := {}
## "1A", "1B", "2A", "2B" -> the 8 wire ids in the order the player crimped
var ends := {}
## cable (1, 2) -> true when the player said "pass" after testing
var tester_verdicts := {}
## The Router port the player used for cable 1 ("" = not yet).
var router_port := ""
## Cables the player discarded after a failed test: the supervisor gave a
## ready-made spare so the work can go on (the player's job still failed).
var spare_cables: Array[int] = []


## What the LAN cable tester shows for `cable`: for main LED 1-8 (and G), the
## remote LED that lights with it — the pin where the same wire sits at the
## other end (0 = no wire there).
func tester_mapping(cable: int) -> Array:
	var a: Array = ends.get("%dA" % cable, [])
	var b: Array = ends.get("%dB" % cable, [])
	var mapping := []
	for pin in 8:
		var wire: String = a[pin] if pin < a.size() else ""
		mapping.append(b.find(wire) + 1 if wire != "" else 0)
	mapping.append(9) # the shield / ground
	return mapping


## Records the verdict once. Returns false if this cable was already judged.
func set_verdict(cable: int, passes: bool) -> bool:
	if tester_verdicts.has(cable):
		return false
	tester_verdicts[cable] = passes
	if not passes and not cable_good(cable):
		spare_cables.append(cable)
	return true


## The cable that ends up installed works: the player's good cable, or a spare.
func installed_cable_works(cable: int) -> bool:
	return cable_good(cable) or cable in spare_cables


func set_cable_type(point: int, type: String) -> bool:
	if not point in POINTS or not type in [STRAIGHT, CROSSOVER] or cable_types.has(point):
		return false
	cable_types[point] = type
	return true


func cable_types_done() -> bool:
	return cable_types.size() == POINTS.size()


## A: 5 per connection point answered Straight-Through.
func cable_type_points() -> float:
	var total := 0.0
	for point in POINTS:
		if cable_types.get(point, "") == STRAIGHT:
			total += CABLE_TYPE_POINTS
	return total


## B: 6 per end, in proportion to the pins in T568B order.
func colour_points() -> float:
	var total := 0.0
	for key: String in ends:
		total += COLOUR_POINTS * WireColors.correct_positions(ends[key]) / 8.0
	return total


## A cable is good when both of its ends are fully T568B.
func cable_good(cable: int) -> bool:
	for side in ["A", "B"]:
		var key := "%d%s" % [cable, side]
		if not ends.has(key) or WireColors.correct_positions(ends[key]) != 8:
			return false
	return true


## D: 5 per cable when the verdict matches the real cable.
func tester_points() -> float:
	var total := 0.0
	for cable: int in tester_verdicts:
		if bool(tester_verdicts[cable]) == cable_good(cable):
			total += TESTER_POINTS
	return total


## E: the Router port is a LAN port.
func port_points() -> float:
	return PORT_POINTS if router_port.begins_with("router_lan") else 0.0


## The job works for real: both cables good and plugged into a Router LAN port.
func job_works() -> bool:
	return cable_good(1) and cable_good(2) and router_port.begins_with("router_lan")


func process_points() -> float:
	return cable_type_points() + colour_points() + tester_points() + port_points()


## Pins (1-8) of an end that are not in T568B order.
func wrong_pins(key: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var order: Array = ends.get(key, [])
	for i in 8:
		if i >= order.size() or String(order[i]) != WireColors.T568B[i]:
			out.append(i + 1)
	return out


## Right decisions / all decisions: cable types (2), ends fully T568B (4),
## tester verdicts (2), Router port (1).
func decision_counts() -> Vector2i:
	var ok := 0
	for point in POINTS:
		if cable_types.get(point, "") == STRAIGHT:
			ok += 1
	for key: String in ["1A", "1B", "2A", "2B"]:
		if ends.has(key) and wrong_pins(key).is_empty():
			ok += 1
	for cable in [1, 2]:
		if tester_verdicts.has(cable) and bool(tester_verdicts[cable]) == cable_good(cable):
			ok += 1
	if router_port.begins_with("router_lan"):
		ok += 1
	return Vector2i(ok, 9)


## The 100-point score: correctness 30 (job works) + process (A B D E) + time.
func mission_score(elapsed_sec: float, time_full_sec: float, time_zero_sec: float) -> MissionScore:
	var counts := decision_counts()
	var score := MissionScore.compute(30 if job_works() else 0, counts.x, counts.y, elapsed_sec, time_full_sec, time_zero_sec)
	# Weighted points (A10 B24 D10 E6), not a plain share of decisions.
	score.process = clampi(roundi(process_points()), 0, MissionScore.PROCESS_MAX)
	score.mistakes = mistakes()
	return score


## Short Thai lines for the summary's "จุดที่ผิดพลาด".
func mistakes() -> PackedStringArray:
	var out := PackedStringArray()
	const ROUTES := {1: "Router → Switched Hub", 2: "Switched Hub → คอมพิวเตอร์ครู"}
	for point in POINTS:
		if cable_types.get(point, "") == CROSSOVER:
			out.append("จุดเชื่อมต่อที่ %d (%s): เลือก Crossover Cable — อุปกรณ์ต่างชนิดกันต้องใช้ Straight-Through Cable" % [point, ROUTES[point]])
	for key: String in ["1A", "1B", "2A", "2B"]:
		var pins := wrong_pins(key)
		if ends.has(key) and not pins.is_empty():
			var names := []
			for pin in pins:
				names.append(str(pin))
			out.append("สายเส้นที่ %s ปลายที่ %s: เรียงสีไม่ตรง T568B ที่ขา %s" % [key.substr(0, 1), "1" if key.ends_with("A") else "2", ", ".join(PackedStringArray(names))])
	for cable in [1, 2]:
		if tester_verdicts.has(cable) and bool(tester_verdicts[cable]) != cable_good(cable):
			if cable_good(cable):
				out.append("สายเส้นที่ %d: อ่านผล Tester ผิด — ไฟตรงกันครบ สายใช้งานได้ แต่ตัดสินว่าต้องทิ้ง" % cable)
			else:
				out.append("สายเส้นที่ %d: อ่านผล Tester ผิด — ไฟไม่ตรงกัน สายใช้งานไม่ได้ แต่ตัดสินว่าผ่าน" % cable)
	if router_port == "router_wan":
		out.append("เสียบสายเส้นที่ 1 เข้าพอร์ต WAN ของ Router — พอร์ต WAN ใช้กับสายอินเทอร์เน็ต ต้องเสียบพอร์ต LAN ห้องคอมจึงไม่มีอินเทอร์เน็ต")
	for cable in spare_cables:
		out.append("สายเส้นที่ %d: สายที่เข้าหัวเองใช้งานไม่ได้ ต้องใช้สายสำรองแทน" % cable)
	if not job_works():
		out.append("ผลงานจึงยังใช้งานไม่ได้จริง (คะแนนความถูกต้อง 0)")
	return out
