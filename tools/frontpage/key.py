import sys, numpy as np
from PIL import Image, ImageFilter
def key(path):
    im=np.asarray(Image.open(path).convert('RGB')).astype(np.float32)/255
    r,g,b=im[...,0],im[...,1],im[...,2]
    mx=im.max(-1); mn=im.min(-1); sat=(mx-mn)/(mx+1e-6)
    # magenta-ness: r and b both above g
    m=np.minimum(r,b)-g
    a=1-np.clip((m-0.06)/0.14,0,1)            # 0 = backdrop
    a=np.where(sat<0.25,1,a)                   # keep greys/whites
    # despill: pull r,b down to max(g, other) where magenta cast
    lim=np.maximum(g, np.minimum(r,b)*0) 
    spill=np.clip(np.minimum(r,b)-g,0,None)
    r2=r-spill*0.85; b2=b-spill*0.85
    out=np.stack([r2,g,b2],-1)
    A=Image.fromarray((a*255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    img=Image.fromarray((np.clip(out,0,1)*255).astype(np.uint8)).convert('RGBA'); img.putalpha(A)
    # remove top-left Roblox buttons area
    px=img.load()
    for y in range(0,70):
        for x in range(0,200): px[x,y]=(0,0,0,0)
    return img
if __name__=='__main__':
    for p in sys.argv[1:]:
        out=p.rsplit('/',1); key(p).save(out[0]+'/cut/'+out[1])
