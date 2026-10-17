"""Equipment lookdev, preserving authored pivots, connectors and screen contracts."""
import bpy, sys, math, json, shutil, tempfile, re
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
import phase1_it_corner as p1
import phase2_architecture as p2
import phase1_surface_textures as tex
WORK=p1.WORK
OUT=ROOT/'3Dmodel/lookdev/phase3'; OUT.mkdir(exist_ok=True,parents=True)
BACKUP=WORK.with_name('classroom_shell_lookdev_before_phase3.blend')
AUDIT=json.loads((OUT/'audit.json').read_text(encoding='utf-8'))
PATHS={}
def write(name,data):
 (OUT/name).parent.mkdir(exist_ok=True,parents=True)
 (OUT/name).write_text(json.dumps(data,indent=2),encoding='utf-8')
def simple(name,color,rough=.5,metal=0):
 m=bpy.data.materials.new('P3 | '+name); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
 m.diffuse_color=(*color,1); return m
def surface(name,color,rough=.5,metal=0,kind='plastic'):
 existing=bpy.data.materials.get('P3 | '+name)
 if existing:return existing
 import numpy as np
 folder=OUT/'textures'; folder.mkdir(exist_ok=True)
 n=512; grain=tex.noise(n,.8,16 if kind=='metal' else .8,301)
 fine=tex.noise(n,2,2,302)
 if kind=='perforated':
  y,x=np.mgrid[0:n,0:n]/n
  r=np.sqrt((x-.5)**2+(y-.5)**2); mask=np.clip((r-.27)*180,0,1)
  variation=mask*.8+.2; height=mask*.5
 else:variation=1+.015*grain+.006*fine; height=grain*.03
 srgb=[12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055 for c in color]
 base=np.stack([c*variation for c in srgb],axis=2)
 paths=tex.maps(folder,name.replace(' ','_'),base,rough+.015*grain,height,.5)
 m=p1.create_material('p3temp',paths,metal,.18 if kind!='perforated' else .65); m.name='P3 | '+name
 PATHS[name]={k:str(v) for k,v in paths.items()}; return m
def common():
 return {
 'Metal':surface('Satin metal',(.45,.48,.52),.32,.85,'metal'),
 'DarkMetal':surface('Anodised graphite',(.075,.085,.10),.38,.72,'metal'),
 'Gold':simple('Plated contacts',(.75,.46,.12),.25,.9),
 'PVC':surface('Flexible black PVC',(.012,.014,.018),.57),
 'White':surface('Ivory ABS',(.70,.72,.70),.46),
 'Mouse':surface('Mouse pale blue',(.38,.53,.65),.43),
 'CableGrey':surface('Cable pale grey',(.62,.65,.67),.59),
 'Red':surface('Red switch polymer',(.42,.018,.009),.39),
 'Perforated':surface('Rack perforation',(.045,.052,.06),.50,.45,'perforated'),
 'BluePVC':surface('Network blue PVC',(.018,.15,.48),.58),
 'YellowPVC':surface('Network yellow PVC',(.60,.42,.012),.58),
 }
def load_p1():
 with bpy.data.libraries.load(str(BACKUP),link=False) as (src,dst):
  dst.materials=[n for n in src.materials if n in ['P1 | Polymer','P1 | PowderCoat','P1 | Rubber','P1 | CoatedWhite'] and n not in bpy.data.materials]
def local_uv(o):
 me=o.data; uv=me.uv_layers.get('P3_SurfaceUV') or me.uv_layers.new(name='P3_SurfaceUV')
 me.uv_layers.active=uv; uv.active_render=True
 for poly in me.polygons:
  axis=max(range(3),key=lambda j:abs(poly.normal[j])); mat=me.materials[poly.material_index] if poly.material_index<len(me.materials) else None
  scale=.006 if mat and mat.name=='P3 | Rack perforation' else .12
  for li in poly.loop_indices:
   co=me.vertices[me.loops[li].vertex_index].co
   co=Vector([co[j]*abs(o.scale[j]) for j in range(3)])
   u,v=(co.x,co.y) if axis==2 else (co.x,co.z) if axis==1 else (co.y,co.z)
   uv.data[li].uv=(u/scale,v/scale)
def target(o):
 if o.type!='MESH' or 'Monitor_Display_Surface' in o.name:return False
 if o.name.startswith(('DC_Rack_','DC_Row_End_Panel','DC_UPS','DC_Battery_Cabinet')):return True
 return any(c.name.startswith(('ASSET | NetCare','Teacher Computer','StudentDesk_','15 | Realistic connected','16 | Underdesk mounts','POWER |','19.2 | Computers')) for c in o.users_collection) or o.name.startswith('StaffPC_')
def replacement(m,mats):
 n=re.sub(r'\.\d{3}$','',m.name)
 if n.startswith(('Polymer | charcoal','Moulded charcoal')):return bpy.data.materials['P1 | Polymer']
 if n in ['Steel | graphite powder coat','DC | rack cabinet black','DC | UPS charcoal']:return bpy.data.materials['P1 | PowderCoat']
 if n.startswith('Rubber | grip'):return bpy.data.materials['P1 | Rubber']
 if n in ['Metal | satin nickel','Nickel plated metal','DC | server bezel silver']:return mats['Metal']
 if n in ['Metal | anodised dark aluminium','DC | server bezel graphite']:return mats['DarkMetal']
 if n in ['Soft black PVC cable jacket','Electrical | cable rubber']:return mats['PVC']
 if n in ['Ivory ABS housing','Electrical | ivory plastic']:return mats['White']
 if n=='Pale blue mouse':return mats['Mouse']
 if n=='Mouse pale gray cable':return mats['CableGrey']
 if n=='Red rocker switch':return mats['Red']
 if n in ['Contacts | plated gold','Gold plated connector']:return mats['Gold']
 if n=='DC | rack perforated door':return mats['Perforated']
 if n=='DC | patch cable blue':return mats['BluePVC']
 if n=='DC | patch cable yellow':return mats['YellowPVC']
 return m

class Parts:
 """Low-cost joined decorative geometry, with true openings made from separate walls."""
 def __init__(self):self.v=[];self.f=[];self.mi=[];self.materials=[]
 def box(self,pos,size,mat):
  idx=len(self.v); x,y,z=pos; a,b,c=[v/2 for v in size]
  self.v += [(x+u*a,y+v*b,z+w*c) for u,v,w in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
  if mat not in self.materials:self.materials.append(mat)
  mi=self.materials.index(mat)
  for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.f.append(tuple(idx+i for i in face)); self.mi.append(mi)
 def socket(self,x,y,z,metal,gold,dark):
  # 8P8C socket: open mouth, metal rim, recessed liner, eight separate contacts.
  self.box((x-.0067,y,z),(.0014,.008,.014),metal); self.box((x+.0067,y,z),(.0014,.008,.014),metal)
  self.box((x,y,z+.0063),(.012,.008,.0014),metal)
  for s in (-1,1):self.box((x+s*.0046,y,z-.0063),(.003,.008,.0014),metal)
  self.box((x,y+.0035,z),(.012,.001,.012),dark)
  for i in range(8):self.box((x+(i-3.5)*.00102,y-.0008,z+.0045),(.0004,.006,.0004),gold)
 def finish(self,name,collection=None):
  me=bpy.data.meshes.new(name);me.from_pydata(self.v,[],self.f);me.update()
  for m in self.materials:me.materials.append(m)
  for p,i in zip(me.polygons,self.mi):p.material_index=i
  o=bpy.data.objects.new(name,me);(collection or bpy.context.scene.collection).objects.link(o);local_uv(o);return o
def rack_details(mats):
 collection=bpy.data.collections.new('P3 | Rack equipment details');bpy.context.scene.collection.children.link(collection)
 p=Parts();metal=mats['Metal'];gold=mats['Gold'];dark=bpy.data.materials['P1 | Polymer']
 z=.14
 for kind in ['2u','1u','1u','2u','sw','pp','2u','2u','1u','1u','2u','4u','2u','1u','1u','2u','sw','pp']:
  h={'1u':.044,'2u':.088,'4u':.176,'sw':.044,'pp':.044}[kind]
  if z+h>1.92:break
  for x in [-.245,.245]:
   p.box((x,-.564,z+h/2),(.004,.001,.004),metal)
   p.box((x,-.5648,z+h/2),(.0028,.0005,.0005),dark)
  if kind in ('sw','pp'):
   for i in range(12):p.socket(-.2+i*.032,-.572,z+h/2,metal,gold,dark)
  else:
   for i in range(4 if h>.05 else 3):
    x=-.17+i*.09
    p.box((x,-.570,z+h*.31),(.055,.003,.003),metal)
    for side in (-1,1):p.box((x+side*.026,-.570,z+h*.40),(.003,.003,h*.2),metal)
    for row in range(3):p.box((x,-.5688,z+h*(.50+row*.07)),(.048,.001,.0016),dark)
  z+=h+.004
 template=p.finish('P3_RackEquipment_Detail',collection);p1.add_bevel(template,.0002,2)
 racks=[o for o in bpy.context.scene.objects if re.fullmatch(r'DC_Rack_[AB]\d+',o.name)]
 for i,rack in enumerate(racks):
  o=template if i==0 else template.copy()
  if i:collection.objects.link(o)
  o.name='P3_Detail_'+rack.name; o.parent=rack;o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4)
 return [o.name for o in collection.objects]
def compare(before,after,changed):
 errors=[]
 for name,old in before.items():
  if name not in after:errors.append('missing '+name);continue
  for field in ['matrix','parent','geometry','properties','hidden']:
   if old[field]!=after[name][field]:errors.append(field+' '+name)
  if name not in changed and old['materials']!=after[name]['materials']:errors.append('outside material '+name)
 return errors
def build_map():
 bpy.ops.wm.open_mainfile(filepath=str(WORK));s=bpy.context.scene
 assert not s.get('phase3_revision') and not BACKUP.exists(),'Existing Phase 3 work; inspect before rebuilding'
 shutil.copy2(WORK,BACKUP); before=p2.snapshot();write('before_snapshot.json',before)
 mats=common(); changed=[];cache={}
 for o in list(s.objects):
  if not target(o):continue
  new=[replacement(m,mats) if m else None for m in o.data.materials]
  if list(o.data.materials)==new:continue
  key=(o.data.name,tuple(m.name if m else None for m in new),tuple(o.scale))
  if key in cache:o.data=cache[key]
  else:
   o.data=o.data.copy()
   for i,m in enumerate(new):o.data.materials[i]=m
   local_uv(o); cache[key]=o.data
  changed.append(o.name)
 added=rack_details(mats);bpy.context.view_layer.update()
 errors=compare(before,p2.snapshot(),set(changed)); assert not errors,errors[:10]
 s['phase3_revision']='Equipment surfaces and rack details 2026-10-16';s['phase3_changed_objects']=json.dumps(changed)
 bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)
 write('changes.json',{'changed_objects':changed,'unique_surface_meshes':len(cache),'new_detail_objects':added,'texture_files':PATHS,'backup':str(BACKUP)})
 print('P3_MAP_SAVED',len(changed),len(cache),len(added),flush=True)

def asset_material(m):
 n=m.name.lower()
 if any(x in n for x in ['led','ink','legend','marking','conductor','studio','_floor','plug | clear','plug edges']):return m
 if any(x in n for x in ['plastic','rubber','grip','steel','metal','housing','bezel','case |','base |','front |','feet','fasteners','boot |','jacket |','touch points','pcb |','recess','ports |','heat spreader','rj45 |','contacts']):
  p=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
  color=tuple(p.inputs['Base Color'].default_value[:3]) if p else tuple(m.diffuse_color[:3])
  metal=p.inputs['Metallic'].default_value if p else 0; rough=p.inputs['Roughness'].default_value if p else .5
  if 'gold' in n or 'contact' in n:return simple('Contact '+m.name,color,rough,metal)
  # Keep the original colours, finish and semantic parts; only add micro-surface maps.
  return surface(re.sub(r'[^A-Za-z0-9]+',' ',m.name).strip(),color,rough,metal,'metal' if metal>.5 else 'plastic')
 return m
def assets():
 reports={}
 folder=OUT/'assets';folder.mkdir(exist_ok=True)
 for key in ['tester','crimper','cat6','router','switch8','server']:
  source=ROOT/AUDIT[key]['path']; dest=folder/(key+'_lookdev.blend')
  assert not dest.exists(),str(dest)
  source_hash=p1.sha(source); bpy.ops.wm.open_mainfile(filepath=str(source));before=p2.snapshot()
  mapping={m.name:asset_material(m) for m in list(bpy.data.materials)};changed=[];cache={}
  for o in bpy.context.scene.objects:
   if o.type!='MESH' or o.hide_render or any(c.name.startswith(('STUDIO','MODULE')) for c in o.users_collection):continue
   new=[mapping.get(m.name,m) if m else None for m in o.data.materials]
   if new==list(o.data.materials):continue
   olddata=o.data.name
   if olddata in cache:o.data=cache[olddata]
   else:
    o.data=o.data.copy()
    for i,m in enumerate(new):o.data.materials[i]=m
    local_uv(o);cache[olddata]=o.data
   changed.append(o.name)
  errors=compare(before,p2.snapshot(),set(changed));assert not errors,errors
  for im in bpy.data.images:
   if im.source=='FILE' and im.has_data:im.pack()
  bpy.ops.wm.save_as_mainfile(filepath=str(dest),compress=True)
  reports[key]={'source':str(source),'source_sha256':source_hash,'output':str(dest),'objects':len(before),'changed':changed,'preserved_geometry_pivots_ports':True}
  write('asset_snapshots/'+key+'.json',before)
  print('P3_ASSET_SAVED',key,len(changed),flush=True)
 write('asset_changes.json',reports)

VIEWS={
 'student':((1.8,5.5,1.52),(.05,3.4,1.0),46),
 'computer_rear':((7.7,9.3,1.22),(7.1,8.1,1.05),52),
 'power':((5.55,8.62,.43),(6.55,8.08,.57),55),
 'server':((.9,40.65,1.55),(-.3,41.95,1.1),32),
}
def render_map(label,only=None):
 bpy.ops.wm.open_mainfile(filepath=str(BACKUP if label=='before' else WORK));s=bpy.context.scene;c=p1.configure_preview(s)
 s.render.resolution_x=1440;s.render.resolution_y=960;s.cycles.samples=24
 for name,(pos,aim,lens) in VIEWS.items():
  if only and name!=only:continue
  c.location=pos;c.rotation_euler=(Vector(aim)-c.location).to_track_quat('-Z','Y').to_euler();c.data.lens=lens;c.data.clip_start=.01
  lamps=[]
  for loc,energy,size in [(Vector(pos)+Vector((0,0,.8)),70,1.3),(Vector(aim)+Vector((1,-.5,1.2)),50,1)]:
   d=bpy.data.lights.new('P3 review light','AREA');d.energy=energy;d.shape='DISK';d.size=size
   lamp=bpy.data.objects.new('P3 review light',d);s.collection.objects.link(lamp);lamp.location=loc;lamp.rotation_euler=(Vector(aim)-loc).to_track_quat('-Z','Y').to_euler();lamps.append(lamp)
  folder=OUT/'renders';folder.mkdir(exist_ok=True);s.render.filepath=str(folder/f'{label}_{name}.png');bpy.ops.render.render(write_still=True)
  for o in lamps:bpy.data.objects.remove(o,do_unlink=True)
  print('P3_RENDERED',label,name,flush=True)
def export_map():
 p2.WORK=WORK;p2.OUT=OUT
 p2.export()
 path=OUT/'godot_preview/architecture.glb';path.rename(path.with_name('equipment_map.glb'))
def verify():
 bpy.ops.wm.open_mainfile(filepath=str(WORK));old=json.loads((OUT/'before_snapshot.json').read_text());new=p2.snapshot()
 changes=json.loads((OUT/'changes.json').read_text());errors=compare(old,new,set(changes['changed_objects']))
 for name in changes['changed_objects']:
  uv=bpy.data.objects[name].data.uv_layers.get('P3_SurfaceUV')
  if not uv or not uv.active_render:errors.append('UV '+name)
 files=json.loads((ROOT/'3Dmodel/lookdev/phase0/baseline.json').read_text(encoding='utf-8'))['file_hashes']
 for name,h in files.items():
  if p1.sha(ROOT/name)!=h:errors.append('source '+name)
 report={'passed':not errors,'original_objects_checked':len(old),'changed_objects':len(changes['changed_objects']),
 'shared_detail_instances':len(changes['new_detail_objects']),'screens_preserved':sum('Monitor_Display_Surface' in n for n in old),'source_files_checked':len(files),'errors':errors,
 'production_interactions_tested':False,'web_performance_tested':False}
 write('verification.json',report);print('P3_VERIFY',json.dumps(report),flush=True);assert not errors
if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:];mode=args[0]
 if mode=='map':build_map()
 elif mode=='assets':assets()
 elif mode in ('before','after'):render_map(mode,args[1] if len(args)>1 else None)
 elif mode=='export':export_map()
 elif mode=='verify':verify()
