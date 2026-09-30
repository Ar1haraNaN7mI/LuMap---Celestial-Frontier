import SwiftUI

struct MobileMethodsView: View {
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("CHOSEN FOR THIS MOMENT", "为此刻的你安排"))
                        .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(MobileTheme.accent)
                    Text(store.currentLearningNode?.title ?? store.t("Learning, one step at a time", "一步一步，找到你的理解方式"))
                        .font(.largeTitle.weight(.semibold))
                    Text(store.t("Lumap combines activities around your current section, then adapts after you finish.", "Lumap 会围绕当前小节组合活动，完成后再根据你的表现调整。"))
                        .foregroundStyle(.secondary)
                }
                if store.activePlan != nil {
                    LearningSectionMethodsView().mobileCard()
                    NavigationLink { MobileMethodExperienceView() } label: {
                        Label(store.t("Continue current activity", "继续当前活动"), systemImage: store.currentMethod.icon)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.borderedProminent)
                    LearningAgentPathView().mobileCard()
                } else {
                    Text(store.t("Choose a learning goal first. Your assigned activities will appear here.", "先选择学习目标，为你安排的活动会显示在这里。"))
                        .foregroundStyle(.secondary)
                    Button(store.t("Find something to learn", "寻找想学的内容")) { store.selectedSection = .home }
                        .buttonStyle(.borderedProminent)
                }
                NavigationLink { MobileFutureLabView() } label: {
                    HStack(spacing: 14) {
                        MobileIconTile(systemImage: "doc.text.magnifyingglass", color: MobileTheme.gold)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.t("Learning workspace", "学习工作空间")).font(.headline)
                            Text(store.t("Your sources, evidence, interests and session files.", "你的资料、学习证据、兴趣和会话文件。"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }.buttonStyle(.plain).mobileCard().accessibilityIdentifier("future-lab-entry")
                NavigationLink { MobileFutureLabScenarioView(scenario: .spatialVision) } label: {
                    Label(store.t("Explore the AR concept preview", "体验 AR 概念预览"), systemImage: "vision.pro")
                        .font(.callout)
                }.buttonStyle(.bordered)
                Text(store.t("The AR preview is a separate demonstration and does not change your assigned learning sequence.", "AR 预览是独立演示，不会改变已安排的学习顺序。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 20)
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Your activities", "你的学习活动"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Follows the current assignment as the store advances, including a transition
/// between a generated activity and a narrated lesson, without a method picker.
struct MobileMethodExperienceView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(store.currentLearningNode?.title ?? store.activeTopic)
                    .font(.largeTitle.weight(.semibold))
                LearningSectionMethodsView()
                if store.currentMethod == .narratedDeck {
                    NarratedLessonPlayerView(topic: store.currentLearningNode?.title ?? store.activeTopic,
                        sourceExcerpt: store.lessonSourceText, sourceLabel: store.activePlan?.title) { artifact in
                        _ = try store.completeActivity(method: .narratedDeck, artifact: artifact)
                        errorMessage = nil
                    }
                    .id("\(store.currentLearningNode?.id ?? ""):narratedDeck")
                } else if store.currentMethod == .spatialAR {
                    Text(store.t("Spatial learning is available as a separate concept preview.", "空间学习以独立概念预览形式提供。"))
                        .foregroundStyle(.secondary)
                } else {
                    AgentLearningActivityView(method: store.currentMethod, topic: store.activeTopic) { artifact in
                        try save(artifact, method: store.currentMethod)
                    }
                    .id("\(store.currentLearningNode?.id ?? ""):\(store.currentMethod.rawValue)")
                }
                LearningSectionContinueView()
            }
            .padding(.horizontal, 16).padding(.vertical, 20)
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Current activity", "当前活动"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(store.t("Couldn't save this activity", "无法保存活动"), isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func save(_ artifact: String, method: LearningMethod) throws {
        do { _ = try store.completeActivity(method: method, artifact: artifact) }
        catch { errorMessage = error.localizedDescription; throw error }
    }
}
