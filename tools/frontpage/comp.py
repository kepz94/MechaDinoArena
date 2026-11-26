import math, numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
FONT='/tmp/claude-0/-home-claude/7c8a0c48-2bce-579f-a00a-b76a8f986b09/scratchpad/edit/fonts/Silkscreen-700.ttf'
def burst(W,H,c0,c1,ray,cx=0.5,cy=0.5,n=18,ray_a=60,vig=0.55):
    y,x=np.mgrid[0:H,0:W].astype(np.float32); X=(x-cx*W)/max(W,H); Y=(y-cy*H)/max(W,H)
    d=np.sqrt(X*X+Y*Y); t=np.clip(d/0.75,0,1)[...,None]
    img=np.array(c0,np.float32)*(1-t)+np.array(c1,np.float32)*t
    ang=np.arctan2(Y,X); r=(np.sin(ang*n)>0.55).astype(np.float32)*np.clip(d*2.2,0,1)
    img=img*(1-r[...,None]*ray_a/255)+np.array(ray,np.float32)*(r[...,None]*ray_a/255)
    img*=(1-vig*np.clip(d-0.35,0,1)[...,None]*1.6)
    return Image.fromarray(np.clip(img,0,255).astype(np.uint8)).convert('RGBA')
def bbox(im): return im.getchannel('A').point(lambda v:255 if v>40 else 0).getbbox()
def outlined(cut,w1=10,c1=(255,255,255),w2=5,c2=(12,12,20),glow=None):
    A=cut.getchannel('A')
    def ring(w,c):
        a=A.filter(ImageFilter.MaxFilter(w*2+1)) if w>0 else A
        l=Image.new('RGBA',cut.size,c+(0,)); l.putalpha(a); return l
    out=Image.new('RGBA',cut.size,(0,0,0,0))
    if glow:
        g=ring(w1+w2+6,glow); g=g.filter(ImageFilter.GaussianBlur(18)); out=Image.alpha_composite(out,g); out=Image.alpha_composite(out,g)
    out=Image.alpha_composite(out,ring(w1+w2,c2)); out=Image.alpha_composite(out,ring(w1,c1)); out=Image.alpha_composite(out,cut); return out
def place(canvas,layer,box_w,cx,cy,anchor='c'):
    s=box_w/layer.size[0]; L=layer.resize((int(layer.size[0]*s),int(layer.size[1]*s)),Image.LANCZOS)
    x=int(cx-L.size[0]/2); y=int(cy-L.size[1]/2) if anchor=='c' else int(cy-L.size[1])
    canvas.alpha_composite(L,(max(x,-10**6),y)) if x>=0 and y>=0 else canvas.paste(L,(x,y),L)
    return canvas
def crop_sub(cut,pad=40):
    b=bbox(cut); return cut.crop((max(0,b[0]-pad),max(0,b[1]-pad),min(cut.size[0],b[2]+pad),min(cut.size[1],b[3]+pad)))
def text3d(txt,size,fill_top=(255,232,120),fill_bot=(255,160,20),stroke=14,depth=12):
    f=ImageFont.truetype(FONT,size); tmp=ImageDraw.Draw(Image.new('L',(1,1))); b=tmp.textbbox((0,0),txt,font=f,stroke_width=stroke)
    W=b[2]-b[0]+depth+stroke*2; H=b[3]-b[1]+depth+stroke*2; ox=-b[0]+stroke; oy=-b[1]+stroke
    im=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im)
    for k in range(depth,0,-1): d.text((ox+k*0.35,oy+k),txt,font=f,fill=(60,20,10,255),stroke_width=stroke,stroke_fill=(20,8,4,255))
    d.text((ox,oy),txt,font=f,fill=(255,255,255,255),stroke_width=stroke,stroke_fill=(15,10,20,255))
    mask=Image.new('L',(W,H),0); ImageDraw.Draw(mask).text((ox,oy),txt,font=f,fill=255)
    grad=Image.new('RGBA',(W,H)); gd=ImageDraw.Draw(grad)
    for y in range(H): t=y/H; gd.line([(0,y),(W,y)],fill=tuple(int(fill_top[i]*(1-t)+fill_bot[i]*t) for i in range(3))+(255,))
    im.paste(grad,(0,0),mask)
    sh=im.getchannel('A').filter(ImageFilter.GaussianBlur(10)); s=Image.new('RGBA',(W+30,H+30),(0,0,0,0)); sl=Image.new('RGBA',(W,H),(0,0,0,150)); sl.putalpha(sh.point(lambda v:v*0.6)); s.alpha_composite(sl,(14,18)); s.alpha_composite(im,(0,0))
    return s
