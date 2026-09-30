import Foundation

/// Persisted model output is deliberately independent of SwiftData and the UI.
/// Sources and generation provenance are assigned by the app, never invented by the model.
struct LearningSource: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let url: String
    let excerpt: String
    let retrievedAt: Date
}

struct LearningPathNode: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let objective: String
    let prerequisiteIDs: [String]
    let estimatedMinutes: Int
    let methodIDs: [String]
}

struct LearningCoursePlan: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let goal: String
    let nodes: [LearningPathNode]
    let sources: [LearningSource]
    let recommendedMethodID: String
    let recommendationReason: String
    let diagnosticQuestion: String
    let generatedAt: Date
    let model: String
}

struct LearningChoice: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let text: String
    let feedback: String
}

struct LearningRecallCard: Codable, Sendable, Equatable, Identifiable {
    let front: String
    let back: String
    var id: String { front }
}

struct LearningConcept: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let detail: String
}

struct LearningConnection: Codable, Sendable, Equatable, Identifiable {
    let from: String
    let to: String
    let label: String
    var id: String { "\(from)|\(to)|\(label)" }
}

struct LearningGeneratedActivity: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let methodID: String
    let nodeID: String
    let title: String
    let explanation: String
    let prompt: String
    let steps: [String]
    let examples: [String]
    let choices: [LearningChoice]
    let correctChoiceID: String?
    let answerExplanation: String
    let cards: [LearningRecallCard]
    let concepts: [LearningConcept]
    let connections: [LearningConnection]
    let hints: [String]
    let sourceIDs: [String]
}

struct LearningEvaluation: Codable, Sendable, Equatable {
    let score: Int
    let feedback: String
    let misconceptions: [String]
    let nextMethodID: String
    let nextNodeID: String
    let reason: String
}

struct LearningSuggestedTopic: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let reason: String
    let methodID: String
}

struct LearningDialogueTurn: Codable, Sendable, Equatable {
    let role: String
    let content: String
}

enum LearningAgentError: LocalizedError, Equatable {
    case emptyGoal
    case noSources
    case invalidOutput(String)
    case unsupportedMethod
    case blockedURL
    case unreadableSource
    case oversizedResponse

    var errorDescription: String? {
        switch self {
        case .emptyGoal: "Enter a topic you want to learn."
        case .noSources: "No readable research sources were found. Try a more specific topic, retry, or upload learning material."
        case .invalidOutput(let detail): "The model could not produce a complete learning plan: \(detail)"
        case .unsupportedMethod: "This learning method is unavailable for generated activities."
        case .blockedURL: "Only public HTTP or HTTPS pages can be researched. Local or private network addresses are not allowed."
        case .unreadableSource: "This page could not be read. It may require sign-in or block automated retrieval."
        case .oversizedResponse: "The response exceeded the learning material size limit."
        }
    }
}
