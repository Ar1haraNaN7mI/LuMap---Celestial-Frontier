import SwiftData
import SwiftUI

/// A visual progress entrance. Opening history never changes the live course cursor.
struct LearningJourneyPresentation: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.dismiss) private var dismiss
    let goal: LearningGoal
    var openLearning: () -> Void = {}
    @State private var reviewPath: [String] = []
    @State private var errorMessage: String?

    private var plan: LearningCoursePlan? {
        if store.currentGoal?.id == goal.id { return store.activePlan }
        guard let data = goal.agentPlanData else { return nil }
        return try? JSONDecoder().decode(LearningCoursePlan.self, from: data)
    }

    private var evidence: LearningSessionEvidence {
        if store.currentGoal?.id == goal.id { return store.sessionEvidence }
        guard let data = goal.agentSessionData,
              let decoded = try? JSONDecoder().decode(LearningSessionEvidence.self, from: data) else {
            return LearningSessionEvidence()
        }
        return decoded
    }

    var body: some View {
        NavigationStack(path: $reviewPath) {
            Group {
                if let plan {
                    let snapshot = LearningJourneySnapshot(plan: plan, evidence: evidence, currentNodeID: goal.agentNodeID)
                    LearningJourneyChainView(snapshot: snapshot, isChinese: store.language == .simplifiedChinese,
                                             reducedMotion: store.profile?.reducedMotion ?? false) { nodeID in
                        if nodeID == snapshot.currentSectionID, goal.status != "completed" {
                            continueLearning()
                        } else {
                            reviewPath.append(nodeID)
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label(store.t("Your path starts here", "你的路径从这里开始"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    } description: {
                        Text(goal.originalInput)
                        Text(store.t("Your explored sections and the current activity will light up here as you learn.", "你探索过的小节和当前活动，会随着学习在这里点亮。"))
                    } actions: {
                        if goal.status != "completed" {
                            Button(store.t("Continue learning", "继续学习"), action: continueLearning)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle(store.t("Your learning chain", "你的学习光链"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t("Close", "关闭")) { dismiss() }
                }
                if goal.status != "completed" {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(store.t("Continue learning", "继续学习"), action: continueLearning)
                    }
                }
            }
            .navigationDestination(for: String.self) { nodeID in
                if let plan, let node = plan.nodes.first(where: { $0.id == nodeID }) {
                    LearningJourneyEvidenceView(node: node, evidence: evidence)
                }
            }
            .alert(store.t("Unable to open the activity", "暂时无法打开活动"), isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        #if os(macOS)
        .frame(minWidth: 680, idealWidth: 1020, minHeight: 560, idealHeight: 740)
        #endif
    }

    private func continueLearning() {
        do {
            if store.currentGoal?.id != goal.id { try store.resumeGoal(goal) }
            if let plan { UserDefaults.standard.set(plan.id, forKey: "lumap.journey.enteredPlanID") }
            dismiss()
            openLearning()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct LearningJourneyEvidenceView: View {
    @EnvironmentObject private var store: LumapStore
    let node: LearningPathNode
    let evidence: LearningSessionEvidence

    private var attempts: [LearningAttemptEvidence] {
        evidence.attempts.filter { $0.nodeID == node.id && evidence.savedActivityIDs.contains($0.activityID) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(store.t("EXPLORED · SAVED EVIDENCE", "已探索 · 保存的证据"), systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(node.title).font(.largeTitle.weight(.semibold))
                Text(node.objective).foregroundStyle(.secondary)
                ForEach(attempts) { attempt in
                    VStack(alignment: .leading, spacing: 14) {
                        if let method = LearningMethod(rawValue: attempt.methodID) {
                            Label(LumapLocalization.methodName(method, language: store.language), systemImage: method.icon)
                                .font(.headline)
                        }
                        Text(attempt.response).textSelection(.enabled)
                        Divider()
                        Text(store.t("Feedback", "学习反馈")).font(.subheadline.bold())
                        Text(attempt.evaluation.feedback).textSelection(.enabled)
                        Label("\(attempt.evaluation.score) / 100", systemImage: "checkmark.seal")
                            .font(.caption.monospacedDigit())
                        ForEach(attempt.evaluation.misconceptions, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
                    }
                    .padding(22)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
                }
                if attempts.isEmpty {
                    Text(store.t("No saved assessment is attached to this section yet.", "这个小节还没有保存的检测证据。"))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(store.t("Learning evidence", "学习证据"))
    }
}
