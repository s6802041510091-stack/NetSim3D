# Held equipment source models

These are unchanged copies of project assets, not substitute geometry:

- `crimping_tool.glb`: `3Dmodel/ด่าน_02/crimp_tools/crimping_tool.glb`
- `cable_stripper.glb`: `3Dmodel/ด่าน_02/crimp_tools/cable_stripper.glb`
- `cable_tester.glb`: `3Dmodel/ด่าน_02/cable_tester/cable_tester.glb`

All placement changes are in `scripts/held_item_catalog.gd`. No scripts from the
source preview scenes are attached to the first-person copies; these are visual
equipment only and do not automatically complete mission actions.

`hand_crimping_tool.glb`, `hand_cable_stripper.glb`, and `hand_cable_tester.glb`
are item-specific poses derived from the original player avatar by
`3Dmodel/scripts/build_item_grips.py`. Original topology, UVs and materials are
retained; only the original finger bones are posed. They are not new hand models.
See `grip_fit_report.json` for source fingerprint, joint angles and offsets.
