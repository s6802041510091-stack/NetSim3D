import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path('D:/NetSim3D/3Dmodel')
bpy.ops.wm.open_mainfile(filepath=str(root/'blend/classroom_shell.blend'))
items=[]
for o in bpy.context.scene.objects:
    p=[o.matrix_world@Vector(v) for v in o.bound_box] if o.type in ('MESH','CURVE','FONT') else [o.matrix_world.translation]
    items.append({'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,
        'collections':[c.name for c in o.users_collection], 'bounds':[[min(v[i] for v in p) for i in range(3)],[max(v[i] for v in p) for i in range(3)]],
        'location':list(o.matrix_world.translation),'dimensions':list(o.dimensions),
        'props':{k:list(v) if hasattr(v,'to_list') else str(v) for k,v in o.items()},
        'hide_viewport':o.hide_viewport,'hide_render':o.hide_render,'hide_set':o.hide_get()})
out=root/'temp/corridor_resize';out.mkdir(parents=True,exist_ok=True)
(out/'before_inventory.json').write_text(json.dumps({'objects':items,'scene_props':{k:str(v) for k,v in bpy.context.scene.items()},'collections':[{'name':c.name,'hide_viewport':c.hide_viewport,'hide_render':c.hide_render} for c in bpy.data.collections]},indent=2),encoding='utf-8')
print('INVENTORY',len(items),str(out/'before_inventory.json'),flush=True)
for i in items:
    if any(x in i['name'].lower() for x in ('corridor','ceiling','room_','floor','camera','slab')) and not any(x in i['name'] for x in ('StudentPC','TeacherPC')):
        print(i['name'],i['type'],'BOUNDS',i['bounds'],'PARENT',i['parent'],flush=True)
print('SCENE_PROPS',{k:str(v) for k,v in bpy.context.scene.items()},flush=True)
