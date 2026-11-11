# School restrooms — 2026-11-12

The existing two restroom shells and basic procedural layout were developed into complete men's and women's rooms in the current school main scene. Existing corridor entry doors and architecture remain in their current locations.

## Contents

| Room | Fixtures |
| --- | --- |
| Women's | 6 north-wall toilet cubicles, 8 basins in two four-basin counters, two framed mirrors, soap dispensers, paper towels, room bin and individual sanitary bins |
| Men's | 6 north-wall toilet cubicles, 6 west-wall urinals with privacy dividers, 8 basins in two four-basin counters, two framed mirrors, soap dispensers, paper towels and room bin |
| Both | Half-height tiled walls, tiled floor, coloured trim continuing on both sides of the entrance, ceiling extractor grilles, local lighting and cleaning-supply closet facade |

The rooms now share the same cubicle and basin arrangement. The men's cleaning closet facade is on the south wall, clear of the new cubicle row. Each entrance has a full-height privacy wall joined to the south wall and ceiling; the former gap at its south end is closed. Entry circulation goes around the north end. Tile bands and trim meet the existing walls without covering the corridor door openings.

Each cubicle is 1.20m wide × 2.35m deep, with a 0.78m door. Women's doors/trim are muted green; men's are blue. The first cubicle in each room starts open; others start closed. Cubicle doors work with the existing **F** interaction from both sides, include a moving collider and refuse to move through a character in the swing path. Numbers/handles are attached to the actual moving leaf. The green disc identifies a vacant cubicle; there is no occupancy/locking simulation.

## Sources and implementation

- Existing toilet source: `D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/WC.blend`, read only. A new metre-scale white porcelain version, flush button and bidet hose/nozzle were exported from it.
- Editable fixtures: `D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/restrooms/`
- Reusable GLB exports: `D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/exports/restrooms/`
- Runtime GLBs: `assets/models/restrooms/` (`school_toilet`, `school_basin`, `school_urinal`), total approximately 335KB.
- Regenerator: `D:/NetSim3D/3Dmodel/scripts/build_school_restroom_fixtures.py`
- Room builder/layout: `scripts/props/restrooms.gd`, on the `Restrooms` node of `scenes/main.tscn`. `@tool` makes generated interiors visible in the editor; generated children are not duplicated in saved scene data.
- Cubicle interaction: `scripts/props/restroom_stall_door.gd`.
- Fixtures are appended into the room's material batches: 15 static visual meshes and 75 static fixture/partition collision shapes; 12 animated doors are separate. Materials are shared. No external model downloads.
- Added Thai/English translations for cubicle prompts and hygiene/cleaning signs to the catalog builder and generated catalog.

The mirror surface is a stylised glass material, not a live reflection viewport. Taps/toilets are environment fixtures; water-flow, flushing and character use animations are not part of this change. The cleaning closet door remains decorative. The web export has not been rebuilt.

## Validation

- `tools/validate_restrooms.gd`: **RESTROOMS_VALID**. 16 capsule route segments through both entries, around privacy walls and up to both basin banks/stalls/urinals are clear. Six ray checks verify privacy-wall closure at floor, eye and upper-wall heights.
- `tools/validate_restroom_stalls.gd`: **RESTROOM_STALLS_VALID doors=12 walks=24 interaction=F language=th/en**. The actual player walks into and out of all 12 cubicles, opens/closes from both sides, is stopped by a closed leaf and prevents a door from closing through them. It also checks Thai/English prompts.
- `tools/validate_doors.gd`: **DOORS_VALID doors=8 bidirectional_walks=16**. Existing room entry doors, including both restroom entrances, still open/close and allow passage in both directions.
- `tools/capture_restrooms.gd`: latest GPU review pictures at `D:/NetSim3D/Preview/โรงเรียนและเมือง/restrooms/revised/`, including both complete room views, all basin banks, the joined entrance wall, urinals and the toilet inside a cubicle. `after/` contains the earlier furnished layout; `before/` contains the primitive fixtures.

Run the usual project with F5 to inspect the rooms beside the main corridor.
