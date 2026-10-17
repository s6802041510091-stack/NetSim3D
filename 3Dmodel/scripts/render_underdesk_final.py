import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend');s=bpy.context.scene
d=bpy.data.cameras.new('Final underdesk inspection');c=bpy.data.objects.new('Final underdesk inspection',d);s.collection.objects.link(c);s.camera=c;c.location=(3.15,-2.45,.42);c.rotation_euler=(Vector((2.7,-1.07,.575))-c.location).to_track_quat('-Z','Y').to_euler();d.lens=29
s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=True;s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/renders/classroom_cable_fix_student_under.png';bpy.ops.render.render(write_still=True)
