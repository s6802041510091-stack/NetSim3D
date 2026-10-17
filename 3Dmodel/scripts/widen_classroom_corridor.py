"""Double the clear central corridor, preserving both furnished room wings.

Run with Blender --background --python this_file.py. No Godot exports touched.
"""
import bpy
import json
import shutil
from collections import Counter
from datetime import datetime
from pathlib import Path
from mathutils import Vector

ROOT = Path('D:/NetSim3D/3Dmodel')
SOURCE = ROOT / 'blend/classroom_shell.blend'
OUT = ROOT / 'temp/corridor_resize'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
assert not scene.get('corridor_double_width_revision'), 'Already widened; refusing to widen twice.'
DELTA = float(scene['map_clear_corridor_width_m'])
assert abs(DELTA - 2.9645070422535205) < 0.0001
MID = -7.63225352112676

def bbox(obj):
    pts = [obj.matrix_world @ Vector(p) for p in obj.bound_box] if obj.type in {'MESH', 'CURVE', 'FONT'} else [obj.matrix_world.translation]
    return [[min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]]

objects = list(scene.objects)
before = {o.name: {'matrix': o.matrix_world.copy(), 'bounds': bbox(o), 'data': o.data, 'parent': o.parent} for o in objects}
stretch = {'Corridor_Floor', 'Corridor_Ceiling'} | {o.name for o in objects if o.name.startswith(('Corridor_North_End_End', 'Corridor_South_End_End'))}
assert len(stretch) == 8
half = {'Room_Corridor', 'Plan_Corridor', 'Map_Camera_Top', 'Map_Camera_Overview'} | {o.name for o in objects if o.name.startswith('Corridor_Light')}
roots = {}
for o in objects:
    r = o
    while r.parent:
        r = r.parent
    roots.setdefault(r.name, []).append(o)

offset = {}
root_offsets = {}
for name, group in roots.items():
    root = bpy.data.objects[name]
    if name in stretch:
        assert len(group) == 1, name
        dx = 0
    elif name in half:
        dx = DELTA / 2
    elif name == 'Corridor_Edge_Inlay.001':
        dx = DELTA
    elif name in {'Corridor_Edge_Inlay', 'Map_Sun'}:
        dx = 0
    else:
        geometry = [o for o in group if o.type in {'MESH', 'CURVE', 'FONT'}]
        points = geometry or [root]
        lo = min(before[o.name]['bounds'][0][0] for o in points)
        hi = max(before[o.name]['bounds'][1][0] for o in points)
        assert not (lo < MID - 0.1 and hi > MID + 0.1), ('Ambiguous hierarchy crossing corridor', name, lo, hi)
        dx = DELTA if (lo + hi) / 2 > MID else 0
    root_offsets[name] = dx
    for o in group:
        offset[o.name] = dx

backup = SOURCE.with_name('classroom_shell_before_corridor_double_' + datetime.now().strftime('%Y%m%d_%H%M%S') + '.blend')
assert not backup.exists()
shutil.copy2(SOURCE, backup)
print('BACKUP', backup, flush=True)

# Only eight structural meshes expand; every other mesh is translated intact.
for name in stretch:
    o = bpy.data.objects[name]
    assert o.type == 'MESH' and not o.parent
    if o.data.users > 1:
        o.data = o.data.copy()
    lo, hi = before[name]['bounds'][0][0], before[name]['bounds'][1][0]
    inv = o.matrix_world.inverted()
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        p.x += DELTA * (p.x - lo) / (hi - lo)
        v.co = inv @ p
    o.data.update()

for name, dx in root_offsets.items():
    if dx:
        o = bpy.data.objects[name]
        m = o.matrix_world.copy()
        m.translation.x += dx
        o.matrix_world = m
bpy.context.view_layer.update()

errors = []
max_error = 0
for o in objects:
    old = before[o.name]
    if o.name in stretch:
        expected_bounds = [old['bounds'][0][:], old['bounds'][1][:]]
        expected_bounds[1][0] += DELTA
    else:
        assert o.data == old['data'], ('Nonstructural mesh changed', o.name)
        expected_bounds = [[p[0] + offset[o.name], p[1], p[2]] for p in old['bounds']]
        expected_matrix = old['matrix'].copy()
        expected_matrix.translation.x += offset[o.name]
        matrix_error = max(abs(o.matrix_world[i][j] - expected_matrix[i][j]) for i in range(4) for j in range(4))
        if matrix_error > 0.0001:
            errors.append([o.name, 'matrix', matrix_error])
    actual = bbox(o)
    error = max(abs(actual[i][j] - expected_bounds[i][j]) for i in range(2) for j in range(3))
    max_error = max(max_error, error)
    if error > 0.0001:
        errors.append([o.name, 'bounds', error])
assert not errors, errors[:20]
assert len(scene.objects) == len(objects)

for o in objects:
    if 'bounds_m' in o:
        values = list(o['bounds_m'])
        if o.name == 'Room_Corridor':
            values[1] += DELTA
        else:
            values[0] += offset[o.name]
            values[1] += offset[o.name]
        o['bounds_m'] = values
scene['map_clear_corridor_width_m'] = DELTA * 2
extent = list(scene['map_extent_m'])
extent[0] += DELTA
scene['map_extent_m'] = extent
scene['student_desk_column_x_m'] = ','.join(f'{x + DELTA:.6f}' for x in (-2.7, 2.7))
scene['corridor_double_width_revision'] = '2026-10-15: fixed left wing, right wing translated, only corridor structure expanded'
scene['corridor_original_clear_width_m'] = DELTA
scene['corridor_right_wing_offset_x_m'] = DELTA
note = bpy.data.texts.new('READ_ME | Corridor width revision')
note.write(f'Central corridor widened from {DELTA:.6f} m to {DELTA * 2:.6f} m clear width.\n'
           f'Left wing unchanged. Entire right wing translated +{DELTA:.6f} m on world X.\n'
           'Room sizes, furniture meshes, door hinges and parent relationships preserved.\n'
           'Corridor floor, ceiling, end walls and skirting extended. Lights recentered.\n'
           'Earlier build/furnishing scripts use OLD world coordinates; do not rerun them without applying the right-wing offset.\n'
           'Godot scene and exported assets have NOT been changed by this Blender revision.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)
report = {'source': str(SOURCE), 'backup': str(backup), 'objects_checked': len(objects),
          'old_clear_width_m': DELTA, 'new_clear_width_m': DELTA * 2,
          'right_wing_translation_x_m': DELTA, 'max_bounds_error_m': max_error,
          'objects_by_translation': dict(Counter(str(round(v, 6)) for v in offset.values())),
          'expanded_meshes': sorted(stretch), 'errors': errors,
          'floor_bounds': bbox(bpy.data.objects['Corridor_Floor']),
          'ceiling_bounds': bbox(bpy.data.objects['Corridor_Ceiling'])}
(OUT / 'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('VALIDATED_AND_SAVED', json.dumps(report), flush=True)
