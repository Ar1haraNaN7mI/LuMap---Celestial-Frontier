"""Load user-supplied v1 film pieces lazily, preserving their chapter overlays.

No footage or private local paths are bundled. configure() accepts the local
workspace described in docs/product-film/README.md. Covered by the repository
MIT license.
"""
from pathlib import Path
import json
from PIL import Image
import imageio_ffmpeg
from cinematic_transitions import SPECS

W,H=1920,1080
ROOT=None
E=None
shots=[]
HEADERS={}
BADGES={}
CHAPTER_ANCHORS={1:1,2:1,3:3,5:5,6:5,7:7,8:8,9:8,10:10,11:10,12:10,13:13,14:14,15:14}

def configure(workspace):
    global ROOT,E,shots
    ROOT=Path(workspace);E=ROOT/'edit'
    manifest=E/'motion_timeline.json'
    if not manifest.exists():
        raise FileNotFoundError('Missing local film manifest. Run init and supply media as described in docs/product-film/README.md.')
    shots=json.loads(manifest.read_text())['shots']
    if len(shots)-1!=len(SPECS):
        raise ValueError('This edit requires the 17-shot v1 template; adapt the cuts when changing shot count.')
    HEADERS.clear();BADGES.clear()

def path(index):
    s=shots[index]
    if not s['authored']:return E/'motion'/(s['name']+'.mp4')
    value=Path(s['path'])
    return value if value.is_absolute() else ROOT/value

def normalized(raw,index):
    anchor=CHAPTER_ANCHORS.get(index)
    if anchor is None:return raw
    if anchor not in HEADERS:
        # These stationary-header clips are distinct from the moving footage.
        src=E/(shots[anchor]['name']+'.mp4')
        g=imageio_ffmpeg.read_frames(str(src),pix_fmt='rgb24')
        next(g);canonical=next(g);HEADERS[anchor]=canonical[:W*162*3];g.close()
        if anchor==14:BADGES[anchor]=Image.frombytes('RGB',(W,H),canonical).crop((75,965,360,1060))
    result=HEADERS[anchor]+raw[W*162*3:]
    if anchor==14:
        frame=Image.frombytes('RGB',(W,H),result)
        frame.paste(BADGES[anchor],(75,965));return frame.tobytes()
    return result

def decode(index):
    g=imageio_ffmpeg.read_frames(str(path(index)),pix_fmt='rgb24')
    meta=next(g)
    if tuple(meta['size'])!=(W,H):raise ValueError(f'Source video must be {W}x{H}: {path(index)}')
    first=normalized(next(g),index)
    def frames():
        try:
            for raw in g:yield normalized(raw,index)
        finally:g.close()
    return frames(),first

def required_files():
    """Distinct source clips and overlay references for a full-film rebuild."""
    result=[path(i) for i in range(len(shots))]
    result.extend(E/(shots[i]['name']+'.mp4') for i in sorted(set(CHAPTER_ANCHORS.values())))
    return list(dict.fromkeys(result))
