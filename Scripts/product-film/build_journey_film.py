"""Lumap Journey Edition: native-code motion inserts around the verified v1 film.

Public Pillow / NumPy compositor; no HTML or GUI automation.
The motion task is standalone; full-film editing requires local media inputs.
See docs/product-film/README.md. This code is covered by the repository MIT license. Original
85-second masters remain untouched. The journey visualization is labelled as a
motion study until a real native app capture is supplied; activity surfaces are
cropped from recorded app screenshots, never fabricated provider responses.
"""
from pathlib import Path
import argparse, functools, hashlib, json, math, os, re, shutil, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import imageio_ffmpeg
import film_sources as original
from cinematic_transitions import transition, ease, plane, add_plane

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT = SCRIPT_DIR.parents[1]
ROOT = Path(os.environ.get('LUMAP_FILM_ROOT', str(SCRIPT_DIR / '.local'))).expanduser().resolve()
WORK = ROOT / 'edit/journey_v2'
FINAL = ROOT / 'final/journey_v2'
WORK.mkdir(parents=True,exist_ok=True); FINAL.mkdir(parents=True,exist_ok=True)
FF = imageio_ffmpeg.get_ffmpeg_exe()
W, H, FPS, DURATION = 1920, 1080, 30, 105
BG = (12, 13, 20)
GOLD = (237, 198, 118)
IVORY = (255, 242, 206)
CARD = (23, 26, 36)
WHITE = (244, 245, 249)
MUTED = (179, 183, 199)
STEM = 'Lumap_Product_Film_Journey'

@functools.lru_cache(maxsize=80)
def font(size, bold=False):
    supplied = os.environ.get('LUMAP_FILM_FONT')
    path = supplied or '/System/Library/Fonts/Avenir Next.ttc'
    index = int(os.environ.get('LUMAP_FILM_FONT_INDEX_BOLD' if bold else 'LUMAP_FILM_FONT_INDEX_REGULAR', '0')) if supplied else (2 if bold else 7)
    return ImageFont.truetype(path, size, index=index)

def text(im, value, xy, size=30, color=WHITE, bold=False, anchor=None):
    ImageDraw.Draw(im).text(xy, value, font=font(size, bold), fill=color, anchor=anchor)

def command(args, name):
    with (WORK / (name + '.log')).open('w') as log:
        subprocess.run([FF, '-hide_banner', '-y', *args], stdout=log, stderr=log, check=True)

def encoder(path, audio=None):
    args = [FF, '-hide_banner', '-y', '-f', 'rawvideo', '-pixel_format', 'rgb24',
            '-video_size', f'{W}x{H}', '-framerate', str(FPS), '-i', 'pipe:0']
    if audio:
        args += ['-i', str(audio), '-map', '0:v:0', '-map', '1:a:0', '-c:a', 'aac', '-b:a', '256k']
    else:
        args += ['-an']
    return args + ['-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p',
                   '-c:v', 'libx264', '-preset', 'fast', '-crf', '17', '-threads', '3',
                   '-colorspace', 'bt709', '-color_trc', 'bt709', '-color_primaries', 'bt709',
                   '-movflags', '+faststart', str(path)]

def write_frames(path, frames, audio=None):
    with path.with_suffix('.log').open('w') as log:
        proc = subprocess.Popen(encoder(path, audio), stdin=subprocess.PIPE, stdout=log, stderr=log)
        try:
            count = 0
            for frame in frames:
                proc.stdin.write(frame if isinstance(frame, bytes) else frame.convert('RGB').tobytes())
                count += 1
            proc.stdin.close()
            assert proc.wait() == 0
            return count
        except BaseException:
            proc.kill(); proc.wait(); raise

def rounded_image(image, size, radius=24):
    source = image.copy()
    source.thumbnail(size, Image.Resampling.LANCZOS)
    surface = Image.new('RGBA', size, CARD + (255,))
    surface.alpha_composite(source.convert('RGBA'), ((size[0]-source.width)//2, (size[1]-source.height)//2))
    mask = Image.new('L', size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0]-1, size[1]-1), radius, fill=255)
    surface.putalpha(mask)
    return surface

def journey_card(title, subtitle, methods, number, complete=False):
    card = Image.new('RGBA', (750, 225))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((1, 1, 749, 224), 22, fill=CARD + (252,), outline=(91, 78, 52, 255), width=2)
    d.rounded_rectangle((27, 26, 65, 64), 10, fill=(57, 49, 34, 255))
    if complete:
        d.line((37, 46, 44, 53, 56, 37), fill=GOLD+(255,), width=3, joint='curve')
    else:
        text(card, f'{number:02}', (46, 45), 20, GOLD, True, 'mm')
    text(card, 'EXPLORED' if complete else 'NOW · CONTINUE', (82, 34), 19, GOLD, True)
    text(card, title, (28, 82), 34, WHITE, True)
    text(card, subtitle, (28, 132), 22, MUTED)
    x = 28
    for label in methods:
        width = round(d.textlength(label, font=font(18)))+28
        d.rounded_rectangle((x, 176, x+width, 207), 9, fill=(36, 38, 49, 255))
        text(card, label, (x+14, 180), 18, (210, 211, 225))
        x += width + 9
    return card

CARDS = {}
def card_for(number, complete):
    key = (number, complete)
    if key not in CARDS:
        CARDS[key] = journey_card(
            'How do plants turn light into life?' if number == 1 else 'Test the idea. Change one condition.',
            'Make sense of the essentials.' if number == 1 else 'Follow the evidence into your next discovery.',
            ['Guided explanation', 'Visual map'] if number == 1 else ['Simulation', 'Teach it back'], number, complete)
    return CARDS[key]

def chain_x(y, t):
    q = min(1.2, max(0, y/H))
    return W/2 + math.sin((y-150)/190+t*.18)*155*(.2+.8*q)

def journey_motion(t):
    """Actual sequential contract: first completed → only then next visible tag."""
    im = Image.new('RGBA', (W, H), BG + (255,))
    # Restrained center light; blur is visual depth, not a screen crossfade.
    glow = Image.new('RGBA', (W//2, H//2))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((280, 50, 680, 570), fill=(132, 94, 27, 24))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(55)).resize((W, H)))
    scroll = 280*ease((t-4.8)/2.2)
    path = Image.new('RGBA', (W, H)); pd = ImageDraw.Draw(path)
    pts = [(chain_x(y-scroll, t), y) for y in range(158, H+30, 5)]
    for i in range(len(pts)-1):
        x, y = pts[i]; width = 1.1 + 10.4*max(0,min(1,y/H))**1.9
        alpha = round(28+220*min(1,(y-150)/340))
        pd.line((pts[i], pts[i+1]), fill=GOLD+(alpha,), width=max(1,round(width)))
    halo = path.filter(ImageFilter.GaussianBlur(15))
    im.alpha_composite(halo); im.alpha_composite(halo); im.alpha_composite(path)
    # A small moving highlight establishes the direction of exploration.
    py = 1010 - ((t*.19)%1)*860
    px = chain_x(py-scroll,t)
    pulse = Image.new('RGBA',(W,H)); p = ImageDraw.Draw(pulse)
    p.ellipse((px-10,py-10,px+10,py+10), fill=IVORY+(220,))
    im.alpha_composite(pulse.filter(ImageFilter.GaussianBlur(11))); im.alpha_composite(pulse)
    reveal = ease((t-3.8)/.65)
    complete = t >= 3.3
    cards = [(1, 575+scroll, 1.0, complete)]
    if reveal > 0:
        cards.append((2, 286+scroll, reveal, False))
    for number, cy, opacity, done in cards:
        sway = math.sin(t*.52 + number*.8)
        cx = 885 + (125 if number == 2 else -75) + sway*5
        card = card_for(number, done).copy()
        card.putalpha(card.getchannel('A').point(lambda a: round(a*opacity)))
        card = card.rotate(sway*.35, Image.Resampling.BICUBIC, expand=True)
        x, y = round(cx-card.width/2), round(cy-card.height/2 + (1-opacity)*20)
        shadow = Image.new('RGBA',card.size,(0,0,0,0))
        shadow.putalpha(card.getchannel('A').filter(ImageFilter.GaussianBlur(17)).point(lambda a: round(a*.30)))
        im.alpha_composite(shadow,(x,y+15)); im.alpha_composite(card,(x,y))
        d=ImageDraw.Draw(im); anchor_y=cy+107
        bx=chain_x(anchor_y-scroll,t)
        d.line((cx,anchor_y,bx,anchor_y+19),fill=GOLD+(round(150*opacity),),width=2)
        d.ellipse((bx-5,anchor_y+14,bx+5,anchor_y+24),fill=IVORY+(round(255*opacity),))
    text(im, 'A little further into possibility.', (106, 63), 50, WHITE, True)
    text(im, 'Your learning journey, illuminated.', (110, 128), 25, MUTED)
    text(im, 'JOURNEY MOTION STUDY', (110, 935), 17, (145, 142, 129), True)
    state = 'A new discovery appears only after you finish the current one.'
    text(im, state, (1810, 937), 20, MUTED, anchor='ra')
    return im.convert('RGB')

def native_journey(t, source):
    """A genuine native screenshot is shown in a moving editorial camera plane."""
    base = Image.new('RGBA',(W,H),BG+(255,))
    im = Image.open(source).convert('RGB')
    # Optional crop provided by root after actual UI inspection; never inferred.
    metadata = WORK/'native_chain.json'
    if metadata.exists():
        crop = json.loads(metadata.read_text()).get('crop')
        if crop: im=im.crop(crop)
    im.thumbnail((1696,750),Image.Resampling.LANCZOS)
    surface=rounded_image(im,im.size,24)
    zoom=1+.02*ease(t/8)
    surface=surface.resize((round(surface.width*zoom),round(surface.height*zoom)),Image.Resampling.BICUBIC)
    base.alpha_composite(surface,((W-surface.width)//2,183+(750-surface.height)//2))
    text(base,'Your journey, illuminated.',(110,57),50,WHITE,True)
    text(base,'NATIVE SWIFTUI COMPONENT · EXAMPLE LESSON DATA',(112,129),22,MUTED)
    return base.convert('RGB')

METHODS = [
    ('Guided explanation','Build a first understanding.','mac/02-learning-studio-guided.jpg',18),
    ('Worked example','See the reasoning unfold.','mac/method-02-worked-example.jpg',18),
    ('Socratic dialogue','Find the next question.','mac/method-03-socratic.jpg',20),
    ('Analogy','Make the unfamiliar familiar.','mac/method-04-analogy.jpg',18),
    ('Visual map','Connect the ideas.','mac/method-05-visual-map.jpg',24),
    ('Story mode','Learn through a different perspective.','mac/method-06-story-mode.jpg',42),
    ('Flash recall','Bring knowledge back.','mac/method-07-flash-recall.jpg',18),
    ('Teach it back','Explain it in your own words.','mac/method-08-teach-back.jpg',18),
    ('Interactive simulation','Change something. Notice why.','mac/method-09-simulation.jpg',22),
    ('Spatial exploration','AR CONCEPT PREVIEW','mac/method-10-spatial-ar.jpg',20),
    ('Deliberate practice','Work on the difficult part.','mac/method-11-deliberate-practice.jpg',18),
    ('Reflection','Make sense of what changed.','mac/method-12-reflection.jpg',18),
    ('Misconception diagnosis','Find the idea to rethink.','mac/method-13-misconception.jpg',18),
    ('Curiosity branch','Follow a useful question.','mac/method-14-curiosity.jpg',18),
    ('Counterfactual lab','What if one assumption changed?','ios/13-ios-counterfactual.jpg',18),
    ('Transfer challenge','Try the idea somewhere new.','ios/14-ios-transfer.jpg',18),
    ('Narrated lesson','Listen. Think. Answer.','export/live-photosynthesis-lesson.png',34),
]
assert sum(m[3] for m in METHODS)==360
EVIDENCE=PROJECT/'docs/test-evidence/2026-09-30'
IMAGES={}
def method_surface(index):
    if index in IMAGES:return IMAGES[index]
    name,_,source,_ = METHODS[index]
    path=EVIDENCE/source
    if name=='Story mode' and (WORK/'paper2galgame-native.png').exists():
        path=WORK/'paper2galgame-native.png'
        im=Image.open(path).convert('RGB')
        meta=WORK/'paper2galgame-native.json'
        if meta.exists() and json.loads(meta.read_text()).get('crop'):
            im=im.crop(json.loads(meta.read_text())['crop'])
    elif source.startswith('export/'):
        im=Image.open(PROJECT/'docs/images/live-photosynthesis-lesson.png').convert('RGB')
    else:
        im=Image.open(path).convert('RGB')
        # These crop coordinates were verified on the real captured app windows.
        # Remove desktop, account name, old method picker, sidebar and future path.
        if source.startswith('mac/'):
            im=im.crop((667,309,1540,880) if index<4 else (788,343,1658,1031))
        else:
            # Exclude iOS status/navigation/tab bars, retain real activity content.
            im=im.crop((40,350,1166,2350))
    IMAGES[index]=im
    return im

def method_frame(index, local_t):
    name,description,source,frames=METHODS[index]
    if index==5 and (WORK/'paper2galgame-native.png').exists():
        name='Story mode · Paper2GalGame'
        description='Your source becomes a playable lesson.'
    duration=frames/FPS
    t=min(1,max(0,local_t/duration))
    im=Image.new('RGBA',(W,H),BG+(255,))
    left=110
    text(im,'MANY WAYS TO UNDERSTAND',(left,55),22,GOLD,True)
    text(im,name,(left,112),52,WHITE,True)
    text(im,description,(left,180),27,MUTED)
    text(im,f'{index+1:02} / {len(METHODS):02}',(1810,117),28,GOLD,True,'ra')
    capture=method_surface(index)
    phone=source.startswith('ios/')
    # Deliberate depth/camera motion: the app imagery is unaltered inside its plane.
    size=(650,650) if phone else (1280,650)
    surface=rounded_image(capture,size,22)
    scale=1.018-.018*ease(t)
    surface=surface.resize((round(size[0]*scale),round(size[1]*scale)),Image.Resampling.BICUBIC)
    cx=1090 if phone else 960
    im.alpha_composite(surface,(round(cx-surface.width/2),round(264+(size[1]-surface.height)/2)))
    if phone:
        text(im,'A new angle.',(220,485),49,WHITE,True)
        text(im,'A deeper understanding.',(220,555),28,MUTED)
    if index==9:
        text(im,'SPATIAL CONCEPT PREVIEW',(110,937),20,GOLD,True)
    else:
        text(im,'APP ACTIVITIES · EXAMPLE LEARNING CONTENT',(110,940),17,(126,132,153),True)
    # Section progress accent is editorial, not a fabricated score or learner result.
    d=ImageDraw.Draw(im)
    for j in range(len(METHODS)):
        x=1467+j*20
        d.rounded_rectangle((x,945,x+12,949),2,fill=GOLD if j==index else (47,50,63))
    return im.convert('RGB')

MONTAGE_CUTS = [
    {'kind':'diagonal','slope':.32}, {'kind':'vertical'}, {'kind':'depth','direction':-1},
    {'kind':'panels'}, {'kind':'portal'}, {'kind':'pan','direction':-1},
    {'kind':'diagonal','slope':-.3,'direction':-1}, {'kind':'focus','focus':[1110,590]},
    {'kind':'depth'}, {'kind':'panels'}, {'kind':'vertical'}, {'kind':'diagonal'},
    {'kind':'portal'}, {'kind':'depth','direction':-1}, {'kind':'pan'}, {'kind':'focus'},
]

def montage_transition(a, b, t, spec):
    # Activity labels stay in one editorial position; their entire baseline and
    # descriptor are protected, instead of the shorter v1 chapter-header area.
    first=Image.frombytes('RGB',(W,H),a);second=Image.frombytes('RGB',(W,H),b)
    clean_a=first.copy();clean_b=second.copy()
    regions=[(0,0,W,244),(0,928,W,H)]
    for box in regions:
        ImageDraw.Draw(clean_a).rectangle(box,fill=BG)
        ImageDraw.Draw(clean_b).rectangle(box,fill=BG)
    result=Image.frombytes('RGB',(W,H),transition(clean_a.tobytes(),clean_b.tobytes(),t,spec))
    # Crisp, single-copy editorial label handoff at the geometric cut midpoint.
    for box in regions:result.paste((first if t<.5 else second).crop(box),(box[0],box[1]))
    return result.tobytes()

def montage_frames():
    for i,method in enumerate(METHODS):
        n=method[3]
        for j in range(n):
            raw=method_frame(i,j/FPS).tobytes()
            pre=4 if i else 0;post=4 if i+1<len(METHODS) else 0
            if pre and j<pre:
                previous=method_frame(i-1,(METHODS[i-1][3]-1)/FPS).tobytes()
                raw=montage_transition(previous,raw,(pre+j)/(2*pre),MONTAGE_CUTS[i-1])
            elif post and j>=n-post:
                nxt=method_frame(i+1,0).tobytes()
                raw=montage_transition(raw,nxt,(j-(n-post))/(2*post),MONTAGE_CUTS[i])
            yield raw
        print('montage',i+1,method[0],flush=True)

def prepare_visuals():
    native=WORK/'native_chain.png'
    def chain_frames():
        for j in range(240):
            t=j/FPS
            if native.exists() and t>=5.4:
                actual=native_journey(t-5.4,native)
                if t<6:
                    yield transition(journey_motion(5.4).tobytes(),actual.tobytes(),(t-5.4)/.6,{'kind':'portal'})
                else:yield actual
            else:yield journey_motion(t)
    assert write_frames(WORK/'journey-insert.mp4',chain_frames())==240
    assert write_frames(WORK/'methods-insert.mp4',montage_frames())==360
    for i,t in enumerate([0.5,3,3.6,4.4,5.8,7.4]):
        journey_motion(t).save(WORK/f'journey-motion-{i}.jpg')
    sheet=Image.new('RGB',(1440,6*282),BG)
    for i in range(17):
        frame=method_frame(i,METHODS[i][3]/FPS*.45)
        sheet.paste(frame.resize((480,270)),((i%3)*480,(i//3)*282))
        text(sheet,METHODS[i][0],((i%3)*480+10,(i//3)*282+265),14,MUTED)
    sheet.save(WORK/'methods-contact.jpg')

def wavread(path):
    with wave.open(str(path)) as w:
        sr=w.getframerate();channels=w.getnchannels()
        a=np.frombuffer(w.readframes(w.getnframes()),np.int16).astype(np.float64)/32768
        return a.reshape(-1,channels),sr

def wavwrite(path,a,sr=48000):
    if a.ndim==1:a=a[:,None]
    with wave.open(str(path),'wb') as w:
        w.setparams((a.shape[1],2,sr,len(a),'NONE','not compressed'))
        w.writeframes(np.int16(np.clip(a,-1,1)*32767).tobytes())

def shift(t):return t+(8 if t>=32 else 0)+(12 if t>=43 else 0)

def prepare_audio():
    # Extend the original procedural composition, retaining its harmonic language.
    code=(SCRIPT_DIR/'compose_music_85.py').read_text()
    substitutions={
        "out=Path(__file__).parent":"out=Path("+repr(str(WORK))+")",
        'duration=85.0':'duration=105.0','0,75.0':'0,95.0','start-64':'start-84',
        'start+bar*4,77':'start+bar*4,97','81-b':'101-b','start+bar*4,76':'start+bar*4,96',
        '27<b<74':'27<b<94','[8.5,24,46.5,64.5,73]':'[8.5,24,32,40,51,63,84.5,93]',
        '(72,83),(77,86),(80.2,81)':'(72,83),(84,81),(92,83),(97,86),(100.2,81)',
        '76.0,0,.105':'96.0,0,.105','(85-t)':'(105-t)',
        'music_original_85s.wav':'music_original_105s.wav','85.000 s':'105.000 s',
    }
    for a,b in substitutions.items():code=code.replace(a,b)
    (WORK/'create_music_105.py').write_text(code)
    exec(compile(code,str(WORK/'create_music_105.py'),'exec'),{'__file__':str(WORK/'create_music_105.py')})
    manifest=json.loads((ROOT/'audio/manifest.json').read_text())
    scenes=[]
    for item in manifest['scenes']:
        scene=dict(item)
        voice_path=Path(scene['file'])
        scene['file']=str(voice_path if voice_path.is_absolute() else ROOT/voice_path)
        scene['voice_start']=shift(scene['voice_start']);scene['scene_start']=shift(scene['scene_start'])
        scenes.append(scene)
    for key,start,length,zh in [
        ('11_journey',32,8,'你的学习旅程，逐渐亮起。\n完成一次探索，下一个发现才会展开。'),
        ('12_methods',51,12,'同一个目标，多种理解方式。\n故事、模拟、回忆与练习，为你的下一步而选择。'),
    ]:
        raw=WORK/(key+'_raw.wav');final=WORK/(key+'.wav')
        a,sr=wavread(raw);duration=len(a)/sr
        filters=f'highpass=f=65,lowpass=f=10000,loudnorm=I=-18:TP=-2:LRA=7,aresample=48000,afade=t=in:d=0.012,afade=t=out:st={duration-.07}:d=0.07'
        command(['-i',str(raw),'-af',filters,'-c:a','pcm_s16le','-ar','48000','-ac','1',str(final)],key+'-master')
        a,sr=wavread(final);duration=len(a)/sr
        assert duration+.6<length,(key,duration)
        scenes.append(dict(id=key,text=(WORK/(key+'.txt')).read_text().strip(),file=str(final),duration=duration,
                           scene_start=start,scene_duration=length,voice_start=start+.5,zh=zh,
                           voice='Kokoro multilingual v1.1 / af_sol / speaker 1 / speed 0.86'))
    scenes.sort(key=lambda s:s['voice_start'])
    sr=48000;n=int(DURATION*sr);voice=np.zeros(n);duck=np.ones(n);tm=np.arange(n)/sr
    for scene in scenes:
        a,rate=wavread(scene['file']);assert rate==sr and a.shape[1]==1
        start=scene['voice_start'];i=round(start*sr);voice[i:i+len(a)]+=a[:,0]
        end=start+len(a)/sr
        env=np.clip((tm-(start-.22))/.22,0,1)*np.clip(((end+.36)-tm)/.36,0,1)
        duck=np.minimum(duck,1-.67*env)
    music,_=wavread(WORK/'music_original_105s.wav')
    mix=voice[:,None]+music*duck[:,None]*.75
    assert np.max(np.abs(mix))<1,'clipping'
    wavwrite(WORK/'launch_mix_105s.wav',mix)
    wavwrite(WORK/'voiceover_105s.wav',voice)
    (WORK/'manifest.json').write_text(json.dumps(dict(total_runtime=DURATION,scenes=scenes,peak=float(np.max(np.abs(mix)))),indent=2))
    print('audio',DURATION,'seconds; 12 complete voice stems; peak',float(np.max(np.abs(mix))),flush=True)

def decode_new(path):
    gen=imageio_ffmpeg.read_frames(str(path),pix_fmt='rgb24');meta=next(gen)
    assert tuple(meta['size'])==(W,H)
    return gen,next(gen)

def render_full():
    original.configure(ROOT)
    shots=[];cuts=[]
    for i,shot in enumerate(original.shots):
        shots.append(dict(shot,old_index=i))
        if i==5:
            cuts.append(dict(kind='focus',frames=32,focus=[980,595],name='Follow the light into the journey'))
            shots.append(dict(name='journey-insert',duration=8))
            cuts.append(dict(kind='diagonal',frames=28,slope=.3,name='A discovery becomes a visual connection'))
        elif i==7:
            cuts.append(dict(kind='panels',frames=24,name='Open the activity gallery'))
            shots.append(dict(name='methods-insert',duration=12))
            cuts.append(dict(kind='portal',frames=24,name='The gallery resolves into the narrated lesson'))
        elif i<len(original.SPECS):cuts.append(original.SPECS[i])
    assert len(cuts)==len(shots)-1
    def decode(s):
        return original.decode(s['old_index']) if 'old_index' in s else decode_new(WORK/(s['name']+'.mp4'))
    marks=[]
    def frames():
        count=0;elapsed=0;prev=None;cur,first=decode(shots[0])
        for i,s in enumerate(shots):
            nxt,peek=decode(shots[i+1]) if i+1<len(shots) else (None,None)
            n=round(s['duration']*FPS);pre=cuts[i-1]['frames']//2 if i else 0;post=cuts[i]['frames']//2 if i<len(cuts) else 0
            for j in range(n):
                raw=first if j==0 else next(cur)
                if pre and j<pre:frame=transition(prev,raw,(pre+j)/(pre*2),cuts[i-1])
                elif post and j>=n-post:frame=transition(raw,peek,(j-(n-post))/(post*2),cuts[i])
                else:frame=raw
                yield frame;count+=1
            elapsed+=s['duration']
            if i<len(cuts):marks.append(dict(cuts[i],boundary_seconds=elapsed))
            prev=raw;cur.close();cur,first=nxt,peek
            print(s['name'],count,'/',DURATION*FPS,flush=True)
    count=write_frames(FINAL/(STEM+'_1080p.mp4'),frames(),WORK/'launch_mix_105s.wav')
    assert count==DURATION*FPS
    (WORK/'timeline.json').write_text(json.dumps(dict(duration_seconds=DURATION,frames=count,shots=shots,transitions=marks,
        chain_native_capture=(WORK/'native_chain.png').exists(),paper_native_capture=(WORK/'paper2galgame-native.png').exists(),
        original_masters_untouched=True,montage_methods=[m[0] for m in METHODS]),indent=2))

def stamp(t):
    ms=round(t*1000);return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'

def package():
    scenes=json.loads((WORK/'manifest.json').read_text())['scenes']
    oldzh=(SCRIPT_DIR/'templates/original_Chinese.srt').read_text().strip().split('\n\n')
    zhmap={f'{i+1:02}': '\n'.join(b.splitlines()[2:]) for i,b in enumerate(oldzh)}
    for language in ['English','Chinese']:
        blocks=[]
        for i,s in enumerate(scenes,1):
            if language=='Chinese':body=s.get('zh',zhmap.get(s['id'][:2],''))
            else:
                words=s['text'].split();mid=len(words)//2;body=' '.join(words[:mid])+'\n'+' '.join(words[mid:])
            blocks.append(f"{i}\n{stamp(s['voice_start'])} --> {stamp(s['voice_start']+s['duration'])}\n{body}\n")
        (FINAL/f'Lumap_Journey_{language}.srt').write_text('\n'.join(blocks))
    ass=(SCRIPT_DIR/'templates/captions.ass').read_text().split('Dialogue:')[0]
    def at(t):
        c=round(t*100);return f'{c//360000}:{c//6000%60:02}:{c//100%60:02}.{c%100:02}'
    lines=[];blocks=(FINAL/'Lumap_Journey_English.srt').read_text().strip().split('\n\n')
    for s,block in zip(scenes,blocks):
        body='\\N'.join(block.splitlines()[2:]);start=s['voice_start'];end=start+s['duration']
        parts=[(start,10.5,'Light'),(10.5,end,'Dark')] if s['id']=='02_introducing' else [(start,end,'Light' if s['id'] in ('01_question','10_close') else 'Dark')]
        for a,b,style in parts:lines.append(f'Dialogue: 0,{at(a)},{at(b)},{style},,0,0,0,,{body}')
    assfile=WORK/'captions.ass';assfile.write_text(ass+'\n'.join(lines)+'\n')
    master=FINAL/(STEM+'_1080p.mp4')
    command(['-i',str(master),'-vf',f'ass={assfile}','-c:v','libx264','-preset','fast','-crf','18','-threads','3','-c:a','copy','-colorspace','bt709','-color_trc','bt709','-color_primaries','bt709','-movflags','+faststart',str(FINAL/(STEM+'_Captions.mp4'))],'caption-render')
    command(['-i',str(master),'-i',str(FINAL/'Lumap_Journey_English.srt'),'-i',str(FINAL/'Lumap_Journey_Chinese.srt'),
        '-map','0:v','-map','0:a','-map','1:0','-map','2:0','-c:v','copy','-c:a','copy','-c:s','mov_text',
        '-metadata:s:s:0','language=eng','-metadata:s:s:0','title=English','-metadata:s:s:1','language=zho','-metadata:s:s:1','title=简体中文',
        '-disposition:s:0','0','-disposition:s:1','0','-metadata','title=Lumap — Journey Edition',
        '-metadata','artist=Celestial Frontier','-metadata','comment=App activities with example learning content, a native SwiftUI component snapshot, and labelled editorial journey motion. AR is a concept preview. Original ten narration stems preserved.',
        '-movflags','+faststart',str(FINAL/(STEM+'_Subtitles.mp4'))],'subtitle-mux')

def validate():
    records=[]
    for edition in ['1080p','Captions','Subtitles']:
        path=FINAL/(STEM+'_'+edition+'.mp4')
        result=subprocess.run([FF,'-hide_banner','-i',str(path),'-map','0:v:0','-map','0:a:0','-f','null','-'],capture_output=True,text=True)
        (WORK/f'decode-{edition}.log').write_text(result.stderr)
        counts=re.findall(r'frame=\s*(\d+)',result.stderr)
        assert result.returncode==0 and counts and int(counts[-1])==3150
        assert '1920x1080' in result.stderr and '30 fps' in result.stderr and '00:01:45.00' in result.stderr
        subs=len(re.findall(r'Stream #0:\d+.*Subtitle:',result.stderr))
        assert edition!='Subtitles' or subs==2
        records.append(dict(file=path.name,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                            duration_seconds=105,frames=3150,fps=30,resolution=[W,H],subtitle_tracks=subs,full_decode='passed'))
        print('full decode',edition,'3150 frames passed',flush=True)
    # Decode the delivery track, verify every spoken stem's full duration survives.
    raw=WORK/'decoded_audio.f32'
    command(['-i',str(FINAL/(STEM+'_1080p.mp4')),'-map','0:a:0','-ar','48000','-ac','2','-f','f32le',str(raw)],'decode-audio')
    audio=np.fromfile(raw,dtype=np.float32).reshape(-1,2).mean(axis=1)
    manifest=json.loads((WORK/'manifest.json').read_text());checks=[]
    for s in manifest['scenes']:
        a,sr=wavread(s['file']);a=a[:,0];offset=round(s['voice_start']*sr)
        clip=audio[offset:offset+len(a)];assert len(clip)==len(a)
        corr=float(np.corrcoef(a,clip)[0,1]);assert corr>.97,(s['id'],corr)
        checks.append(dict(id=s['id'],start=s['voice_start'],duration=s['duration'],correlation=corr,entire_stem_preserved=True))
    times=[.8,8,13,22,29,32.7,35.7,36.6,38.5,40.6,47.5,51.3,52.7,54.2,55.6,56.5,57.7,59.3,60.8,62.4,65,68,73,78,83,89,93,97,101,104.5]
    sheet=Image.new('RGB',(1440,10*284),BG)
    for i,t in enumerate(times):
        p=WORK/f'qa-frame-{i:02}.jpg'
        command(['-ss',str(t),'-i',str(FINAL/(STEM+'_Captions.mp4')),'-frames:v','1','-vf','scale=480:270',str(p)],f'qa-frame-{i:02}')
        x=i%3*480;y=i//3*284;sheet.paste(Image.open(p),(x,y));text(sheet,f'{t}s',(x+4,y+268),14,MUTED)
    sheet.save(WORK/'journey-final-contact.jpg')
    command(['-ss','38.6','-i',str(FINAL/(STEM+'_1080p.mp4')),'-frames:v','1',
             '-vf','scale=1600:900','-q:v','2',str(FINAL/'Lumap_Journey_Poster.jpg')],'poster-export')
    public_timeline=json.loads((WORK/'timeline.json').read_text().replace(str(ROOT)+'/', 'FILM_WORKSPACE/').replace(str(PROJECT)+'/', ''))
    provenance=[]
    for filename,description in [
        ('native_chain.png','User-supplied native component image; example lesson data; source authenticity requires editorial review'),
        ('paper2galgame-native.png','User-supplied Paper2GalGame player image; source revision and generation provenance require editorial review'),
    ]:
        path=WORK/filename
        if path.exists():provenance.append(dict(file=filename,description=description,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),pixels=list(Image.open(path).size)))
    result=dict(editions=records,voice_stems=checks,audio_peak=float(np.max(np.abs(audio))),
                compositor='Python Pillow NumPy; native-code vector motion and geometry; no browser renderer',
                new_insert_seconds=20,method_gallery_count=17,original_voice_stems_preserved=10,new_kokoro_stems=2,
                native_asset_provenance=provenance,boundaries=public_timeline)
    (FINAL/'journey_video_qa.json').write_text(json.dumps(result,indent=2))
    (FINAL/'SHA256SUMS.txt').write_text('\n'.join(r['sha256']+'  '+r['file'] for r in records)+'\n')
    (FINAL/'JOURNEY_EDITING_GUIDE.txt').write_text('''LUMAP — JOURNEY EDITION
Celestial Frontier

DELIVERY
105.000 seconds / 1920 × 1080 / 30 fps / H.264 / stereo AAC.
Clean master, English burned-caption edition, and English + Chinese optional
subtitle edition. V1 cinematic masters and their published release are untouched.

NEW EDIT
00:32–00:40: an eight-second golden learning-journey insert. A near-thick,
far-thin S-shaped beam, softly moving lesson tags, completion-triggered reveal,
and vertical exploration. The code-authored visualization is explicitly labelled
“Journey motion study”; the native SwiftUI component snapshot is separately
labelled as example lesson data. It is a real component rendered with fixtures,
not a claim that a learner completed those particular lessons.
00:51–01:03: a twelve-second activity gallery spanning all 17 method categories:
guided explanation, worked example, Socratic dialogue, analogy, visual map,
story mode, flash recall, teach-back, simulation, spatial preview, deliberate
practice, reflection, misconception diagnosis, curiosity branch, counterfactual
lab, transfer challenge, and narrated lesson.

The gallery uses captured app activities with example learning content, a real
generated lesson slide, and a real upstream Paper2GalGame WebKit render. The
upstream shot's synthetic/provider provenance is noted in its supplied test
evidence; a real rendering does not by itself prove generation. The gallery
crops away desktop/account information and the historical all-method
picker. Archived examples are visual evidence of the activity gallery; they are
not a claim that a single present-day learner sees every method or future step.
AR remains explicitly labelled as a concept preview. A Paper2GalGame native
capture replaces the earlier illustrative story card when available; see QA JSON.

MOTION
All new animation and compositing use Pillow/NumPy frame-by-frame geometry.
No HTML renderer, slideshow export, or UI-control process is used. Geometric
cuts include depth-plane travel, diagonal light sweeps, focus portals, staggered
panels, vertical travel and directional match cuts. Activity titles remain fixed
and change once at each cut midpoint so they never duplicate or tear.

AUDIO
All ten original Kokoro narration stems survive in full. Two additional lines
use the same offline Kokoro multilingual v1.1 / af_sol voice at speed 0.86.
The original procedural music composition is extended to 105 seconds, with a
new resolving outro and smooth speech ducking. No stock music or voice cloning.
English/Chinese subtitles use the exact revised voice timings.

VERIFICATION
Every edition is fully decoded: 3150 frames. The exported AAC track is decoded
again and each full narration stem is correlated against its delivery interval.
journey_video_qa.json records per-edition hashes, durations and per-stem checks.
SHA256SUMS.txt records the three final video checksums.

REBUILD
Use the product-film local Python environment and Scripts/product-film/build_journey_film.py.
Commands: init, motion, audio, prepare, render, package, validate (or all).
Optional real assets: edit/journey_v2/native_chain.png and
edit/journey_v2/paper2galgame-native.png, with JSON crop sidecars if necessary.
Runtime voice weights, local provider keys and private learner data are omitted.
''')
    print('VOICE AND VIDEO VERIFICATION COMPLETE',flush=True)

def initialize_workspace():
    """Copy text-only templates; never overwrite supplied media or manifests."""
    for source,target in [
        ('motion_timeline.json',ROOT/'edit/motion_timeline.json'),
        ('original_voice_manifest.json',ROOT/'audio/manifest.json'),
        ('11_journey.txt',WORK/'11_journey.txt'),
        ('12_methods.txt',WORK/'12_methods.txt'),
    ]:
        target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists():shutil.copyfile(SCRIPT_DIR/'templates'/source,target)
    print('Local media workspace initialized:',ROOT)
    print('Text templates only. See docs/product-film/README.md for required recordings and voice stems.')


def preflight():
    """Read-only inventory; no network, model call, UI operation or credential read."""
    font(30)
    encoders=subprocess.run([FF,'-hide_banner','-encoders'],capture_output=True,text=True,check=True).stdout
    filters=subprocess.run([FF,'-hide_banner','-filters'],capture_output=True,text=True,check=True).stdout
    for token,listing in [('libx264',encoders),('aac',encoders),(' ass ',filters)]:
        if token not in listing:raise RuntimeError('Required FFmpeg capability unavailable: '+token.strip())
    original.configure(ROOT)
    required=original.required_files()
    manifest=ROOT/'audio/manifest.json';required.append(manifest)
    if manifest.exists():
        for scene in json.loads(manifest.read_text())['scenes']:
            path=Path(scene['file']);required.append(path if path.is_absolute() else ROOT/path)
    for key in ['11_journey','12_methods']:
        required.extend([WORK/(key+'_raw.wav'),WORK/(key+'.txt')])
    required.extend(EVIDENCE/m[2] for m in METHODS if not m[2].startswith('export/'))
    required.append(PROJECT/'docs/images/live-photosynthesis-lesson.png')
    missing=[str(path) for path in required if not path.exists()]
    print(json.dumps(dict(workspace=str(ROOT),font='available',ffmpeg='libx264 / AAC / libass available',
                         full_film_required_files=len(required),missing=missing,
                         native_chain_supplied=(WORK/'native_chain.png').exists(),
                         paper2galgame_supplied=(WORK/'paper2galgame-native.png').exists()),indent=2))
    return not missing


def render_motion_study():
    """An independently reproducible eight-second code animation; no captures or audio."""
    path=WORK/'journey-motion-study.mp4'
    count=write_frames(path,(journey_motion(j/FPS) for j in range(240)))
    assert count==240
    print('Rendered 240 frames / 8 seconds / 1920x1080@30:',path)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description='Code-native Lumap film renderer. Motion needs no private captures; full film requires supplied media.')
    parser.add_argument('task',choices=['init','check','motion','prepare','audio','render','package','validate','all'])
    args=parser.parse_args()
    if args.task=='init':initialize_workspace()
    elif args.task=='check':raise SystemExit(0 if preflight() else 1)
    elif args.task=='motion':render_motion_study()
    else:
        for label,fn in [('audio',prepare_audio),('prepare',prepare_visuals),('render',render_full),('package',package),('validate',validate)]:
            if args.task in (label,'all'):fn()
