"""Independent validation of the saved Blender asset and exported GLB."""
import bpy
import json
import struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

root = Path(__file__).resolve().parent
if (root/'exports'/'pc_tower_realism_validation.json').exists():
    import runpy
    runpy.run_path(str(root/'validate_pc_tower_realism.py'),run_name='__main__')
    raise SystemExit(0)
path = root/'exports'/'pc_tower_nic.glb'
raw = path.read_bytes()
magic, version, length = struct.unpack_from('<4sII',raw)
assert (magic,version,length)==(b'glTF',2,len(raw))
chunk_length, chunk_type = struct.unpack_from('<II',raw,12)
assert chunk_type==0x4E4F534A
gltf=json.loads(raw[20:20+chunk_length])
names={n['name']:i for i,n in enumerate(gltf['nodes'])}
original={'PC_Tower','Case_Body','Side_Cover','Interior','NIC_Card','Power_LED','NIC_Link_LED','NIC_Port_Point'}
interactions=json.loads((root/'exports'/'pc_tower_interactions.json').read_text(encoding='utf-8'))
required=original|set(interactions)|{'PCIe_Slot_Target'}
assert required <= names.keys(), names
assert set(interactions)=={'Cover_Screw_1','Cover_Screw_2','NIC_Bracket_Screw','Power_Button','Power_Cable_Plug'}
root_children=gltf['nodes'][names['PC_Tower']]['children']
for name in set(interactions)|{'PCIe_Slot_Target'}:
    assert names[name] in root_children, name
for name,data in interactions.items():
    node=gltf['nodes'][names[name]]
    assert 'mesh' in node and node['extras']['interaction_id']==name
assert len({gltf['nodes'][names[name]]['mesh'] for name in interactions})==5
# Regression comparison against the pre-task-2 asset, when available locally.
baseline=root.parents[1]/'tmp'/'pc_tower_before_task2'/'pc_tower_nic.glb'
if baseline.exists():
    data=baseline.read_bytes()
    size=struct.unpack_from('<I',data,12)[0]
    before=json.loads(data[20:20+size])
    old={n['name']:n for n in before['nodes']}
    for name in original:
        current=gltf['nodes'][names[name]]
        for key in ('translation','rotation','scale','matrix'):
            assert current.get(key)==old[name].get(key), (name,key,current.get(key),old[name].get(key))
children=gltf['nodes'][names['NIC_Card']]['children']
assert names['NIC_Link_LED'] in children and names['NIC_Port_Point'] in children
assert not gltf.get('images') and not gltf.get('textures')
assert not gltf.get('cameras')
assert 'KHR_lights_punctual' not in gltf.get('extensions',{})
triangles=0
for mesh in gltf['meshes']:
    for p in mesh['primitives']:
        assert p.get('mode',4)==4
        triangles += gltf['accessors'][p['indices']]['count']//3
assert triangles<=20000, triangles

bpy.ops.wm.open_mainfile(filepath=str(root/'pc_tower_nic.blend'))
assert {o.name for o in bpy.data.objects}==required
assert all(o.type not in {'LIGHT','CAMERA'} and not o.modifiers for o in bpy.data.objects)
assert all((o.scale-Vector((1,1,1))).length<1e-6 for o in bpy.data.objects)
assert bpy.data.objects['PC_Tower'].location.length==0
assert (bpy.data.objects['PCIe_Slot_Target'].matrix_world.translation-bpy.data.objects['NIC_Card'].matrix_world.translation).length<1e-6

def tree(obj,offset=0):
    vertices=[obj.matrix_world@v.co+Vector((-offset,0,0)) for v in obj.data.vertices]
    return BVHTree.FromPolygons(vertices,[list(p.vertices) for p in obj.data.polygons])

# After 10 mm travel the gold fingers have cleared the PCIe socket.
# Check every 5 mm through the -X extraction trajectory, with side panel removed.
fixed={name:tree(bpy.data.objects[name]) for name in ('Case_Body','Interior')}
nic=bpy.data.objects['NIC_Card']
for step in range(2,61):
    moving=tree(nic,step*.005)
    for name,bvh in fixed.items():
        overlaps=moving.overlap(bvh)
        assert not overlaps, (step*.005,name,len(overlaps))

# Import the actual exported bytes and check Blender <-> glTF axis conversion.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
bpy.context.view_layer.update()
nic=bpy.data.objects['NIC_Card']
port=bpy.data.objects['NIC_Port_Point']
assert port.parent==nic
assert bpy.data.objects['NIC_Link_LED'].parent==nic
assert (nic.matrix_world.translation-Vector((.045,.145,.118))).length<1e-6
assert (port.matrix_world.to_3x3()@Vector((0,0,-1))-Vector((0,-1,0))).length<1e-6
for name in interactions:
    assert bpy.data.objects[name].parent.name=='PC_Tower'
assert (bpy.data.objects['PCIe_Slot_Target'].matrix_world.translation-nic.matrix_world.translation).length<1e-6
vertices=[o.matrix_world@v.co for o in bpy.data.objects if o.type=='MESH' and o.name not in interactions for v in o.data.vertices]
low=[min(v[i] for v in vertices) for i in range(3)]
high=[max(v[i] for v in vertices) for i in range(3)]
assert all(abs(high[i]-low[i]-s)<1e-5 for i,s in enumerate((.19,.4,.4))), (low,high)
report_path=root/'exports'/'pc_tower_nic_validation.json'
report=json.loads(report_path.read_text(encoding='utf-8'))
assert triangles==report['triangles']
report.update(glb_bytes=len(raw),glb_triangles=triangles,glb_reimport='passed',
              nic_extraction='no triangle intersections with Case_Body/Interior from 10 to 300 mm at 5 mm intervals',
              required_hierarchy='passed',clean_source='passed', independent_interaction_meshes='passed',
              original_transforms='unchanged vs baseline' if baseline.exists() else 'baseline unavailable',
              pcie_target='matches NIC_Card origin')
report_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
print('VALIDATION_PASSED',json.dumps(report),flush=True)
