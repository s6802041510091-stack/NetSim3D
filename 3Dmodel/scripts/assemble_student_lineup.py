"""Reopen and validate the five students, then make an inspection-only lineup."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

ROOT=Path('D:/NetSim3D/3Dmodel');folder=ROOT/'blend/students'
specs=[('male_mullet','SHORT CROP',1.65),('male_two_block','SIDE PART',1.65),('female_bob_cut','SHORT PIXIE',1.60),('female_wendy_cut','PONYTAIL',1.60),('female_layer_cut','TIED BUN',1.60)]
reports=[]
for stem,label,height in specs:
    bpy.ops.wm.open_mainfile(filepath=str(folder/('student_'+stem+'.blend')))
    asset=next(c for c in bpy.data.collections if c.name.startswith('STUDENT |'))
    rig=next(o for o in asset.all_objects if o.type=='ARMATURE')
    dg=bpy.context.evaluated_depsgraph_get();pts=[];tris=0;unweighted=0
    for ob in asset.all_objects:
        if ob.type!='MESH':continue
        assert all(math.isfinite(c) for v in ob.data.vertices for c in v.co)
        unweighted+=sum(sum(g.weight for g in v.groups)<.0001 for v in ob.data.vertices)
        ev=ob.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles();tris+=len(me.loop_triangles)
        pts.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
    lo=min(v.z for v in pts);hi=max(v.z for v in pts)
    assert abs(hi-lo-height)<.001 and abs(lo)<.001
    assert unweighted==0,(stem,unweighted)
    assert all(im.packed_file for im in bpy.data.images if im.source=='FILE' and im.users)
    reports.append({'file':'student_'+stem+'.blend','height_m':hi-lo,'feet_z':lo,'bones':len(rig.data.bones),'triangles':tris,'unweighted_vertices':unweighted,'packed_textures':True})

bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
for idx,(stem,label,height) in enumerate(specs):
    with bpy.data.libraries.load(str(folder/('student_'+stem+'.blend')),link=False) as (src,dst):
        dst.collections=[n for n in src.collections if n.startswith('STUDENT |')]
    col=dst.collections[0];scene.collection.children.link(col)
    for ob in col.all_objects:
        if ob.parent is None:
            ob.location.x+=(idx-2)*.90
            if ob.type=='ARMATURE':ob.rotation_euler.z+=math.radians([0,-12,10,-30,30][idx])
    font=bpy.data.curves.new(label,'FONT');font.body=label; font.size=.082;font.align_x='CENTER'
    text=bpy.data.objects.new('Preview label | '+label,font);scene.collection.objects.link(text)
    text.location=((idx-2)*.90,-.22,-.105);text.rotation_euler=(math.pi/2,0,0)
    m=bpy.data.materials.get('Labels') or bpy.data.materials.new('Labels');m.diffuse_color=(.66,.77,.86,1);font.materials.append(m)

def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1)
    return m
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.13));bpy.context.object.name='STUDIO | ground';bpy.context.object.data.materials.append(material('Slate studio',(.032,.043,.06)))
for pos,power,size in [((1,-4,5),850,5),((-4,-2,2.5),500,4),((2,3,4),1000,3)]:
    d=bpy.data.lights.new('Studio softbox','AREA');d.energy=power;d.shape='DISK';d.size=size
    ob=bpy.data.objects.new(d.name,d);scene.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector((0,0,.9))-ob.location).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('Studio world');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.15,.20,1)
bpy.ops.object.camera_add(location=(0,-9,2.5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.80))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.85;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1800;scene.render.resolution_y=950;scene.render.resolution_percentage=100
scene.render.filepath=str(ROOT/'renders/students/students_lineup.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        sp=area.spaces.active;sp.overlay.show_overlays=False;sp.shading.type='MATERIAL'
        sp.region_3d.view_location=(0,0,.8);sp.region_3d.view_distance=6;sp.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
for ob in scene.objects:
    ob.select_set(False)
    if ob.type=='ARMATURE':ob.hide_set(True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'students_lineup.blend'))
bpy.ops.render.render(write_still=True)
(folder/'validation.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
print('ALL_FIVE_REOPENED_AND_VALIDATED '+json.dumps(reports),flush=True)
