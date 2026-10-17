import bpy,json
path='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/teacher_male_khaki_180cm.blend'
bpy.ops.wm.open_mainfile(filepath=path)
col=bpy.data.collections['TEACHER | male · 180 cm']
rig=bpy.data.objects['Teacher_Male_Rig']
assert len(rig.data.bones)==163
assert sum(o.type=='MESH' for o in col.objects)==13
assert bpy.context.scene.unit_settings.scale_length==1
images=[im for im in bpy.data.images if im.source=='FILE' and im.users]
assert all(im.packed_file for im in images)
txt=bpy.data.texts['README | Teacher']
note=txt.as_string().replace('Origin/root at ground centre.','Source rig transforms are retained.')
txt.clear();txt.write(note)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=path)
print('REOPEN_VERIFIED',json.dumps({'file':path,'meshes':13,'packed_textures':len(images),'bones':163,'animations':len(bpy.data.actions),'height_m':rig['height_m']}))
