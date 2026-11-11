"""Restore unwarped MakeHuman female feet and fit the original shoe proxy to them.

This supersedes the ankle taper and collar compression in the two previous
repair scripts. Arms, head, uniform and the rig's presentation pose are retained.
"""
import bpy, bmesh, json, shutil
from pathlib import Path
from collections import defaultdict
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT=Path('D:/NetSim3D/3Dmodel')
OUT=ROOT/'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm.blend'
BACKUP=ROOT/'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm_before_anatomical_feet_20261109.blend'
if not BACKUP.exists():
    raise SystemExit('This one-time repair is already applied to the approved model. Its historical input was removed; do not recreate it from the repaired output.')
bpy.ops.wm.open_mainfile(filepath=str(BACKUP))
bpy.context.preferences.filepaths.save_version=0
body=bpy.data.objects['Body | female head arms lower legs']
shoe=bpy.data.objects['Shoes | black Oxford with socks']
rig=bpy.data.objects['Teacher_Female_Rig']
asset=bpy.data.collections['TEACHER | female · 160 cm']
source=ROOT/'temp/teacher_male/source';female=ROOT/'temp/teacher_female/source'
folder=ROOT/'temp/teacher_male/system_assets/clothes/shoes04'
def read_obj(path):
    vs=[];uv=[];faces=[];groups=[];group=''
    for line in path.read_text().splitlines():
        t=line.split()
        if not t:continue
        if t[0]=='v':vs.append(Vector(tuple(map(float,t[1:4]))))
        elif t[0]=='vt':uv.append(tuple(map(float,t[1:3])))
        elif t[0]=='g':group=t[1]
        elif t[0]=='f':
            faces.append([(int(a.split('/')[0])-1,int(a.split('/')[1])-1) for a in t[1:]])
            groups.append(group)
    return vs,uv,faces,groups
verts,uvs,faces,groups=read_obj(source/'base.obj')
for filename,influence in [('asian-female-young.target',.9),('caucasian-female-young.target',.1),('universal-female-young-averagemuscle-averageweight.target',1.)]:
    for line in (female/filename).read_text().splitlines():
        t=line.split()
        if t and t[0].isdigit():verts[int(t[0])]+=Vector(tuple(float(x)*influence for x in t[1:4]))
floor=min(verts[i].y for f,g in zip(faces,groups) if g=='body' for i,_ in f)
def co(p):return Vector((p.x*.105,-p.z*.105,(p.y-floor)*.105+.026))
weights=defaultdict(dict)
for name,items in json.loads((source/'default_weights.mhw').read_text())['weights'].items():
    for i,w in items:weights[i][name]=w
def mesh(name,points,fs,uvs,mat,weights):
    data=bpy.data.meshes.new(name);data.from_pydata(points,[],[[i for i,_ in f] for f in fs]);data.update()
    obj=bpy.data.objects.new(name,data);asset.objects.link(obj)
    obj.parent=rig;data.materials.append(mat)
    layer=data.uv_layers.new(name='MakeHuman_UV')
    for p,f in zip(data.polygons,fs):
        p.use_smooth=True
        for li,(_,ui) in zip(p.loop_indices,f):layer.data[li].uv=uvs[ui]
    for i,ww in weights.items():
        for name,w in ww.items():
            vg=obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            vg.add([i],w,'REPLACE')
    return obj

# Retain the complete native foot, heel and ankle rather than a truncated tube.
upper_before=[tuple(v.co) for v in body.data.vertices if v.co.z>.60]
bm=bmesh.new();bm.from_mesh(body.data)
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<.60],context='VERTS')
bm.to_mesh(body.data);bm.free()
leg_faces=[f for f,g in zip(faces,groups) if g=='body' and sum(co(verts[i]).z for i,_ in f)/len(f)<.59]
ids=sorted({i for f in leg_faces for i,_ in f});lookup={i:j for j,i in enumerate(ids)}
legs=mesh('Anatomical female legs and full feet',[co(verts[i]) for i in ids], [[(lookup[i],u) for i,u in f] for f in leg_faces],uvs,body.data.materials[0],{lookup[i]:weights[i] for i in ids})
bpy.ops.object.select_all(action='DESELECT');body.hide_set(False);body.select_set(True);legs.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.join()
upper_tree=KDTree(len(body.data.vertices))
for v in body.data.vertices:upper_tree.insert(v.co,v.index)
upper_tree.balance()
upper_error=max(upper_tree.find(Vector(p))[2] for p in upper_before)
assert upper_error<.000001,upper_error

# Re-evaluate the official shoe fitting coordinates against this female body.
# Reusing the old male shoe and squeezing its opening caused the previous defect.
pv,pu,pf,_=read_obj(folder/'shoes04.obj');fitted=[];scales={};active=False
for line in (folder/'shoes04.mhclo').read_text().splitlines():
    t=line.split()
    if not t or t[0].startswith('#'):continue
    if t[0].endswith('_scale'):
        axis={'x':0,'y':1,'z':2}[t[0][0]]
        scales[axis]=abs(verts[int(t[1])][axis]-verts[int(t[2])][axis])/float(t[3])
    elif t[0]=='verts':active=True
    elif active and t[0].lstrip('-').isdigit() and len(fitted)<len(pv):
        if len(t)==1:fitted.append(verts[int(t[0])].copy())
        elif len(t)>=9:
            p=sum((verts[int(t[j])]*float(t[j+3]) for j in range(3)),Vector())
            p+=Vector(tuple(float(t[j+6])*scales.get(j,1.) for j in range(3)))
            fitted.append(p)
assert len(fitted)==len(pv)
shoe_weights=defaultdict(dict)
for name,items in json.loads((folder/'shoes04.mhw').read_text())['weights'].items():
    for i,w in items:shoe_weights[i][name]=w
newshoe=mesh('Shoes | fitted female Oxford without socks',[co(p) for p in fitted],pf,pu,shoe.data.materials[0],shoe_weights)
arm=newshoe.modifiers.new('Humanoid deformation','ARMATURE');arm.object=rig
sub=newshoe.modifiers.new('Smooth leather surface','SUBSURF');sub.levels=1;sub.render_levels=1
bm=bmesh.new();bm.from_mesh(newshoe.data)
remaining=set(bm.verts);islands=[]
while remaining:
    seed=remaining.pop();todo=[seed];vs={seed}
    while todo:
        v=todo.pop()
        for e in v.link_edges:
            n=e.other_vert(v)
            if n in remaining:remaining.remove(n);vs.add(n);todo.append(n)
    islands.append(vs)
islands.sort(key=len,reverse=True)
print('SHOE_COMPONENTS',[(len(vs),min(v.co.z for v in vs),max(v.co.z for v in vs)) for vs in islands],flush=True)
assert len(islands)==4
bmesh.ops.delete(bm,geom=list(islands[2]|islands[3]),context='VERTS')
# Match the sole to the barefoot heel plane. The fitted proxy's heel underside
# remains about 25 mm higher than the female heel, despite correct upper sizing.
# Lower the heel/outsole smoothly; the original ankle anatomy stays untouched.
def smooth(t):
    t=max(0.,min(1.,t));return t*t*(3-2*t)
for v in bm.verts:
    heel=smooth((v.co.y+.10)/.08)
    low=1-smooth((v.co.z-.058)/.042)
    v.co.z-=.028*heel*low
    toe=smooth((-v.co.y-.12)/.07)
    v.co.y-=.006*toe

# Fit the uncut, original leather opening to the restored ankle. There are no
# flat caps across the mouth, and no narrowing of skin to manufacture a fit.
bpy.context.view_layer.update()
skin=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
rim={v for e in bm.edges if e.is_boundary for v in e.verts}
original={v:v.co.copy() for v in bm.verts};moves={}
for v in rim:
    center=Vector((.165 if v.co.x>0 else -.165,-.018,v.co.z))
    direction=Vector((v.co.x-center.x,v.co.y-center.y,0)).normalized()
    hit,normal,_,_=skin.ray_cast(center,direction,.2)
    assert hit is not None,tuple(v.co)
    moves[v]=(hit+direction*.002-v.co)*.92
front=set(rim);depths={v:0 for v in rim}
for depth in range(1,4):
    nxt={e.other_vert(v) for v in front for e in v.link_edges if e.other_vert(v) not in depths}
    for v in nxt:depths[v]=depth
    front=nxt
for v,depth in depths.items():
    if depth==0:delta=moves[v]
    else:
        near=sorted((n for n in rim if n.co.x*v.co.x>0),key=lambda n:(original[v]-original[n]).length_squared)[:4]
        ww=[1/max((original[v]-original[n]).length_squared,1e-8) for n in near]
        delta=sum((moves[n]*w for n,w in zip(near,ww)),Vector())/sum(ww)
        delta*=[1,.60,.20,.025][depth]
    v.co=original[v]+delta
bm.to_mesh(newshoe.data);bm.free()
bpy.data.objects.remove(shoe,do_unlink=True)
# The proxy includes clearance for socks but can intersect the actual bare foot.
# Constrain only penetrating shoe points to the outside of the intact anatomy.
fit=newshoe.modifiers.new('Fit outside complete anatomical feet','SHRINKWRAP')
fit.target=body;fit.wrap_method='NEAREST_SURFACEPOINT';fit.wrap_mode='OUTSIDE';fit.offset=.003
lining=newshoe.modifiers.new('Leather edge thickness','SOLIDIFY');lining.thickness=.0015;lining.offset=-1
newshoe['anatomical_fit']='Official shoe proxy fitted to original female morphology; complete unwarped feet retained; sole and original collar fitted to anatomy.'
rig['ankle_revision']='Complete native female feet and ankles restored; shoes refitted from source proxy, 2026-11-09'
bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get();points=[]
for obj in asset.objects:
    if obj.type!='MESH':continue
    evaluated=obj.evaluated_get(dg);data=evaluated.to_mesh()
    points.extend(evaluated.matrix_world @ v.co for v in data.vertices)
    evaluated.to_mesh_clear()
low=min(p.z for p in points);high=max(p.z for p in points)
factor=1.60/(high-low)
rig.scale*=factor;rig.location.z=rig.location.z*factor-low*factor
bpy.context.view_layer.update()
scene=bpy.context.scene;cam=scene.camera
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
def render(name,location,target,scale,x=1000,y=800):
    cam.location=location;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=x;scene.render.resolution_y=y
    scene.render.filepath=str(ROOT/('ใช้ร่วมกัน/renders/teacher_female_khaki_160cm_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
render('feet_anatomical_side',(2,-.15,.35),(0,-.02,.18),.6)
render('feet_anatomical_back',(.65,1.1,.95),(0,-.01,.13),.65)
render('feet_anatomical_front',(.6,-1.6,1.2),(0,-.04,.15),.7)
render('anatomical_preview',(2,-5.6,1.5),(0,0,.81),1.83,750,1000)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
print('ANATOMICAL_FEET_SAVED',str(OUT),flush=True)
