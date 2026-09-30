import SwiftUI

struct MobileGroundedStudyView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if store.currentGoal != nil {
                    LearningAgentStatusView()
                    LearningSectionSourcesView()
                    if store.activePlan != nil {
                        LearningSectionMethodsView()
                        currentActivity
                        LearningSectionContinueView()
                        DisclosureGroup(store.t("Your learning journey", "你的学习历程")) {
                            LearningAgentPathView().padding(.top, 12)
                        }
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.orange) }
                } else {
                    ContentUnavailableView {
                        Label(store.t("No active learning goal", "还没有进行中的学习目标"), systemImage: "text.book.closed")
                    } description: {
                        Text(store.t("Create a goal or upload a document first.", "请先创建学习目标或上传资料。"))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 20)
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Source-grounded study", "资料学习"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: store.currentGoal?.id) { await store.prepareLearningPlan() }
    }

    @ViewBuilder private var currentActivity: some View {
        if store.currentMethod == .narratedDeck {
            NarratedLessonPlayerView(topic: store.currentLearningNode?.title ?? store.activeTopic,
                sourceExcerpt: store.lessonSourceText, sourceLabel: store.activePlan?.title) { artifact in
                save(artifact, method: .narratedDeck)
            }
            .id("\(store.currentLearningNode?.id ?? ""):narratedDeck")
        } else {
            AgentLearningActivityView(method: store.currentMethod, topic: store.activeTopic) { artifact in
                save(artifact, method: store.currentMethod)
            }
            .id("\(store.currentLearningNode?.id ?? ""):\(store.currentMethod.rawValue)")
        }
    }

    private func save(_ artifact: String, method: LearningMethod) {
        do { _ = try store.completeActivity(method: method, artifact: artifact); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}
