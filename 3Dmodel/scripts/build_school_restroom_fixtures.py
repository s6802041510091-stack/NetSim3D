"""Reuse WC.blend and author hollow basins/urinals for both school restrooms.
All exports are metre-scale, floor Z=0, front -Y (Godot +Z).
"""
import bpy, math, json, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SHARED=ROOT/'3Dmodel/ใช้ร่วมกัน'
BLEND=SHARED/'blend/restrooms'
EXPORT=SHARED/'exports/restrooms'
GAME=ROOT/'net-sim-3d/assets/models/restrooms'
for path in (BLEND,EXPORT,GAME):path.mkdir(parents=True,exist_ok=True)
REPORT={}

def material(name,color,rough=.3,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m

def materials():
    return {'white':material('Fixture_Porcelain',(.88,.91,.90),.22),
            'metal':material('Fixture_Chrome',(.63,.68,.71),.23,.85),
            'dark':material('Fixture_Drain',(.055,.075,.078),.35,.5)}

def finish(obj,mat):
    obj.data.materials.clear();obj.data.materials.append(mat)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def box(name,pos,size,mat,bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('Rounded edges','BEVEL');b.width=bevel;b.segments=3
        bpy.ops.object.modifier_apply(modifier=b.name)
    return finish(o,mat)

def cylinder(name,pos,radius,depth,mat,segments=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=radius,depth=depth,location=pos)
    o=bpy.context.object;o.name=name;return finish(o,mat)

def tube(name,points,radius,mat):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D'
    curve.bevel_depth=radius;curve.bevel_resolution=2;curve.resolution_u=10
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,curve);bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat);bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o.select_set(False)
    return o

def rings(name,profiles,mat,sides=40,vertical=False):
    vs=[];fs=[]
    for rx,ry,z in profiles:
        for k in range(sides):
            a=k*math.tau/sides
            vs.append((rx*math.cos(a),ry*math.sin(a),z))
    for j in range(len(profiles)-1):
        for k in range(sides):fs.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple((len(profiles)-1)*sides+k for k in range(sides)))
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(o)
    return finish(o,mat)

def export(name):
    bpy.context.preferences.filepaths.save_version=0
    s=bpy.context.scene;s.unit_settings.system='METRIC'
    meshes=[o for o in s.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    obj.data.calc_loop_triangles()
    REPORT[name]={'triangles':len(obj.data.loop_triangles),'dimensions_m':list(obj.dimensions)}
    # A clean source file contains only the reusable prop, not the inspection camera.
    for o in list(s.objects):
        if o!=obj:bpy.data.objects.remove(o,do_unlink=True)
    s['front']='-Y; exported Godot +Z';s['floor']='Z=0'
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND/(name+'.blend')),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_extras=True)
    shutil.copy2(EXPORT/(name+'.glb'),GAME/(name+'.glb'))

# 1. Use the user's existing toilet model, normalised without changing WC.blend.
bpy.ops.wm.open_mainfile(filepath=str(SHARED/'blend/WC.blend'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
for other in list(bpy.context.scene.objects):
    if other!=obj:bpy.data.objects.remove(other,do_unlink=True)
bpy.context.view_layer.objects.active=obj;obj.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
pts=[v.co.copy() for v in obj.data.vertices]
lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
factor=.82/(hi.z-lo.z)
top=[p for p in pts if p.z>lo.z+(hi.z-lo.z)*.8]
tank_y=sum(p.y for p in top)/len(top)
centre=(lo+hi)/2
# The tank is the rear, +Y; bowl faces -Y for a consistent prop convention.
flip=tank_y<centre.y
for v in obj.data.vertices:
    p=v.co-centre
    if flip:p.x=-p.x;p.y=-p.y
    v.co=Vector((p.x*factor,p.y*factor,(v.co.z-lo.z)*factor))
m=materials();finish(obj,m['white'])
obj['source_model']='WC.blend; source untouched'
pts=[v.co for v in obj.data.vertices]
top=[p for p in pts if p.z>.78]
tx=sum(p.x for p in top)/len(top);ty=sum(p.y for p in top)/len(top)
box('Dual flush button',(tx+.09,ty,.823),(.065,.043,.008),m['metal'],.003)
tube('Bidet flexible hose',[(-.28,.23,.65),(-.31,.19,.29),(-.33,-.03,.19),(-.29,-.04,.53)],.007,m['metal'])
tube('Handheld bidet nozzle',[(-.29,-.04,.53),(-.29,-.04,.63),(-.29,-.08,.67)],.012,m['metal'])
export('school_toilet')

# 2. Real recessed oval vessel basin and curved mixer tap.
bpy.ops.wm.read_factory_settings(use_empty=True);m=materials()
rings('Hollow oval basin',[(.176,.108,.005),(.222,.157,.075),(.229,.163,.10),
      (.206,.140,.10),(.175,.116,.055),(.080,.052,.019),(.025,.025,.017)],m['white'])
cylinder('Basin drain',(0,0,.019),.023,.004,m['metal'])
for a in range(8):
    angle=a*math.tau/8
    cylinder('Drain perforation',(.014*math.cos(angle),.014*math.sin(angle),.0215),.0022,.001,m['dark'],8)
tube('Curved mixer tap',[(0,.14,.01),(0,.14,.19),(0,.11,.24),(0,.035,.24),(0,-.005,.205)],.014,m['metal'])
box('Mixer handle',(0,.142,.15),(.033,.08,.014),m['metal'],.004)
cylinder('Tap foot',(0,.14,.012),.027,.024,m['metal'])
export('school_basin')

# 3. Wall-mounted urinal with a genuinely recessed front, flush pipe and drain.
bpy.ops.wm.read_factory_settings(use_empty=True);m=materials()
box('Urinal back shell',(0,-.035,.75),(.35,.07,.64),m['white'],.025)
vs=[];fs=[];sides=40
for rx,rz,y in [(.16,.29,-.05),(.205,.325,-.22),(.178,.292,-.23),(.12,.24,-.09),(.035,.055,-.075)]:
    for k in range(sides):
        a=k*math.tau/sides
        vs.append((rx*math.cos(a),y+.025*math.sin(a),.75+rz*math.sin(a)))
for j in range(4):
    for k in range(sides):fs.append((j*sides+k,(j+1)*sides+k,(j+1)*sides+(k+1)%sides,j*sides+(k+1)%sides))
fs.append(tuple(4*sides+k for k in range(sides)))
me=bpy.data.meshes.new('Urinal recessed bowl');me.from_pydata(vs,[],fs);me.update()
o=bpy.data.objects.new('Urinal recessed bowl',me);bpy.context.scene.collection.objects.link(o);finish(o,m['white'])
tube('Flush pipe',[(0,-.025,1.04),(0,-.025,1.25)],.016,m['metal'])
box('Flush control',(0,-.035,1.28),(.074,.055,.067),m['metal'],.009)
drain=cylinder('Urinal drain',(0,-.122,.477),.025,.006,m['dark'])
drain.rotation_euler.x=math.radians(25)
export('school_urinal')
(EXPORT/'asset-report.json').write_text(json.dumps(REPORT,indent=2),encoding='utf-8')
print('RESTROOM_FIXTURES_CREATED',json.dumps(REPORT),flush=True)
