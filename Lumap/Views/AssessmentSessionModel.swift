import Combine
import Foundation

/// Identifies the exact learning context that an optional check belongs to.
/// A question and its draft must never follow the learner into another section.
struct AssessmentSessionContext: Equatable, Hashable {
    let goalID: UUID?
    let planID: String?
    let nodeID: String?
    let language: String

    @MainActor init(store: LumapStore) {
        goalID = store.currentGoal?.id
        planID = store.activePlan?.id
        nodeID = store.currentLearningNode?.id
        language = store.learningLanguage.rawValue
    }

    init(goalID: UUID?, planID: String?, nodeID: String?, language: String) {
        self.goalID = goalID
        self.planID = planID
        self.nodeID = nodeID
        self.language = language
    }
}

/// Shared presentation state for the Mac and iPhone optional assessment surfaces.
/// Request ownership is independent of the main learning activity's loading state.
@MainActor final class AssessmentSessionModel: ObservableObject {
    @Published var selectedKind: AssessmentKind = .theoretical
    @Published var theoryAnswer = ""
    @Published var prediction = ""
    @Published var observation = ""
    @Published var adjustment = ""
    @Published private(set) var theoryActivity: LearningGeneratedActivity?
    @Published private(set) var practicalActivity: LearningGeneratedActivity?
    @Published private(set) var theoryResult: AssessmentRecord?
    @Published private(set) var practicalResult: AssessmentRecord?
    @Published private(set) var preparing = false
    @Published private(set) var evaluating = false
    @Published var errorMessage: String?
    @Published private(set) var context: AssessmentSessionContext?

    private var preparationTask: Task<Void, Never>?
    private var evaluationTask: Task<Void, Never>?
    private var preparationRequestID: UUID?
    private var evaluationRequestID: UUID?
    private var submittedTheoryResponse: String?
    private var submittedPracticalResponse: String?

    var activity: LearningGeneratedActivity? {
        selectedKind == .theoretical ? theoryActivity : practicalActivity
    }

    var result: AssessmentRecord? {
        selectedKind == .theoretical ? theoryResult : practicalResult
    }

    var canSubmit: Bool {
        guard !preparing, !evaluating, activity != nil else { return false }
        if selectedKind == .theoretical {
            return !clean(theoryAnswer).isEmpty && response != submittedTheoryResponse
        }
        return ![prediction, observation, adjustment].contains { clean($0).isEmpty }
            && response != submittedPracticalResponse
    }

    func synchronize(context next: AssessmentSessionContext) {
        guard context != next else { return }
        cancelRequests()
        context = next
        theoryAnswer = ""
        prediction = ""
        observation = ""
        adjustment = ""
        theoryActivity = nil
        practicalActivity = nil
        theoryResult = nil
        practicalResult = nil
        submittedTheoryResponse = nil
        submittedPracticalResponse = nil
        errorMessage = nil
    }

    func prepare(
        context next: AssessmentSessionContext,
        operation: @escaping @MainActor (AssessmentKind) async throws -> LearningGeneratedActivity
    ) {
        synchronize(context: next)
        preparationTask?.cancel()
        preparationRequestID = nil
        preparing = false
        errorMessage = nil
        guard next.goalID != nil, activity == nil else { return }
        let kind = selectedKind
        let requestID = UUID()
        preparationRequestID = requestID
        preparing = true
        preparationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.preparationRequestID == requestID {
                    self.preparationRequestID = nil
                    self.preparationTask = nil
                    self.preparing = false
                }
            }
            do {
                try Task.checkCancellation()
                let activity = try await operation(kind)
                guard !Task.isCancelled, self.preparationRequestID == requestID,
                      self.context == next, self.selectedKind == kind else { return }
                guard activity.nodeID == next.nodeID else { throw LearningSessionError.sessionChanged }
                if kind == .theoretical { self.theoryActivity = activity }
                else { self.practicalActivity = activity }
            } catch {
                guard !Task.isCancelled, self.preparationRequestID == requestID,
                      self.context == next, self.selectedKind == kind else { return }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func submit(
        context next: AssessmentSessionContext,
        operation: @escaping @MainActor (AssessmentKind, String, LearningGeneratedActivity) async throws -> AssessmentRecord
    ) {
        synchronize(context: next)
        guard canSubmit, let activity else { return }
        let kind = selectedKind
        let submittedResponse = response
        let requestID = UUID()
        evaluationRequestID = requestID
        evaluating = true
        errorMessage = nil
        if kind == .theoretical { theoryResult = nil } else { practicalResult = nil }
        evaluationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.evaluationRequestID == requestID {
                    self.evaluationRequestID = nil
                    self.evaluationTask = nil
                    self.evaluating = false
                }
            }
            do {
                try Task.checkCancellation()
                let record = try await operation(kind, submittedResponse, activity)
                guard !Task.isCancelled, self.evaluationRequestID == requestID,
                      self.context == next, self.selectedKind == kind else { return }
                if kind == .theoretical {
                    self.theoryResult = record
                    self.submittedTheoryResponse = submittedResponse
                } else {
                    self.practicalResult = record
                    self.submittedPracticalResponse = submittedResponse
                }
            } catch {
                guard !Task.isCancelled, self.evaluationRequestID == requestID,
                      self.context == next, self.selectedKind == kind else { return }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func cancelRequests() {
        preparationTask?.cancel()
        evaluationTask?.cancel()
        preparationTask = nil
        evaluationTask = nil
        preparationRequestID = nil
        evaluationRequestID = nil
        preparing = false
        evaluating = false
    }

    private var response: String {
        if selectedKind == .theoretical { return clean(theoryAnswer) }
        return "Context: \(practicalActivity?.explanation ?? "")\nPrediction: \(clean(prediction))\nObservation: \(clean(observation))\nRevision: \(clean(adjustment))"
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
