import bpy, sys, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Preview/โรงเรียนและเมือง/phase3'; OUT.mkdir(parents=True,exist_ok=True)
SOURCES={
 'map':'Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend',
 'tester':'3Dmodel/ด่าน_02/cable_tester/source/cable_tester.blend',
 'crimper':'3Dmodel/ด่าน_02/crimp_tools/source/crimp_tools.blend',
 'cat6':'3Dmodel/ใช้ร่วมกัน/blend/lan_cable_cat6_5m.blend',
 'router':'3Dmodel/ใช้ร่วมกัน/network/router_ont/source/router.blend',
 'switch48':'3Dmodel/ใช้ร่วมกัน/network/switch_48port/source/switch_48port.blend',
 'switch8':'3Dmodel/ใช้ร่วมกัน/blend/office_switch_8port.blend',
 'server':'3Dmodel/ใช้ร่วมกัน/blend/rack_server_2u.blend',
}
result={}
for key,path in SOURCES.items():
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/path)); rows=[]
 for o in bpy.context.scene.objects:
  pts=[o.matrix_world@Vector(v) for v in o.bound_box] if o.type=='MESH' else [o.matrix_world.translation]
  rows.append({'name':o.name,'type':o.type,'mesh':o.data.name if o.type=='MESH' else None,
   'materials':[m.name if m else None for m in o.data.materials] if o.type=='MESH' else [],
   'collections':[c.name for c in o.users_collection],'parent':o.parent.name if o.parent else None,
   'min':[min(v[i] for v in pts) for i in range(3)],'max':[max(v[i] for v in pts) for i in range(3)],
   'hidden':o.hide_render,'properties':{k:o[k] for k in o.keys() if isinstance(o[k],(str,int,float,bool))}})
 result[key]={'path':path,'objects':rows,'materials':[{ 'name':m.name,'color':list(m.diffuse_color)} for m in bpy.data.materials]}
 print('AUDIT',key,len(rows),flush=True)
(OUT/'audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
