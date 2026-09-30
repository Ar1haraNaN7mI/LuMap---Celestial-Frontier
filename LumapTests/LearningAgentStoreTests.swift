import SwiftData
import XCTest
@testable import Lumap

final class LearningAgentStoreTests: XCTestCase {
    @MainActor private func store(useSavedProvider: Bool = false) throws -> (LumapStore, ModelContext) {
        let schema = Schema([LearnerProfile.self, SourceRecord.self, InterestEvidence.self, LearningGoal.self,
                             ActivityRecord.self, AssessmentRecord.self, RewardEntry.self, MaterialRecord.self, AppHealthRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let store = try isolatedLumapStore(useSavedProvider: useSavedProvider)
        store.configure(context: context)
        return (store, context)
    }

    private func plan(_ topic: String) -> LearningCoursePlan {
        LearningCoursePlan(id: UUID().uuidString, title: topic, summary: "A test course", goal: topic,
            nodes: [.init(id: "n1", title: "Foundation", objective: "Explain", prerequisiteIDs: [], estimatedMinutes: 5, methodIDs: ["workedExample"]),
                    .init(id: "n2", title: "Application", objective: "Apply", prerequisiteIDs: ["n1"], estimatedMinutes: 5, methodIDs: ["workedExample"])],
            sources: [.init(id: "S1", title: "Provided material", url: "", excerpt: "Fixture evidence", retrievedAt: .now)],
            recommendedMethodID: "workedExample", recommendationReason: "Test rationale", diagnosticQuestion: "Explain", generatedAt: .now, model: "test-fixture")
    }

    private func activity(_ id: String, node: String) -> LearningGeneratedActivity {
        .init(id: id, methodID: "workedExample", nodeID: node, title: "Solve", explanation: "Fixture content", prompt: "Explain the reasoning",
              steps: ["One", "Two"], examples: ["Example"], choices: [], correctChoiceID: nil, answerExplanation: "Expected reasoning",
              cards: [], concepts: [], connections: [], hints: [], sourceIDs: ["S1"])
    }

    private func evaluation(score: Int) -> LearningEvaluation {
        .init(score: score, feedback: "Rubric feedback", misconceptions: score < 70 ? ["A specific gap"] : [],
              nextMethodID: "workedExample", nextNodeID: score < 70 ? "n1" : "n2", reason: "Follow evidence")
    }

    @MainActor private func recordAssessment(_ store: LumapStore, score: Int, response: String = "Assessed reasoning") {
        guard let activity = store.activeActivity, let method = LearningMethod(rawValue: activity.methodID) else {
            return XCTFail("An assessed activity is required for this fixture")
        }
        let result = evaluation(score: score)
        store.currentGoal?.agentNodeID = activity.nodeID
        store.currentMethod = method
        store.sessionEvidence.activities[store.activityCacheKey(nodeID: activity.nodeID, method: method)] = activity
        store.sessionEvidence.attempts.append(.init(id: UUID(), nodeID: activity.nodeID, activityID: activity.id,
            methodID: activity.methodID, response: response, evaluation: result, durationSeconds: 20, createdAt: .now))
        store.activityFeedback = result
        store.evaluatedResponse = response
    }

    @MainActor func testNewTopicClearsPreviousGeneratedContentAndFeedback() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.activeActivity = activity("a1", node: "n1")
        recordAssessment(s, score: 90)
        try s.startLearning(topic: "Eigenvectors")
        XCTAssertNil(s.activePlan)
        XCTAssertNil(s.activeActivity)
        XCTAssertNil(s.activityFeedback)
        XCTAssertEqual(s.currentGoal?.originalInput, "Eigenvectors")
    }

    @MainActor func testRepeatingMethodAcrossNodesSavesDistinctEvidenceButNotDuplicateRewards() throws {
        let (s, context) = try store()
        try s.startLearning(topic: "Eigenvectors")
        s.activePlan = plan("Eigenvectors")
        s.currentGoal?.totalSteps = 2
        for index in 1...2 {
            s.currentGoal?.agentNodeID = "n\(index)"
            s.activeActivity = activity("a\(index)", node: "n\(index)")
            recordAssessment(s, score: 80)
            XCTAssertTrue(try s.completeActivity(method: .workedExample, artifact: "Valid submitted reasoning"))
            XCTAssertFalse(try s.completeActivity(method: .workedExample, artifact: "Same activity"))
        }
        XCTAssertEqual(s.rewardBalance, 20)
        XCTAssertEqual(s.currentGoal?.progress, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ActivityRecord>()).count, 2)
        XCTAssertEqual(s.sessionEvidence.completedNodeIDs, ["n1", "n2"])
        XCTAssertEqual(s.currentGoal?.status, "completed")
        XCTAssertEqual(s.currentGoal?.currentStep, 2)
        let restored = try isolatedLumapStore()
        restored.configure(context: context)
        XCTAssertNil(restored.currentGoal, "A completed path must not reopen as active on app launch")
        XCTAssertEqual(try context.fetch(FetchDescriptor<LearningGoal>()).first?.status, "completed")
    }

    @MainActor func testSavingAnAttemptDoesNotMistakeFailureForMastery() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.currentGoal?.agentNodeID = "n1"
        s.activeActivity = activity("a1", node: "n1")
        recordAssessment(s, score: 25)
        _ = try s.completeActivity(method: .workedExample, artifact: "An attempted answer")
        XCTAssertEqual(s.currentGoal?.progress, 0)
        XCTAssertTrue(s.sessionEvidence.completedNodeIDs.isEmpty)
        XCTAssertEqual(s.rewardBalance, 10)
    }

    @MainActor func testGeneratedPlanAndActivitiesSurviveResumeWithoutReusingAnotherTopic() throws {
        let (s, context) = try store()
        try s.startLearning(topic: "Photosynthesis")
        let original = try XCTUnwrap(s.currentGoal)
        original.agentPlanData = try JSONEncoder().encode(plan("Photosynthesis"))
        original.agentNodeID = "n1"
        s.sessionEvidence.activities["n1:guidedExplanation:en"] = activity("a1", node: "n1")
        try s.persistLearningAgentState()
        try s.startLearning(topic: "Eigenvectors")
        try s.resumeGoal(original)
        XCTAssertEqual(s.activePlan?.goal, "Photosynthesis")
        XCTAssertEqual(s.sessionEvidence.activities.count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LearningGoal>()).count, 2)
    }

    @MainActor func testSuccessfulRetryUpdatesMasteryWithoutAwardingTwice() throws {
        let (s, context) = try store()
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.currentGoal?.agentNodeID = "n1"
        s.activeActivity = activity("a1", node: "n1")
        recordAssessment(s, score: 25)
        XCTAssertTrue(try s.completeActivity(method: .workedExample, artifact: "First attempt"))
        recordAssessment(s, score: 90)
        XCTAssertFalse(try s.completeActivity(method: .workedExample, artifact: "Corrected explanation"))
        XCTAssertEqual(s.currentGoal?.progress, 0.5)
        XCTAssertEqual(s.rewardBalance, 10)
        let records = try context.fetch(FetchDescriptor<ActivityRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.artifactText, "Corrected explanation")
    }

    @MainActor func testAllAssignedMethodsMustFinishBeforeSectionUnlocks() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        let base = plan("Photosynthesis")
        s.activePlan = LearningCoursePlan(id: base.id, title: base.title, summary: base.summary, goal: base.goal,
            nodes: [.init(id: "n1", title: "Foundation", objective: "Explain and retrieve", prerequisiteIDs: [],
                          estimatedMinutes: 8, methodIDs: ["workedExample", "flashRecall"]), base.nodes[1]],
            sources: base.sources, recommendedMethodID: "workedExample", recommendationReason: "Mix methods",
            diagnosticQuestion: base.diagnosticQuestion, generatedAt: .now, model: base.model)
        s.currentGoal?.agentNodeID = "n1"
        s.currentMethod = .workedExample
        s.activeActivity = activity("a1", node: "n1")
        recordAssessment(s, score: 90)
        XCTAssertFalse(s.canContinueLearningSection)
        XCTAssertThrowsError(try s.selectLearningNode("n2"))
        _ = try s.completeGeneratedActivity(method: .workedExample, artifact: "A correct explanation")
        XCTAssertTrue(s.canContinueLearningSection)
        XCTAssertFalse(s.currentSectionIsComplete)
        XCTAssertEqual(s.currentGoal?.progress, 0)
        XCTAssertThrowsError(try s.selectLearningNode("n2", unlocking: true))
        let a = activity("a2", node: "n1")
        s.currentMethod = .flashRecall
        s.activeActivity = .init(id: a.id, methodID: "flashRecall", nodeID: a.nodeID, title: a.title,
            explanation: a.explanation, prompt: a.prompt, steps: a.steps, examples: a.examples,
            choices: [], correctChoiceID: nil, answerExplanation: a.answerExplanation, cards: [],
            concepts: [], connections: [], hints: [], sourceIDs: a.sourceIDs)
        recordAssessment(s, score: 80)
        _ = try s.completeGeneratedActivity(method: .flashRecall, artifact: "Retrieved the key ideas")
        XCTAssertTrue(s.currentSectionIsComplete)
        XCTAssertEqual(s.currentGoal?.progress, 0.5)
        try s.selectLearningNode("n2", unlocking: true)
        XCTAssertEqual(s.currentLearningNode?.id, "n2")
    }

    @MainActor func testOldPassingEvidenceCannotRepairALaterFailedMethod() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        let base = plan("Photosynthesis")
        s.activePlan = LearningCoursePlan(id: base.id, title: base.title, summary: base.summary, goal: base.goal,
            nodes: [.init(id: "n1", title: "Foundation", objective: "Explain and retrieve", prerequisiteIDs: [],
                          estimatedMinutes: 8, methodIDs: ["workedExample", "flashRecall"]), base.nodes[1]],
            sources: base.sources, recommendedMethodID: "workedExample", recommendationReason: "Mix methods",
            diagnosticQuestion: base.diagnosticQuestion, generatedAt: .now, model: base.model)
        let passingActivity = activity("passing", node: "n1")
        s.activeActivity = passingActivity
        recordAssessment(s, score: 90)
        _ = try s.completeGeneratedActivity(method: .workedExample, artifact: "Earlier correct reasoning")
        s.activeActivity = .init(id: "later-failure", methodID: "flashRecall", nodeID: "n1", title: "Recall",
            explanation: "Recall the concept", prompt: "Explain", steps: [], examples: [], choices: [],
            correctChoiceID: nil, answerExplanation: "Rubric", cards: [], concepts: [], connections: [], hints: [], sourceIDs: ["S1"])
        recordAssessment(s, score: 25)
        _ = try s.completeGeneratedActivity(method: .flashRecall, artifact: "Later incomplete answer")
        s.activeActivity = passingActivity
        s.currentMethod = .workedExample
        XCTAssertFalse(try s.completeGeneratedActivity(method: .workedExample, artifact: "Earlier correct reasoning"))
        XCTAssertFalse(s.currentSectionIsComplete)
        XCTAssertEqual(s.sessionEvidence.completedSectionMethods?["n1"], ["workedExample"])
        XCTAssertThrowsError(try s.selectLearningNode("n2", unlocking: true))
        recordAssessment(s, score: 90, response: "Fresh successful repair after the failed recall")
        _ = try s.completeGeneratedActivity(method: .workedExample, artifact: "New repair")
        XCTAssertTrue(s.currentSectionIsComplete)
        XCTAssertEqual(s.rewardBalance, 20, "Neither re-saving nor repairing duplicates the activity reward")
    }

    @MainActor func testGenerationDeadlineStopsSpinnerAndIgnoresOldRequest() throws {
        let (s, _) = try store()
        let current = UUID()
        s.activityRequestID = current
        s.isGeneratingActivity = true
        s.expireActivityGeneration(requestID: UUID())
        XCTAssertTrue(s.isGeneratingActivity)
        s.expireActivityGeneration(requestID: current)
        XCTAssertFalse(s.isGeneratingActivity)
        XCTAssertNotNil(s.learningError)
        XCTAssertNotEqual(s.activityRequestID, current)
    }

    @MainActor func testResumeRestoresAssessedFeedbackWithoutCallingModelAgain() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        let original = try XCTUnwrap(s.currentGoal)
        let course = plan("Photosynthesis")
        original.agentPlanData = try JSONEncoder().encode(course)
        original.agentNodeID = "n1"
        s.activePlan = course
        s.currentMethod = .workedExample
        let generated = activity("saved-attempt", node: "n1")
        s.sessionEvidence.activities[s.activityCacheKey(nodeID: "n1", method: .workedExample)] = generated
        s.sessionEvidence.attempts.append(.init(id: UUID(), nodeID: "n1", activityID: generated.id,
            methodID: generated.methodID, response: "My assessed reasoning", evaluation: evaluation(score: 65),
            durationSeconds: 30, createdAt: .now))
        try s.persistLearningAgentState()
        try s.startLearning(topic: "Eigenvectors")
        try s.resumeGoal(original)
        XCTAssertEqual(s.currentMethod, .workedExample)
        XCTAssertEqual(s.activeActivity?.id, generated.id)
        XCTAssertEqual(s.activityFeedback?.score, 65)
        XCTAssertEqual(s.evaluatedResponse, "My assessed reasoning")
    }

    @MainActor func testResumeRepairsLegacyFinishedCourseStatus() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        let goal = try XCTUnwrap(s.currentGoal)
        goal.agentPlanData = try JSONEncoder().encode(plan("Photosynthesis"))
        goal.agentNodeID = "n2"
        s.sessionEvidence.completedNodeIDs = ["n1", "n2"]
        try s.persistLearningAgentState()
        XCTAssertEqual(goal.status, "active")
        try s.resumeGoal(goal)
        XCTAssertEqual(goal.status, "completed")
        XCTAssertEqual(goal.progress, 1)
        XCTAssertEqual(goal.currentStep, 2)
    }

    @MainActor func testStopAndNewTopicRejectLateSectionAdaptation() async throws {
        let (s, _) = try store()
        let endpoint = s.providerEndpoint
        s.providerEndpoint = "http://127.0.0.1:1/v1"
        defer { s.providerEndpoint = endpoint }
        try s.startLearning(topic: "Photosynthesis")
        let course = plan("Photosynthesis")
        s.activePlan = course
        s.currentGoal?.agentNodeID = "n1"
        s.currentMethod = .workedExample
        s.sessionEvidence.completedSectionMethods = ["n1": ["workedExample"]]
        s.sessionEvidence.completedNodeIDs = ["n1"]
        var pending: CheckedContinuation<LearningPathNode, Error>?
        s.sectionAdapter = { _, _, _, _ in
            try await withCheckedThrowingContinuation { pending = $0 }
        }
        let oldTask = Task { await s.continueLearningSection() }
        for _ in 0..<100 where pending == nil { await Task.yield() }
        let reply = try XCTUnwrap(pending)
        XCTAssertTrue(s.isAdaptingSection)
        let oldID = s.sectionAdaptationRequestID
        s.cancelLearningGeneration()
        XCTAssertFalse(s.isAdaptingSection)
        XCTAssertNotEqual(s.sectionAdaptationRequestID, oldID)
        try s.startLearning(topic: "Eigenvectors")
        // Simulate a new course's request while the old provider ignores cancellation.
        s.isAdaptingSection = true
        reply.resume(returning: course.nodes[1])
        await oldTask.value
        XCTAssertTrue(s.isAdaptingSection, "Late old completion must not clear a newer request's spinner")
        XCTAssertEqual(s.currentGoal?.originalInput, "Eigenvectors")
        XCTAssertNil(s.activePlan)
        XCTAssertNil(s.learningError)
        s.cancelLearningGeneration()
    }

    @MainActor func testRetryAfterAdaptationFailureRequestsNextSectionAgain() async throws {
        let (s, _) = try store()
        let endpoint = s.providerEndpoint
        s.providerEndpoint = "http://127.0.0.1:1/v1"
        defer { s.providerEndpoint = endpoint }
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.currentGoal?.agentNodeID = "n1"
        s.currentMethod = .workedExample
        s.sessionEvidence.completedSectionMethods = ["n1": ["workedExample"]]
        s.sessionEvidence.completedNodeIDs = ["n1"]
        var requests: [String] = []
        s.sectionAdapter = { _, node, _, _ in
            requests.append(node)
            throw LearningAgentError.invalidOutput("Fixture provider failure")
        }
        await s.continueLearningSection()
        XCTAssertFalse(s.isAdaptingSection)
        XCTAssertNotNil(s.learningError)
        await s.retryLearningGeneration()
        XCTAssertEqual(requests, ["n2", "n2"], "Retry must adapt the hidden next section, not regenerate the finished one")
        XCTAssertEqual(s.currentLearningNode?.id, "n1")
        XCTAssertFalse(s.isGeneratingActivity)
    }


    @MainActor func testRepeatedProviderDeckIDKeepsDistinctSectionEvidenceAndRewards() async throws {
        let (s, context) = try store()
        try s.startLearning(topic: "Feedback loops")
        let base = plan("Feedback loops")
        s.activePlan = .init(id: base.id, title: base.title, summary: base.summary, goal: base.goal,
            nodes: base.nodes.map { .init(id: $0.id, title: $0.title, objective: $0.objective,
                prerequisiteIDs: $0.prerequisiteIDs, estimatedMinutes: $0.estimatedMinutes,
                methodIDs: ["narratedDeck"]) }, sources: base.sources,
            recommendedMethodID: "narratedDeck", recommendationReason: base.recommendationReason,
            diagnosticQuestion: base.diagnosticQuestion, generatedAt: base.generatedAt, model: base.model)
        let deck = try await LocalNarratedDeckGenerator().generate(.init(topic: "Feedback loops", languageCode: "en")).deck
        let answers = deck.slides.compactMap(\.quiz).map {
            NarratedDeckQuizResult(quizID: $0.id, selectedOptionID: $0.correctOptionID, wasCorrect: true)
        }
        s.currentMethod = .narratedDeck
        for nodeID in ["n1", "n2"] {
            s.currentGoal?.agentNodeID = nodeID
            try s.recordNarratedLessonOutcome(deck: deck, narratedSlideNumbers: deck.slides.map(\.index), quizResults: answers)
            XCTAssertTrue(try s.completeGeneratedActivity(method: .narratedDeck, artifact: "Full chapter evidence \(nodeID)"))
            XCTAssertFalse(try s.completeGeneratedActivity(method: .narratedDeck, artifact: "Full chapter evidence \(nodeID)"))
        }
        XCTAssertEqual(s.sessionEvidence.attempts.count, 2)
        XCTAssertEqual(Set(s.sessionEvidence.savedActivityIDs).count, 2)
        XCTAssertEqual(s.rewardBalance, 20)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ActivityRecord>()).count, 2)
        XCTAssertEqual(s.currentGoal?.status, "completed")
    }


    /// Opt-in live check: synthetic learning material only, using the saved provider.
    @MainActor func testLiveOptionalAssessmentPersistsActualModelFeedback() async throws {
        guard let directory = ProcessInfo.processInfo.environment["LUMAP_LIVE_POLISH_OUTPUT"] else {
            throw XCTSkip("Set TEST_RUNNER_LUMAP_LIVE_POLISH_OUTPUT to verify actual assessment generation and evaluation.")
        }
        let (s, context) = try store(useSavedProvider: true)
        guard let provider = s.providerConfigurationForGeneration() else {
            throw XCTSkip("The authorized provider credential is unavailable in this test host.")
        }
        try s.startLearning(topic: "Understand where the carbon in plant sugar comes from")
        let base = plan("Photosynthesis")
        s.activePlan = .init(id: base.id, title: "Carbon through photosynthesis", summary: "Trace carbon into plant sugar.",
            goal: s.activeTopic,
            nodes: [.init(id: "n1", title: "The source of carbon", objective: "Explain why the carbon atoms in new sugar come from carbon dioxide, not soil or light.",
                prerequisiteIDs: [], estimatedMinutes: 5, methodIDs: ["workedExample", "teachBack"]), base.nodes[1]],
            sources: [.init(id: "S1", title: "Synthetic biology teaching notes", url: "",
                excerpt: "Plants use light energy to convert carbon dioxide and water into sugars. The carbon atoms in newly produced sugar come from carbon dioxide taken from the air. Light supplies energy, not carbon atoms. Water supplies hydrogen and oxygen. Soil supplies water and minerals, not the principal carbon source of sugar. Photosynthesis releases oxygen.", retrievedAt: .now)],
            recommendedMethodID: "workedExample", recommendationReason: "Begin with a concrete explanation, then retrieve it.",
            diagnosticQuestion: "Where does the carbon in plant sugar originate?", generatedAt: .now, model: provider.model)
        s.currentGoal?.agentNodeID = "n1"
        s.currentMethod = .workedExample
        let activity = try await s.prepareAssessmentActivity(kind: .theoretical)
        XCTAssertEqual(activity.nodeID, "n1")
        XCTAssertEqual(activity.methodID, LearningMethod.teachBack.rawValue)
        XCTAssertFalse(activity.prompt.isEmpty)
        let record = try await s.evaluateAssessment(kind: .theoretical,
            response: "The carbon atoms in newly formed sugar come from carbon dioxide in the air. Photosynthesis uses light as an energy source to build sugar from carbon dioxide and water. Light is not matter and contributes no carbon atoms; soil minerals are not the principal source of the sugar's carbon. Carbon dioxide is taken into the plant and its carbon is incorporated into sugar.",
            displayedActivity: activity)
        XCTAssertTrue((0...100).contains(try XCTUnwrap(record.score)))
        XCTAssertFalse(record.feedback.isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AssessmentRecord>()).count, 1)
        XCTAssertEqual(s.sessionEvidence.attempts.count, 1)
        XCTAssertEqual(s.rewardBalance, 15)
        XCTAssertTrue(s.sessionEvidence.completedNodeIDs.isEmpty, "An optional check cannot bypass the assigned lesson activities")
        XCTAssertEqual(s.currentGoal?.status, "active")
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(activity).write(to: output.appendingPathComponent("assessment-activity.json"))
        try encoder.encode(s.sessionEvidence).write(to: output.appendingPathComponent("assessment-evidence.json"))
    }


    @MainActor func testAssessmentWithoutProviderExplainsConfigurationInsteadOfEndlessPreparation() async throws {
        let (s, _) = try store()
        let endpoint = s.providerEndpoint
        s.providerEndpoint = "invalid-provider"
        defer { s.providerEndpoint = endpoint }
        try s.startLearning(topic: "Photosynthesis")
        do {
            _ = try await s.prepareAssessmentActivity(kind: .theoretical)
            XCTFail("A missing provider cannot prepare an assessment")
        } catch {
            XCTAssertEqual(error.localizedDescription, LearningSessionError.providerRequired.localizedDescription)
        }
        XCTAssertFalse(s.isPlanning)
        XCTAssertNil(s.activePlan)
    }

    @MainActor func testDisplayFeedbackCannotReplaceAssessedEvidenceWhenSaving() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.currentGoal?.agentNodeID = "n1"
        s.currentMethod = .workedExample
        s.activeActivity = activity("a1", node: "n1")
        s.activityFeedback = evaluation(score: 95)
        XCTAssertThrowsError(try s.completeGeneratedActivity(method: .workedExample, artifact: "Ungraded answer"))
        XCTAssertEqual(s.rewardBalance, 0)
        XCTAssertTrue(s.sessionEvidence.completedNodeIDs.isEmpty)
        recordAssessment(s, score: 25)
        s.activityFeedback = evaluation(score: 95)
        _ = try s.completeGeneratedActivity(method: .workedExample, artifact: "Attempt with actual low assessment")
        XCTAssertEqual(s.currentGoal?.progress, 0, "Only the bound assessment score can count toward completion")
    }

    @MainActor func testCancelledLateFeedbackDoesNotPersistAnAttempt() async throws {
        let (s, _) = try store()
        let endpoint = s.providerEndpoint
        s.providerEndpoint = "http://127.0.0.1:1/v1"
        defer { s.providerEndpoint = endpoint }
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.currentGoal?.agentNodeID = "n1"
        s.currentMethod = .workedExample
        s.activeActivity = activity("a1", node: "n1")
        var pending: CheckedContinuation<LearningEvaluation, Error>?
        s.activityEvaluator = { _, _, _, _, _ in
            try await withCheckedThrowingContinuation { pending = $0 }
        }
        let task = Task { try await s.evaluateActivityResponse("A reasoned answer") }
        for _ in 0..<100 where pending == nil { await Task.yield() }
        let reply = try XCTUnwrap(pending)
        task.cancel()
        reply.resume(returning: evaluation(score: 90))
        do { _ = try await task.value; XCTFail("Cancelled feedback must be discarded") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertTrue(s.sessionEvidence.attempts.isEmpty)
        XCTAssertNil(s.activityFeedback)
        XCTAssertFalse(s.isEvaluatingActivity)
    }

    @MainActor func testReturningToCachedActivityRestoresItsOwnFeedback() async throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.activeActivity = activity("a1", node: "n1")
        recordAssessment(s, score: 80, response: "My saved reasoning")
        try s.setMethod(.teachBack)
        XCTAssertNil(s.activityFeedback)
        await s.ensureLearningActivity(method: .workedExample)
        XCTAssertEqual(s.activeActivity?.id, "a1")
        XCTAssertEqual(s.activityFeedback?.score, 80)
        XCTAssertEqual(s.evaluatedResponse, "My saved reasoning")
    }

    @MainActor func testCompletedSectionCannotJumpPastNextEligibleSection() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        let base = plan("Photosynthesis")
        s.activePlan = .init(id: base.id, title: base.title, summary: base.summary, goal: base.goal,
            nodes: base.nodes + [.init(id: "n3", title: "Advanced", objective: "Transfer", prerequisiteIDs: ["n2"], estimatedMinutes: 5, methodIDs: ["teachBack"])],
            sources: base.sources, recommendedMethodID: base.recommendedMethodID, recommendationReason: base.recommendationReason,
            diagnosticQuestion: base.diagnosticQuestion, generatedAt: .now, model: base.model)
        s.currentGoal?.agentNodeID = "n1"
        s.sessionEvidence.completedNodeIDs = ["n1"]
        s.sessionEvidence.completedSectionMethods = ["n1": ["workedExample"]]
        XCTAssertThrowsError(try s.selectLearningNode("n3", unlocking: true))
        XCTAssertEqual(s.currentLearningNode?.id, "n1")
        try s.selectLearningNode("n2", unlocking: true)
        XCTAssertEqual(s.currentLearningNode?.id, "n2")
    }

    @MainActor func testNarratedOutcomeRequiresValidEvidenceAndWaitsForArtifactSave() async throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Feedback loops")
        let base = plan("Feedback loops")
        s.activePlan = .init(id: base.id, title: base.title, summary: base.summary, goal: base.goal,
            nodes: [.init(id: "n1", title: "Foundation", objective: "Explain", prerequisiteIDs: [], estimatedMinutes: 5, methodIDs: ["narratedDeck"])],
            sources: base.sources, recommendedMethodID: "narratedDeck", recommendationReason: base.recommendationReason,
            diagnosticQuestion: base.diagnosticQuestion, generatedAt: .now, model: base.model)
        s.currentGoal?.agentNodeID = "n1"
        s.currentMethod = .narratedDeck
        let deck = try await LocalNarratedDeckGenerator().generate(.init(topic: "Feedback loops", languageCode: "en")).deck
        let answers = deck.slides.compactMap(\.quiz).map {
            NarratedDeckQuizResult(quizID: $0.id, selectedOptionID: $0.correctOptionID, wasCorrect: true)
        }
        let bad = answers.map { NarratedDeckQuizResult(quizID: $0.quizID, selectedOptionID: "missing-option", wasCorrect: false) }
        XCTAssertThrowsError(try s.recordNarratedLessonOutcome(deck: deck, narratedSlideNumbers: deck.slides.map(\.index), quizResults: bad))
        XCTAssertThrowsError(try s.recordNarratedLessonOutcome(deck: deck, narratedSlideNumbers: deck.slides.map(\.index) + [999], quizResults: answers))
        XCTAssertThrowsError(try s.recordNarratedLessonOutcome(deck: deck, narratedSlideNumbers: deck.slides.map(\.index), quizResults: answers + [answers[0]]))
        XCTAssertTrue(s.sessionEvidence.attempts.isEmpty)
        try s.recordNarratedLessonOutcome(deck: deck, narratedSlideNumbers: deck.slides.map(\.index), quizResults: answers)
        XCTAssertFalse(s.currentSectionIsComplete)
        XCTAssertEqual(s.currentGoal?.progress, 0)
        XCTAssertFalse(s.canContinueLearningSection)
        XCTAssertEqual(s.rewardBalance, 0)
        _ = try s.completeGeneratedActivity(method: .narratedDeck, artifact: "Complete lesson artifact")
        XCTAssertTrue(s.currentSectionIsComplete)
        XCTAssertEqual(s.currentGoal?.status, "completed")
        XCTAssertEqual(s.rewardBalance, 10)
    }

}
