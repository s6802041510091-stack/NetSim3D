"""Refresh embedded asset notes and confirm shoulder/leg preservation."""
import bpy,json
from pathlib import Path
FOLDER=Path('D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/students')
report=[]
for stem in ['male_mullet','male_two_block','female_bob_cut','female_wendy_cut','female_layer_cut']:
    path=FOLDER/('student_'+stem+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(FOLDER/'backup_before_simple_hair_v2'/path.name))
    original_body=next(o for o in bpy.context.scene.objects if o.name.startswith('Body |'))
    leg_positions={v.index:tuple(v.co) for v in original_body.data.vertices if sum(g.weight for g in v.groups if 'leg' in original_body.vertex_groups[g.group].name)>.6}
    shirt=next(o for o in bpy.context.scene.objects if o.name.startswith('Uniform_Shirt'))
    shirt_positions=[tuple(v.co) for v in shirt.data.vertices]
    bpy.ops.wm.open_mainfile(filepath=str(path))
    col=next(c for c in bpy.data.collections if c.name.startswith('STUDENT |'))
    rig=next(o for o in col.all_objects if o.type=='ARMATURE')
    hair=[o for o in col.all_objects if o.type=='MESH' and o.name.startswith('Hair |')]
    assert hair and all(any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers) for o in hair)
    assert len(rig.data.bones)==163
    body=next(o for o in col.all_objects if o.name.startswith('Body |'))
    assert all(max(abs(a-b) for a,b in zip(body.data.vertices[i].co,p))<1e-6 for i,p in leg_positions.items())
    shirt=next(o for o in col.all_objects if o.name.startswith('Uniform_Shirt'))
    assert [tuple(v.co) for v in shirt.data.vertices]==shirt_positions
    for ob in col.all_objects:
        if ob.type=='MESH':assert all(sum(g.weight for g in v.groups)>.0001 for v in ob.data.vertices),ob.name
    note=bpy.data.texts.get('README | Student') or bpy.data.texts.new('README | Student');note.clear()
    note.write(f'NetSim3D student | current hairstyle: {rig["hairstyle"]}\n'
        f'Height including hair and shoes: {rig["height_m"]:.2f} m. Feet Z=0; front -Y.\n'
        'Legacy filename retained for compatibility; current hairstyle is named in the collection.\n'
        'White school uniform and black shorts/skirt. Female slim-leg revision retained.\n'
        'Female arms recovered from original MakeHuman anatomy via UV correspondence.\n'
        '163-bone deform skeleton. No animation clips. Retargeting and moving poses still need testing.\n'
        'Export STUDENT collection only. Textures packed. STUDIO is a preview scene.\n'
        'Hair/body/skin/rig sources: MakeHuman CC0 system assets, fitted to each head.\n'
        'https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.ASSETS.md\n'
        'New backup: backup_before_simple_hair_v2. No classroom/Godot files edited.\n')
    for im in bpy.data.images:
        if im.source=='FILE' and im.users and not im.packed_file:im.pack()
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(path))
    report.append({'file':path.name,'hairstyle':rig['hairstyle'],'head_bound':True,'bones':len(rig.data.bones),'leg_mesh_preserved':True,'shirt_mesh_preserved':True,'animations_tested':False})
(FOLDER/'simple_hair_revision.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('FINAL_REVISION',json.dumps(report),flush=True)
