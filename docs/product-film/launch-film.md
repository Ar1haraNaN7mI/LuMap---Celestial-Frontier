# Lumap launch film — hybrid edition

The [119-second hybrid release](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/launch-film-hybrid-2026-10-01) combines expressive animation with genuine Lumap operation at **1920 × 1080, 30 fps**. It restores the first 49 seconds of the 99-second personalized edition, adds a 35-second native-app demonstration, and closes with a light violet/cyan sequence about individual potential, continuity and understanding. The narration addresses the learner rather than explaining the example lesson step by step.

## Watch and download

| File | Contents |
| --- | --- |
| [Launch film](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-hybrid-2026-10-01/Lumap_Launch_Film_Hybrid.mp4) | Picture, narration, original score and sound effects. |
| [No-music edition](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-hybrid-2026-10-01/Lumap_Launch_Film_Hybrid_No_Music.mp4) | The same picture, narration and sound effects. |
| [Editable project](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-hybrid-2026-10-01/Lumap_Launch_Hybrid_Editable_Project.zip) | Remotion source, selected media, captions, separate PCM stems and production notes. |
| [English captions](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-hybrid-2026-10-01/Lumap_Launch_Hybrid_English.srt) | Sidecar SRT; captions are also embedded in both MP4s and off by default. |

## The film

| Time | Picture and purpose |
| --- | --- |
| 0–10 s | Owner-supplied opening about individual strengths and potential. The original 720p image is upscaled without reframing. |
| 10–17 s | Read, listen, ask and try move through the method carousel. |
| 17–30 s | One question branches into possible approaches; sources converge into connected ideas. |
| 30–49 s | A golden learning journey, followed by one continuous transformation through explanation, experiment and Lumi dialogue. |
| 49–60 s | Actual goal entry and submission, generated lesson output, then source selection and excerpt inspection. |
| 60–72 s | The native story player with a labeled example script, followed by actual narrated chapters. |
| 72–84 s | A real quiz response, written reasoning and tutor feedback. |
| 84–98 s | Personalization, curiosity, creativity, critical thinking and room for individual talent. |
| 98–104 s | Actual personal page and saved learning history. |
| 104–112 s | Mac and iPhone clients, then interactive spatial-concept controls. |
| 112–119 s | Understanding, Lumap, Celestial Frontier and the repository link. |

The animated front half uses motion to make ideas memorable. The central demonstration lets the actual interface carry the evidence. Processing waits are shortened and selected results are held for reading. The later personal history is an existing saved record; this edition's demonstration ends on tutor feedback and does not show saving that exact response or unlocking its next activity.

## Edit and render

Unzip the project and run these commands in the directory containing `package.json`. Node.js and npm are required:

```sh
npm ci
npm run studio
```

`src/timeline.ts` defines 15 scene slots and 3,570 frames. The 37–42 and 42–49 second slots form one continuous `AdaptiveContinuum` animation. `ShotcraftScenes.tsx`, `BeginDiscovery.tsx` and the Journey in `Film.tsx` supply the restored opening; `HybridLiveScenes.tsx` supplies the three native-app sequences. `LightBrandScenes.tsx`, the personal-page component in `RealDemoScenes.tsx`, and `RealDeviceShowcase.tsx` supply the ending. The active timeline and scene switch distinguish current scenes from retained earlier implementations.

Native recordings retain 3024 × 1640 pixels, with crop positions expressed in a logical 1920 × 1042 space. The prepared clips use constant 30 fps without optical-flow interpolation. Avenir Next is used on macOS; fallback fonts can change layout elsewhere.

With Python 3 and FFmpeg installed, render and package both editions:

```sh
npx remotion render src/index.ts LumapLaunch rendered.mp4 --props='{"audio":false,"bgm":false}'
python3 finalize.py rendered.mp4 exports
```

Set `FFMPEG` to the executable path if needed. The finalizer copies the shared H.264 picture, mixes the voice/music/SFX stems, encodes each mix once to AAC and adds optional captions. Recheck timing, transitions, captions and audio after any edit.

`src/workbench.ts` also imports 15 clips and separate audio lanes into the [video-shotcraft workbench](https://github.com/Vincentwei1021/video-shotcraft/tree/main/workbench). Its controls support clip order, timing, transforms and audio mixing; internal wording and styling remain in TSX. The archive's README and design notes provide the detailed source map.

## Voice, sound and provenance

The 166-word English direction preserves the first 37 seconds of the earlier personalized narration, then uses complete thoughts about learning and individual potential. Original whole device, closing and brand takes are also retained. New speech uses local Kokoro v1.0 FP32, `af_heart`, with native synthesis rates of 0.94–0.97. The production approach preserves whole phrases without pitch shifting, time stretching or syllable splicing.

The score and harmonic accents are original. Brief key, switch, page and transition Foley comes from the video-shotcraft library under the [Mixkit Sound Effects Free License](https://mixkit.co/license/#sfxFree). The project includes exact source URLs and assembly details in `public/audio/AUDIO_PROVENANCE.json`. Speech recognition checks wording and approximate timing; it does not establish emotional quality or replace listening.

Motion recipes are adapted from [video-shotcraft](https://github.com/Vincentwei1021/video-shotcraft), under Apache-2.0. `SHOTCRAFT_LICENSE.txt` preserves attribution, and `shotcraft-mapping.json` records source references and active adaptations, including the restored carousel, source convergence and inverse-camera journey. Brand assets and the opening were supplied by the owner. Google references informed pacing and the progression from idea to interaction; no Google footage, marks, voice or music is included.

## What the footage establishes

The native footage uses public photosynthesis material from edited sessions. The narrated deck is a separate generated lesson on the same topic. These are actual recorded app states, without a claim that they form one uninterrupted session, demonstrate instant generation or measure learning effectiveness.

The story is a still from the actual native player using an example teaching script; it does not demonstrate a live branch choice or fresh story generation. The early golden path and adaptive illustrations are editorial animation, with native example-route imagery used as a reference. Spatial Vision Lab is an interactive concept preview, without camera tracking or a production headset client. Mac/iPhone transfer uses manual file-based Handoff; automatic cloud sync and trained RL deployment remain future work.

See the [hybrid film verification report](../examples/launch-film-hybrid-verification.json) for this delivery's recorded checks and limitations. App validation is documented separately in the [functional-integrity update](../updates/2026-09-30-functional-integrity.md) and [golden-journey update](../updates/2026-09-30-golden-journey.md); a film revision is not a new full application test run.

The [119-second real-demo release](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/launch-film-demo-2026-10-01) and [99-second personalized release](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/launch-film-personalized-2026-10-01) remain archived unchanged.
