# Functional integrity and complete learning media

30 September 2026 · Celestial Frontier · Lumap 0.3.0

This update makes generated learning activities complete, ties progression to saved assessment evidence, and keeps recovery and Handoff consistent. It preserves the one-section-at-a-time workflow. The separately published [85-second cinematic product film](https://github.com/Ar1haraNaN7mI/LuMap---Celestial-Frontier/releases/tag/product-film-2026-09-30) includes English captions and selectable English/Chinese subtitles.

## What changed

| Area | Observable behavior | Implementation |
| --- | --- | --- |
| Generated activities | Story scenes, simulation instructions, practice problems/examples, Socratic hints and worked predictions actually appear in the activity. Invalid incomplete content produces a recoverable error. | Per-method contracts, required counts and unique interactions; at most one bounded contract repair. |
| Save and completion | A success message appears only after persistence succeeds. A displayed score alone cannot unlock the next section. | Throwing save callbacks on Mac/iOS; current node/method/activity must have an actual assessment; transactional evidence writes. |
| Sequential repair | An old passing answer cannot repair a failure that happened later. The next section cannot be skipped. | Repair evidence must follow the failed attempt; only the next prerequisite-ready section may unlock. |
| Cancellation and revisit | Stop or leaving an activity discards late feedback. Returning to a cached activity restores its own answer and feedback. | Request identities, cancellation checks and scoped restoration. |
| Narrated lessons | Exact completed chapters and valid quiz selections are required. Saving the quiz result alone does not complete the section. | Validate unique chapter/result sets and actual answer correctness; advance after artifact persistence. |
| Knowledge Studio | Sources are deduplicated; answers retain their original question; a late material-course response cannot replace a newly selected project. | Source identity and request goal/plan/language guards. |
| Handoff | Completed progress must be backed by saved evidence, and reopening a document preserves a consistent current method. | Contiguous completed sections; no future activities; compatible historical activities; persisted method cursor. |
| Exports | PPTX preserves legal multilingual text, symbols and emoji. Cancelling MP4 export cleans up the current operation's temporary video. | XML-scalar validation, cooperative export cancellation and scoped cleanup. |

These changes do not add camera supervision, a visionOS app, cloud sync or trained RL weights. AR remains a labeled interactive concept preview. The current adaptive policy uses a model with local constraints and learner evidence.

## Validation

| Check | Result |
| --- | --- |
| Final default macOS suite | **112 tests: 109 passed, 3 explicit opt-ins skipped, 0 failures**; 28 additional tests relative to the previous 84-test suite. |
| Separate live integration suite | **3 passed, 0 failures**: actual-model assessment, source-grounded Q&A/course, researched narrated lesson/video. |
| iOS Simulator build | **Succeeded** after the final shared-store changes. |
| macOS universal Release build | **Succeeded**; packaged app passed strict deep code-signature verification. |
| Native app smoke check | Installed Release opened the existing Personal history and restored a six-chapter narrated section, with the later assigned activity locked until completion. |
| Publication checks | No whitespace errors or exposed credentials in reviewed files; README relative links resolve. |

### Actual provider and media checks

The opt-in checks used the configured `gpt-5.6-sol` Responses route and synthetic/public photosynthesis material. Credentials remained in Keychain. The first run exposed an invalid test-output location outside the signed app's sandbox, and one provider request reached its existing timeout. Re-running with an app-container output directory passed the optional assessment and source-grounded Q&A/course checks. No timeout was hidden by substituting demonstration content.

The fresh lesson contains **6 slides, 2 quizzes and 650 spoken words**. Independent inspection verified all 37 PPTX package members, CRC checks, valid XML and 39 internal relationships. All six chapters' complete narration and quiz content are included in presentation notes. The 7,104-character exported teaching script exactly matches the generated lesson JSON.

The final video is **247.078 seconds**, 1280×720 at 12 fps, with one H.264 video track and one 24 kHz mono AAC audio track. Independent decoding completed all **2,965 video frames and 5,929,840 audio samples**; audio and video durations differ by about 1.7 ms. The clip contains approximately 210.23 seconds of non-silent audio. Kokoro emitted warnings about the `U+025a` phoneme; these media checks establish structural completeness, not a word-by-word pronunciation audit.

The signed live test run used the final activity, narration and workspace validation changes. Two subsequently added cursor/repair-order fixes were verified by the final default suite and both builds; the paid integration suite was not repeated for those local state-only changes.

### Local application packaging

The upstream ONNX framework in this Release build contained two redundant malformed nested symlinks. [`package-local-macos.py`](../../Scripts/package-local-macos.py) removes only those exact aliases from a staged copy, preserves the normal framework links, signs its dependencies and app, and verifies the result before delivery. It refuses to replace an existing destination. This is local ad-hoc signing, not Developer ID notarization.

```sh
python3 Scripts/package-local-macos.py \
  .build/DerivedData/Build/Products/Release/Lumap.app tmp/packaged/Lumap.app
```

### Reproduction

Default checks make no paid model requests:

```sh
xcodebuild -project Lumap.xcodeproj -scheme Lumap -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData test
xcodebuild -project Lumap.xcodeproj -scheme LumapiOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/iOSDerivedData build
```

Run the three integration checks explicitly with a working configured Keychain credential and the local Kokoro voice pack. Signed test hosts must write into their app container:

```sh
TEST_RUNNER_LUMAP_LIVE_POLISH_OUTPUT="$HOME/Library/Containers/com.local.lumap/Data/tmp/live/assessment" \
TEST_RUNNER_LUMAP_LIVE_WORKSPACE_OUTPUT="$HOME/Library/Containers/com.local.lumap/Data/tmp/live/workspace" \
TEST_RUNNER_LUMAP_LIVE_NARRATED_OUTPUT="$HOME/Library/Containers/com.local.lumap/Data/tmp/live/narration" \
xcodebuild -project Lumap.xcodeproj -scheme Lumap -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData \
  -only-testing:LumapTests/LearningAgentStoreTests/testLiveOptionalAssessmentPersistsActualModelFeedback \
  -only-testing:LumapTests/LearningWorkspaceTests/testLiveGroundedQuestionAndSourceOnlyCourse \
  -only-testing:LumapTests/NarratedLessonMVPTests/testLiveResearchedLessonAndCompleteVideo test
```

The observed results are local development evidence, not a production service-level guarantee, a physical-device certification or proof of improved long-term learning outcomes. Provider availability and response latency remain external dependencies.
