# Lumap launch film — personalized edition

The [99-second launch release](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/launch-film-personalized-2026-10-01) presents Lumap by Celestial Frontier at **1920 × 1080, 30 fps**. It combines the owner's supplied 10-second opening, original code animation, real product captures, English narration and an original score. The opening's 1280 × 720 image is upscaled without reframing.

## New scenes and narrative

| Time | What changes | Purpose |
| --- | --- | --- |
|17–24s|One question becomes a hub for five illustrated learning modes.|Make multiple ways to understand immediately visible.|
|37–49s|A sentence becomes the same continuous light/leaf/energy explanation; audio, a light experiment and Lumi appear within it.|Show cause and effect, with a natural transition between learning methods.|
|70–84s|Knowledge, method and pace reshape a route; curiosity, creativity and critical thinking become concrete activities.|Make full personalization and the development of individual potential explicit.|
|84–99s|The approved Mac/iPhone/spatial-concept and brand ending moves 14 seconds later.|Preserve the conclusion with time for the added purpose sequence.|

Three whole scene narration takes replace the earlier fragmented delivery. All use the same native speech rate, with no time stretching, pitch shift, syllable splicing or initial-word trimming. Approved narration outside the changed windows is retained sample for sample. The score has a new harmonic section and narration-aware levels. Local ASR checks wording and timing; it is not proof of subjective vocal quality.

The [85-second immersive voice edition](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/launch-film-immersive-2026-10-01) remains archived. This revision changes the picture and must not be confused with the previous audio-only update.

## Download and edit

| File | Purpose |
| --- | --- |
| [Launch film](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-personalized-2026-10-01/Lumap_Launch_Film_Personalized.mp4) | Finished MP4 with music, narration and sound effects. |
| [No-music edition](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-personalized-2026-10-01/Lumap_Launch_Film_Personalized_No_Music.mp4) | Same picture, with narration and sound effects retained. |
| [Editable project](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-personalized-2026-10-01/Lumap_Launch_Personalized_Editable_Project.zip) | Remotion source, selected media, separate audio stems and production notes. |
| [English captions](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/download/launch-film-personalized-2026-10-01/Lumap_Launch_Personalized_English.srt) | Optional SRT captions for a compatible player or editor. |

Unzip the project and open a terminal in the directory containing its `package.json`. With Node.js and npm installed:

```sh
npm ci
npm run studio
```

`src/timeline.ts` is the single source of shot timing. `src/Film.tsx` holds the scenes and transitions; `src/ShotcraftScenes.tsx` holds the adapted motion recipes. The redesigned scenes are `BeginDiscovery.tsx`, `AdaptiveContinuum.tsx` and `PersonalizedPotential.tsx`. The adaptive component continues across the 42-second boundary without a new cut. The `public/` directory includes the selected source crops, brand images, caption file and independent `voice.wav`, `music.wav` and `sfx.wav` masters. Edit wording and visual styles in the TSX source; keep timing and narration changes coordinated.

To render and package both editions from that same directory, also install Python 3 and FFmpeg:

```sh
npx remotion render src/index.ts LumapLaunch rendered.mp4 --props='{"audio":false,"bgm":false}'
python3 finalize.py rendered.mp4 exports
```

`finalize.py` copies the same H.264 picture into both editions, mixes the original PCM voice/music/SFX stems, encodes each mix to AAC once and adds optional English subtitles. This avoids the extra AAC priming delay observed in the initial Remotion export. Set the `FFMPEG` environment variable to your FFmpeg executable if it is not on `PATH`.

For an immediate no-music preview, the Remotion render command also accepts `--props=props-no-music.json`; use the finalization step for delivery. The project uses the macOS-installed Avenir Next family with a system sans-serif fallback, so typography can differ on another machine. The archive excludes dependency folders, runtime voice-model weights, credentials and the Google reference video.

## Visual workbench

The project supplies `src/workbench.ts` for the [video-shotcraft workbench](https://github.com/Vincentwei1021/video-shotcraft/tree/main/workbench). After installing that toolkit, run from its root, replacing the path with the extracted film project:

```sh
node workbench/scripts/open.mjs /absolute/path/to/lumap-launch-film
```

The local workbench opens at `http://localhost:5198/?import=project`. It imports **14 shot clips** and separate music, narration and SFX lanes. Clips can be reordered, trimmed, duplicated, repositioned, scaled or played at a different speed; audio tracks can be remixed independently. Current film-unit schemas do not expose internal scene wording or colors as inspector fields; edit those in the source or add a separate text overlay.

The earlier workbench was checked against its original composition; this revision adds new components and a 14-second insert. Re-render and review after editing. The workbench can add spare editing space after the last clip, while the source composition remains 2,970 frames (99 seconds).

## Motion recipes

The included `shotcraft-mapping.json` records the exact source revision, card/demo paths and hashes. These recipes adapt motion structure to Lumap's violet, cyan and gold identity:

| Recipe | Placement | Narrative purpose |
| --- | --- | --- |
| `avatar-bracket-carousel` | 10–17 s | Read, listen, ask and try rotate through a fixed focal point. |
| `bezier-source-converge-merge` | 24–30 s | Materials converge into connected ideas. |
| `basic-3d-scene` | 30–37 s | A moving camera explores completed history and the current learning step. |
| `chip-grid-single-select-blackout` | 56–63 s | An illustrated choice becomes evidence for the next step. |
| `blur-slide` | Narrative text | Coordinated position, blur and opacity settle into readable headlines. |
| `brand-ink-open` | 95.5–99 s | The Lumap wordmark and supplied logo settle into the final lockup. |

`aurora-bloom-bg-flip` and `dataviz-landscape-open` were evaluated and prototyped; the project owner's finished opening replaced those proposed opening scenes. The mapping distinguishes them from recipes used in the final composition. Video-shotcraft adaptations retain their Apache-2.0 attribution in the archive's `SHOTCRAFT_LICENSE.txt`.

## What the images demonstrate

The native app captures use public example material about photosynthesis. The actual lesson, quiz, tutor feedback, evidence save and enabled next-activity state remain visible in the edited recording. Waiting periods are shortened through editing.

Paper2Galgame and the golden-chain snapshot use actual renderers with disclosed synthetic lesson fixtures. The animated path, illustrated experiment and selection sequence are explanatory visuals; they do not establish live inference or a measured learning outcome. Spatial scenes are explicitly labeled concepts. Mac/iPhone continuity refers to the available clients and file-based Handoff, not automatic cloud synchronization. The trained RL policy remains a research direction.

Brand assets and the opening were supplied by the project owner. Narration was synthesized locally with Kokoro v1.0 FP32; the musical score and quiet accents were composed for this film. Audio provenance is included under `public/audio/`. Google DeepMind's launch video informed the visual direction; no Google footage, marks, narration or soundtrack is included.

See the [launch-film verification](../examples/launch-film-personalized-verification.json) for delivery checks. Existing application validation remains documented separately in the [functional-integrity update](../updates/2026-09-30-functional-integrity.md) and [golden-journey update](../updates/2026-09-30-golden-journey.md). The [previous film's editing source](README.md) is retained for archival use.
