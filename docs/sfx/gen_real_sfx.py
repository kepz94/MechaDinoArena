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
# B: metal armor clang (mech plating hit)
d=0.6
parts=[(420,1.0,0.18),(1130,0.6,0.12),(1870,0.45,0.09),(2690,0.3,0.07),(3550,0.2,0.05)]
B=mix(sum(np.sin(2*np.pi*f*t(d)+rng.uniform(0,6))*a*expenv(d,tau) for f,a,tau in parts), sine_sweep(160,60,0.2)*expenv(0.2,0.05)*0.8, hp(noise(0.05),2500)*expenv(0.05,0.006)*0.6)
# C: crunchy punch + metal tick
d=0.3
C=mix(sat(sine_sweep(220,55,d)*expenv(d,0.06)*1.3,3)*0.9, bp(noise(d),300,2500)*expenv(d,0.04)*0.8, np.sin(2*np.pi*2400*t(0.06))*expenv(0.06,0.01)*0.35)
S['hurt']=[A,B,C]
# YOU DIED
# A: mech power-down (servo whine falling + clunk + rumble)
d=1.6
whine=lp(saw_sweep(900,70,d),3000)*np.linspace(1,0.2,int(SR*d))*0.45
hum=np.sin(2*np.pi*np.geomspace(120,40,int(SR*d)).cumsum()/SR)*np.linspace(0.6,0,int(SR*d))*0.5
clunk=pad(mix(sine_sweep(120,40,0.4)*expenv(0.4,0.12),lp(noise(0.4),600)*expenv(0.4,0.05)),d)
clunk=np.roll(clunk,int(SR*1.05))
DA=mix(whine,hum,clunk*0.9)
# B: big collapse boom + debris
d=1.8
boom=sat(sine_sweep(90,30,d)*expenv(d,0.35),2.5)
rumble=lp(noise(d),250)*expenv(d,0.45)*1.4
debris=bp(noise(d),800,5000)*expenv(d,0.18)*0.25
crack=hp(noise(0.03),1500)*0.8
DB=mix(boom,rumble,debris,crack)
# C: dying growl (low formant saw dropping) + thud
d=1.5
f0=np.geomspace(110,45,int(SR*d)); ph=np.cumsum(f0)/SR; saw=2*(ph%1)-1
saw=saw*(1+0.3*np.sin(2*np.pi*14*t(d)))
g=mix(bp(saw,250,650,2)*1.0,bp(saw,900,1400,2)*0.6,bp(saw,2200,2800,2)*0.25)
g=g*np.concatenate([np.linspace(0,1,int(SR*0.08)),np.ones(int(SR*d)-int(SR*0.08))])*np.linspace(1,0,int(SR*d))**1.5
th=np.roll(pad(mix(sine_sweep(110,40,0.4)*expenv(0.4,0.1),lp(noise(0.4),500)*expenv(0.4,0.05)),d),int(SR*1.0))
DC=mix(sat(g*2,2)*0.8,th*0.9)
S['died']=[DA,DB,DC]
meta={}
for k,vs in S.items():
    for i,x in enumerate(vs):
        x=norm(x); pcm=(x*32000).astype('<i2'); fn=f'wav/{k}_{"ABC"[i]}.wav'
        with wave.open(fn,'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(pcm.tobytes())
        meta[f'{k}_{"ABC"[i]}']=round(len(x)/SR,2)
print(meta); json.dump(meta,open('meta2.json','w'))
