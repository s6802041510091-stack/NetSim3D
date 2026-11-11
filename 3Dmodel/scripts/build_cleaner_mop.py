"""Author a metre-scale reusable cotton mop, plus cleaner scale previews."""
import bpy,math,random,json
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/NetSim3D/3Dmodel');random.seed(31)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'ใช้ร่วมกัน/blend/cleaner_female_apron_160cm.blend'))
bpy.context.preferences.filepaths.save_version=0
collection=bpy.data.collections.new('PROP | cleaner cotton mop');bpy.context.scene.collection.children.link(collection)
root=bpy.data.objects.new('Cleaner_Mop',None);collection.objects.link(root)
def material(name,color,rough=.5,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
steel=material('Mop | brushed aluminium',(.48,.54,.57),.32,.8)
sage=material('Mop | sage green plastic',(.08,.24,.21),.48)
rubber=material('Mop | dark grip rings',(.035,.065,.057),.8)
cotton=[material('Mop | cotton '+str(i),c,.94) for i,c in enumerate([(.63,.60,.49),(.76,.73,.62),(.54,.54,.45),(.69,.68,.57)])]
def finish(o,mat):
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o);o.parent=root;o.data.materials.append(mat)
    for f in o.data.polygons:f.use_smooth=True
    return o
def cylinder(name,radius,depth,z,mat,vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(0,0,z));o=bpy.context.object;o.name=name
    finish(o,mat);bevel=o.modifiers.new('Soft manufactured edges','BEVEL');bevel.width=.0012;bevel.segments=2
    return o
def tube(name,points,radius,mat,sides=5):
    vs=[];faces=[]
    for i,p in enumerate(points):
        p=Vector(p);direction=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])).normalized()
        axis=direction.cross(Vector((0,0,1)))
        if axis.length<.01:axis=direction.cross(Vector((0,1,0)))
        axis.normalize();other=direction.cross(axis).normalized()
        for k in range(sides):vs.append(p+radius*(axis*math.cos(k*math.tau/sides)+other*math.sin(k*math.tau/sides)))
    for i in range(len(points)-1):
        for k in range(sides):faces.append((i*sides+k,i*sides+(k+1)%sides,(i+1)*sides+(k+1)%sides,(i+1)*sides+k))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+k for k in range(sides))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);collection.objects.link(o);o.parent=root;mesh.materials.append(mat)
    for f in mesh.polygons:f.use_smooth=True
    return o
# Floor at Z=0, socket at 16 cm; pole and textured grip reach 1.42 m.
cylinder('Mop_Pole',.011,1.15,.745,steel)
cylinder('Mop_Upper_Grip',.015,.18,1.32,sage)
cylinder('Mop_Handle_Cap',.017,.025,1.415,sage)
for i in range(9):cylinder('Mop_Grip_Ring_%02d'%i,.0158,.003,1.246+i*.017,rubber)
# A real hanging loop with an open centre.
tube('Mop_Hanging_Loop',[(.018*math.cos(k*math.tau/24),0,1.442+.024*math.sin(k*math.tau/24)) for k in range(25)],.0035,sage,6)
cylinder('Mop_Head_Socket',.026,.085,.165,sage)
cylinder('Mop_Socket_Collar',.031,.017,.129,rubber)
cylinder('Mop_Cotton_Binding',.038,.035,.106,cotton[2])
for i in range(56):
    angle=i*2.39996323;reach=random.uniform(.065,.135);start_r=random.uniform(.006,.029)
    points=[]
    for j in range(9):
        t=j/8;rad=start_r+(reach-start_r)*(t**.75)
        a=angle+.10*math.sin(t*math.pi*2+i)
        z=.105*(1-t)**2+.0045+.004*math.sin(t*math.pi)
        points.append((rad*math.cos(a),rad*math.sin(a),z))
    tube('Mop_Cotton_Strand_%02d'%i,points,random.uniform(.003,.0044),cotton[i%4])
root['height_m']=1.47;root['role']='Reusable cleaner cotton mop';root['floor_axis']='Z up, cotton rests at Z=0';root['grip_diameter_m']=.03
root['hand_grip_z_m']=.85
scene=bpy.context.scene;cam=scene.camera;scene.render.engine='CYCLES';scene.cycles.samples=28;scene.cycles.use_denoising=True;scene.render.resolution_percentage=100
renders=ROOT/'ใช้ร่วมกัน/renders/cleaner';renders.mkdir(parents=True,exist_ok=True)
def render(name,loc,target,scale,w=900,h=1100):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(renders/(name+'.png'));bpy.ops.render.render(write_still=True)
root.location=(.48,-.12,0)
render('cleaner_mop_scale',(2,-6,1.75),(.17,0,.8),1.95,1000,1100)
for o in list(bpy.data.collections['CLEANER | female | 160 cm'].all_objects):bpy.data.objects.remove(o,do_unlink=True)
root.location=(0,0,0)
render('cleaner_mop',(1.5,-4,1.6),(0,0,.73),1.65)
render('cleaner_mop_head',(.6,-.85,.63),(0,0,.09),.43,1000,800)
render_path=scene.render.filepath
cam.location=(1.5,-4,1.6);cam.rotation_euler=(Vector((0,0,.73))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.65
bpy.ops.object.select_all(action='DESELECT')
for o in collection.objects:o.select_set(True)
bpy.context.view_layer.objects.active=root
export=ROOT/'ใช้ร่วมกัน/exports/cleaner_mop.glb'
bpy.ops.export_scene.gltf(filepath=str(export),export_format='GLB',use_selection=True,export_apply=True)
out=ROOT/'ใช้ร่วมกัน/blend/cleaner_mop.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out))
print('MOP_CREATED',json.dumps({'blend':str(out),'glb':str(export),'mesh_objects':sum(o.type=='MESH' for o in collection.objects),'triangles_approx':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in collection.objects if o.type=='MESH')}),flush=True)
