import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend')
s=bpy.context.scene
for o in s.objects:
 if 'ceiling' in o.name.lower():o.hide_render=True
d=bpy.data.cameras.new('Overview');c=bpy.data.objects.new('Overview',d);s.collection.objects.link(c)
c.location=(0,-16,19);c.rotation_euler=(Vector((0,0,0))-c.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=25;s.camera=c
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True
s.render.resolution_x=1400;s.render.resolution_y=1200;s.render.resolution_percentage=100
s.render.filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/renders/classroom_student_computers.png';bpy.ops.render.render(write_still=True)
