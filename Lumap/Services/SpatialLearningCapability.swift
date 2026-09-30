import Foundation

enum SpatialLearningAvailability: String, Sendable {
    case checking
    case previewOnly
    case ready
    case unavailable
}

struct SpatialLearningScenario: Identifiable, Sendable {
    let id: String
    let title: String
    let learningGoal: String
    let anchorHint: String
    let steps: [String]

    static let feedbackLab = SpatialLearningScenario(
        id: "feedback-lab",
        title: "Feedback Loop Lab",
        learningGoal: "Predict, observe and explain how one variable changes a system.",
        anchorHint: "A future spatial adapter can place the model on a horizontal surface.",
        steps: [
            "Choose one variable to change.",
            "Predict the direction of the effect.",
            "Observe the model and compare it with your prediction.",
            "Explain what evidence would change your conclusion."
        ]
    )
}

/// A platform-neutral boundary for camera or spatial learning experiences.
/// iOS supplies an ARKit-aware adapter; a future spatial target can provide its
/// own implementation without changing the learning flow or evidence model.
@MainActor
protocol SpatialLearningProviding: AnyObject {
    var availability: SpatialLearningAvailability { get }
    var scenario: SpatialLearningScenario { get }

    func prepare() async
    func reset()
}
