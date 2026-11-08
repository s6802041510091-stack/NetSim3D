"""Read-only triangle/object audit of the school lookdev for the web budget.

Run: blender -b --python 3Dmodel/scripts/inspect_school_web_budget.py -- <out.json>
Never saves the .blend. Counts evaluated triangles (modifiers applied), the same
geometry the glTF export with export_apply=True produces.
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend"


def main(out_path):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    rows = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.hide_render or obj.name.startswith("Plan_"):
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
        rows.append({
            "name": obj.name,
            "tris": tris,
            "data": obj.data.name,
            "parent": obj.parent.name if obj.parent else "",
            "collection": obj.users_collection[0].name if obj.users_collection else "",
            "collision": obj.get("collision", ""),
            "modifiers": [m.type for m in obj.modifiers],
            "dims": [round(d, 3) for d in obj.dimensions],
        })
    by_collection = defaultdict(lambda: [0, 0])
    for r in rows:
        by_collection[r["collection"]][0] += 1
        by_collection[r["collection"]][1] += r["tris"]
    report = {
        "objects": len(rows),
        "tris": sum(r["tris"] for r in rows),
        "by_collection": sorted(([k, v[0], v[1]] for k, v in by_collection.items()), key=lambda x: -x[2]),
        "rows": rows,
    }
    Path(out_path).write_text(json.dumps(report, ensure_ascii=False), encoding="utf-8")
    print("SCHOOL_AUDIT", report["objects"], "objects", report["tris"], "tris", flush=True)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1])
