"""Read-only: list objects, sizes and materials in the phase3 device lookdev files.

Run: blender -b --python 3Dmodel/scripts/inspect_device_models.py
"""

from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1].parent
ASSETS = ROOT / "Preview/โรงเรียนและเมือง/phase3/assets"

for name in ("router_lookdev.blend", "switch8_lookdev.blend"):
    bpy.ops.wm.open_mainfile(filepath=str(ASSETS / name))
    print("FILE", name, "engine", bpy.context.scene.render.engine)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.hide_render]
    print("  mesh objects", len(meshes))
    for obj in sorted(meshes, key=lambda o: -max(o.dimensions))[:12]:
        mats = ",".join(m.name for m in obj.data.materials if m)
        print("  ", obj.name, [round(d, 3) for d in obj.dimensions], [round(v, 3) for v in obj.location], "|", mats[:80])
    print("  collections", [c.name for c in bpy.data.collections][:10])
    cams = [o.name for o in bpy.context.scene.objects if o.type == "CAMERA"]
    lights = [o.name for o in bpy.context.scene.objects if o.type == "LIGHT"]
    print("  cameras", cams, "lights", lights)
