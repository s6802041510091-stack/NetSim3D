"""Restore continuous source anatomy instead of bending the upper arm to a shirt.

Only skin hidden inside the fixed short-sleeved outfit is trimmed. The shirt,
apron, head, legs, hands, UVs and armature layout remain otherwise unchanged.
This function is also used by the cleaner builder to prevent regression.
"""
import bpy,bmesh,math,json,shutil,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
from mathutils.kdtree import KDTree

ROOT=Path('D:/NetSim3D/3Dmodel')
sys.path.insert(0,str(ROOT/'scripts'))
from rebuild_student_hair_and_arms import anatomy,bounds

def smooth(t):
    t=max(0.,min(1.,t));return t*t*(3.-2.*t)

def skin_matrix(body,entries,matrices):
    total=0.;result=Matrix(((0.,)*4,)*4)
    for index,weight in entries:
        name=body.vertex_groups[index].name
        if name in matrices:result+=matrices[name]*weight;total+=weight
    return result*(1/total) if total>.000001 else Matrix.Identity(4)

def refit_cleaner_arms(body,rig,shirt):
    vs,uv,fs,groups,co=anatomy('female');by_uv={}
    for face,group in zip(fs,groups):
        if group=='body':
            for i,ui in face:by_uv[tuple(round(x,6) for x in uv[ui])]=i
    source={}
    for loop in body.data.loops:
        key=tuple(round(x,6) for x in body.data.uv_layers.active.data[loop.index].uv)
        if key in by_uv:source[loop.vertex_index]=co(vs[by_uv[key]])
    arm_names={}
    for side in ('L','R'):
        root=rig.data.bones['upperarm01.'+side]
        arm_names[side]={root.name}|{b.name for b in root.children_recursive}
    all_names=arm_names['L']|arm_names['R']
    mats={b.name:rig.matrix_world@b.matrix@b.bone.matrix_local.inverted() for b in rig.pose.bones}
    protected=[];restored=0;maxmove=0
    for v in body.data.vertices:
        arm_weight=sum(g.weight for g in v.groups if body.vertex_groups[g.group].name in all_names)
        if arm_weight>.5 and v.index in source:
            before=mats['spine05']@v.co
            delta=(v.co-source[v.index]).length;maxmove=max(maxmove,delta)
            if delta>1e-7:restored+=1
            v.co=source[v.index]
        elif arm_weight<.01:
            protected.append(v.co.copy())

    # Read the actual sleeve openings with the fabric thickness disabled.
    solid=[m for m in shirt.modifiers if m.type=='SOLIDIFY']
    previous=[m.show_viewport for m in solid]
    for m in solid:m.show_viewport=False
    bpy.context.view_layer.update();ev=shirt.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    bm=bmesh.new();bm.from_mesh(me);edges={e for e in bm.edges if e.is_boundary};cuffs={}
    while edges:
        edge=edges.pop();stack=[edge];part=set(edge.verts)
        while stack:
            for v in stack.pop().verts:
                for e in v.link_edges:
                    if e in edges:edges.remove(e);stack.append(e);part.update(e.verts)
        points=[shirt.matrix_world@v.co for v in part];centre=sum(points,Vector())/len(points)
        if abs(centre.x)>.12 and 1.08<centre.z<1.24:
            side='L' if centre.x>0 else 'R'
            cuffs[side]={'centre':centre,'cut_z':max(p.z for p in points)+.014}
    bm.free();ev.to_mesh_clear()
    for m,shown in zip(solid,previous):m.show_viewport=shown
    assert len(cuffs)==2,'Both sleeve openings must be identified'

    # Pose-space trimming lets the hidden skin end follow the saved garment.
    # The visible upper arm, elbow, forearm and hand stay the source shape.
    for v in body.data.vertices:v.co=skin_matrix(body,((g.group,g.weight) for g in v.groups),mats)@v.co
    bm=bmesh.new();bm.from_mesh(body.data);deform=bm.verts.layers.deform.verify()
    old_faces=len(bm.faces);old_vertices=len(bm.verts)
    for side in ('L','R'):
        indices={g.index for g in body.vertex_groups if g.name in arm_names[side]}
        cuff=cuffs[side];cut=cuff['cut_z'];centre=cuff['centre']
        chosen={v for v in bm.verts if sum(w for i,w in v[deform].items() if i in indices)>.5}
        # Only a short overlap concealed by the sleeve is fitted inward.
        # No cross-section warp is applied below the visible sleeve edge.
        for v in chosen:
            t=smooth((v.co.z-(centre.z-.002))/(cut-(centre.z-.002)))
            if t:
                sign=1 if side=='L' else -1
                v.co.x-=sign*.008*t
                v.co.y=centre.y+(v.co.y-centre.y)*(1-.06*t)
        edges={e for v in chosen for e in v.link_edges}
        faces={f for v in chosen for f in v.link_faces}
        bmesh.ops.bisect_plane(bm,geom=list(chosen)+list(edges)+list(faces),
            dist=.000001,plane_co=(0,0,cut),plane_no=(0,0,1),clear_outer=True)
    for v in bm.verts:v.co=skin_matrix(body,v[deform].items(),mats).inverted()@v.co
    bm.to_mesh(body.data);bm.free();body.data.update();bpy.context.view_layer.update()
    # Confirm that the non-arm surface was not altered or discarded.
    tree=KDTree(len(body.data.vertices))
    for v in body.data.vertices:tree.insert(v.co,v.index)
    tree.balance();protected_error=max(tree.find(p)[2] for p in protected)
    print('PROTECTED_ANATOMY_MAX_ERROR',protected_error,flush=True)
    assert protected_error<.000002,'Non-arm anatomy changed'
    assert all(sum(g.weight for g in v.groups)>.0001 for v in body.data.vertices)
    rig['arm_revision']='2026-10-14: complete source upper-arm anatomy restored, hidden sleeve overlap trimmed. No 5 cm inward upper-arm warp.'
    return {'restored_vertices':restored,'maximum_removed_rest_distortion_m':maxmove,
            'hidden_skin_faces_removed':old_faces-len(body.data.polygons),
            'vertex_count_before':old_vertices,'vertex_count_after':len(body.data.vertices),
            'non_arm_anatomy_preserved':True,'sleeve_cut_world_z':{k:v['cut_z'] for k,v in cuffs.items()}}

def main():
    path=ROOT/'blend/cleaner_female_apron_160cm.blend'
    backup=ROOT/'blend/cleaner_female_apron_160cm_before_arm_alignment.blend'
    if not backup.exists():shutil.copy2(path,backup)
    bpy.ops.wm.open_mainfile(filepath=str(backup));bpy.context.preferences.filepaths.save_version=0
    asset=bpy.data.collections['CLEANER | female | 160 cm'];rig=bpy.data.objects['Cleaner_Female_Rig']
    body=bpy.data.objects['Body | female head arms lower legs'];shirt=bpy.data.objects['Workwear | short sleeve blouse']
    original={o.name:[tuple(v.co) for v in o.data.vertices] for o in asset.all_objects if o.type=='MESH' and o!=body}
    report=refit_cleaner_arms(body,rig,shirt)
    for name,points in original.items():assert [tuple(v.co) for v in bpy.data.objects[name].data.vertices]==points,name
    lo,hi=bounds(asset);assert abs(hi-lo-1.6)<.0001 and abs(lo)<.0001
    report.update({'file':str(path),'backup':str(backup),'height_m':hi-lo,'feet_z':lo,'bones':len(rig.data.bones),'clothes_apron_hair_unchanged':True})
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_percentage=100;cam=scene.camera;cam.data.type='ORTHO'
    def view(pos,target,scale,name,w=850,h=1100,render=True):
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(ROOT/'renders/cleaner'/(name+'.png'))
        if render:bpy.ops.render.render(write_still=True)
    view((0,-6,1.05),(0,0,1.02),.87,'cleaner_arms_front_corrected',900,1000)
    view((5,0,1.03),(.21,0,1.01),.58,'cleaner_arm_side_corrected',650,1000)
    view((0,5,1.05),(0,0,1.02),.87,'cleaner_arms_back_corrected',850,1000)
    view((1.8,-6,1.4),(0,0,.81),1.84,'cleaner_female_apron_160cm')
    view((2,5,1.5),(0,0,.83),1.84,'cleaner_back')
    view((5,-.3,1.3),(0,0,.87),1.84,'cleaner_side')
    view((.7,-4,1.21),(0,0,1.07),.76,'cleaner_apron_detail',900,1000)
    view((1.8,-6,1.4),(0,0,.81),1.84,'cleaner_female_apron_160cm',render=False)
    note=bpy.data.texts['README | Cleaner'];note.write('\nArm correction: full source upper-arm contour restored; only hidden skin under the short sleeves trimmed. Outfit and other anatomy preserved.\n')
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    (ROOT/'renders/cleaner/arm_alignment_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('CLEANER_ARM_CORRECTION',json.dumps(report),flush=True)

if __name__=='__main__':main()
