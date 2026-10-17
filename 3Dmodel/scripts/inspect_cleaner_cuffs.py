import bpy,bmesh,json
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/blend/cleaner_female_apron_160cm.blend')
o=bpy.data.objects['Workwear | short sleeve blouse']
for m in o.modifiers:
    if m.type=='SOLIDIFY':m.show_viewport=False
ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
bm=bmesh.new();bm.from_mesh(me)
edges={e for e in bm.edges if e.is_boundary};loops=[]
while edges:
    e=edges.pop();stack=[e];part={v for v in e.verts}
    while stack:
        for v in stack.pop().verts:
            for edge in v.link_edges:
                if edge in edges:edges.remove(edge);stack.append(edge);part.update(edge.verts)
    pts=[o.matrix_world@v.co for v in part];centre=sum(pts,Vector())/len(pts)
    loops.append({'vertices':len(pts),'centre':tuple(centre),'bounds':[(min(p[i] for p in pts),max(p[i] for p in pts)) for i in range(3)]})
print('CUFFS',json.dumps(loops))
