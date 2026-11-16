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
# VENOM GATLING (press: 0.4 s spin-up, then darts over 1 s)
d=1.5
# A motor spin-up whine + rapid wet pffts
f=np.concatenate([np.geomspace(80,600,int(SR*0.4)),np.full(int(SR*1.1),600)])
mot=lp(np.sign(np.sin(2*np.pi*np.cumsum(f)/SR)),2500)*0.25
shots=sum(at(pfft()*0.9+thump(300,120,0.06,0.02)*0.4,0.4+i*0.125,d) for i in range(8))
GA=mix(mot,shots)
# B mechanical barrel spin rattle + sharp spit shots
rat=bp(noise(len(f)/SR),1500,4000)*(0.5+0.5*np.sign(np.sin(2*np.pi*np.cumsum(f/8)/SR)))*0.25
shots=sum(at(bp(noise(0.05),2000,8000)*expenv(0.05,0.01)+thump(500,200,0.05,0.015)*0.5,0.4+i*0.125,d) for i in range(8))
GB=mix(rat,shots*0.9)
# C deep pneumatic chug (heavier, slower thumps)
spin=fsweep(60,240,0.4)*np.linspace(0,0.4,int(SR*0.4))
shots=sum(at(mix(thump(160,60,0.12,0.04)*0.9,pfft(0.08,300,2500)*0.6),0.4+i*0.125,d) for i in range(8))
GC=mix(pad(spin,d),shots)
S['gatling']=[fade(GA,0.002),fade(GB,0.002),fade(GC,0.002)]
# TOXIN MORTAR (the canister leaves)
d=0.8
MA=mix(sat(thump(90,35,0.5,0.12)*1.6,2.5), pad(lp(noise(0.3),800)*expenv(0.3,0.08)*0.7,d), at(bp(noise(0.4),1000,4000)*np.linspace(0.3,0,int(SR*0.4)),0.05,d))
# B hollow tube "thoonk" with a gas hiss
tube=sum(np.sin(2*np.pi*fq*t(0.5))*a for fq,a in [(180,1),(360,0.4),(540,0.2)])*expenv(0.5,0.08)
MB=mix(pad(tube,d)*0.8, at(bp(noise(0.6),2500,8000)*expenv(0.6,0.2)*0.35,0.04,d), pad(thump(110,50,0.2,0.05),d)*0.6)
# C slingshot whoosh launch (spring + rising whistle)
spring=sum(np.sin(2*np.pi*fq*t(0.3))*expenv(0.3,0.05) for fq in (700,1100))*0.4
wh=fsweep(400,1600,0.6)*np.sin(np.pi*t(0.6)/0.6)*0.35
MC=mix(pad(thump(150,60,0.2,0.05),d),pad(spring,d),at(wh,0.05,d),at(bp(noise(0.5),800,3000)*np.sin(np.pi*t(0.5)/0.5)*0.4,0.05,d))
S['mortar']=[fade(MA,0.001),fade(MB,0.001),fade(MC,0.001)]
# SPINE BURST (the spines leave, all round)
d=0.7
SA=mix(sum(at(bp(noise(0.25),2500,9000)*expenv(0.25,0.06)*0.5,i*0.012,d) for i in range(6)), pad(thump(200,80,0.15,0.04),d)*0.6)
# B crack + many whistling darts
SB=mix(pad(hp(noise(0.03),1500)*expenv(0.03,0.006),d), sum(at(fsweep(3000+i*300,1500+i*100,0.4)*expenv(0.4,0.1)*0.12,0.01*i,d) for i in range(8)), pad(thump(180,70,0.15,0.04),d)*0.5)
# C frill rattle + punchy shhk
rat=bp(noise(0.25),1500,5000)*(0.5+0.5*np.sign(np.sin(2*np.pi*35*t(0.25))))*0.4
SC=mix(pad(rat,d),at(sat(bp(noise(0.3),600,6000)*expenv(0.3,0.05)*1.5,2),0.2,d),at(thump(150,60,0.2,0.05),0.2,d)*0.7)
S['spine']=[fade(SA,0.001),fade(SB,0.001),fade(SC,0.001)]
# VENOM OVERDRIVE (press: 0.7 s reactor charge, roar)
d=1.5
# A reactor charge whine rising + bubbling surge
ch=lp(saw_sweep(150,1400,0.7),4000)*np.linspace(0.1,0.5,int(SR*0.7))
bub=lp(noise(0.8),1200)*(0.5+0.5*np.sin(2*np.pi*22*t(0.8)))*np.linspace(1,0,int(SR*0.8))*0.6
OA=mix(pad(ch,d),at(sat(thump(120,45,0.5,0.15)*1.4,2),0.7,d),at(bub,0.7,d))
# B charge + raspy dilo shriek
f0=np.geomspace(500,900,int(SR*0.7)); sr=2*((np.cumsum(f0)/SR)%1)-1
shriek=mix(bp(sr,1200,2600,2),bp(noise(0.7),2000,5000)*0.4)*np.sin(np.pi*t(0.7)/0.7)
OB=mix(pad(fsweep(100,800,0.7)*np.linspace(0,0.4,int(SR*0.7)),d),at(sat(shriek*2,2)*0.7,0.7,d),at(thump(100,40,0.3,0.08),0.7,d)*0.7)
# C deep power-up thrum + electric crackle
thr=chorus(55,d,4,0.03)*np.minimum(1,t(d)/0.7)*np.linspace(1,0.6,int(SR*d))
crk=bp(noise(d),2000,8000)*(rng.uniform(0,1,int(SR*d))>0.985)*3*np.minimum(1,t(d)/0.7)
OC=mix(sat(thr*1.5,2)*0.6,crk*0.3,at(thump(140,50,0.3,0.08),0.7,d)*0.8)
S['over']=[fade(OA,0.01),fade(OB,0.01),fade(OC,0.05)]
# SONIC HISS (the blast)
d=0.9
# A huge snake hiss + subsonic wobble
hs=bp(noise(d),2500,9000)*np.minimum(1,t(d)/0.02)*expenv(d,0.3)
wob=np.sin(2*np.pi*50*t(d))*(0.5+0.5*np.sin(2*np.pi*9*t(d)))*expenv(d,0.25)
HA=mix(hs*0.8,wob*0.7)
# B speaker blast: distorted sonic boom + ring
boom=sat(sine_sweep(300,60,0.4)*expenv(0.4,0.12)*2,3)
ring=np.sin(2*np.pi*1800*t(d))*expenv(d,0.2)*0.2
HB=mix(pad(boom,d)*0.8,ring,bp(noise(d),3000,8000)*expenv(d,0.15)*0.4)
# C warbling sonic wave (FM) sweep down
fm=np.sin(2*np.pi*np.cumsum(np.geomspace(2000,300,int(SR*d))*(1+0.3*np.sin(2*np.pi*30*t(d))))/SR)*expenv(d,0.3)
HC=mix(fm*0.6,bp(noise(d),3000,9000)*expenv(d,0.12)*0.4,pad(thump(150,60,0.2,0.05),d)*0.4)
S['hiss']=[fade(HA,0.001),fade(HB,0.001),fade(HC,0.001)]
# ANTIVENOM PUMP (the jolt: clears tags)
d=0.8
# A piston clunk + injection hiss + cleansing chime
PA=mix(pad(mix(thump(160,70,0.15,0.04),hp(noise(0.03),1500)*expenv(0.03,0.006)*0.5),d)*0.8, at(bp(noise(0.35),3000,9000)*expenv(0.35,0.12)*0.4,0.03,d), at(sum(np.sin(2*np.pi*fq*t(0.5))*a for fq,a in [(1047,0.5),(1568,0.3)])*expenv(0.5,0.15),0.12,d)*0.4)
# B electric defib jolt
PB=mix(pad(lp(np.sign(np.sin(2*np.pi*120*t(0.25))),3000)*expenv(0.25,0.08),d)*0.6, pad(bp(noise(0.25),2000,8000)*expenv(0.25,0.06)*0.6,d), pad(thump(130,50,0.25,0.07),d)*0.8)
# C pneumatic pump "chk-pssh" + rising tone
PC=mix(pad(hp(noise(0.02),2000)*expenv(0.02,0.004),d)*0.8, at(bp(noise(0.25),1000,6000)*expenv(0.25,0.07)*0.6,0.03,d), at(fsweep(400,1200,0.4)*np.linspace(0.4,0,int(SR*0.4)),0.15,d))
S['pump']=[fade(PA,0.001),fade(PB,0.001),fade(PC,0.001)]
# SNIPER SCOPE (the shot, hits instantly)
d=0.9
# A sharp sniper crack + tail
KA=mix(pad(hp(noise(0.02),2000)*expenv(0.02,0.004),d), pad(sat(thump(250,60,0.3,0.06)*1.5,2.5),d)*0.8, lp(noise(d),1500)*expenv(d,0.25)*0.35)
# B suppressed "thwip" + venom splat
KB=mix(pad(bp(noise(0.08),800,5000)*expenv(0.08,0.02),d)*0.8, pad(fsweep(1500,300,0.1)*expenv(0.1,0.03)*0.5,d), at(lp(noise(0.15),1200)*expenv(0.15,0.04)*0.6,0.12,d))
# C railgun zing
zing=fsweep(3500,800,0.4)*expenv(0.4,0.12)
KC=mix(pad(zing*0.6,d),pad(thump(200,60,0.25,0.06)*0.8,d),bp(noise(d),2000,7000)*expenv(d,0.1)*0.3)
S['scope']=[fade(KA,0.001),fade(KB,0.001),fade(KC,0.001)]
import subprocess
meta={}
for k,vs in S.items():
    for i,x in enumerate(vs):
        x=norm(x); pcm=(x*32000).astype('<i2'); fn=f'wav/{k}_{"ABC"[i]}.wav'
        with wave.open(fn,'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg','-y','-loglevel','error','-i',fn,'-b:a','96k',fn[:-4]+'.mp3'],check=True)
        meta[f'{k}_{"ABC"[i]}']=round(len(x)/SR,2)
print(meta); json.dump(meta,open('meta4.json','w'))
