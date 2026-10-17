"""Repair only existing case-panel aperture vertices; preserve saved scene edits."""
import bpy
import math
import json
import hashlib
from pathlib import Path
from mathutils import Vector

BASE = Path('D:/NetSim3D/3Dmodel')
OUTDIR = BASE / 'temp/teacher_computer_set/case_aperture_fix'
OUTDIR.mkdir(parents=True, exist_ok=True)
OUT = OUTDIR / 'teacher_computer_set_fixed.blend'
pc = bpy.data.objects['01_Case']
obj = bpy.data.objects['01_Case_StaticDetails']
mesh = obj.data
to_case = pc.matrix_world.inverted() @ obj.matrix_world

def object_signature(o):
    h = hashlib.sha256()
    h.update(str([list(row) for row in o.matrix_world]).encode())
    if o.type == 'MESH':
        for v in o.data.vertices:
            h.update(str(tuple(v.co)).encode())
    return h.hexdigest()

before = {o.name: object_signature(o) for o in bpy.data.objects if o != obj}
neighbors = [[] for _ in mesh.vertices]
for e in mesh.edges:
    a,b = e.vertices
    neighbors[a].append(b)
    neighbors[b].append(a)
remaining = set(range(len(mesh.vertices)))
panels = {}
while remaining:
    queue = [remaining.pop()]
    island = []
    while queue:
        i = queue.pop()
        island.append(i)
        for j in neighbors[i]:
            if j in remaining:
                remaining.remove(j)
                queue.append(j)
    if len(island) < 100:
        continue
    coords = [to_case @ mesh.vertices[i].co for i in island]
    lo = [min(v[a] for v in coords) for a in range(3)]
    hi = [max(v[a] for v in coords) for a in range(3)]
    if abs((hi[0]-lo[0])-.176)<1e-5 and abs((hi[2]-lo[2])-.354)<1e-5:
        if hi[1] < -.160:
            panels['front'] = island
        elif lo[1] > .160:
            panels['rear'] = island
assert set(panels) == {'front','rear'}, panels.keys()

def rr(w,h,r,n=4):
    pts=[]
    for cx,cy,a in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),(-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)]:
        for j in range(n+1):
            t=math.radians(a+j*90/n)
            pts.append((cx+r*math.cos(t),cy+r*math.sin(t)))
    return pts

def contour(kind):
    if kind=='RJ45': return [(-6.2,5),(6.2,5),(6.2,-2.3),(3.2,-2.3),(3.2,-4.9),(-3.2,-4.9),(-3.2,-2.3),(-6.2,-2.3)]
    if kind.startswith('USB_A'): return rr(12.5,5.5,.45)
    if kind=='USB_C': return rr(8.4,2.6,1.25,8)
    if kind=='DP': return [(-8,2.55),(6.1,2.55),(8,.65),(8,-2.55),(-8,-2.55)]
    if kind=='HDMI': return [(-6.9,2.25),(6.9,2.25),(6.9,-.7),(4.9,-2.25),(-4.9,-2.25),(-6.9,-.7)]
    if kind=='C14': return [(-12,7),(-8,10),(8,10),(12,7),(12,-10),(-12,-10)]
    if kind=='AUDIO': return [(1.85*math.cos(i*math.tau/32),1.85*math.sin(i*math.tau/32)) for i in range(32)]
    raise ValueError(kind)

jobs=[('front',bpy.data.objects['Front_Grille_Mount'],rr(100,250,3)),
      ('rear',bpy.data.objects['Rear_Exhaust_Mount'],[(36*math.cos(i*math.tau/64),36*math.sin(i*math.tau/64)) for i in range(64)])]
for o in bpy.data.objects:
    if o.name.startswith('Socket_') and o.parent == pc:
        jobs.append(('front' if o.location.y<0 else 'rear',o,contour(o['connector_type'])))

changes=[]
changed_ids=set()
for panel,marker,profile in jobs:
    local_from_mesh=marker.matrix_world.inverted() @ obj.matrix_world
    mesh_from_local=local_from_mesh.inverted()
    w=max(x for x,y in profile)-min(x for x,y in profile)
    h=max(y for x,y in profile)-min(y for x,y in profile)
    count=0
    for i in panels[panel]:
        v=mesh.vertices[i]
        co=local_from_mesh @ v.co
        for x,y in profile:
            if abs(co.x-x*1.12*.001)<2e-6 and abs(co.y-y*1.12*.001)<2e-6:
                assert i not in changed_ids
                co.x=x*(1+.3/w)*.001
                co.y=y*(1+.3/h)*.001
                v.co=mesh_from_local @ co
                count+=1
                changed_ids.add(i)
                break
    assert count==len(profile)*2, (marker.name,count,len(profile)*2)
    changes.append({'opening':marker.name,'boundary_vertices':count,'clearance_per_side_mm':.15})
mesh.update()
bpy.context.view_layer.update()

# Cast short rays through every previously uncovered area on all four grille edges.
# This proves the actual shell geometry blocks the view; a dark render alone cannot.
deps=bpy.context.evaluated_depsgraph_get()
case_world=pc.matrix_world
samples=[(20,303),(20,37),(-33,170),(73,170)]
for z in (60,120,180,240,280):
    samples.extend([(-33,z),(73,z)])
ray_results=[]
for x,z in samples:
    origin=case_world @ Vector((x*.001,-.19,z*.001))
    direction=case_world.to_3x3() @ Vector((0,1,0))
    hit,location,normal,face,hitobj,matrix=bpy.context.scene.ray_cast(deps,origin,direction,distance=.03)
    assert hit and hitobj.original==obj, ('unsealed_front_gap',x,z,hit,hitobj)
    ray_results.append({'x_mm':x,'z_mm':z,'blocked':True})

# A centre ray in USB-A must enter the socket instead of hitting the fascia face.
port_check=[]
for name in ('Socket_Front_USB_A1','Socket_Rear_USB_A1','Socket_LAN_RJ45'):
    socket=bpy.data.objects[name]
    origin=socket.matrix_world @ Vector((0,-.001,.005))
    direction=socket.matrix_world.to_3x3() @ Vector((0,0,-1))
    hit,location,*_=bpy.context.scene.ray_cast(deps,origin,direction,distance=.03)
    assert hit,name
    depth=(socket.matrix_world.inverted() @ location).z
    assert depth < -.001,(name,depth)
    port_check.append({'name':name,'first_hit_depth_m':depth})

assert all(object_signature(bpy.data.objects[name])==value for name,value in before.items()), 'Unrelated object changed'
report={'fixed_openings':changes,'changed_vertices':len(changed_ids),'grille_gap_ray_checks':ray_results,'ports_remain_open':port_check,'unrelated_objects_preserved':True}
(OUTDIR/'repair_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
print('REPAIR_VALIDATED',json.dumps(report),flush=True)

# Render direct-front plus oblique views using the saved studio lighting.
scene=bpy.context.scene
camera=bpy.data.objects['Camera_Hero']
saved_matrix=camera.matrix_world.copy()
saved_type=camera.data.type
saved_lens=camera.data.lens
saved_res=(scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)
saved_path=scene.render.filepath
scene.camera=camera
scene.render.resolution_percentage=100
scene.cycles.samples=32
def shot(name,pos,target,scale=None):
    camera.location=case_world @ Vector(pos)
    target_world=case_world @ Vector(target)
    camera.rotation_euler=(target_world-camera.location).to_track_quat('-Z','Y').to_euler()
    if scale:
        camera.data.type='ORTHO'
        camera.data.ortho_scale=scale
    else:
        camera.data.type='PERSP'
        camera.data.lens=55
    scene.render.resolution_x=950
    scene.render.resolution_y=1150
    scene.render.filepath=str(BASE/'ใช้ร่วมกัน/renders'/f'teacher_computer_case_fixed_{name}.png')
    bpy.ops.render.render(write_still=True)
shot('front',(0,-.9,.19),(0,-.166,.187),.415)
shot('angle',(.42,-.85,.48),(0,-.07,.19))
shot('rear',(.36,.82,.43),(0,.16,.21))
camera.matrix_world=saved_matrix
camera.data.type=saved_type
camera.data.lens=saved_lens
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=saved_res
scene.render.filepath=saved_path
print('REPAIR_RENDER_COMPLETE',flush=True)
