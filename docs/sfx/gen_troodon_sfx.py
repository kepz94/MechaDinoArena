import numpy as np, wave, json
from scipy import signal
SR=44100
rng=np.random.default_rng(11)
def t(d): return np.arange(int(SR*d))/SR
def expenv(d,tau): return np.exp(-t(d)/tau)
def lp(x,fc,o=4): b,a=signal.butter(o,fc/(SR/2),'low'); return signal.lfilter(b,a,x)
def hp(x,fc,o=2): b,a=signal.butter(o,fc/(SR/2),'high'); return signal.lfilter(b,a,x)
def bp(x,f1,f2,o=2): b,a=signal.butter(o,[f1/(SR/2),f2/(SR/2)],'band'); return signal.lfilter(b,a,x)
def noise(d): return rng.uniform(-1,1,int(SR*d))
def sine_sweep(f0,f1,d,curve=3):
    tt=t(d); f=f1+(f0-f1)*np.exp(-tt*curve/d*3) ; ph=2*np.pi*np.cumsum(f)/SR; return np.sin(ph)
def saw_sweep(f0,f1,d):
    f=np.geomspace(f0,f1,int(SR*d)); ph=np.cumsum(f)/SR; return 2*(ph%1)-1
def pad(x,d): n=int(SR*d); return np.concatenate([x,np.zeros(max(0,n-len(x)))])[:n]
def mix(*xs):
    n=max(len(x) for x in xs); o=np.zeros(n)
    for x in xs: o[:len(x)]+=x
    return o
def norm(x,peak=0.9):
    x=x-np.mean(x); m=np.max(np.abs(x)) or 1; x=x/m*peak
    f=int(SR*0.004); x[-f:]*=np.linspace(1,0,f); return x
def sat(x,k=2.0): return np.tanh(k*x)/np.tanh(k)
S={}
# GETTING HIT
# A: heavy body thud (creature hit)
d=0.35
A=mix(sine_sweep(140,48,d)*expenv(d,0.09)*1.0, lp(noise(d),900)*expenv(d,0.03)*0.9, bp(noise(d),1500,4000)*expenv(d,0.008)*0.5)
rng=np.random.default_rng(23)
def fsweep(f0,f1,d,geo=True):
    f=np.geomspace(f0,f1,int(SR*d)) if geo else np.linspace(f0,f1,int(SR*d)); return np.sin(2*np.pi*np.cumsum(f)/SR)
def fade(x,a=0.01,r=0.05):
    n=len(x); e=np.ones(n); ai=int(SR*a); ri=int(SR*r)
    if ai: e[:ai]=np.linspace(0,1,ai)
    if ri: e[-ri:]*=np.linspace(1,0,ri)
    return x*e
def at(x,sec,d): return np.roll(pad(x,d),int(SR*sec))
def chorus(f,d,n=4,spread=0.012):
    return sum(np.sin(2*np.pi*f*(1+spread*(i-(n-1)/2))*t(d)+rng.uniform(0,6)) for i in range(n))/n
S={}
def pfft(d0=0.06,lo=600,hi=5000): return bp(noise(d0),lo,hi)*expenv(d0,0.015)
def thump(f0=120,f1=45,d0=0.25,tau=0.07): return sine_sweep(f0,f1,d0)*expenv(d0,tau)
def click(d0=0.02,fc=1500): return hp(noise(d0),fc)*expenv(d0,d0/5)
def whoosh(d0=0.3,lo=500,hi=3000,a=0.6): return bp(noise(d0),lo,hi)*np.sin(np.pi*t(d0)/d0)**2*a
def chime(fs,d0=0.6,tau=0.18): return sum(np.sin(2*np.pi*f*t(d0))*a for f,a in fs)*expenv(d0,tau)
def arp(notes,step,d0,tau=0.12,dd=None):
    return mix(*[at(np.sin(2*np.pi*f*t(0.4))*expenv(0.4,tau),i*step,d0) for i,f in enumerate(notes)])
# BLOOM BURST
d=1.0
BA=mix(pad(whoosh(0.25),d), at(chime([(1175,0.5),(1760,0.3),(2350,0.2)],0.7,0.2),0.25,d)*0.6)
BB=mix(pad(mix(thump(300,150,0.06,0.02),click(0.02,2000)*0.5),d)*0.6, arp([880,1109,1319,1760],0.07,d)*0.45)
BC=mix(pad(bp(noise(0.3),2000,7000)*(0.5+0.5*np.sign(np.sin(2*np.pi*40*t(0.3))))*np.sin(np.pi*t(0.3)/0.3)*0.4,d), at(chorus(523,0.7,5,0.01)*np.sin(np.pi*t(0.7)/0.7)*0.5,0.2,d))
S['oburst']=[fade(BA,0.002),fade(BB,0.002),fade(BC,0.002)]
# SHIELD DOME
d=1.1
DA=mix(pad(mix(click(0.03,1500),thump(250,120,0.08,0.02)*0.6),d)*0.7, at(chorus(180,0.8,4,0.02)*np.minimum(1,t(0.8)/0.2)*expenv(0.8,0.4)*0.6,0.2,d), at(fsweep(200,700,0.5)*np.linspace(0.3,0,int(SR*0.5)),0.2,d))
DB=mix(pad(whoosh(0.25,400,2500,0.5),d), at(sat(fsweep(60,160,0.6)*np.minimum(1,t(0.6)/0.05)*expenv(0.6,0.25)*1.5,2)*0.7,0.25,d))
DC=mix(pad(np.sin(2*np.pi*2200*t(0.3))*expenv(0.3,0.06)*0.5,d), at(chorus(440,0.8,6,0.015)*np.sin(np.pi*t(0.8)/0.8)*0.5,0.1,d))
S['odome']=[fade(DA,0.002),fade(DB,0.002),fade(DC,0.002)]
# ARC LANTERN
d=1.0
zap=lambda d0: bp(noise(d0),1500,8000)*(rng.uniform(0,1,int(SR*d0))>0.9)*expenv(d0,d0/3)*3
LA=mix(pad(whoosh(0.25),d), at(mix(zap(0.3)*0.5,lp(np.sign(np.sin(2*np.pi*120*t(0.3))),3000)*expenv(0.3,0.08)*0.4),0.3,d))
LB=mix(pad(chorus(240,0.3,3,0.02)*0.3,d), at(zap(0.15)*0.6,0.3,d), at(zap(0.15)*0.5,0.5,d))
LC=mix(pad(whoosh(0.2,800,4000,0.4),d), at(lp(np.sign(np.sin(2*np.pi*(80+40*np.sin(2*np.pi*12*t(0.5)))*t(0.5))),4000)*expenv(0.5,0.2)*0.5,0.2,d), at(zap(0.4)*0.3,0.2,d))
S['olantern']=[fade(LA,0.002),fade(LB,0.002),fade(LC,0.002)]
# MENDER DRONE
d=1.1
wr=lambda d0,f0,f1: lp(np.sign(np.sin(2*np.pi*np.cumsum(np.geomspace(f0,f1,int(SR*d0)))/SR)),2000)
MA=mix(pad(wr(0.6,80,320)*np.minimum(1,t(0.6)/0.1)*np.linspace(1,0.3,int(SR*0.6))*0.3,d), at(chime([(1047,0.5),(1568,0.3)],0.6,0.18),0.45,d)*0.5)
MB=mix(lp(noise(d),3000)*(0.5+0.5*np.sign(np.sin(2*np.pi*45*t(d))))*np.sin(np.pi*t(d)/d)*0.35, chorus(160,d,3,0.03)*np.sin(np.pi*t(d)/d)*0.3)
MC=mix(pad(np.sin(2*np.pi*1200*t(0.08))*0.4,d), at(np.sin(2*np.pi*1800*t(0.08))*0.4,0.1,d), at(wr(0.6,100,250)*np.linspace(0.3,0,int(SR*0.6)),0.2,d))
S['omender']=[fade(MA,0.002),fade(MB,0.02),fade(MC,0.002)]
# PORTAL FEATHERS
d=1.1
PA=mix(pad(whoosh(0.3,600,4000),d), at(whoosh(0.3,600,4000,0.5),0.25,d), at(fsweep(300,900,0.5)*np.sin(np.pi*t(0.5)/0.5)*0.3,0.4,d))
PB=mix(chorus(660,d,6,0.02)*np.sin(np.pi*t(d)/d)*0.4, fsweep(400,2000,d)*np.sin(np.pi*t(d)/d)*0.2, bp(noise(d),3000,9000)*np.sin(np.pi*t(d)/d)*0.2)
PC=mix(sat(fsweep(200,50,0.6)*expenv(0.6,0.2)*1.5,2)*0.6, at(arp([1568,2093,2637],0.05,0.6,0.1),0.15,d)*0.35)
S['oportal']=[fade(PA,0.002),fade(PB,0.02),fade(PC,0.002)]
# SAP WALL
d=1.0
glp=lambda d0,f0,f1: np.sin(2*np.pi*np.cumsum(np.geomspace(f0,f1,int(SR*d0)))/SR)*expenv(d0,d0/3)
WA=mix(pad(whoosh(0.25,400,2500,0.5),d), at(mix(lp(noise(0.25),900)*expenv(0.25,0.06)*0.8,glp(0.2,500,150)*0.5),0.3,d))
WB=mix(pad(glp(0.3,120,400)*0.7,d), at(lp(noise(0.3),700)*expenv(0.3,0.1)*0.6,0.05,d), at(bp(noise(0.3),2000,6000)*(rng.uniform(0,1,int(SR*0.3))>0.95)*2*expenv(0.3,0.1),0.35,d)*0.4)
WC=mix(pad(whoosh(0.3,500,3000,0.5),d), at(mix(thump(140,60,0.15,0.04)*0.6,lp(noise(0.3),1200)*expenv(0.3,0.05)*0.8),0.3,d))
S['osapwall']=[fade(WA,0.002),fade(WB,0.002),fade(WC,0.002)]
# SENTRY POD
d=1.1
NA=mix(pad(whoosh(0.2),d), *[at(mix(click(0.02,2000)*0.5,thump(400,200,0.05,0.015)*0.3),0.3+i*0.08,d) for i in range(5)])
NB=mix(pad(wr(0.4,200,600)*np.linspace(0.4,0.1,int(SR*0.4)),d), at(np.sin(2*np.pi*1500*t(0.08))*0.4,0.5,d), at(np.sin(2*np.pi*2000*t(0.12))*0.4,0.62,d))
NC=mix(pad(mix(click(0.04,1000),thump(200,90,0.1,0.03)),d)*0.7, at(wr(0.6,60,500)*np.linspace(0.2,0.4,int(SR*0.6)),0.15,d))
S['osentry']=[fade(NA,0.002),fade(NB,0.002),fade(NC,0.02)]
# FEATHER SHED
d=0.9
SA=mix(*[at(bp(noise(0.12),1500,6000)*expenv(0.12,0.03)*0.5,i*0.025+rng.uniform(0,0.01),d) for i in range(14)], pad(thump(200,80,0.12,0.03)*0.5,d))
SB=mix(pad(hp(noise(0.03),1500)*expenv(0.03,0.006),d), at(lp(noise(0.5),2500)*expenv(0.5,0.12)*0.6,0.02,d))
SC=mix(pad(bp(noise(0.4),1000,5000)*np.minimum(1,t(0.4)/0.01)*expenv(0.4,0.1)*0.7,d), at(chime([(1319,0.5),(1976,0.3)],0.5,0.12),0.1,d)*0.4)
S['oshed']=[fade(SA,0.001),fade(SB,0.001),fade(SC,0.001)]
# SLEEP DART
d=0.9
ZA=mix(pad(bp(noise(0.08),600,4000)*expenv(0.08,0.02),d), pad(fsweep(1500,700,0.15)*expenv(0.15,0.05)*0.3,d))
ZB=mix(pad(fsweep(1200,400,0.12)*expenv(0.12,0.04)*0.5,d), at(arp([784,659,523],0.1,0.7,0.15),0.1,d)*0.4)
ZC=mix(pad(click(0.02,1500)*0.6,d), at(fsweep(2600,1800,0.5)*np.sin(np.pi*t(0.5)/0.5)*0.3,0.02,d))
S['osleep']=[fade(ZA,0.001),fade(ZB,0.001),fade(ZC,0.001)]
import subprocess
meta={}
for k,vs in S.items():
    for i,x in enumerate(vs):
        x=norm(x); pcm=(x*32000).astype('<i2'); fn=f'wav/{k}_{"ABC"[i]}.wav'
        with wave.open(fn,'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg','-y','-loglevel','error','-i',fn,'-b:a','96k',fn[:-4]+'.mp3'],check=True)
        meta[f'{k}_{"ABC"[i]}']=round(len(x)/SR,2)
print(meta); json.dump(meta,open('meta6.json','w'))
