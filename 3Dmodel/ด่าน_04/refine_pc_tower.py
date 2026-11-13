"""Realism pass, using the immutable pre-refinement .blend as input.
Only writes under this directory. Does not access or modify the game project.
Run create_detail_atlas.ps1 first, then Blender -b --python this_file.py.
"""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

OUT=Path(__file__).resolve().parent
BASE=OUT/'revisions/before_realism/pc_tower_nic.blend'
bpy.ops.wm.open_mainfile(filepath=str(BASE))
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
bpy.context.view_layer.update()
objects={o.name:o for o in scene.objects}
expected={'PC_Tower','Case_Body','Side_Cover','Interior','Power_LED','NIC_Card','NIC_Link_LED',
          'NIC_Port_Point','Cover_Screw_1','Cover_Screw_2','NIC_Bracket_Screw','Power_Button',
          'Power_Cable_Plug','PCIe_Slot_Target'}
assert set(objects)==expected
def bounds(o):
    vs=[o.matrix_world@v.co for v in o.data.vertices]
    return ([min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)])
def state(o):
    return {'parent':o.parent.name if o.parent else None,
            'matrix_local':[list(row) for row in o.matrix_local],
            'origin_world':list(o.matrix_world.translation), 'dimensions':list(o.dimensions),
            'bounds_world':bounds(o) if o.type=='MESH' else None}
baseline={name:state(o) for name,o in objects.items()}
(OUT/'revisions/before_realism/contract.json').write_text(json.dumps(baseline,indent=2),encoding='utf-8')
parts={name:[] for name,o in objects.items() if o.type=='MESH'}
mm=lambda v:Vector(v)*.001
mats=bpy.data.materials
coat=mats['Graphite powder-coated steel']; steel=mats['Steel chassis']
silver=mats['Brushed aluminium']; black=mats['Socket cavities and rubber']
plastic=mats['Charcoal polymer']; gold=mats['Gold contacts']; white=mats['Silkscreen and labels']

def finish(o,material,group,bevel=0):
    o.data.materials.append(material)
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Manufactured edge','BEVEL');mod.width=bevel*.001;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    parts[group].append(o)
    return o
def box(label,size,pos,material=steel,group='Interior',bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=mm(pos))
    o=bpy.context.object;o.name=label;o.dimensions=mm(size)
    return finish(o,material,group,bevel)
def cylinder(label,radius,depth,pos,material=silver,group='Interior',axis='X',segments=12):
    rot={'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0),'Z':(0,0,0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=radius*.001,depth=depth*.001,
                                      location=mm(pos),rotation=rot)
    o=bpy.context.object;o.name=label
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return finish(o,material,group)
def mesh(label,verts,faces,material,group):
    data=bpy.data.meshes.new(label);data.from_pydata([mm(v) for v in verts],[],faces);data.update()
    o=bpy.data.objects.new(label,data);scene.collection.objects.link(o)
    return finish(o,material,group)
def components(o):
    adjacency=[[] for v in o.data.vertices]
    for e in o.data.edges:
        a,b=e.vertices;adjacency[a].append(b);adjacency[b].append(a)
    visited=set();result=[]
    for start in range(len(adjacency)):
        if start in visited:continue
        stack=[start];visited.add(start);group=[]
        while stack:
            i=stack.pop();group.append(i)
            for j in adjacency[i]:
                if j not in visited:visited.add(j);stack.append(j)
        result.append(group)
    return result
def remove_vertices(o,indices):
    bm=bmesh.new();bm.from_mesh(o.data);bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[bm.verts[i] for i in indices],context='VERTS')
    bm.to_mesh(o.data);bm.free();o.data.update()

# Replace only the 28 coarse blade islands; frames, mounts and overall bounds stay put.
fans=[((30,17,309),37,'Y'),((-10,-180,273),53,'Y'),((-17,185,301),51,'Y'),((6,120,94),45,'Z')]
interior=objects['Interior'];remove=[];removed_blades=0
for island in components(interior):
    if len(island)!=8:continue
    coords=[interior.matrix_world@interior.data.vertices[i].co*1000 for i in island]
    center=sum(coords,Vector())/len(coords)
    for c,r,axis in fans:
        delta=center-Vector(c);normal=delta.y if axis=='Y' else delta.z
        radius=math.hypot(delta.x,delta.z if axis=='Y' else delta.y)
        if abs(normal)<4 and .25*r<radius<.85*r:
            remove.extend(island);removed_blades+=1;break
assert removed_blades==28,removed_blades
remove_vertices(interior,remove)
for center,radius,axis in fans:
    c=Vector(center);u=Vector((1,0,0));v=Vector((0,0,1)) if axis=='Y' else Vector((0,1,0))
    n=Vector((0,1,0)) if axis=='Y' else Vector((0,0,1))
    for blade in range(7):
        angle=blade*math.tau/7
        outline=[]
        for r,a,h in [(0.24,0,-1),(.46,.02,-1.6),(.72,.14,-1.2),(.94,.33,0),
                      (.97,.51,.8),(.75,.61,1.8),(.46,.68,2.4),(.25,.57,1.2)]:
            outline.append(c+u*(radius*r*math.cos(angle+a))+v*(radius*r*math.sin(angle+a))+n*h)
        verts=outline+[p+n*.8 for p in outline]
        faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
        o=mesh('Swept pitched fan blade',verts,faces,plastic,'Interior')
        for p in o.data.polygons:p.use_smooth=True
    # Small hub axle; fits inside each existing hub.
    cylinder('Fan axle',3,7.5,c,silver,axis=axis,segments=12)

# Fine PCB art and component labels share a single 1024 px texture atlas.
image=bpy.data.images.load(str(OUT/'textures/pc_detail_atlas_1024.png'),check_existing=False)
image.pack()
atlas=bpy.data.materials.new('PC detail atlas | silk and labels');atlas.use_nodes=True
p=atlas.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.65
tex=atlas.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
atlas.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
def decal(label,pos,width,height,rect,group='Interior',plane='side'):
    c=Vector(pos)
    u,v={'side':(Vector((0,-1,0)),Vector((0,0,1))),
         'top':(Vector((1,0,0)),Vector((0,1,0))),
         'front':(Vector((1,0,0)),Vector((0,0,1)))}[plane]
    verts=[c-u*width/2-v*height/2,c+u*width/2-v*height/2,c+u*width/2+v*height/2,c-u*width/2+v*height/2]
    o=mesh(label,verts,[(0,1,2,3)],atlas,group)
    x,y,w,h=rect;uvs=[(x/1024,1-(y+h)/1024),((x+w)/1024,1-(y+h)/1024),
                       ((x+w)/1024,1-y/1024),(x/1024,1-y/1024)]
    uv=o.data.uv_layers.new(name='UVMap')
    for i,value in enumerate(uvs):uv.data[i].uv=value
    return o
decal('Motherboard solder-mask traces',(85.94,35,246),238,288,(0,0,512,640))
decal('Power supply ratings',(-68.9,118,51),92,48,(512,0,512,256))
decal('NVMe controller label',(79.25,64,212),41,16,(512,256,512,96))
decal('HDD serial label',(-9,-110,41.85),56,30,(512,352,512,96),plane='top')
decal('SATA SSD label',(-9,-116,63.35),48,23,(512,640,512,128),plane='top')
for y in (-25,-41):
    decal('DIMM capacity label',(48.95,y,308),4.2,45,(512,448,512,96))
decal('NIC service label',(45,166,118.95),28,7,(512,544,512,96),'NIC_Card','top')
decal('CPU fan electrical rating',(30,12.8,309),17,5,(0,640,512,128),plane='front')

# Electrolytic capacitors with scored aluminium caps; VRM chokes and solder pads.
for y,z in [(-65,230),(-65,245),(-65,260),(-65,275),(109,278),(122,278),(135,278),(110,331),(125,331),(140,331)]:
    cylinder('Electrolytic capacitor sleeve',3.0,8,(81,y,z),black,segments=10)
    cylinder('Electrolytic capacitor aluminium cap',2.65,.35,(76.8,y,z),silver,segments=10)
    box('Capacitor scored vent',(.12,4.5,.35),(76.56,y,z),plastic)
    box('Capacitor scored vent',(.12,.35,4.5),(76.56,y,z),plastic)
for y in (35,51,67,83):
    box('VRM ferrite choke',(7,9,8),(81,y,371),plastic,bevel=.4)
    box('Choke metal crown',(.3,7,6),(77.3,y,371),steel)
for y,z in [(-65,187),(-59,196),(-56,206),(15,180),(25,187),(38,182),(107,188),(117,175),(136,158)]:
    box('Ceramic SMD capacitor',(1.4,3,1.7),(84.3,y,z),gold)
    for dy in (-2,2):box('Solder termination',(.6,1,2),(84.5,y+dy,z),silver)

# Folded sheet metal returns stay inside Case_Body's original envelope.
for y in (-192,192):
    box('Folded upper case return',(7,5,2),(-88,y,393),steel,'Case_Body',.4)
box('Upper rolled rim',(4,378,2),(-90,0,393),steel,'Case_Body',.4)
box('Lower rolled rim',(4,378,2),(-90,0,10),steel,'Case_Body',.4)
box('Front folded jamb',(4,3,374),(-90,-192,202),steel,'Case_Body',.4)
for y in (-185,185):
    for z in (20,389):
        cylinder('Case rivet',1.7,1.0,(-92,y,z),silver,'Case_Body',segments=8)

# Rear slot surround: solid sheet around the NIC's actual bracket aperture.
# It sits aft of all card geometry (y >=199.7 mm), so the -X removal still clears.
def rear_rect(label,x0,x1,z0,z1):
    return box(label,(x1-x0,.3,z1-z0),((x0+x1)/2,199.85,(z0+z1)/2),coat,'Case_Body')
rear_rect('Solid rear slot left',-92,-12.8,107,143)
rear_rect('Solid rear slot right',76.8,92,107,143)
rear_rect('Solid rear slot lower',-12.8,76.8,107,116.7)
rear_rect('Solid rear slot upper',-12.8,76.8,135.3,143)
# Close cosmetic gaps between the upper rear rim and fan surround too.
rear_rect('Rear fan upper seam',-76,38,376,380)

# Re-route the cable as a vertical service loop above the tabletop.
# Keep plug housing and origin unchanged; preserve the entire object's XYZ size.
plug=objects['Power_Cable_Plug'];remove=[];removed_segments=0
for island in components(plug):
    coords=[plug.matrix_world@plug.data.vertices[i].co for i in island]
    if len(island)==24 and min(v.y for v in coords)>.236 and max(v.y for v in coords)>.239:
        remove.extend(island);removed_segments+=1
assert removed_segments==8,removed_segments
remove_vertices(plug,remove)
old_size=baseline['Power_Cable_Plug']['dimensions']
top=4+old_size[2]*1000
controls=[(53,237,48),(56,245,44),(62,251,32),(62,251,17),(59,251,9),(53,251,7),
          (47,251,9),(44,251,17),(44,251,top-15),(47,251,top-6),
          (53,251,top-3),(59,251,top-6),(62,251,top-15),(62,251,78)]
controls=[Vector(v) for v in controls]
path=[]
for i in range(len(controls)-1):
    p0,p1,p2,p3=controls[max(i-1,0)],controls[i],controls[i+1],controls[min(i+2,len(controls)-1)]
    for j in range(4):
        t=j/4
        path.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
path.append(controls[-1]);verts=[];sides=10
for i,c in enumerate(path):
    tangent=(path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized()
    u=tangent.cross(Vector((0,1,0))).normalized();v=tangent.cross(u).normalized()
    for j in range(sides):
        a=j*math.tau/sides;verts.append(c+3*(u*math.cos(a)+v*math.sin(a)))
lo_z=min(v.z for v in verts);hi_z=max(v.z for v in verts);max_y=max(v.y for v in verts)
old_y=baseline['Power_Cable_Plug']['bounds_world'][1][1]*1000
for v in verts:
    v.z=4+(v.z-lo_z)/(hi_z-lo_z)*(top-4)
    v.y=237+(v.y-237)*(old_y-237)/(max_y-237)
# Anchor the first ring to the original strain relief mouth after the size fit.
shift=Vector((53,237,48))-sum(verts[:sides],Vector())/sides
for ring in range(3):
    for j in range(sides):verts[ring*sides+j]+=shift*(1-ring/3)
faces=[]
for i in range(len(path)-1):
    for j in range(sides):
        a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
faces += [tuple(reversed(range(sides))),tuple(range((len(path)-1)*sides,len(path)*sides))]
cable=mesh('Tabletop-safe service loop',verts,faces,black,'Power_Cable_Plug')
for p in cable.data.polygons:p.use_smooth=len(p.vertices)==4

# Merge additions into their original named objects, keeping the active origin.
for name,added in parts.items():
    if not added:continue
    o=objects[name];original_world=o.matrix_world.copy()
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    for item in added:item.select_set(True)
    bpy.context.view_layer.objects.active=o;bpy.ops.object.join();o.matrix_world=original_world
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
bpy.context.view_layer.update()
for name,o in objects.items():
    now=state(o);old=baseline[name]
    assert now['parent']==old['parent'],name
    assert max(abs(a-b) for row_a,row_b in zip(now['matrix_local'],old['matrix_local']) for a,b in zip(row_a,row_b))<1e-7,name
    assert max(abs(a-b) for a,b in zip(now['dimensions'],old['dimensions']))<2e-6,(name,old['dimensions'],now['dimensions'])
    assert all(abs(a-b)<1e-7 for a,b in zip(now['origin_world'],old['origin_world'])),name
assert set(o.name for o in scene.objects)==expected
assert bounds(plug)[0][2]>=0
triangles={}
for name,o in objects.items():
    if o.type=='MESH':o.data.calc_loop_triangles();triangles[name]=len(o.data.loop_triangles)
assert sum(triangles.values())<=20000,triangles
assert all(not o.modifiers for o in objects.values())
report={'triangles':sum(triangles.values()),'per_object_triangles':triangles,'contract_objects':len(expected),
        'original_origins_and_dimensions':'preserved within 0.002 mm',
        'texture_size':[1024,1024],'texture_count':1,'cable_min_z_m':bounds(plug)[0][2],
        'cable_max_z_m':bounds(plug)[1][2], 'rear_slot_aperture_mm':[-12.8,76.8,116.7,135.3],
        'before':baseline,'after':{name:state(o) for name,o in objects.items()}}
(OUT/'exports/pc_tower_realism_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene['asset_triangle_count']=sum(triangles.values());scene['asset_revision']='realism / tabletop-safe cable'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pc_tower_nic.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'exports/pc_tower_nic.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False)
print('REFINEMENT_SAVED',sum(triangles.values()),'CABLE_MIN_Z',bounds(plug)[0][2],flush=True)

# Studio is render-only, created after the clean asset is saved/exported.
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
box('Preview tabletop',(2000,2000,20),(0,0,-10),plastic,'Case_Body')
camdata=bpy.data.cameras.new('Preview camera');cam=bpy.data.objects.new('Preview camera',camdata)
scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO'
for name,pos,energy,size in [('Key',(-.65,-.5,.9),38,.7),('Fill',(-.6,.5,.5),22,.6),('Rim',(.5,.25,.9),40,.6)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;aim(o,(0,0,.2))
world=bpy.data.worlds.new('Soft studio');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.24,.30,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True;scene.cycles.max_bounces=6
scene.render.resolution_x=1400;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-.4
shots=[('closed',(-.75,-.9,.65),(0,0,.20),.70,False),
       ('open',(-1,.56,.61),(0,0,.20),.70,True),
       ('service_parts',(-.55,.85,.46),(0,0,.20),.70,False),
       ('detail',(-.65,.31,.42),(.02,.04,.245),.40,True)]
for name,pos,target,scale,opened in shots:
    for obj in ('Side_Cover','Cover_Screw_1','Cover_Screw_2'):objects[obj].hide_render=opened
    cam.location=pos;aim(cam,target);camdata.ortho_scale=scale
    scene.render.filepath=str(OUT/'previews'/f'pc_tower_{name}.png')
    bpy.ops.render.render(write_still=True);print('PREVIEW_DONE',name,flush=True)
