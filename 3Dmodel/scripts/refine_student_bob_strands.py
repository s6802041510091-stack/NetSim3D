"""Layered, strand-defined bob; preserve the approved face, clothes and feet."""
import math, random, shutil, json
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path('D:/NetSim3D')
OUT=ROOT/'3Dmodel/ใช้ร่วมกัน/blend/students/student_female_bob_cut.blend'
BACK=Path(globals().get('SOURCE_SNAPSHOT',ROOT/'tmp/student_bob_before_strand_refinement_20261109.blend'))
FRONT_LENGTH_FACTOR=float(globals().get('FRONT_LENGTH_FACTOR',1.0))
PREVIEW_PREFIX=globals().get('PREVIEW_PREFIX','bob_strands')
CANDIDATE_NAME=globals().get('CANDIDATE_NAME','student_bob_strands_candidate.blend')
if not BACK.exists(): shutil.copy2(OUT,BACK)
bpy.ops.wm.open_mainfile(filepath=str(BACK))
bpy.context.preferences.filepaths.save_version=0
asset=next(c for c in bpy.data.collections if c.name.startswith('STUDENT |'))
rig=next(o for o in asset.all_objects if o.type=='ARMATURE')
protected={o.name:[tuple(v.co) for v in o.data.vertices] for o in asset.all_objects if o.type=='MESH' and not o.name.startswith('Hair |')}
for ob in list(asset.all_objects):
    if ob.name.startswith('Hair |'): bpy.data.objects.remove(ob,do_unlink=True)
bpy.context.view_layer.update()
body=next(o for o in asset.all_objects if o.name.startswith('Body |'))
scalp=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
front_tip_z=None
if globals().get('BROW_CLEARANCE_METERS') is not None:
    brows=next(o for o in asset.all_objects if o.name.startswith('Eyebrows |'))
    to_rig=rig.matrix_world.inverted()@brows.matrix_world
    brow_top=max((to_rig@v.co).z for v in brows.data.vertices)
    front_tip_z=brow_top+float(BROW_CLEARANCE_METERS)/rig.scale.z-.002
    print('FRONT_TIP_TARGET',brow_top,front_tip_z,flush=True)
def smooth(t):
    t=max(0,min(1,t))
    return t*t*(3-2*t)
rng=random.Random(91126)

def material(name,col,rough=.58):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*col,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Specular IOR Level'].default_value=.055
    p.inputs['Anisotropic'].default_value=.35
    p.inputs['Anisotropic Rotation'].default_value=.25
    return m

base=material('Hair | irregular fine strands, soft dark brown',(.008,.005,.003))
n=base.node_tree.nodes;l=base.node_tree.links;p=n.get('Principled BSDF')
uv=n.new('ShaderNodeTexCoord');scale=n.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(850,4,1);l.new(uv.outputs['UV'],scale.inputs[0])
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1;noise.inputs['Detail'].default_value=2.2;noise.inputs['Roughness'].default_value=.7;l.new(scale.outputs[0],noise.inputs['Vector'])
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=(.002,.0013,.0009,1);ramp.color_ramp.elements[1].position=.79;ramp.color_ramp.elements[1].color=(.024,.013,.007,1);l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.000025;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
# Let the dense underlayer fade into individual fibres at every cut edge.
# This removes the solid, scalloped rim without holes higher on the scalp.
sep=n.new('ShaderNodeSeparateXYZ');l.new(uv.outputs['UV'],sep.inputs[0])
cut=n.new('ShaderNodeMath');cut.operation='MULTIPLY_ADD';cut.inputs[1].default_value=.045;cut.inputs[2].default_value=.947;l.new(noise.outputs['Fac'],cut.inputs[0])
delta=n.new('ShaderNodeMath');delta.operation='SUBTRACT';l.new(cut.outputs[0],delta.inputs[0]);l.new(sep.outputs['Y'],delta.inputs[1])
alpha=n.new('ShaderNodeMath');alpha.operation='MULTIPLY';alpha.inputs[1].default_value=420;alpha.use_clamp=True;l.new(delta.outputs[0],alpha.inputs[0]);l.new(alpha.outputs[0],p.inputs['Alpha'])
strandmats=[material('Hair | filament tone %02d'%i,(.003+i*.002,.002+i*.0012,.0015+i*.0007),.48+i*.015) for i in range(8)]

def position(a,t):
    angle=abs((a+math.pi)%math.tau-math.pi)
    end=1.600-.218*smooth(angle/1.10)+.003*math.cos(a)*smooth((angle-1.1)/.4)
    # Extend central front locks while blending into the original temple contour.
    end-=.030*(FRONT_LENGTH_FACTOR-1.0)*(1-smooth(angle/.60))
    if front_tip_z is not None:
        blend=1-smooth((angle-.50)/.50)
        end=end*(1-blend)+front_tip_z*blend
    center=1.530;h=.100
    maxphi=math.acos(max(-1,min(1,(end-center)/h))) if end>center else math.pi/2
    caplength=h*maxphi;distance=t*(caplength+max(0,center-end))
    f=min(1,distance/caplength);tail=max(0,distance-caplength)
    # Roots emerge along a sagittal part, not a single radial pole.
    root=Vector((0,-.55*math.cos(a),math.sqrt(1-(.55*math.cos(a))**2)))
    edge=Vector((math.sin(maxphi)*math.sin(a),-math.sin(maxphi)*math.cos(a),math.cos(maxphi)))
    unit=(root*(1-f)+edge*f).normalized()
    down=tail/max(center-end,.001);inset=1-.11*smooth((down-.65)/.35)
    x=.089*unit.x*inset+.003*(1-t)**2
    x+=(.0004 if math.sin(a)>=0 else -.0004)*(1-f)**3
    y=-.025+.112*unit.y*(1-.065*smooth((down-.65)/.35));z=center+h*unit.z-tail
    fit=smooth((t-.72)/.28)*smooth((z-1.54)/.035)
    if fit>0 and angle<.65:
        hit,*_=scalp.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)),.8)
        if hit is not None:y=y*(1-fit)+(hit.y-.0015)*fit
    return x,y,z

def normal(a,t):
    q=Vector(position(a,t));da=Vector(position(a+.0005,t))-Vector(position(a-.0005,t));dt=Vector(position(a,min(.9999,t+.0005)))-Vector(position(a,max(.0001,t-.0005)))
    nor=da.cross(dt).normalized()
    if nor.dot(Vector((q.x,q.y+.025,max(0,q.z-1.53))))<0:nor=-nor
    return nor

def flow(a,t):
    # Irregular, shallow overlapping locks; taper variation is local to the tips.
    sweep=.025*math.sin(a*5+.8)*math.sin(math.pi*t)
    aa=a+sweep
    endtrim=(.003+.0025*math.sin(a*31+.6)+.0015*math.sin(a*67+1.9))*smooth((t-.88)/.12)
    q=Vector(position(aa,t));q.z+=endtrim
    relief=(.00012*math.sin(a*39+1.4*t)+.00006*math.sin(a*83-.6*t))*math.sin(math.pi*t*.94)**2
    return q+normal(aa,max(.01,t))*relief

def mesh(name,verts,faces,mats,uvs=None,indices=None):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
    o=bpy.data.objects.new(name,d);asset.objects.link(o);o.parent=rig
    for m in mats:d.materials.append(m)
    for i,f in enumerate(d.polygons):
        f.use_smooth=True
        if indices:f.material_index=indices[i]
    if uvs:
        layer=d.uv_layers.new(name='Strand flow')
        for f in d.polygons:
            for li in f.loop_indices:layer.data[li].uv=uvs[d.loops[li].vertex_index]
    group=o.vertex_groups.new(name='head');group.add(list(range(len(verts))),1,'REPLACE')
    mod=o.modifiers.new('Follow head bone','ARMATURE');mod.object=rig
    return o

N=384;R=56;vs=[];uvs=[];fs=[]
for j in range(R):
    t=.001+j/(R-1)*.999
    for k in range(N+1):
        a=k*math.tau/N;vs.append(tuple(flow(a,t)));uvs.append((k/N,t))
for j in range(R-1):
    for k in range(N):
        i=j*(N+1)+k;fs.append((i+N+1,i+N+2,i+1,i))
hair=mesh('Hair | softly layered bob foundation',vs,fs,[base],uvs)
solid=hair.modifiers.new('Thin inward edge','SOLIDIFY');solid.thickness=.0006;solid.offset=-1

# Fine 3D ribbons catch individual highlights, with independently tapered tips.
# They follow the same head-attached shell so they do not drift during posing.
vs=[];fs=[];mi=[]
for i in range(3300):
    a=(i+rng.random())*math.tau/3300
    start=rng.uniform(.001,.035);finish=rng.uniform(.975,1.018)
    width=rng.uniform(.000045,.00010)
    lift=rng.uniform(.00015,.0009)
    phase=rng.uniform(0,math.tau);tone=rng.randrange(len(strandmats))
    segs=28;off=len(vs)
    for j in range(segs):
        f=j/(segs-1);t=start+(finish-start)*f
        aa=a+.010*math.sin(math.pi*f)*math.sin(phase+f*2)
        q=flow(aa,min(t,1));nor=normal(aa,min(.995,max(.01,t)))
        q+=nor*(lift*math.sin(math.pi*f*.96))
        if t>1:q.z-=(t-1)*.25
        tangent=(flow(aa+.0005,min(t,1))-flow(aa-.0005,min(t,1))).normalized()
        taper=min(1,f/.07)*max(.015,min(1,(1-f)/.17))
        vs.extend([tuple(q-tangent*width*taper),tuple(q+tangent*width*taper)])
        if j<segs-1:
            h=off+j*2;fs.append((h,h+1,h+3,h+2));mi.append(tone)
mesh('Hair | 3300 tapered surface filaments',vs,fs,strandmats,indices=mi)

# Separate wisps soften the silhouette and the cut edge without adding a halo.
vs=[];fs=[];mi=[]
for i in range(160):
    a=rng.uniform(0,math.tau);start=rng.uniform(.12,.65);end=rng.uniform(.99,1.045)
    lift=rng.uniform(.0008,.0048);radius=rng.uniform(.000055,.00010);off=len(vs);segs=30
    for j in range(segs):
        f=j/(segs-1);t=start+(end-start)*f;q=flow(a,min(1,t));nor=normal(a,min(.995,t));q+=nor*lift*math.sin(math.pi*f)
        if t>1:q.z-=(t-1)*.25
        side=Vector((math.cos(a),math.sin(a),0));r=radius*max(.015,math.sin(math.pi*f)**.4)
        for s in range(3):vs.append(tuple(q+(side*math.cos(s*math.tau/3)+nor*math.sin(s*math.tau/3))*r))
        if j<segs-1:
            h=off+j*3
            for s in range(3):fs.append((h+s,h+(s+1)%3,h+3+(s+1)%3,h+3+s));mi.append(2)
mesh('Hair | fine flyaways and feathered ends',vs,fs,strandmats,indices=mi)

for name,old in protected.items():assert old==[tuple(v.co) for v in bpy.data.objects[name].data.vertices],name
rig['hairstyle']='Centre-part bob, irregular strand texture, 3300 fine filaments, feathered tips'
bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get();bounds=[]
for ob in asset.all_objects:
    if ob.type!='MESH':continue
    ev=ob.evaluated_get(dg);me=ev.to_mesh();bounds.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
low=min(v.z for v in bounds);high=max(v.z for v in bounds);factor=1.6/(high-low)
rig.scale*=factor;rig.location.z=rig.location.z*factor-low*factor
bpy.context.view_layer.update()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100;cam=scene.camera
folder=ROOT/'3Dmodel/ใช้ร่วมกัน/renders/students'
def render(name,loc,target,scale,w=900,h=1000):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(folder/(name+'.png'));bpy.ops.render.render(write_still=True)
render(PREVIEW_PREFIX+'_three_quarter',(1.6,-3,1.52),(0,-.015,1.45),.43)
render(PREVIEW_PREFIX+'_front',(0,-3,1.50),(0,-.015,1.45),.43)
render(PREVIEW_PREFIX+'_side',(3,-.5,1.50),(0,-.015,1.45),.43)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tmp'/CANDIDATE_NAME))
print('STRAND_BOB_READY',json.dumps({'non_hair_meshes_unchanged':len(protected),'bones':len(rig.data.bones)}),flush=True)
