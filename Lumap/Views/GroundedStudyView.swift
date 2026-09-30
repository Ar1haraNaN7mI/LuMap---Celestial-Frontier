import SwiftUI

struct GroundedStudyView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LumapBackdrop()
            if store.currentGoal != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Label(store.t("SOURCE-GROUNDED LEARNING", "基于资料的学习"), systemImage: "text.book.closed")
                            .font(.caption.weight(.bold)).foregroundStyle(LumapTheme.accent)
                        LearningAgentStatusView()
                        LearningSectionSourcesView()
                        if store.activePlan != nil {
                            LearningSectionMethodsView()
                            currentActivity
                            LearningSectionContinueView()
                            DisclosureGroup(store.t("Completed learning and current section", "已完成学习与当前小节")) {
                                LearningAgentPathView().padding(.top, 12)
                            }
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }
                    .padding(26)
                    .frame(maxWidth: 920, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                ContentUnavailableView {
                    Label(store.t("No active learning goal", "还没有进行中的学习目标"), systemImage: "text.book.closed")
                } description: {
                    Text(store.t("Start from an uploaded source or choose a learning goal.", "从上传资料开始，或选择一个学习目标。"))
                } actions: {
                    Button(store.t("Open Library", "打开资料库")) { store.selectedSection = .library }
                    Button(store.t("Open Discover", "打开探索")) { store.selectedSection = .home }
                }
            }
        }
        .task(id: store.currentGoal?.id) { await store.prepareLearningPlan() }
    }

    @ViewBuilder private var currentActivity: some View {
        if store.currentMethod == .narratedDeck {
            NarratedLessonPlayerView(topic: store.currentLearningNode?.title ?? store.activeTopic,
                sourceExcerpt: store.lessonSourceText, sourceLabel: store.activePlan?.title) { artifact in
                _ = try store.completeActivity(method: .narratedDeck, artifact: artifact)
                errorMessage = nil
            }
            .id("\(store.currentLearningNode?.id ?? ""):narratedDeck")
        } else {
            AgentLearningActivityView(method: store.currentMethod, topic: store.activeTopic) { artifact in
                try save(artifact, method: store.currentMethod)
            }
            .id("\(store.currentLearningNode?.id ?? ""):\(store.currentMethod.rawValue)")
        }
    }

    private func save(_ artifact: String, method: LearningMethod) throws {
        do { _ = try store.completeActivity(method: method, artifact: artifact); errorMessage = nil }
        catch { errorMessage = error.localizedDescription; throw error }
    }
}
