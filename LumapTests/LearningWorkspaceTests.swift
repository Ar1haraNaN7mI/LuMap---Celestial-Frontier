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

    @MainActor private func payload(plan: LearningCoursePlan? = nil, session: LearningSessionEvidence = .init(), version: Int = 1,
                                    node: String = "n1", method: String = "guidedExplanation", language: AppLanguage = .english) -> LearningWorkspaceTransfer {
        .init(schemaVersion: version, exportedAt: .now, plan: plan ?? self.plan(), session: session,
              currentNodeID: node, currentMethodID: method, teachingLanguage: language)
    }

    @MainActor private func attempt(id: String = "old-draft", node: String = "n1", method: String = "guidedExplanation", score: Int = 85, nextNode: String = "n2") -> LearningAttemptEvidence {
        .init(id: UUID(), nodeID: node, activityID: id, methodID: method, response: "Carbon comes from carbon dioxide.",
              evaluation: .init(score: score, feedback: "Correct source of carbon", misconceptions: [], nextMethodID: "workedExample", nextNodeID: nextNode, reason: "Try applying the idea"),
              durationSeconds: 20, createdAt: .now)
    }

    private func activity(id: String = "old-draft", node: String = "n1", method: String = "guidedExplanation") -> LearningGeneratedActivity {
        .init(id: id, methodID: method, nodeID: node, title: "Light energy", explanation: "Plants use light energy.",
              prompt: "Where does the carbon come from?", steps: [], examples: [], choices: [], correctChoiceID: nil,
              answerExplanation: "Carbon dioxide", cards: [], concepts: [], connections: [], hints: [], sourceIDs: ["S1"])
    }

    @MainActor private func store() throws -> (LumapStore, ModelContext) {
        let schema = Schema([LearnerProfile.self, SourceRecord.self, InterestEvidence.self, LearningGoal.self,
                             ActivityRecord.self, AssessmentRecord.self, RewardEntry.self, MaterialRecord.self, AppHealthRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let store = try isolatedLumapStore()
        store.configure(context: context)
        return (store, context)
    }

    @MainActor func testGroundedAnswerRejectsInventedQuotesAndUnknownInlineCitations() throws {
        let sources = plan().sources
        let valid = WorkspaceAnswer(answer: "Plants obtain carbon from carbon dioxide [S1].", citations: [.init(sourceID: "S1", quote: "convert carbon dioxide and water into sugars")])
        XCTAssertNoThrow(try LearningWorkspaceService.validateAnswer(valid, sources: sources))
        XCTAssertThrowsError(try LearningWorkspaceService.validateAnswer(.init(answer: "Plants eat soil [S1].", citations: [.init(sourceID: "S1", quote: "Plants eat soil")]), sources: sources))
        XCTAssertThrowsError(try LearningWorkspaceService.validateAnswer(.init(answer: "Supported [S1] and invented [S2].", citations: valid.citations), sources: sources))
        XCTAssertThrowsError(try LearningWorkspaceService.validateAnswer(.init(answer: "An unsupported answer [S1].", citations: [.init(sourceID: "S1", quote: " \n\t ")]), sources: sources))
    }

    @MainActor func testSelectedEvidenceIsBoundedAndDuplicateIDsAreRejected() throws {
        let source = LearningSource(id: "S1", title: "Long document", url: "", excerpt: String(repeating: "x", count: 9000), retrievedAt: .now)
        XCTAssertEqual(try LearningWorkspaceService.boundedSources([source])[0].excerpt.count, 4000)
        XCTAssertThrowsError(try LearningWorkspaceService.boundedSources([]))
        XCTAssertThrowsError(try LearningWorkspaceService.boundedSources([source, source]))
    }

    @MainActor func testSourceCatalogDeduplicatesMaterialsAlreadyInCurrentCourse() throws {
        let original = LearningSource(id: "M-1", title: "My notes", url: "", excerpt: String(repeating: "a", count: 6000), retrievedAt: .now)
        let courseCopy = LearningSource(id: original.id, title: original.title, url: "", excerpt: String(original.excerpt.prefix(4000)), retrievedAt: original.retrievedAt)
        let sources = LearningWorkspaceService.selectableSources(materials: [original], course: [courseCopy] + plan().sources)
        XCTAssertEqual(sources.map(\.id), ["M-1", "S1"])
        XCTAssertEqual(sources[0].excerpt.count, 6000)
        XCTAssertEqual(try LearningWorkspaceService.boundedSources(sources).count, 2)
    }

    @MainActor func testTransferRejectsProgressWithoutSavedPassingEvidence() throws {
        var session = LearningSessionEvidence()
        session.completedNodeIDs = ["n1"]
        session.completedSectionMethods = ["n1": ["guidedExplanation"]]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
        session.attempts = [attempt()]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)), "An unsaved answer cannot complete a section")
        session.savedActivityIDs = ["old-draft"]
        session.attempts = [attempt(score: 40)]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
        session.attempts = [attempt()]
        XCTAssertNoThrow(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
        session.completedSectionMethods = [:]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
    }

    @MainActor func testTransferRejectsSkippingSectionsAndFutureEvidence() throws {
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(node: "n2", method: "workedExample")))
        var session = LearningSessionEvidence()
        session.attempts = [attempt(id: "future", node: "n2", method: "workedExample")]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
        session.savedActivityIDs = ["future"]
        session.completedNodeIDs = ["n2"]
        session.completedSectionMethods = ["n2": ["workedExample"]]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session, node: "n2", method: "workedExample")))
        session = LearningSessionEvidence()
        session.activities["n2:workedExample:\(AppLanguage.english.rawValue)"] = activity(id: "future", node: "n2", method: "workedExample")
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
        session.activities = ["n1:guidedExplanation:\(AppLanguage.english.rawValue)": activity()]
        XCTAssertNoThrow(try LearningWorkspaceTransferCodec.encode(payload(session: session)), "A readable current activity need not have been assessed")
    }

    @MainActor func testTransferRejectsMismatchedCurrentMethodsAndAcceptsUnsavedOptionalAssessments() throws {
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(method: "workedExample")))
        var session = LearningSessionEvidence()
        session.currentMethodID = "workedExample"
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
        session.currentMethodID = "guidedExplanation"
        session.attempts = [attempt(id: "optional-check", method: "teachBack")]
        XCTAssertNoThrow(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
    }

    @MainActor func testTransferRejectsAnActivityIDReusedForDifferentMethods() throws {
        var session = LearningSessionEvidence()
        session.attempts = [attempt(), attempt(method: "teachBack")]
        session.savedActivityIDs = ["old-draft"]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
        session.attempts = [attempt(), attempt(id: "optional-check", method: "teachBack")]
        XCTAssertNoThrow(try LearningWorkspaceTransferCodec.encode(payload(session: session)))
    }

    @MainActor func testTransferPreservesSavedRepairEvidenceWithoutCompletingUnattemptedMethods() throws {
        let course = plan(nodes: [.init(id: "n1", title: "Light", objective: "Explain energy transfer", prerequisiteIDs: [],
                                      estimatedMinutes: 8, methodIDs: ["guidedExplanation", "workedExample"]),
                                  .init(id: "n2", title: "Growth", objective: "Explain carbon source", prerequisiteIDs: ["n1"],
                                      estimatedMinutes: 10, methodIDs: ["teachBack"])])
        var session = LearningSessionEvidence()
        session.attempts = [attempt(score: 40), attempt(id: "repair", method: "workedExample")]
        session.savedActivityIDs = ["old-draft", "repair"]
        session.completedNodeIDs = ["n1"]
        session.completedSectionMethods = ["n1": ["guidedExplanation", "workedExample"]]
        XCTAssertNoThrow(try LearningWorkspaceTransferCodec.encode(payload(plan: course, session: session)))
        session.attempts.removeFirst()
        session.savedActivityIDs = ["repair"]
        XCTAssertThrowsError(try LearningWorkspaceTransferCodec.encode(payload(plan: course, session: session)))
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
        let (store, context) = try store()
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
        XCTAssertTrue(store.currentSectionIsComplete, "Legacy completion is restored from saved assessed evidence")
        XCTAssertEqual(store.rewardBalance, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<RewardEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LearningGoal>()).count, 2)
        let export = try store.exportWorkspaceSession()
        defer { try? FileManager.default.removeItem(at: export) }
        XCTAssertEqual(try store.readWorkspaceSession(from: export).session.attempts.count, 1)
    }

    @MainActor func testImportRestoresSelectedMethodAndItsFeedbackTogether() throws {
        let (store, context) = try store()
        let course = plan(nodes: [.init(id: "n1", title: "Light", objective: "Explain energy transfer", prerequisiteIDs: [],
                                      estimatedMinutes: 8, methodIDs: ["guidedExplanation", "workedExample"])])
        var session = LearningSessionEvidence()
        let cached = activity(id: "worked", method: "workedExample")
        session.activities["n1:workedExample:\(AppLanguage.english.rawValue)"] = cached
        session.attempts = [attempt(id: cached.id, method: cached.methodID, nextNode: "n1")]
        try store.installWorkspaceSession(payload(plan: course, session: session, method: "workedExample"))
        XCTAssertEqual(store.currentMethod, .workedExample)
        XCTAssertEqual(store.activeActivity, cached)
        XCTAssertEqual(store.activityFeedback, session.attempts[0].evaluation)
        XCTAssertEqual(store.evaluatedResponse, session.attempts[0].response)
        let persisted = try JSONDecoder().decode(LearningSessionEvidence.self, from: XCTUnwrap(store.currentGoal?.agentSessionData))
        XCTAssertEqual(persisted.currentMethodID, "workedExample")

        let reopened = try isolatedLumapStore()
        reopened.configure(context: context)
        XCTAssertEqual(reopened.currentMethod, .workedExample)
        XCTAssertEqual(reopened.activeActivity, cached)
        XCTAssertEqual(reopened.activityFeedback, session.attempts[0].evaluation)
    }

    @MainActor func testImportKeepsForeignLanguageCacheWithoutReplacingCurrentTeachingLanguage() throws {
        let (store, _) = try store()
        var session = LearningSessionEvidence()
        session.activities["n1:guidedExplanation:\(AppLanguage.simplifiedChinese.rawValue)"] = activity()
        session.attempts = [attempt()]
        try store.installWorkspaceSession(payload(session: session, language: .simplifiedChinese))
        XCTAssertEqual(store.learningLanguage, .english)
        XCTAssertNil(store.activeActivity)
        XCTAssertNil(store.activityFeedback)
        XCTAssertEqual(store.sessionEvidence.activities.count, 1)
    }

    @MainActor func testInvalidImportLeavesCurrentProjectUnchanged() throws {
        let (store, context) = try store()
        try store.startLearning(topic: "Existing course")
        let original = try XCTUnwrap(store.currentGoal)
        XCTAssertThrowsError(try store.installWorkspaceSession(payload(node: "n2", method: "workedExample")))
        XCTAssertEqual(store.currentGoal?.id, original.id)
        XCTAssertEqual(original.status, "active")
        XCTAssertEqual(try context.fetch(FetchDescriptor<LearningGoal>()).count, 1)
    }

    @MainActor func testReopeningMaterialSynchronizesCachedMethodForExportAndRelaunch() async throws {
        let (store, context) = try store()
        let course = plan(nodes: [.init(id: "n1", title: "Light", objective: "Explain energy transfer", prerequisiteIDs: [],
                                      estimatedMinutes: 8, methodIDs: ["guidedExplanation", "workedExample"]),
                                  .init(id: "n2", title: "Growth", objective: "Explain carbon source", prerequisiteIDs: ["n1"],
                                      estimatedMinutes: 10, methodIDs: ["teachBack"])])
        let firstActivity = activity(id: "first")
        let lastActivity = activity(id: "last", method: "workedExample")
        var session = LearningSessionEvidence()
        session.activities = ["n1:guidedExplanation:en": firstActivity, "n1:workedExample:en": lastActivity]
        session.attempts = [attempt(id: "first"), attempt(id: "last", method: "workedExample", score: 90)]
        session.savedActivityIDs = ["first", "last"]
        session.completedNodeIDs = ["n1"]
        session.completedSectionMethods = ["n1": ["guidedExplanation", "workedExample"]]
        try store.installWorkspaceSession(payload(plan: course, session: session, method: "workedExample"))
        let goal = try XCTUnwrap(store.currentGoal)
        let material = MaterialRecord(fileName: "biology.txt", fileType: "txt", excerpt: course.sources[0].excerpt, citationLabel: "Class notes")
        context.insert(material)
        goal.materialID = material.id
        try context.save()

        try store.startGroundedStudy(from: material)
        XCTAssertEqual(store.currentGoal?.id, goal.id)
        XCTAssertEqual(store.currentMethod, .guidedExplanation)
        XCTAssertEqual(store.sessionEvidence.currentMethodID, "guidedExplanation")
        XCTAssertNil(store.activeActivity, "Switching must clear the other method's activity and feedback")
        XCTAssertNil(store.activityFeedback)
        await store.ensureLearningActivity(method: .guidedExplanation)
        XCTAssertEqual(store.activeActivity, firstActivity)
        XCTAssertEqual(store.activityFeedback?.score, 85)

        let export = try store.exportWorkspaceSession()
        defer { try? FileManager.default.removeItem(at: export) }
        let transferred = try store.readWorkspaceSession(from: export)
        XCTAssertEqual(transferred.currentMethodID, "guidedExplanation")
        XCTAssertEqual(transferred.session.currentMethodID, transferred.currentMethodID)
        XCTAssertEqual(store.rewardBalance, 0)

        let reopened = try isolatedLumapStore()
        reopened.configure(context: context)
        XCTAssertEqual(reopened.currentMethod, .guidedExplanation)
        XCTAssertEqual(reopened.activeActivity, firstActivity)
        XCTAssertEqual(reopened.activityFeedback?.score, 85)
    }

    @MainActor func testChangingAssignedMethodPersistsBeforeAnyActivityGeneration() throws {
        let (store, context) = try store()
        let course = plan(nodes: [.init(id: "n1", title: "Light", objective: "Explain energy transfer", prerequisiteIDs: [],
                                      estimatedMinutes: 8, methodIDs: ["guidedExplanation", "workedExample"])])
        let cached = activity(id: "worked", method: "workedExample")
        var session = LearningSessionEvidence()
        session.activities["n1:workedExample:en"] = cached
        try store.installWorkspaceSession(payload(plan: course, session: session))

        try store.setMethod(.workedExample)
        XCTAssertEqual(store.sessionEvidence.currentMethodID, "workedExample")
        XCTAssertEqual(store.currentGoal?.preferredMethodID, "guidedExplanation", "Resuming a method must not overwrite the learner's preference")
        let export = try store.exportWorkspaceSession()
        defer { try? FileManager.default.removeItem(at: export) }
        let transferred: LearningWorkspaceTransfer
        do {
            transferred = try store.readWorkspaceSession(from: export)
            print("Workspace fixture round-trip: selected=\(store.currentMethod.rawValue), persisted=\(store.sessionEvidence.currentMethodID ?? "nil"), decoded=\(transferred.currentMethodID)")
        } catch {
            let diagnostic = error as NSError
            print("Workspace fixture read failed: domain=\(diagnostic.domain), code=\(diagnostic.code)")
            throw error
        }
        XCTAssertEqual(transferred.currentMethodID, "workedExample")

        let reopened = try isolatedLumapStore()
        reopened.configure(context: context)
        XCTAssertEqual(reopened.currentMethod, .workedExample)
        XCTAssertEqual(reopened.activeActivity, cached)
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
        XCTAssertTrue((2...12).contains(course.nodes.count))
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
