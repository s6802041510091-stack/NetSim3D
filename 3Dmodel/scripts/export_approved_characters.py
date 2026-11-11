"""Export the current character sources as skinned GLBs and verify roundtrips."""
import bpy, json, math
from pathlib import Path
root=Path('D:/NetSim3D/3Dmodel/ใช้ร่วมกัน')
sources=['it_support_male_180cm','it_support_supervisor_male_170cm',
 'teacher_male_khaki_180cm','teacher_female_khaki_160cm','cleaner_female_apron_160cm']
sources += ['students/student_'+name for name in ['male_mullet','male_two_block','female_bob_cut','female_wendy_cut','female_layer_cut']]
out=root/'exports/characters';out.mkdir(parents=True,exist_ok=True)
required={'spine05','upperarm01.L','upperarm01.R','lowerarm01.L','lowerarm01.R',
          'upperleg01.L','upperleg01.R','lowerleg01.L','lowerleg01.R'}
report=[]
for relative in sources:
    source=root/'blend'/(relative+'.blend');name=source.stem
    assert source.is_file(),source
    bpy.ops.wm.open_mainfile(filepath=str(source))
    assets=[c for c in bpy.data.collections if c.name.startswith(('STUDENT |','TEACHER','CLEANER','IT Support','IT_Support'))]
    rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
    assert len(rigs)==1,(name,[o.name for o in rigs]);rig=rigs[0]
    bones={b.name for b in rig.data.bones}
    assert required<=bones,(name,sorted(required-bones))
    bpy.ops.object.select_all(action='DESELECT')
    selected=[rig]
    for ob in bpy.data.objects:
        if ob.type=='MESH' and (ob.parent==rig or any(m.type=='ARMATURE' and m.object==rig for m in ob.modifiers)):
            selected.append(ob)
    assert len(selected)>1,name
    rig.hide_set(False)
    for ob in selected:
        ob.hide_set(False)
        ob.select_set(True)
    bpy.context.view_layer.objects.active=rig
    if name=='student_female_bob_cut':
        # glTF cannot carry Blender's procedural hair color nodes; the
        # unbaked ramp exported white. Keep the approved dark palette in GLB.
        for ob in selected:
            if not ob.name.startswith('Hair |'):continue
            for mat in ob.data.materials:
                if not mat or not mat.use_nodes:continue
                p=mat.node_tree.nodes.get('Principled BSDF')
                if not p:continue
                for inp in ('Base Color','Alpha'):
                    for link in list(p.inputs[inp].links):mat.node_tree.links.remove(link)
                p.inputs['Base Color'].default_value=mat.diffuse_color
                p.inputs['Alpha'].default_value=1.0
    print('SELECTION',name,'rig_visible',rig.visible_get(),'rig_hide',rig.hide_render,
          'actual',[(o.name,o.type) for o in bpy.context.selected_objects[:3]],
          'mesh_armature',[(m.name,m.show_viewport,m.show_render) for m in selected[1].modifiers if m.type=='ARMATURE'],flush=True)
    target=out/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
        export_skins=True,export_animations=False,export_materials='EXPORT')
    assert target.stat().st_size>10000,(name,target.stat().st_size)
    print('EXPORTED',name,target.stat().st_size,len(selected)-1,flush=True)
    # Verify the actual GLB that Godot will import, not just the Blender source.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(target))
    armatures=[o for o in bpy.data.objects if o.type=='ARMATURE']
    assert len(armatures)==1,(name,len(armatures))
    exported_bones={b.name for b in armatures[0].data.bones}
    assert required<=exported_bones,(name,sorted(required-exported_bones))
    skinned=[o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
    assert skinned,(name,'no skinned meshes')
    entry={'name':name,'source':str(source.relative_to(root)),'glb':str(target.relative_to(root)),
           'glb_bytes':target.stat().st_size,'source_bones':len(bones),'glb_bones':len(exported_bones),
           'skinned_meshes':len(skinned),'required_bones':True}
    report.append(entry)
    print('VERIFIED',json.dumps(entry,ensure_ascii=False),flush=True)
(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('ALL_CHARACTERS_EXPORTED_AND_VERIFIED',len(report),flush=True)
