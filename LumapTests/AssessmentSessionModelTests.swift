import XCTest
@testable import Lumap

@MainActor final class AssessmentSessionModelTests: XCTestCase {
    private let goalID = UUID()

    private func context(node: String = "n1", language: String = "en") -> AssessmentSessionContext {
        .init(goalID: goalID, planID: "course", nodeID: node, language: language)
    }

    private func activity(_ id: String, node: String = "n1", method: String = "teachBack") -> LearningGeneratedActivity {
        .init(id: id, methodID: method, nodeID: node, title: "Explain the evidence", explanation: "Research context",
              prompt: "Explain why this works", steps: [], examples: [], choices: [], correctChoiceID: nil,
              answerExplanation: "Reason from the evidence", cards: [], concepts: [], connections: [], hints: [], sourceIDs: ["S1"])
    }

    private func record() -> AssessmentRecord {
        .init(goalID: goalID, kind: .theoretical, status: "reviewed", score: 82,
              feedback: "A reasoned explanation", evidenceSummary: "AI rubric /100")
    }

    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Assessment state did not settle", file: file, line: line)
    }

    func testLatePreparationCannotReplaceAnotherKindOrClearItsLoadingState() async throws {
        let model = AssessmentSessionModel()
        var theory: CheckedContinuation<LearningGeneratedActivity, Error>?
        var practice: CheckedContinuation<LearningGeneratedActivity, Error>?
        model.prepare(context: context()) { _ in
            try await withCheckedThrowingContinuation { theory = $0 }
        }
        await waitUntil { theory != nil }
        XCTAssertTrue(model.preparing)
        model.selectedKind = .practical
        model.prepare(context: context()) { _ in
            try await withCheckedThrowingContinuation { practice = $0 }
        }
        await waitUntil { practice != nil }
        theory?.resume(returning: activity("old-theory"))
        // Let the canceled continuation resume while the new request remains suspended.
        await Task.yield()
        await Task.yield()
        XCTAssertNil(model.theoryActivity)
        XCTAssertTrue(model.preparing)
        practice?.resume(returning: activity("practice", method: "transferChallenge"))
        await waitUntil { !model.preparing }
        XCTAssertEqual(model.practicalActivity?.id, "practice")
        XCTAssertNil(model.errorMessage)
    }

    func testSectionAndLanguageChangesClearQuestionDraftAndOldResults() async {
        let model = AssessmentSessionModel()
        model.prepare(context: context()) { _ in self.activity("a1") }
        await waitUntil { !model.preparing }
        model.theoryAnswer = "A complete explanation"
        model.prediction = "A prediction"
        model.submit(context: context()) { _, _, _ in self.record() }
        await waitUntil { !model.evaluating }
        XCTAssertNotNil(model.theoryResult)

        model.synchronize(context: context(node: "n2"))
        XCTAssertNil(model.theoryActivity)
        XCTAssertNil(model.theoryResult)
        XCTAssertEqual(model.theoryAnswer, "")
        XCTAssertEqual(model.prediction, "")
        model.theoryAnswer = "A new-language draft"
        model.synchronize(context: context(node: "n2", language: "zh-Hans"))
        XCTAssertEqual(model.theoryAnswer, "")
    }

    func testCancelAndContextSwitchRejectLateEvaluationWithoutLockingNewSession() async {
        let model = AssessmentSessionModel()
        model.prepare(context: context()) { _ in self.activity("a1") }
        await waitUntil { !model.preparing }
        model.theoryAnswer = "My reasoning"
        var pending: CheckedContinuation<Void, Error>?
        model.submit(context: context()) { _, _, _ in
            try await withCheckedThrowingContinuation { pending = $0 }
            return self.record()
        }
        await waitUntil { pending != nil }
        XCTAssertTrue(model.evaluating)
        model.synchronize(context: context(node: "n2"))
        XCTAssertFalse(model.evaluating)
        pending?.resume(returning: ())
        await Task.yield()
        await Task.yield()
        XCTAssertNil(model.theoryResult)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.context?.nodeID, "n2")
    }

    func testFailureKeepsDraftAndSuccessfulRetryBlocksIdenticalSubmission() async {
        let model = AssessmentSessionModel()
        model.prepare(context: context()) { _ in self.activity("a1") }
        await waitUntil { !model.preparing }
        model.theoryAnswer = "  Explain cause and evidence  "
        model.submit(context: context()) { _, _, _ in throw TestFailure.unavailable }
        await waitUntil { !model.evaluating }
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.theoryAnswer, "  Explain cause and evidence  ")
        XCTAssertTrue(model.canSubmit)
        var submissions = 0
        model.submit(context: context()) { kind, answer, activity in
            submissions += 1
            XCTAssertEqual(kind, .theoretical)
            XCTAssertEqual(answer, "Explain cause and evidence")
            XCTAssertEqual(activity.id, "a1")
            return self.record()
        }
        await waitUntil { !model.evaluating }
        XCTAssertNil(model.errorMessage)
        XCTAssertNotNil(model.theoryResult)
        XCTAssertFalse(model.canSubmit)
        model.submit(context: context()) { _, _, _ in
            submissions += 1
            return self.record()
        }
        XCTAssertEqual(submissions, 1)
        model.theoryAnswer += " with a revised example"
        XCTAssertTrue(model.canSubmit)
    }

    func testPrepareFailureEndsLoadingAndAllowsRetryWithoutInventedContent() async {
        let model = AssessmentSessionModel()
        model.prepare(context: context()) { _ in throw TestFailure.unavailable }
        await waitUntil { !model.preparing }
        XCTAssertNil(model.activity)
        XCTAssertNotNil(model.errorMessage)
        model.prepare(context: context()) { _ in self.activity("retry") }
        await waitUntil { !model.preparing }
        XCTAssertEqual(model.activity?.id, "retry")
        XCTAssertNil(model.errorMessage)
    }

    func testPracticalCheckRequiresAllThreeEvidenceFieldsAndKeepsTheoryDraft() async {
        let model = AssessmentSessionModel()
        model.prepare(context: context()) { _ in self.activity("theory") }
        await waitUntil { !model.preparing }
        model.theoryAnswer = "Preserved explanation"
        model.selectedKind = .practical
        model.prepare(context: context()) { _ in self.activity("practical", method: "transferChallenge") }
        await waitUntil { !model.preparing }
        model.prediction = "Expected result"
        model.observation = "Observed result"
        XCTAssertFalse(model.canSubmit)
        model.adjustment = "Revise the hypothesis"
        XCTAssertTrue(model.canSubmit)
        model.selectedKind = .theoretical
        model.prepare(context: context()) { _ in
            XCTFail("Switching back should reuse the prepared question")
            return self.activity("unexpected")
        }
        XCTAssertEqual(model.theoryAnswer, "Preserved explanation")
        XCTAssertEqual(model.activity?.id, "theory")
    }
}

private enum TestFailure: Error {
    case unavailable
}
