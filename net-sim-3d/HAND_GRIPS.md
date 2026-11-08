# Item-specific first-person grips

Scope: all three entries currently equipable through `held_item_catalog.gd`:
`crimping_tool`, `cable_stripper`, `cable_tester`. Other scene props are not
inventory pickups; this work does not grant items or complete missions.

Each entry selects its own original-avatar hand pose. The empty-hand reference
pose, forearm orientation, body collision and world camera remain unchanged.
Held items and hands share the animated parent, preserving their fit during
walking and interaction. Only one fitted pose is visible; poses are cached and
reused when switching. Fingers switch pose on equip, not a continuous grasp
animation. Tools retain their source meshes/materials.

## Verification (2026-11-08)

- All three equipped models were rendered in the main game scene.
- Actual imported runtime meshes, not just Blender source geometry, were tested
  for hand/tool triangle intersections: **zero for each item**.
- Nearest hand/tool surface contacts were within 0.14 mm for all three items.
- E/Esc, ownership checks, equip/unequip, switching, removal of the last item,
  computer-input locking and fixed forearm orientation pass the presentation test.
- This validates the current held poses, not future moving tool jaws or new items.
  No browser export/performance claim is made by these tests.

## Rebuild or extend

1. In Godot, run `tools/export_grip_geometry.gd -- --baseline`. This exports
   current tool geometry into `../tmp/avatar_arm_export/grip_geometry.json`,
   removing `fit_offset` so repeated builds do not accumulate offsets.
2. Run Blender in background with `3Dmodel/scripts/build_item_grips.py`.
   This poses only existing avatar bones within bounded joint ranges and fits
   against the actual tool surfaces. The exporter rejects intersecting results.
3. Copy each `offset_blender` from its fit report into the corresponding
   `fit_offset` in the catalog. These values are normalized Blender-arm XYZ;
   the runtime converts them to Godot axes and the preserved arm orientation.
4. Reimport the generated hand GLBs in Godot.
5. Run `tools/export_grip_geometry.gd` without `--baseline`, then Blender with
   `3Dmodel/scripts/validate_item_grips.py`. This independently checks the runtime
   tool and hand surfaces and fails for any intersection or a contact gap >3 mm.
6. Run `tools/validate_player_presentation.gd`, then visually review every item
   in game. Do not treat a geometry-only pass as proof of a natural grasp.

The builder can use `-- --refine` to continue from the temporary fit report.
The committed artifact report is `assets/models/tools/grip_fit_report.json`;
runtime verification is recorded in `assets/models/tools/grip_validation.json`.
