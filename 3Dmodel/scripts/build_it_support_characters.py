"""Create two separate polo-uniform variants from the existing teacher asset.
Preserves the source .blend byte-for-byte. All dimensions in metres.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

BASE=Path('D:/NetSim3D/3Dmodel')
SOURCE=BASE/'ใช้ร่วมกัน/blend/teacher_male_khaki_180cm.blend'
TEMP=BASE/'temp/it_support_characters';TEMP.mkdir(parents=True,exist_ok=True)
SOURCE_HASH=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
S=.105; FLOOR=-8.1862
def co(x,y,z):return Vector((x*S,-z*S,(y-FLOOR)*S+.026))
def source_xyz(p):return p.x/S,p.z/S+FLOOR-.026/S,-p.y/S

def material(name,color,rough=.65,metal=0,knit=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if knit:
        tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=1150;tex.inputs['Detail'].default_value=2
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.17;bump.inputs['Distance'].default_value=.00010
        l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
        p.inputs['Sheen Weight'].default_value=.15
    return m

def make_variant(stem,role,height,blue,stocky):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene
    asset=bpy.data.collections['TEACHER | male · 180 cm'];asset.name='CHARACTER | '+role
    rig=bpy.data.objects['Teacher_Male_Rig'];rig.name='IT_Supervisor_Rig' if stocky else 'IT_Support_Rig'
    rig.data.name=rig.name+'_Skeleton';rig.hide_set(False);rig.data.pose_position='REST'
    # These removals affect only the in-memory copy loaded from the teacher file.
    for name in ['Uniform | epaulets','Uniform | chest pockets','Uniform | buttons and placket','Uniform | editable name badge']:
        ob=bpy.data.objects.get(name)
        if ob:bpy.data.objects.remove(ob,do_unlink=True)
    shirt=bpy.data.objects['Uniform_Shirt | short sleeve'];shirt.name='Polo | short sleeve blue'
    pants=bpy.data.objects['Uniform_Trousers | straight tailored leg'];pants.name='Trousers | black'
    polo=material('Polo | blue pique knit',blue,.76,knit=True)
    rib=material('Polo | rib collar and sleeve cuffs',tuple(c*.70 for c in blue),.82,knit=True)
    placketmat=material('Polo | short button placket',tuple(c*.91 for c in blue),.74,knit=True)
    buttonmat=material('Polo | navy buttons',(.009,.016,.035),.34)
    thread=material('Polo | matching thread',tuple(c*.67 for c in blue),.83)
    embroidery=material('Polo | light gray embroidery',(.67,.73,.80),.8)
    trousermat=material('Trousers | matte black weave',(.010,.012,.015),.75,knit=True)
    beltmat=material('Belt | black leather',(.006,.008,.010),.43)
    buckle=material('Belt | brushed steel',(.35,.39,.43),.31,.82)
    shirt.data.materials.clear();shirt.data.materials.append(polo);shirt.data.materials.append(rib)
    for poly in shirt.data.polygons:
        x,y,z=source_xyz(poly.center)
        sleeve_distance=.67*(abs(x)-2.90)-.74*(y-3.78)
        collar=abs(x)<1.12 and y>4.95
        cuff=abs(x)>1.9 and -.24<sleeve_distance<.025
        # Keep one continuous cloth color: coarse face-based collar/cuff
        # assignments produced visibly stepped boundaries after subdivision.
        poly.material_index=0
    pants.data.materials.clear();pants.data.materials.append(trousermat)
    for p in pants.data.polygons:p.material_index=0
    belt=bpy.data.objects['Uniform | belt and buckle'];belt.name='Belt | black with steel buckle'
    for i,m in enumerate(belt.data.materials):
        belt.data.materials[i]=buckle if m and ('brass' in m.name or 'gold' in m.name) else beltmat
    seams=bpy.data.objects.get('Uniform | trouser stitching')
    if seams:
        seams.name='Trousers | seam details'
        for i in range(len(seams.data.materials)):seams.data.materials[i]=trousermat

    bpy.context.view_layer.update()
    # Work in the original armature's local rest coordinates, preserving its bind pose.
    body=bpy.data.objects['Body | head neck arms hands']
    to_rig=rig.matrix_world.inverted()@body.matrix_world
    kd=KDTree(len(body.data.vertices))
    for v in body.data.vertices:kd.insert(to_rig@v.co,v.index)
    kd.balance()
    body_groups={g.index:g.name for g in body.vertex_groups}
    shirt_bvh=BVHTree.FromObject(shirt,bpy.context.evaluated_depsgraph_get())
    def front(x,y):
        loc,normal,index,distance=shirt_bvh.ray_cast(co(x,y,5),Vector((0,1,0)))
        return -loc.y/S if loc is not None else 1.2
    def bind(ob):
        ob.parent=rig
        to_local=rig.matrix_world.inverted()@ob.matrix_world
        for v in ob.data.vertices:
            _,idx,dist=kd.find(to_local@v.co)
            weights=body.data.vertices[idx].groups
            total=sum(g.weight for g in weights)
            for item in weights:
                name=body_groups[item.group]
                vg=ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
                vg.add([v.index],item.weight/total,'REPLACE')
        mod=ob.modifiers.new('Humanoid deformation','ARMATURE');mod.object=rig
        bpy.context.view_layer.objects.active=ob
        while ob.modifiers.find(mod.name)>0:bpy.ops.object.modifier_move_up(modifier=mod.name)
    def mesh(name,vs,fs,mat):
        data=bpy.data.meshes.new(name+'Mesh');data.from_pydata(vs,[],fs);data.update()
        ob=bpy.data.objects.new(name,data);asset.objects.link(ob);data.materials.append(mat)
        for p in data.polygons:p.use_smooth=True
        return ob
    # A short three-button polo placket replaces the teacher's full-length button row.
    vs=[];fs=[];nx=4;ny=16
    for j in range(ny+1):
        y=3.05+(4.34-3.05)*j/ny
        for i in range(nx+1):
            x=-.095+.19*i/nx;vs.append(co(x,y,front(x,y)+.025))
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
    placket=mesh('Polo | short placket',vs,fs,placketmat)
    sol=placket.modifiers.new('Fabric thickness','SOLIDIFY');sol.thickness=.0008
    bind(placket)
    def sphere(name,center,scale,mat):
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,location=center)
        ob=bpy.context.object;ob.name=name
        for c in list(ob.users_collection):c.objects.unlink(ob)
        asset.objects.link(ob);ob.scale=scale
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        # Bake location into the vertices, so new parts share the source rig's local frame.
        bpy.ops.object.transform_apply(location=True,rotation=False,scale=False)
        ob.data.materials.append(mat)
        for p in ob.data.polygons:p.use_smooth=True
        bind(ob);ob.select_set(False);return ob
    for index,y in enumerate([3.25,3.74,4.22],1):
        z=front(0,y)+.063
        sphere('Polo | button '+str(index),co(0,y,z),(.004,.0015,.004),buttonmat)
        for x in [-.012,.012]:sphere('Polo | sewn button holes',co(x,y,z+.016),(.00055,.00038,.00055),thread)
    # Low-profile chest embroidery (not a government rank or a third-party logo).
    cu=bpy.data.curves.new('Role embroidery','FONT');cu.body='IT LEAD' if stocky else 'IT SUPPORT'
    cu.align_x='CENTER';cu.align_y='CENTER';cu.size=.0068;cu.extrude=.00007;cu.bevel_depth=.00002
    label=bpy.data.objects.new('Polo | '+cu.body+' embroidery',cu);asset.objects.link(label)
    label.location=co(.86,3.69,front(.86,3.69)+.046);label.rotation_euler=(math.pi/2,0,0);cu.materials.append(embroidery)
    bpy.ops.object.select_all(action='DESELECT');label.select_set(True);bpy.context.view_layer.objects.active=label
    bpy.ops.object.convert(target='MESH');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);bind(label)

    # Mild, continuous widening across the torso and face. Clothes, accessories,
    # skeleton and anatomy are deformed together, not scaled independently.
    def fuller(p):
        if not stocky:return p.copy()
        x,y,z=p
        belly=math.exp(-((z-1.00)/.22)**2)
        chest=math.exp(-((z-1.30)/.20)**2)
        hip=math.exp(-((z-.79)/.18)**2)
        head=math.exp(-((z-1.64)/.13)**4)
        central=max(0,min(1,(.34-abs(x))/.12))
        wide=1+central*(.23*belly+.065*chest+.085*hip)+.065*head
        depth=1+central*(.32*belly+.085*chest+.10*hip)+.045*head
        x*=wide;y=-.0105+(y+.0105)*depth
        if y<-.05:y-=.009*belly*central
        return Vector((x,y,z))
    if stocky:
        for ob in asset.objects:
            if ob.type!='MESH':continue
            tr=rig.matrix_world.inverted()@ob.matrix_world;inv=tr.inverted()
            for v in ob.data.vertices:v.co=inv@fuller(tr@v.co)
            ob.data.update()
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
        bpy.ops.object.mode_set(mode='EDIT')
        for b in rig.data.edit_bones:
            b.head=fuller(b.head);b.tail=fuller(b.tail)
        bpy.ops.object.mode_set(mode='OBJECT')
    rig.data.pose_position='POSE';bpy.context.view_layer.update()
    def bounds():
        dg=bpy.context.evaluated_depsgraph_get();points=[]
        for ob in asset.objects:
            if ob.type!='MESH':continue
            ev=ob.evaluated_get(dg);me=ev.to_mesh()
            points.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
        return Vector(tuple(min(p[k] for p in points) for k in range(3))),Vector(tuple(max(p[k] for p in points) for k in range(3)))
    low,high=bounds();factor=height/(high.z-low.z)
    rig.scale*=factor;rig.location*=factor
    bpy.context.view_layer.update();low,high=bounds();rig.location.z-=low.z
    bpy.context.view_layer.update();low,high=bounds()
    assert abs(high.z-low.z-height)<.00001
    assert abs(low.z)<.00001
    for ob in asset.objects:
        if ob.type=='MESH':
            assert all(sum(g.weight for g in v.groups)>.001 for v in ob.data.vertices),ob.name
            assert all(math.isfinite(c) for v in ob.data.vertices for c in v.co),ob.name
    rig['role']=role;rig['height_m']=height;rig['build']='Slightly fuller waist, abdomen, hips and face' if stocky else 'Original teacher proportions'
    rig['uniform']='Navy short-sleeve polo, short three-button placket, black trousers and shoes. No epaulets or teacher insignia.'
    rig['source_asset']=str(SOURCE);rig['export_note']='Export CHARACTER collection only. Studio is preview-only. Basic deform skeleton, no animation clips.'
    notes=bpy.data.texts.get('README | Teacher')
    if notes:
        provenance=notes.as_string().split('PROVENANCE',1)[-1]
        notes.name='README | '+role;notes.clear()
        notes.write(f'''NETSIM3D / {role.upper()}
Height including hair and shoes: {height:.2f} metres. Feet at world Z = 0.
Separate character variant derived from teacher_male_khaki_180cm.blend.
The original teacher and classroom files are not modified.

Short-sleeve blue polo with ribbed collar/cuffs, a short three-button placket,
subtle role embroidery, black trousers, black belt and black Oxford shoes.
{'Slightly fuller male build, not an extreme or caricatured body shape.' if stocky else 'Original male teacher body, face and hairstyle preserved.'}

Basic deform skeleton retained (163 bones). No animation clips or IK controls.
Unhide the rig in the Outliner to pose. Clear pose rotations to recover the
source rest pose. Test and refine skin weights when making game animations.
All six texture images packed into the blend. Export CHARACTER collection only;
the STUDIO collection is for previews. Source rig transforms are retained.

PROVENANCE{provenance}
Polo variants, color/material changes and supervisor body adaptation authored
for this NetSim3D request.
''')
    for image in bpy.data.images:
        if image.source=='FILE' and image.users and not image.packed_file:image.pack()
    report={'role':role,'height_m':high.z-low.z,'feet_z':low.z,'stockier_build':stocky,
            'bounds':[list(low),list(high)],'bones':len(rig.data.bones),
            'meshes':sum(o.type=='MESH' for o in asset.objects),'animations':len(bpy.data.actions),
            'packed_textures':[i.name for i in bpy.data.images if i.source=='FILE' and i.users and i.packed_file],
            'source_sha256':SOURCE_HASH,'output':str(BASE/'ใช้ร่วมกัน/blend'/f'{stem}.blend')}
    (TEMP/f'{stem}_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('CHARACTER_VALIDATED',json.dumps(report),flush=True)
    bpy.ops.object.select_all(action='DESELECT');rig.hide_set(True)
    cam=scene.camera;cam.name=role+' preview camera'
    def camera(pos,target,ortho):
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=ortho
    camera((2,-6.5,height+0.24),(0,0,height*.505),height*1.16)
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_x=960;scene.render.resolution_y=1280;scene.render.resolution_percentage=100
    scene.render.filepath=str(BASE/'ใช้ร่วมกัน/renders'/f'{stem}_preview.png')
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_location=(0,0,height/2)
            area.spaces.active.region_3d.view_distance=height*1.50
    path=BASE/'ใช้ร่วมกัน/blend'/f'{stem}.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    bpy.ops.render.render(write_still=True)
    camera((1.8,5,height+.2),(0,0,height*.505),height*1.17)
    scene.render.resolution_x=720;scene.render.resolution_y=960
    scene.render.filepath=str(BASE/'ใช้ร่วมกัน/renders'/f'{stem}_back.png');bpy.ops.render.render(write_still=True)
    camera((2,-6.5,height+0.24),(0,0,height*.505),height*1.16)
    scene.render.resolution_x=960;scene.render.resolution_y=1280;scene.render.filepath=str(BASE/'ใช้ร่วมกัน/renders'/f'{stem}_preview.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    # Confirm that the complete saved file can be reopened and all textures are embedded.
    saved_rig_name=rig.name
    bpy.ops.wm.open_mainfile(filepath=str(path))
    saved_rig=bpy.data.objects.get(saved_rig_name)
    assert saved_rig is not None and saved_rig.type=='ARMATURE'
    assert len(saved_rig.data.bones)==163
    assert bpy.data.collections.get('CHARACTER | '+role) is not None
    assert all(im.packed_file for im in bpy.data.images if im.source=='FILE' and im.users)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_HASH,'Source teacher changed unexpectedly'
    print('SAVED_AND_REOPENED',str(path),flush=True)

make_variant('it_support_male_180cm','IT Support',1.80,(.017,.065,.235),False)
make_variant('it_support_supervisor_male_170cm','IT Support Supervisor',1.70,(.011,.035,.12),True)
print('BOTH_CHARACTERS_COMPLETE; ORIGINAL_TEACHER_UNCHANGED',flush=True)
