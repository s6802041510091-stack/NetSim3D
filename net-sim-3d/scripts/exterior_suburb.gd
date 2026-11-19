class_name JapaneseSuburb
extends Node3D

## The Japanese suburb around the school, built in code (2026-11-20, the
## user's choice: the old district was 72 copies of a CC-BY model, 2.24 M
## triangles and a 16 MB file). Low-poly and light: everything static is
## merged into one mesh per material, coloured per vertex (no textures):
##   * inner ring of plots: two-storey houses (gable or hip tiled roofs,
##     balconies, block walls, a kei car in some drives, AC units), two
##     convenience stores on corners, small apartment blocks;
##   * outer ring: three-storey apartment blocks ("mansions") and houses;
##   * utility poles with sagging wires along the ring roads, vending
##     machines;
##   * far ring: simple houses so the ground meets the painted horizon;
##   * an elevated railway on the east (seen from the computer room) with a
##     commuter train passing about once a minute, kei cars driving on the
##     left on both ring roads.
## Visual only: nothing here collides. Shops and trains carry no real brand.

const GROUND_Y := -7.2
## Ring roads (centre lines) and the plot strips beside them, from the
## ground model (town.glb).
const INNER_ROAD := Rect2(-52.5, -76.5, 108.0, 119.0) # x, z, width, depth
const OUTER_ROAD := Rect2(-78.5, -100.5, 159.0, 165.0)
const LANE := 1.7 # cars keep this far left of the centre line
const RAIL_X := 114.0
const RAIL_Z := Vector2(-280.0, 220.0)
## High enough to pass over the rooftops, seen from the third floor.
const DECK_Y := GROUND_Y + 8.0

const WALLS := [Color(0.92, 0.89, 0.80), Color(0.81, 0.79, 0.75), Color(0.93, 0.93, 0.91), Color(0.85, 0.77, 0.64),
	Color(0.75, 0.79, 0.71), Color(0.64, 0.54, 0.44), Color(0.74, 0.79, 0.83)]
const ROOFS := [Color(0.24, 0.25, 0.28), Color(0.25, 0.31, 0.40), Color(0.38, 0.28, 0.22), Color(0.28, 0.34, 0.32)]
const CAR_COLORS := [Color(0.95, 0.95, 0.94), Color(0.72, 0.74, 0.77), Color(0.60, 0.78, 0.86), Color(0.93, 0.86, 0.60),
	Color(0.72, 0.25, 0.24), Color(0.15, 0.16, 0.18)]
const CONCRETE := Color(0.70, 0.70, 0.68)
const FRAME := Color(0.80, 0.82, 0.83)
const DARK := Color(0.16, 0.17, 0.19)

var building_count := 0
var _tools := {} # material key -> SurfaceTool
var _materials := {}
var _rng := RandomNumberGenerator.new()
var _cars: Array[Dictionary] = []
var _train: Node3D
var _train_t := 0.0


func _ready() -> void:
	_rng.seed = 7311
	_make_materials()
	_inner_plots()
	_outer_plots()
	_far_houses()
	_utility_poles()
	_railway()
	_commit(self)
	_make_cars()
	_make_train()


func _process(delta: float) -> void:
	for car in _cars:
		car.distance += car.speed * delta * car.dir
		var node: Node3D = car.node
		var here := _loop_point(car.road, car.distance, car.dir)
		node.position = here
		node.look_at(_loop_point(car.road, car.distance + 0.5 * car.dir, car.dir), Vector3.UP)
	_step_train(delta)


# ---------------------------------------------------------------- plots

## Along the inner ring (the old plot lines): houses, two shops, small
## apartment blocks. Each plot faces the road towards the school.
func _inner_plots() -> void:
	var rows := [
		[Vector3(-65, 0, 55), Vector3(11, 0, 0), 13, PI], [Vector3(-65, 0, -91), Vector3(11, 0, 0), 13, 0.0],
		[Vector3(-65, 0, 29), Vector3(0, 0, -11), 10, -PI * 0.5], [Vector3(70, 0, 29), Vector3(0, 0, -11), 10, PI * 0.5]]
	for r in rows.size():
		var row: Array = rows[r]
		var i := 0
		while i < int(row[2]):
			var at: Vector3 = row[0] + row[1] * i
			var yaw: float = row[3]
			if (r == 0 and i == 0) or (r == 1 and i == 12):
				_konbini(at, yaw)
			elif i % 5 == 3 and i + 1 < int(row[2]):
				_apartment(at + row[1] * 0.5, yaw, 2, 18.0)
				i += 1
			else:
				_house(at, yaw)
			i += 1


## Outer ring: apartment blocks with houses between them.
func _outer_plots() -> void:
	var rows := [[Vector3(-80, 0, 76), Vector3(13, 0, 0), 14, PI], [Vector3(-80, 0, -109), Vector3(13, 0, 0), 14, 0.0],
		[Vector3(-91, 0, 56), Vector3(0, 0, -13), 13, -PI * 0.5], [Vector3(94, 0, 56), Vector3(0, 0, -13), 13, PI * 0.5]]
	for row: Array in rows:
		var i := 0
		while i < int(row[2]):
			var at: Vector3 = row[0] + row[1] * i
			if i % 3 == 0 and i + 1 < int(row[2]):
				_apartment(at + row[1] * 0.5, row[3], 3, 20.0)
				i += 2
			else:
				_house(at, row[3])
				i += 1


## Simple houses on a loose grid out to the painted horizon (no details).
func _far_houses() -> void:
	for gx in range(-170, 175, 15):
		for gz in range(-200, 160, 15):
			var p := Vector3(gx + _rng.randf_range(-3, 3), 0, gz + _rng.randf_range(-3, 3))
			if absf(p.x) < 108 and p.z > -125 and p.z < 92:
				continue # the school, its streets and plots
			if absf(p.x - RAIL_X) < 13:
				continue # the railway
			if _rng.randf() < 0.25:
				continue
			var yaw := _rng.randi_range(0, 3) * PI * 0.5
			var t := _place(p, yaw)
			var w := _rng.randf_range(6.5, 9.0)
			var d := _rng.randf_range(7.0, 9.0)
			var h := 5.6 if _rng.randf() < 0.8 else 8.4
			_box("wall", t, Vector3(0, h * 0.5, 0), Vector3(w, h, d), _pick(WALLS))
			_gable(t, Vector3(0, h, 0), w, d, 2.0, 0.4, _pick(ROOFS))
			building_count += 1


# ---------------------------------------------------------------- buildings

## A two-storey house: plaster or siding walls, a tiled gable or hip roof,
## a front balcony upstairs, an entrance with a canopy, a block wall and
## sometimes a kei car in the drive. Front = +Z.
func _house(at: Vector3, yaw: float) -> void:
	var t := _place(at, yaw)
	var w := _rng.randf_range(7.0, 8.4)
	var d := _rng.randf_range(7.6, 9.0)
	var h := 5.8
	var wall: Color = _pick(WALLS)
	var roof: Color = _pick(ROOFS)
	var front := d * 0.5
	_box("wall", t, Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	_box("wall", t, Vector3(0, 0.25, 0), Vector3(w + 0.06, 0.5, d + 0.06), wall.darkened(0.35)) # base
	_box("wall", t, Vector3(0, 2.9, 0), Vector3(w + 0.08, 0.12, d + 0.08), wall.darkened(0.12)) # floor band
	if _rng.randf() < 0.55:
		_gable(t, Vector3(0, h, 0), w, d, 2.1, 0.55, roof)
	else:
		_hip(t, Vector3(0, h, 0), w, d, 1.9, 0.55, roof)
	# Ground floor: the door (left) and a wide window; upstairs two windows.
	var door_x := -w * 0.5 + 1.3
	_box("dark", t, Vector3(door_x, 1.05, front + 0.02), Vector3(0.95, 2.1, 0.06), Color(0.42, 0.30, 0.22))
	_box("frame", t, Vector3(door_x, 2.42, front + 0.45), Vector3(1.6, 0.08, 0.9), FRAME) # canopy
	_window(t, Vector3(w * 0.12, 1.5, front), 2.4, 1.6)
	var balcony := _rng.randf() < 0.6
	for x in [-w * 0.22, w * 0.22]:
		_window(t, Vector3(x, 4.35, front), 1.5, 1.15)
	if balcony:
		_box("frame", t, Vector3(w * 0.1, 3.05, front + 0.55), Vector3(w * 0.7, 0.12, 1.1), FRAME)
		_box("frame", t, Vector3(w * 0.1, 3.55, front + 1.08), Vector3(w * 0.7, 0.9, 0.05), FRAME.darkened(0.08))
		if _rng.randf() < 0.5: # laundry on the balcony pole
			for k in 3:
				_box("wall", t, Vector3(w * (0.0 + 0.12 * k) - 0.4, 3.75, front + 0.7), Vector3(0.6, 0.7, 0.04), _pick([Color(0.95, 0.95, 0.95), Color(0.62, 0.75, 0.88), Color(0.95, 0.80, 0.75)]))
	for z in [-d * 0.2, d * 0.2]: # side windows
		_window(t, Vector3(w * 0.5, 4.35, z), 0.9, 0.9, true)
	_box("wall", t, Vector3(w * 0.5 + 0.35, 0.4, -d * 0.25), Vector3(0.7, 0.6, 0.3), Color(0.92, 0.92, 0.9)) # AC unit
	# Concrete block wall along the front, open at the gate and the drive.
	var lot_front := front + 2.6
	_box("concrete", t, Vector3(-w * 0.5 - 0.3, 0.6, lot_front - 1.3), Vector3(0.15, 1.2, 2.6), CONCRETE)
	_box("concrete", t, Vector3(w * 0.25, 0.6, lot_front), Vector3(w * 0.5, 1.2, 0.15), CONCRETE)
	if _rng.randf() < 0.45:
		_kei_car(t * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-w * 0.18, 0, front + 1.5)), _pick(CAR_COLORS))
	building_count += 1


## A small apartment block: balconies with frosted panels across the front,
## a flat roof with a parapet and an outside stair. Front = +Z.
func _apartment(at: Vector3, yaw: float, floors: int, w: float) -> void:
	var t := _place(at, yaw)
	var d := 9.0
	var fh := 2.9
	var h := floors * fh + 0.6
	var wall: Color = _pick([Color(0.93, 0.92, 0.88), Color(0.86, 0.80, 0.70), Color(0.80, 0.81, 0.80), Color(0.70, 0.58, 0.48)])
	var front := d * 0.5
	_box("wall", t, Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	_box("wall", t, Vector3(0, h + 0.3, 0), Vector3(w + 0.2, 0.6, d + 0.2), wall.darkened(0.1)) # parapet
	var units := int(w / 4.5)
	var unit_w := w / units
	for f in floors:
		var y := f * fh
		_box("frame", t, Vector3(0, y + 0.1, front + 0.6), Vector3(w, 0.18, 1.2), wall.darkened(0.05)) # balcony slab
		for u in units:
			var x := -w * 0.5 + unit_w * (u + 0.5)
			_box("glass", t, Vector3(x, y + 1.35, front + 0.02), Vector3(unit_w * 0.62, 1.9, 0.05), Color.WHITE)
			_box("frame", t, Vector3(x, y + 0.85, front + 1.18), Vector3(unit_w - 0.2, 1.0, 0.06), Color(0.86, 0.89, 0.91)) # frosted panel
			_box("wall", t, Vector3(x + unit_w * 0.3, y + 0.55, front + 0.8), Vector3(0.7, 0.6, 0.3), Color(0.92, 0.92, 0.9)) # AC unit
		for u in units + 1: # partitions between the balconies
			_box("frame", t, Vector3(-w * 0.5 + unit_w * u, y + 1.2, front + 0.6), Vector3(0.06, 1.8, 1.2), FRAME)
	# Outside stair at one end.
	_box("concrete", t, Vector3(w * 0.5 + 1.2, h * 0.45, -d * 0.2), Vector3(2.4, h * 0.9, 3.0), CONCRETE)
	for f in floors:
		_box("dark", t, Vector3(w * 0.5 + 2.42, f * fh + 1.2, -d * 0.2), Vector3(0.05, 0.9, 2.4), DARK)
	building_count += 1


## A corner convenience store (no real brand): white box, a glass front, a
## lit sign band in teal and yellow, parking bays and vending machines.
func _konbini(at: Vector3, yaw: float) -> void:
	var t := _place(at, yaw)
	var w := 15.0
	var d := 11.0
	var h := 4.4
	var front := d * 0.5 - 2.5
	_box("wall", t, Vector3(0, h * 0.5, -2.5), Vector3(w, h, d), Color(0.95, 0.95, 0.94))
	_box("glass", t, Vector3(0.0, 1.45, front + 0.03), Vector3(w * 0.8, 2.5, 0.06), Color.WHITE)
	for k in 7:
		_box("frame", t, Vector3(-w * 0.4 + w * 0.8 / 6.0 * k, 1.45, front + 0.07), Vector3(0.1, 2.5, 0.06), FRAME)
	_box("lit", t, Vector3(0, 3.55, front + 0.08), Vector3(w, 0.9, 0.12), Color(0.96, 0.97, 0.95)) # sign band
	_box("lit", t, Vector3(0, 3.25, front + 0.16), Vector3(w, 0.22, 0.04), Color(0.10, 0.62, 0.60))
	_box("lit", t, Vector3(0, 3.85, front + 0.16), Vector3(w, 0.16, 0.04), Color(0.98, 0.78, 0.18))
	# Parking in front with white lines; a pole sign.
	_box("concrete", t, Vector3(0, 0.02, front + 3.0), Vector3(w, 0.04, 6.0), Color(0.55, 0.56, 0.57))
	for k in 6:
		_box("lit", t, Vector3(-w * 0.5 + 2.5 * k + 1.25, 0.05, front + 3.5), Vector3(0.12, 0.02, 4.0), Color(0.85, 0.85, 0.85))
	_box("concrete", t, Vector3(w * 0.5 - 0.6, 3.0, front + 5.4), Vector3(0.3, 6.0, 0.3), FRAME)
	_box("lit", t, Vector3(w * 0.5 - 0.6, 6.4, front + 5.4), Vector3(1.6, 1.6, 0.4), Color(0.10, 0.62, 0.60))
	for k in 3:
		_vending(t * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.7 + 1.1 * k, 0, front + 0.45)), k)
	building_count += 1


## A drinks vending machine (white, red or blue), front lit.
func _vending(t: Transform3D, kind: int) -> void:
	var body: Color = [Color(0.95, 0.95, 0.95), Color(0.80, 0.16, 0.15), Color(0.16, 0.36, 0.70)][kind % 3]
	_box("wall", t, Vector3(0, 0.92, 0), Vector3(1.0, 1.84, 0.75), body)
	_box("lit", t, Vector3(0, 1.3, 0.38), Vector3(0.84, 0.8, 0.02), Color(0.92, 0.95, 0.98))
	_box("dark", t, Vector3(0, 0.35, 0.38), Vector3(0.6, 0.22, 0.02), DARK)


## A boxy Japanese kei car, front = +Z (static, merged with the town).
func _kei_car(t: Transform3D, color: Color) -> void:
	_box("wall", t, Vector3(0, 0.62, 0), Vector3(1.46, 0.75, 3.35), color)
	_box("wall", t, Vector3(0, 1.32, -0.25), Vector3(1.40, 0.68, 2.2), color)
	_box("glass", t, Vector3(0, 1.33, -0.25), Vector3(1.42, 0.5, 2.0), Color.WHITE)
	for x in [-0.68, 0.68]:
		for z in [-1.05, 1.05]:
			_box("dark", t, Vector3(x, 0.3, z), Vector3(0.2, 0.56, 0.56), DARK)


# ---------------------------------------------------------------- street furniture

## Concrete utility poles with cross-arms along both ring roads, three
## sagging wires between neighbours: the most Japanese thing on a street.
func _utility_poles() -> void:
	for ring: Rect2 in [INNER_ROAD.grow(5.5), OUTER_ROAD.grow(4.5)]:
		var corners := [Vector3(ring.position.x, 0, ring.position.y), Vector3(ring.end.x, 0, ring.position.y),
			Vector3(ring.end.x, 0, ring.end.y), Vector3(ring.position.x, 0, ring.end.y)]
		var poles: Array[Vector3] = []
		for s in 4:
			var a: Vector3 = corners[s]
			var b: Vector3 = corners[(s + 1) % 4]
			var n := maxi(1, int(round(a.distance_to(b) / 22.0)))
			for k in n:
				poles.append(a.lerp(b, float(k) / n))
		for i in poles.size():
			var p := poles[i]
			var q := poles[(i + 1) % poles.size()]
			var along := (q - p).normalized()
			var t := Transform3D(Basis(Vector3.UP, atan2(along.x, along.z)), Vector3(p.x, GROUND_Y, p.z))
			_cylinder("concrete", t, 0.14, 9.0, CONCRETE)
			_box("concrete", t, Vector3(0, 8.4, 0), Vector3(1.8, 0.1, 0.1), CONCRETE.darkened(0.15))
			if i % 3 == 1:
				_cylinder("frame", t * Transform3D(Basis.IDENTITY, Vector3(0.35, 6.6, 0)), 0.28, 0.9, Color(0.62, 0.65, 0.66)) # transformer
			for k in 3:
				var off := (k - 1) * 0.8
				var side := Vector3(along.z, 0, -along.x) * off
				_wire(Vector3(p.x, GROUND_Y + 8.45, p.z) + side, Vector3(q.x, GROUND_Y + 8.45, q.z) + side, 0.45)


## A wire hanging between two points (in 5 straight pieces).
func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var pieces := 5
	var prev := a
	for k in range(1, pieces + 1):
		var f := float(k) / pieces
		var p := a.lerp(b, f) - Vector3(0, sag * 4.0 * f * (1.0 - f), 0)
		_beam("dark", prev, p, 0.035, DARK)
		prev = p


## The elevated railway on the east: piers, a deck, two tracks and the
## overhead line masts.
func _railway() -> void:
	var length := RAIL_Z.y - RAIL_Z.x
	var mid := (RAIL_Z.x + RAIL_Z.y) * 0.5
	var t := Transform3D(Basis.IDENTITY, Vector3(RAIL_X, 0, mid))
	_box("concrete", t, Vector3(0, DECK_Y - 0.5, 0), Vector3(9.0, 1.0, length), CONCRETE)
	_box("concrete", t, Vector3(-4.4, DECK_Y + 0.5, 0), Vector3(0.2, 1.0, length), CONCRETE.darkened(0.08))
	_box("concrete", t, Vector3(4.4, DECK_Y + 0.5, 0), Vector3(0.2, 1.0, length), CONCRETE.darkened(0.08))
	for x in [-2.2, 2.2]:
		for r in [-0.72, 0.72]:
			_box("dark", t, Vector3(x + r, DECK_Y + 0.12, 0), Vector3(0.08, 0.14, length), Color(0.35, 0.33, 0.31))
	for z in range(int(RAIL_Z.x), int(RAIL_Z.y) + 1, 20):
		var pier := Transform3D(Basis.IDENTITY, Vector3(RAIL_X, GROUND_Y, z))
		_box("concrete", pier, Vector3(0, (DECK_Y - 1.0 - GROUND_Y) * 0.5, 0), Vector3(1.8, DECK_Y - 1.0 - GROUND_Y, 1.8), CONCRETE.darkened(0.05))
		if z % 40 == 0:
			for x in [-4.1, 4.1]:
				_box("frame", pier, Vector3(x, DECK_Y + 3.0 - GROUND_Y, 0), Vector3(0.18, 6.0, 0.18), Color(0.55, 0.58, 0.6))
			_box("frame", pier, Vector3(0, DECK_Y + 5.8 - GROUND_Y, 0), Vector3(8.4, 0.15, 0.15), Color(0.55, 0.58, 0.6))
	for x in [-2.2, 2.2]:
		_box("dark", t, Vector3(x, DECK_Y + 5.4, 0), Vector3(0.04, 0.04, length), DARK) # overhead line


# ---------------------------------------------------------------- moving

## Kei cars on both ring roads, driving on the left, both directions.
func _make_cars() -> void:
	var plan := [[INNER_ROAD, 1, 0.0], [INNER_ROAD, -1, 150.0], [INNER_ROAD, 1, 300.0],
		[OUTER_ROAD, -1, 40.0], [OUTER_ROAD, 1, 260.0], [OUTER_ROAD, -1, 480.0]]
	for i in plan.size():
		var car := Node3D.new()
		car.name = "KeiCar_%d" % i
		add_child(car)
		_kei_car(Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), CAR_COLORS[i % CAR_COLORS.size()])
		_commit(car)
		_cars.append({"node": car, "road": plan[i][0], "dir": plan[i][1], "distance": plan[i][2], "speed": _rng.randf_range(7.0, 9.5)})


## A point on a ring road `distance` along it, in the left lane for `dir`.
func _loop_point(road: Rect2, distance: float, dir: int) -> Vector3:
	var corners := [Vector2(road.position.x, road.position.y), Vector2(road.end.x, road.position.y),
		Vector2(road.end.x, road.end.y), Vector2(road.position.x, road.end.y)]
	var total := 2.0 * (road.size.x + road.size.y)
	var left := fposmod(distance, total)
	for s in 4:
		var a: Vector2 = corners[s]
		var b: Vector2 = corners[(s + 1) % 4]
		var length := a.distance_to(b)
		if left <= length:
			var p := a.lerp(b, left / length)
			var forward := (b - a).normalized() * dir
			var lane := Vector2(forward.y, -forward.x) * LANE # left of travel
			return Vector3(p.x + lane.x, GROUND_Y + 0.02, p.y + lane.y)
		left -= length
	return Vector3(corners[0].x, GROUND_Y, corners[0].y)


## A four-car commuter train (silver, a green band; no real line's livery).
func _make_train() -> void:
	_train = Node3D.new()
	_train.name = "Train"
	add_child(_train)
	for c in 4:
		var t := Transform3D(Basis.IDENTITY, Vector3(0, 0, -c * 20.5))
		_box("frame", t, Vector3(0, 2.0, 0), Vector3(2.9, 3.0, 20.0), Color(0.84, 0.86, 0.88))
		_box("lit", t, Vector3(0, 1.25, 0), Vector3(2.94, 0.28, 20.0), Color(0.12, 0.56, 0.34))
		_box("glass", t, Vector3(0, 2.4, 0), Vector3(2.96, 0.9, 18.6), Color.WHITE)
		_box("dark", t, Vector3(0, 0.45, 0), Vector3(2.4, 0.5, 18.0), DARK)
	_commit(_train)
	_train.visible = false
	_train_t = 20.0


## Runs north then south along the deck, a pass about once a minute.
func _step_train(delta: float) -> void:
	_train_t += delta
	var period := 60.0
	var run := 30.0
	var phase := fposmod(_train_t, period * 2.0)
	var northbound := phase < period
	var t := fposmod(phase, period)
	_train.visible = t < run
	if not _train.visible:
		return
	var span := RAIL_Z.y - RAIL_Z.x + 90.0
	var z := RAIL_Z.x - 45.0 + span * (t / run)
	if not northbound:
		z = RAIL_Z.y + 45.0 - span * (t / run)
	_train.position = Vector3(RAIL_X + (2.2 if northbound else -2.2), DECK_Y, z)
	_train.rotation.y = 0.0 if northbound else PI # cars trail towards -Z


# ---------------------------------------------------------------- geometry

func _place(at: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, GROUND_Y, at.z))


func _pick(list: Array) -> Variant:
	return list[_rng.randi() % list.size()]


## A window: aluminium frame and glass, on the wall at `at` (front, +Z), or
## on the right side (+X) when `side`.
func _window(t: Transform3D, at: Vector3, w: float, h: float, side := false) -> void:
	var size := Vector3(0.06, h, w) if side else Vector3(w, h, 0.06)
	var out := Vector3(0.04, 0, 0) if side else Vector3(0, 0, 0.04)
	_box("frame", t, at + out * 0.5, size + Vector3(0.12, 0.12, 0.12) * (Vector3(0, 1, 1) if side else Vector3(1, 1, 0)), FRAME)
	_box("glass", t, at + out, size, Color.WHITE)


func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


## A triangle facing away from `inside` (a point within the shape), whatever
## order its corners come in: the normal points out, and the corners are
## written clockwise as seen from outside (Godot's front faces).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
		var swap := b
		b = c
		c = swap
	n = n.normalized()
	for v in [a, c, b]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, inside: Vector3) -> void:
	_tri(st, a, b, c, color, inside)
	_tri(st, a, c, d, color, inside)


## A box of `size` centred at `at` in the frame `t`.
func _box(key: String, t: Transform3D, at: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var st := _tool(key)
	var h := size * 0.5
	var p := []
	for i in 8:
		var corner := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		p.append(t * (at + basis * corner))
	var inside := t * at
	_quad(st, p[4], p[5], p[7], p[6], color, inside) # +Z
	_quad(st, p[1], p[0], p[2], p[3], color, inside) # -Z
	_quad(st, p[5], p[1], p[3], p[7], color, inside) # +X
	_quad(st, p[0], p[4], p[6], p[2], color, inside) # -X
	_quad(st, p[6], p[7], p[3], p[2], color, inside) # +Y
	_quad(st, p[0], p[1], p[5], p[4], color, inside) # -Y


## A thin box from a to b (wires).
func _beam(key: String, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var dir := b - a
	var z := dir.normalized()
	var x := Vector3.UP.cross(z).normalized()
	if x.length_squared() < 0.01:
		x = Vector3.RIGHT
	var y := z.cross(x)
	_box(key, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3.ZERO, Vector3(thickness, thickness, dir.length()), color)


## An upright six-sided post of `height`, base at the frame's origin.
func _cylinder(key: String, t: Transform3D, radius: float, height: float, color: Color) -> void:
	var st := _tool(key)
	var inside := t * Vector3(0, height * 0.5, 0)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		var p0 := Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		_quad(st, t * p1, t * p0, t * (p0 + Vector3(0, height, 0)), t * (p1 + Vector3(0, height, 0)), color, inside)
		_tri(st, t * Vector3(0, height, 0), t * (p1 + Vector3(0, height, 0)), t * (p0 + Vector3(0, height, 0)), color, inside)


## A tiled gable roof on a body of w x d whose top is at `at`: the ridge
## runs along X, eaves overhang by `over`. Gable ends in the roof colour.
func _gable(t: Transform3D, at: Vector3, w: float, d: float, rise: float, over: float, color: Color) -> void:
	var st := _tool("roof")
	var under := t * (at + Vector3(0, -3.0, 0)) # every slope faces away from here
	var mid := t * (at + Vector3(0, -1.0, 0))
	var hw := w * 0.5 + over
	var hd := d * 0.5 + over
	var drop := rise * over / (d * 0.5) # the eaves sit a little below the wall top
	var fl := t * (at + Vector3(-hw, -drop, hd))
	var fr := t * (at + Vector3(hw, -drop, hd))
	var bl := t * (at + Vector3(-hw, -drop, -hd))
	var br := t * (at + Vector3(hw, -drop, -hd))
	var rl := t * (at + Vector3(-hw, rise, 0))
	var rr := t * (at + Vector3(hw, rise, 0))
	_quad(st, fl, fr, rr, rl, color, under)
	_quad(st, br, bl, rl, rr, color, under)
	var wall := _tool("wall")
	_tri(wall, t * (at + Vector3(-w * 0.5, 0, d * 0.5)), t * (at + Vector3(-w * 0.5, rise - drop * 0.0, 0)), t * (at + Vector3(-w * 0.5, 0, -d * 0.5)), color.lightened(0.5), mid)
	_tri(wall, t * (at + Vector3(w * 0.5, 0, -d * 0.5)), t * (at + Vector3(w * 0.5, rise, 0)), t * (at + Vector3(w * 0.5, 0, d * 0.5)), color.lightened(0.5), mid)
	_box("roof", t, at + Vector3(0, rise + 0.05, 0), Vector3(w + over * 2.0, 0.14, 0.3), color.darkened(0.2)) # ridge tiles


## A hip roof: four slopes up to a short ridge along X.
func _hip(t: Transform3D, at: Vector3, w: float, d: float, rise: float, over: float, color: Color) -> void:
	var st := _tool("roof")
	var under := t * (at + Vector3(0, -3.0, 0))
	var hw := w * 0.5 + over
	var hd := d * 0.5 + over
	var drop := rise * over / (d * 0.5)
	var ridge := maxf(0.4, hw - hd)
	var fl := t * (at + Vector3(-hw, -drop, hd))
	var fr := t * (at + Vector3(hw, -drop, hd))
	var bl := t * (at + Vector3(-hw, -drop, -hd))
	var br := t * (at + Vector3(hw, -drop, -hd))
	var rl := t * (at + Vector3(-ridge, rise, 0))
	var rr := t * (at + Vector3(ridge, rise, 0))
	_quad(st, fl, fr, rr, rl, color, under)
	_quad(st, br, bl, rl, rr, color, under)
	_tri(st, bl, fl, rl, color.darkened(0.06), under)
	_tri(st, fr, br, rr, color.darkened(0.06), under)
	_box("roof", t, at + Vector3(0, rise + 0.05, 0), Vector3(ridge * 2.0 + 0.3, 0.14, 0.3), color.darkened(0.2))


## One mesh per material under `parent` (so a moving car is its own few).
func _commit(parent: Node3D) -> void:
	for key: String in _tools:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh_" + key
		mesh.mesh = (_tools[key] as SurfaceTool).commit()
		mesh.material_override = _materials[key]
		parent.add_child(mesh)
	_tools.clear()


func _make_materials() -> void:
	var make := func(rough: float, metal := 0.0, emit := 0.0, two_sided := false) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = rough
		m.metallic = metal
		if emit > 0.0: # signs and lit panels: unshaded, as bright day or night
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if two_sided:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m
	_materials["wall"] = make.call(0.9)
	_materials["roof"] = make.call(0.7, 0.0, 0.0, true)
	_materials["frame"] = make.call(0.5, 0.3)
	_materials["concrete"] = make.call(0.95)
	_materials["dark"] = make.call(0.7)
	_materials["lit"] = make.call(0.6, 0.0, 0.35)
	var glass: StandardMaterial3D = make.call(0.12, 0.25)
	glass.vertex_color_use_as_albedo = false
	glass.albedo_color = Color(0.26, 0.34, 0.40)
	_materials["glass"] = glass
