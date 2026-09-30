"""Pixel-native cinematic transitions for real product footage.
Geometry, depth planes, directional masks and focus changes are evaluated per frame.
No HTML, browser renderer, third-party transition templates, or generated UI results.
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
W,H=1920,1080
XX=np.arange(W,dtype=np.float32)[None,:]
YY=np.arange(H,dtype=np.float32)[:,None]
BG=(18,18,22)

def ease(t):
 t=max(0.,min(1.,t));return t*t*t*(t*(t*6-15)+10)
def ramp(x):
 x=np.clip(x,0,1);return x*x*(3-2*x)
def pil(raw):return Image.frombytes('RGB',(W,H),raw)
def affine(im,scale=1,cx=960,cy=540,dx=0,dy=0):
 inv=1/scale
 return im.transform((W,H),Image.Transform.AFFINE,(inv,0,cx*(1-inv)-dx*inv,0,inv,cy*(1-inv)-dy*inv),Image.Resampling.BICUBIC,fillcolor=BG)
def composite(a,b,mask):
 m=Image.fromarray(np.uint8(np.clip(mask,0,1)*255),'L')
 return Image.composite(b,a,m)
def circle_mask(cx,cy,radius,feather=16):
 dist=np.sqrt((XX-cx)**2+(YY-cy)**2)
 return ramp((radius-dist)/feather+.5)
def rounded_mask(cx,cy,hw,hh,radius=30,feather=12):
 radius=min(radius,hw,hh)
 qx=np.abs(XX-cx)-(hw-radius);qy=np.abs(YY-cy)-(hh-radius)
 distance=np.minimum(np.maximum(qx,qy),0)+np.sqrt(np.maximum(qx,0)**2+np.maximum(qy,0)**2)-radius
 return ramp(.5-distance/feather)
def ring(im,mask,strength=.14):
 # A faint lavender contour rides the reveal edge instead of washing out the image.
 a=np.asarray(im).astype(np.float32)
 edge=4*mask*(1-mask)*strength
 return Image.fromarray(np.uint8(np.clip(a*(1-edge[:,:,None])+np.array([157,143,239])*edge[:,:,None],0,255)))

def plane(im,cx=960,cy=540,scale=1,yaw=0,opacity=1):
 """Project a rounded image plane with a small perspective yaw and a soft shadow."""
 w=W*scale;h=H*scale;d=.055*yaw
 dest=[(cx-w/2,cy-h/2-h*d),(cx+w/2,cy-h/2+h*d),(cx+w/2,cy+h/2-h*d),(cx-w/2,cy+h/2+h*d)]
 src=[(0,0),(W,0),(W,H),(0,H)]
 A=[];B=[]
 for (x,y),(u,v) in zip(dest,src):
  A.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]]);B.extend([u,v])
 coeff=np.linalg.solve(np.array(A),np.array(B))
 rgba=im.convert('RGBA');mask=Image.new('L',(W,H));ImageDraw.Draw(mask).rounded_rectangle((0,0,W,H),radius=24,fill=round(255*opacity));rgba.putalpha(mask)
 return rgba.transform((W,H),Image.Transform.PERSPECTIVE,tuple(coeff),Image.Resampling.BICUBIC)
def add_plane(canvas,p):
 shadow=Image.new('RGBA',(W,H),(0,0,0,0));sh=p.getchannel('A').filter(ImageFilter.GaussianBlur(16));shadow.putalpha(sh.point(lambda x:round(x*.30)))
 canvas.alpha_composite(shadow,(0,13));canvas.alpha_composite(p)

def _transition(raw_a,raw_b,t,spec):
 if t<=0:return raw_a
 if t>=1:return raw_b
 e=ease(t);a=pil(raw_a);b=pil(raw_b);kind=spec['kind'];pulse=math.sin(math.pi*t)**2
 if kind in ('portal','focus'):
  if kind=='portal':
   cx,cy=960,390+150*e;m=rounded_mask(cx,cy,1030*e,640*e,48,14)
   b=affine(b,1.105-.105*e,cx=960,cy=575)
   a=affine(a,1-.045*e)
  elif kind=='focus':
   cx,cy=spec.get('focus',[960,600]);r=1450*e;m=circle_mask(cx,cy,r,90)
   a=affine(a,1+.47*e,cx=cx,cy=cy)
   b=affine(b,.91+.09*e,cx=960,cy=600)
  return ring(composite(a,b,m),m,0 if kind=='focus' else .09).tobytes()
 if kind=='orb':
  # Actual photographed model anchors, measured in the composed footage.
  # Both center and orbit radius converge to the incoming phone model.
  sx,sy=975,404;tx,ty=1455,588
  cx=sx+(tx-sx)*e;cy=sy+(ty-sy)*e
  scale=1+(.669-1)*e
  a=affine(a,scale,cx=sx,cy=sy,dx=(tx-sx)*e,dy=(ty-sy)*e)
  radius=1650*(1-e)+83*e
  m=circle_mask(cx,cy,radius,20)*(1-ramp((t-.80)/.20))
  return composite(b,a,m).tobytes()
 if kind=='diagonal':
  slope=spec.get('slope',.22);direction=spec.get('direction',1)
  field=XX+slope*(YY-H/2)
  if direction<0:field=W-field
  margin=abs(slope)*H/2+45;edge=-margin+(W+2*margin)*e
  m=ramp((edge-field)/28+.5)
  a=affine(a,1,dx=-direction*32*e);b=affine(b,1.025-.025*e,dx=direction*32*(1-e))
  return ring(composite(a,b,m),m,.25).tobytes()
 if kind=='panels':
  # Five offset architectural reveals; all keep the original screen proportions.
  columns=5;local=XX/W*columns;idx=np.floor(local).clip(0,columns-1)
  delay=idx*.048;v=ramp((t-delay)/(.80));pos=-65+(H+130)*v
  m=ramp((pos-YY)/36+.5)
  a=affine(a,1-.025*e);b=affine(b,1.04-.04*e)
  return composite(a,b,m).tobytes()
 if kind in ('depth','vertical','pan'):
  c=Image.new('RGBA',(W,H),BG+(255,));d=spec.get('direction',1)
  if kind=='depth':
   lift=1-.065*math.sin(math.pi*t)
   pa=plane(a,960-d*(W+120)*e,540-20*pulse,lift,-d*.72*pulse)
   pb=plane(b,960+d*(W+120)*(1-e),540+20*pulse,lift,d*.72*pulse)
  elif kind=='vertical':
   lift=1-.025*math.sin(math.pi*t)
   pa=plane(a,960,540-(H+24)*e,lift,0)
   pb=plane(b,960,540+(H+24)*(1-e),lift,0)
  else:
   pa=plane(a,960-d*W*e,540,1,0)
   pb=plane(b,960+d*W*(1-e),540,1,0)
  add_plane(c,pa);add_plane(c,pb)
  # Keep shutter blur restrained: only at peak movement, never on settled UI.
  rgb=c.convert('RGB')
  if kind=='pan' and pulse>.15:rgb=rgb.filter(ImageFilter.GaussianBlur(1.5*pulse))
  return rgb.tobytes()
 if kind=='close':
  # Resolve the whole spatial screen into a retreating rounded plane.
  # The light brand canvas arrives around it, with no empty shrinking black iris.
  c=b.convert('RGBA');scale=1-.92*e
  card=plane(a,960,540-75*e,scale,.26*pulse,1-ramp((t-.55)/.45))
  add_plane(c,card)
  return c.convert('RGB').tobytes()
 raise ValueError(kind)

SPECS=[
 {'kind':'portal','frames':36,'name':'Curiosity opens into the product'},
 {'kind':'focus','frames':30,'name':'Focus into the learning goal','focus':[970,605]},
 {'kind':'diagonal','frames':30,'name':'Reveal the source material'},
 {'kind':'depth','frames':28,'name':'Research moves into an adaptive path'},
 {'kind':'portal','frames':28,'name':'The next learning step opens'},
 {'kind':'panels','frames':30,'name':'Evidence assembles into a concept map'},
 {'kind':'depth','frames':32,'name':'The companion enters the conversation'},
 {'kind':'diagonal','frames':30,'name':'Open the narrated lesson','direction':-1,'slope':-.18},
 {'kind':'vertical','frames':24,'name':'Move from the lesson into its quiz'},
 {'kind':'depth','frames':28,'name':'Enter optional checks'},
 {'kind':'pan','frames':24,'name':'Answer to specific feedback'},
 {'kind':'panels','frames':28,'name':'Evidence builds a growth record'},
 {'kind':'depth','frames':36,'name':'Pull back to the two-device experience','direction':-1},
 {'kind':'focus','frames':36,'name':'Enter spatial exploration','focus':[970,560]},
 {'kind':'orb','frames':36,'name':'Connect the spatial model across devices'},
 {'kind':'close','frames':40,'name':'Spatial world resolves into the brand'}
]

# Unchanged chapter labels remain readable while their product content moves.
for k in range(1,15):SPECS[k]['protect_header']=True
SPECS[14]['protect_preview_badge']=True

def transition(raw_a,raw_b,t,spec):
 if t<=0:return raw_a
 if t>=1:return raw_b
 # Remove overlays before spatial transforms, then place one stable overlay above
 # the effect. Merely pasting a stable title would leave a second moving copy.
 protected=spec.get('protect_header') or spec.get('protect_preview_badge')
 if not protected:return _transition(raw_a,raw_b,t,spec)
 a=pil(raw_a);b=pil(raw_b);ca=a.copy();cb=b.copy()
 regions=[]
 if spec.get('protect_header'):regions.append((0,0,W,162))
 if spec.get('protect_preview_badge'):regions.append((75,965,360,1060))
 for rect in regions:
  ImageDraw.Draw(ca).rectangle(rect,fill=BG);ImageDraw.Draw(cb).rectangle(rect,fill=BG)
 out=pil(_transition(ca.tobytes(),cb.tobytes(),t,spec))
 for rect in regions:
  ar=a.crop(rect);br=b.crop(rect)
  if ar.tobytes()==br.tobytes():overlay=ar
  elif rect==(0,0,W,162):
   # Changing chapter headings use an editorial handoff at a fixed position.
   # They never enlarge, slide off-frame, or overlap into doubled type.
   backdrop=Image.new('RGB',ar.size,BG)
   overlay=Image.blend(ar,backdrop,ease(t/.5)) if t<.5 else Image.blend(backdrop,br,ease((t-.5)/.5))
  else:overlay=Image.blend(ar,br,ease(t))
  out.paste(overlay,(rect[0],rect[1]))
 return out.tobytes()
