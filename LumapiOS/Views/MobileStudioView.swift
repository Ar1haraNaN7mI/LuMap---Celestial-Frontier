import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MobileStudioView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \MaterialRecord.importedAt, order: .reverse) private var materials: [MaterialRecord]
    @State private var showingImporter = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showingJourney = false
    @AppStorage("lumap.journey.enteredPlanID") private var enteredPlanID = ""

    var body: some View {
        Group {
            if let goal = store.currentGoal {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        goalHeader(goal)
                        LearningAgentStatusView()
                        if store.activePlan != nil {
                            Button { showingJourney = true } label: {
                                Label(store.t("Your learning chain", "你的学习光链"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.bordered).tint(MobileTheme.gold)
                        }
                        LearningSectionMethodsView().mobileCard()

                        let copy = store.moduleCopy(for: store.currentMethod)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(copy.eyebrow)
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(MobileTheme.accent)
                            Text(copy.title)
                                .font(.title2.bold())
                            Text(copy.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Divider()
                            Label(copy.prompt, systemImage: "lightbulb.fill")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(MobileTheme.gold)
                        }
                        .mobileCard(prominent: true)

                        NavigationLink {
                            MobileMethodExperienceView()
                        } label: {
                            HStack(spacing: 14) {
                                MobileIconTile(systemImage: store.currentMethod.icon)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(store.t("Open learning activity", "打开学习活动"))
                                        .font(.headline)
                                    Text(store.t("Continue the activity prepared for this section.", "继续完成为本节安排的学习活动。"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .mobileCard()

                        if let material = currentMaterial {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(material.fileName).font(.headline)
                                    Text(material.citationLabel).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "doc.text.fill").foregroundStyle(MobileTheme.cyan)
                            }
                            .mobileCard()
                        }


                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .background(MobileTheme.background)
            } else {
                ContentUnavailableView {
                    Label(store.t("No active learning map", "还没有进行中的学习地图"), systemImage: "map")
                } description: {
                    Text(store.t("Choose an idea in Discover, or import a document to begin.", "请在探索中选择主题，或导入文档开始学习。"))
                } actions: {
                    Button(store.t("Import a Document", "导入文档")) {
                        showingImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task(id: store.currentGoal?.id) {
            await store.prepareLearningPlan()
            if let plan = store.activePlan, enteredPlanID != plan.id {
                enteredPlanID = plan.id
                showingJourney = true
            }
        }
        .sheet(isPresented: $showingJourney) {
            if let goal = store.currentGoal { LearningJourneyPresentation(goal: goal) }
        }
        .navigationTitle(store.t("Learn", "学习"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingImporter = true
                } label: {
                    if isImporting { ProgressView() } else { Image(systemName: "doc.badge.plus") }
                }
                .disabled(isImporting)
                .accessibilityLabel(store.t("Import learning material", "导入学习资料"))
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .plainText, .json, .commaSeparatedText, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                if case let .failure(error) = result { errorMessage = error.localizedDescription }
                return
            }
            Task { await importMaterial(url) }
        }
        .alert(store.t("Learning activity needs attention", "学习活动需要处理"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var currentMaterial: MaterialRecord? {
        guard let materialID = store.currentGoal?.materialID else { return nil }
        return materials.first { $0.id == materialID }
    }

    private func goalHeader(_ goal: LearningGoal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                MobileIconTile(systemImage: "map.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.t("Current path", "当前路径"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(goal.originalInput)
                        .font(.title2.bold())
                }
            }
            Text(store.t("Your next step takes shape as you learn", "下一步，会随着你的学习逐渐成形"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .mobileCard()
    }

    @MainActor
    private func importMaterial(_ url: URL) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let material = try await store.importMaterial(from: url)
            let title = url.deletingPathExtension().lastPathComponent
            try store.startLearning(topic: title.isEmpty ? material.fileName : title, materialID: material.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
