import sys; sys.path.insert(0,'.')
from comp import *
import numpy as np, scipy.ndimage as nd
W,H=1920,1080
def clean(p,keep=2,pad=70,minfrac=0.02):
    c=Image.open(p).copy(); w,h=c.size; c.paste((0,0,0,0),(0,0,int(w*0.16),int(h*0.10)))
    arr=np.asarray(c).astype(np.float32); a=arr[...,3]
    m=a>40; lab,n=nd.label(nd.binary_dilation(m,iterations=2)); sizes=nd.sum(m,lab,range(1,n+1))
    ids=[i+1 for i in np.argsort(sizes)[::-1][:keep] if sizes[i]>m.sum()*minfrac]
    arr[...,3]=np.where(np.isin(lab,ids),a,0)
    im=Image.fromarray(arr.astype(np.uint8)); b=im.getchannel('A').point(lambda v:255 if v>40 else 0).getbbox(); im=im.crop(b)
    out=Image.new('RGBA',(im.size[0]+pad*2,im.size[1]+pad*2),(0,0,0,0)); out.paste(im,(pad,pad)); return out
def build(src,out,width=1700,cx=980,bottom=1120):
    bg=burst(W,H,(80,190,255),(10,20,80),(160,230,255),cx=0.30,cy=0.58,n=24)
    lay=outlined(clean(src),w1=8,w2=6,glow=(120,230,255))
    s=width/lay.size[0]; L=lay.resize((int(lay.size[0]*s),int(lay.size[1]*s)),Image.LANCZOS)
    if L.size[1]>900: s2=900/L.size[1]; L=L.resize((int(L.size[0]*s2),900),Image.LANCZOS)
    bg.paste(L,(int(cx-L.size[0]/2),int(bottom-L.size[1])),L)
    tx=text3d('MECHA BATTLES',150); bg.alpha_composite(tx,((W-tx.size[0])//2,40)); bg.convert('RGB').save(out,quality=95); return bg
if __name__=='__main__':
    ims=[]
    for t in ['3.483','3.50','17.55']: ims.append(build('h/cut/s3_%s.png'%t,'final/t3b_%s.jpg'%t).convert('RGB').resize((640,360)))
    o=Image.new('RGB',(640*3,360))
    for i,im in enumerate(ims): o.paste(im,(i*640,0))
    o.save('t3opts.jpg')
