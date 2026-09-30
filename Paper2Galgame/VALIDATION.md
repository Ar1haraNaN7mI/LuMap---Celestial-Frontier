# Local Paper2Galgame validation — 2026-09-30

## Verified integration

- Exact upstream revision: `da60826012493b16872add56d6c6d412197e6f1c`.
- Download allowlist: upstream `GameScreen.tsx` and `types.ts`, SHA-256 checked.
- Production web build completed with pinned React/Vite/Tailwind dependencies.
- Four Python integration-contract tests passed: download boundaries, fail-closed source patches, network-disabled CSP and generated runtime inspection.
- The generated runtime contains no upstream artwork hosts, hosted JavaScript dependencies, Gemini service or provider credentials.
- Actual native WKWebView rendered the installed upstream GameScreen through the production `Paper2GalgameWebView.Coordinator` bridge.
- `ready` handshake, restored position 5, dialogue-history opening and snapshot output all passed, with no reported runtime errors.
- Native snapshots: opening, teaching scene and dialogue history, 2560 × 1440 pixels each.
- Source data for those renderer snapshots is a clearly identified **synthetic biology teaching fixture**. The screenshots prove real local renderer behavior; they are not evidence of a live model call.

The renderer initially exposed a `file://` ES-module CORS incompatibility. The installer now builds a single classic IIFE JavaScript file and local stylesheet. Re-running the same native harness passed without disabling web security or relaxing the Content Security Policy.

## Application tests

`LumapTests/Paper2GalgameTests.swift` adds four offline tests for complete script contracts, safe local session filenames, bounded playback positions and credential-free settings. The root application's final test/build report records the final Xcode results for the full shared-source integration.

`testLivePaper2GalgameGenerationAndRuntimeSnapshot` is opt-in. It generates a real model chapter from synthetic source notes, then renders the exact resulting script in the installed upstream component and verifies Log/progress. This test requires the user's existing Keychain credential and is separately reported by the application test run. Renderer-fixture results must not be described as a successful real-model test.

## Distribution boundary

No original upstream source, compiled runtime or unlicensed artwork is committed. The public installer fetches and builds the requested source locally. The upstream application still has no license at the inspected revision; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
