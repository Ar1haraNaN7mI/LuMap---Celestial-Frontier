import SwiftUI

struct LearningAgentStatusView: View {
    @EnvironmentObject private var store: LumapStore
    var showsSummary = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.isPlanning {
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t("Building your learning path", "正在编排你的学习路径")).font(.headline)
                        Text(store.planningMessage).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button(store.t("Stop", "停止")) { store.cancelLearningGeneration() }
                }
                Text(store.t("Research and lesson writing can take a few minutes. Your topic stays saved while you wait.", "检索和课程写作可能需要几分钟，等待期间你的主题会保存在本地。"))
                    .font(.caption).foregroundStyle(.secondary)
            } else if let error = store.learningError {
                Label(store.t("Your course needs attention", "课程生成需要处理"), systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text(error).font(.callout).textSelection(.enabled)
                HStack {
                    Button(store.t("Retry", "重试")) {
                        Task {
                            await store.retryLearningGeneration()
                        }
                    }.buttonStyle(.borderedProminent)
                    Button(store.t("Model settings", "模型设置")) { store.selectedSection = .settings }
                }
            } else if let plan = store.activePlan, showsSummary {
                Label(store.t("Researched for your goal", "为你的目标检索编排"), systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(store.currentLearningNode?.title ?? plan.title).font(.title2.weight(.semibold)).textSelection(.enabled)
                Text(store.currentLearningNode?.objective ?? store.activeTopic).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !store.adaptiveReason.isEmpty {
                    Label(store.adaptiveReason, systemImage: "arrow.triangle.branch")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup(store.t("\(plan.sources.count) research sources", "\(plan.sources.count) 份检索资料")) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(plan.sources) { source in
                            VStack(alignment: .leading, spacing: 4) {
                                if let url = URL(string: source.url), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                                    Link("[\(source.id)] \(source.title)", destination: url)
                                } else { Text("[\(source.id)] \(source.title)").fontWeight(.semibold) }
                                Text(String(source.excerpt.prefix(340))).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(store.t("Generated with \(plan.model). Source excerpts support the lesson; review linked originals for context.", "由 \(plan.model) 编排。课程基于资料摘录，可打开原文查看上下文。"))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }
            } else if store.activePlan == nil {
                Text(store.t("Ready to research your topic", "准备检索你的主题")).font(.headline)
                Button(store.t("Build my course", "编排我的课程")) { Task { await store.prepareLearningPlan(force: true) } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

struct LearningAgentPathView: View {
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(store.t("Your learning journey", "你的学习历程")).font(.headline)
            if let plan = store.activePlan {
                let completed = plan.nodes.filter {
                    store.sessionEvidence.completedNodeIDs.contains($0.id) && $0.id != store.currentLearningNode?.id
                }
                if !completed.isEmpty {
                    DisclosureGroup(store.t("Completed sections", "已完成的小节")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(completed) { node in
                                Label(node.title, systemImage: "checkmark.circle.fill")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.top, 8)
                    }.font(.subheadline)
                }
                if let node = store.currentLearningNode {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(store.t("CURRENT SECTION", "当前小节"), systemImage: "circle.inset.filled")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                        Text(node.title).font(.subheadline.weight(.semibold))
                        Text(node.objective).font(.caption).foregroundStyle(.secondary)
                        Text(store.t("About \(node.estimatedMinutes) min", "约 \(node.estimatedMinutes) 分钟"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Label(store.t("Your next step takes shape as you learn", "下一步，会随着你的学习逐渐成形"), systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(store.t("We’ll reveal your first section after researching your goal.", "完成目标检索后，我们会呈现你的第一节内容。"))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

/// The model assigns these activities. Status chips never switch a course method.
struct LearningSectionMethodsView: View {
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(store.t("For this section", "本节学习安排"))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if store.sectionMethods.isEmpty {
                Text(store.t("Choosing the right activities for you…", "正在为你安排合适的活动…"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.sectionMethods) { method in
                            let done = store.completedCurrentSectionMethodIDs.contains(method.rawValue)
                            let current = method == store.currentMethod
                            HStack(spacing: 7) {
                                Image(systemName: done ? "checkmark.circle.fill" : (current ? method.icon : "lock.fill"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LumapLocalization.methodName(method, language: store.language)).font(.caption.weight(.semibold))
                                    Text(done ? store.t("Completed", "已完成") : (current ? store.t("Current", "进行中") : store.t("Later in this section", "本节后续")))
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(current ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(current ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LearningSectionContinueView: View {
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if journeyCompleted {
                Label(store.t("Learning path completed", "学习路径已完成"), systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(Color.accentColor)
                Button(store.t("Review your learning progress", "查看你的学习进展")) { store.selectedSection = .profile }
                    .buttonStyle(.borderedProminent)
            } else {
            Button {
                Task { await store.continueLearningSection() }
            } label: {
                HStack(spacing: 9) {
                    if store.isAdaptingSection { ProgressView().controlSize(.small) }
                    Text(store.isAdaptingSection
                         ? store.t("Preparing your next step…", "正在编排下一步…")
                         : (store.currentSectionIsComplete ? store.t("Next section", "下一小节") : store.t("Next activity", "下一项活动")))
                    if !store.isAdaptingSection { Image(systemName: "arrow.right") }
                }
                .frame(minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canContinueLearningSection || store.isAdaptingSection || store.isGeneratingActivity || store.isPlanning)
            .accessibilityIdentifier("continue-learning-section")
            if store.isAdaptingSection {
                Button(store.t("Stop preparing", "停止编排")) { store.cancelLearningGeneration() }
                    .buttonStyle(.borderless)
            }
            Text(store.canContinueLearningSection
                 ? store.t("Your next activity follows the evidence from this section.", "下一项活动会根据本节的学习证据安排。")
                 : store.t("Complete the current activity before continuing.", "完成当前活动后即可继续。"))
                .font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var journeyCompleted: Bool {
        guard let plan = store.activePlan, !plan.nodes.isEmpty else { return false }
        return plan.nodes.allSatisfy { store.sessionEvidence.completedNodeIDs.contains($0.id) }
    }
}

/// Sources remain inspectable without exposing or selecting future sections.
struct LearningSectionSourcesView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var question = ""
    @State private var answer: WorkspaceAnswer?
    @State private var answerSources: [LearningSource] = []
    @State private var isAnswering = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var requestID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let plan = store.activePlan {
                DisclosureGroup(store.t("Inspect learning sources", "查看学习资料")) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(plan.sources) { source in
                            VStack(alignment: .leading, spacing: 7) {
                                sourceTitle(source)
                                Text(source.excerpt).font(.caption).textSelection(.enabled)
                            }
                        }
                    }.padding(.top, 12)
                }
                TextField(store.t("Ask a question about these sources…", "针对这些资料提出问题…"), text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...5)
                Button {
                    let sources = Array(plan.sources.prefix(12))
                    let submittedQuestion = question
                    let planID = plan.id
                    let request = UUID()
                    requestID = request
                    isAnswering = true
                    error = nil
                    task = Task { @MainActor in
                        defer { if requestID == request { isAnswering = false } }
                        do {
                            let result = try await store.askWorkspaceQuestion(submittedQuestion, sources: sources)
                            try Task.checkCancellation()
                            guard store.activePlan?.id == planID else { return }
                            answer = result
                            answerSources = sources
                        } catch is CancellationError { }
                        catch { if requestID == request { self.error = error.localizedDescription } }
                    }
                } label: {
                    Label(store.t("Ask with citations", "提问并查看引用"), systemImage: "quote.bubble")
                }
                .buttonStyle(.bordered)
                .disabled(isAnswering || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if isAnswering { ProgressView(store.t("Checking your sources…", "正在检查资料…")) }
                if let answer {
                    Text(answer.answer).font(.callout).textSelection(.enabled)
                    ForEach(answer.citations) { citation in
                        if let source = answerSources.first(where: { $0.id == citation.sourceID }) {
                            VStack(alignment: .leading, spacing: 5) {
                                sourceTitle(source)
                                Text("“\(citation.quote)”").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }.padding(.vertical, 5)
                        }
                    }
                }
                if let error { Text(error).font(.caption).foregroundStyle(.orange) }
                Text(store.t("Questions use excerpts from up to 12 course sources. Quoted evidence is checked against those excerpts.", "提问最多使用 12 份课程资料的摘录，引用证据会与这些摘录进行核对。"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 18))
        .onDisappear { task?.cancel() }
        .onChange(of: store.activePlan?.id) { _, _ in
            requestID = UUID(); task?.cancel(); question = ""; answer = nil; error = nil; isAnswering = false
        }
    }

    @ViewBuilder private func sourceTitle(_ source: LearningSource) -> some View {
        if let url = URL(string: source.url), LearningResearchService.isAllowedPublicURL(url) {
            Link("[\(source.id)] \(source.title)", destination: url).font(.caption.weight(.semibold))
        } else {
            Text("[\(source.id)] \(source.title)").font(.caption.weight(.semibold))
        }
    }
}
