import bpy, bmesh, sys, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend'
bpy.ops.wm.open_mainfile(filepath=str(WORK))
o=bpy.data.objects['Chair_IT_PlayerDesk_1']
if '--apply' in sys.argv and o.get('p1_cushions_rounded'):
    with bpy.data.libraries.load(str(WORK.with_name('classroom_shell_lookdev_before_phase1.blend')),link=False) as (source,target):
        target.meshes=['Desk chair shared geometry']
    o.data=target.meshes[0]
    for i,name in enumerate(['Fabric','PowderCoat','Rubber']):
        o.data.materials[i]=bpy.data.materials['P1 | '+name]
bm=bmesh.new(); bm.from_mesh(o.data)
fabric_faces=[f for f in bm.faces if f.material_index==0]
verts=set(v for f in fabric_faces for v in f.verts)
components=[]
while verts:
    pending=[verts.pop()]; group=set(pending)
    while pending:
        v=pending.pop()
        for e in v.link_edges:
            n=e.other_vert(v)
            if n in verts: verts.remove(n); group.add(n); pending.append(n)
    components.append(group)
for group in components:
    print('FABRIC_COMPONENT',len(group),[min(v.co[i] for v in group) for i in range(3)],[max(v.co[i] for v in group) for i in range(3)],flush=True)
if '--apply' in sys.argv:
    # Work only on the private sample mesh. Retain the original steel legs/frame.
    import numpy as np
    from mathutils import Matrix
    for group in components:
        coords=np.array([v.co[:] for v in group]); center=coords.mean(axis=0)
        values,axes=np.linalg.eigh(np.cov((coords-center).T))
        if np.linalg.det(axes)<0: axes[:,0]*=-1
        extent=np.max(np.abs((coords-center)@axes),axis=0)
        bmesh.ops.delete(bm,geom=list(group),context='VERTS')
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=2)
        temp=bpy.context.object
        for v in temp.data.vertices: v.co=Vector(np.array(v.co[:])*extent)
        temp.data.update()
        bevel=temp.modifiers.new('Cushion rounding','BEVEL'); bevel.width=.018; bevel.segments=5
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        new=[bm.verts.new(Vector(center+axes@np.array(v.co[:]))) for v in temp.data.vertices]
        for poly in temp.data.polygons:
            f=bm.faces.new([new[i] for i in poly.vertices]); f.material_index=0
            f.smooth=poly.area<.004
        bpy.data.objects.remove(temp,do_unlink=True)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free()
    edge=o.modifiers.get('P1 edge highlight')
    if edge: o.modifiers.remove(edge)
    sys.path.insert(0,str(Path(__file__).parent))
    import phase1_it_corner as p1
    p1.box_uv(o,{'P1 | Fabric':.24,'P1 | PowderCoat':.15,'P1 | Rubber':.16})
    o['p1_cushions_rounded']=True
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)
