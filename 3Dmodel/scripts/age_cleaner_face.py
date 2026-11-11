"""Age only the existing cleaner's face; retain outfit, body, rig and hairstyle."""
import bpy, math, shutil, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/NetSim3D');MODEL=ROOT/'3Dmodel/ใช้ร่วมกัน/blend/cleaner_female_apron_160cm.blend'
BACKUP=ROOT/'tmp/cleaner_before_face_age_20261109.blend'
if not BACKUP.exists():
    raise SystemExit('This face edit is already applied. Its historical input was removed during cleanup; use the current cleaner model instead of recreating a backup from it.')
bpy.ops.wm.open_mainfile(filepath=str(BACKUP));bpy.context.preferences.filepaths.save_version=0
asset=bpy.data.collections['CLEANER | female | 160 cm'];body=bpy.data.objects['Body | female head arms lower legs']
others={o.name:[tuple(v.co) for v in o.data.vertices] for o in asset.all_objects if o.type=='MESH' and o!=body}
protected=[tuple(v.co) for v in body.data.vertices if v.co.z<1.39]
def g(x,c,w):return math.exp(-((x-c)/w)**2)
changed=0
for v in body.data.vertices:
    x,y,z=v.co;ax=abs(x)
    if z<1.39 or y>-.065:continue
    front=min(1,max(0,(-y-.065)/.035))
    cheek=g(ax,.045,.022)*g(z,1.465,.022)*front
    jaw=g(ax,.054,.020)*g(z,1.425,.020)*front
    eye=g(ax,.028,.020)*g(z,1.485,.006)*front
    v.co.y+=.005*cheek-.0012*eye
    v.co.z-=.003*cheek+.0035*jaw+.0008*eye
    v.co.x+=(1 if x>0 else -1)*.0015*jaw
    lip=g(x,0,.028)*g(z,1.438,.006)*front
    v.co.z+=(1.438-z)*.13*lip
    changed+=1
assert protected==[tuple(v.co) for v in body.data.vertices if v.co.z<1.39]

# Analytic wrinkle shader in mesh coordinates: shallow furrows with soft ends.
# It uses the original skin texture and UVs; no external texture dependencies.
skin=body.data.materials[0].copy();skin.name='Cleaner | mature skin 50-55 years';body.data.materials[0]=skin
n=skin.node_tree.nodes;l=skin.node_tree.links
def op(kind,a,b=None):
    node=n.new('ShaderNodeMath');node.operation=kind
    for i,value in enumerate([a,b] if b is not None else [a]):
        if isinstance(value,(int,float)):node.inputs[i].default_value=value
        else:l.new(value,node.inputs[i])
    return node.outputs[0]
def gauss(value,center,width):
    d=op('DIVIDE',op('SUBTRACT',value,center),width)
    return op('EXPONENT',op('MULTIPLY',op('MULTIPLY',d,d),-1))
coord=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(coord.outputs['Object'],sep.inputs[0])
x,y,z=[sep.outputs[k] for k in ['X','Y','Z']];ax=op('ABSOLUTE',x)
front=op('MULTIPLY',op('LESS_THAN',y,-.085),op('GREATER_THAN',z,1.395))
lines=[]
for height,strength in [(1.533,.65),(1.543,.8),(1.553,.55)]:
    curved=op('SUBTRACT',height,op('MULTIPLY',op('MULTIPLY',x,x),.9))
    lines.append(op('MULTIPLY',op('MULTIPLY',gauss(z,curved,.00055),gauss(x,0,.046)),strength))
# Under-eye creases and fine crow's feet stay below/outside the eyelids.
curve=op('ADD',1.490,op('MULTIPLY',op('POWER',op('SUBTRACT',ax,.028),2),9))
lines.append(op('MULTIPLY',gauss(z,curve,.00055),gauss(ax,.030,.014)))
for slope in [-.38,0,.38]:
    center=op('ADD',1.495,op('MULTIPLY',op('SUBTRACT',ax,.049),slope))
    lines.append(op('MULTIPLY',op('MULTIPLY',gauss(z,center,.00045),gauss(ax,.056,.008)),.65))
# Nasolabial folds fade before the chin rather than forming painted outlines.
fold_x=op('ADD',.025,op('MULTIPLY',op('SUBTRACT',1.465,z),.40))
lines.append(op('MULTIPLY',op('MULTIPLY',gauss(ax,fold_x,.0011),gauss(z,1.446,.019)),.8))
wrinkles=lines[0]
for line in lines[1:]:wrinkles=op('ADD',wrinkles,line)
wrinkles=op('MINIMUM',op('MULTIPLY',wrinkles,front),1)
bsdf=n.get('Principled BSDF');original=bsdf.inputs['Base Color'].links[0].from_socket
mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[2].default_value=(.65,.55,.48,1)
l.new(op('MULTIPLY',wrinkles,.30),mix.inputs[0]);l.new(original,mix.inputs[1]);l.new(mix.outputs[0],bsdf.inputs['Base Color'])
bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.45;bump.inputs['Distance'].default_value=.0008;bump.invert=True
l.new(wrinkles,bump.inputs['Height'])
if bsdf.inputs['Normal'].is_linked:l.new(bsdf.inputs['Normal'].links[0].from_socket,bump.inputs['Normal'])
l.new(bump.outputs['Normal'],bsdf.inputs['Normal']);bsdf.inputs['Roughness'].default_value=.64

hair=next(o for o in asset.all_objects if o.name.startswith('Hair |'))
for slot in hair.material_slots:
    if not slot.material or not slot.material.use_nodes:continue
    mat=slot.material.copy();slot.material=mat;mat.name='Cleaner | dark hair with early grey'
    nn=mat.node_tree.nodes;ll=mat.node_tree.links;p=nn.get('Principled BSDF')
    if not p or not p.inputs['Base Color'].is_linked:continue
    color=p.inputs['Base Color'].links[0].from_socket
    noise=nn.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=95;noise.inputs['Detail'].default_value=2
    ramp=nn.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.51;ramp.color_ramp.elements[1].position=.73
    ramp.color_ramp.elements[1].color=(.48,.48,.48,1);ll.new(noise.outputs['Fac'],ramp.inputs[0])
    blend=nn.new('ShaderNodeMixRGB');blend.inputs[2].default_value=(.22,.21,.19,1)
    blend.inputs[0].default_value=.12
    ll.new(color,blend.inputs[1]);ll.new(blend.outputs[0],p.inputs['Base Color'])
for name,points in others.items():assert points==[tuple(v.co) for v in bpy.data.objects[name].data.vertices],name
rig=bpy.data.objects['Cleaner_Female_Rig'];rig['face_revision']='Mature adult around 50-55: cheek volume, mild jowls, shallow expression lines and early greying; 2026-11-09'
bpy.context.view_layer.update()
scene=bpy.context.scene;cam=scene.camera;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
def render(name,location,target,scale,w=850,h=950):
    cam.location=location;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=w;scene.render.resolution_y=h
    scene.render.filepath=str(ROOT/('3Dmodel/ใช้ร่วมกัน/renders/cleaner/'+name+'.png'));bpy.ops.render.render(write_still=True)
render('cleaner_mature_face',(.3,-3,1.52),(0,-.02,1.46),.37)
render('cleaner_mature_three_quarter',(2,-3,1.53),(0,-.02,1.46),.37)
render('cleaner_mature_full',(1.8,-6,1.4),(0,0,.81),1.84,850,1100)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tmp/cleaner_mature_candidate.blend'))
print('MATURE_FACE_REPORT',json.dumps({'face_vertices':changed,'body_below_face_preserved':True,'outfit_and_other_meshes_preserved':True,'bones':len(rig.data.bones)}),flush=True)
