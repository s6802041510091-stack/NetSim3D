"""Render eight consistent transparent 512px UI icons from original geometry.
Uses existing project tool models; no AI image generation or external assets.
Run with Blender -b --python this_file.py.
"""
import bpy, bmesh, math, json, shutil, struct
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'net-sim-3d/assets/ui/mission_04'
OUT.mkdir(parents=True,exist_ok=True)
REPORT=[]

def material(name,color,metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.36 if metal else .46
    return m

def finish(o,m,bevel=0):
    o.data.materials.append(m)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('Rounded manufacturing edges','BEVEL'); b.width=bevel; b.segments=3
        bpy.ops.object.modifier_apply(modifier=b.name)
        w=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); w.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=w.name)
    return o

def box(size,pos,m,bev=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object; o.dimensions=size
    return finish(o,m,bev)

def cylinder(radius,depth,pos,m,axis='Z',n=32):
    rot={'Z':(0,0,0),'Y':(math.pi/2,0,0),'X':(0,math.pi/2,0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=radius,depth=depth,location=pos,rotation=rot)
    return finish(bpy.context.object,m,.0004)

def text(s,pos,size,m):
    bpy.ops.object.text_add(location=pos)
    o=bpy.context.object; o.data.body=s; o.data.align_x='CENTER'; o.data.size=size; o.data.resolution_u=3
    bpy.ops.object.convert(target='MESH'); o.data.materials.append(m)

def import_model(relative):
    bpy.ops.import_scene.gltf(filepath=str(ROOT/relative))

def remove_ink():
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH': continue
        inds={i for i,m in enumerate(o.data.materials) if m and ('Ink_' in m.name or 'Silkscreen' in m.name)}
        if not inds: continue
        bm=bmesh.new(); bm.from_mesh(o.data)
        faces=[f for f in bm.faces if f.material_index in inds]
        bmesh.ops.delete(bm,geom=faces,context='FACES')
        loose=[v for v in bm.verts if not v.link_faces]
        if loose: bmesh.ops.delete(bm,geom=loose,context='VERTS')
        bm.to_mesh(o.data); bm.free()

def flatten(rotation=None):
    bpy.context.view_layer.update()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in meshes:
        world=o.matrix_world.copy(); o.parent=None
        o.data.transform((rotation or Matrix.Identity(4))@world); o.matrix_world=Matrix.Identity(4)
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH': bpy.data.objects.remove(o,do_unlink=True)
    return meshes

def build(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    black=material('Charcoal polymer',(.018,.023,.031))
    rubber=material('Rubber',(.006,.008,.011))
    metal=material('Satin steel',(.5,.57,.63),.85)
    gold=material('Gold plating',(.72,.44,.11),.8)
    pcb=material('Green PCB',(.015,.16,.065),.12)
    blue=material('Blue grip',(.015,.12,.37))
    if name=='tool_cable_tester':
        import_model('3Dmodel/ด่าน_02/cable_tester/cable_tester.glb')
        remove_ink()
        ink=material('Numeral ink',(.02,.025,.03))
        for y in (.0115,.0488):
            for i,s in enumerate('12345678G'):
                text(s,((i-4)*.0058,y,.0267),.003,ink)
        flatten()
        # Give the remote a clear visual gap without changing any game asset.
        # Imported pieces preserve the two original module silhouettes.
    elif name=='tool_crimper':
        import_model('3Dmodel/ด่าน_02/crimp_tools/crimping_tool.glb')
        remove_ink()
        jaw=bpy.data.objects.get('Jaw_Moving')
        if jaw: jaw.rotation_euler.y=math.radians(18)
        flatten(Matrix.Rotation(math.radians(15),4,'Z')@Matrix.Rotation(-math.pi/2,4,'X'))
    elif name=='tool_stripper':
        import_model('3Dmodel/ด่าน_02/crimp_tools/cable_stripper.glb')
        remove_ink(); flatten(Matrix.Rotation(math.radians(-22),4,'Z'))
    elif name=='part_nic':
        import_model('3Dmodel/ด่าน_04/exports/pc_tower_nic.glb')
        keep={'NIC_Card','NIC_Link_LED'}
        bpy.context.view_layer.update()
        for o in list(bpy.context.scene.objects):
            if o.name in keep:
                mat=o.matrix_world.copy(); o.parent=None; o.matrix_world=mat
        for o in list(bpy.context.scene.objects):
            if o.name not in keep: bpy.data.objects.remove(o,do_unlink=True)
        remove_ink(); flatten(Matrix.Rotation(math.pi,4,'Z'))
    elif name=='tool_screwdriver':
        cylinder(.0027,.095,(.017,0,.013),metal,'X')
        cylinder(.009,.065,(-.063,0,.013),blue,'X')
        cylinder(.010,.012,(-.092,0,.013),rubber,'X')
        cylinder(.009,.006,(-.029,0,.013),rubber,'X')
        for a in range(0,360,60):
            r=math.radians(a)
            cylinder(.0015,.044,(-.063,.008*math.cos(r),.013+.008*math.sin(r)),rubber,'X',16)
        # Tapered cross-head tip with four flutes.
        for angle in (0,math.pi/2):
            verts=[(.064,-.0025,-.0008),(.064,.0025,-.0008),(.075,.0007,-.0006),(.075,-.0007,-.0006),
                   (.064,-.0025,.0008),(.064,.0025,.0008),(.075,.0007,.0006),(.075,-.0007,.0006)]
            rot=Matrix.Rotation(angle,3,'X')
            verts=[rot@Vector(v)+Vector((0,0,.013)) for v in verts]
            mesh=bpy.data.meshes.new('Phillips tip'); mesh.from_pydata(verts,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
            o=bpy.data.objects.new('Phillips tip',mesh); bpy.context.scene.collection.objects.link(o); o.data.materials.append(metal)
        flatten(Matrix.Rotation(math.radians(20),4,'Z'))
    elif name=='part_ram':
        box((.133,.030,.0016),(0,0,.006),pcb,.0005)
        for x in (-.054,-.039,-.024,-.009,.009,.024,.039,.054):
            box((.011,.015,.0018),(x,.002,.0077),black,.0004)
        for i in range(60):
            x=-.061+i*.00205
            if abs(x-.008)<.002: continue
            box((.0011,.005,.00025),(x,-.0135,.007),gold)
        for x in (-.065,.065):
            box((.002,.004,.002),(x,-.003,.006),rubber)
        flatten(Matrix.Rotation(math.radians(14),4,'Z'))
    elif name=='part_gpu':
        box((.205,.092,.002),(0,0,.010),pcb,.001)
        box((.196,.087,.020),(0,0,.023),black,.004)
        # Fin stack peeking out beneath the shroud.
        for x in range(-90,95,4):
            box((.0015,.080,.012),(x*.001,0,.012),metal)
        for x in (-.047,.047):
            cylinder(.035,.001,(x,0,.0335),rubber)
            cylinder(.011,.006,(x,0,.037),black)
            for i in range(9):
                a=i*math.tau/9
                blade=box((.023,.010,.002),(x+.021*math.cos(a),.021*math.sin(a),.036),metal,.001)
                blade.rotation_euler.z=a+.45
        box((.002,.100,.035),(-.105,0,.025),metal,.001)
        for y in (-.030,-.010,.010,.030):
            box((.001,.014,.006),(-.1062,y,.024),rubber,.0005)
        for i in range(28):
            box((.0016,.008,.0003),(-.073+i*.003,-.048,.0112),gold)
        flatten(Matrix.Rotation(math.radians(14),4,'Z'))
    elif name=='part_usb_wifi':
        box((.026,.045,.012),(0,0,.010),black,.003)
        box((.012,.016,.005),(0,-.029,.011),metal,.0007)
        box((.009,.001,.003),(0,-.0373,.011),rubber)
        for x in (-.003,-.001,.001,.003):
            box((.0006,.001,.0005),(x,-.0379,.011),gold)
        cylinder(.005,.017,(0,.024,.011),metal,'X')
        start=Vector((0,.027,.013)); end=Vector((0,.057,.065))
        antenna=cylinder(.004,(end-start).length,(start+end)/2,black)
        antenna.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
        cylinder(.004,.007,end,black)
        flatten(Matrix.Rotation(math.radians(15),4,'Z'))

def render(name):
    build(name)
    scene=bpy.context.scene
    objs=[o for o in scene.objects if o.type=='MESH']
    points=[o.matrix_world@v.co for o in objs for v in o.data.vertices]
    lo=Vector([min(v[i] for v in points) for i in range(3)])
    hi=Vector([max(v[i] for v in points) for i in range(3)])
    scale=.24/max(hi-lo)
    offset=Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
    for o in objs:
        o.data.transform(Matrix.Scale(scale,4)@Matrix.Translation(offset)@o.matrix_world)
        o.matrix_world=Matrix.Identity(4)
    points=[v.co.copy() for o in objs for v in o.data.vertices]
    camera_data=bpy.data.cameras.new('Icon camera'); cam=bpy.data.objects.new('Icon camera',camera_data)
    scene.collection.objects.link(cam); scene.camera=cam
    cam.location=(.33,-.48,.48)
    target=Vector((0,0,max(p.z for p in points)/2))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO'
    bpy.context.view_layer.update()
    inv=cam.matrix_world.inverted()
    projected=[inv@p for p in points]
    xmin,xmax=min(p.x for p in projected),max(p.x for p in projected)
    ymin,ymax=min(p.y for p in projected),max(p.y for p in projected)
    camera_data.ortho_scale=max(xmax-xmin,ymax-ymin)/.82
    cam.location += cam.rotation_euler.to_matrix()@Vector(((xmin+xmax)/2,(ymin+ymax)/2,0))
    scene.render.engine='CYCLES'; scene.cycles.samples=40; scene.cycles.use_denoising=True
    floor=box((3,3,.002),(0,0,-.002),material('Shadow catcher',(.25,.25,.25)))
    floor.is_shadow_catcher=True
    for name_light,pos,energy,size in [('Key',(-.4,-.35,.65),28,.55),('Fill',(.4,-.1,.4),16,.5),('Rim',(.1,.45,.6),30,.5)]:
        d=bpy.data.lights.new(name_light,'AREA'); d.energy=energy; d.shape='DISK'; d.size=size
        o=bpy.data.objects.new(name_light,d); scene.collection.objects.link(o); o.location=pos
        o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
    world=bpy.data.worlds.new('Neutral studio'); world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.25,.3,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.45; scene.world=world
    scene.render.film_transparent=True
    scene.render.resolution_x=scene.render.resolution_y=512; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
    scene.view_settings.exposure=-1.25
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)
    # Compatibility copies for the paths currently used by mission_04_controller.gd.
    alias=name.split('_',1)[1]+'.png'
    shutil.copyfile(OUT/(name+'.png'),OUT/alias)
    im=bpy.data.images.load(str(OUT/(name+'.png')),check_existing=False)
    pixels=list(im.pixels); alpha=pixels[3::4]
    assert tuple(im.size)==(512,512) and im.channels==4
    assert min(alpha)==0 and max(alpha)>.99
    visible=[(i%512,i//512) for i,a in enumerate(alpha) if a>.95]
    bounds=[min(p[0] for p in visible),min(p[1] for p in visible),max(p[0] for p in visible),max(p[1] for p in visible)]
    assert min(bounds[:2])>=25 and max(bounds[2:])<=487, (name,bounds)
    REPORT.append({'file':name+'.png','alias':alias,'size':[512,512],'channels':4,'opaque_bounds':bounds,'transparent_pixels':sum(a==0 for a in alpha)})
    print('ICON_DONE',name,bounds,flush=True)

for name in ('tool_cable_tester','tool_crimper','tool_stripper','tool_screwdriver','part_nic','part_ram','part_gpu','part_usb_wifi'):
    render(name)
(ROOT/'3Dmodel/ด่าน_04/exports/equipment_icons_validation.json').write_text(json.dumps(REPORT,indent=2),encoding='utf-8')
print('ALL_ICONS_VALIDATED',flush=True)
