import SwiftData
import XCTest
@testable import Lumap

final class LearningAgentStoreTests: XCTestCase {
    @MainActor private func store() throws -> (LumapStore, ModelContext) {
        let schema = Schema([LearnerProfile.self, SourceRecord.self, InterestEvidence.self, LearningGoal.self,
                             ActivityRecord.self, AssessmentRecord.self, RewardEntry.self, MaterialRecord.self, AppHealthRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let store = LumapStore()
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

    @MainActor func testNewTopicClearsPreviousGeneratedContentAndFeedback() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.activeActivity = activity("a1", node: "n1")
        s.activityFeedback = evaluation(score: 90)
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
            s.activityFeedback = evaluation(score: 80)
            XCTAssertTrue(try s.completeActivity(method: .workedExample, artifact: "Valid submitted reasoning"))
            XCTAssertFalse(try s.completeActivity(method: .workedExample, artifact: "Same activity"))
        }
        XCTAssertEqual(s.rewardBalance, 20)
        XCTAssertEqual(s.currentGoal?.progress, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ActivityRecord>()).count, 2)
        XCTAssertEqual(s.sessionEvidence.completedNodeIDs, ["n1", "n2"])
    }

    @MainActor func testSavingAnAttemptDoesNotMistakeFailureForMastery() throws {
        let (s, _) = try store()
        try s.startLearning(topic: "Photosynthesis")
        s.activePlan = plan("Photosynthesis")
        s.currentGoal?.agentNodeID = "n1"
        s.activeActivity = activity("a1", node: "n1")
        s.activityFeedback = evaluation(score: 25)
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
        s.activityFeedback = evaluation(score: 25)
        XCTAssertTrue(try s.completeActivity(method: .workedExample, artifact: "First attempt"))
        s.activityFeedback = evaluation(score: 90)
        XCTAssertFalse(try s.completeActivity(method: .workedExample, artifact: "Corrected explanation"))
        XCTAssertEqual(s.currentGoal?.progress, 0.5)
        XCTAssertEqual(s.rewardBalance, 10)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ActivityRecord>()).count, 1)
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
        s.activityFeedback = evaluation(score: 90)
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
        s.activityFeedback = evaluation(score: 80)
        _ = try s.completeGeneratedActivity(method: .flashRecall, artifact: "Retrieved the key ideas")
        XCTAssertTrue(s.currentSectionIsComplete)
        XCTAssertEqual(s.currentGoal?.progress, 0.5)
        try s.selectLearningNode("n2", unlocking: true)
        XCTAssertEqual(s.currentLearningNode?.id, "n2")
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
}
