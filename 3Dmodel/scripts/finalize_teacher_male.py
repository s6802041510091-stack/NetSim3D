"""Consolidate accessories, validate the saved character and render inspection views."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
P=Path('D:/NetSim3D/3Dmodel')
FILE=P/'ใช้ร่วมกัน/blend/teacher_male_khaki_180cm.blend'
bpy.ops.wm.open_mainfile(filepath=str(FILE))
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;rig=bpy.data.objects['Teacher_Male_Rig']
asset=bpy.data.collections['TEACHER | male · 180 cm'];studio=bpy.data.collections['STUDIO | excluded from game export']
rig.data.pose_position='REST'
bpy.context.view_layer.update()
groups={
    'Uniform | epaulets':['Epaulet'],
    'Uniform | chest pockets':['Chest pocket','Pocket double','Pocket flap','Pocket button'],
    'Uniform | buttons and placket':['Shirt button','Shirt placket'],
    'Uniform | editable name badge':['Nameplate'],
    'Uniform | belt and buckle':['Belt','Buckle'],
    'Uniform | trouser stitching':['Trouser','Slanted'],
}
for label,prefixes in groups.items():
    obs=[o for o in asset.objects if o.type=='MESH' and any(o.name.startswith(p) for p in prefixes)]
    if not obs:continue
    for ob in obs:
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        for mod in list(ob.modifiers):
            if mod.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.join();obs[0].name=label
rig.data.pose_position='POSE';bpy.context.view_layer.update()

notes='''NETSIM3D / MALE TEACHER / KHAKI SHORT-SLEEVE UNIFORM

Model height: 1.800 m including hair and shoes. Feet rest at world Z = 0.
Blender metric units, +Z up, character faces -Y. Source rig transforms are retained.

The TEACHER collection contains the character. STUDIO is only for preview renders.
All image textures are packed in this .blend file. No external texture paths required.

Includes a deform skeleton with facial and finger bones. No animation clips or IK controls.
The current relaxed standing pose is a preview pose. Clear pose rotations to recover
the source rest pose before retargeting. Animation weight refinement and Godot
retargeting should be tested in the target project before production use.
The rig is hidden only in the viewport for a clean inspection view; unhide it in
the Outliner to pose the character. Mesh parts remain individually editable.

Khaki shirt with short sleeves, folded collar, 2 chest pockets and flaps,
brass buttons, generic gold-trimmed epaulets, an editable TEACHER nameplate,
straight trousers, cloth belt and brass buckle, black Oxford shoes.
Insignia are deliberately generic: no exact government rank is represented.

PROVENANCE
Anatomy, morph targets, eyes, default deform rig and weights: MakeHuman CC0 assets,
makehumancommunity/makehuman commit a8bc2d54ff0ac92e78ff71431b1023eda42bf482.
https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.ASSETS.md

Official CC0 system asset pack: young_asian_male skin, short04 hair,
eyebrow001 brows, shoes04, adapted male_casualsuit01 shirt topology.
https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html

Uniform cut, pockets, epaulets, belt, buttons, nameplate and scene assembly
were adapted/authored for this NetSim3D request using the user's uniform reference.
The reference image itself is not embedded or redistributed in the model.

classroom_shell.blend and other existing scene files were not modified.
'''
txt=bpy.data.texts.get('README | Teacher') or bpy.data.texts.new('README | Teacher');txt.clear();txt.write(notes)
rig['source']='MakeHuman CC0 anatomy, skin, eyes, hair, brows, shoes, adapted shirt topology and deform rig; custom uniform details.'
rig['animation_status']='Deform skeleton included; no animation clips. Validate and refine weights when animating.'

dg=bpy.context.evaluated_depsgraph_get();points=[];triangles=0;raw_verts=0;unweighted=[]
for ob in asset.objects:
    if ob.type!='MESH':continue
    raw_verts+=len(ob.data.vertices)
    empty=[v.index for v in ob.data.vertices if sum(g.weight for g in v.groups)<.001]
    if empty:unweighted.append({'object':ob.name,'count':len(empty)})
    assert all(math.isfinite(c) for v in ob.data.vertices for c in v.co)
    ev=ob.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles();triangles+=len(me.loop_triangles)
    points.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
low=tuple(min(p[k] for p in points) for k in range(3));high=tuple(max(p[k] for p in points) for k in range(3))
assert abs(high[2]-low[2]-1.8)<.00001,(low,high)
assert abs(low[2])<.00001
assert not unweighted,unweighted
images=[im for im in bpy.data.images if im.source=='FILE' and im.users]
for im in images:
    if not im.packed_file:im.pack()
assert all(im.packed_file for im in images)
report={'height_m':high[2]-low[2],'feet_z':low[2],'bounds':[low,high],
        'mesh_objects':sum(o.type=='MESH' for o in asset.objects),'raw_vertices':raw_verts,
        'evaluated_triangles':triangles,'bones':len(rig.data.bones),'unweighted_vertices':unweighted,
        'packed_images':[im.name for im in images],'file':str(FILE),'animations':0}
(P/'temp/teacher_male/final_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('FINAL_VALIDATION',json.dumps(report),flush=True)

bpy.ops.object.select_all(action='DESELECT')
rig.hide_set(True)
for ob in studio.objects:ob.hide_set(True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        sp=area.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
        sp.region_3d.view_location=(0,0,.90);sp.region_3d.view_distance=2.70

cam=scene.camera
def camera(pos,target,ortho):
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=ortho
def render(name,x=1050,y=1400):
    scene.render.resolution_x=x;scene.render.resolution_y=y;scene.render.resolution_percentage=100
    scene.render.filepath=str(P/'ใช้ร่วมกัน/renders'/name);bpy.ops.render.render(write_still=True)
scene.cycles.samples=48
camera((2.0,-6.5,2.05),(0,0,.91),2.08)
bpy.ops.wm.save_as_mainfile(filepath=str(FILE))
render('teacher_male_khaki_180cm_preview.png')
camera((1.8,5,2.1),(0,0,.91),2.1)
render('teacher_male_khaki_back.png',900,1200)
camera((.15,-4,1.66),(0,0,1.53),.67)
render('teacher_male_khaki_detail.png',1100,1100)
camera((2.0,-6.5,2.05),(0,0,.91),2.08)
scene.render.resolution_x=1050;scene.render.resolution_y=1400
scene.render.filepath=str(P/'ใช้ร่วมกัน/renders/teacher_male_khaki_180cm_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(FILE))
print('FINAL_TEACHER_SAVED',str(FILE),flush=True)
