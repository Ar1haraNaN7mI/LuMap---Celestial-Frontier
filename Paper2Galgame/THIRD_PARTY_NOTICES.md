# Third-party source and local-installation boundary

## Paper2Galgame

- Repository: https://github.com/Nova42x/paper2galgame
- Verified revision: `da60826012493b16872add56d6c6d412197e6f1c`
- Inspected on: 2026-09-30
- Upstream application license: **no LICENSE file or application license grant found at this revision**.

No license or public redistribution grant is inferred from public availability. Lumap's public repository does not vendor the upstream application's code, compiled JavaScript or original character/background artwork. The user-requested local installer fetches two specific files into ignored directories for local integration. A public binary containing that compiled runtime is a separate distribution decision; obtain permission or an appropriate upstream license before publishing such a binary. The ordinary public source can build without the optional runtime, displaying setup instructions.

## Exact upstream files

| File | SHA-256 |
| --- | --- |
| `components/GameScreen.tsx` | `68643aff56ed8141895616d8e96c8f82e9d5073ce6a9da7b778f2eae9978f4f7` |
| `types.ts` | `901a4d50f65308d134da9a2cc113ebde37041933cb9a3797b4adff3accb5128d` |

The installer fails on a hash mismatch or an absent patch anchor. It does not fetch `services/geminiService.ts`, which contains an upstream embedded credential. It does not clone Git history, download original images, contact image-host URLs or include hosted Google Fonts, Font Awesome, esm.sh or Tailwind scripts.

## Documented local patches

1. Replace the remote character-image table with Lumap's per-session local data images.
2. Add `startIndex` and `onPosition` props to restore/save playback position; retain upstream playback and history logic.
3. Replace the fixed character alt text with the actual guide/speaker name.
4. Add an accessible label to the dialogue-history close button.
5. Compile styles locally with the supplied Tailwind theme and Lumap-owned layout overrides.

`Web/adapter.tsx` is the original Lumap host around the downloaded GameScreen; it passes scripts into the genuine component and sends only bounded progress events to the native bridge. `Native/` contains the original Lumap provider, persistence, extraction, WebKit and SwiftUI adapters.

## Artwork

The integration's default vector guide is original code-defined Lumap artwork. Users can import portraits/backgrounds they are entitled to use. The upstream anime sprites and background are not downloaded. The legacy VoiceClass integration elsewhere in the author's local workspace is separate and is not copied into Lumap.

## Build dependencies

React and React DOM (MIT), Vite (MIT), TypeScript (Apache-2.0) and Tailwind CSS (MIT) are separately licensed packages. Exact direct/transitive dependencies are recorded in `Web/package-lock.json`; installed package license files remain in the local installation. These package licenses do not grant rights to the upstream application or artwork.
