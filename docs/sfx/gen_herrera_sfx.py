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
# QUILL LAUNCHER (volley)
d=1.0
QA=mix(*[at(mix(click(0.02,2000)*0.7,fsweep(2600,1400,0.18)*expenv(0.18,0.05)*0.25),i*0.07,d) for i in range(8)])
QB=mix(*[at(mix(thump(220,90,0.08,0.02)*0.6,pfft(0.07,1500,7000)*0.8),i*0.06,d) for i in range(8)], pad(fsweep(120,60,0.3)*expenv(0.3,0.1)*0.4,d))
QC=mix(pad(lp(saw_sweep(100,500,0.25),2000)*np.linspace(0,0.3,int(SR*0.25)),d),*[at(bp(noise(0.12),3000,9000)*expenv(0.12,0.03)*0.7,0.25+i*0.05,d) for i in range(8)])
S['quills']=[fade(QA,0.001),fade(QB,0.001),fade(QC,0.002)]
# SMOKE PODS (cloud bursts)
d=1.2
SA=mix(pad(mix(thump(140,60,0.15,0.04),click(0.02)*0.6),d)*0.8, lp(noise(d),1500)*np.minimum(1,t(d)/0.03)*expenv(d,0.35)*0.7)
SB=mix(*[at(mix(click(0.015,2500)*0.5,bp(noise(0.5),400,3000)*expenv(0.5,0.15)*0.6),i*0.12,d) for i in range(3)])
SC=mix(pad(fsweep(800,200,0.2)*expenv(0.2,0.06)*0.4,d), bp(noise(d),200,1500)*np.sin(np.pi*np.minimum(1,t(d)/d))**0.5*expenv(d,0.5)*0.8)
S['smoke']=[fade(SA,0.001),fade(SB,0.001),fade(SC,0.002)]
# STROBE FRILL (flash -> daze)
d=0.8
XA=mix(pad(hp(noise(0.05),3000)*expenv(0.05,0.01),d), pad(sum(np.sin(2*np.pi*fq*t(0.6))*a for fq,a in [(2000,0.5),(3000,0.3),(4100,0.2)])*expenv(0.6,0.15),d)*0.5)
XB=mix(pad(fsweep(200,4000,0.08)*0.5,d), at(sat(bp(noise(0.3),1000,8000)*expenv(0.3,0.06)*2,2)*0.6,0.08,d), at(np.sin(2*np.pi*60*t(0.5))*expenv(0.5,0.12)*0.5,0.08,d))
fl=np.sign(np.sin(2*np.pi*14*t(0.6)))*0.5+0.5
XC=mix(pad(lp(np.sign(np.sin(2*np.pi*880*t(0.6))),5000)*fl*expenv(0.6,0.25)*0.35,d), pad(click(0.03,2500),d))
S['strobe']=[fade(XA,0.001),fade(XB,0.001),fade(XC,0.001)]
# STUN BREAKER (break free)
d=0.8
BA=mix(pad(sat(thump(180,60,0.3,0.08)*1.5,2),d), pad(hp(noise(0.06),1500)*expenv(0.06,0.015)*0.8,d), at(bp(noise(0.4),1500,6000)*expenv(0.4,0.1)*0.3,0.03,d))
parts=[(800,1,0.15),(1900,0.6,0.1),(3100,0.4,0.07)]
BB=mix(pad(sum(np.sin(2*np.pi*fq*t(0.5)+rng.uniform(0,6))*a*expenv(0.5,ta) for fq,a,ta in parts)*0.6,d), pad(lp(np.sign(np.sin(2*np.pi*120*t(0.3))),2500)*expenv(0.3,0.08)*0.5,d), pad(thump(150,60,0.2,0.05),d)*0.6)
BC=mix(pad(fsweep(150,900,0.25)*np.linspace(0.2,0.6,int(SR*0.25)),d), at(sat(bp(noise(0.3),300,4000)*expenv(0.3,0.06)*2,2)*0.7,0.25,d), at(thump(160,50,0.3,0.08),0.25,d)*0.8)
S['breaker']=[fade(BA,0.001),fade(BB,0.001),fade(BC,0.001)]
# RAZOR CALTROPS (spikes dropped)
d=0.9
CA=mix(*[at(np.sin(2*np.pi*(2500+300*i)*t(0.12)+rng.uniform(0,6))*expenv(0.12,0.03)*0.4+0,0.04+i*0.09+rng.uniform(0,0.03),d) for i in range(6)], pad(click(0.02)*0.6,d))
CB=mix(pad(bp(noise(0.25),1500,5000)*(0.5+0.5*np.sign(np.sin(2*np.pi*30*t(0.25))))*0.5,d), *[at(click(0.015,3000)*0.6,0.25+i*0.06+rng.uniform(0,0.02),d) for i in range(6)])
CC=mix(pad(mix(thump(200,90,0.1,0.03),click(0.02)),d)*0.6, *[at(mix(click(0.01,2500)*0.4,np.sin(2*np.pi*(1800+200*i)*t(0.2))*expenv(0.2,0.05)*0.3),0.08+i*0.07,d) for i in range(6)])
S['caltrops']=[fade(CA,0.001),fade(CB,0.001),fade(CC,0.001)]
# GOO BLOB SHOOTER (blob tossed)
d=0.8
gl=np.sin(2*np.pi*np.cumsum(np.geomspace(150,600,int(SR*0.25)))/SR)*expenv(0.25,0.08)
GA=mix(pad(gl*0.7,d), pad(lp(noise(0.2),1200)*expenv(0.2,0.05)*0.6,d), pad(thump(120,60,0.15,0.04)*0.5,d))
GB=mix(pad(thump(90,40,0.3,0.08)*0.9,d), at(lp(noise(0.3),900)*(0.5+0.5*np.sin(2*np.pi*25*t(0.3)))*expenv(0.3,0.1)*0.6,0.03,d))
GC=mix(pad(fsweep(600,150,0.12)*expenv(0.12,0.04)*0.6,d), pad(lp(noise(0.25),1500)*expenv(0.25,0.06)*0.5,d), at(sum(np.sin(2*np.pi*fq*t(0.2))*expenv(0.2,0.04) for fq in (300,450))*0.3,0.1,d))
S['goo']=[fade(GA,0.001),fade(GB,0.001),fade(GC,0.001)]
# GLIDER WINGS (wings snap open)
d=0.8
WA=mix(pad(click(0.03,1200)*0.8,d), at(bp(noise(0.6),400,3000)*np.sin(np.pi*t(0.6)/0.6)*0.6,0.03,d))
WB=mix(pad(mix(thump(300,150,0.08,0.02),hp(noise(0.04),2000)*expenv(0.04,0.01)),d)*0.7, at(lp(noise(0.6),1200)*np.sin(np.pi*t(0.6)/0.6)**2*0.6,0.05,d), at(fsweep(300,600,0.4)*np.linspace(0.3,0,int(SR*0.4)),0.05,d))
WC=mix(*[at(mix(click(0.02,1500)*0.5,thump(250,120,0.06,0.02)*0.4),i*0.05,d) for i in range(4)], at(bp(noise(0.5),800,4000)*np.sin(np.pi*t(0.5)/0.5)*0.4,0.2,d))
S['glider']=[fade(WA,0.001),fade(WB,0.001),fade(WC,0.001)]
# CRUISE MISSILE launch
d=1.3
MA=mix(pad(sat(thump(110,45,0.3,0.08)*1.5,2),d), lp(noise(d),3000)*np.minimum(1,t(d)/0.05)*np.linspace(1,0,int(SR*d))*0.6, fsweep(200,500,d)*np.linspace(0.3,0,int(SR*d)))
MB=mix(pad(fsweep(400,2500,0.3)*0.3,d), at(bp(noise(1.0),300,5000)*np.linspace(1,0,int(SR*1.0))*0.8,0.2,d), at(thump(130,50,0.3,0.08),0.2,d)*0.8)
MC=mix(pad(click(0.05,1000),d)*0.8, at(lp(noise(1.2),2000)*(0.7+0.3*np.sin(2*np.pi*40*t(1.2)))*np.minimum(1,t(1.2)/0.1)*np.linspace(1,0,int(SR*1.2))*0.7,0.05,d))
S['cmlaunch']=[fade(MA,0.001),fade(MB,0.001),fade(MC,0.001)]
# CRUISE MISSILE boom
d=2.0
EA=mix(sat(sine_sweep(80,28,d)*expenv(d,0.4)*1.5,2.5), lp(noise(d),400)*expenv(d,0.5)*1.2, pad(hp(noise(0.04),1500)*0.8,d), bp(noise(d),1000,6000)*expenv(d,0.2)*0.3)
EB=mix(pad(hp(noise(0.06),1000)*expenv(0.06,0.02),d), sat(sine_sweep(120,35,d)*expenv(d,0.3)*2,3)*0.8, lp(noise(d),1200)*expenv(d,0.3)*0.6)
EC=mix(sat(sine_sweep(70,25,d)*expenv(d,0.6),2)*0.8, lp(noise(d),250)*expenv(d,0.7)*1.4, at(bp(noise(1.2),1500,6000)*expenv(1.2,0.3)*0.2,0.15,d))
S['cmboom']=[fade(EA,0.001),fade(EB,0.001),fade(EC,0.001)]
import subprocess
meta={}
for k,vs in S.items():
    for i,x in enumerate(vs):
        x=norm(x); pcm=(x*32000).astype('<i2'); fn=f'wav/{k}_{"ABC"[i]}.wav'
        with wave.open(fn,'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg','-y','-loglevel','error','-i',fn,'-b:a','96k',fn[:-4]+'.mp3'],check=True)
        meta[f'{k}_{"ABC"[i]}']=round(len(x)/SR,2)
print(meta); json.dump(meta,open('meta5.json','w'))
