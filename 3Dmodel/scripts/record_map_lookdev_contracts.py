"""Record existing Godot bindings without changing any scene or script."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Preview/โรงเรียนและเมือง/phase0'
baseline = json.loads((OUT / 'baseline.json').read_text(encoding='utf-8'))
main = (ROOT / 'net-sim-3d/scenes/main.tscn').read_text(encoding='utf-8')
prefixes = re.findall(r'^part_prefix = "([^"]+)"', main, re.M)
kinds = ('Leaf', 'Kick_Plate', 'Handle_Base', 'Lever')
door_objects = [o for o in baseline['objects'] if any(o['name'].startswith(prefix + kind) for prefix in prefixes for kind in kinds)]
screens = [o for o in baseline['objects'] if o['type'] == 'MESH' and 'Monitor_Display_Surface' in o['name']]
nodes = []
for block in re.split(r'(?=^\[node )', main, flags=re.M):
    if block.startswith('[node '):
        header = block.splitlines()[0]
        fields = [line for line in block.splitlines()[1:] if line.startswith(('position =', 'transform =', 'rotation =', 'part_prefix =', 'map_visual_path ='))]
        if fields:
            nodes.append({'header': header, 'properties': fields})
protected = {o['name']: o for o in json.loads((OUT / 'protected_objects.json').read_text(encoding='utf-8'))}
for o in door_objects:
    protected[o['name']] = o
(OUT / 'protected_objects.json').write_text(json.dumps(list(protected.values()), ensure_ascii=False, indent=2), encoding='utf-8')
baseline['summary']['protected_objects'] = len(protected)
(OUT / 'baseline.json').write_text(json.dumps(baseline, ensure_ascii=False, indent=2), encoding='utf-8')
(OUT / 'summary.json').write_text(json.dumps(baseline['summary'], ensure_ascii=False, indent=2), encoding='utf-8')
contracts = {'screen_binding': 'ComputerManager searches direct MeshInstance3D children of MapVisual whose names contain Monitor_Display_Surface.',
             'screen_names_blender': [o['name'] for o in screens],
             'blender_suffix_conversion': 'Godot named-screen mapping uses _001, _002, _003 in place of Blender .001, .002, .003; verify exported node names.',
             'door_prefixes_in_main': prefixes, 'door_part_kinds': kinds, 'door_mesh_names': [o['name'] for o in door_objects],
             'godot_static_transforms': nodes,
             'coordinate_conversion': 'Blender (x,y,z) => Godot (x,z,-y).',
             'pending_corridor_sync': {'right_wing_offset_x_m': 2.9645070422535205,
                                      'corridor_center_offset_x_m': 1.4822535211267603,
                                      'scope': 'Only associated right-wing placements move; do not add offset to all nodes. Regenerate collisions with the updated GLB in the same integration step.'},
             'warning': 'Snapshot only, not runtime verification. Do not rename/reparent/join interactive screen or door meshes without updating and testing bindings.'}
(OUT / 'godot_contracts.json').write_text(json.dumps(contracts, ensure_ascii=False, indent=2), encoding='utf-8')
print('CONTRACTS', len(screens), 'screens;', len(door_objects), 'door parts;', len(protected), 'protected objects')
