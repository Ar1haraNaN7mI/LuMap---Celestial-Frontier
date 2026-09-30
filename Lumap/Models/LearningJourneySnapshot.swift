import Foundation

/// A read-only projection for the journey. It deliberately contains no future
/// nodes, so neither the drawing nor accessibility can reveal an unopened step.
struct LearningJourneySnapshot: Equatable, Identifiable {
    struct SavedEvidence: Equatable, Identifiable {
        let id: UUID
        let activityID: String
        let methodID: String
        let response: String
        let score: Int
        let feedback: String
        let createdAt: Date
    }

    struct Method: Equatable, Identifiable {
        let method: LearningMethod
        let isCompleted: Bool
        let savedEvidenceCount: Int
        var id: String { method.rawValue }
    }

    struct Section: Equatable, Identifiable {
        enum State: Equatable {
            case current
            case explored
        }

        let id: String
        let ordinal: Int
        let title: String
        let objective: String
        let estimatedMinutes: Int
        let state: State
        let methods: [Method]
        let savedEvidence: [SavedEvidence]
        var isExplored: Bool { state == .explored }
    }

    let id: String
    let title: String
    let goal: String
    /// Learning order: the origin first, the currently open section last.
    let sections: [Section]
    let currentSectionID: String?
    let isComplete: Bool

    init(plan: LearningCoursePlan, evidence: LearningSessionEvidence, currentNodeID: String?) {
        id = plan.id
        title = plan.title
        goal = plan.goal

        // A stale/corrupt completion beyond a gap must not disclose future work.
        // Workspace imports separately validate assessed mastery; this projection
        // never changes or repairs the authoritative saved learning state.
        let declaredCompleted = Set(evidence.completedNodeIDs)
        let completedPrefix = Array(plan.nodes.prefix { declaredCompleted.contains($0.id) })
        let completedIDs = Set(completedPrefix.map(\.id))
        let nextNode = plan.nodes.dropFirst(completedPrefix.count).first
        let requestedID = currentNodeID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessibleIDs = completedIDs.union(nextNode.map { [$0.id] } ?? [])
        // Missing legacy cursors may show the origin or last explored section,
        // but must not manufacture a visit to a newly eligible future section.
        let selectedID = requestedID.flatMap { accessibleIDs.contains($0) ? $0 : nil }
            ?? completedPrefix.last?.id ?? nextNode?.id
        isComplete = !plan.nodes.isEmpty && completedPrefix.count == plan.nodes.count
        currentSectionID = selectedID.flatMap { completedIDs.contains($0) ? nil : $0 }

        let savedIDs = Set(evidence.savedActivityIDs)
        var seenNodes = Set<String>()
        sections = plan.nodes.enumerated().compactMap { index, node in
            guard seenNodes.insert(node.id).inserted,
                  completedIDs.contains(node.id) || node.id == selectedID else { return nil }
            var seenMethods = Set<String>()
            let assignedMethods = node.methodIDs.compactMap(LearningMethod.init(rawValue:))
                .filter { seenMethods.insert($0.rawValue).inserted }
            let assignedIDs = Set(assignedMethods.map(\.rawValue))
            var seenAttempts = Set<UUID>()
            let saved = evidence.attempts.filter {
                $0.nodeID == node.id && assignedIDs.contains($0.methodID)
                    && savedIDs.contains($0.activityID) && seenAttempts.insert($0.id).inserted
            }
            let completionIDs = Set(evidence.completedSectionMethods?[node.id]
                ?? (completedIDs.contains(node.id) ? node.methodIDs : []))
            let methods = assignedMethods.map { method in
                Method(method: method, isCompleted: completionIDs.contains(method.rawValue),
                       savedEvidenceCount: saved.filter { $0.methodID == method.rawValue }.count)
            }
            return Section(id: node.id, ordinal: index + 1, title: node.title,
                           objective: node.objective, estimatedMinutes: max(0, node.estimatedMinutes),
                           state: completedIDs.contains(node.id) ? .explored : .current,
                           methods: methods, savedEvidence: saved.map {
                SavedEvidence(id: $0.id, activityID: $0.activityID, methodID: $0.methodID,
                              response: $0.response, score: $0.evaluation.score,
                              feedback: $0.evaluation.feedback, createdAt: $0.createdAt)
            })
        }
    }
}
