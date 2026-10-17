# Town preview verification — 2026-10-17

- Static Blender build and glTF export succeeded: 39,116 triangles in 19 material batches, town GLB 4,825,120 bytes. These are asset counts, not measured frame-time or draw-call guarantees.
- Godot runtime validation passed: 14 walkers, 6 cyclists, finite actor positions, motion after two seconds, matching route positions after a complete loop, eye height 8.85 m above the grounds.
- Five actual Godot Compatibility screenshots captured successfully. Reviewed campus overview, east classroom field, west science garden, south shops and street view. Corrected initial excessive illumination; moved window cameras inside the rooms so window frames and sill establish the view.
- Combined school + static exterior saved separately as `school_with_town.blend`; production main scene was not modified. Original school coordinates remain unchanged.
- Restricted-environment Godot shader-cache/editor-settings and Blender thumbnail warnings occurred. Explicit project-local engine logs avoided the default-user-log-directory crash. Runtime validation and final screenshot capture succeeded; no script errors in final logs.

## Remaining production / art work

This is a first low-poly art pass, not final anime-production quality. Buildings repeat, road corners and character turns are sharp; walkers/cyclists are procedural background figures without navigation, avoidance, detailed rigging or interaction. Effects are basic drifting petals. No collisions or traversable lower-floor interiors are supplied. Additional art direction, screen/door regression tests, production integration and web performance budgeting remain separate work.

## Painted 2D horizon update

Replaced polygon hills and 3D clouds with a project-local 2172 × 724 painted city/mountain/sky image. The sky uses mirrored panorama hemispheres; matching distant-ground shading removes the hard straight grass/sky boundary. Checked actual window views after integration. Runtime validation still passes, including exactly one ground-blend material and preservation of the third-floor eye height and 20 moving actors. The combined Blender preview includes the packed image on a separate inward-facing dome; Godot-only horizon blending is not replicated there. Background is designed for classroom/window viewing, not unrestricted aerial travel. Production main scene remains untouched.

## Japanese building layout update

The supplied GLB's metadata explicitly identifies Michał Solarek and CC-BY-4.0. Seven building groups were extracted and 72 shared-mesh instances placed around the campus. Normalized building heights approximately 6.7–11.4 m; district building footprint approximately 193 × 192 m. Original base/terrain omitted. All building AABBs checked outside campus bounds and bottom-aligned to -7.2 m, without errors. Runtime instance count/actor/eye-height checks pass. Actual window views and overview rendered; primary street fronts face the school. Author credit appears on-screen and in ATTRIBUTION.md, also copied into the standalone Godot project.

Added paved exterior blocks and secondary residential lanes; moved the outer trees beyond the building rows to avoid the earlier tree/building intersections. Latest combined Blender file is `school_with_japanese_town.blend`. The earlier `school_with_town.blend` is now a campus/background intermediate. Original download and working school blend remain unchanged. No production collision, web FPS, VRAM or interaction acceptance is claimed.
