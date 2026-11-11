"""Centre-parted, forehead-open bob following the user's photo reference."""
import bpy,math,shutil,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path('D:/NetSim3D');OUT=ROOT/'3Dmodel/ใช้ร่วมกัน/blend/students/student_female_bob_cut.blend'
BACK=ROOT/'tmp/student_bob_before_reference_hair_20261109.blend'
if not BACK.exists():shutil.copy2(OUT,BACK)
bpy.ops.wm.open_mainfile(filepath=str(BACK));bpy.context.preferences.filepaths.save_version=0
asset=next(c for c in bpy.data.collections if c.name.startswith('STUDENT |'));rig=next(o for o in asset.all_objects if o.type=='ARMATURE')
protected={o.name:[tuple(v.co) for v in o.data.vertices] for o in asset.all_objects if o.type=='MESH' and not o.name.startswith('Hair |')}
for o in list(asset.all_objects):
    if o.name.startswith('Hair |'):bpy.data.objects.remove(o,do_unlink=True)
mat=bpy.data.materials.new('Bob reference | natural black brown');mat.diffuse_color=(.012,.009,.007,1);mat.use_nodes=True
p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.012,.009,.007,1);p.inputs['Roughness'].default_value=.51;p.inputs['Specular IOR Level'].default_value=.24;p.inputs['Anisotropic'].default_value=.28
N=128;R=40;points=[]
bpy.context.view_layer.update()
body=next(o for o in asset.all_objects if o.name.startswith('Body |'))
scalp=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def position(a,t):
    angle=abs((a+math.pi)%(math.tau)-math.pi)
    # A high central hairline drops progressively down each side of the face;
    # no straight bang strip bridges across the forehead.
    end=1.600-.218*smooth(angle/1.10)
    end+=.003*math.cos(a)*smooth((angle-1.1)/.4)
    centre=1.530;capheight=.100
    maxphi=math.acos(max(-1,min(1,(end-centre)/capheight))) if end>centre else math.pi/2
    caplength=capheight*maxphi;distance=t*(caplength+max(0,centre-end))
    phi=min(maxphi,distance/capheight)
    tail=max(0,distance-caplength)
    z=centre+capheight*math.cos(phi)-tail
    down=tail/max(centre-end,.001)
    inset=1-.11*smooth((down-.65)/.35)
    rx=.089*math.sin(phi)*inset;ry=.112*math.sin(phi)*(1-.065*smooth((down-.65)/.35))
    # Slight off-centre root and gently swept sides, like the reference.
    x=rx*math.sin(a)+.003*(1-t)**2
    y=-.025-ry*math.cos(a)
    z+=.0025*math.exp(-((abs(x-.003)-.015)/.012)**2-((y+.04)/.075)**2)
    # Front roots sit on the actual scalp, not on a floating ellipsoid edge.
    fit=smooth((t-.72)/.28)*smooth((z-1.54)/.035)
    if fit>0 and angle<.65:
        hit,*_=scalp.ray_cast(Vector((x,-.5,z)),Vector((0,1,0)),.8)
        if hit is not None:y=y*(1-fit)+(hit.y-.0015)*fit
    return (x,y,z)
for j in range(R):
    for k in range(N):points.append(position(k*math.tau/N,j/(R-1)))
faces=[(j*N+k,j*N+(k+1)%N,(j+1)*N+(k+1)%N,(j+1)*N+k) for j in range(R-1) for k in range(N)]
data=bpy.data.meshes.new('Photo bob | swept surface');data.from_pydata(points,[],faces);data.update()
hair=bpy.data.objects.new('Hair | centre-parted bob open forehead',data);asset.objects.link(hair);hair.parent=rig;data.materials.append(mat)
for f in data.polygons:f.use_smooth=True
uv=data.uv_layers.new(name='Flowing strand UV')
for f in data.polygons:
    for li in f.loop_indices:
        i=data.loops[li].vertex_index;uv.data[li].uv=(i%N/N,i//N/(R-1))
n=mat.node_tree.nodes;l=mat.node_tree.links
tex=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tex.outputs['UV'],sep.inputs[0])
freq=n.new('ShaderNodeMath');freq.operation='MULTIPLY';freq.inputs[1].default_value=math.tau*230;l.new(sep.outputs[0],freq.inputs[0])
wave=n.new('ShaderNodeMath');wave.operation='SINE';l.new(freq.outputs[0],wave.inputs[0])
bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.15;bump.inputs['Distance'].default_value=.00012;l.new(wave.outputs[0],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
vg=hair.vertex_groups.new(name='head');vg.add(list(range(len(points))),1,'REPLACE')
arm=hair.modifiers.new('Humanoid deformation','ARMATURE');arm.object=rig
sub=hair.modifiers.new('Smooth swept bob','SUBSURF');sub.levels=1;sub.render_levels=1
solid=hair.modifiers.new('Fine hair edge','SOLIDIFY');solid.thickness=.0014;solid.offset=-1
# A restrained scalp part follows the top/front crown rather than a painted
# vertical stripe on the face. The part tapers away behind the crown.
partmat=bpy.data.materials.new('Hair | narrow natural part');partmat.diffuse_color=(.105,.065,.045,1);partmat.use_nodes=True
partmat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.105,.065,.045,1)
curve=bpy.data.curves.new('Natural near-centre part','CURVE');curve.dimensions='3D';curve.bevel_depth=.00075;curve.bevel_resolution=2
spl=curve.splines.new('POLY');spl.points.add(23)
for i in range(24):
    point=Vector(position(0,i/23));point.z+=.0007
    spl.points[i].co=(*point,1)
part=bpy.data.objects.new('Hair | near-centre part',curve);asset.objects.link(part);curve.materials.append(partmat)
bpy.ops.object.select_all(action='DESELECT');part.select_set(True);bpy.context.view_layer.objects.active=part;bpy.ops.object.convert(target='MESH')
part=bpy.context.object;part.parent=rig;vg=part.vertex_groups.new(name='head');vg.add(list(range(len(part.data.vertices))),1,'REPLACE');arm=part.modifiers.new('Head attachment','ARMATURE');arm.object=rig
for name,old in protected.items():assert old==[tuple(v.co) for v in bpy.data.objects[name].data.vertices],name
rig['hairstyle']='Reference bob: near-centre part, open forehead, jaw length, inward tips'
asset.name='STUDENT | female | Centre-parted bob'
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();bounds=[]
for o in asset.all_objects:
    if o.type!='MESH':continue
    evaluated=o.evaluated_get(dg);me=evaluated.to_mesh();bounds.extend(evaluated.matrix_world@v.co for v in me.vertices);evaluated.to_mesh_clear()
low=min(v.z for v in bounds);high=max(v.z for v in bounds);factor=1.6/(high-low)
rig.scale*=factor;rig.location.z=rig.location.z*factor-low*factor
bpy.context.view_layer.update()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=28;scene.cycles.use_denoising=True;scene.render.resolution_percentage=100;cam=scene.camera
folder=ROOT/'3Dmodel/ใช้ร่วมกัน/renders/students'
def render(name,loc,target,scale,w=900,h=1000):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(folder/(name+'.png'));bpy.ops.render.render(write_still=True)
render('bob_reference_front',(0,-3,1.50),(0,-.015,1.45),.43)
render('bob_reference_three_quarter',(1.6,-3,1.52),(0,-.015,1.45),.43)
render('bob_reference_side',(3,-.5,1.50),(0,-.015,1.45),.43)
render('bob_reference_full',(1.8,-6,1.4),(0,0,.81),1.84,850,1100)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tmp/student_bob_reference_candidate.blend'))
print('REFERENCE_BOB_READY',json.dumps({'non_hair_meshes_unchanged':len(protected),'bones':len(rig.data.bones)}),flush=True)
