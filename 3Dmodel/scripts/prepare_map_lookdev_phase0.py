"""Read-only scene audit + isolated look-development baseline. Never export to Godot."""
import bpy
import array
import csv
import hashlib
import json
import re
import shutil
import zipfile
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '3Dmodel/lookdev/phase0'
SOURCE = ROOT / '3Dmodel/blend/classroom_shell.blend'
WORK = ROOT / '3Dmodel/lookdev/working/classroom_shell_lookdev.blend'
STAMP = datetime.now().strftime('%Y%m%d_%H%M%S')
BACKUP = ROOT / '3Dmodel/temp/lookdev_phase0_backups' / STAMP

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def write_json(name, value):
    (BASE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')

def write_csv(name, rows):
    if not rows:
        return
    with (BASE / name).open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

def serial(value):
    if hasattr(value, 'to_list'):
        return value.to_list()
    if hasattr(value, 'to_dict'):
        return {k: serial(v) for k, v in value.to_dict().items()}
    if isinstance(value, (str, bool, int, float)):
        return value
    return str(value)

def bounds(o):
    points = [o.matrix_world @ Vector(v) for v in o.bound_box] if o.type in {'MESH', 'CURVE', 'FONT'} else [o.matrix_world.translation]
    return [[min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]]

def mesh_fingerprint(mesh):
    h = hashlib.sha256()
    for collection, attr, width, dtype in [(mesh.vertices, 'co', 3, 'f'), (mesh.loops, 'vertex_index', 1, 'i'), (mesh.polygons, 'loop_total', 1, 'i')]:
        buf = array.array(dtype, [0]) * (len(collection) * width)
        collection.foreach_get(attr, buf)
        h.update(buf.tobytes())
    return h.hexdigest()

def category(o):
    n = o.name.lower()
    # Work queues, not a claim that all objects are unique assets.
    if 'monitor_display_surface' in n:
        return '03_interactive_screen_KEEP_NAME'
    if any(k in n for k in ('studentpc', 'teachercomputer', 'keyboard', 'mouse', 'hdmi', 'rj45', 'patch', 'power', 'outlet', 'socket', 'rack', 'server', 'staffpc')):
        return '03_computers_network_power'
    if any(k in n for k in ('plant', 'leaf', 'pot_', 'soil')):
        return '04_plants'
    if any(k in n for k in ('chair', 'sofa', 'cushion', 'rug')):
        return '04_seating_fabric'
    if any(k in n for k in ('desk', 'table', 'cabinet', 'locker', 'bookcase', 'shelf', 'drawer', 'partition')):
        return '04_furniture'
    if any(k in n for k in ('floor', 'wall', 'ceiling', 'stair', 'door', 'window', 'corridor', 'skirting')):
        return '02_architecture'
    if any(c.name.startswith('15') and 'Lab' in c.name for c in o.users_collection):
        return '04_science_props'
    return '04_props_manual_review'

assert not WORK.exists(), 'Working copy already exists: refusing overwrite.'
assert not (BASE / 'baseline.json').exists(), 'Baseline already exists: refusing overwrite.'
BASE.mkdir(parents=True, exist_ok=True)
BACKUP.mkdir(parents=True, exist_ok=False)
WORK.parent.mkdir(parents=True, exist_ok=True)

# Preserve both divergent states: widened Blender and pre-widening Godot.
files = {SOURCE, ROOT / 'net-sim-3d/project.godot', ROOT / 'net-sim-3d/assets/models/classroom_shell.glb'}
for folder in ('scripts', 'scenes', 'data', 'tools'):
    files.update(p for p in (ROOT / 'net-sim-3d' / folder).rglob('*') if p.is_file() and p.suffix in {'.gd', '.tscn', '.tres', '.json', '.py', '.uid'})
for p in (ROOT / '3Dmodel/scripts').glob('*.py'):
    files.add(p)
files = sorted(p for p in files if p.is_file())
hashes = {str(p.relative_to(ROOT)).replace('\\', '/'): sha(p) for p in files}
archive = BACKUP / 'map_and_godot_baseline.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1) as z:
    for p in files:
        z.write(p, p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name, expected in hashes.items():
        assert hashlib.sha256(z.read(name)).hexdigest() == expected, name
shutil.copy2(SOURCE, WORK)
assert sha(WORK) == hashes['3Dmodel/blend/classroom_shell.blend']
print('BACKUP_AND_WORKING_COPY_VERIFIED', flush=True)

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
bpy.context.view_layer.update()
objects = list(scene.objects)
mesh_objects = [o for o in objects if o.type == 'MESH']
meshes = {o.data for o in mesh_objects}
mesh_info = {}
for mesh in meshes:
    mesh.calc_loop_triangles()
    uv_info = []
    for layer in mesh.uv_layers:
        values = array.array('f', [0]) * (len(layer.data) * 2)
        layer.data.foreach_get('uv', values)
        us, vs = values[::2], values[1::2]
        uv_info.append({'name': layer.name, 'loops': len(us),
                        'u_range': [min(us), max(us)] if us else [],
                        'v_range': [min(vs), max(vs)] if vs else [],
                        'collapsed': not us or (max(us) - min(us) < 1e-7 and max(vs) - min(vs) < 1e-7)})
    mesh_info[mesh.name] = {'vertices': len(mesh.vertices), 'triangles_base': len(mesh.loop_triangles),
                           'uv': uv_info, 'geometry_sha256': mesh_fingerprint(mesh)}

object_records = []
csv_records = []
collections = defaultdict(list)
material_users = defaultdict(list)
shared = defaultdict(list)
protected = []
for o in objects:
    record = {'name': o.name, 'type': o.type, 'parent': o.parent.name if o.parent else None,
              'collections': sorted(c.name for c in o.users_collection),
              'world_matrix': [list(row) for row in o.matrix_world], 'bounds': bounds(o),
              'hide_render': o.hide_render, 'hide_viewport': o.hide_viewport, 'hide_set': o.hide_get(),
              'properties': {k: serial(v) for k, v in o.items()}}
    if o.type == 'MESH':
        info = mesh_info[o.data.name]
        record.update({'mesh': o.data.name, 'geometry_sha256': info['geometry_sha256'], 'category': category(o),
                       'materials': [m.name if m else '' for m in o.data.materials],
                       'modifiers': [{'name': m.name, 'type': m.type} for m in o.modifiers]})
        shared[o.data.name].append(o.name)
        for m in o.data.materials:
            if m:
                material_users[m.name].append(o.name)
        for c in o.users_collection:
            collections[c.name].append(o)
        csv_records.append({'object': o.name, 'category': record['category'], 'collections': ' | '.join(record['collections']),
                            'mesh': o.data.name, 'triangles_base': info['triangles_base'],
                            'uv_layers': len(info['uv']), 'collapsed_uv': any(u['collapsed'] for u in info['uv']),
                            'materials': ' | '.join(record['materials']), 'parent': record['parent'] or '',
                            'nonuniform_scale': max(o.scale) - min(o.scale) > 0.0001,
                            'negative_scale': o.matrix_world.determinant() < 0,
                            'modifier_count': len(o.modifiers)})
    object_records.append(record)
    if 'Monitor_Display_Surface' in o.name or o.name.startswith(('Door_', 'Room_', 'Player_Spawn', 'Floor01_Origin', 'StudentDesk_')) or o.name in {'IT_PlayerDesk', 'IT_HeadDesk', 'IT_SpareDesk', 'TeacherDesk'} or o.get('collision'):
        protected.append(record)

material_rows = []
for name, users in sorted(material_users.items()):
    m = bpy.data.materials[name]
    nodes = list(m.node_tree.nodes) if m.node_tree else []
    textures = [n for n in nodes if n.type == 'TEX_IMAGE' and n.image]
    procedural = [n.type for n in nodes if n.type.startswith('TEX_') and n.type != 'TEX_IMAGE']
    material_rows.append({'material': name, 'object_slot_references': len(users),
                          'image_nodes': len(textures), 'images': ' | '.join(n.image.name for n in textures),
                          'procedural_nodes': ' | '.join(procedural),
                          'node_types': ' | '.join(sorted(set(n.type for n in nodes))),
                          'example_object': users[0], 'action': 'Bake/export test' if procedural else 'UV and PBR review'})

collection_rows = [{'collection': name, 'mesh_objects': len(obs),
                    'unique_mesh_data': len({o.data.name for o in obs}),
                    'triangles_base_instanced': sum(mesh_info[o.data.name]['triangles_base'] for o in obs)}
                   for name, obs in sorted(collections.items())]
reusable = [{'mesh': name, 'instances': len(names), 'representative': names[0], 'objects': names}
            for name, names in shared.items() if len(names) > 1]
reusable.sort(key=lambda r: (-r['instances'], r['mesh']))
summary = {'scene_objects': len(objects), 'mesh_objects': len(mesh_objects), 'unique_mesh_data': len(meshes),
           'used_materials': len(material_rows), 'materials_with_images': sum(r['image_nodes'] > 0 for r in material_rows),
           'procedural_materials': sum(bool(r['procedural_nodes']) for r in material_rows),
           'unique_meshes_without_uv': sum(not i['uv'] for i in mesh_info.values()),
           'mesh_objects_without_uv': sum(not mesh_info[o.data.name]['uv'] for o in mesh_objects),
           'unique_meshes_with_collapsed_uv': sum(any(u['collapsed'] for u in i['uv']) for i in mesh_info.values()),
           'shared_mesh_groups': len(reusable), 'screen_meshes': sum('Monitor_Display_Surface' in o.name for o in mesh_objects),
           'triangles_base_instanced': sum(mesh_info[o.data.name]['triangles_base'] for o in mesh_objects),
           'triangles_base_unique': sum(i['triangles_base'] for i in mesh_info.values()),
           'protected_objects': len(protected), 'corridor_clear_width_m': scene.get('map_clear_corridor_width_m'),
           'godot_sync_status': 'NOT_SYNCED: Blender corridor widened; existing Godot GLB and placements unchanged',
           'uv_audit_limit': 'Layer presence/ranges/collapse only; overlap, texel density and bake suitability require visual checks.',
           'triangle_audit_limit': 'Base meshes, all scene mesh instances, before modifiers and export splitting; not runtime visible triangle count.'}
write_json('baseline.json', {'created': STAMP, 'source': str(SOURCE), 'working_copy': str(WORK),
                            'backup_zip': str(archive), 'file_hashes': hashes, 'summary': summary,
                            'scene_properties': {k: serial(v) for k, v in scene.items()}, 'objects': object_records, 'meshes': mesh_info})
write_json('summary.json', summary)
write_json('protected_objects.json', protected)
write_json('shared_mesh_candidates.json', reusable)
write_csv('objects.csv', csv_records)
write_csv('materials.csv', material_rows)
write_csv('collections.csv', collection_rows)
write_csv('shared_mesh_candidates.csv', [{k: v for k, v in r.items() if k != 'objects'} for r in reusable])

# Original assets and Godot files must remain byte-for-byte unchanged.
changed = [name for name, expected in hashes.items() if sha(ROOT / name) != expected]
assert not changed, changed
write_json('verification.json', {'original_files_unchanged': True, 'original_files_checked': len(hashes),
                               'backup_zip_verified': True, 'working_copy_matches_source': sha(WORK) == sha(SOURCE),
                               'no_scene_saved_or_exported': True})
print('PHASE0_SUMMARY', json.dumps(summary), flush=True)
print('PHASE0_DONE', BASE, flush=True)
