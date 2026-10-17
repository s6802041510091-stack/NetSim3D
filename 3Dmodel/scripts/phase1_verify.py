"""Read-only verification of Phase 1 against the Phase 0 snapshot."""
import bpy,json,hashlib,array,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Preview/โรงเรียนและเมือง/phase1'
baseline=json.loads((ROOT/'Preview/โรงเรียนและเมือง/phase0/baseline.json').read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend'))
def digest(mesh):
    h=hashlib.sha256()
    for collection,attr,width,dtype in [(mesh.vertices,'co',3,'f'),(mesh.loops,'vertex_index',1,'i'),(mesh.polygons,'loop_total',1,'i')]:
        buf=array.array(dtype,[0])*(len(collection)*width); collection.foreach_get(attr,buf); h.update(buf.tobytes())
    return h.hexdigest()
changed=set(json.loads(bpy.context.scene['phase1_changed_objects']))
errors=[]; screens=0; geometry_checked=0; cache={}
for old in baseline['objects']:
    name=old['name']; o=bpy.context.scene.objects.get(name)
    if o is None: errors.append('missing '+name); continue
    if max(abs(o.matrix_world[i][j]-old['world_matrix'][i][j]) for i in range(4) for j in range(4))>1e-5: errors.append('moved '+name)
    if (o.parent.name if o.parent else None)!=old['parent']: errors.append('parent '+name)
    if o.type=='MESH' and name not in changed:
        if o.data.name not in cache: cache[o.data.name]=digest(o.data)
        if cache[o.data.name]!=old['geometry_sha256']: errors.append('geometry '+name)
        geometry_checked+=1
    if 'Monitor_Display_Surface' in name:
        screens+=1
        if name in changed: errors.append('screen changed '+name)
    if name in changed:
        uv=o.data.uv_layers.get('P1_SurfaceUV')
        if uv is None or not uv.active_render: errors.append('render UV '+name)
        elif any(not math.isfinite(v) for loop in uv.data for v in loop.uv): errors.append('invalid UV '+name)
original_files=0
for file,expected in baseline['file_hashes'].items():
    h=hashlib.sha256()
    with (ROOT/file).open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    original_files+=1
    if h.hexdigest()!=expected: errors.append('source file modified '+file)
images=[i for i in bpy.data.images if i.name.startswith('T_')]
if len(images)!=27 or not all(i.packed_file for i in images): errors.append('packed textures')
report={'passed':not errors,'original_objects_checked':len(baseline['objects']),'unmodified_mesh_instances_checked':geometry_checked,
        'interactive_screens_preserved':screens,'original_files_unchanged':original_files,'packed_texture_images':len(images),
        'changed_mesh_instances':len(changed),'errors':errors,'web_performance_tested':False,'main_game_interactions_tested':False}
(OUT/'final_verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('P1_FINAL_VERIFICATION',json.dumps(report),flush=True)
assert not errors,errors
