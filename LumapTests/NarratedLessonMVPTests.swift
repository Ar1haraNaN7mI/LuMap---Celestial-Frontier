import AVFoundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import Lumap

@MainActor
final class NarratedLessonMVPTests: XCTestCase {
    func testCheckpointCannotBeSkippedOrDismissedBeforeAnswering() async throws {
        let fixture = try await validFixture()
        var progress = NarratedLessonProgress(slides: fixture.deck.slides)
        let checkpoint = try XCTUnwrap(fixture.deck.slides.firstIndex { $0.quiz != nil })
        XCTAssertTrue(progress.seek(checkpoint))
        let request = try XCTUnwrap(progress.beginPlayback())
        XCTAssertTrue(progress.finishPlayback(requestID: request))
        let quiz = try XCTUnwrap(progress.pendingQuiz)
        XCTAssertFalse(progress.seek(checkpoint + 1))
        XCTAssertFalse(progress.seek(0))
        XCTAssertNil(progress.beginPlayback())
        XCTAssertFalse(progress.dismissAnsweredQuiz())
        XCTAssertFalse(progress.answerQuiz(optionID: "not-an-option"))
        XCTAssertTrue(progress.quizResults.isEmpty)
        XCTAssertTrue(progress.answerQuiz(optionID: quiz.correctOptionID))
        XCTAssertFalse(progress.answerQuiz(optionID: quiz.options[0].id))
        XCTAssertFalse(progress.seek(checkpoint + 1), "The learner reviews the feedback before navigating.")
        XCTAssertTrue(progress.dismissAnsweredQuiz())
        XCTAssertTrue(progress.seek(checkpoint + 1))
    }

    func testLateAudioCompletionNeverCreditsTheNewChapter() async throws {
        let fixture = try await validFixture()
        var progress = NarratedLessonProgress(slides: fixture.deck.slides)
        let oldRequest = try XCTUnwrap(progress.beginPlayback())
        XCTAssertTrue(progress.seek(1))
        let currentRequest = try XCTUnwrap(progress.beginPlayback())
        XCTAssertFalse(progress.finishPlayback(requestID: oldRequest))
        XCTAssertTrue(progress.narratedSlides.isEmpty)
        XCTAssertTrue(progress.finishPlayback(requestID: currentRequest))
        XCTAssertEqual(progress.narratedSlides, [fixture.deck.slides[1].index])
        XCTAssertFalse(progress.finishPlayback(requestID: currentRequest), "Duplicate completion callbacks must be ignored.")
    }

    func testStoppedNarrationIsNotLearningEvidence() async throws {
        let fixture = try await validFixture()
        var progress = NarratedLessonProgress(slides: fixture.deck.slides)
        let request = try XCTUnwrap(progress.beginPlayback())
        progress.cancelPlayback()
        XCTAssertFalse(progress.finishPlayback(requestID: request))
        XCTAssertFalse(progress.finishPlayback(requestID: nil))
        XCTAssertTrue(progress.narratedSlides.isEmpty)
        XCTAssertFalse(progress.isComplete)
    }

    func testCompletionRequiresEveryFullChapterAndReviewedCheckpoint() async throws {
        XCTAssertFalse(NarratedLessonProgress(slides: []).isComplete)
        let fixture = try await validFixture()
        var progress = NarratedLessonProgress(slides: fixture.deck.slides)
        for index in fixture.deck.slides.indices {
            XCTAssertFalse(progress.isComplete)
            XCTAssertTrue(progress.seek(index))
            let request = try XCTUnwrap(progress.beginPlayback())
            XCTAssertTrue(progress.finishPlayback(requestID: request))
            if let quiz = progress.pendingQuiz {
                XCTAssertFalse(progress.isComplete)
                let option = try XCTUnwrap(quiz.options.first { $0.id != quiz.correctOptionID })
                XCTAssertTrue(progress.answerQuiz(optionID: option.id))
                XCTAssertEqual(progress.quizResults[quiz.id]?.wasCorrect, false)
                XCTAssertFalse(progress.isComplete)
                XCTAssertTrue(progress.dismissAnsweredQuiz())
            }
        }
        XCTAssertTrue(progress.isComplete, "A completed attempt preserves incorrect answers for adaptation.")
        let checkpoint = try XCTUnwrap(fixture.deck.slides.firstIndex { $0.quiz != nil })
        XCTAssertTrue(progress.seek(checkpoint))
        let replay = try XCTUnwrap(progress.beginPlayback())
        XCTAssertTrue(progress.finishPlayback(requestID: replay))
        XCTAssertNil(progress.pendingQuiz, "Replaying does not replace the first assessed answer.")
        XCTAssertTrue(progress.isComplete)
    }

    func testCancelledLessonRequestExitsBeforeProviderWork() async {
        let request = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await NarratedDeckGenerationCoordinator(configuration: nil)
                .generate(.init(topic: "Photosynthesis", languageCode: "en"))
        }
        do {
            _ = try await request.value
            XCTFail("A cancelled lesson request must not start provider or cache work.")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testAOneSlideProviderResponseIsRejected() async throws {
        let fixture = try await validFixture()
        let short = replacingSlides(in: fixture, slides: Array(fixture.deck.slides.prefix(1)))
        XCTAssertThrowsError(try decode(short))
    }

    func testTruncatedNarrationAndMissingRetrievalChecksAreRejected() async throws {
        let fixture = try await validFixture()
        var slides = fixture.deck.slides
        let first = slides[0]
        slides[0] = .init(id: first.id, index: first.index, eyebrow: first.eyebrow, title: first.title,
                          bullets: first.bullets, narration: "A single sentence is not a teaching script.", visual: first.visual, quiz: first.quiz)
        XCTAssertThrowsError(try decode(replacingSlides(in: fixture, slides: slides)))
        slides = fixture.deck.slides.map {
            .init(id: $0.id, index: $0.index, eyebrow: $0.eyebrow, title: $0.title,
                  bullets: $0.bullets, narration: $0.narration, visual: $0.visual, quiz: nil)
        }
        XCTAssertThrowsError(try decode(replacingSlides(in: fixture, slides: slides)))
    }

    func testUnavailableAIProviderDoesNotMasqueradeAsARealLesson() async {
        do {
            _ = try await NarratedDeckGenerationCoordinator(configuration: nil).generate(.init(topic: "Photosynthesis", languageCode: "en"))
            XCTFail("Production generation must never silently substitute the fixed demo.")
        } catch { XCTAssertTrue(error is NarratedDeckGenerationError) }
    }

    func testTeachingScriptExportsEverySlideAndQuiz() async throws {
        let fixture = try await validFixture()
        let script = fixture.deck.teachingScript
        for slide in fixture.deck.slides {
            XCTAssertTrue(script.contains(slide.narration))
            if let quiz = slide.quiz {
                XCTAssertTrue(script.contains(quiz.prompt))
                XCTAssertTrue(script.contains(quiz.explanation))
            }
        }
        XCTAssertEqual(NarratedDeckGenerationRequest(topic: "Piano", languageCode: "en", maximumSlideCount: 1).maximumSlideCount, 5)
    }

    func testDifferentSectionsHaveDifferentNarratedCacheRequests() throws {
        let first = NarratedDeckGenerationRequest(topic: "Energy transfer", languageCode: "en", courseID: "course-a", nodeID: "node-1")
        let second = NarratedDeckGenerationRequest(topic: "Energy transfer", languageCode: "en", courseID: "course-a", nodeID: "node-2")
        let otherCourse = NarratedDeckGenerationRequest(topic: "Energy transfer", languageCode: "en", courseID: "course-b", nodeID: "node-1")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertNotEqual(try encoder.encode(first), try encoder.encode(second))
        XCTAssertNotEqual(try encoder.encode(first), try encoder.encode(otherCourse))
    }

    func testPowerPointContainsEditableSlidesAndFullSpeakerNotes() async throws {
        let fixture = try await validFixture()
        let archive = try LessonPresentationExporter.data(deck: fixture.deck)
        XCTAssertEqual(Array(archive.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
        // Export uses uncompressed ZIP members; the OOXML is directly readable.
        let xml = String(decoding: archive, as: UTF8.self)
        for slide in fixture.deck.slides {
            XCTAssertTrue(xml.contains("ppt/slides/slide\(slide.index).xml"))
            XCTAssertTrue(xml.contains("ppt/notesSlides/notesSlide\(slide.index).xml"))
            XCTAssertTrue(xml.contains(slide.narration.prefix(60)))
        }
        XCTAssertTrue(xml.contains("presentationml.presentation.main+xml"))
        XCTAssertTrue(xml.contains("Teaching script"))
    }

    func testKokoroRendersAllSentencesWhenVoicePackIsInstalled() async throws {
        guard KokoroVoicePackManager.isInstalled() else { throw XCTSkip("Optional 147 MB Kokoro voice pack is not installed in this test container.") }
        let narration = "Photosynthesis turns light energy into chemical energy. Chlorophyll in the leaf absorbs sunlight, and the plant takes carbon dioxide from the air. Water arrives through the roots. Inside chloroplasts, light dependent reactions supply the energy needed to build sugar. Oxygen is released as a byproduct. To test your understanding, explain why covering a leaf changes its ability to make sugar, even when the plant still has water."
        let url = try await NarrationAudioRenderer.render(.init(text: narration, languageCode: "en", voiceID: "af_maple", speakingRate: 1))
        defer { try? FileManager.default.removeItem(at: url) }
        let duration = try await AVURLAsset(url: url).load(.duration)
        // The former premature 1–2 second retrieval timer cannot pass this check.
        XCTAssertGreaterThan(duration.seconds, 15)
        let audio = try AVAudioFile(forReading: url)
        XCTAssertEqual(audio.processingFormat.sampleRate, 24_000)
        XCTAssertGreaterThan(audio.length, 24_000 * 15)
    }

    /// Opt-in, incurs provider tokens and local TTS work. The regular suite never
    /// calls an external model. Output contains no credentials or profile data.
    func testLiveResearchedLessonAndCompleteVideo() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let destination = environment["LUMAP_LIVE_NARRATED_OUTPUT"], !destination.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_LUMAP_LIVE_NARRATED_OUTPUT to run a real researched teaching-video export.")
        }
        let output = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let sources: [LearningSource]
        if let sourcePath = environment["LUMAP_LIVE_NARRATED_SOURCES"] {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sourceData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
            if let plan = try? decoder.decode(LearningCoursePlan.self, from: sourceData) { sources = plan.sources }
            else { sources = try decoder.decode([LearningSource].self, from: sourceData) }
        } else {
            sources = try await LearningResearchService.research(goal: "I want to learn photosynthesis", language: "en")
        }
        XCTAssertFalse(sources.isEmpty)
        guard let key = LumapKeychainStore.read(account: "active-provider"), !key.isEmpty else {
            XCTFail("The authorized provider credential is not available in the test host Keychain.")
            return
        }
        let configuration = ProviderConfiguration(endpoint: "https://api.ikuncode.cc/v1", model: "gpt-5.6-sol", style: .openAIResponses, apiKey: key)
        let response: NarratedDeckGenerationResponse
        if let reusedDeckPath = environment["LUMAP_REUSE_NARRATED_DECK"] {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            response = try decoder.decode(NarratedDeckGenerationResponse.self, from: Data(contentsOf: URL(fileURLWithPath: reusedDeckPath)))
        } else {
        response = try await RemoteNarratedDeckGenerator(configuration: configuration).generate(.init(
            topic: "Photosynthesis: where plant mass and energy come from",
            sourceMaterial: sources.map { "[\($0.id)] \($0.title)\n\($0.url)\n\($0.excerpt)" }.joined(separator: "\n\n"),
            sourceLabel: sources.map { "\($0.title): \($0.url)" }.joined(separator: "\n"), languageCode: "en",
            learnerContext: "Adult beginner who enjoys houseplants and learns well from concrete experiments. Explain carbon dioxide, water, glucose, chlorophyll, chloroplasts, light-dependent reactions and the Calvin cycle without presuming chemistry. Correct the misconception that most plant mass comes from soil. Use a houseplant example and two causal prediction checks.", maximumSlideCount: 6))
        }
        XCTAssertEqual(response.deck.slides.count, 6)
        XCTAssertGreaterThanOrEqual(response.deck.slides.compactMap(\.quiz).count, 2)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(response).write(to: output.appending(path: "Photosynthesis-Live-Lesson.json"), options: .atomic)
        try Data(response.deck.teachingScript.utf8).write(to: output.appending(path: "Photosynthesis-Teaching-Script.txt"), options: .atomic)
        try LessonPresentationExporter.data(deck: response.deck).write(to: output.appending(path: "Lumap-Photosynthesis-Learning-Slides.pptx"), options: .atomic)
        for slide in response.deck.slides {
            let renderer = ImageRenderer(content: NarratedSlideStage(slide: slide, total: response.deck.slides.count, progress: 0).frame(width: 1280, height: 720))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            let imageURL = output.appending(path: "Photosynthesis-Slide-\(slide.index).png")
            let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(imageURL as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(writer, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(writer))
        }
        let videoURL = try await LessonVideoExporter.export(deck: response.deck, languageCode: "en") { progress, status in
            // Status includes only a chapter count; no prompts or credentials.
            print("Narrated video \(Int(progress * 100))%: \(status)")
        }
        let finalVideo = output.appending(path: "Lumap-Photosynthesis-Teaching-Video.mp4")
        if FileManager.default.fileExists(atPath: finalVideo.path) { try FileManager.default.removeItem(at: finalVideo) }
        try FileManager.default.copyItem(at: videoURL, to: finalVideo)
        let asset = AVURLAsset(url: finalVideo)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(videoTracks.count, 1)
        XCTAssertEqual(audioTracks.count, 1)
        XCTAssertGreaterThan(duration.seconds, 120)
        let metadata: [String: Any] = [
            "model": response.modelID, "sourceCount": sources.count,
            "slideCount": response.deck.slides.count, "quizCount": response.deck.slides.compactMap(\.quiz).count,
            "durationSeconds": duration.seconds, "videoTracks": videoTracks.count, "audioTracks": audioTracks.count,
            "narrationWordsPerSlide": response.deck.slides.map { $0.narration.split(whereSeparator: \.isWhitespace).count },
            "generatedAt": ISO8601DateFormatter().string(from: .now)
        ]
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appending(path: "Photosynthesis-Verification.json"), options: .atomic)
    }

    private func validFixture() async throws -> NarratedDeckGenerationResponse {
        try await LocalNarratedDeckGenerator().generate(.init(topic: "Feedback loops", languageCode: "en", maximumSlideCount: 5))
    }

    private func replacingSlides(in response: NarratedDeckGenerationResponse, slides: [NarratedDeckSlide]) -> NarratedDeckGenerationResponse {
        .init(providerID: response.providerID, modelID: response.modelID, deck: .init(
            id: response.deck.id, title: response.deck.title, subtitle: response.deck.subtitle,
            sourceLabel: response.deck.sourceLabel, slides: slides))
    }

    private func decode(_ response: NarratedDeckGenerationResponse) throws -> NarratedDeckGenerationResponse {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try RemoteNarratedDeckGenerator.decodeAndValidate(
            String(decoding: encoder.encode(response), as: UTF8.self), expectedMaximumSlideCount: 6,
            configuredModelID: "configured-test-model", trustedSourceLabel: "verified-source")
    }
}
