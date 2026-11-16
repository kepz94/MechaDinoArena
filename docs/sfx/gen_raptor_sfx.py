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
# CLOAK FIELD (turn invisible)
d=0.9
# A shimmer fade-out: rising airy sweep + glassy sparkle, fading
air=bp(noise(d),1500,7000)*np.linspace(0,1,int(SR*d))**0.5*np.linspace(1,0,int(SR*d))**2
sw=fsweep(300,2400,d)*np.linspace(0.6,0,int(SR*d))*0.4
spark=sum(at(np.sin(2*np.pi*f*t(0.15))*expenv(0.15,0.04),s,d) for f,s in [(3100,0.1),(4200,0.22),(3600,0.34),(5000,0.46)])*0.25
CA=mix(air*0.7,sw,spark)
# B electric hum that bends down and cuts out ("vwoop")
d=0.7
hum=chorus(1,d)  # placeholder
f=np.geomspace(520,90,int(SR*d)); hum=sum(np.sin(2*np.pi*np.cumsum(f*m)/SR) for m in (1,1.01,2.02))/3
hum=sat(hum*1.5,2)*np.linspace(1,0,int(SR*d))**1.3
CB=mix(hum*0.8, hp(noise(d),3000)*expenv(d,0.05)*0.3)
# C quick stealth whoosh (reverse-swell noise then gone)
d=0.6
sw=lp(noise(d),2500)*np.linspace(0,1,int(SR*d))**3
sw[int(SR*0.5):]*=np.linspace(1,0,len(sw)-int(SR*0.5))
CC=mix(sw, fsweep(200,900,d)*np.linspace(0,0.4,int(SR*d))**2)
S['cloak']=[fade(CA),fade(CB),fade(CC,0.002)]
# ENERGY SHIELD (block all damage)
d=0.9
# A power-up hum + bass thump + ring
thump=sine_sweep(150,55,0.3)*expenv(0.3,0.08)
hum=chorus(220,d)*np.minimum(1,t(d)/0.15)*expenv(d,0.5)*0.5
ring=sum(np.sin(2*np.pi*fq*t(d))*a for fq,a in [(880,0.5),(1320,0.3),(1760,0.2)])*expenv(d,0.25)*0.35
SA=mix(pad(thump,d)*0.9,hum,ring)
# B energy bubble: rising tremolo sweep "vwomm"
d=0.8
b=fsweep(140,520,d)*(0.6+0.4*np.sin(2*np.pi*18*t(d)))*np.minimum(1,t(d)/0.05)*np.linspace(1,0.2,int(SR*d))
SB=mix(sat(b,1.5)*0.8, bp(noise(d),2000,6000)*expenv(d,0.1)*0.25)
# C metallic clang + electric buzz
d=0.8
parts=[(600,1.0,0.25),(1510,0.5,0.15),(2470,0.35,0.1)]
clang=sum(np.sin(2*np.pi*fq*t(d)+rng.uniform(0,6))*a*expenv(d,tau) for fq,a,tau in parts)
buzz=lp(np.sign(np.sin(2*np.pi*110*t(d))),1800)*expenv(d,0.3)*0.35
SC=mix(clang*0.7,buzz,hp(noise(0.04),2000)*expenv(0.04,0.008)*0.6)
S['shield']=[fade(SA,0.002),fade(SB,0.002),fade(SC,0.001)]
# ADRENALINE (heal + speed)
def beat(d0=0.12): return sine_sweep(90,45,d0+0.1)*expenv(d0+0.1,0.06)
# A syringe hiss + heartbeat x2 (fast)
d=1.0
hiss=bp(noise(0.3),3000,9000)*np.minimum(1,t(0.3)/0.02)*expenv(0.3,0.12)
hb=at(beat(),0.3,d)*1.0+at(beat(),0.48,d)*0.8+at(beat(),0.7,d)*1.0+at(beat(),0.86,d)*0.8
AA=mix(pad(hiss,d)*0.6,hb)
# B pneumatic injector "pssht-click" + rising tone
d=0.9
click=hp(noise(0.02),1500)*expenv(0.02,0.004)
pss=bp(noise(0.25),1200,6000)*expenv(0.25,0.08)
rise=fsweep(300,1200,0.6)*np.minimum(1,t(0.6)/0.05)*np.linspace(0.5,0,int(SR*0.6))
AB=mix(pad(click,d)*0.8,at(pss,0.03,d)*0.7,at(rise,0.25,d)*0.6)
# C heartbeat that speeds up + rising whine
d=1.1
hb=sum(at(beat(),s,d)*a for s,a in [(0,1),(0.15,0.7),(0.42,1),(0.55,0.7),(0.75,1),(0.85,0.7),(1.0,0.9)])
wh=lp(saw_sweep(200,900,d),2500)*np.linspace(0,0.25,int(SR*d))
AC=mix(hb,wh)
S['adren']=[fade(AA,0.001),fade(AB,0.001),fade(AC,0.001)]
# SHOCK CANNON (fire electric ball)
# A charge zap + boom
d=0.7
zap=lp(saw_sweep(200,3000,0.12),6000)*0.5
crack=bp(noise(d),800,7000)*expenv(d,0.08)*(0.6+0.4*np.sign(np.sin(2*np.pi*60*t(d))))
boom=sat(sine_sweep(160,45,d)*expenv(d,0.15),2)
KA=mix(pad(zap,d),at(crack,0.1,d)*0.6,at(boom,0.1,d)*0.9)
# B heavy plasma "pew" with crackle tail
d=0.6
pew=sat(fsweep(1800,180,0.35)*expenv(0.35,0.12),2)
crk=bp(noise(d),2000,8000)*(rng.uniform(0,1,int(SR*d))>0.97)*expenv(d,0.2)*3
KB=mix(pad(pew,d)*0.8,crk*0.4,pad(sine_sweep(120,50,0.2)*expenv(0.2,0.05),d)*0.6)
# C deep thump + buzzing electric tail
d=0.8
th=sat(sine_sweep(110,40,0.35)*expenv(0.35,0.1)*1.5,2.5)
tail=lp(np.sign(np.sin(2*np.pi*(90+30*np.sin(2*np.pi*7*t(d)))*t(d))),2500)*expenv(d,0.25)*0.35
KC=mix(pad(th,d),tail,pad(hp(noise(0.05),2500)*expenv(0.05,0.01),d)*0.5)
S['cannon']=[fade(KA,0.001),fade(KB,0.001),fade(KC,0.001)]
# SCENT SENSE (sniff, trails glow)
def sniff(d0=0.13,lo=700,hi=4000): return bp(noise(d0),lo,hi)*np.sin(np.pi*t(d0)/d0)**2
# A two quick sniffs + soft chime
d=1.0
chime=sum(np.sin(2*np.pi*fq*t(0.6))*a for fq,a in [(988,0.6),(1480,0.35),(1976,0.2)])*expenv(0.6,0.18)
NA=mix(pad(sniff(),d)*0.9,at(sniff(),0.17,d)*0.9,at(chime,0.38,d)*0.45)
# B snort sniff + sonar ping
d=1.1
snort=mix(sniff(0.2,400,2500),np.sin(2*np.pi*120*t(0.2))*np.sin(np.pi*t(0.2)/0.2)**2*0.3)
ping=np.sin(2*np.pi*1300*t(0.8))*expenv(0.8,0.2)
echo=at(ping*0.35,0.25,0.9)
NB=mix(pad(snort,d)*0.9,at(ping*0.5,0.25,d),at(echo,0.25,d))
# C three short sniffs + low shimmer swell
d=1.1
sh=chorus(330,0.8,6,0.02)*np.sin(np.pi*t(0.8)/0.8)*0.35
NC=mix(pad(sniff(0.09),d),at(sniff(0.09),0.12,d),at(sniff(0.1),0.24,d),at(sh,0.3,d))
S['scent']=[fade(NA,0.002),fade(NB,0.002),fade(NC,0.002)]
import subprocess
meta={}
for k,vs in S.items():
    for i,x in enumerate(vs):
        x=norm(x); pcm=(x*32000).astype('<i2'); fn=f'wav/{k}_{"ABC"[i]}.wav'
        with wave.open(fn,'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg','-y','-loglevel','error','-i',fn,'-b:a','96k',fn[:-4]+'.mp3'],check=True)
        meta[f'{k}_{"ABC"[i]}']=round(len(x)/SR,2)
print(meta); json.dump(meta,open('meta3.json','w'))
