"""ARCHIVED ATTEMPT: superseded by rebuild_teacher_female_feet.py.

Fit the existing female teacher's leather shoe openings to her ankle surface.

Run after repair_teacher_female_limbs.py. The dated input backup makes this
refinement repeatable without changing the approved arms or body anatomy.
"""
import bpy
import bmesh
import shutil
import json
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path('D:/NetSim3D/3Dmodel')
OUTPUT=ROOT/'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm.blend'
BACKUP=ROOT/'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm_before_collar_fit_20261109.blend'
if not BACKUP.exists():
    raise SystemExit('Retired collar experiment: its input snapshot was removed after approval. Use the approved teacher_female_khaki_160cm.blend.')
bpy.ops.wm.open_mainfile(filepath=str(BACKUP))
bpy.context.preferences.filepaths.save_version=0
body=bpy.data.objects['Body | female head arms lower legs']
shoe=bpy.data.objects['Shoes | black Oxford with socks']
rig=bpy.data.objects['Teacher_Female_Rig']
original_body=[tuple(v.co) for v in body.data.vertices]
dg=bpy.context.evaluated_depsgraph_get()
skin=BVHTree.FromObject(body,dg)
mats={b.name:b.matrix @ b.bone.matrix_local.inverted() for b in rig.pose.bones}

bm=bmesh.new();bm.from_mesh(shoe.data)
deform=bm.verts.layers.deform.active
def transform(v):
    out=Matrix(((0.,)*4,)*4);total=0.
    for index,w in v[deform].items():
        name=shoe.vertex_groups[index].name
        if name in mats:out+=mats[name]*w;total+=w
    return out*(1/total) if total>1e-8 else Matrix.Identity(4)
remaining=set(bm.verts);socks=[]
while remaining:
    seed=remaining.pop();todo=[seed];island={seed}
    while todo:
        v=todo.pop()
        for e in v.link_edges:
            n=e.other_vert(v)
            if n in remaining:remaining.remove(n);island.add(n);todo.append(n)
    # Original socks are disconnected, short open tubes, unlike the complete
    # leather shoe islands (which include the sole at Z=0.023).
    if min(v.co.z for v in island)>.06 and len(island)<150:socks.extend(island)
assert len(socks)==152, ('Unexpected shoe topology',len(socks))
bmesh.ops.delete(bm,geom=socks,context='VERTS')

lining=bpy.data.materials.new('Shoes | fitted dark leather collar lining')
lining.diffuse_color=(.014,.017,.019,1);lining.use_nodes=True
bsdf=lining.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value=(.014,.017,.019,1)
bsdf.inputs['Roughness'].default_value=.65
shoe.data.materials.append(lining);lining_index=len(shoe.data.materials)-1

# Close small front/heel cuts left by the previous horizontal sock removal.
boundary={e for e in bm.edges if e.is_boundary};opening=[];caps=0
while boundary:
    seed=boundary.pop();edges={seed};todo=list(seed.verts);vs=set(seed.verts)
    while todo:
        v=todo.pop()
        for e in v.link_edges:
            if e in boundary:
                boundary.remove(e);edges.add(e);n=e.other_vert(v);vs.add(n);todo.append(n)
    if all(abs(v.co.z-.113)<1e-5 for v in vs):
        result=bmesh.ops.holes_fill(bm,edges=list(edges),sides=0)
        for face in result['faces']:face.material_index=lining_index;face.smooth=True
        caps+=1
    else: opening.append((edges,vs))
assert len(opening)==2 and caps==4,(len(opening),caps)

def ankle_target(p,clearance=.0012):
    center=Vector((.165 if p.x>0 else -.165,-.018,p.z))
    direction=Vector((p.x-center.x,p.y-center.y,0)).normalized()
    hit,normal,_,_=skin.ray_cast(center,direction,.15)
    assert hit is not None, ('Missing ankle section',tuple(p))
    return hit+direction*clearance

# Boundary displacements are propagated only a few mesh rows into the upper;
# the toe silhouette, sole and heel bottom remain unchanged.
sole_before=[tuple(v.co) for v in bm.verts if v.co.z<.055]
posed={v:transform(v) @ v.co for v in bm.verts}
displacements={}
for edges,vs in opening:
    for v in vs:displacements[v]=ankle_target(posed[v])-posed[v]
all_boundary=set(displacements)
front=set(displacements)
distances={v:0 for v in front}
for depth in range(1,5):
    next_front=set()
    for v in front:
        for e in v.link_edges:
            n=e.other_vert(v)
            if n not in distances and n.co.z>.06:next_front.add(n)
    for v in next_front:distances[v]=depth
    front=next_front
falloffs=[1.,.78,.42,.16,.035]
for v,depth in distances.items():
    if depth==0:delta=displacements[v]
    else:
        candidates=sorted(((posed[v]-posed[n]).length_squared,n) for n in all_boundary if posed[n].x*posed[v].x>0)
        weights=[1/max(d,1e-8) for d,n in candidates[:4]]
        delta=sum((displacements[n]*w for (_,n),w in zip(candidates[:4],weights)),Vector())/sum(weights)
        delta*=falloffs[depth]
    v.co=transform(v).inverted() @ (posed[v]+delta)

# Add a narrow inward leather lip: the outer opening is close to the ankle,
# and its inner edge sits just beneath the skin so no hollow slit is visible.
for edges,vs in opening:
    inner={}
    for v in vs:
        p=transform(v) @ v.co
        target=ankle_target(p,-.0010);target.z-=.002
        n=bm.verts.new(transform(v).inverted() @ target)
        for index,w in v[deform].items():n[deform][index]=w
        inner[v]=n
    for e in edges:
        a,b=e.verts
        face=bm.faces.new((a,b,inner[b],inner[a]))
        face.material_index=lining_index;face.smooth=True
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
sole_after=[tuple(v.co) for v in bm.verts if v.co.z<.055]
assert sole_after==sole_before
bm.to_mesh(shoe.data);bm.free();shoe.data.update()
assert original_body==[tuple(v.co) for v in body.data.vertices]
shoe['collar_revision']='Removed both sock islands, fitted leather collars to ankle skin, added inward lining lip; 2026-11-09'
bpy.context.view_layer.update()

scene=bpy.context.scene;cam=scene.camera
saved_camera=(cam.location.copy(),cam.rotation_euler.copy(),cam.data.ortho_scale)
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
def render(name,loc,target,scale,x=1000,y=800):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=x;scene.render.resolution_y=y
    scene.render.filepath=str(ROOT/('ใช้ร่วมกัน/renders/teacher_female_khaki_160cm_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
render('ankles_top_fitted',(.6,-1.6,1.45),(0,-.04,.12),.67)
render('ankles_back_fitted',(.65,1.1,1.0),(0,-.01,.11),.65)
render('ankles_repaired',(1,-3,.55),(0,-.02,.17),.65)
render('preview',(2,-5.6,1.5),(0,0,.81),1.83,750,1000)
cam.location,cam.rotation_euler,cam.data.ortho_scale=saved_camera
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
print('SHOE_COLLAR_FIT',json.dumps({'sock_vertices_removed':len(socks),'fitted_openings':len(opening),'cut_caps_closed':caps,'body_unchanged':True,'sole_unchanged':True}),flush=True)
