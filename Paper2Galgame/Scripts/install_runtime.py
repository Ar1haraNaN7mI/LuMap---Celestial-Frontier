#!/usr/bin/env python3
"""Build the user's local upstream Paper2Galgame renderer. No provider files or artwork are fetched."""
from pathlib import Path
import hashlib,json,shutil,subprocess,urllib.request,re,os
ROOT=Path(__file__).resolve().parents[1]
REVISION='da60826012493b16872add56d6c6d412197e6f1c'
FILES={'components/GameScreen.tsx':'68643aff56ed8141895616d8e96c8f82e9d5073ce6a9da7b778f2eae9978f4f7','types.ts':'901a4d50f65308d134da9a2cc113ebde37041933cb9a3797b4adff3accb5128d'}
def patch_game(source):
    # Entire image table is replaced, never contacting the original artwork hosts.
    source,count=re.subn(r'const CHARACTER_IMAGES: Record<string, string> = \{.*?\n\};','const CHARACTER_IMAGES: Record<string, string> = {};',source,count=1,flags=re.S)
    if count!=1: raise ValueError('Upstream image-table patch failed')
    replacements={
      '  onExit: () => void;':'  onExit: () => void;\n  startIndex: number;\n  onPosition: (index: number) => void;',
      '({ script, title, onExit })':'({ script, title, onExit, startIndex, onPosition })',
      'useState(0);':'useState(startIndex);',
      '  const currentLine = script[currentIndex];':'  useEffect(() => { onPosition(currentIndex); }, [currentIndex]);\n  const currentLine = script[currentIndex];',
      "return CHARACTER_IMAGES[key] || CHARACTER_IMAGES['normal'];":"return window.lumapPaperSprites?.[key] || window.lumapPaperSprites?.normal || '';",
      'alt="Murasame"':'alt={currentLine.speaker}',
      '<button onClick={() => setShowLog(false)}':'<button aria-label="Close dialogue history" onClick={() => setShowLog(false)}',
    }
    for old,new in replacements.items():
        if old not in source: raise ValueError('Upstream patch anchor missing')
        source=source.replace(old,new,1)
    # Keep local fonts and own CSS; no URLs survive the downloaded component.
    if re.search(r'https?://',source): raise ValueError('Unexpected remote URL remains')
    return source

def main():
    build=ROOT/'.local-build'
    build.mkdir(exist_ok=True)
    for file in (ROOT/'Web').iterdir():
        if file.is_file(): shutil.copy2(file,build/file.name)
    for name,digest in FILES.items():
        request=urllib.request.Request(f'https://raw.githubusercontent.com/Nova42x/paper2galgame/{REVISION}/{name}',headers={'User-Agent':'Lumap-local-integration/1.0'})
        with urllib.request.urlopen(request,timeout=30) as response: data=response.read(200_000)
        if hashlib.sha256(data).hexdigest()!=digest: raise ValueError('Upstream integrity mismatch: '+name)
        text=data.decode('utf-8')
        if name.endswith('GameScreen.tsx'): text=patch_game(text)
        path=build/'upstream'/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    npm=shutil.which('npm')
    if not npm: raise SystemExit('Install Node.js/npm to compile the local renderer.')
    environment = dict(os.environ, npm_config_cache=str(build/'npm-cache'))
    subprocess.run([npm,'ci','--ignore-scripts','--no-audit','--no-fund'] if (build/'package-lock.json').exists() else [npm,'install','--ignore-scripts','--no-audit','--no-fund'],cwd=build,check=True,env=environment)
    subprocess.run([npm,'run','build'],cwd=build,check=True,env=environment)
    runtime=ROOT/'Resources'/'Runtime'
    if runtime.exists(): shutil.rmtree(runtime)
    shutil.copytree(build/'dist',runtime)
    shutil.copy2(build/'index.html', runtime/'index.html')
    shutil.copy2(build/'compiled.css', runtime/'style.css')
    manifest={'upstream':'https://github.com/Nova42x/paper2galgame','revision':REVISION,'downloadedFiles':FILES,'adapterVersion':1,'credentialBearingServiceIncluded':False,'upstreamArtIncluded':False}
    (runtime/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
    notices=[]
    for package in ['react','react-dom','tailwindcss']:
        license_path=build/'node_modules'/package/'LICENSE'
        if license_path.exists(): notices.append(package+'\n'+license_path.read_text())
    (runtime/'THIRD_PARTY_LICENSES.txt').write_text('\n\n'.join(notices)+'\n')
    print('Installed genuine upstream GameScreen runtime at '+str(runtime))
    print('Local integration only: upstream source is excluded from Git; no application license was provided upstream.')
if __name__=='__main__': main()
