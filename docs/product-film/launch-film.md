# Lumap launch film — real-demo edition

The [119-second release](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/launch-film-demo-2026-10-01) presents Lumap by Celestial Frontier at **1920 × 1080, 30 fps**. It combines the owner's opening, real native-app recordings, code animation, whole-context English narration, physical sound effects and an original score.

## A question becomes a learning experience

| Time | Picture and purpose |
| --- | --- |
| 0–10 s | Owner-supplied opening: individual strengths, potential and Lumap. The original 720p image is upscaled without reframing. |
| 10–17 s | Read, listen, question and try occupy one focal point. |
| 17–33 s | A real typed photosynthesis goal, generated lesson and source inspection. Processing waits are shortened. |
| 33–46 s | A generated visual map, then the actual Paper2Galgame player with a labeled example teaching script. |
| 46–62 s | Actual narrated chapters and a quiz: read the question, choose, then see the confirmation. |
| 62–78 s | Written reasoning, tutor feedback, evidence save and next-step availability; then the native golden journey with example lesson fixtures. |
| 78–94 s | Knowledge, pace and learning method shape an individual path. Curiosity, creativity and critical thinking receive concrete prompts. |
| 94–102 s | An uninterrupted view of actual saved learning history and evidence. |
| 102–111 s | Mac and iPhone clients, followed by actual interactive spatial-concept controls. |
| 111–119 s | Understanding, Lumap, Celestial Frontier and the repository link. |

Three persistent headlines guide the central 61-second case. Native pages settle into a front-on view before interactions. Results remain visible long enough to register, with a consistent light violet/cyan visual treatment through the ending.

## Download

| File | Purpose |
| --- | --- |
| [Launch film](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-demo-2026-10-01/Lumap_Launch_Film_Demo_Edition.mp4) | Music, narration and sound effects. |
| [No-music edition](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-demo-2026-10-01/Lumap_Launch_Film_Demo_Edition_No_Music.mp4) | Identical picture, with narration and sound effects retained. |
| [Editable project](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-demo-2026-10-01/Lumap_Launch_Demo_Editable_Project.zip) | Remotion source, selected media, separate PCM stems and production notes. |
| [English captions](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-demo-2026-10-01/Lumap_Launch_Demo_English.srt) | Optional captions, also embedded in each MP4 and off by default. |

## Edit and render

Unzip the project. With Node.js and npm installed, run inside the directory containing `package.json`:

```sh
npm ci
npm run studio
```

`src/timeline.ts` defines the eight timeline units and 3,570 frames. `RealDemoScenes.tsx` carries the continuous product case; `LightBrandScenes.tsx` contains the method words, personalization and closing; `RealDeviceShowcase.tsx` contains client and spatial-concept views. `Film.tsx` composes the transitions. All native crop coordinates are logical 1920×1042 coordinates; the embedded recordings retain 3024×1640 pixels for sharper close-ups.

The original recorded sessions are edited into related public photosynthesis examples, rather than one uninterrupted session. The rendered result is constant 30fps, with deliberate still holds and no optical-flow interpolation. The archive retains some earlier scene components for editing; `timeline.ts` identifies the active version.

Install Python 3 and FFmpeg, then render and finalize both editions:

```sh
npx remotion render src/index.ts LumapLaunch rendered.mp4 --props='{"audio":false,"bgm":false}'
python3 finalize.py rendered.mp4 exports
```

`finalize.py` copies the shared H.264 picture, mixes the PCM voice/music/SFX stems, encodes each final mix to AAC once and adds English subtitles. Set `FFMPEG` to the executable path if it is not on `PATH`. The project uses Avenir Next on macOS with system sans-serif fallbacks; typography can differ on another OS.

## Audio and synchronization

New narration uses complete contextual takes with the early launch's Kokoro af_heart voice settings: native rate 0.97, with the reflective personalization passage at 0.94. The supplied opening narration and earlier whole method/closing/brand takes are retained. There is no time stretch, pitch shift or syllable splicing. ASR verifies wording and approximate clause timing, not subjective emotional quality.

Recorded UI actions anchor the edit: source inspection around 27.70s, chapter change 49.57s, quiz confirmation 59.40s, reasoning 64.70–66.00s, feedback 68.10s and saved evidence/next-step availability 71.43s. The final reasoning take stays whole; the picture waits before typing so the first phrase and the later unlock both align.

Brief key, switch, page and transition Foley is sourced from the video-shotcraft library with individual Mixkit URLs and license records. The score and harmonic motion accents are original. `public/audio/AUDIO_PROVENANCE.json` records sources; the music-free edition keeps the narration and sound effects.

## Visual workbench

`src/workbench.ts` imports eight shot units with separate narration, SFX and music tracks into the [video-shotcraft workbench](https://github.com/Vincentwei1021/video-shotcraft/tree/main/workbench). From that toolkit's root:

```sh
node workbench/scripts/open.mjs /absolute/path/to/lumap-launch-film
```

The workbench opens at `http://localhost:5198/?import=project`. Reorder, trim, position and scale clips, or remix the audio lanes. Internal scene wording and styling remain in the TSX source; the current unit schemas do not expose every scene element as an inspector field. Re-render and review after editing. The source composition is 119 seconds even if the editor adds spare space after the final clip.

`shotcraft-mapping.json` distinguishes inspected recipes, active narrow adaptations and superseded prototypes. The current restrained scenes are original adaptations; the film does not claim to reproduce every Gallery card. Apache-2.0 attribution is preserved in `SHOTCRAFT_LICENSE.txt`.

## Demonstration scope and provenance

Native footage uses public photosynthesis example material. The generated lesson, source inspection, quiz, tutor feedback, evidence save and next-step availability are actual recorded app states. Paper2Galgame and the golden journey show actual renderers with labeled synthetic teaching fixtures. They do not establish a new live provider request or measured learning outcome.

Spatial controls are a working interactive concept preview, without camera tracking or a headset client. Mac/iPhone continuity refers to available clients and file-based Handoff, not automatic cloud synchronization. The trained RL policy remains a research direction. The personalization animation communicates the product's intended learning approach, not an efficacy study.

Brand assets and the opening were supplied by the owner. The Google references informed pacing and the prompt→construction→result→interaction structure; no Google footage, marks, voice or music is embedded. The archive excludes credentials, private learner files, dependency folders and model weights.

See the [delivery verification](../examples/launch-film-demo-verification.json). Existing app validation is recorded separately in the [functional-integrity update](../updates/2026-09-30-functional-integrity.md) and [golden-journey update](../updates/2026-09-30-golden-journey.md); this film revision does not represent a new full application test run. The [99-second personalized release](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/launch-film-personalized-2026-10-01) remains archived unchanged.
