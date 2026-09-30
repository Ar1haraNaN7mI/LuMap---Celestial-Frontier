# Learning flow polish — 30 September 2026

Team: **Celestial Frontier**

This iteration improves continuity, optional assessment, narrated lessons and recommendation freshness. The main learning contract stays sequential: only the current section and completed history are visible; the model assigns methods; assessed evidence is saved before the next section opens. Trained reinforcement-learning weights and camera-based AR supervision remain future work.

## 1. Course completion and recovery

- Completing all assigned methods now persists the course as `completed`, sets progress to 100%, and stops the completed project reopening as active on the next launch.
- Restoring an older fully completed course repairs its previous `active` status from saved section evidence.
- Resuming a course restores the most recent assessed response and feedback in the learning store.
- Saving a corrected response updates the existing personal evidence record while retaining the single reward for that activity.
- Next-section adaptation owns a cancellable task and request identity. Stopping or switching courses retires that request; late success, failure or cleanup cannot overwrite the newer course.
- Retry after next-section adaptation failure retries adaptation, rather than regenerating the already completed activity.

Validation: focused store regressions cover persisted completion, resume, repair, duplicate rewards, late uncancellable responses and retry routing.

## 2. Optional assessments on Mac and iPhone

- A shared `AssessmentSessionModel` keys each check to goal, plan, section and teaching language.
- Theory and practice have independent drafts and results; practical submission requires prediction, observation and revision.
- Preparation has its own visible loading state, cancellation and retry. Submission failure retains the draft, and the same successful response cannot be submitted again unchanged.
- Switching context clears stale questions, results and drafts. Old asynchronous responses cannot land in a different course.
- Persistence of an assessment, attempt evidence and reward is transactional; cancellation is checked before saving.
- The iPhone Personal page now offers **Check your understanding** and explicit **Resume learning** buttons. Resume switches back to Learn even when the store was already on the studio section.
- Recent assessment history is scoped to the current learning goal. Optional checks inform adaptation but do not bypass assigned activities.

Validation: six asynchronous assessment-state tests; live model generation and assessment; native iPhone Simulator navigation and error-state inspection. The simulator did not have a provider key; real provider behavior was tested separately on macOS with synthetic notes.

## 3. Narration, quizzes and evidence

- An unanswered checkpoint remains attached to its chapter until an answer is selected and its feedback reviewed.
- Audio completion carries a request ID. Stops, chapter changes, stale callbacks and duplicate callbacks cannot credit another chapter.
- Saving requires every full chapter and every valid, reviewed quiz response. Incorrect first answers remain available for adaptation.
- Identical provider deck IDs in different sections no longer collide in saved evidence or rewards.
- Voice availability can refresh after Kokoro installation without regenerating the lesson.
- Cancelled generation checks cancellation before provider work and before writing the lesson cache.

Validation: five new playback/generation regressions plus a cross-section deck-identity regression. The full long-form video export was not repeated in this iteration; the existing six-slide example remains the earlier media validation evidence.

## 4. Recommendations follow updated context

- Confirming/removing interests, saving a profile, changing language or provider, switching goals, importing a course, or saving new learning evidence invalidates the old suggestion cache.
- Discovery observes a published context revision and refreshes when visible. Invalidation itself makes no network request.
- A forced refresh supersedes an in-flight request. Old success, error and cleanup are ignored using the request ID, revision and cancellation state.
- Explicit “not interested” exclusions survive context edits.

Validation: six offline tests use controlled responses, including deliberately late replies, without reading credentials or spending model tokens.

## 5. AR preview stays interactive without false assessment

The iPhone spatial preview still supports its visual interaction and **preview notes**. Notes can be shared, but the preview no longer calls the real practical-assessment API or grants assessment scores, progress or Lumens. This remains a camera-off concept demonstration.

## Verification results

| Check | Result |
| --- | --- |
| macOS build | Passed |
| macOS default XCTest suite | **84 total; 81 passed, 3 opt-in tests skipped, 0 failures** |
| iOS Simulator build | Passed |
| Live optional-assessment integration | **1 passed; 0 skipped; 0 failures**, about 75.6 seconds |
| Actual model result | Topic-specific photosynthesis teach-back question; **90/100** with substantive feedback; one assessment and one attempt saved, 15 Lumens, no section unlocked |
| iPhone UI spot check | Personal → Check understanding; Personal → Resume learning → Learn; readable failure state without a configured provider |
| Local Mac app update | Bundle updated, signature verified and launched; user completed macOS Keychain confirmation; existing goal, assigned method and saved progress restored; live personalized suggestions returned |

The live test used synthetic biology notes and a synthetic answer, not a learner's private material. It validates the generation → evaluation → persistence path, not pedagogical effectiveness or clinical/formal certification. Source-only teaching stayed on the supplied evidence.

Inspect the actual [generated assessment](../examples/learning-polish-assessment.json) and [saved evidence](../examples/learning-polish-evidence.json). Neither contains credentials or personal learner data.

## Reproduce

```sh
xcodegen generate
xcodebuild -project Lumap.xcodeproj -scheme Lumap \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData test

xcodebuild -project Lumap.xcodeproj -scheme LumapiOS \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/iOSDerivedData build

# Explicit opt-in; uses the saved provider and can consume provider quota.
TEST_RUNNER_LUMAP_LIVE_POLISH_OUTPUT="$PWD/tmp/live-assessment" \
  xcodebuild -project Lumap.xcodeproj -scheme Lumap \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  -only-testing:LumapTests/LearningAgentStoreTests/testLiveOptionalAssessmentPersistsActualModelFeedback test
```

## Short manual walkthrough

1. Confirm an interest in the workspace, return to Discover, and inspect newly generated suggestions. Refresh twice; the older response must not replace the current batch.
2. Start one project, start another, then use **Personal → Resume learning** on iPhone to return to the first.
3. In **Check understanding**, try Theory and Practice, cancel preparation, retry, submit an explanation, then inspect the saved feedback. Change courses while preparing: no previous question should appear.
4. Play a narrated lesson to a quiz. Chapter navigation remains locked through answer review; stopping or seeking does not count as listening. Finish all chapters and checks before saving.
5. Complete the final assigned section and inspect the project's completed state. Reopen the app: it must not be restored as an active unfinished project.
6. Open the AR preview, capture a note and share it. Verify that this interaction changes no assessment score or reward balance.
