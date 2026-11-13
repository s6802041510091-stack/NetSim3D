"""Validate final source and the GLB bytes against the pre-realism contract."""
import bpy, json, struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT=Path(__file__).resolve().parent
baseline=json.loads((OUT/'revisions/before_realism/contract.json').read_text(encoding='utf-8'))
report_path=OUT/'exports/pc_tower_realism_validation.json'
report=json.loads(report_path.read_text(encoding='utf-8'))
raw=(OUT/'exports/pc_tower_nic.glb').read_bytes()
assert struct.unpack_from('<4sII',raw)==(b'glTF',2,len(raw))
size,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
doc=json.loads(raw[20:20+size]);bin_offset=20+size+8
assert {n['name'] for n in doc['nodes']}==set(baseline)
assert not doc.get('cameras') and 'KHR_lights_punctual' not in doc.get('extensions',{})
tris=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
assert tris==report['triangles'] and tris<=20000
texture_sizes=[]
for image in doc.get('images',[]):
    view=doc['bufferViews'][image['bufferView']];start=bin_offset+view.get('byteOffset',0)
    data=raw[start:start+view['byteLength']]
    assert data[:8]==b'\x89PNG\r\n\x1a\n'
    w,h=struct.unpack_from('>II',data,16);assert max(w,h)<=1024
    texture_sizes.append([w,h])
assert texture_sizes==[[1024,1024]]
assert all('pbrMetallicRoughness' in m for m in doc['materials'])

def validate_contract():
    bpy.context.view_layer.update()
    assert {o.name for o in bpy.context.scene.objects}==set(baseline)
    for name,old in baseline.items():
        o=bpy.data.objects[name]
        assert (o.parent.name if o.parent else None)==old['parent'],name
        assert (o.matrix_world.translation-Vector(old['origin_world'])).length<2e-6,name
        assert (o.dimensions-Vector(old['dimensions'])).length<3e-6,(name,list(o.dimensions),old['dimensions'])
        assert max(abs(o.matrix_local[r][c]-old['matrix_local'][r][c]) for r in range(4) for c in range(4))<2e-6,name
    assert (bpy.data.objects['PCIe_Slot_Target'].matrix_world.translation-
            bpy.data.objects['NIC_Card'].matrix_world.translation).length<1e-6
    plug=bpy.data.objects['Power_Cable_Plug']
    assert min((plug.matrix_world@v.co).z for v in plug.data.vertices)>=.00399

bpy.ops.wm.open_mainfile(filepath=str(OUT/'pc_tower_nic.blend'))
validate_contract()
assert all(not o.modifiers for o in bpy.context.scene.objects)
for material in bpy.data.materials:
    if material.users:
        assert material.use_nodes and material.node_tree.nodes.get('Principled BSDF'),material.name
assert all(max(image.size)<=1024 for image in bpy.data.images if image.type=='IMAGE' and image.users)

# Re-import the actual GLB, then repeat transform and dimension checks.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'exports/pc_tower_nic.glb'))
validate_contract()
def tree(o,dx=0):
    return BVHTree.FromPolygons([o.matrix_world@v.co+Vector((dx,0,0)) for v in o.data.vertices],
                               [list(p.vertices) for p in o.data.polygons])
fixed={name:tree(bpy.data.objects[name]) for name in ('Case_Body','Interior')}
for step in range(2,61):
    moving=tree(bpy.data.objects['NIC_Card'],-step*.005)
    for name,t in fixed.items():assert not moving.overlap(t),(step,name)

# Every rear-panel sample outside the tightly fitted NIC aperture must hit opaque
# Case_Body metal at the rear sheet, before reaching any circuit-board geometry.
checks=0
for x in range(-91,92):
    for z in range(108,143):
        if -12.8<x<76.8 and 116.7<z<135.3:continue
        point,normal,index,distance=fixed['Case_Body'].ray_cast(Vector((x*.001,.25,z*.001)),Vector((0,-1,0)),.06)
        assert point is not None and point.y>=.19969,(x,z,point)
        checks+=1
report.update(glb_bytes=len(raw),glb_triangles=tris,glb_texture_sizes=texture_sizes,
              source_contract='passed for all 14 objects',glb_contract='passed for all 14 objects',
              no_unapplied_modifiers='passed',pbr_materials='passed',
              nic_extraction='clear from 10 to 300 mm, every 5 mm, cover/screw removed',
              rear_panel_opaque_samples=checks,rear_panel='passed',cable_above_table='passed')
report_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
# Keep the primary delivery validation summary current too.
summary={k:v for k,v in report.items() if k not in ('before','after')}
summary['dimensions_blender_m']=[.19,.4,.4]
(OUT/'exports/pc_tower_nic_validation.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print('REALISM_VALIDATION_PASSED',json.dumps(summary),flush=True)
