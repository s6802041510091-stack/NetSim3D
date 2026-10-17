import bpy, shutil, datetime, json
from pathlib import Path
from mathutils import Vector
BASE=Path('D:/NetSim3D/3Dmodel')
path=BASE/'ใช้ร่วมกัน/blend/classroom_shell.blend'
backup=BASE/'ใช้ร่วมกัน/blend'/('classroom_shell_before_windows_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend')
shutil.copy2(path,backup)
bpy.ops.wm.open_mainfile(filepath=str(path))
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
col=bpy.data.collections.new('12 | Classroom corridor windows');scene.collection.children.link(col)
frame=bpy.data.materials['MAT_Frame_Dark_Gray']
glass=bpy.data.materials.new('Windows | clear two-sided glass');glass.use_nodes=True
glass.diffuse_color=(.85,.94,1,.10)
nodes=glass.node_tree.nodes;nodes.clear();links=glass.node_tree.links
out=nodes.new('ShaderNodeOutputMaterial');mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.10
trans=nodes.new('ShaderNodeBsdfTransparent');g=nodes.new('ShaderNodeBsdfGlass');g.inputs['Color'].default_value=(.96,.99,1,1);g.inputs['Roughness'].default_value=.035;g.inputs['IOR'].default_value=1.45
links.new(trans.outputs[0],mix.inputs[1]);links.new(g.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs['Surface'])
glass.use_backface_culling=False
def box(name,pos,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o)
 if mat:o.data.materials.append(mat)
 return o
targets=[('Wall_Left_With_Door',-6.075,'Computer'),('Left_Corridor_South_Segment_0',-9.19,'Background')]
centers=[-6.7,-2.8,1.1,5.0]
for wallname,x,prefix in targets:
 wall=bpy.data.objects[wallname]
 for i,y in enumerate(centers,1):
  tag=f'CorridorWindow_{prefix}_{i:02d}'
  cutter=box(tag+'_Cut',(x,y,1.7),(.65,2.8,1.4),None)
  bpy.context.view_layer.objects.active=wall
  mod=wall.modifiers.new(tag+'_Opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
  for side in [-1,1]:
   box(tag+'_Jamb',(x,y+side*1.37,1.7),(.20,.06,1.4),frame)
   box(tag+'_Rail',(x,y,1.7+side*.67),(.20,2.68,.06),frame)
  box(tag+'_Mullion',(x,y,1.7),(.12,.045,1.28),frame)
  box(tag+'_Sill',(x,y,.99),(.30,2.9,.035),frame)
  for side in [-1,1]:
   pane=box(tag+'_ClearGlass',(x,y+side*.68,1.7),(.006,1.30,1.28),glass)
   pane.display_type='WIRE';pane['note']='Clear from both sides. Wire display in Solid mode; glass visible in Material Preview / Rendered.'
  # Verify an unobstructed ray through the actual wall mesh, away from the mullion.
  inv=wall.matrix_world.inverted();a=inv@Vector((x-1,y+.4,1.7));d=(inv.to_3x3()@Vector((1,0,0))).normalized()
  assert not wall.ray_cast(a,d)[0],wallname+' opening obstructed'
for o in bpy.data.objects:
 if o.type=='MESH' and o.name.startswith('Window_') and '_Glass_' in o.name:
  o.data.materials.clear();o.data.materials.append(glass);o.display_type='WIRE'
scene['corridor_windows']='8 windows: four per classroom, 2.8m x 1.4m, sill 1.0m. Openings cut through walls, two-sided clear glass.'
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
print('SAVED',path,'BACKUP',backup,flush=True)
# Render verification from standing eye level in the corridor, looking into the furnished room.
camdata=bpy.data.cameras.new('Window verification camera');cam=bpy.data.objects.new('Window verification camera',camdata);scene.collection.objects.link(cam)
cam.location=(-7.65,-2.8,1.7);target=Vector((1,-2.0,1.25));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camdata.lens=22;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.render.filepath=str(BASE/'ใช้ร่วมกัน/renders/classroom_corridor_windows.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.open_mainfile(filepath=str(path))
assert len([o for o in bpy.data.objects if o.name.startswith('CorridorWindow_') and 'ClearGlass' in o.name])==16
print('VERIFIED_EIGHT_WINDOWS_AND_REOPENED',flush=True)
