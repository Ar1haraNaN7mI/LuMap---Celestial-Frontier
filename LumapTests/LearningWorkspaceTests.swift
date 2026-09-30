import Foundation
import SwiftData
import XCTest
@testable import Lumap

final class LearningWorkspaceTests: XCTestCase {
    @MainActor private func plan(nodes: [LearningPathNode]? = nil, sourceURL: String = "") -> LearningCoursePlan {
        .init(id: "course", title: "Plant growth", summary: "Evidence-grounded course", goal: "Understand photosynthesis",
              nodes: nodes ?? [.init(id: "n1", title: "Light", objective: "Explain energy transfer", prerequisiteIDs: [], estimatedMinutes: 8, methodIDs: ["guidedExplanation"]),
                               .init(id: "n2", title: "Growth", objective: "Explain carbon source", prerequisiteIDs: ["n1"], estimatedMinutes: 10, methodIDs: ["workedExample"])],
              sources: [.init(id: "S1", title: "Biology notes", url: sourceURL, excerpt: "Plants use light energy to convert carbon dioxide and water into sugars.", retrievedAt: .now)],
              recommendedMethodID: "guidedExplanation", recommendationReason: "Begin with foundations", diagnosticQuestion: "Where does plant carbon come from?", generatedAt: .now, model: "fixture")
    }

    @MainActor private func payload(plan: LearningCoursePlan? = nil, session: LearningSessionEvidence = .init(), version: Int = 1) -> LearningWorkspaceTransfer {
        .init(schemaVersion: version, exportedAt: .now, plan: plan ?? self.plan(), session: session,
              currentNodeID: "n1", currentMethodID: "guidedExplanation", teachingLanguage: .english)
    }

    @MainActor private func attempt(id: String = "old-draft", method: String = "guidedExplanation", score: Int = 85, nextNode: String = "n2") -> LearningAttemptEvidence {
        .init(id: UUID(), nodeID: "n1", activityID: id, methodID: method, response: "Carbon comes from carbon dioxide.",
              evaluation: .init(score: score, feedback: "Correct source of carbon", misconceptions: [], nextMethodID: "workedExample", nextNodeID: nextNode, reason: "Try applying the idea"),
              durationSeconds: 20, createdAt: .now)
    }

    @MainActor func testGroundedAnswerRejectsInventedQuotesAndUnknownInlineCitations() throws {
        let sources = plan().sources
        let valid = WorkspaceAnswer(answer: "Plants obtain carbon from carbon dioxide [S1].", citations: [.init(sourceID: "S1", quote: "convert carbon dioxide and water into sugars")])
        XCTAssertNoThrow(try LearningWorkspaceService.validateAnswer(valid, sources: sources))
        XCTAssertThrowsError(try LearningWorkspaceService.validateAnswer(.init(answer: "Plants eat soil [S1].", citations: [.init(sourceID: "S1", quote: "Plants eat soil")]), sources: sources))
        XCTAssertThrowsError(try LearningWorkspaceService.validateAnswer(.init(answer: "Supported [S1] and invented [S2].", citations: valid.citations), sources: sources))
    }

    @MainActor func testSelectedEvidenceIsBoundedAndDuplicateIDsAreRejected() throws {
        let source = LearningSource(id: "S1", title: "Long document", url: "", excerpt: String(repeating: "x", count: 9000), retrievedAt: .now)
        XCTAssertEqual(try LearningWorkspaceService.boundedSources([source])[0].excerpt.count, 4000)
        XCTAssertThrowsError(try LearningWorkspaceService.boundedSources([]))
        XCTAssertThrowsError(try LearningWorkspaceService.boundedSources([source, source]))
    }

    @MainActor func testTransferRoundTripPreservesNarratedAndRegeneratedActivityEvidence() throws {
        var session = LearningSessionEvidence()
        session.attempts = [attempt(), attempt(id: "narrated-deck", method: "narratedDeck")]
        session.savedActivityIDs = ["old-draft", "n1:narratedDeck"]
        session.completedNodeIDs = ["n1"]
        let encoded = try LearningWorkspaceTransferCodec.encode(payload(session: session))
        let restored = try LearningWorkspaceTransferCodec.decode(encoded)
        XCTAssertEqual(restored.session.attempts.count, 2)
        XCTAssertEqual(restored.session.completedNodeIDs, ["n1"])
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains("apiKey"))
        XCTAssertFalse(text.contains("rewardBalance"))
    }

    @MainActor func testTransferRejectsCyclesUnknownNodesScoresAndPrivateSourceURLs() throws {
        let cyclic = [LearningPathNode(id: "n1", title: "A", objective: "A", prerequisiteIDs: ["n2"], estimatedMinutes: 5, methodIDs: ["guidedExplanation"]),
                      LearningPathNode(id: "n2", title: "B", objective: "B", prerequisiteIDs: ["n1"], estimatedMinutes: 5, methodIDs: ["guidedExplanation"])]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(plan: plan(nodes: cyclic))))
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(plan: plan(sourceURL: "http://127.0.0.1/private"))))
        var invalid = LearningSessionEvidence()
        invalid.attempts = [attempt(score: 101)]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: invalid)))
        invalid.attempts = [attempt(nextNode: "missing")]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: invalid)))
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(version: 2)))
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.decode(Data(repeating: 0, count: LearningWorkspaceTransferCodec.maximumBytes + 1)))
    }

    @MainActor func testImportCreatesSeparateGoalAndDoesNotIssueRewards() throws {
        let schema = Schema([LearnerProfile.self, SourceRecord.self, InterestEvidence.self, LearningGoal.self,
                             ActivityRecord.self, AssessmentRecord.self, RewardEntry.self, MaterialRecord.self, AppHealthRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let store = LumapStore()
        store.configure(context: context)
        try store.startLearning(topic: "Existing algebra project")
        let original = try XCTUnwrap(store.currentGoal)
        var session = LearningSessionEvidence()
        session.attempts = [attempt()]
        session.savedActivityIDs = ["old-draft"]
        session.completedNodeIDs = ["n1"]
        try store.installWorkspaceSession(payload(session: session))
        XCTAssertNotEqual(store.currentGoal?.id, original.id)
        XCTAssertEqual(original.status, "paused")
        XCTAssertEqual(store.activePlan?.title, "Plant growth")
        XCTAssertEqual(store.currentGoal?.progress, 0.5)
        XCTAssertEqual(store.rewardBalance, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<RewardEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LearningGoal>()).count, 2)
        let export = try store.exportWorkspaceSession()
        defer { try? FileManager.default.removeItem(at: export) }
        XCTAssertEqual(try store.readWorkspaceSession(from: export).session.attempts.count, 1)
    }

    /// Opt-in integration test: sends only the named source excerpts to the
    /// authorised provider, and saves generated content without credentials.
    @MainActor func testLiveGroundedQuestionAndSourceOnlyCourse() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["LUMAP_LIVE_WORKSPACE_OUTPUT"] else {
            throw XCTSkip("Set TEST_RUNNER_LUMAP_LIVE_WORKSPACE_OUTPUT to run the live workspace integration check.")
        }
        guard let key = LumapKeychainStore.read(account: "active-provider"), !key.isEmpty else {
            throw XCTSkip("The authorised provider credential is unavailable in this test host.")
        }
        let configuration = ProviderConfiguration(endpoint: "https://api.ikuncode.cc/v1", model: "gpt-5.6-sol", style: .openAIResponses, apiKey: key)
        let sources = [LearningSource(id: "notes-a", title: "Photosynthesis class notes", url: "", excerpt: "Plants use light energy to convert carbon dioxide and water into sugars. The carbon atoms in newly produced sugar come from carbon dioxide. Oxygen is released during photosynthesis. Chloroplasts contain chlorophyll that absorbs light.", retrievedAt: .now),
                       LearningSource(id: "notes-b", title: "Controlled plant experiment", url: "", excerpt: "In a controlled experiment, compare otherwise identical plants exposed to different light intensities. Keep water supply, carbon dioxide availability, species, temperature and measurement duration constant. Measure a consistent indicator of photosynthetic activity. Low light may limit the rate; beyond a point another factor can become limiting.", retrievedAt: .now)]
        let answer = try await LearningWorkspaceService.answer(question: "Where does the carbon in plant sugar come from, and what should I keep constant when testing light intensity?", sources: sources, language: .english, configuration: configuration)
        XCTAssertGreaterThan(answer.answer.count, 80)
        XCTAssertEqual(Set(answer.citations.map(\.sourceID)), Set(sources.map(\.id)))
        let course = try await LearningWorkspaceService.course(topic: "Explain photosynthesis and design a fair experiment testing light intensity", sources: sources, learnerContext: "Teaching language: English. A beginner with 15 minutes. Use concrete examples before equations.", configuration: configuration)
        XCTAssertTrue((4...8).contains(course.nodes.count))
        XCTAssertEqual(course.sources.map(\.id), sources.map(\.id))
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(answer).write(to: output.appendingPathComponent("workspace-grounded-answer.json"))
        try encoder.encode(course).write(to: output.appendingPathComponent("workspace-source-course.json"))
    }
}
