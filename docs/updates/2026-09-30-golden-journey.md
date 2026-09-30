# Golden learning chain, Paper2Galgame and Journey film — 30 September 2026

## Product changes

The golden chain is an additional progress entrance, shared by Learning Studio and Personal archives on macOS and iOS. Its tapered light beam and course cards sway slowly; current and explored cards are clickable, while future titles and methods never enter the view model. Completing the current section does not reveal a new tag until the next section is actually opened. Current cards continue the existing lesson; explored cards show saved answers and feedback without changing the live course cursor. Existing lesson layouts, model-assigned methods and assessed progression are preserved.

Paper2Galgame now uses the actual pinned upstream React GameScreen inside the app's local WKWebView. The original typewriter, Auto, Log, Hide, Exit, emotional portraits and technical notes are connected. Native controls supply custom API configuration, personality, script detail, PDF/text references, custom images and session persistence. The configured model generates a validated source-grounded script; native assessment and saved evidence still control learning progress. The JavaScript bridge never receives the API key and cannot unlock sections. The local installer is required when building from the public source.

The 105-second Journey film adds eight seconds of golden-chain visualization and twelve seconds spanning 17 activity types. Geometric transitions use frame-by-frame code. The native chain and upstream renderer images use clearly identified synthetic example lessons; AR remains a concept preview. Original narration is intact, with two additional Kokoro segments. The separate [animation source bundle](../product-film/README.md) can render its eight-second motion study from a fresh directory.

## Verified results

| Check | Result |
| --- | --- |
| macOS XCTest run | 123 executed: **120 passed, 3 opt-in real-service tests skipped, 0 failures**; three additional protected-file round-trip cases were explicitly excluded while the host was locked. |
| Golden-chain projection and native snapshots | All seven tests passed, including future-node hiding, completion boundary, archive projection and nonblank actual SwiftUI captures. |
| Actual upstream runtime in the signed app test host | Passed: 15-line synthetic fixture, ready handshake, dialogue display, Log, restored line 5, native position callbacks and PNG snapshots. Generation mode was `reused-script-fixture`, not a model call. |
| Python local-installer contracts | All four passed. |
| macOS Release / iOS Simulator | Both final builds succeeded. The locally packaged Mac app passed strict deep code-signature verification; it is an ad-hoc local build, not a notarized public binary. |
| Video | All three editions decoded completely: 3,150 frames, 105 seconds, 1920 × 1080 at 30 fps. All twelve narration intervals were checked against complete stems. |
| Public animation source | Fresh-folder eight-second render passed full decoding: 240 frames, 1080p, 30 fps; no private footage or provider input required. |

The test host now avoids opening the real learner database or starting Home recommendations. Normal Store fixtures use isolated preferences and a nil credential reader; they cannot overwrite the user's provider settings or trigger real Keychain reads. Production continues to use the actual saved provider and Keychain. Native snapshot export avoids FocusState bindings, and the optional WebKit test explicitly manages its offscreen window lifetime.

## Still requires an unlocked host

The computer was locked during final validation. Desktop click-through and a new real-provider Paper2Galgame generation were therefore not completed. Earlier real-provider checks documented in the functional-integrity report remain historical evidence; they are not presented as new Paper2Galgame generation results.

Three Handoff file round-trip tests were explicitly excluded from this run because protected files could not be reread while the host was locked: `testChangingAssignedMethodPersistsBeforeAnyActivityGeneration`, `testImportCreatesSeparateGoalAndDoesNotIssueRewards`, and `testReopeningMaterialSynchronizesCachedMethodForExportAndRelaunch`. The in-memory transfer validation tests passed. Production retains `.completeFileProtectionUnlessOpen` on both platforms, with owner-only directory/file permissions; file protection was not disabled to pass the locked-host tests.

After unlocking, rerun the default full XCTest suite and the optional real-provider Paper2Galgame test described in [the integration README](../../Paper2Galgame/README.md), then verify the installed Studio/Personal click paths. The updated local app is staged separately so the currently running application is not replaced while the desktop is locked.

## Public evidence

- [Golden chain native component](../images/golden-learning-chain.png)
- [Actual upstream renderer](../images/paper2galgame-local-runtime.png)
- [Renderer verification](../examples/paper2galgame-renderer-verification.json)
- [Film export verification](../examples/journey-film-verification.json)
- [Film editing guide](../examples/journey-film-editing-guide.txt)
- [Local integration and provenance](../../Paper2Galgame/README.md)

Upstream code, compiled runtime, third-party anime artwork, private learning data, raw recordings and credentials are excluded from the public repository. The earlier cinematic release remains available unchanged.
