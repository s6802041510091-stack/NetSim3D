import bpy,shutil,datetime,json
from pathlib import Path
from mathutils import Vector
BASE=Path('D:/NetSim3D/3Dmodel');path=BASE/'ใช้ร่วมกัน/blend/classroom_shell.blend'
backup=path.with_name('classroom_shell_before_student_computers_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend');shutil.copy2(path,backup)
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
assert not bpy.data.collections.get('13 | Student computers - 20 sets'),'Already populated'
col=bpy.data.collections.new('13 | Student computers - 20 sets');scene.collection.children.link(col)
source=bpy.data.objects['TeacherComputerSet_Root'];originals=[source]+list(source.children_recursive)
desks=sorted([o for o in scene.objects if o.name.startswith('StudentDesk_Row')],key=lambda o:o.name);assert len(desks)==10
def bounds(objects):
 pts=[o.matrix_world@Vector(c) for o in objects if o.type=='MESH' for c in o.bound_box]
 return [min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]
report=[]
for desk in desks:
 inv=desk.matrix_world.inverted();p=inv@Vector((desk.location.x+.3,desk.location.y,2))
 hit,loc,normal,index=desk.ray_cast(p,(inv.to_3x3()@Vector((0,0,-1))).normalized());assert hit
 top=(desk.matrix_world@loc).z
 dlo,dhi=bounds([desk]);
 for seat,offset in enumerate([-.705,.495],1):
  group=bpy.data.collections.new(desk.name+f' | Computer {seat}');col.children.link(group)
  copies={}
  for ob in originals:
   cp=ob.copy();cp.name=f'StudentPC_{desk.name.removeprefix("StudentDesk_")}_{seat}__{ob.name}';group.objects.link(cp);copies[ob]=cp
  for ob,cp in copies.items():
   if ob.parent in copies:cp.parent=copies[ob.parent]
   for mod in cp.modifiers:
    if hasattr(mod,'object') and mod.object in copies:mod.object=copies[mod.object]
   for constraint in cp.constraints:
    if hasattr(constraint,'target') and constraint.target in copies:constraint.target=copies[constraint.target]
  root=copies[source];root.location=(desk.location.x+offset,desk.location.y,top+.0005);root.rotation_euler=(0,0,0)
  root['placement']='Student station facing front board (+Y); screen and keyboard face seated student (-Y)'
  root['desk']=desk.name;root['seat']=seat
  bpy.context.view_layer.update()
  lo,hi=bounds(list(copies.values()))
  assert lo[0]>dlo[0]+.02 and hi[0]<dhi[0]-.02,(desk.name,lo,hi)
  assert lo[1]>dlo[1]+.02 and hi[1]<dhi[1]-.02,(desk.name,lo,hi)
  for name in ['01_Case','02_Monitor','03_Keyboard','04_Mouse']:
   part=copies[bpy.data.objects[name]];pmin,pmax=bounds(list(part.children_recursive));assert abs(pmin[2]-top)<.002,(name,pmin,top)
  report.append({'desk':desk.name,'seat':seat,'tabletop':top,'bounds':[lo,hi]})
scene['student_computers']='20 full desktop sets, 2 per student desk; linked mesh data, independent object hierarchies.'
bpy.ops.object.select_all(action='DESELECT');bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
(BASE/'temp/student_computers_validation.json').write_text(json.dumps({'backup':str(backup),'stations':report},indent=2))
print('SAVED_20_COMPUTERS',str(backup),flush=True)
# Preview only: do not save camera or ceiling visibility changes to the asset.
for o in scene.objects:
 if 'ceiling' in o.name.lower():o.hide_render=True
data=bpy.data.cameras.new('Student PCs preview');cam=bpy.data.objects.new('Student PCs preview',data);scene.collection.objects.link(cam)
cam.location=(0,-9.0,5.5);target=Vector((0,-.2,.8));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();data.lens=22;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.filepath=str(BASE/'ใช้ร่วมกัน/renders/classroom_student_computers.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.open_mainfile(filepath=str(path));assert len(bpy.data.collections['13 | Student computers - 20 sets'].children)==20
print('REOPEN_VERIFIED',flush=True)
