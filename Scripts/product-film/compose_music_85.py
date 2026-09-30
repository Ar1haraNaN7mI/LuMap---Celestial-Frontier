"""Original, procedurally composed Lumap launch-film bed; no sampled music."""
from pathlib import Path
import numpy as np
import wave

out=Path(__file__).parent
sr=48000
duration=85.0
N=int(duration*sr)
mix=np.zeros((N,2),np.float64)
rng=np.random.default_rng(20260930)
beat=.6
bar=2.4

def hz(m):return 440*2**((m-69)/12)
def smoothstep(x):
 x=np.clip(x,0,1);return x*x*(3-2*x)
def add(y,start,pan=0.0,gain=1.):
 i=round(start*sr)
 if i<0:y=y[-i:];i=0
 n=min(len(y),N-i)
 if n<=0:return
 # equal power stereo placement
 angle=(pan+1)*np.pi/4
 mix[i:i+n,0]+=y[:n]*np.cos(angle)*gain
 mix[i:i+n,1]+=y[:n]*np.sin(angle)*gain

def pad(notes,dur,phase):
 t=np.arange(int(dur*sr))/sr
 a=smoothstep(t/1.4)*smoothstep((dur-t)/2.5)
 wavelet=np.zeros(len(t))
 for j,note in enumerate(notes):
  f=hz(note)
  carrier=(np.sin(2*np.pi*f*t + .012*np.sin(2*np.pi*.17*t+phase))+
    .17*np.sin(2*np.pi*2*f*t+phase)+.04*np.sin(2*np.pi*3*f*t))
  detune=np.sin(2*np.pi*f*1.0016*t + j*.29)
  wavelet+=(carrier+detune*.35)/(1.4*len(notes))
 return wavelet*a*(.84+.16*np.sin(2*np.pi*.07*t+phase))

def pluck(note,dur=.62,bright=.25):
 t=np.arange(int(dur*sr))/sr;f=hz(note)
 env=(1-np.exp(-t/.004))*np.exp(-t/.18)*smoothstep((dur-t)/.16)
 return (np.sin(2*np.pi*f*t)+bright*np.sin(2*np.pi*2*f*t)*np.exp(-t/.05)+
 .08*np.sin(2*np.pi*3*f*t)*np.exp(-t/.04))*env

# D major palette. Open voicings leave room for a spoken lead.
chords=[([59,62,66,69],47),([55,59,62,66],43),([54,57,62,64],38),([57,62,64,69],45)]
for block,start in enumerate(np.arange(0,75.0,bar*4)):
 notes,bass=chords[block%4]
 intensity=.72+.35*smoothstep((start-18)/25)-.30*smoothstep((start-64)/12)
 add(pad(notes,bar*4+2.3,block*.81),start-.8,-.45,.095*intensity)
 add(pad([n+12 for n in notes],bar*4+2.1,block*.81+1.2),start-.5,.55,.035*intensity)
 # Bass is intentionally rounded, moving twice a bar rather than a big kick.
 for b in np.arange(start,min(start+bar*4,77),beat*2):
  t=np.arange(int(.58*sr))/sr
  env=(1-np.exp(-t/.022))*np.exp(-t/.2)
  sig=(np.sin(2*np.pi*hz(bass)*t)+.1*np.sin(2*np.pi*hz(bass)*2*t))*env
  add(sig,b,0,.13*smoothstep((b-13)/9)*smoothstep((81-b)/8))
 # A measured arpeggio, getting brighter through the middle of the film.
 for k,b in enumerate(np.arange(start,min(start+bar*4,76),beat)):
  lift=smoothstep((b-16)/12)*smoothstep((81-b)/10)
  if lift==0:continue
  order=[0,2,1,3,2,1,3,1]
  note=notes[order[k%8]]+12
  sig=pluck(note,.75,.22)
  volume=.055*lift*(.70+.30*smoothstep((b-30)/22))
  pan=(-.5 if k%2 else .5)
  add(sig,b,pan,volume)
  add(sig,b+beat*.75,-pan,volume*.22)
  add(sig,b+beat*1.5,pan,volume*.08)
  # Restrained airy ticks, no drums under the opening phrase.
  if 27<b<74:
   tt=np.arange(int(.075*sr))/sr
   noise=rng.normal(0,1,len(tt));noise=np.r_[0,np.diff(noise)]
   tick=noise*np.exp(-tt/.015)*(1-np.exp(-tt/.001))
   add(tick,b+beat*.5,(-.6 if k%2 else .6),.0036*lift)

# Soft transition swells and sparse upper-register sparkles.
for start in [8.5,24,46.5,64.5,73]:
 t=np.arange(int(1.4*sr))/sr
 noise=rng.normal(0,1,len(t))
 # smoothed noise with a gentle rise and release; no disruptive whoosh.
 kernel=np.hanning(91);kernel/=kernel.sum()
 air=np.convolve(noise,kernel,mode='same')*np.sin(np.pi*t/1.4)**2
 add(air,start,.15,.030)
for start,note in [(2.8,86),(11.9,81),(24,86),(36,83),(48,81),(60,86),(72,83),(77,86),(80.2,81)]:
 sig=pluck(note,1.4,.12)
 add(sig,start,-.25,.038)
 add(sig,start+.32,.5,.012)

# Resolve into D major; ample silence-tail for a logo hold.
add(pad([50,57,62,66,69],8.4,.4),76.0,0,.105)
t=np.arange(N)/sr
fade=smoothstep(t/3)*smoothstep((85-t)/6)
mix*=fade[:,None]
# Soft limiter and comfortable unmastered delivery headroom.
mix=np.tanh(mix*1.15)
peak=np.max(np.abs(mix));mix*=10**(-10/20)/max(peak,1e-9)
with wave.open(str(out/'music_original_85s.wav'),'wb') as w:
 w.setparams((2,2,sr,N,'NONE','not compressed'))
 w.writeframes(np.int16(np.clip(mix,-1,1)*32767).tobytes())
print('Wrote original 85.000 s stereo bed. Peak -10 dBFS. Root should mix about -10 to -16 dB under voice.')
