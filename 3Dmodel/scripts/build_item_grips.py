"""Fit original avatar finger bones to the actual equipped tool surfaces.

Input geometry is exported by tools/export_grip_geometry.gd in the avatar arm's
normalized Blender space. No hand vertices are sculpted and no tools are scaled
or replaced here. Outputs are separate hand poses and an inspectable fit report.
"""
from pathlib import Path
import bpy, bmesh, json, math, hashlib, tempfile, sys
import numpy as np
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
scratch = ROOT / 'tmp/avatar_arm_export'
tempfile.tempdir = str(scratch)
geometry = json.loads((scratch / 'grip_geometry.json').read_text())
SOURCE = ROOT / 'net-sim-3d/assets/models/it_support_male_180cm.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
skin = next(o for o in bpy.data.objects if o.name.startswith('Body |'))
source_meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith(('Body |', 'Polo | short sleeve'))]
wrist = rig.matrix_world @ rig.data.bones['wrist.R'].head_local
elbow = rig.matrix_world @ rig.data.bones['lowerarm01.R'].head_local
rotation = (wrist-elbow).normalized().rotation_difference(Vector((0,0,1)))
across = (rig.data.bones['finger2-1.R'].head_local-rig.data.bones['finger5-1.R'].head_local).normalized()
forward = (rig.data.bones['finger3-1.R'].tail_local-rig.data.bones['finger3-1.R'].head_local).normalized()
normal = across.cross(forward).normalized()
groups = {g.index:g.name for g in skin.vertex_groups}
weights = [{groups[g.group]:g.weight for g in v.groups} for v in skin.data.vertices]
arm_indices = [i for i,w in enumerate(weights) if sum(v for k,v in w.items() if k.endswith('.R') and k.startswith(('upperarm','lowerarm','wrist','finger','metacarpal'))) >= .5]
hand_indices = [i for i in arm_indices if sum(v for k,v in weights[i].items() if k.endswith('.R') and k.startswith(('wrist','finger','metacarpal'))) > .5]
tip_indices = {f:[i for i in hand_indices if weights[i].get(f'finger{f}-3.R',0)>.5] for f in range(1,6)}
local_axes = {}
for f in range(1,6):
    for s in range(1,4):
        bone = rig.pose.bones[f'finger{f}-{s}.R']
        inv = bone.bone.matrix_local.to_3x3().inverted()
        local_axes[f,s] = [(inv@a).normalized() for a in (across,normal,forward)]

# 12 finger flexions, 4 base abductions, thumb base XYZ and two thumb flexions.
initial = np.array([45,55,25]*4 + [0]*4 + [0]*5 + [0]*3, dtype=float)
bounds = [(15,85),(15,95),(0,55)]*4 + [(-15,15)]*4 + [(-55,55)]*3 + [(-25,55)]*2 + [(-70,70)]*3
skin.data.calc_loop_triangles()
arm_set=set(arm_indices)
arm_triangles=[tuple(t.vertices) for t in skin.data.loop_triangles if all(i in arm_set for i in t.vertices)]
def pose(values):
    for f in range(2,6):
        for s in range(1,4):
            b=rig.pose.bones[f'finger{f}-{s}.R']
            b.rotation_mode='QUATERNION'
            q=Quaternion(local_axes[f,s][0],math.radians(values[(f-2)*3+s-1]))
            if s==1: q=Quaternion(local_axes[f,s][1],math.radians(values[12+f-2]))@q
            b.rotation_quaternion=q
    for s in range(1,4):
        b=rig.pose.bones[f'finger1-{s}.R']; b.rotation_mode='QUATERNION'
        if s==1:
            q=Quaternion()
            for axis,angle in zip(local_axes[1,1],values[16:19]): q=Quaternion(axis,math.radians(angle))@q
        else: q=Quaternion(local_axes[1,s][0],math.radians(values[17+s]))
        b.rotation_quaternion=q
    bpy.context.view_layer.update()

def skin_points():
    evaluated=skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [rotation@(skin.matrix_world@v.co-wrist) for v in evaluated.data.vertices]

reports={}
previous = json.loads((scratch/'grip_fit_report.json').read_text()) if '--refine' in sys.argv else {}
for item_id,data in geometry.items():
    if item_id != 'cable_tester':
        initial[:12]=[60,65,25]*4
        bounds[:12]=[(40,85),(35,95),(10,55)]*4
    else:
        initial[:12]=[45,55,25]*4
        bounds[:12]=[(15,85),(15,95),(0,55)]*4
    tool_vertices=[Vector(v) for v in data['vertices']]
    faces=data['triangles']
    # Godot uses clockwise surface winding; Blender BVH normals require CCW.
    faces=[(a,c,b) for a,b,c in faces]
    tool=BVHTree.FromPolygons(tool_vertices,faces,all_triangles=True)
    def score(values, details=False):
        pose(values)
        offset=Vector(values[21:24]/1000)
        points=[p-offset for p in skin_points()]
        surface=BVHTree.FromPolygons(points,arm_triangles,all_triangles=True)
        intersections=len(surface.overlap(tool))
        gaps=[]
        for f,indices in tip_indices.items():
            distances=sorted(tool.find_nearest(points[i])[3] for i in indices)
            # Several pad vertices must approach the surface, not only a single tip.
            gaps.append(sum(distances[:5])/5)
        regularity=float(np.sum((values[:21]-initial[:21])**2))*1e-8
        loss=intersections*.002 + sum(g*g for g in gaps)*8 + regularity
        return (loss,intersections,gaps) if details else loss
    values=initial.copy()
    if item_id in previous:
        values[:21]=previous[item_id]['angles']
        values[21:24]=np.array(previous[item_id]['offset_blender'])*1000
    best=score(values)
    print('FIT_START',item_id,score(values,True),flush=True)
    # Begin outside the geometry, then close the fingers. Starting inside a tool
    # traps local fitting in a pose with penetrating surfaces.
    from itertools import product
    for delta in ([] if previous else product(range(-60,61,20),repeat=3)):
        candidate=initial.copy();candidate[21:24]=delta
        loss=score(candidate)
        if loss<best: values=candidate;best=loss
    print('FIT_CLEAR_SEED',item_id,score(values,True),flush=True)
    for step in (() if previous else (16,8,4,2,1)):
        for sweep in range(5):
            improved=False
            for k in list(range(21,24))+list(range(21)):
                lo,hi=bounds[k]
                original=values[k]; winner=original
                for direction in (-1,1):
                    values[k]=min(hi,max(lo,original+direction*step))
                    loss=score(values)
                    if loss < best:
                        best=loss;winner=values[k];improved=True
                values[k]=winner
            print('FIT_SWEEP',item_id,step,sweep,score(values,True),flush=True)
            if not improved: break
    if item_id != 'cable_tester':
        # A finger may have to pass through the item during an offline search
        # to reach the collision-free wrapped pose on its opposite side.
        # Evaluate complete joint ranges instead of being trapped by that path.
        for sweep in range(3):
            for k in range(21):
                lo,hi=bounds[k]
                original=values[k];winner=original
                for candidate in np.linspace(lo,hi,15):
                    values[k]=candidate
                    loss=score(values)
                    if loss<best: best=loss;winner=candidate
                values[k]=winner
            print('FIT_WRAP',item_id,sweep,score(values,True),flush=True)
    final=score(values,True)
    derived=[]
    for source in source_meshes:
        allowed={g.index for g in source.vertex_groups if g.name.endswith('.R') and g.name.startswith(('upperarm','lowerarm','wrist','finger','metacarpal'))}
        keep={v.index for v in source.data.vertices if sum(g.weight for g in v.groups if g.group in allowed)>=.5}
        graph=bpy.context.evaluated_depsgraph_get()
        mesh=bpy.data.meshes.new_from_object(source.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
        bm=bmesh.new();bm.from_mesh(mesh);bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context='VERTS')
        bm.to_mesh(mesh);bm.free()
        for vertex in mesh.vertices: vertex.co=rotation@(source.matrix_world@vertex.co-wrist)
        mesh.update()
        obj=bpy.data.objects.new('AvatarRightArm_'+('Skin' if source==skin else 'OriginalSleeve'),mesh)
        bpy.context.collection.objects.link(obj);derived.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in derived: obj.select_set(True)
    output=ROOT/f'net-sim-3d/assets/models/tools/hand_{item_id}.glb'
    hand=derived[0].data
    hand.calc_loop_triangles()
    hand_bvh=BVHTree.FromPolygons([v.co for v in hand.vertices],[tuple(t.vertices) for t in hand.loop_triangles],all_triangles=True)
    offset=Vector(values[21:24]/1000)
    shifted_tool=BVHTree.FromPolygons([p+offset for p in tool_vertices],faces,all_triangles=True)
    intersections=len(hand_bvh.overlap(shifted_tool))
    assert intersections == 0, f'{item_id}: refusing to export intersecting hand/tool surfaces'
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_animations=False)
    reports[item_id]={'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'angles':values[:21].tolist(),'offset_blender':list(offset),'finger_contact_gaps_m':final[2],'surface_intersection_pairs':intersections}
    print('FIT_RESULT',item_id,reports[item_id],flush=True)
    for obj in derived: bpy.data.objects.remove(obj,do_unlink=True)
(scratch/'grip_fit_report.json').write_text(json.dumps(reports,indent=2))
