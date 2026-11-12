# Corridor student life

Seven students are instanced in `scenes/npc/corridor_students.tscn`, which is part of `scenes/main.tscn` and therefore shared by all six levels. `mullet_b` and `bob_b` reuse the mullet and bob-cut models with a different hair tone (`hair_tint`); replace them when new character models exist.

## Behaviour (agreed with the user 2026-11-12)

- Students mostly stay put: about 60–90 s on a bench, against a wall, at a corridor window looking into the classrooms, or chatting with a friend. Inside the restroom 35–60 s, inside the science room 60–100 s.
- At most three are walking at once. A student whose time is up waits a little longer when the corridor is busy.
- Walkers keep to the left-hand lane of their direction (x −7.35 going toward the IT end, x −4.95 going toward the computer-room end) and pass through corners without stopping or turning on the spot. Speeds are 0.72–0.85 m/s with gentle acceleration, turning and a 1.7 s sit/stand.
- Standing spots are only against walls, at least 0.9 m from doorways and clear of the stair opening. Nobody stops in the walkway.
- Conversations: two friends standing by a wall or sitting on the same bench. A student may walk over to a friend who is settled and sit or stand beside them. Speakers take turns. After a talk, one may stay a little longer.
- Rooms: girls use the women's restroom, boys the men's; anyone may use the science room (shoes off at the science shoe rack first, on again after). The student opens the door, steps in, disappears behind it and shuts it; later opens it, comes out and shuts it again. One person passes through a doorway at a time.
- Students glance at the player when the player passes close by, look down while resting on a bench, and step aside early for other walkers. They wait for the player rather than push.

## Implementation

- `scripts/npc/student_life.gd` is the director: spots, reservations, walker budget, chat groups and the plan for each student's next activity. Its `random_seed` export (0 = random each run) makes runs repeatable.
- `scripts/npc/student_character.gd` follows a plan of steps (`via` pass-through points, `anchor` long stays, `bench`/`slot`, `door`/`door_op`, `hide`). It reuses the approved rig, bench pose, foot contacts and cloth correction unchanged.
- Doors are the existing `InteractiveDoor` nodes (`set_open`), so the door swing, collision and sounds are the same as when the player opens them.

## Housekeeper (agreed with the user 2026-11-12)

`Cleaner` in `corridor_students.tscn` uses the approved `cleaner_female_apron_160cm.glb` and `cleaner_mop.glb` (copied to `assets/models/cleaner/`). `scripts/npc/cleaner_character.gd` extends the student character (walking, doors, avoidance) and adds the mop.

- She is always in sight: the restrooms have no closet, so she never hides or rests out of view. She starts each level already mopping the corridor.
- Cycle: mops two corridor stretches → mops the other restroom (in, passes, back out, door shut) → two more stretches → and so on. If a student is in that restroom, she mops one more corridor stretch first and tries again.
- Mopping: 0.22 m/s, three passes per corridor stretch (x −7.3, −6.15, −5.0), three or four passes between the cubicles and the basins in a restroom, swinging the mop slowly left and right (one swing every 3.4 s, 22 cm each side) while she looks down at the floor she is mopping. Between jobs she carries it upright at her right side. Both hands grip the handle by arm IK, and the fingers wrap round it.
- She opens and shuts the restroom doors herself. Students don't go into a restroom while she is mopping it. Students avoid her, and she waits for the player.
- She is not counted in the students' three-walker limit.

Checks: `tools/validate_cleaner.gd [-- seed]` (16 in-game minutes) and `tools/capture_cleaner.gd` (pictures in `Preview/โถงทางเดิน/cleaner/`).

## Girls' thighs and skirt (runtime fix)

The female models have bare legs only from the ankle to just above the knee; seated, the cut leg ends showed under the knee-length skirt. `scripts/npc/student_thighs.gd` now adds, at load time:

- a skinned thigh from the cut up to the hip, inside the skirt, coloured from the leg's own skin texture;
- skirt skinning that hands its lower part to the thigh bones, so the skirt lies over the thighs when seated instead of hanging from the waist. Thigh and skirt use the same hip/thigh hand-over, so they fold alike at the hip.

The GLB files are unchanged. `tools/capture_seated_students.gd` seats all seven students and saves player-view, low-front and side pictures (and the girls standing) to `Preview/โถงทางเดิน/students/seated/`.

## Checks

`tools/validate_students.gd [-- seed]` runs eight in-game minutes and checks: seven rigs, standing spots and lanes clear of walls and furniture, at most three walkers, settled people only against walls, doors shut after use, stays (median), conversations, room visits, capsule/arm clearance, pause, yielding to the player and solid collision.

Result on 2026-11-12: 20 of 21 random seeds passed. The one failure (seed 15) is a 2–3 cm arm/shoulder brush between two students near BenchLeft04 and is still open.
