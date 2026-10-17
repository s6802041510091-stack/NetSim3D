import bpy,json
from collections import defaultdict,deque
from mathutils import Vector
from mathutils.bvhtree import BVHTree
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/teacher_male_khaki_180cm.blend')
eye=bpy.data.objects['Eyes | fitted cornea iris sclera'];me=eye.data
image=bpy.data.images.get('brown_eye.png');pix=list(image.pixels[:]);w,h=image.size
for u,v in [(.284,.278),(.717,.719),(.90,.10),(.50,.50)]:
    idx=(int(v*h)*w+int(u*w))*4;print('PIX',u,v,pix[idx:idx+4])
adj=defaultdict(set)
for edge in me.edges:
    a,b=edge.vertices;adj[a].add(b);adj[b].add(a)
unseen=set(range(len(me.vertices)));components=[]
while unseen:
    start=unseen.pop();comp={start};todo=[start]
    while todo:
        i=todo.pop()
        for j in adj[i]:
            if j in unseen:unseen.remove(j);comp.add(j);todo.append(j)
    components.append(comp)
for c in components:
    ids=sorted(c,key=lambda i:me.vertices[i].co.y)[:8]
    print('COMPONENT',len(c),'BOUNDS',[[min(me.vertices[i].co[k] for i in c),max(me.vertices[i].co[k] for i in c)] for k in range(3)])
    for i in ids[:3]:
        uv=[tuple(me.uv_layers.active.data[l.index].uv) for l in me.loops if l.vertex_index==i][:1]
        print('FRONT',i,tuple(me.vertices[i].co),uv)
shirt=bpy.data.objects['Uniform_Shirt | short sleeve'];bvh=BVHTree.FromObject(shirt,bpy.context.evaluated_depsgraph_get())
floor=-8.1862;S=.105
for x,y in [(0,4.75),(.16,5.03),(.70,4.79),(.98,5.34),(0,3.7),(.65,4.85)]:
    p=Vector((x*S,-5*S,(y-floor)*S+.026));loc,_,_,_=bvh.ray_cast(p,Vector((0,1,0)))
    print('SHIRT FRONT',x,y,-loc.y/S if loc is not None else None)
