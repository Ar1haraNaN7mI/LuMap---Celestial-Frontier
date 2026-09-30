# Lumap product film: code animation and compositing

The Journey Edition uses Python, Pillow and NumPy to draw a golden learning path,
animate lesson tags, and compose geometric transitions around app footage.
FFmpeg encodes the result. There is no HTML renderer, slideshow export or desktop
automation in this bundle.

**The eight-second motion study can be rendered independently. Rebuilding the
complete 105-second film requires locally supplied footage and voice stems.**
Those raw recordings, runtime voice weights and local production files are not
part of this repository. The published video is the finished delivery, not a
replacement for its individual editable source clips.

## Render the independent golden-chain animation

From the repository root, on macOS with Python 3.9 or later:

```sh
python3 -m venv Scripts/product-film/.venv
Scripts/product-film/.venv/bin/python -m pip install -r Scripts/product-film/requirements.txt
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py motion
```

The output is
`Scripts/product-film/.local/edit/journey_v2/journey-motion-study.mp4`:
240 frames, 1920 × 1080, 30 fps, eight seconds, without audio.

This command draws every frame from code. It needs no app capture, API key,
provider account, browser, voice model or learner data. It depicts an explicitly
labelled **motion study**, with invented example lesson text: the current tag
changes to explored, then the next tag appears, and the camera scrolls along the
path. This animation alone does not demonstrate persistence or model inference.

The default typeface is the macOS system-installed Avenir Next collection. Fonts
are not distributed. To use a font you have installed on another platform:

```sh
export LUMAP_FILM_FONT="/path/to/your/font.ttf"
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py motion
```

A custom font uses face index `0` by default. Set
`LUMAP_FILM_FONT_INDEX_REGULAR` and `LUMAP_FILM_FONT_INDEX_BOLD` for a collection.
Different fonts can change text layout; inspect the frames after replacing one.
The burned-caption ASS template also names Avenir Next; change that template or
configure an appropriate installed fallback when working off macOS.

## What the code does

| File | Responsibility |
| --- | --- |
| [build_journey_film.py](../../Scripts/product-film/build_journey_film.py) | Golden S-curve, tapered beam and glow, restrained tag sway, completion reveal, method gallery, audio timeline, subtitles, export and verification. |
| [cinematic_transitions.py](../../Scripts/product-film/cinematic_transitions.py) | Rounded portals, depth planes, focus reveals, directional travel, diagonal masks and staggered panel cuts. |
| [film_sources.py](../../Scripts/product-film/film_sources.py) | Lazy loading of the original 17 source shots and their stationary chapter overlays. |
| [compose_music_85.py](../../Scripts/product-film/compose_music_85.py) | Original procedural music composition, extended to 105 seconds by the editor. No sampled music is included. |
| [templates](../../Scripts/product-film/templates) | Relative-path shot plan, voice timing/text, caption styling, Chinese translation and the two added voice scripts. No recordings or credentials. |

The transition compositor evaluates geometry per frame. It uses quintic easing,
perspective transforms, feathered masks and restrained focus changes. Method
titles stay fixed during each cut and change once at the midpoint, preventing
duplicate moving text. The golden beam becomes thinner in the distance; lesson
tags move slowly, and future tags remain absent until the illustrated completion.

## Rebuild or adapt the full film

The default private media workspace is `Scripts/product-film/.local/`, which is
ignored by Git. You can choose a separate local directory:

```sh
export LUMAP_FILM_ROOT="/absolute/path/to/your/local-film-workspace"
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py init
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py check
```

`init` copies text-only templates and never overwrites an existing manifest.
`check` inventories the full-film inputs and checks the font plus FFmpeg's
`libx264`, AAC and `libass` support. It exits with a nonzero status while required
media is absent; this is expected for a fresh clone. It makes no network requests,
model calls or credential reads.

Supply these local inputs before the full render:

| Local input | Expected form |
| --- | --- |
| `edit/motion_timeline.json` | The supplied 17-shot plan, with workspace-relative authored paths. Adapt the editor if changing shot count or durations. |
| `edit/motion/<shot-name>.mp4` | The prepared moving-camera clips for every non-authored shot. Each is 1920 × 1080 at 30 fps and at least the specified duration. |
| `edit/motion_titles/*.mp4` | The three authored pieces named in the template: continuous introduction, adaptive-path title, and closing sequence. |
| `edit/<anchor-shot>.mp4` | Original stationary-overlay references for `s04_discover`, `s06_sources`, `s08_save`, `s10_question`, `s11_lesson`, `s13_check`, `s16_devices` and `s17_spatial_mac`. These supply stable chapter headers. |
| `audio/manifest.json` | The ten original voice texts, source-file names and timings. Relative file paths resolve inside the workspace. |
| `audio/01_question.wav` through `audio/10_close.wav` | Ten complete mastered narration stems, mono PCM 16-bit at 48 kHz. The template supplies their exact timing; substitute stems only after updating durations and checking their allocated scene windows. |
| `edit/journey_v2/11_journey_raw.wav` and `12_methods_raw.wav` | The two added complete voice recordings, matching the supplied text files. They are converted to mono 48 kHz during mastering. Their lengths must fit their eight- and twelve-second windows. |
| Repository `docs/test-evidence/2026-09-30/` images | Archived app activity examples used by the method gallery. Crops exclude the desktop, account identity, historical method picker and future-step list. Keep this repository structure or change `EVIDENCE`. |
| Repository `docs/images/live-photosynthesis-lesson.png` | A real generated lesson slide used in the narrated-method gallery beat. |
| Optional `edit/journey_v2/native_chain.png` | A real native learning-chain component snapshot. The delivered film uses real SwiftUI rendered with synthetic example lesson data, which the video labels explicitly. |
| Optional `edit/journey_v2/paper2galgame-native.png` | A real upstream Paper2GalGame player snapshot. The delivered film uses its actual WebKit renderer with a synthetic lesson fixture; that image is not evidence of a live model generation. |

The two optional snapshot inputs support JSON sidecars named `native_chain.json`
and `paper2galgame-native.json`, containing `{"crop": [left, top, right, bottom]}`.
Coordinates must come from inspecting the supplied capture. Omit the sidecar to
show the complete image. With no native chain image, the entire chain insert
remains a labelled motion study. With no upstream player snapshot, the gallery
uses the repository's historical story-mode example and does not add the
Paper2GalGame-specific editorial title.

The public package consumes WAV files; it does not bundle a speech synthesis
engine or download voice weights. The delivered new lines were synthesized
offline using Kokoro multilingual v1.1, `af_sol`, at speed `0.86`. Lumap's existing
[voice-pack installer](../../Scripts/install-kokoro-voice-pack.sh) is separate
from this film compositor. Other narration is possible, but its timings must be
rechecked and its usage rights are the contributor's responsibility.

Once the required media is present:

```sh
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py audio
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py prepare
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py render
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py package
Scripts/product-film/.venv/bin/python Scripts/product-film/build_journey_film.py validate
```

`all` runs the same sequence. These commands produce new files under the local
workspace's `final/journey_v2/`; they do not rewrite the original cinematic
masters. They generate a clean master, an English burned-caption edition, an
English/Chinese selectable-caption edition, SRT files, a poster, an editing
guide, SHA-256 checksums and a verification JSON.

The exact prepared clips and original voice stems are not included, so a fresh
clone cannot reproduce the complete published film by running `all` alone.
Different encoders, fonts and supplied footage can also change the bytes and
visuals. This is an editable animation/compositing source bundle, not a promise
of a byte-identical rebuild from the finished MP4.

## Timing and evidence

The delivered edit preserves all ten original voice stems in full. It inserts
eight seconds at the original 32-second boundary and twelve seconds at the
original 43-second boundary, producing a 105-second film. The first added line
starts at 32.5 seconds; the second starts at 51.5 seconds after the first insert.
Downstream narration, source shots and EN/ZH subtitles share the same revised
timeline. Both insertions occur in gaps between the original spoken segments.

The gallery covers all 17 method categories. Its footer identifies example
learning content; AR remains a concept preview. The native chain and upstream
player snapshots demonstrate real UI rendering with fixtures, and the motion
study demonstrates the visual progression. None of these images alone proves a
trained recommendation model, a provider response, or an actual learner outcome.

`validate` fully decodes all three editions and checks 3,150 frames, 105 seconds,
1080p and 30 fps. It decodes the delivered AAC track again and compares each
complete narration interval with its WAV stem. It also records the supplied
native-image hashes/provenance and produces a visual contact sheet. Review that
contact sheet and listen to the film; automated checks do not replace visual or
editorial inspection. The verifier expects the fixed Journey Edition timeline;
update those assertions when making a different-duration edit.

The scripts are covered by the repository [MIT license](../../LICENSE).
Pillow, NumPy, imageio-ffmpeg/FFmpeg, fonts, voice models and any supplied media
retain their own licenses. This bundle redistributes no system fonts, model
weights, API keys, private learner material or unreviewed raw recordings.
