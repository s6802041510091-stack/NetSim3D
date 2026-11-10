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
