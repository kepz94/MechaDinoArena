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
glp=lambda d0,f0,f1: np.sin(2*np.pi*np.cumsum(np.geomspace(f0,f1,int(SR*d0)))/SR)*expenv(d0,d0/3)
wr=lambda d0,f0,f1: lp(np.sign(np.sin(2*np.pi*np.cumsum(np.geomspace(f0,f1,int(SR*d0)))/SR)),2000)
# GRAPPLING HOOK (claw fires)
d=0.9
chain=lambda d0: mix(*[at(np.sin(2*np.pi*(2800+200*(i%3))*t(0.05))*expenv(0.05,0.01)*0.3,i*0.04,d0) for i in range(int(d0/0.04)-2)])
HA=mix(pad(mix(thump(200,90,0.12,0.03),click(0.03,1500)),d)*0.7, at(chain(0.5),0.05,d), at(whoosh(0.4,800,4000,0.4),0.05,d))
HB=mix(pad(lp(noise(0.15),3000)*expenv(0.15,0.04)*0.8,d), at(fsweep(1800,600,0.5)*expenv(0.5,0.15)*0.3,0.03,d), at(click(0.03,2500)*0.5,0.03,d))
HC=mix(pad(wr(0.25,300,900)*np.linspace(0.3,0.1,int(SR*0.25)),d), at(mix(thump(250,100,0.1,0.03),hp(noise(0.03),2000)*expenv(0.03,0.006)),0.25,d)*0.8, at(chain(0.4),0.3,d))
S['hookarm']=[fade(HA,0.001),fade(HB,0.001),fade(HC,0.002)]
# INK SHOOTER (glob fired)
d=0.8
IA=mix(pad(sat(thump(120,50,0.25,0.07)*1.4,2),d), at(lp(noise(0.3),900)*(0.5+0.5*np.sin(2*np.pi*20*t(0.3)))*expenv(0.3,0.1)*0.7,0.02,d))
IB=mix(pad(fsweep(700,150,0.15)*expenv(0.15,0.05)*0.6,d), pad(bp(noise(0.25),400,2500)*expenv(0.25,0.06)*0.7,d))
IC=mix(pad(mix(hp(noise(0.04),1200)*expenv(0.04,0.01),thump(180,70,0.12,0.03)*0.6),d), at(glp(0.4,400,120)*0.5,0.05,d), at(lp(noise(0.3),1200)*expenv(0.3,0.08)*0.4,0.05,d))
S['ink']=[fade(IA,0.001),fade(IB,0.001),fade(IC,0.001)]
# MED-STATION (machine dropped)
d=1.2
MA=mix(pad(mix(thump(140,60,0.2,0.05),click(0.04,1200)*0.7),d), at(wr(0.5,120,400)*np.linspace(0.3,0.05,int(SR*0.5)),0.15,d), at(chime([(988,0.5),(1319,0.35),(1976,0.2)],0.6,0.2),0.55,d)*0.5)
MB=mix(pad(thump(110,45,0.3,0.08),d)*0.9, at(np.sin(2*np.pi*1400*t(0.1))*0.35,0.35,d), at(np.sin(2*np.pi*1400*t(0.1))*0.35,0.55,d), at(chorus(330,0.6,4,0.02)*np.sin(np.pi*t(0.6)/0.6)*0.35,0.6,d))
MC=mix(pad(mix(click(0.03,1500),thump(220,100,0.1,0.03)*0.6),d), at(bp(noise(0.4),2000,8000)*expenv(0.4,0.12)*0.4,0.1,d), at(arp([659,880,1109,1319],0.08,0.7,0.12),0.35,d)*0.4)
S['medstation']=[fade(MA,0.001),fade(MB,0.001),fade(MC,0.001)]
# OVERCLOCKED SERVO DASH (hip thrusters launch)
d=1.0
SA=mix(pad(sat(thump(130,50,0.25,0.07)*1.5,2),d), lp(noise(d),2500)*np.minimum(1,t(d)/0.02)*expenv(d,0.25)*0.6, wr(d,200,900)*expenv(d,0.4)*0.2)
SB=mix(pad(hp(noise(0.05),1200)*expenv(0.05,0.012),d)*0.8, at(bp(noise(0.8),600,4000)*np.linspace(1,0,int(SR*0.8))*0.6,0.02,d), at(fsweep(300,1200,0.6)*np.linspace(0.3,0,int(SR*0.6)),0.02,d))
SC=mix(pad(wr(0.2,150,600)*0.25,d), at(sat(bp(noise(0.6),300,3000)*expenv(0.6,0.15)*2,2)*0.6,0.18,d), at(thump(150,60,0.2,0.05),0.18,d)*0.7)
S['servodash']=[fade(SA,0.001),fade(SB,0.001),fade(SC,0.002)]
# TETHER SPIKE (spike fired)
d=0.9
TA=mix(pad(mix(thump(300,120,0.08,0.02),click(0.03,2000)),d)*0.7, at(fsweep(2400,900,0.4)*expenv(0.4,0.12)*0.3,0.02,d), at(chain(0.35),0.05,d))
TB=mix(pad(bp(noise(0.1),1000,6000)*expenv(0.1,0.025)*0.8,d), at(np.sin(2*np.pi*1500*t(0.5)+3*np.sin(2*np.pi*30*t(0.5)))*expenv(0.5,0.15)*0.3,0.05,d))
TC=mix(pad(sat(thump(180,60,0.2,0.05)*1.4,2),d), at(lp(np.sign(np.sin(2*np.pi*110*t(0.4))),3000)*expenv(0.4,0.12)*0.3,0.05,d))
S['tether']=[fade(TA,0.001),fade(TB,0.001),fade(TC,0.001)]
# DOME VISOR (faceplate drops)
d=0.8
parts=[(700,1,0.18),(1650,0.5,0.12),(2800,0.3,0.08)]
VA=mix(pad(sum(np.sin(2*np.pi*fq*t(0.6)+rng.uniform(0,6))*a*expenv(0.6,ta) for fq,a,ta in parts)*0.6,d), pad(thump(160,70,0.15,0.04)*0.7,d))
VB=mix(pad(wr(0.2,400,150)*0.3,d), at(mix(click(0.04,1200),thump(200,80,0.15,0.04)*0.7),0.2,d)*0.9, at(bp(noise(0.3),2000,6000)*expenv(0.3,0.06)*0.3,0.2,d))
VC=mix(pad(mix(hp(noise(0.03),1500)*expenv(0.03,0.006),thump(220,90,0.12,0.03)*0.6),d), at(chorus(260,0.6,4,0.02)*np.minimum(1,t(0.6)/0.05)*expenv(0.6,0.2)*0.4,0.03,d))
S['visor']=[fade(VA,0.001),fade(VB,0.002),fade(VC,0.001)]
# BLOOD RUSH (pays health for a headbutt)
d=1.0
hb=lambda: sine_sweep(80,40,0.22)*expenv(0.22,0.06)
BA=mix(pad(hb(),d), at(hb()*0.8,0.18,d), at(lp(noise(0.4),1500)*(0.5+0.5*np.sin(2*np.pi*12*t(0.4)))*expenv(0.4,0.15)*0.5,0.05,d))
BB=mix(pad(glp(0.3,300,90)*0.6,d), pad(bp(noise(0.4),500,3000)*expenv(0.4,0.1)*0.6,d), at(hb(),0.3,d))
BC=mix(pad(sat(fsweep(90,45,0.5)*expenv(0.5,0.15)*1.6,2.5)*0.8,d), at(bp(noise(0.4),2500,8000)*expenv(0.4,0.1)*0.35,0.02,d), at(hb()*0.8,0.5,d))
S['bloodrush']=[fade(BA,0.001),fade(BB,0.001),fade(BC,0.001)]
import subprocess
meta={}
for k,vs in S.items():
    for i,x in enumerate(vs):
        x=norm(x); pcm=(x*32000).astype('<i2'); fn=f'wav/{k}_{"ABC"[i]}.wav'
        with wave.open(fn,'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg','-y','-loglevel','error','-i',fn,'-b:a','96k',fn[:-4]+'.mp3'],check=True)
        meta[f'{k}_{"ABC"[i]}']=round(len(x)/SR,2)
print(meta); json.dump(meta,open('meta7.json','w'))
