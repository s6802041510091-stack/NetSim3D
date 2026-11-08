"""Run with Blender after Godot tools/export_grip_geometry.gd (without --baseline)."""
from pathlib import Path
import json
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
scratch = ROOT / 'tmp/avatar_arm_export'
data = json.loads((scratch / 'grip_runtime_geometry.json').read_text())
report = {}
for item_id, entry in data.items():
    hand = entry['hand']
    tool_bvh = BVHTree.FromPolygons(entry['vertices'], entry['triangles'], all_triangles=True)
    hand_bvh = BVHTree.FromPolygons(hand['vertices'], hand['triangles'], all_triangles=True)
    overlaps = len(hand_bvh.overlap(tool_bvh))
    clearance = min(tool_bvh.find_nearest(Vector(point))[3] for point in hand['vertices'])
    passed = overlaps == 0 and clearance < .003
    report[item_id] = {'surface_intersection_pairs': overlaps, 'nearest_contact_mm': clearance * 1000, 'passed': passed}
    print('GRIP_CHECK', item_id, report[item_id], flush=True)
(scratch / 'grip_validation.json').write_text(json.dumps(report, indent=2))
assert data and all(row['passed'] for row in report.values()), 'A held item intersects the hand or floats more than 3mm away'
print('ALL_RUNTIME_GRIPS_VALID', len(data), flush=True)
