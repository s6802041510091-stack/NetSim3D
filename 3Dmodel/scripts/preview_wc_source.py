"""Read-only inspection of the existing WC.blend prop."""
import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root/'3Dmodel/ใช้ร่วมกัน/blend/WC.blend'))
objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
pts=[o.matrix_world@Vector(c) for o in objs for c in o.bound_box]
lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
print('WC_BOUNDS',list(lo),list(hi),'MATERIALS',[(m.name,list(m.diffuse_color)) for m in bpy.data.materials],flush=True)
s=bpy.context.scene
camera=bpy.data.objects.new('Inspection camera',bpy.data.cameras.new('Inspection camera'))
s.collection.objects.link(camera)
centre=(lo+hi)*.5
size=max(hi-lo)
camera.location=centre+Vector((1.7,-2.5,1.3))*size
camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=size*1.5
s.camera=camera;s.render.engine='BLENDER_WORKBENCH'
s.display.shading.light='STUDIO';s.display.shading.color_type='MATERIAL'
s.render.resolution_x=900;s.render.resolution_y=900;s.render.resolution_percentage=100
out=root/'Preview/โรงเรียนและเมือง/restrooms'
out.mkdir(parents=True,exist_ok=True)
s.render.filepath=str(out/'wc-source.png')
bpy.ops.render.render(write_still=True)
