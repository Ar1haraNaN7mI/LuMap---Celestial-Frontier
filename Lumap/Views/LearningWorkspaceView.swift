import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Shared live workspace for the four non-spatial Future Lab flows.
/// The surrounding macOS/iOS containers own scrolling and navigation.
struct LearningWorkspaceView: View {
    let scenario: FutureLabScenario
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \MaterialRecord.importedAt, order: .reverse) private var materials: [MaterialRecord]
    @Query(sort: \InterestEvidence.createdAt, order: .reverse) private var interests: [InterestEvidence]
    @State private var selectedSourceIDs: Set<String> = []
    @State private var question = ""
    @State private var courseGoal = ""
    @State private var publicLink = ""
    @State private var answer: WorkspaceAnswer?
    @State private var answeredQuestion = ""
    @State private var answeredSources: [LearningSource] = []
    @State private var error: String?
    @State private var isWorking = false
    @State private var workLabel = ""
    @State private var importingMaterial = false
    @State private var importingSession = false
    @State private var exportURL: URL?
    @State private var pendingSession: LearningWorkspaceTransfer?
    @State private var courseIsReady = false
    @State private var task: Task<Void, Never>?
    @State private var operationID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            switch scenario {
            case .knowledgeStudio: knowledgeStudio
            case .adaptivePath: adaptivePath
            case .learningHandoff: handoff
            case .interestConstellation: interestMap
            case .spatialVision: EmptyView()
            }
            if isWorking {
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text(workLabel).font(.callout)
                    Spacer(minLength: 8)
                    Button(store.t("Cancel", "取消")) { operationID = UUID(); task?.cancel(); task = nil; isWorking = false }
                }.padding(16).workspacePanel()
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(isPresented: $importingMaterial, allowedContentTypes: [.pdf, .plainText, .html, .json], allowsMultipleSelection: true) { result in
            run(store.t("Reading your learning materials…", "正在读取学习资料…")) {
                for url in try result.get() {
                    try Task.checkCancellation()
                    let material = try await store.importMaterial(from: url)
                    selectedSourceIDs.insert("M-\(material.id.uuidString)")
                }
            }
        }
        .fileImporter(isPresented: $importingSession, allowedContentTypes: [.json]) { result in
            do { pendingSession = try store.readWorkspaceSession(from: result.get()); error = nil }
            catch { self.error = error.localizedDescription }
        }
        .onDisappear { task?.cancel() }
        .accessibilityIdentifier("live-workspace-\(scenario.rawValue)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(store.t("LEARNING WORKSPACE", "学习工作空间"), systemImage: scenario.icon)
                .font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
            Text(scenario.title(language: store.language)).font(.largeTitle.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var subtitle: String {
        switch scenario {
        case .knowledgeStudio: store.t("Bring your sources together. Ask a precise question, inspect the evidence, or turn them into your next course.", "汇集你的资料，提出具体问题、检查证据，或把它们编排成下一门课程。")
        case .adaptivePath: store.t("See how your actual answers shape what comes next.", "查看你的真实回答如何影响下一步学习。")
        case .learningHandoff: store.t("Take your current course and learning evidence to another Lumap installation using a session file.", "通过会话文件，把当前课程和学习证据带到另一台安装 Lumap 的设备。")
        case .interestConstellation: store.t("Your interests are yours to confirm. Only confirmed signals personalise future recommendations.", "兴趣由你确认。只有已确认的信号才会用于后续个性化推荐。")
        case .spatialVision: ""
        }
    }

    private var availableSources: [LearningSource] {
        let materialSources = materials.map {
            LearningSource(id: "M-\($0.id.uuidString)", title: "\($0.fileName) · \($0.citationLabel)", url: "", excerpt: $0.excerpt, retrievedAt: $0.importedAt)
        }
        return LearningWorkspaceService.selectableSources(materials: materialSources, course: store.activePlan?.sources ?? [])
    }
    private var selectedSources: [LearningSource] { availableSources.filter { selectedSourceIDs.contains($0.id) } }

    private var knowledgeStudio: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.t("Sources", "资料")).font(.headline)
                    Spacer()
                    Button { importingMaterial = true } label: { Label(store.t("Upload", "上传"), systemImage: "plus") }
                        .disabled(isWorking)
                }
                if availableSources.isEmpty {
                    Text(store.t("Upload a PDF or text file, or research a course first. Your own sources will appear here.", "上传 PDF 或文本文件，或者先检索一门课程；你的真实资料会显示在这里。"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(availableSources) { source in
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: Binding(get: { selectedSourceIDs.contains(source.id) }, set: { enabled in
                            if enabled { selectedSourceIDs.insert(source.id) } else { selectedSourceIDs.remove(source.id) }
                        })) { Text(source.title).font(.subheadline.weight(.medium)) }
                        .toggleStyle(.switch)
                        .disabled(isWorking || (!selectedSourceIDs.contains(source.id) && selectedSources.count >= 12))
                        DisclosureGroup(store.t("Inspect source", "查看资料")) {
                            VStack(alignment: .leading, spacing: 8) {
                                sourceLink(source)
                                Text(source.excerpt).font(.caption).textSelection(.enabled)
                            }.padding(.vertical, 8)
                        }.font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
                Text(store.t("\(selectedSources.count)/12 selected · Up to 4,000 characters per source are sent to your configured model.", "已选 \(selectedSources.count)/12 份 · 每份资料最多发送 4,000 字符给已配置的模型。"))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(18).workspacePanel()

            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("Ask your sources", "向资料提问")).font(.headline)
                TextField(store.t("What would you like to understand?", "你希望理解什么？"), text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...5)
                Button(store.t("Ask with citations", "提问并查看引用")) {
                    let sources = selectedSources
                    let submittedQuestion = question
                    run(store.t("Reading selected evidence and writing a grounded answer…", "正在基于所选证据组织回答…")) {
                        let result = try await store.askWorkspaceQuestion(submittedQuestion, sources: sources)
                        try Task.checkCancellation()
                        answeredSources = sources
                        answeredQuestion = submittedQuestion
                        answer = result
                    }
                }.buttonStyle(.borderedProminent)
                    .disabled(isWorking || selectedSources.isEmpty || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let answer {
                    Divider()
                    Text(answeredQuestion).font(.subheadline.weight(.semibold)).textSelection(.enabled)
                    Text(answer.answer).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    ForEach(answer.citations) { citation in
                        if let source = answeredSources.first(where: { $0.id == citation.sourceID }) {
                            VStack(alignment: .leading, spacing: 5) {
                                sourceLink(source)
                                Text("“\(citation.quote)”").font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                            }.padding(12).workspacePanel()
                        }
                    }
                }
            }.padding(18).workspacePanel()

            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("Build from these sources", "用这些资料编排课程")).font(.headline)
                TextField(store.t("What should this course help you do?", "这门课程需要帮助你做到什么？"), text: $courseGoal, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...4)
                Button(store.t("Create my course", "创建我的课程")) {
                    let sources = selectedSources
                    let goal = courseGoal
                    courseIsReady = false
                    run(store.t("Planning a personalised course from your selected sources…", "正在用所选资料编排个性化课程…")) {
                        try await store.buildWorkspaceCourse(topic: goal, sources: sources)
                        courseIsReady = true
                    }
                }.buttonStyle(.borderedProminent)
                    .disabled(isWorking || selectedSources.isEmpty || courseGoal.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                Text(store.t("A revised course is saved as a new project so your previous learning evidence stays attached to its original path.", "重新编排会保存为新项目，之前的学习证据仍关联原来的路径。"))
                    .font(.caption).foregroundStyle(.secondary)
                if courseIsReady { courseReadyLink }
            }.padding(18).workspacePanel()
        }
    }

    private var adaptivePath: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.activePlan != nil {
                LearningAgentPathView().padding(18).workspacePanel()
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("Evidence behind the recommendation", "推荐背后的学习证据")).font(.headline)
                    Text(store.adaptiveReason).fixedSize(horizontal: false, vertical: true)
                    if store.sessionEvidence.attempts.isEmpty {
                        Text(store.t("No assessed attempts yet. The starting method uses your goal and profile; your answers will refine it.", "还没有已评估的尝试。初始方式基于目标和个人信息，后续会根据回答调整。"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(store.sessionEvidence.attempts.suffix(8).reversed())) { attempt in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(methodTitle(attempt.methodID)).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(attempt.evaluation.score)/100").monospacedDigit().font(.subheadline.weight(.semibold))
                            }
                            Text(attempt.evaluation.feedback).font(.callout)
                            if !attempt.evaluation.misconceptions.isEmpty {
                                Text(store.t("Work on: ", "待提升：") + attempt.evaluation.misconceptions.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(attempt.createdAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                        }.padding(14).workspacePanel()
                    }
                }.padding(18).workspacePanel()
                methodEvidence
                openLearningAction
                Text(store.t("The MVP uses model feedback and prerequisite rules. These observations are not a trained reinforcement-learning policy or proof that one method caused better outcomes.", "MVP 使用模型反馈和前置知识规则。当前观测不代表已训练的强化学习策略，也不能证明某种方式导致更好的结果。"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                emptyCourse
            }
        }
    }

    private var methodEvidence: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Method observations", "学习方式观测")).font(.headline)
            ForEach(LearningMethod.allCases) { method in
                let attempts = store.sessionEvidence.attempts.filter { $0.methodID == method.rawValue }
                if !attempts.isEmpty {
                    let mean = attempts.reduce(0) { $0 + $1.evaluation.score } / attempts.count
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(methodTitle(method.rawValue))
                            Spacer()
                            Text(store.t("\(attempts.count) attempts · \(mean)/100 mean", "\(attempts.count) 次尝试 · 均分 \(mean)/100")).foregroundStyle(.secondary)
                        }.font(.caption)
                        ProgressView(value: Double(mean), total: 100)
                    }
                }
            }
        }.padding(18).workspacePanel()
    }

    private var handoff: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Label(store.t("Export current session", "导出当前会话"), systemImage: "square.and.arrow.up").font(.headline)
                if let plan = store.activePlan {
                    Text(plan.title).font(.title3.weight(.semibold))
                    Text(store.t("\(store.sessionEvidence.completedNodeIDs.count) completed sections · \(store.sessionEvidence.attempts.count) assessed attempts", "\(store.sessionEvidence.completedNodeIDs.count) 个已完成小节 · \(store.sessionEvidence.attempts.count) 次已评估尝试"))
                        .foregroundStyle(.secondary)
                    Button(store.t("Prepare session file", "生成会话文件")) {
                        do { exportURL = try store.exportWorkspaceSession(); error = nil }
                        catch { self.error = error.localizedDescription }
                    }.buttonStyle(.borderedProminent)
                    if let exportURL {
                        ShareLink(item: exportURL) { Label(store.t("Save or share session file", "保存或分享会话文件"), systemImage: "square.and.arrow.up") }
                    }
                } else { Text(store.t("Build a course before exporting.", "编排课程后即可导出。")) }
                Text(store.t("The file includes source excerpts, your written answers and feedback. API keys, original files, profile data and reward balances are excluded.", "文件包含资料摘录、你的作答和反馈；不包含 API 密钥、原始文件、个人档案或奖励余额。"))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(18).workspacePanel()
            VStack(alignment: .leading, spacing: 12) {
                Label(store.t("Continue from a file", "从文件继续学习"), systemImage: "square.and.arrow.down").font(.headline)
                Button(store.t("Choose a Lumap session", "选择 Lumap 会话文件")) { importingSession = true }
                    .buttonStyle(.bordered)
                if let pendingSession {
                    Text(pendingSession.plan.title).font(.title3.weight(.semibold))
                    Text(pendingSession.plan.summary).foregroundStyle(.secondary)
                    Text(store.t("\(pendingSession.session.completedNodeIDs.count) completed sections · \(pendingSession.session.attempts.count) attempts", "\(pendingSession.session.completedNodeIDs.count) 个已完成小节 · \(pendingSession.session.attempts.count) 次尝试"))
                        .font(.caption)
                    Button(store.t("Import as a new learning project", "导入为新的学习项目")) {
                        do { try store.installWorkspaceSession(pendingSession); self.pendingSession = nil; courseIsReady = true; error = nil }
                        catch { self.error = error.localizedDescription }
                    }.buttonStyle(.borderedProminent)
                }
                Text(store.t("Transfer this file with AirDrop, Files or another sharing tool, then import it in Lumap. Automatic cloud syncing is not enabled.", "通过 AirDrop、文件应用或其他分享工具传输，再在 Lumap 中导入；当前未启用自动云同步。"))
                    .font(.caption).foregroundStyle(.secondary)
                if courseIsReady { courseReadyLink }
            }.padding(18).workspacePanel()
        }
    }

    private var interestMap: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("Connect a public page", "连接公开页面")).font(.headline)
                TextField("https://…", text: $publicLink).textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Button(store.t("Read and suggest interests", "读取并建议兴趣")) {
                    let link = publicLink
                    run(store.t("Reading public text and finding possible interests…", "正在读取公开文字并寻找可能的兴趣…")) {
                        try await store.analyzePublicProfile(link)
                    }
                }.buttonStyle(.borderedProminent)
                    .disabled(isWorking || store.isAnalyzingSource || publicLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text(store.t("Only publicly readable text is used. Pages that require sign-in or block access return an error; they do not create invented interests.", "仅使用可公开读取的文字。需要登录或禁止访问的页面会提示错误，不会生成虚构兴趣。"))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(18).workspacePanel()
            if interests.isEmpty {
                Text(store.t("No interest signals yet. Paste your public profile or add interests on your profile page.", "还没有兴趣信号。粘贴你的公开主页，或在个人页面添加兴趣。"))
                    .foregroundStyle(.secondary)
            }
            ForEach(interests) { interest in
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top) {
                        Text(interest.topic).font(.title3.weight(.semibold))
                        Spacer()
                        Label(interest.status == "confirmed" ? store.t("Confirmed", "已确认") : store.t("Review", "待确认"),
                              systemImage: interest.status == "confirmed" ? "checkmark.seal.fill" : "questionmark.circle")
                            .font(.caption).foregroundStyle(interest.status == "confirmed" ? Color.accentColor : Color.secondary)
                    }
                    Text(interest.explanation).font(.callout).textSelection(.enabled)
                    Text(interest.sourceLabel).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        if interest.status != "confirmed" {
                            Button(store.t("This fits me", "符合我的兴趣")) {
                                do { try store.confirmInterest(interest); error = nil }
                                catch { self.error = error.localizedDescription }
                            }.buttonStyle(.borderedProminent)
                        }
                        Button(store.t("Remove", "移除"), role: .destructive) {
                            do { try store.removeInterest(interest); error = nil }
                            catch { self.error = error.localizedDescription }
                        }.buttonStyle(.bordered)
                    }
                }.padding(18).workspacePanel()
            }
            Button(store.t("Refresh my learning suggestions", "更新我的学习推荐")) {
                Task { await store.refreshPersonalizedRecommendations(force: true) }
            }.buttonStyle(.bordered).disabled(store.isRefreshingRecommendations)
            if let recommendationError = store.recommendationError {
                Text(recommendationError).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var emptyCourse: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Start with something you want to learn", "从你想学的内容开始")).font(.headline)
            Text(store.t("Your path and assessment evidence appear here after a real course has been planned.", "真实课程编排完成后，这里会显示路径和评估证据。"))
                .foregroundStyle(.secondary)
            Button(store.t("Explore a topic", "探索主题")) { store.selectedSection = .home }.buttonStyle(.borderedProminent)
        }.padding(18).workspacePanel()
    }

    private var courseReadyLink: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(store.activePlan?.title ?? store.t("Course ready", "课程就绪"), systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(Color.accentColor)
            openLearningAction
        }.padding(.top, 8)
    }

    @ViewBuilder private var openLearningAction: some View {
        #if os(iOS)
        NavigationLink { MobileStudioView() } label: {
            Label(store.t("Open current learning activity", "打开当前学习活动"), systemImage: "arrow.right")
        }.buttonStyle(.borderedProminent)
        #else
        Button(store.t("Open current learning activity", "打开当前学习活动")) { store.selectedSection = .studio }
            .buttonStyle(.borderedProminent)
        #endif
    }

    @ViewBuilder private func sourceLink(_ source: LearningSource) -> some View {
        if let url = URL(string: source.url), LearningResearchService.isAllowedPublicURL(url) {
            Link("[\(source.id)] \(source.title)", destination: url).font(.caption.weight(.semibold))
        } else { Text("[\(source.id)] \(source.title)").font(.caption.weight(.semibold)) }
    }

    private func methodTitle(_ id: String) -> String {
        guard let method = LearningMethod(rawValue: id) else { return id }
        return LumapLocalization.methodName(method, language: store.language)
    }

    private func run(_ label: String, action: @escaping @MainActor () async throws -> Void) {
        task?.cancel()
        let requestID = UUID()
        operationID = requestID
        error = nil
        isWorking = true
        workLabel = label
        task = Task { @MainActor in
            defer { if operationID == requestID { isWorking = false } }
            do { try await action() }
            catch is CancellationError { }
            catch { if operationID == requestID { self.error = error.localizedDescription } }
        }
    }
}

private extension View {
    func workspacePanel() -> some View {
        background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
    }
}
