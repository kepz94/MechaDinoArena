import numpy as np, wave, os, json
SR=22050
rng=np.random.default_rng(7)
def t(d): return np.arange(int(SR*d))/SR
def env(n, a=0.004, r=0.03):
    e=np.ones(n); na=max(1,int(SR*a)); nr=max(1,int(SR*r))
    e[:na]=np.linspace(0,1,na); e[-nr:]*=np.linspace(1,0,nr); return e
def sq(f,d,duty=0.5,vol=0.5,a=0.003,r=0.02):
    tt=t(d); f=np.broadcast_to(f,tt.shape) if np.ndim(f) else np.full(tt.shape,f)
    ph=np.cumsum(f)/SR; w=np.where((ph%1)<duty,1.0,-1.0); return w*vol*env(len(tt),a,r)
def tri(f,d,vol=0.5,a=0.003,r=0.02):
    tt=t(d); f=np.full(tt.shape,f) if not np.ndim(f) else f
    ph=np.cumsum(f)/SR; w=2*np.abs(2*(ph%1)-1)-1; return w*vol*env(len(tt),a,r)
def noise(d,vol=0.4,a=0.001,r=0.02,step=1):
    n=int(SR*d); v=rng.uniform(-1,1,n//step+1).repeat(step)[:n]; return v*vol*env(n,a,r)
def sweep(f0,f1,d,kind='sq',**k):
    f=np.linspace(f0,f1,int(SR*d)); return (sq if kind=='sq' else tri)(f,d,**k)
def cat(*xs): return np.concatenate(xs)
def rest(d): return np.zeros(int(SR*d))
def mix(*xs):
    n=max(len(x) for x in xs); o=np.zeros(n)
    for x in xs: o[:len(x)]+=x
    return o
N=lambda s: 440*2**((s-69)/12)  # midi
C5,E5,G5,C6,D6,E6,G6,A5,B5,F5,C7,E7,G4,C4=72,76,79,84,86,88,91,81,83,77,96,100,67,60
def notes(seq,dur,kind='sq',gap=0.0,**k):
    out=[]
    for n in seq:
        out.append((sq if kind=='sq' else tri)(N(n),dur,**k)); 
        if gap: out.append(rest(gap))
    return cat(*out)
S={}
# hit confirm (yours)
S['hit']=[sq(1320,0.045,duty=0.25,vol=0.45,r=0.03),
          cat(sq(1046,0.03,duty=0.25,vol=0.4,r=0.01),sq(1568,0.04,duty=0.25,vol=0.4)),
          mix(noise(0.025,0.35,step=3),sq(1760,0.05,duty=0.125,vol=0.3))]
# kill confirm
S['kill']=[notes([C6,E6,G6,C7],0.055,duty=0.25,vol=0.4,r=0.015),
           cat(sq(N(B5),0.07,duty=0.5,vol=0.4,r=0.01),sq(N(E6),0.28,duty=0.5,vol=0.4,r=0.2)),
           cat(sweep(2200,700,0.09,duty=0.25,vol=0.35),mix(sq(N(C6),0.25,0.25,0.25,r=0.18),sq(N(E6),0.25,0.25,0.2,r=0.18),sq(N(G6),0.25,0.25,0.2,r=0.18)))]
# point captured (your team)
S['captured']=[cat(notes([C5,E5,G5],0.08,vol=0.35,r=0.01),sq(N(C6),0.35,vol=0.35,r=0.25)),
               sweep(300,1800,0.35,duty=0.25,vol=0.3,r=0.08),
               cat(sq(N(G5),0.09,vol=0.35),rest(0.03),sq(N(G5),0.09,vol=0.35),rest(0.03),sq(N(C6),0.4,vol=0.38,r=0.3))]
# point lost (enemy took it)
S['lost']=[cat(sq(N(E5),0.14,vol=0.35,r=0.02),sq(N(C5)-0,0.3,vol=0.35,r=0.2)),
           sq(150,0.45,duty=0.5,vol=0.3,r=0.1),
           sweep(1200,200,0.4,duty=0.5,vol=0.3,r=0.1)]
# contested
S['contested']=[cat(*[sq(f,0.07,vol=0.3,r=0.01) for f in [880,660,880,660]]),
                cat(*[cat(sq(1000,0.04,duty=0.125,vol=0.3,r=0.01),rest(0.04)) for _ in range(4)]),
                mix(sq(700,0.3,vol=0.25,r=0.1),sq(740,0.3,vol=0.25,r=0.1))]
# point moving soon
S['moving']=[cat(*[cat(sq(N(n),0.09,duty=0.25,vol=0.35,r=0.02),rest(0.05)) for n in [C6,E6,G6]]),
             cat(sweep(600,1200,0.25,duty=0.5,vol=0.3,r=0.02),sweep(1200,600,0.25,duty=0.5,vol=0.3)),
             cat(tri(N(G6),0.18,vol=0.5,r=0.08),tri(N(C6),0.3,vol=0.5,r=0.2))]
# countdown tick (3,2,1)
S['tick']=[sq(880,0.08,duty=0.5,vol=0.35,r=0.03),
           mix(noise(0.03,0.4,step=6),tri(1200,0.04,vol=0.3)),
           tri(660,0.1,vol=0.6,r=0.05)]
# GO
S['go']=[sq(1760,0.45,duty=0.5,vol=0.35,r=0.15),
         mix(sq(N(C6),0.4,0.25,0.25,r=0.25),sq(N(E6),0.4,0.25,0.22,r=0.25),sq(N(G6),0.4,0.25,0.22,r=0.25),noise(0.06,0.3,step=2)),
         sweep(400,2400,0.3,duty=0.25,vol=0.3,r=0.08)]
# UI click
S['click']=[sq(2000,0.02,duty=0.25,vol=0.3,r=0.012),
            tri(1000,0.03,vol=0.5,r=0.02),
            noise(0.015,0.35,step=4,r=0.01)]
# win jingle
S['win']=[cat(notes([C5,E5,G5,C6],0.09,vol=0.3,r=0.01),rest(0.05),notes([G5],0.09,vol=0.3),sq(N(C6),0.5,vol=0.32,r=0.35)),
          cat(notes([G5,G5],0.08,gap=0.03,vol=0.3),sq(N(C6),0.12,vol=0.3),sq(N(E6),0.12,vol=0.3),sq(N(G6),0.45,vol=0.32,r=0.3)),
          cat(notes([C5,E5,G5,C6,E6,G6],0.06,duty=0.25,vol=0.28,r=0.01),*[sq(N(n),0.05,duty=0.25,vol=0.28) for n in [C7,G6]*3],sq(N(C7),0.3,duty=0.25,vol=0.3,r=0.25))]
# lose jingle
S['lose']=[cat(sq(N(G5),0.25,vol=0.3,r=0.03),sq(N(F5+1),0.25,vol=0.3,r=0.03),sq(N(F5),0.25,vol=0.3,r=0.03),sweep(N(E5),N(E5)*0.94,0.6,vol=0.3,r=0.3)),
           cat(notes([C6,A5,F5,D6-12],0.12,vol=0.3,r=0.02),sq(N(C5),0.4,vol=0.3,r=0.3)),
           sq(110,0.8,duty=0.5,vol=0.25,r=0.4)]
meta={}
os.makedirs('wav',exist_ok=True)
for k,vs in S.items():
    for i,x in enumerate(vs):
        x=np.clip(x,-1,1); pcm=(x*32000).astype('<i2')
        fn=f'wav/{k}_{"ABC"[i]}.wav'
        with wave.open(fn,'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
        meta[f'{k}_{"ABC"[i]}']=round(len(x)/SR,2)
json.dump(meta,open('meta.json','w'),indent=0)
print(meta)
