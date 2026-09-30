import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Renders researched, topic-specific activities. No sample curriculum is substituted
/// when generation or evaluation fails: the learner can retry the actual request.
struct AgentLearningActivityView: View {
    @EnvironmentObject private var store: LumapStore
    let method: LearningMethod
    let topic: String
    let complete: (String) throws -> Void

    @State private var response = ""
    @State private var prediction = ""
    @State private var adjustment = ""
    @State private var selectedChoice: String?
    @State private var revealedSteps = 1
    @State private var stepPredictions: [String] = []
    @State private var revealedHints = 0
    @State private var recallIndex = 0
    @State private var recallRevealed = false
    @State private var recallAnswers: [String] = []
    @State private var recallAttempt = ""
    @State private var chat: [LearningDialogueTurn] = []
    @State private var customConnections: [LearningConnection] = []
    @State private var connectionFrom = ""
    @State private var connectionTo = ""
    @State private var connectionLabel = ""
    @State private var evaluation: LearningEvaluation?
    @State private var submittedResponse = ""
    @State private var isWorking = false
    @State private var interactionRequestID = UUID()
    @State private var interactionTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var saved = false
    @State private var showingPortraitPicker = false
    @State private var portraitData: Data?
    @AppStorage("lumap.story.portraitPath") private var portraitPath = ""
    @AppStorage("lumap.story.guideName") private var guideName = "Lumi"

    private var activity: LearningGeneratedActivity? {
        guard let activity = store.activeActivity, activity.methodID == method.rawValue,
              activity.nodeID == store.currentLearningNode?.id else { return nil }
        return activity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let activity {
                activityHeader(activity)
                activityBody(activity)
                    .disabled(isWorking)
                if method != .socraticDialogue && method != .flashRecall {
                    submitButton(activity)
                }
                workingIndicator
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                if let evaluation { evaluationPanel(evaluation) }
                sourcePanel(activity)
            } else if store.isGeneratingActivity || store.isPlanning {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView()
                    Text(store.t("Preparing your activity", "正在准备你的学习活动")).font(.headline)
                    Text(store.t("The agent is turning your researched material into this learning method. This can take a little while.", "Agent 正在根据检索到的材料编排这种学习方式，这可能需要一些时间。"))
                        .foregroundStyle(.secondary)
                    if let started = store.activityGenerationStartedAt {
                        TimelineView(.periodic(from: started, by: 1)) { timeline in
                            let seconds = max(0, Int(timeline.date.timeIntervalSince(started)))
                            Text(store.t("Waiting for the model · \(seconds)s", "正在等待模型 · \(seconds) 秒"))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            if seconds >= 25 {
                                Text(store.t("This request is taking longer. It will stop with a retry option if the model does not respond.", "这次请求比较慢。如果模型未及时返回，将停止等待并提供重试。"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button(store.t("Stop waiting", "停止等待")) { store.cancelLearningGeneration() }
                }
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            } else {
                ContentUnavailableView {
                    Label(store.t("Activity not ready", "学习活动尚未就绪"), systemImage: "sparkles")
                } description: {
                    Text(store.learningError ?? store.t("Start a topic and let the agent research a learning path first.", "先开始一个主题，让 Agent 检索并规划学习路径。"))
                } actions: {
                    Button(store.t("Prepare activity", "准备学习活动")) {
                        Task { await store.ensureLearningActivity(method: method, force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(.secondary.opacity(0.15)) }
        .task(id: "\(topic)|\(method.rawValue)|\(store.currentLearningNode?.id ?? "none")") {
            await store.ensureLearningActivity(method: method)
        }
        .onChange(of: activity?.id) { _, _ in resetInteraction() }
        .onDisappear { cancelInteraction() }
        .fileImporter(isPresented: $showingPortraitPicker, allowedContentTypes: [.image]) { result in
            importPortrait(result)
        }
        .onAppear {
            if !portraitPath.isEmpty { portraitData = try? Data(contentsOf: URL(fileURLWithPath: portraitPath)) }
            restoreAssessedResponse()
        }
    }

    private func activityHeader(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(LumapLocalization.methodName(method, language: store.language), systemImage: method.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Text(activity.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            if !activity.explanation.isEmpty && method != .story && method != .flashRecall {
                if method == .guidedExplanation || method == .workedExample {
                    Text(activity.explanation).foregroundStyle(.secondary).textSelection(.enabled)
                } else {
                    DisclosureGroup(store.t("A little context", "先了解一点背景")) {
                        Text(activity.explanation).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func activityBody(_ activity: LearningGeneratedActivity) -> some View {
        switch method {
        case .guidedExplanation, .workedExample:
            progressiveLesson(activity)
        case .socraticDialogue:
            dialogue(activity)
        case .analogy:
            analogy(activity)
        case .visualMap:
            conceptMap(activity)
        case .story:
            story(activity)
        case .flashRecall:
            recall(activity)
        case .simulation, .counterfactualLab:
            scenario(activity)
        case .deliberatePractice, .misconceptionDiagnosis:
            practice(activity)
        case .curiosityBranch:
            curiosity(activity)
        case .teachBack, .reflection, .transferChallenge:
            openResponse(activity)
        case .spatialAR, .narratedDeck:
            EmptyView()
        }
    }

    private func progressiveLesson(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if method == .workedExample && revealedSteps < activity.steps.count {
                responseField(store.t("Predict the next step before revealing it", "揭晓之前，先预测下一步"), text: $prediction)
            }
            ForEach(Array(activity.steps.prefix(revealedSteps).enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)").font(.callout.bold()).frame(width: 28, height: 28)
                        .background(.tint.opacity(0.12), in: Circle())
                    Text(step).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if revealedSteps < activity.steps.count {
                Button(store.t("Reveal next step", "揭晓下一步"), systemImage: "arrow.down.circle") {
                    if method == .workedExample {
                        stepPredictions.append("Prediction before step \(revealedSteps + 1): \(prediction.trimmingCharacters(in: .whitespacesAndNewlines))")
                        prediction = ""
                    }
                    revealedSteps += 1
                }
                    .buttonStyle(.bordered)
                    .disabled(method == .workedExample && prediction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                examples(activity)
                responseField(activity.prompt, text: $response)
                hints(activity)
            }
        }
    }

    private func dialogue(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            conversationBubble(activity.prompt, isLearner: false)
            ForEach(Array(chat.enumerated()), id: \.offset) { _, turn in
                conversationBubble(turn.content, isLearner: turn.role == "user")
            }
            responseField(store.t("Think aloud, answer, or ask a question", "说出你的想法、回答或提出问题"), text: $response)
            HStack {
                Button {
                    let message = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !message.isEmpty else { return }
                    interactionTask = Task { await sendDialogue(message) }
                } label: {
                    Label(store.t("Continue dialogue", "继续对话"), systemImage: "arrow.up.message")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !chat.isEmpty {
                    Button(store.t("Review my reasoning", "反馈我的推理")) {
                        interactionTask = Task { await evaluate(chat.map { "\($0.role): \($0.content)" }.joined(separator: "\n")) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                }
            }
            hints(activity)
        }
    }

    private func analogy(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            examples(activity)
            ForEach(Array(activity.steps.enumerated()), id: \.offset) { _, mapping in
                Label(mapping, systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
            responseField(activity.prompt, text: $response)
            responseField(store.t("Where does this analogy stop working?", "这个类比在哪些地方不再成立？"), text: $adjustment)
            hints(activity)
        }
    }

    private func conceptMap(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(activity.concepts) { concept in
                    VStack(alignment: .leading, spacing: 7) {
                        Label(concept.label, systemImage: "circle.hexagongrid.fill").font(.headline)
                        Text(concept.detail).font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            ForEach(activity.connections + customConnections) { connection in
                HStack(alignment: .top) {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(.tint)
                    Text("\(conceptName(connection.from, in: activity)) → \(conceptName(connection.to, in: activity))")
                        .fontWeight(.medium)
                    Text(connection.label).foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            if activity.concepts.count > 1 {
                Text(store.t("Add a relationship you can explain", "添加一条你能够解释的关系")).font(.headline)
                Picker(store.t("From", "从"), selection: $connectionFrom) {
                    Text(store.t("Choose a concept", "选择概念")).tag("")
                    ForEach(activity.concepts) { Text($0.label).tag($0.id) }
                }
                Picker(store.t("To", "到"), selection: $connectionTo) {
                    Text(store.t("Choose a concept", "选择概念")).tag("")
                    ForEach(activity.concepts) { Text($0.label).tag($0.id) }
                }
                TextField(store.t("How are they connected?", "它们有什么关系？"), text: $connectionLabel)
                    .textFieldStyle(.roundedBorder)
                Button(store.t("Add connection", "添加连接"), systemImage: "plus") {
                    customConnections.append(.init(from: connectionFrom, to: connectionTo, label: connectionLabel))
                    connectionLabel = ""
                    evaluation = nil
                    saved = false
                }
                .buttonStyle(.bordered)
                .disabled(connectionFrom.isEmpty || connectionTo.isEmpty || connectionFrom == connectionTo || connectionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            responseField(activity.prompt, text: $response)
        }
    }

    private func story(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Paper2GalgameLearningView(activity: activity)
            Text(activity.prompt).font(.headline)
            choiceButtons(activity)
            if let choice = activity.choices.first(where: { $0.id == selectedChoice }) {
                Text(choice.feedback).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                responseField(store.t("What led you to this choice, and what happens next?", "你为什么这样选择？接下来会发生什么？"), text: $response)
            }
        }
    }

    private func recall(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: Double(recallIndex), total: Double(max(1, activity.cards.count)))
            if recallIndex < activity.cards.count {
                let card = activity.cards[recallIndex]
                Text(store.t("Card \(recallIndex + 1) of \(activity.cards.count)", "卡片 \(recallIndex + 1) / \(activity.cards.count)"))
                    .font(.caption).foregroundStyle(.secondary)
                Text(card.front).font(.title3.weight(.semibold))
                responseField(store.t("Recall the answer before revealing it", "先回忆答案，再揭晓"), text: $response)
                if recallRevealed {
                    Text(card.back).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    Button(store.t("Next card", "下一张"), systemImage: "arrow.right") {
                        recallAnswers.append("Question: \(card.front)\nLearner recall before reveal: \(recallAttempt)")
                        recallIndex += 1
                        response = ""
                        recallRevealed = false
                    }.buttonStyle(.borderedProminent)
                } else {
                    Button(store.t("Reveal answer", "揭晓答案"), systemImage: "eye") { recallAttempt = response; recallRevealed = true }
                        .buttonStyle(.bordered)
                        .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Text(store.t("Review what you recalled", "回顾你的回忆结果")).font(.headline)
                Text(store.t("Your original answers will be assessed against the researched material.", "你的原始回答将依据检索到的材料进行评估。"))
                    .foregroundStyle(.secondary)
                Button(store.t("Assess my recall", "评估回忆效果")) {
                    interactionTask = Task { await evaluate(recallAnswers.joined(separator: "\n\n")) }
                }.buttonStyle(.borderedProminent).disabled(isWorking || recallAnswers.isEmpty)
            }
        }
    }

    private func scenario(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            numberedSteps(activity.steps, title: method == .simulation
                ? store.t("Simulation setup", "模拟设置") : store.t("Scenario setup", "情境设置"))
            examples(activity)
            Text(activity.prompt).font(.headline)
            choiceButtons(activity)
            responseField(store.t("Predict the outcome and explain why", "预测结果，并解释原因"), text: $prediction)
            if let choice = activity.choices.first(where: { $0.id == selectedChoice }), !prediction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DisclosureGroup(store.t("Inspect the scenario consequence", "查看情境后果")) {
                    Text(choice.feedback).padding(.top, 10).foregroundStyle(.secondary)
                }
            }
            responseField(store.t("What evidence would change your prediction?", "什么证据会改变你的预测？"), text: $response)
            hints(activity)
        }
    }

    private func practice(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if method == .deliberatePractice {
                examples(activity)
                numberedSteps(activity.steps, title: store.t("Practice problems", "练习题"))
            }
            Text(activity.prompt).font(.headline)
            choiceButtons(activity)
            responseField(method == .misconceptionDiagnosis
                ? store.t("Identify the mistaken assumption and correct it", "指出错误假设，并修正它")
                : store.t("Show your reasoning, not just the answer", "写下推理过程和答案"), text: $response)
            hints(activity)
            if evaluation != nil && !activity.answerExplanation.isEmpty {
                DisclosureGroup(store.t("Worked solution", "参考解答")) {
                    Text(activity.answerExplanation).padding(.top, 10).textSelection(.enabled)
                }
            }
        }
    }

    private func curiosity(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(activity.prompt).font(.headline)
            choiceButtons(activity)
            if let choice = activity.choices.first(where: { $0.id == selectedChoice }) {
                Text(choice.feedback).foregroundStyle(.secondary)
            }
            responseField(store.t("Which question interests you, and how does it connect to what you learned?", "哪个问题让你感兴趣？它与你刚学到的内容有什么联系？"), text: $response)
            Text(store.t("Your reasoning helps shape the next section after you finish this one.", "完成当前环节后，你的想法将用于适配下一环节。"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func openResponse(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            examples(activity)
            if !activity.steps.isEmpty {
                DisclosureGroup(store.t("Guidance", "学习引导")) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(activity.steps.enumerated()), id: \.offset) { index, step in Text("\(index + 1). \(step)") }
                    }.padding(.top, 10)
                }
            }
            responseField(activity.prompt, text: $response)
            if method == .reflection {
                responseField(store.t("What will you try next, and why?", "下一步你会尝试什么？为什么？"), text: $adjustment)
            }
            hints(activity)
        }
    }

    private func choiceButtons(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(activity.choices) { choice in
                Button {
                    selectedChoice = choice.id
                    evaluation = nil
                    saved = false
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selectedChoice == choice.id ? "checkmark.circle.fill" : "circle")
                        Text(choice.text).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .tint(selectedChoice == choice.id ? .accentColor : .secondary)
                .accessibilityAddTraits(selectedChoice == choice.id ? .isSelected : [])
            }
        }
    }

    private func examples(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(activity.examples.enumerated()), id: \.offset) { index, example in
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.t("Example \(index + 1)", "案例 \(index + 1)")).font(.caption.weight(.bold)).foregroundStyle(.tint)
                    Text(example).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder private func numberedSteps(_ steps: [String], title: String) -> some View {
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)").font(.callout.bold())
                            .frame(width: 28, height: 28)
                            .background(.tint.opacity(0.12), in: Circle())
                        Text(step).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder private func hints(_ activity: LearningGeneratedActivity) -> some View {
        if !activity.hints.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(activity.hints.prefix(revealedHints).enumerated()), id: \.offset) { _, hint in
                    Label(hint, systemImage: "lightbulb").font(.callout).foregroundStyle(.secondary)
                }
                if revealedHints < activity.hints.count {
                    Button(store.t("Give me a hint", "给我一个提示"), systemImage: "lightbulb") { revealedHints += 1 }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func responseField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
            TextField(store.t("Write your thoughts…", "写下你的想法……"), text: Binding(
                get: { text.wrappedValue },
                set: {
                    text.wrappedValue = $0
                    evaluation = nil
                    saved = false
                }
            ), axis: .vertical)
                .lineLimit(3...10)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
                .disabled(isWorking)
        }
    }

    private func submitButton(_ activity: LearningGeneratedActivity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                interactionTask = Task { await evaluate(assembledResponse(activity)) }
            } label: {
                Label(store.t("Get feedback on my reasoning", "获取我的推理反馈"), systemImage: "sparkle.magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking || !readyToEvaluate(activity))
        }
    }

    @ViewBuilder private var workingIndicator: some View {
        if isWorking {
            HStack(spacing: 9) {
                ProgressView().controlSize(.small)
                Text(store.t("Your tutor is reading your reasoning…", "导师正在阅读你的推理……")).font(.callout).foregroundStyle(.secondary)
                Button(store.t("Stop waiting", "停止等待")) { cancelInteraction() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func evaluationPanel(_ result: LearningEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(store.t("Tutor feedback", "导师反馈"), systemImage: "text.bubble").font(.headline)
                Spacer()
                Text("\(result.score)/100").font(.headline.monospacedDigit())
            }
            Text(result.feedback).textSelection(.enabled)
            DisclosureGroup(store.t("Assessed answer", "已评估的回答")) {
                Text(submittedResponse).font(.callout).textSelection(.enabled)
                    .padding(.top, 8)
            }
            ForEach(Array(result.misconceptions.enumerated()), id: \.offset) { _, misconception in
                Label(misconception, systemImage: "arrow.uturn.backward.circle").font(.callout)
            }
            Button {
                do {
                    try complete("\(topic) · \(method.rawValue)\n\(submittedResponse)\nTutor feedback: \(result.feedback)\nScore: \(result.score)/100")
                    saved = true
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Label(saved ? store.t("Evidence saved", "学习证据已保存") : store.t("Save learning evidence", "保存学习证据"), systemImage: saved ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(saved || isWorking)
        }
        .padding(16).background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sourcePanel(_ activity: LearningGeneratedActivity) -> some View {
        let sources = (store.activePlan?.sources ?? []).filter { activity.sourceIDs.contains($0.id) }
        return DisclosureGroup(store.t("Learning sources · \(sources.count)", "学习资料 · \(sources.count)")) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sources) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        if let url = URL(string: source.url), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                            Link(destination: url) { Label(source.title, systemImage: "arrow.up.right.square") }
                        } else {
                            Label(source.title, systemImage: "doc.text")
                        }
                        Text(String(source.excerpt.prefix(360))).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(store.t("This activity was generated from the course research. Open the sources to check a claim.", "本活动根据课程检索材料生成。你可以打开资料核对具体说法。"))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 10)
        }
    }

    private func conversationBubble(_ text: String, isLearner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isLearner ? store.t("You", "你") : guideName).font(.caption.bold()).foregroundStyle(.secondary)
            Text(text).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isLearner ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var portrait: some View {
        #if os(macOS)
        if let portraitData, let image = NSImage(data: portraitData) {
            Image(nsImage: image).resizable().scaledToFit()
        } else { portraitPlaceholder }
        #else
        if let portraitData, let image = UIImage(data: portraitData) {
            Image(uiImage: image).resizable().scaledToFit()
        } else { portraitPlaceholder }
        #endif
    }

    private var portraitPlaceholder: some View {
        Image(systemName: "person.crop.rectangle.badge.sparkles")
            .font(.system(size: 45)).foregroundStyle(.tint).accessibilityLabel(store.t("Story guide", "剧情导师"))
    }

    private func conceptName(_ id: String, in activity: LearningGeneratedActivity) -> String {
        activity.concepts.first { $0.id == id }?.label ?? id
    }

    private func readyToEvaluate(_ activity: LearningGeneratedActivity) -> Bool {
        let hasResponse = !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if method == .guidedExplanation || method == .workedExample {
            return hasResponse && revealedSteps >= activity.steps.count
        }
        if [.story, .misconceptionDiagnosis, .curiosityBranch].contains(method) {
            return hasResponse && selectedChoice != nil
        }
        if method == .simulation || method == .counterfactualLab {
            return hasResponse && !prediction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (activity.choices.isEmpty || selectedChoice != nil)
        }
        return hasResponse
    }

    private func assembledResponse(_ activity: LearningGeneratedActivity) -> String {
        var parts: [String] = []
        if let choice = activity.choices.first(where: { $0.id == selectedChoice }) { parts.append("Selected choice: \(choice.text)") }
        parts.append(contentsOf: stepPredictions)
        if !prediction.isEmpty { parts.append("Prediction: \(prediction)") }
        parts.append("Learner response: \(response)")
        if !adjustment.isEmpty { parts.append("Reflection / limitations: \(adjustment)") }
        for connection in customConnections {
            parts.append("Learner connection: \(conceptName(connection.from, in: activity)) → \(conceptName(connection.to, in: activity)): \(connection.label)")
        }
        parts.append("Hints requested: \(revealedHints)")
        return parts.joined(separator: "\n")
    }

    @MainActor private func evaluate(_ answer: String) async {
        guard !isWorking, !Task.isCancelled else { return }
        let requestID = UUID()
        interactionRequestID = requestID
        isWorking = true
        errorMessage = nil
        evaluation = nil
        defer { if interactionRequestID == requestID { isWorking = false } }
        do {
            let result = try await store.evaluateActivityResponse(answer)
            guard interactionRequestID == requestID else { return }
            submittedResponse = answer
            evaluation = result
            saved = false
        } catch {
            if interactionRequestID == requestID { errorMessage = error.localizedDescription }
        }
    }

    @MainActor private func sendDialogue(_ message: String) async {
        guard !isWorking, !Task.isCancelled else { return }
        let requestID = UUID()
        interactionRequestID = requestID
        isWorking = true
        errorMessage = nil
        defer { if interactionRequestID == requestID { isWorking = false } }
        do {
            let answer = try await store.askActivityQuestion(message)
            guard interactionRequestID == requestID else { return }
            chat.append(.init(role: "user", content: message))
            chat.append(.init(role: "assistant", content: answer))
            response = ""
            evaluation = nil
        } catch {
            if interactionRequestID == requestID { errorMessage = error.localizedDescription }
        }
    }

    private func resetInteraction() {
        cancelInteraction()
        response = ""; prediction = ""; adjustment = ""; selectedChoice = nil
        revealedSteps = 1; stepPredictions = []; revealedHints = 0; recallIndex = 0; recallRevealed = false
        recallAnswers = []; recallAttempt = ""; chat = []; customConnections = []
        connectionFrom = ""; connectionTo = ""; connectionLabel = ""
        evaluation = nil; submittedResponse = ""; errorMessage = nil; saved = false
        restoreAssessedResponse()
    }

    private func restoreAssessedResponse() {
        guard evaluation == nil, submittedResponse.isEmpty, let activity else { return }
        chat = store.dialogueMessages
        guard let attempt = store.sessionEvidence.attempts.last(where: {
            $0.activityID == activity.id && $0.nodeID == activity.nodeID && $0.methodID == method.rawValue
        }) else { return }
        submittedResponse = attempt.response
        evaluation = attempt.evaluation
        saved = store.sessionEvidence.savedActivityIDs.contains(activity.id)
    }

    private func cancelInteraction() {
        interactionTask?.cancel()
        interactionTask = nil
        interactionRequestID = UUID()
        isWorking = false
    }

    private func importPortrait(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard data.count <= 10_000_000 else {
                errorMessage = store.t("Choose a portrait smaller than 10 MB.", "请选择小于 10 MB 的立绘。")
                return
            }
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Lumap/StoryPortrait", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent("custom-portrait.image")
            try data.write(to: destination, options: .atomic)
            portraitPath = destination.path
            portraitData = data
        } catch { errorMessage = error.localizedDescription }
    }
}
