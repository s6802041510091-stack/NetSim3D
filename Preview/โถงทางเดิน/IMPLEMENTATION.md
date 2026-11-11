# Approved corridor furnishings — 2026-11-11

Built from `corridor-concept-v2.png`, approved by the user. Reusable models authored in Blender, exported as GLB, placed in the actual Godot main scene. The architecture source is unchanged.

## Files

- Blender sources: `D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/corridor/`
  - `corridor_bench.blend`
  - `corridor_shoe_rack_30.blend`
  - `corridor_plant.blend`
- Reusable exports: `D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/exports/corridor/`
- Runtime GLBs: `D:/NetSim3D/net-sim-3d/assets/models/corridor/`
- Godot arrangement: `D:/NetSim3D/net-sim-3d/scenes/props/corridor_furnishings.tscn`
- Source generator: `D:/NetSim3D/3Dmodel/scripts/build_corridor_furnishings.py`

## Arrangement

8 benches, 11 potted plants, 2 shoe racks (computer/science classrooms). Each rack has 10 columns × 3 rows = 30 pair compartments, 3.12m long × 0.35m deep × 0.985m high. Some compartments intentionally empty. Benches are 1.5m long with 0.45m seat height. Furniture is positioned on available wall segments, away from door swings and the stairwell opening. The central route remains clear.

Each prop uses a shared imported mesh and simple physics shapes. Each model has one mesh: bench 1,516 triangles; rack including shoes 17,432; plant 1,852. The three runtime GLBs total approximately 1.23MB. Wood grain is an original generated texture included in the Blender files and GLBs; no external asset downloads.

## Review images

- `corridor-built.png`: actual Godot corridor, same camera as the original reference.
- `shoe-rack-built.png`: classroom rack detail.
- `stairs-built.png`: unobstructed stair approach.

## Validation

`tools/validate_corridor_furnishings.gd`: real player capsule traverses the full corridor in three lanes, both directions; two stair approaches; solid prop collision; floor alignment; no overlapping furniture; all eight door sweeps clear. Passed `CORRIDOR_VALID`.

`tools/validate_doors.gd`: passed `DOORS_VALID doors=8 bidirectional_walks=16 floor_and_open_pose=valid`, including animated open/close. The prompt check now accepts both Thai and English because the player can choose a language.

The existing web build has not been re-exported. Open the Godot project and run the current main game to see the new furnishings.
