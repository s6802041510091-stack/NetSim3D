# Sakura town — pre-Phase 5 look development

## Latest: Japanese street buildings

Open **`school_with_japanese_town.blend`** for the latest combined Blender scene. The Godot preview project now uses 72 shared-mesh building instances extracted from the user-supplied *Stylized Little Japanese Town Street* by Michał Solarek (CC BY 4.0). Full credit and modification details: `ATTRIBUTION.md`.

The phrase “about 200 metres around the school” is implemented as a roughly 200 × 200 m overall district, **not** a 200 m radius. Verified building bounds are approximately 193 × 192 m. Seven variants retain the author's textures and are rotated to face the ring road. The source's terrain and base were omitted; buildings rescaled by 0.018 to approximately 6.7–11.4 m tall. Outer rows add depth, with paving and secondary lanes. Existing school ground offset, field, garden, wall, walkers, cyclists and painted far sky remain.

`japanese_layout_verification.json` checks ground alignment and exclusion of buildings from the campus. `godot_preview/validation.json` checks the 72 imported instances plus existing actor and eye-height tests. Repeated meshes share resources; this is not yet a measured web-performance pass. Buildings have no newly supplied gameplay collision/interiors.

Rebuild sequence: `school_town.py -- --campus-only`, `school_town.py -- --combine`, `japanese_town_layout.py -- --build`, then `japanese_town_layout.py -- --combine`, each run through Blender's `--python` option. The inspect mode of `japanese_town_layout.py` initially reads the user's GLB and saves `japanese_source_inspected.blend`. Do not run the old default town build if you want to preserve this replacement of procedural houses.

`school_with_town.blend` is now the campus/background intermediate for the Japanese layout, not the final district file.

An isolated, editable town surrounding the latest school, including its exterior windows.

- Ground is Z = -7.2 m in Blender (Y = -7.2 in Godot). Existing playable floor stays at 0; a 1.65 m eye is 8.85 m above the grounds. Two supporting facade storeys establish the school as a three-storey building without moving rooms or mission objects.
- Low school wall and south entrance, playing field, garden paths, sakura trees, benches, pastel houses, cafe/bakery/book/flower storefronts, sidewalks, ring road and crosswalk. The distant skyline is now a painted 2D panorama with city, mountains and clouds.
- Procedural low-poly geometry with reusable pastel materials and 14 locally generated texture sets (base color, roughness, normal): roof seams, paving joints, wood grain, plaster, turf and asphalt. No third-party downloaded assets. This is an initial art pass, not a final production town.
- Godot preview adds 14 looping walkers, 6 cyclists and 80 drifting petals. Actors are lightweight stylized figures with procedural limb/wheel movement, not rigged production characters. Paths are rectangular and turns currently sharp.

## Painted background update

`godot_preview/town_panorama_v1.png` is an AI-generated 2172 × 724 matte-painting texture made with the built-in imagegen tool. The prompt is saved in `BACKDROP_PROMPT.md`. The image is project-local and also packed into the combined Blender preview.

Godot maps it to a 360-degree sky using mirrored hemispheres (not a true unique 360-degree photographed panorama), fades the zenith and blends distant ground into the matching image to reduce the hard green horizon. Replaced the previous polygon hills and floating 3D cloud shapes. The background is intentionally static, without parallax, optimized compositionally for the school's third-floor window views; it is not a traversable city extension.

Blender's combined preview contains a large inward-facing image dome named `BACKGROUND 2D | painted city mountains sky`. Switch to Material Preview or Rendered to see its texture; Solid uses wire display. The Godot horizon-blending shader is runtime-only, so Blender's ground transition is not identical.

## Open

Open `godot_preview/project.godot` in Godot 4.7 and run. Keys 1–5 change views, WASD moves, Q/E moves vertically, arrow keys look around. Views 2–4 are at the unchanged third-floor eye height, looking through actual school windows.

`school_with_town.blend` combines the school with the static exterior in a separate preview file. `town.blend` is the editable static exterior only. `godot_preview/architecture.glb` is a fresh export of the school working file; `town.glb` is material-batched town geometry. Animation lives in `preview.gd`, not Blender.

## Rebuild / test

Use Blender in background with `--python-exit-code 1 --python 3Dmodel/scripts/school_town.py` for the town, append `-- --school` for the school export or `-- --combine` for the combined Blender preview. Import the preview project in Godot before running. `-- --validate` writes `validation.json`; `-- --capture` writes five runtime screenshots. In a restricted environment, supply `--log-file` pointing to a writable project path; this avoids Godot failing to create its default user log directory. Shader-cache/editor-settings warnings in that environment do not signify successful production acceptance.

The original school blend, working lookdev blend, production main scene, mission positions, and production collision are not edited by this workflow. Production integration, physics, door/screen interaction and web/FPS/memory acceptance remain Phase 5 work. The school preview GLB is large (~322 MB); this preview is not a web-ready optimized distribution.
