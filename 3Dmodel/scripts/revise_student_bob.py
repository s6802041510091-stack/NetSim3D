"""Distinct student face, chin-length bob and anatomically fitted school socks."""
import bpy,bmesh,math,shutil,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path('D:/NetSim3D');OUT=ROOT/'3Dmodel/ใช้ร่วมกัน/blend/students/student_female_bob_cut.blend'
BACK=ROOT/'tmp/student_bob_before_revision_20261109.blend'
if not BACK.exists():shutil.copy2(OUT,BACK)
bpy.ops.wm.open_mainfile(filepath=str(BACK));bpy.context.preferences.filepaths.save_version=0
asset=next(c for c in bpy.data.collections if c.name.startswith('STUDENT |'))
rig=next(o for o in asset.all_objects if o.type=='ARMATURE');body=next(o for o in asset.all_objects if o.name.startswith('Body |'))
others={o.name:[tuple(v.co) for v in o.data.vertices] for o in asset.all_objects if o.type=='MESH' and not o.name.startswith(('Hair |','Shoes |','Body |','Eyes |','Eyebrows |'))}
def g(x,c,w):return math.exp(-((x-c)/w)**2)
# A softer round/heart-shaped face, shorter nose, fuller cheeks and smaller chin.
for v in body.data.vertices:
    x,y,z=v.co
    if z<1.39:continue
    front=max(0,min(1,(-y-.055)/.045))
    v.co.x*=1+.065*g(z,1.455,.026)*front-.10*g(z,1.408,.018)*front
    v.co.y+=.0035*g(z,1.465,.015)*g(x,0,.019)*front
    v.co.x*=1-.13*g(x,0,.020)*g(z,1.465,.018)*front
    v.co.x*=1-.13*g(z,1.438,.008)*g(x,0,.030)*front
    v.co.y-=.0022*g(abs(x),.043,.022)*g(z,1.462,.022)*front
    v.co.z+=.003*g(z,1.405,.018)*front
    # More widely spaced eyes, with the lids and brows following the eyeballs.
    v.co.x+=(1 if x>0 else -1)*.0022*g(abs(x),.030,.021)*g(z,1.502,.018)*front
for o in asset.all_objects:
    if o.type=='MESH' and o.name.startswith(('Eyes |','Eyebrows |')):
        for v in o.data.vertices:v.co.x+=(1 if v.co.x>0 else -1)*.0022
for o in list(asset.all_objects):
    if o.name.startswith('Hair |'):bpy.data.objects.remove(o,do_unlink=True)
def mat(name,c,rough=.6):
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough
    return m
hairmat=mat('Student Bob | dark chestnut hair',(.018,.010,.007),.64)
hairmat.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.22
noise=hairmat.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=180;noise.inputs['Detail'].default_value=2
bump=hairmat.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.0002
hairmat.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);hairmat.node_tree.links.new(bump.outputs['Normal'],hairmat.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
def mesh(name,points,faces,material,bone=None):
    data=bpy.data.meshes.new(name);data.from_pydata(points,[],faces);data.update();o=bpy.data.objects.new(name,data);asset.objects.link(o);o.parent=rig;data.materials.append(material)
    for f in data.polygons:f.use_smooth=True
    if bone:
        vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(points))),1,'REPLACE')
    arm=o.modifiers.new('Humanoid deformation','ARMATURE');arm.object=rig
    return o
def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
# Closed crown and a continuous bob silhouette. Front fringe ends above eyebrows;
# temple, side and back lengths end at the jaw, with gently turned-in tips.
N=96;rows=26;points=[]
for j in range(rows):
    t=j/(rows-1)
    for k in range(N):
        a=2*math.pi*k/N;angle=abs((a+math.pi)%(2*math.pi)-math.pi)
        if t<.55:
            phi=(t/.55)*1.50;rx=.094*math.sin(phi);ry=.118*math.sin(phi);z=1.528+.103*math.cos(phi)
        else:
            u=(t-.55)/.45;length=smooth((angle-.36)/.72)
            end=1.534-(.140*length)+.0018*math.cos(a*3)
            z=(1.528+.103*math.cos(1.50))*(1-u)+end*u
            rx=.094*math.sin(1.50)*(1+.025*math.sin(u*math.pi)-.09*u**4)
            ry=.118*math.sin(1.50)*(1-.05*u**4)
        ripple=1+.002*math.sin(a*48+t*1.2)
        points.append((rx*math.sin(a)*ripple,-.025-ry*math.cos(a)*ripple,z))
faces=[(j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k) for j in range(rows-1) for k in range(N)]
hair=mesh('Hair | chin-length bob with soft fringe',points,faces,hairmat,'head')
uv=hair.data.uv_layers.new(name='Bob strands')
for f in hair.data.polygons:
    for li in f.loop_indices:
        idx=hair.data.loops[li].vertex_index;uv.data[li].uv=(idx%N/N,idx//N/(rows-1))
tex=hairmat.node_tree.nodes.new('ShaderNodeTexCoord');separate=hairmat.node_tree.nodes.new('ShaderNodeSeparateXYZ');hairmat.node_tree.links.new(tex.outputs['UV'],separate.inputs[0])
freq=hairmat.node_tree.nodes.new('ShaderNodeMath');freq.operation='MULTIPLY';freq.inputs[1].default_value=math.tau*180
wave=hairmat.node_tree.nodes.new('ShaderNodeMath');wave.operation='SINE';hairmat.node_tree.links.new(separate.outputs['X'],freq.inputs[0]);hairmat.node_tree.links.new(freq.outputs[0],wave.inputs[0]);hairmat.node_tree.links.new(wave.outputs[0],bump.inputs['Height'])
sub=hair.modifiers.new('Smooth bob silhouette','SUBSURF');sub.levels=1;sub.render_levels=1
solid=hair.modifiers.new('Hair edge thickness','SOLIDIFY');solid.thickness=.002;solid.offset=-1

shoe=next(o for o in asset.all_objects if o.name.startswith('Shoes |'))
bm=bmesh.new();bm.from_mesh(shoe.data);remaining=set(bm.verts);islands=[]
while remaining:
    seed=remaining.pop();stack=[seed];vs={seed}
    while stack:
        v=stack.pop()
        for e in v.link_edges:
            n=e.other_vert(v)
            if n in remaining:remaining.remove(n);vs.add(n);stack.append(n)
    islands.append(vs)
islands.sort(key=len,reverse=True)
print('SHOE_ISLANDS',[(len(vs),min(v.co.z for v in vs),max(v.co.z for v in vs)) for vs in islands],flush=True)
bmesh.ops.delete(bm,geom=[v for vs in islands[2:] for v in vs],context='VERTS')
# Remove the old white material assignment from the leather islands.
for f in bm.faces:f.material_index=0
bm.to_mesh(shoe.data);bm.free()
bpy.context.view_layer.update();skin=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
white=mat('School socks | warm white knit',(.75,.75,.71),.92)
sockpoints=[];sockfaces=[];centers={}
for side,sign in [('L',1),('R',-1)]:
    # Measure this actual student's ankle, preserving her slimmer leg revision.
    pts=[v.co for v in body.data.vertices if v.co.x*sign>0 and .16<v.co.z<.19]
    cx=(min(p.x for p in pts)+max(p.x for p in pts))/2;cy=(min(p.y for p in pts)+max(p.y for p in pts))/2
    centers[side]=(cx,cy)
    def radius_at(a,z):
        sample=max(z,.153);d=Vector((math.cos(a),math.sin(a),0));hit,*_=skin.ray_cast(Vector((cx,cy,sample)),d,.12)
        assert hit is not None,('Ankle missing',side,z)
        return (hit-Vector((cx,cy,sample))).length+.0025
    points=[]
    zs=[.080,.095,.12,.145,.168,.177,.179]
    for z in zs:
        for k in range(48):
            a=k*math.tau/48;rib=1+.014*math.cos(k*math.tau/48*24)
            radius=radius_at(a,z)*rib*(1+.025*smooth((z-.168)/.01))
            points.append((cx+radius*math.cos(a),cy+radius*math.sin(a),z))
    faces=[(j*48+k,j*48+(k+1)%48,(j+1)*48+(k+1)%48,(j+1)*48+k) for j in range(len(zs)-1) for k in range(48)]
    sock=mesh('Socks | fitted ankle '+side,points,faces,white,'foot.'+side)
    solid=sock.modifiers.new('Knitted thickness','SOLIDIFY');solid.thickness=.0012;solid.offset=-1
    sub=sock.modifiers.new('Soft knit','SUBSURF');sub.levels=1;sub.render_levels=1
    # Centre the original shoe beneath the ankle instead of keeping the wider
    # teacher shoe's lateral offset. The leather silhouette is preserved.
    bm=bmesh.new();bm.from_mesh(shoe.data)
    vs=[v for v in bm.verts if v.co.x*sign>0];rim=[v for v in vs if any(e.is_boundary for e in v.link_edges)]
    oldcx=(min(v.co.x for v in rim)+max(v.co.x for v in rim))/2
    oldcy=(min(v.co.y for v in rim)+max(v.co.y for v in rim))/2
    for v in vs:v.co.x+=cx-oldcx;v.co.y+=cy-oldcy
    # Fit the original leather edge around the sock, without capping the opening.
    original={v:v.co.copy() for v in vs};moves={}
    for v in rim:
        d=Vector((v.co.x-cx,v.co.y-cy,0));a=math.atan2(d.y,d.x);d.normalize()
        target=Vector((cx,cy,v.co.z))+d*(radius_at(a,v.co.z)+.0015)
        moves[v]=target-v.co
    depths={v:0 for v in rim};front=set(rim)
    for depth in range(1,4):
        nxt={e.other_vert(v) for v in front for e in v.link_edges if e.other_vert(v) not in depths}
        for v in nxt:depths[v]=depth
        front=nxt
    for v,depth in depths.items():
        if depth==0:delta=moves[v]
        else:
            near=sorted(rim,key=lambda n:(original[v]-original[n]).length_squared)[:4];ww=[1/max((original[v]-original[n]).length_squared,1e-8) for n in near]
            delta=sum((moves[n]*w for n,w in zip(near,ww)),Vector())/sum(ww)*[1,.6,.2,.02][depth]
        v.co=original[v]+delta
    bm.to_mesh(shoe.data);bm.free()
for name,old in others.items():assert old==[tuple(v.co) for v in bpy.data.objects[name].data.vertices],name
rig['hairstyle']='Chin-length bob with soft fringe';rig['face_revision']='Distinct round/heart-shaped face, wider eye spacing, shorter nose, softer cheeks; 2026-11-09'
rig['foot_revision']='Original flared sock islands replaced by cuffs measured on the actual ankle; shoes centred below each leg.'
asset.name='STUDENT | female | Chin-length bob'
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();pts=[]
for o in asset.all_objects:
    if o.type=='MESH':
        e=o.evaluated_get(dg);m=e.to_mesh();pts.extend(e.matrix_world@v.co for v in m.vertices);e.to_mesh_clear()
low=min(p.z for p in pts);high=max(p.z for p in pts);factor=1.6/(high-low);rig.scale*=factor;rig.location.z=rig.location.z*factor-low*factor
bpy.context.view_layer.update()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=28;scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
cam=scene.camera;renderdir=ROOT/'3Dmodel/ใช้ร่วมกัน/renders/students'
def render(name,loc,target,scale,w=900,h=1000):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(renderdir/(name+'.png'));bpy.ops.render.render(write_still=True)
render('bob_revised_face',(.3,-3,1.53),(0,-.015,1.45),.43)
render('bob_revised_side',(3,-.5,1.50),(0,-.01,1.45),.43)
render('bob_revised_feet',(.7,-1.5,.8),(0,-.04,.15),.65,1000,800)
render('bob_revised_feet_back',(.7,1.5,.65),(0,-.02,.15),.65,1000,800)
render('bob_revised_full',(1.8,-6,1.4),(0,0,.81),1.84,850,1100)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tmp/student_bob_revised_candidate.blend'))
print('BOB_REVISED',json.dumps({'height_m':1.60,'ankle_centers':centers,'other_clothes_preserved':True,'bones':len(rig.data.bones)}),flush=True)
