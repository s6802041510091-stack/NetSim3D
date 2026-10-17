"""Standalone adult cleaner with an authored bib apron; never overwrite inputs.

Reuses the established CC0-derived adult female anatomy and 163-bone rig.
Apron, straps, pocket, ties and cloth are authored in posed world space and
inverse-skinned into bind space, so the preview and the saved rig agree.
"""
import sys, math, json, hashlib
from pathlib import Path
from collections import defaultdict
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path('D:/NetSim3D/3Dmodel')
sys.path.insert(0,str(ROOT/'scripts'))
from rebuild_student_hair_and_arms import fit_hair, bounds
from fix_cleaner_arms import refit_cleaner_arms

SOURCE=ROOT/'blend/teacher_female_khaki_160cm.blend'
OUTPUT=ROOT/'blend/cleaner_female_apron_160cm.blend'
RENDER=ROOT/'renders/cleaner';RENDER.mkdir(parents=True,exist_ok=True)
DIGEST=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version=0
asset=next(c for c in bpy.data.collections if c.name.startswith('TEACHER |'))
asset.name='CLEANER | female | 160 cm'
rig=next(o for o in asset.all_objects if o.type=='ARMATURE')
rig.name='Cleaner_Female_Rig';rig.hide_set(False)
body=next(o for o in asset.all_objects if o.name.startswith('Body |'))

def material(name,color,rough=.8,cloth=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    n=m.node_tree.nodes;p=n.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
    p.inputs['Specular IOR Level'].default_value=.2
    if cloth:
        tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=340;tex.inputs['Detail'].default_value=2
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.13;bump.inputs['Distance'].default_value=.0006
        m.node_tree.links.new(tex.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
        p.inputs['Sheen Weight'].default_value=.14
    return m

blue=material('Cleaner | slate blue cotton',(.068,.137,.185),cloth=True)
cream=material('Apron | warm ivory cotton',(.72,.70,.62),cloth=True)
edge_mat=material('Apron | darker stitched piping',(.47,.46,.39),cloth=True)
cloth_mat=material('Cleaning cloth | muted sage microfiber',(.11,.24,.19),cloth=True)
black=material('Shoes | dark practical socks',(.016,.018,.022))

for o in list(asset.all_objects):
    if o.name.startswith(('Hair |','Uniform | epaulets','Uniform | chest pockets','Uniform | editable name badge','Uniform | belt and buckle','Uniform | buttons')):
        bpy.data.objects.remove(o,do_unlink=True)
shirt=next(o for o in asset.all_objects if o.name.startswith('Uniform_Shirt'))
skirt=next(o for o in asset.all_objects if 'skirt' in o.name)
for o in (shirt,skirt):
    o.data.materials.clear();o.data.materials.append(blue)
    for p in o.data.polygons:p.material_index=0
shirt.name='Workwear | short sleeve blouse'
skirt.name='Workwear | practical knee length skirt'
shoes=next(o for o in asset.all_objects if o.name.startswith('Shoes |'))
for v in shoes.data.vertices:
    if v.co.z>.115:v.co.z=.115+(v.co.z-.115)*.35
shoes.data.materials.append(black);sock_slot=len(shoes.data.materials)-1
for p in shoes.data.polygons:
    if sum(shoes.data.vertices[i].co.z for i in p.vertices)/len(p.vertices)>.112:p.material_index=sock_slot
shoes.name='Shoes | closed black work shoes and dark socks'
arm_revision=refit_cleaner_arms(body,rig,shirt)
changed=arm_revision['restored_vertices']
hair=fit_hair('short02','Neat short crop','female',rig,asset)
rig['role']='Adult school cleaner / housekeeper'
rig['hairstyle']='Neat short crop'
rig['height_m']=1.60
rig['animation_status']='Deform skeleton retained; no animation clips. Test garment weights before animation production.'

bpy.context.view_layer.update()
def surface_tree(objects):
    vs=[];fs=[];dg=bpy.context.evaluated_depsgraph_get()
    for o in objects:
        ev=o.evaluated_get(dg);me=ev.to_mesh();offset=len(vs)
        vs.extend(ev.matrix_world@v.co for v in me.vertices)
        fs.extend(tuple(i+offset for i in p.vertices) for p in me.polygons);ev.to_mesh_clear()
    return BVHTree.FromPolygons(vs,fs)
surface=surface_tree([shirt,skirt])
def front(x,z,offset=.009):
    hit=surface.ray_cast(Vector((x,-.65,z)),Vector((0,1,0)),1.3)[0]
    if hit is None:
        # Interpolate across the tiny shirt-to-skirt seam hidden by the belt.
        hits=[surface.ray_cast(Vector((x,-.65,z+d)),Vector((0,1,0)),1.3)[0] for d in (-.014,.014)]
        hits=[p for p in hits if p is not None]
        if hits:hit=Vector((x,sum(p.y for p in hits)/len(hits),z))
    if hit is None:raise RuntimeError(f'Apron missed clothing at {x=}, {z=}')
    return Vector((x,hit.y-offset,z))

def weights(p):
    z=p.z
    if z>=.99:
        levels=[(.96,'spine05'),(1.035,'spine04'),(1.105,'spine03'),(1.22,'spine02'),(1.38,'spine01')]
        for (z0,b0),(z1,b1) in zip(levels,levels[1:]):
            if z<=z1:
                t=max(0,min(1,(z-z0)/(z1-z0)));return {b0:1-t,b1:t}
        return {'spine01':1}
    # Continuous left/right blend avoids a hard split in the apron centre.
    side=max(0,min(1,(p.x+.05)/.10))
    pelvis=max(.50,min(1,(z-.545)/.42))
    return {'pelvis.L':side*pelvis,'pelvis.R':(1-side)*pelvis,
            'upperleg01.L':side*(1-pelvis),'upperleg01.R':(1-side)*(1-pelvis)}

def bind_world(obj,weight_fn=weights):
    matrices={b.name:rig.matrix_world@b.matrix@b.bone.matrix_local.inverted() for b in rig.pose.bones}
    for v in obj.data.vertices:
        p=obj.matrix_world@v.co;w={k:n for k,n in weight_fn(p).items() if n>.000001}
        total=sum(w.values());w={k:n/total for k,n in w.items()}
        transform=Matrix(((0.,)*4,)*4)
        for k,n in w.items():transform+=matrices[k]*n
        v.co=transform.inverted()@p
        for k,n in w.items():
            g=obj.vertex_groups.get(k) or obj.vertex_groups.new(name=k);g.add([v.index],n,'REPLACE')
    obj.parent=rig;obj.matrix_parent_inverse=Matrix.Identity(4);obj.matrix_basis=Matrix.Identity(4)
    m=obj.modifiers.new('Cleaner skeleton deformation','ARMATURE');m.object=rig

def mesh(name,points,faces,mat,thickness=0):
    data=bpy.data.meshes.new(name);data.from_pydata(points,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);asset.objects.link(obj);data.materials.append(mat)
    for p in data.polygons:p.use_smooth=True
    bind_world(obj)
    if thickness:
        mod=obj.modifiers.new('Cotton fabric thickness','SOLIDIFY');mod.thickness=thickness;mod.offset=0
    return obj

def grid(name,fn,nx,ny,mat,thickness=.0015):
    points=[fn(i/nx,j/ny) for j in range(ny+1) for i in range(nx+1)]
    faces=[]
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;faces.append((a,a+nx+1,a+nx+2,a+1))
    obj=mesh(name,points,faces,mat,thickness)
    return obj,points

def tube(name,points,radius,mat):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=12
    curve.bevel_depth=radius;curve.bevel_resolution=2
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for v,p in zip(spline.points,points):v.co=(*p,1)
    obj=bpy.data.objects.new(name,curve);asset.objects.link(obj);curve.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH');obj=bpy.context.object
    bind_world(obj)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def ribbon(name,points,width,mat=cream):
    pts=[]
    for i,p in enumerate(points):
        tangent=points[min(i+1,len(points)-1)]-points[max(0,i-1)]
        cross=tangent.cross(Vector((0,1,0))).normalized()
        if cross.length<.1:cross=Vector((1,0,0))
        pts.extend([p-cross*width*.5,p+cross*width*.5])
    fs=[(i*2,i*2+2,i*2+3,i*2+1) for i in range(len(points)-1)]
    return mesh(name,pts,fs,mat,.0018)

def bib(u,v):
    # Smooth sides widen towards the waist; squared top stays below the collar.
    width=.084+.038*(v*v*(3-2*v));z=1.257-v*.302
    p=front((2*u-1)*width,z,.010)
    p.y-=.0010*math.sin(u*math.pi*4)**2*math.sin(v*math.pi)
    return p
bib_obj,_=grid('Apron | fitted chest bib',bib,28,40,cream)
for edge,fn in [('left',lambda t:bib(0,t)),('right',lambda t:bib(1,t)),('top',lambda t:bib(t,0))]:
    tube('Apron | bib '+edge+' bound edge',[fn(i/60)+Vector((0,-.001,0)) for i in range(61)],.0011,edge_mat)

def apron_lower(u,v):
    width=.126+.037*math.sin(v*math.pi/2);z=.965-.363*v
    # Rounded front hem and controlled soft drape.
    z+=.012*abs(2*u-1)**6*v**8
    p=front((2*u-1)*width,z,.012)
    p.y-=.0035*math.sin(u*math.pi*8)**2*math.sin(v*math.pi/2)
    return p
panel,_=grid('Apron | softly draped front skirt',apron_lower,44,46,cream)
for edge,fn in [('left',lambda t:apron_lower(0,t)),('right',lambda t:apron_lower(1,t)),('hem',lambda t:apron_lower(t,1))]:
    tube('Apron | skirt '+edge+' stitched edge',[fn(i/80)+Vector((0,-.001,0)) for i in range(81)],.0010,edge_mat)

# Waist ribbon wraps around the actual blouse/skirt silhouette, not a box.
waist_center=Vector((0,-.017,.961))
def belt(u,v):
    angle=u*math.tau;z=.943+v*.035;d=Vector((math.sin(angle),-math.cos(angle),0))
    # A single envelope across the waist makes an even band and covers the
    # meeting edges of the bib and lower apron without coplanar flickering.
    distances=[]
    for sample_z in (.945,.953,.961,.969,.977):
        centre=Vector((0,-.017,sample_z))
        hit=surface.ray_cast(centre+d*.5,-d,1)[0]
        if hit is not None:distances.append((hit-centre).dot(d))
    # Only the front needs room for two layers of apron fabric. Keep the
    # sides and back close to the dress instead of making a rigid hoop.
    radius=max(distances)+.004+.012*max(0,math.cos(angle))**6
    return Vector((0,-.017,z))+d*radius
belt_obj,_=grid('Apron | continuous waist tie',belt,160,3,cream)

# Neck loop climbs over the shoulders around the collar, clear of the neck.
neck_path=[]
start=bib(0,0);end=bib(1,0)
control=[start,Vector((-.078,-.12,1.31)),Vector((-.066,-.065,1.371)),Vector((-.064,.02,1.376)),
         Vector((-.058,.058,1.34)),Vector((0,.085,1.316)),Vector((.058,.058,1.34)),
         Vector((.064,.02,1.376)),Vector((.066,-.065,1.371)),Vector((.078,-.12,1.31)),end]
def catmull(points,steps=10):
    result=[]
    for i in range(len(points)-1):
        a=points[max(i-1,0)];b=points[i];c=points[i+1];d=points[min(i+2,len(points)-1)]
        for j in range(steps):
            t=j/steps;result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    return result+[points[-1]]
neck_path=catmull(control,12)
ribbon('Apron | continuous neck strap',neck_path,.021)

# Deep open-top patch pocket, with continuous stitching on the three sides.
def pocket(u,v):
    x=(u-.5)*.206;z=.865-v*.13
    p=front(x,z,.025);p.y-=.006*math.sin(u*math.pi)*math.sin(v*math.pi)
    return p
grid('Apron | large front utility pocket',pocket,26,18,cream)
for edge,fn in [('left',lambda t:pocket(0,t)),('right',lambda t:pocket(1,t)),('bottom',lambda t:pocket(t,1)),('rim',lambda t:pocket(t,0)),('divider',lambda t:pocket(.5,t))]:
    tube('Apron | pocket '+edge+' seam',[fn(i/50)+Vector((0,-.001,0)) for i in range(51)],.0009,edge_mat)

# One folded cloth hangs over the pocket rim; its lower end stays on the apron.
def cleaning_cloth(u,v):
    x=.019+u*.064;z=.905-v*.102
    p=front(x,z,.034+.009*math.sin(v*math.pi))
    p.y-=.0015*math.cos(u*math.pi*6);return p
grid('Accessory | folded microfiber cloth',cleaning_cloth,22,20,cloth_mat,.0022)
tube('Accessory | cloth stitched hem',[cleaning_cloth(i/35,1)+Vector((0,-.001,0)) for i in range(36)],.0008,edge_mat)

# Flat, practical knot and two fabric tails at the back of the waist.
back=surface.ray_cast(Vector((0,.5,.96)),Vector((0,-1,0)),1)[0].y+.013
for sign in (-1,1):
    control=[Vector((0,back,.961)),Vector((sign*.05,back+.008,.981)),Vector((sign*.077,back+.006,.96)),Vector((sign*.047,back+.008,.947)),Vector((0,back,.96))]
    ribbon('Apron | back bow loop '+str(sign),catmull(control,12),.017)
    control=[Vector((sign*.007,back+.005,.955)),Vector((sign*.022,back+.009,.906)),Vector((sign*.038,back+.015,.848)),Vector((sign*.047,back+.016,.821))]
    ribbon('Apron | back tie tail '+str(sign),catmull(control,12),.022)
bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12)
knot=bpy.context.object;knot.name='Apron | back tie knot'
for c in list(knot.users_collection):c.objects.unlink(knot)
asset.objects.link(knot)
for v in knot.data.vertices:v.co=(v.co.x*.013,back+v.co.y*.009,.960+v.co.z*.015)
knot.data.materials.append(cream);bind_world(knot)
for p in knot.data.polygons:p.use_smooth=True

# Final physical units and self-contained texture packing.
bpy.context.view_layer.update();lo,hi=bounds(asset);factor=1.60/(hi-lo)
rig.scale*=factor;rig.location*=factor;bpy.context.view_layer.update()
lo,hi=bounds(asset);rig.location.z-=lo;bpy.context.view_layer.update()
for im in bpy.data.images:
    if im.source=='FILE' and im.users and not im.packed_file:im.pack()
for t in list(bpy.data.texts):
    if t.name.startswith('README'):bpy.data.texts.remove(t)
readme=bpy.data.texts.new('README | Cleaner')
readme.write('NETSIM3D / ADULT FEMALE CLEANER / 160 CM\n\n'
             'Slate blue work blouse and knee-length skirt; ivory bib apron with pocket, continuous straps and back ties.\n'
             'Short fitted hairstyle, closed work shoes, folded microfiber cloth.\n'
             '1 Blender unit = 1 metre. Feet at Z=0, front faces -Y, +Z up.\n'
             'Export only CLEANER collection. STUDIO is for previews. All textures packed.\n'
             '163-bone deform skeleton retained; no animation clips. Garment weights require motion testing before production.\n'
             'CC0 MakeHuman anatomy/morphs, skin, eyes, brows, hairstyle and original rig; custom NetSim3D garment adaptations.\n'
             'https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.ASSETS.md\n'
             'Teacher and student assets were not modified.\n')

scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
cam=scene.camera;cam.data.type='ORTHO'
def view(pos,target,scale,name,w=850,h=1100,render=True):
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(RENDER/(name+'.png'))
    if render:bpy.ops.render.render(write_still=True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
        sp.region_3d.view_location=(0,0,.83);sp.region_3d.view_distance=2.7
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(True);bpy.context.view_layer.objects.active=None
view((1.8,-6,1.4),(0,0,.81),1.84,'cleaner_female_apron_160cm',render=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
view((1.8,-6,1.4),(0,0,.81),1.84,'cleaner_female_apron_160cm')
view((2,5,1.5),(0,0,.83),1.84,'cleaner_back')
view((5,-.3,1.3),(0,0,.87),1.84,'cleaner_side')
view((.7,-4,1.21),(0,0,1.07),.76,'cleaner_apron_detail',900,1000)
view((1.8,-6,1.4),(0,0,.81),1.84,'cleaner_female_apron_160cm',render=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==DIGEST,'Input teacher asset changed'
lo,hi=bounds(asset)
assert abs(lo)<.0001 and abs(hi-lo-1.60)<.0001
unweighted=[]
for o in asset.all_objects:
    if o.type!='MESH':continue
    bad=[v.index for v in o.data.vertices if sum(g.weight for g in v.groups)<.0001]
    if bad:unweighted.append((o.name,len(bad)))
assert not unweighted,unweighted
report={'file':str(OUTPUT),'height_m':hi-lo,'feet_z':lo,'bones':len(rig.data.bones),'mesh_objects':sum(o.type=='MESH' for o in asset.all_objects),'unweighted_vertices':0,'recovered_arm_vertices':changed,'arm_revision':arm_revision,'source_unchanged':True,'textures_packed':True,'animation_clips':0,'preview':str(RENDER/'cleaner_female_apron_160cm.png')}
(RENDER/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('CLEANER_COMPLETE '+json.dumps(report),flush=True)
