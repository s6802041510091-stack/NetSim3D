"""Original deterministic PBR textures, generated in Blender with NumPy.
No photographs, downloaded textures, or baked lighting are used.
"""
import bpy
import numpy as np
from pathlib import Path

def noise(n, sx, sy, seed):
    rng=np.random.default_rng(seed)
    a=rng.standard_normal((n,n))
    fx=np.fft.rfftfreq(n)[None,:]; fy=np.fft.fftfreq(n)[:,None]
    a=np.fft.irfft2(np.fft.rfft2(a)*np.exp(-2*np.pi**2*((fx*sx)**2+(fy*sy)**2)),s=(n,n))
    return a/(a.std()+1e-8)

def save_image(path, rgb, data=False):
    h,w=rgb.shape[:2]
    im=bpy.data.images.new(path.stem,width=w,height=h,alpha=True,float_buffer=False)
    if data: im.colorspace_settings.name='Non-Color'
    rgba=np.ones((h,w,4),dtype=np.float32)
    rgba[:,:,:3]=np.clip(rgb if rgb.ndim==3 else rgb[:,:,None],0,1)
    im.pixels.foreach_set(rgba.ravel()); im.filepath_raw=str(path); im.file_format='PNG'; im.save()
    bpy.data.images.remove(im)

def maps(folder, name, color, rough, height, strength=1):
    # Height is dimensionless detail; gradients become tangent-space normal data.
    dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.5*strength
    dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.5*strength
    normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=2)
    normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    n=height.shape[0]
    paths={}
    for channel,value,data in [('BaseColor',color,False),('Roughness',rough,True),('Normal',normal*.5+.5,True)]:
        path=folder/f'T_{name}_{channel}_{n}.png'; save_image(path,value,data); paths[channel]=path
    return paths

def generate(folder):
    folder=Path(folder); folder.mkdir(parents=True,exist_ok=True)
    results={}; n=1024
    y,x=np.mgrid[0:n,0:n]/n
    broad=noise(n,35,140,10); fine=noise(n,.65,35,11); mid=noise(n,2,95,12)
    phase=2*np.pi*(x*69+.26*np.sin(y*2*np.pi)+.12*noise(n,28,65,15))
    grain=.5+.5*np.sin(phase+.6*np.sin(phase*.37))
    pores=np.maximum(0,-fine-1.3)
    value=.045*broad+.025*mid+.026*(grain-.5)-.023*pores
    wood=np.stack((.57+value,.40+value*.77,.235+value*.5),axis=2)
    results['Oak']=maps(folder,'Oak',wood,.43+.045*mid+.025*grain, .20*fine+.10*grain, .75)
    n=512; y,x=np.mgrid[0:n,0:n]/n
    coarse=noise(n,7,7,20); micro=noise(n,.7,.7,21)
    for key,base,r,amp in [('Paint',(.77,.76,.72),.84,.008),('CoatedWhite',(.78,.79,.78),.43,.005),
                           ('Polymer',(.047,.055,.064),.52,.004),('PowderCoat',(.065,.075,.087),.48,.004),
                           ('Rubber',(.025,.029,.034),.78,.003),('Binder',(.055,.065,.079),.72,.005)]:
        a=amp*(micro*.5+coarse*.3)
        rgb=np.stack([v+a for v in base],axis=2)
        results[key]=maps(folder,key,rgb,r+.025*micro+.018*coarse,micro, .08 if key=='Paint' else .12)
    weave=(np.sin(x*2*np.pi*128)*np.sin(y*2*np.pi*128))
    weave2=np.cos(x*2*np.pi*64)*np.cos(y*2*np.pi*64)
    rgb=np.stack([v+(.007*weave+.003*micro) for v in (.085,.125,.17)],axis=2)
    results['Fabric']=maps(folder,'FabricNavy',rgb,.85+.04*weave, .12*weave+.06*weave2,.9)
    # Single 600 mm tile with a narrow grout joint; repeats without image seams.
    n=1024; y,x=np.mgrid[0:n,0:n]/n
    dist=np.minimum.reduce([x,1-x,y,1-y]); grout=dist<.0035
    edge=np.clip((dist-.0035)/.003,0,1)
    stone=noise(n,25,25,45)*.009+noise(n,2,2,46)*.003
    rgb=np.stack([v+stone for v in (.58,.585,.57)],axis=2)
    rgb=rgb*edge[:,:,None]+np.array([.30,.31,.30])[None,None,:]*(1-edge[:,:,None])
    results['Tile']=maps(folder,'Porcelain600',rgb,.38+.05*noise(n,12,12,47)+grout*.35,edge*.35+stone*.08,1.5)
    return results
