import SwiftData
import SwiftUI

private enum StudioLayout: Equatable {
    case expanded
    case balanced
    case compact

    init(width: CGFloat) {
        if width >= 1200 {
            self = .expanded
        } else if width >= 640 {
            self = .balanced
        } else {
            self = .compact
        }
    }
}

struct LearningStudioView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \MaterialRecord.importedAt, order: .reverse) private var materials: [MaterialRecord]
    @State private var errorMessage: String?
    @State private var showsPath = true
    @State private var showsTutor = true
    @State private var showsPathSheet = false
    @State private var showJourneyAfterPath = false
    @State private var showsTutorSheet = false
    @State private var showsJourney = false
    @AppStorage("lumap.journey.enteredPlanID") private var enteredPlanID = ""

    private var currentMaterial: MaterialRecord? {
        guard let materialID = store.currentGoal?.materialID else { return nil }
        return materials.first { $0.id == materialID }
    }

    var body: some View {
        Group {
            if store.currentGoal == nil {
                ContentUnavailableView {
                    Label(store.t("No active learning map", "还没有进行中的学习地图"), systemImage: "map")
                } description: {
                    Text(store.t("Choose a recommendation or enter a topic on Discover.", "请在探索页面选择推荐或输入主题。"))
                } actions: {
                    Button(store.t("Go to Discover", "前往探索")) { store.selectedSection = .home }
                }
            } else {
                studio
            }
        }
        .task(id: store.currentGoal?.id) {
            await store.prepareLearningPlan()
            presentNewJourney()
        }
        .onChange(of: store.activePlan?.id) { _, _ in presentNewJourney() }
        .onChange(of: store.currentLearningNode?.id) { previous, next in
            if previous != nil, next != nil, previous != next { showsJourney = true }
        }
        .sheet(isPresented: $showsJourney) {
            if let goal = store.currentGoal { LearningJourneyPresentation(goal: goal) }
        }
    }

    private var studio: some View {
        GeometryReader { proxy in
            let layout = StudioLayout(width: proxy.size.width)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    header(for: layout)
                    Divider()
                    methodRail(for: layout)
                    Divider()
                    workspace(for: layout)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                if layout == .expanded && showsTutor {
                    Divider()
                    TutorSidebarView().frame(width: 280)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .toolbar {
                ToolbarItemGroup {
                    Button { showsJourney = true } label: {
                        Label(store.t("Your learning chain", "你的学习光链"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .help(store.t("Explore your progress along the golden learning chain", "沿金色学习光链回顾你的探索进度"))
                    .accessibilityIdentifier("learning-journey-entry")
                    Button {
                        if layout == .compact {
                            showsPathSheet = true
                        } else {
                            showsPath.toggle()
                        }
                    } label: {
                        let isVisible = layout != .compact && showsPath
                        Label(
                            isVisible ? store.t("Hide Path", "隐藏路径") : store.t("Show Path", "显示路径"),
                            systemImage: "sidebar.leading"
                        )
                    }
                    .help(store.t("Show or hide the learning path", "显示或隐藏学习路径"))

                    Button {
                        if layout == .expanded {
                            showsTutor.toggle()
                        } else {
                            showsTutorSheet = true
                        }
                    } label: {
                        let isVisible = layout == .expanded && showsTutor
                        Label(
                            isVisible ? store.t("Hide Lumi", "隐藏 Lumi") : store.t("Show Lumi", "显示 Lumi"),
                            systemImage: "sparkles"
                        )
                    }
                    .help(store.t("Show or hide Lumi", "显示或隐藏 Lumi"))

                    Button {
                        store.selectedSection = .assessment
                    } label: {
                        Label(store.t("Check learning", "检测学习效果"), systemImage: "checkmark.seal")
                    }
                    Button {
                        store.selectedSection = .library
                    } label: {
                        Label(store.t("Add material", "添加资料"), systemImage: "doc.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showsPathSheet, onDismiss: {
                if showJourneyAfterPath {
                    showJourneyAfterPath = false
                    showsJourney = true
                }
            }) {
                NavigationStack {
                    ScrollView {
                        pathPanel
                            .frame(maxWidth: .infinity, minHeight: 480, alignment: .topLeading)
                    }
                    .navigationTitle(store.t("Learning Path", "学习路径"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(store.t("Done", "完成")) { showsPathSheet = false }
                        }
                    }
                }
                .frame(minWidth: 320, minHeight: 520)
            }
            .sheet(isPresented: $showsTutorSheet) {
                NavigationStack {
                    TutorSidebarView()
                        .navigationTitle("Lumi")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(store.t("Done", "完成")) { showsTutorSheet = false }
                            }
                        }
                }
                .frame(minWidth: 320, minHeight: 520)
            }
        }
    }

    @ViewBuilder
    private func workspace(for layout: StudioLayout) -> some View {
        if layout == .compact {
            activityScroll(for: layout)
        } else {
            HStack(spacing: 0) {
                if showsPath {
                    pathPanel
                        .frame(width: 210)
                    Divider()
                }
                activityScroll(for: layout)
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
    }

    private func activityScroll(for layout: StudioLayout) -> some View {
        ScrollView {
            activityPanel
                .padding(layout == .compact ? 18 : 26)
                .frame(maxWidth: 760, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func header(for layout: StudioLayout) -> some View {
        if layout == .compact {
            VStack(alignment: .leading, spacing: 12) {
                headerIdentity
                goalProgress(compact: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
        } else {
            HStack(alignment: .center, spacing: 18) {
                headerIdentity
                Spacer()
                goalProgress(compact: false)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
        }
    }

    private var headerIdentity: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(store.t("Learning Map", "学习地图"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LumapTheme.accent)
                Text(store.t("Explicit goal", "主动目标"))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LumapTheme.mint.opacity(0.14), in: Capsule())
                    .foregroundStyle(LumapTheme.mint)
            }
            Text(store.activeTopic)
                .font(.system(size: 25, weight: .semibold))
                .lineLimit(2)
            Text(store.t("Your words are preserved. Interests never rewrite this goal.", "保留你的原始表达，兴趣画像不会改写这个目标。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func goalProgress(compact: Bool) -> some View {
        if store.currentGoal != nil {
            VStack(alignment: compact ? .leading : .trailing, spacing: 5) {
                Text(store.activePlan == nil ? store.t("PREPARING YOUR FIRST SECTION", "正在编排第一节") : store.t("CURRENT SECTION", "当前小节"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(store.t("\(store.completedCurrentSectionMethodIDs.count) activities completed", "已完成 \(store.completedCurrentSectionMethodIDs.count) 项活动"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: compact ? .infinity : nil, alignment: compact ? .leading : .trailing)
        }
    }

    private func methodRail(for layout: StudioLayout) -> some View {
        LearningSectionMethodsView()
            .padding(.horizontal, layout == .compact ? 18 : 22)
            .padding(.vertical, 12)
            .background(LumapTheme.surface.opacity(0.72))
    }

    private var pathPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button {
                    if showsPathSheet {
                        showJourneyAfterPath = true
                        showsPathSheet = false
                    } else {
                        showsJourney = true
                    }
                } label: {
                    Label(store.t("View learning chain", "查看学习光链"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(LumapTheme.gold)
                LearningAgentPathView()
            }.padding(20)
        }
        .background(LumapTheme.surface)
    }

    private func presentNewJourney() {
        guard let plan = store.activePlan, enteredPlanID != plan.id else { return }
        enteredPlanID = plan.id
        showsJourney = true
    }

    @ViewBuilder
    private var activityPanel: some View {
        let copy = store.moduleCopy(for: store.currentMethod)
        VStack(alignment: .leading, spacing: 22) {
            if store.activePlan == nil || store.isPlanning || store.learningError != nil {
                LearningAgentStatusView()
            } else {
                DisclosureGroup(store.t("About this section and its sources", "本环节目标与资料")) {
                    LearningAgentStatusView().padding(.top, 8)
                }
                .font(.callout)
            }

            if let material = currentMaterial {
                LumapCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(store.t("Grounded in \(material.fileName)", "基于资料：\(material.fileName)"), systemImage: "quote.opening")
                            .font(.subheadline.weight(.semibold))
                        Text(String(material.excerpt.prefix(420)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                        Text(material.citationLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(LumapTheme.cyan)
                    }
                }
            }

            LearningMethodModuleView(
                method: store.currentMethod,
                topic: store.currentMethod == .narratedDeck ? (store.currentLearningNode?.title ?? store.activeTopic) : store.activeTopic,
                sourceExcerpt: store.lessonSourceText ?? currentMaterial?.excerpt,
                sourceLabel: store.activePlan?.title ?? currentMaterial?.fileName,
                complete: completeCurrent
            )

            if store.activePlan != nil { LearningSectionContinueView() }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(LumapTheme.coral)
            }
        }
    }

    private func completeCurrent(_ artifact: String) throws {
        do {
            _ = try store.completeActivity(method: store.currentMethod, artifact: artifact)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

private struct TutorSidebarView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var reply = ""
    @State private var conversation: [String] = []
    @State private var isReplying = false
    @State private var replyError: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [LumapTheme.accent, LumapTheme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 68, height: 68)
                Text("Lumi").font(.title3.bold())
                Text(store.t("Your learning companion", "你的学习伙伴"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    dialogueBubble(store.personaPrompt, fromUser: false)
                    ForEach(Array(conversation.enumerated()), id: \.offset) { index, text in
                        dialogueBubble(text, fromUser: index.isMultiple(of: 2))
                    }
                }
                .padding(16)
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    tutorAction(store.t("Summary", "总结"), icon: "text.alignleft", kind: .summary)
                    tutorAction(store.t("Another way", "换种方式"), icon: "arrow.triangle.2.circlepath", kind: .anotherWay)
                    tutorAction(store.t("Question", "提问"), icon: "questionmark", kind: .question)
                }
                if isReplying { ProgressView() }
                if let replyError { Text(replyError).font(.caption).foregroundStyle(.red) }
                HStack {
                    TextField(store.t("Reply to Lumi…", "回复 Lumi…"), text: $reply)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(sendReply)
                    Button(action: sendReply) {
                        Image(systemName: "arrow.up.circle.fill")
                            .frame(width: 28, height: 28)
                    }
                        .buttonStyle(.plain)
                        .font(.title2)
                        .foregroundStyle(LumapTheme.accent)
                        .disabled(reply.isEmpty || isReplying || store.activePlan == nil)
                        .accessibilityLabel(store.t("Send Reply", "发送回复"))
                        .help(store.t("Send Reply", "发送回复"))
                }
            }
            .padding(14)
        }
        .background(LumapTheme.surface)
    }

    private func dialogueBubble(_ text: String, fromUser: Bool) -> some View {
        HStack {
            if fromUser { Spacer(minLength: 28) }
            Text(text)
                .font(.subheadline)
                .padding(11)
                .background(
                    fromUser ? LumapTheme.accent.opacity(0.13) : LumapTheme.mutedSurface.opacity(0.70),
                    in: RoundedRectangle(cornerRadius: LumapTheme.compactRadius, style: .continuous)
                )
            if !fromUser { Spacer(minLength: 28) }
        }
        .frame(maxWidth: .infinity)
    }

    private func tutorAction(_ label: String, icon: String, kind: PersonaNudgeKind) -> some View {
        Button {
            store.showPersonaNudge(kind)
            conversation.append(store.personaPrompt)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                Text(label).font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func sendReply() {
        let clean = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isReplying else { return }
        conversation.append(clean)
        reply = ""
        isReplying = true
        replyError = nil
        Task {
            defer { isReplying = false }
            do { conversation.append(try await store.askActivityQuestion(clean)) }
            catch { replyError = error.localizedDescription }
        }
    }
}
