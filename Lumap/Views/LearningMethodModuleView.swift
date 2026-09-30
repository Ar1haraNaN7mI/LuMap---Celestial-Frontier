import SwiftUI

/// A platform-neutral renderer for every learning method Lumap offers.
///
/// Each module produces a plain-text learning artifact through `complete`, so the
/// host can persist progress without knowing about a renderer's temporary state.
struct LearningMethodModuleView: View {
    let method: LearningMethod
    let topic: String
    let sourceExcerpt: String?
    let sourceLabel: String?
    let complete: (String) throws -> Void
    @State private var completionError: String?

    init(
        method: LearningMethod,
        topic: String,
        sourceExcerpt: String? = nil,
        sourceLabel: String? = nil,
        complete: @escaping (String) throws -> Void
    ) {
        self.method = method
        self.topic = topic
        self.sourceExcerpt = sourceExcerpt
        self.sourceLabel = sourceLabel
        self.complete = complete
    }

    @ViewBuilder
    var body: some View {
        switch method {
        case .spatialAR:
            SpatialARModule(topic: topic, complete: completeLegacyActivity)
        case .narratedDeck:
            NarratedLessonPlayerView(
                topic: topic,
                sourceExcerpt: sourceExcerpt,
                sourceLabel: sourceLabel,
                complete: complete
            )
        default:
            AgentLearningActivityView(method: method, topic: topic, complete: complete)
        }
        if let completionError { Text(completionError).font(.caption).foregroundStyle(.red) }
    }

    private func completeLegacyActivity(_ artifact: String) {
        do {
            try complete(artifact)
            completionError = nil
        } catch { completionError = error.localizedDescription }
    }
}

private struct MethodCard<Content: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    init(icon: String, title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        LumapCard(style: .featured) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 13) {
                    LumapIconTile(icon: icon, tint: LumapTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(LumapTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content
            }
        }
    }
}

private struct ArtifactButton: View {
    @EnvironmentObject private var store: LumapStore
    let enabled: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .disabled(!enabled)
        .help(store.learningText("Save this learning artifact", "保存这份学习产物"))
    }
}

private struct GuidedExplanationModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var lens = 0
    @State private var note = ""

    private var lenses: [(String, String, String)] {
        [
            (store.learningText("System", "系统"), store.learningText("What belongs inside this system?", "这个系统包含哪些部分？"), "square.3.layers.3d"),
            (store.learningText("Change", "变化"), store.learningText("What changes, and what stays stable?", "什么会变化，什么保持稳定？"), "arrow.left.arrow.right"),
            (store.learningText("Evidence", "证据"), store.learningText("What could you observe to test the idea?", "可以观察什么来检验这个想法？"), "magnifyingglass")
        ]
    }

    var body: some View {
        MethodCard(
            icon: lenses[lens].2,
            title: store.learningText("Build a mental model", "建立心智模型"),
            detail: store.learningText("Look at \(topic) through one lens, then capture the connection in your own words.", "从一个角度观察 \(topic)，再用自己的话记录联系。")
        ) {
            Picker(store.learningText("Lens", "观察角度"), selection: $lens) {
                ForEach(lenses.indices, id: \.self) { index in Text(lenses[index].0).tag(index) }
            }
            .pickerStyle(.segmented)

            Label(lenses[lens].1, systemImage: "lightbulb.max.fill")
                .font(.headline)
                .foregroundStyle(LumapTheme.accent)

            TextField(store.learningText("Write one clear connection…", "写下一条清晰的联系……"), text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            ArtifactButton(enabled: !note.trimmed.isEmpty, label: store.learningText("Save mental model", "保存心智模型")) {
                complete(store.learningText(
                    "\(lenses[lens].0) lens · \(topic): \(note.trimmed)",
                    "\(lenses[lens].0)视角 · \(topic)：\(note.trimmed)"
                ))
            }
        }
    }
}

private struct WorkedExampleModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var step = 0
    @State private var transferRule = ""

    private var steps: [(String, String, String)] {
        [
            (store.learningText("Frame the goal", "明确目标"), store.learningText("Turn the topic into a question: “How can I tell whether an explanation of \(topic) is strong?”", "把主题变成问题：“怎样判断对 \(topic) 的解释是否可靠？”"), "target"),
            (store.learningText("Work the evidence", "处理证据"), store.learningText("Separate the claim, the observation and the link between them. Check one link at a time.", "区分主张、观察结果和它们之间的联系，每次检查一条联系。"), "list.number"),
            (store.learningText("Check the result", "检查结果"), store.learningText("Try the explanation on a new case. If it fails, revise the link rather than hiding the exception.", "用新案例检验解释。如果失败，应修改联系，而不是忽略例外。"), "checkmark.seal")
        ]
    }

    var body: some View {
        MethodCard(
            icon: "list.number",
            title: store.learningText("Follow a worked example", "跟随步骤示例"),
            detail: store.learningText("Move through a complete reasoning pattern, then write the rule you can reuse.", "跟随一套完整推理过程，再写出可以复用的规则。")
        ) {
            HStack(spacing: 7) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? LumapTheme.accent : LumapTheme.border)
                        .frame(maxWidth: .infinity)
                        .frame(height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.learningText("Example progress", "示例进度"))
            .accessibilityValue("\(step + 1) / \(steps.count)")

            HStack(alignment: .top, spacing: 13) {
                Image(systemName: steps[step].2)
                    .font(.title2)
                    .foregroundStyle(LumapTheme.cyan)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.learningText("Step \(step + 1)", "第 \(step + 1) 步"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LumapTheme.accent)
                    Text(steps[step].0).font(.headline)
                    Text(steps[step].1).foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(store.learningText("Previous", "上一步"), systemImage: "chevron.left") { step -= 1 }
                    .disabled(step == 0)
                Button(store.learningText("Next", "下一步"), systemImage: "chevron.right") { step += 1 }
                    .disabled(step == steps.count - 1)
                Spacer()
                Text("\(step + 1) / \(steps.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            TextField(store.learningText("The reusable rule is…", "可以复用的规则是……"), text: $transferRule, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            ArtifactButton(enabled: transferRule.trimmed.count >= 8, label: store.learningText("Save worked rule", "保存步骤规则")) {
                complete(store.learningText(
                    "Worked example for \(topic) · Reusable rule: \(transferRule.trimmed)",
                    "\(topic) 步骤示例 · 可复用规则：\(transferRule.trimmed)"
                ))
            }
        }
    }
}

private struct SocraticDialogueModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var questionIndex = 0
    @State private var answer = ""
    @State private var transcript: [String] = []

    private var questions: [String] {
        [
            store.learningText("What do you currently believe about \(topic)?", "你目前对 \(topic) 有什么判断？"),
            store.learningText("What evidence would make that belief weaker?", "什么证据会削弱这个判断？"),
            store.learningText("How would you test the revised belief in a new situation?", "你会怎样在新情境中检验修改后的判断？")
        ]
    }

    var body: some View {
        MethodCard(
            icon: "questionmark.bubble.fill",
            title: store.learningText("Reason through questions", "通过提问推进推理"),
            detail: store.learningText("Lumi will not give away the conclusion. Each answer unlocks a sharper question.", "Lumi 不会直接给出结论，每次回答都会解锁更深入的问题。")
        ) {
            ForEach(Array(transcript.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(questions[index]).font(.caption.weight(.semibold)).foregroundStyle(LumapTheme.accent)
                    Text(item).font(.subheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LumapTheme.mutedSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            }

            if questionIndex < questions.count {
                Label(questions[questionIndex], systemImage: "sparkles")
                    .font(.headline)
                TextField(store.learningText("Think aloud…", "写下你的思考……"), text: $answer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                Button(store.learningText(questionIndex == questions.count - 1 ? "Finish dialogue" : "Answer and continue", questionIndex == questions.count - 1 ? "完成对话" : "回答并继续")) {
                    transcript.append(answer.trimmed)
                    answer = ""
                    questionIndex += 1
                }
                .buttonStyle(.bordered)
                .disabled(answer.trimmed.count < 4)
            }

            ArtifactButton(enabled: transcript.count == questions.count, label: store.learningText("Save reasoning trail", "保存推理轨迹")) {
                let turns = zip(questions, transcript).map { store.learningText("Q: \($0) A: \($1)", "问：\($0) 答：\($1)") }.joined(separator: " | ")
                complete(store.learningText("Socratic dialogue on \(topic) · \(turns)", "关于 \(topic) 的苏格拉底对话 · \(turns)"))
            }
        }
    }
}

private struct AnalogyModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var source = 0
    @State private var mapping = ""
    @State private var limit = ""

    private var sources: [(String, String)] {
        [
            (store.learningText("Transit map", "交通地图"), "tram.fill"),
            (store.learningText("Recipe", "食谱"), "frying.pan.fill"),
            (store.learningText("Ecosystem", "生态系统"), "leaf.fill")
        ]
    }

    var body: some View {
        MethodCard(
            icon: "arrow.triangle.branch",
            title: store.learningText("Build and break an analogy", "建立并检验类比"),
            detail: store.learningText("A useful analogy maps a relationship and also names where the comparison stops.", "有效类比既要映射关系，也要指出比较在哪里失效。")
        ) {
            Picker(store.learningText("Familiar system", "熟悉的系统"), selection: $source) {
                ForEach(sources.indices, id: \.self) { index in
                    Label(sources[index].0, systemImage: sources[index].1).tag(index)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                conceptToken(sources[source].0, icon: sources[source].1, tint: LumapTheme.cyan)
                Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                conceptToken(topic, icon: "book.closed.fill", tint: LumapTheme.accent)
            }

            TextField(store.learningText("Both systems…", "两个系统都……"), text: $mapping, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField(store.learningText("The analogy stops working when…", "这个类比在以下情况会失效……"), text: $limit, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            ArtifactButton(enabled: mapping.trimmed.count >= 6 && limit.trimmed.count >= 6, label: store.learningText("Save analogy", "保存类比")) {
                complete(store.learningText(
                    "Analogy for \(topic) using \(sources[source].0) · Mapping: \(mapping.trimmed) · Limit: \(limit.trimmed)",
                    "用 \(sources[source].0) 类比 \(topic) · 映射：\(mapping.trimmed) · 边界：\(limit.trimmed)"
                ))
            }
        }
    }

    private func conceptToken(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(tint)
    }
}

private struct VisualMapModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var relation = 0
    @State private var concept = ""
    @State private var nodes: [(relation: String, concept: String)] = []

    private var relations: [String] {
        [store.learningText("causes", "导致"), store.learningText("depends on", "依赖"), store.learningText("contrasts with", "对比"), store.learningText("is evidence for", "是其证据")]
    }

    var body: some View {
        MethodCard(
            icon: "point.3.connected.trianglepath.dotted",
            title: store.learningText("Draw the idea network", "绘制概念网络"),
            detail: store.learningText("Add at least two labelled connections. The relationship matters as much as the node.", "至少添加两条带标签的连接，关系和节点同样重要。")
        ) {
            VStack(spacing: 11) {
                Label(topic, systemImage: "circle.hexagongrid.fill")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LumapTheme.accent.opacity(0.13), in: Capsule())
                    .foregroundStyle(LumapTheme.accent)

                ForEach(nodes.indices, id: \.self) { index in
                    HStack(spacing: 9) {
                        Rectangle().fill(LumapTheme.border).frame(width: 28, height: 1)
                        Text(nodes[index].relation).font(.caption).foregroundStyle(.secondary)
                        Rectangle().fill(LumapTheme.border).frame(width: 28, height: 1)
                        Text(nodes[index].concept)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(LumapTheme.cyan.opacity(0.10), in: Capsule())
                        Button {
                            nodes.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(store.learningText("Remove connection", "删除连接"))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)

            ViewThatFits(in: .horizontal) {
                HStack {
                    relationPicker
                    conceptField
                    addConnectionButton
                }
                VStack(alignment: .leading) {
                    relationPicker
                    conceptField
                    addConnectionButton
                }
            }

            ArtifactButton(enabled: nodes.count >= 2, label: store.learningText("Save concept map", "保存概念图谱")) {
                let connections = nodes.map { "\(topic) \($0.relation) \($0.concept)" }.joined(separator: "; ")
                complete(store.learningText("Visual map · \(connections)", "视觉图谱 · \(connections)"))
            }
        }
    }

    private var relationPicker: some View {
        Picker(store.learningText("Relationship", "关系"), selection: $relation) {
            ForEach(relations.indices, id: \.self) { index in Text(relations[index]).tag(index) }
        }
        .frame(minWidth: 150)
    }

    private var conceptField: some View {
        TextField(store.learningText("Related concept", "相关概念"), text: $concept)
            .textFieldStyle(.roundedBorder)
    }

    private var addConnectionButton: some View {
        Button(store.learningText("Add", "添加"), systemImage: "plus") {
            nodes.append((relations[relation], concept.trimmed))
            concept = ""
        }
        .disabled(concept.trimmed.count < 2)
    }
}

private struct StoryLearningModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var scene = 0
    @State private var branch: String?
    @State private var response = ""

    private var dialogue: [String] {
        [
            store.learningText("A strange result has appeared in the archive. Lumi asks you to investigate it through \(topic).", "档案室出现了一个反常结果。Lumi 邀请你用 \(topic) 调查它。"),
            branch == "evidence"
                ? store.learningText("You follow the evidence trail. One observation conflicts with the first explanation—exactly the clue you needed.", "你沿着证据追踪，发现一项观察与最初解释冲突——这正是关键线索。")
                : store.learningText("You begin with intuition, then stop to ask what observation could prove it wrong. The hunch becomes a testable idea.", "你从直觉出发，随后追问什么观察能证明它错误。直觉因此变成了可检验的想法。"),
            store.learningText("The case is ready to close. State the idea you would carry into the next chapter.", "案件即将结案。请说出你会带入下一章的核心想法。")
        ]
    }

    var body: some View {
        MethodCard(
            icon: "theatermasks.fill",
            title: store.learningText("Learn through a local story", "通过本地故事学习"),
            detail: store.learningText("An offline visual-novel flow inspired by the local Paper2Galgame integration: scenes, a branch and a learning check, using original Lumap presentation.", "离线视觉小说流程，借鉴本地 Paper2Galgame 集成的场景、分支和理解检查，并使用 Lumap 自有界面。")
        ) {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [LumapTheme.accent.opacity(0.24), LumapTheme.cyan.opacity(0.12), LumapTheme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 14) {
                    HStack {
                        Label(store.learningText("Chapter 1 · The unexpected clue", "第一章 · 意外线索"), systemImage: "book.pages.fill")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(scene + 1) / 3").font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)

                    Image(systemName: scene == 2 ? "sparkles.rectangle.stack.fill" : "person.crop.circle.fill.badge.questionmark")
                        .font(.system(size: 52))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(LumapTheme.accent, LumapTheme.cyan)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Lumi").font(.caption.weight(.bold)).foregroundStyle(LumapTheme.accent)
                        Text(dialogue[scene])
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(LumapTheme.border) }
            .accessibilityElement(children: .combine)

            if scene == 0 {
                Text(store.learningText("Choose how to investigate", "选择调查方式")).font(.headline)
                ViewThatFits(in: .horizontal) {
                    HStack { branchButtons }
                    VStack(alignment: .leading) { branchButtons }
                }
            } else if scene == 2 {
                TextField(store.learningText("The key idea I will carry forward is…", "我要带走的核心想法是……"), text: $response, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
            }

            HStack {
                Button(store.learningText("Previous", "上一幕"), systemImage: "chevron.left") { scene -= 1 }
                    .disabled(scene == 0)
                if scene < 2 {
                    Button(store.learningText("Continue", "继续"), systemImage: "chevron.right") { scene += 1 }
                        .buttonStyle(.borderedProminent)
                        .disabled(scene == 0 && branch == nil)
                } else {
                    ArtifactButton(enabled: response.trimmed.count >= 8, label: store.learningText("Complete chapter", "完成章节")) {
                        let englishBranch = branch == "evidence" ? "follow evidence" : "test intuition"
                        let chineseBranch = branch == "evidence" ? "跟随证据" : "检验直觉"
                        complete(store.learningText(
                            "Story chapter on \(topic) · Branch: \(englishBranch) · Takeaway: \(response.trimmed)",
                            "\(topic) 故事章节 · 分支：\(chineseBranch) · 核心收获：\(response.trimmed)"
                        ))
                    }
                }
            }
        }
    }

    @ViewBuilder private var branchButtons: some View {
        Button {
            branch = "evidence"
        } label: {
            Label(store.learningText("Follow the evidence", "跟随证据"), systemImage: branch == "evidence" ? "checkmark.circle.fill" : "magnifyingglass.circle")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)

        Button {
            branch = "intuition"
        } label: {
            Label(store.learningText("Test the intuition", "检验直觉"), systemImage: branch == "intuition" ? "checkmark.circle.fill" : "lightbulb")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }
}

private struct FlashRecallModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var index = 0
    @State private var revealed = false
    @State private var remembered = 0
    @State private var review = 0
    @State private var difficultPoint = ""

    private var cards: [(String, String)] {
        [
            (store.learningText("Name the central idea in \(topic).", "说出 \(topic) 的核心概念。"), store.learningText("Use one sentence and avoid repeating the title.", "用一句话回答，不要只重复标题。")),
            (store.learningText("What causes a change in this system?", "什么会引起这个系统变化？"), store.learningText("Name the variable and the direction of change.", "说出变量和变化方向。")),
            (store.learningText("Where might the idea fail?", "这个想法可能在哪里失效？"), store.learningText("Look for a boundary, exception or missing condition.", "寻找边界、例外或缺失条件。"))
        ]
    }

    var body: some View {
        MethodCard(
            icon: "bolt.fill",
            title: store.learningText("Retrieve before reviewing", "先回忆，再复习"),
            detail: store.learningText("Pause, answer from memory, reveal one cue, then rate the recall honestly.", "先暂停并凭记忆回答，再显示提示，最后如实评价回忆效果。")
        ) {
            ProgressView(value: Double(index), total: Double(cards.count))
                .tint(LumapTheme.accent)

            if index < cards.count {
                VStack(spacing: 14) {
                    Text(cards[index].0)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if revealed {
                        Label(cards[index].1, systemImage: "eye.fill")
                            .foregroundStyle(LumapTheme.cyan)
                            .transition(.opacity)
                    } else {
                        Button(store.learningText("Reveal cue", "显示提示"), systemImage: "eye") { revealed = true }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(LumapTheme.mutedSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))

                HStack {
                    Button(store.learningText("Remembered", "已记住"), systemImage: "checkmark") {
                        remembered += 1
                        nextCard()
                    }
                    .buttonStyle(.borderedProminent)
                    Button(store.learningText("Review again", "需要复习"), systemImage: "arrow.counterclockwise") {
                        review += 1
                        nextCard()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Label(store.learningText("\(remembered) remembered · \(review) to review", "记住 \(remembered) 张 · 需复习 \(review) 张"), systemImage: "chart.bar.fill")
                    .font(.headline)
                TextField(store.learningText("The hardest point was…", "最难回忆的是……"), text: $difficultPoint, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                HStack {
                    Button(store.learningText("Run again", "再来一轮"), systemImage: "arrow.clockwise") { reset() }
                    ArtifactButton(enabled: !difficultPoint.trimmed.isEmpty, label: store.learningText("Save recall result", "保存回忆结果")) {
                        complete(store.learningText(
                            "Flash recall for \(topic) · Remembered \(remembered)/\(cards.count) · Review \(review) · Hardest point: \(difficultPoint.trimmed)",
                            "\(topic) 闪记回忆 · 记住 \(remembered)/\(cards.count) · 需复习 \(review) · 最难点：\(difficultPoint.trimmed)"
                        ))
                    }
                }
            }
        }
    }

    private func nextCard() {
        index += 1
        revealed = false
    }

    private func reset() {
        index = 0
        revealed = false
        remembered = 0
        review = 0
        difficultPoint = ""
    }
}

private struct TeachBackModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var explanation = ""
    @State private var feedback: String?

    var body: some View {
        MethodCard(
            icon: "person.wave.2.fill",
            title: store.learningText("Teach Lumi the idea", "把这个概念教给 Lumi"),
            detail: store.learningText("Explain \(topic) to a beginner. Include an idea, a causal link and an example.", "向初学者解释 \(topic)，包含概念、因果联系和例子。")
        ) {
            TextEditor(text: $explanation)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 130, idealHeight: 160, maxHeight: 220)
                .background(LumapTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(LumapTheme.border) }

            HStack {
                Button(store.learningText("Ask for feedback", "请求反馈"), systemImage: "sparkles") {
                    let clean = explanation.trimmed
                    if clean.count < 70 {
                        feedback = store.learningText("Add why the idea works and one concrete example.", "请补充这个概念为何成立，并加入一个具体例子。")
                    } else if !clean.localizedCaseInsensitiveContains("because") && !clean.contains("因为") {
                        feedback = store.learningText("Make one causal bridge explicit with “because”.", "请用“因为”明确写出一条因果连接。")
                    } else {
                        feedback = store.learningText("The causal bridge is visible. Try it on a different example next.", "因果连接已经清楚，下一步可用另一个例子检验。")
                    }
                }
                .disabled(explanation.trimmed.isEmpty)

                ArtifactButton(enabled: explanation.trimmed.count >= 20, label: store.learningText("Save teach-back", "保存反向教学")) {
                    complete(store.learningText("Teach-back on \(topic): \(explanation.trimmed)", "\(topic) 反向教学：\(explanation.trimmed)"))
                }
            }

            if let feedback {
                Label(feedback, systemImage: "sparkles")
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LumapTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct SimulationModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var input = 0.45
    @State private var friction = 0.22
    @State private var prediction = ""

    private var output: Double { max(0, min(100, pow(input, 1.55) * 118 * (1 - friction))) }

    var body: some View {
        MethodCard(
            icon: "slider.horizontal.3",
            title: store.learningText("Change one variable", "只改变一个变量"),
            detail: store.learningText("A deterministic model for \(topic). Predict first, then manipulate inputs and compare.", "这是一个关于 \(topic) 的确定性模型。先预测，再调整输入并比较。")
        ) {
            TextField(store.learningText("I predict the output will…", "我预测输出会……"), text: $prediction, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            VStack(spacing: 13) {
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(0..<12, id: \.self) { bar in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(bar < Int(output / 8.4) ? LumapTheme.cyan.gradient : Color.secondary.opacity(0.12).gradient)
                            .frame(maxWidth: .infinity)
                            .frame(height: 18 + CGFloat(bar) * 5)
                    }
                }
                .frame(minHeight: 82, alignment: .bottom)

                LabeledContent(store.learningText("Input", "输入")) {
                    Slider(value: $input).frame(minWidth: 140)
                }
                LabeledContent(store.learningText("Resistance", "阻力")) {
                    Slider(value: $friction, in: 0...0.75).frame(minWidth: 140)
                }
                HStack {
                    MetricPill(icon: "dial.low", value: input.formatted(.number.precision(.fractionLength(2))), label: store.learningText("Input", "输入"), tint: LumapTheme.accent)
                    MetricPill(icon: "waveform.path.ecg", value: "\(Int(output))%", label: store.learningText("Output", "输出"), tint: LumapTheme.cyan)
                }
            }

            ArtifactButton(enabled: prediction.trimmed.count >= 5, label: store.learningText("Save prediction and result", "保存预测和结果")) {
                let inputText = input.formatted(.number.precision(.fractionLength(2)))
                let frictionText = friction.formatted(.number.precision(.fractionLength(2)))
                complete(store.learningText(
                    "Simulation for \(topic) · Prediction: \(prediction.trimmed) · Input \(inputText), resistance \(frictionText), output \(Int(output))%",
                    "\(topic) 互动模拟 · 预测：\(prediction.trimmed) · 输入 \(inputText)，阻力 \(frictionText)，输出 \(Int(output))%"
                ))
            }
        }
    }
}

private struct SpatialARModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var scale = 0.48
    @State private var anchorCount = 0
    @State private var observation = ""

    var body: some View {
        MethodCard(
            icon: "arkit",
            title: store.learningText("Place the idea in space", "把概念放进空间"),
            detail: store.learningText("A camera-free spatial prototype today, with the same activity contract ready for ARKit on iPhone and visionOS.", "当前为无需摄像头的空间原型，并使用可直接交给 iPhone ARKit 与 visionOS 的同一活动契约。")
        ) {
            Label(store.learningText("Spatial preview · camera is off", "空间预览 · 摄像头未开启"), systemImage: "camera.badge.ellipsis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LumapTheme.secondaryInk)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [LumapTheme.accent.opacity(0.22), LumapTheme.cyan.opacity(0.08), LumapTheme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(spacing: 13) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(LumapTheme.cyan)
                        .overlay {
                            Image(systemName: "cube.transparent.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(LumapTheme.accent)
                                .scaleEffect(0.72 + scale * 0.58)
                        }
                    Text(topic)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(store.learningText("\(anchorCount) learning anchor(s) placed", "已放置 \(anchorCount) 个学习锚点"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(22)
            }
            .frame(minHeight: 210)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LumapTheme.border, lineWidth: 0.75)
            }
            .accessibilityElement(children: .combine)

            LabeledContent(store.learningText("Object scale", "对象缩放")) {
                Slider(value: $scale)
                    .frame(minWidth: 140)
            }

            HStack {
                Button(store.learningText("Place anchor", "放置锚点"), systemImage: "plus.viewfinder") {
                    anchorCount = min(anchorCount + 1, 3)
                }
                .buttonStyle(.bordered)
                .disabled(anchorCount == 3)

                if anchorCount > 0 {
                    Button(store.learningText("Reset space", "重置空间"), systemImage: "arrow.counterclockwise") {
                        anchorCount = 0
                        scale = 0.48
                    }
                    .buttonStyle(.borderless)
                }
            }

            TextField(store.learningText("Describe what changed as you adjusted the object…", "描述调整对象后发生了什么变化……"), text: $observation, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            ArtifactButton(enabled: anchorCount > 0 && observation.trimmed.count >= 8, label: store.learningText("Save spatial observation", "保存空间观察")) {
                complete("Spatial AR lab for \(topic) · Anchors \(anchorCount) · Scale \(scale.formatted(.number.precision(.fractionLength(2)))) · Observation: \(observation.trimmed)")
            }
        }
    }
}

private struct DeliberatePracticeModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var focus = 0
    @State private var attempt = ""
    @State private var correction = ""
    @State private var accuracy = 3

    private var focuses: [String] {
        [store.learningText("Precision", "准确性"), store.learningText("Transfer", "迁移"), store.learningText("Speed", "速度")]
    }

    var body: some View {
        MethodCard(
            icon: "scope",
            title: store.learningText("Practise the weak edge", "针对薄弱点练习"),
            detail: store.learningText("Choose one dimension, make a small attempt, compare it with the criterion, then revise.", "选择一个维度，完成一次小练习，对照标准后再修正。")
        ) {
            Picker(store.learningText("Practice focus", "练习重点"), selection: $focus) {
                ForEach(focuses.indices, id: \.self) { index in Text(focuses[index]).tag(index) }
            }
            .pickerStyle(.segmented)

            Text(store.learningText("Attempt: explain one claim about \(topic) using a claim → reason → evidence structure.", "练习：用“主张 → 理由 → 证据”的结构解释一个关于 \(topic) 的观点。"))
                .font(.headline)

            TextField(store.learningText("Write the first attempt…", "写下第一次尝试……"), text: $attempt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Stepper(value: $accuracy, in: 1...5) {
                LabeledContent(store.learningText("Self-check", "自我检查")) {
                    Text(store.learningText("\(accuracy) of 5", "\(accuracy) / 5"))
                        .monospacedDigit()
                }
            }

            TextField(store.learningText("On the next attempt I will change…", "下一次我会改进……"), text: $correction, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            ArtifactButton(enabled: attempt.trimmed.count >= 15 && correction.trimmed.count >= 6, label: store.learningText("Save practice attempt", "保存练习记录")) {
                complete(store.learningText(
                    "Deliberate practice on \(topic) · Focus: \(focuses[focus]) · Attempt: \(attempt.trimmed) · Self-check: \(accuracy)/5 · Next correction: \(correction.trimmed)",
                    "\(topic) 刻意练习 · 重点：\(focuses[focus]) · 尝试：\(attempt.trimmed) · 自评：\(accuracy)/5 · 下次改进：\(correction.trimmed)"
                ))
            }
        }
    }
}

private struct ReflectionModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var confidence = 0.55
    @State private var surprise = ""
    @State private var uncertainty = ""
    @State private var nextAction = ""

    var body: some View {
        MethodCard(
            icon: "brain.head.profile.fill",
            title: store.learningText("Reflect and choose the next move", "反思并选择下一步"),
            detail: store.learningText("Separate confidence from evidence, name what changed, and leave a concrete next action.", "区分信心和证据，写下认知变化，并留下具体的下一步行动。")
        ) {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent(store.learningText("Confidence", "信心")) {
                    Text("\(Int(confidence * 100))%").monospacedDigit()
                }
                Slider(value: $confidence)
                    .accessibilityValue("\(Int(confidence * 100))%")
            }

            TextField(store.learningText("What surprised me…", "让我意外的是……"), text: $surprise, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField(store.learningText("What remains uncertain…", "我仍然不确定的是……"), text: $uncertainty, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField(store.learningText("My next observable action…", "我的下一项可观察行动……"), text: $nextAction, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            ArtifactButton(enabled: !surprise.trimmed.isEmpty && !uncertainty.trimmed.isEmpty && nextAction.trimmed.count >= 5, label: store.learningText("Save reflection", "保存反思")) {
                complete(store.learningText(
                    "Reflection on \(topic) · Confidence \(Int(confidence * 100))% · Changed: \(surprise.trimmed) · Uncertain: \(uncertainty.trimmed) · Next: \(nextAction.trimmed)",
                    "\(topic) 学习反思 · 信心 \(Int(confidence * 100))% · 认知变化：\(surprise.trimmed) · 仍不确定：\(uncertainty.trimmed) · 下一步：\(nextAction.trimmed)"
                ))
            }
        }
    }
}

private struct MisconceptionDiagnosisModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var selectedClaim: Int?
    @State private var rationale = ""

    private var claims: [String] {
        [
            store.learningText("A system can contain both reinforcing and balancing relationships.", "一个系统可以同时包含增强关系和平衡关系。"),
            store.learningText("If two events move together, one must be causing the other.", "如果两个事件同步变化，其中一个一定导致了另一个。"),
            store.learningText("A useful explanation should make a prediction we could check.", "一个有用的解释应当给出可以检验的预测。")
        ]
    }

    var body: some View {
        MethodCard(
            icon: "exclamationmark.triangle.fill",
            title: store.learningText("Catch the convincing mistake", "识别看似可信的错误"),
            detail: store.learningText("Case: a learner explains \(topic) with three claims. Select the claim that hides a faulty assumption, then propose a test.", "案例：一位学习者用三个观点解释 \(topic)。请选择隐藏错误假设的观点，再提出检验方法。")
        ) {
            VStack(spacing: 10) {
                ForEach(claims.indices, id: \.self) { index in
                    Button {
                        selectedClaim = index
                    } label: {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: selectedClaim == index ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedClaim == index ? LumapTheme.accent : LumapTheme.secondaryInk)
                            Text(claims[index])
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .background(selectedClaim == index ? LumapTheme.accent.opacity(0.10) : LumapTheme.mutedSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedClaim {
                Label(
                    selectedClaim == 1
                        ? store.learningText("That is the hidden leap: correlation alone does not establish causation.", "这里存在隐藏跳跃：仅凭相关性不能证明因果关系。")
                        : store.learningText("This claim can be reasonable. Look for the claim that turns correlation into certainty.", "这个观点可能成立。请寻找把相关性直接当成确定因果的观点。"),
                    systemImage: selectedClaim == 1 ? "lightbulb.fill" : "arrow.counterclockwise"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selectedClaim == 1 ? LumapTheme.mint : LumapTheme.coral)
            }

            TextField(store.learningText("What observation would distinguish correlation from causation?", "什么观察可以区分相关性和因果性？"), text: $rationale, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            ArtifactButton(enabled: selectedClaim != nil && rationale.trimmed.count >= 8, label: store.learningText("Save diagnosis", "保存诊断")) {
                complete(store.learningText(
                    "Misconception diagnosis for \(topic) · Selected claim \((selectedClaim ?? 0) + 1) · Proposed test: \(rationale.trimmed)",
                    "\(topic) 误区诊断 · 选择观点 \((selectedClaim ?? 0) + 1) · 检验方法：\(rationale.trimmed)"
                ))
            }
        }
    }
}

private struct CuriosityBranchModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var selectedBranch: Int?
    @State private var inquiry = ""

    private var branches: [(title: String, prompt: String, icon: String)] {
        [
            (store.learningText("Build it", "构建它"), store.learningText("What is the smallest working version of \(topic) you could create?", "你能构建的最小可运行 \(topic) 是什么？"), "hammer.fill"),
            (store.learningText("Break it", "拆解它"), store.learningText("Under what extreme condition would \(topic) stop working?", "在什么极端条件下，\(topic) 会失效？"), "bolt.slash.fill"),
            (store.learningText("Connect it", "连接它"), store.learningText("Which idea from another field has the same hidden structure?", "另一个领域中，哪个概念具有相同的隐藏结构？"), "link")
        ]
    }

    var body: some View {
        MethodCard(
            icon: "point.3.connected.trianglepath.dotted",
            title: store.learningText("Let curiosity choose the next step", "让好奇心选择下一步"),
            detail: store.learningText("The same topic can open into making, stress-testing or connecting. Pick the pull you feel now; the path can change later.", "同一个主题可以走向构建、压力测试或跨域连接。选择此刻最吸引你的方向，路径之后仍可改变。")
        ) {
            HStack(spacing: 10) {
                ForEach(branches.indices, id: \.self) { index in
                    Button {
                        selectedBranch = index
                        inquiry = ""
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: branches[index].icon)
                                .font(.title3)
                            Text(branches[index].title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(selectedBranch == index ? .white : .primary)
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .background(selectedBranch == index ? LumapTheme.accent : LumapTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedBranch {
                Label(branches[selectedBranch].prompt, systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(LumapTheme.accent)
                TextField(store.learningText("Follow the question in your own words…", "用自己的话继续追问……"), text: $inquiry, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            } else {
                Text(store.learningText("Choose a branch to reveal its first question.", "选择一条分岔，查看第一个问题。"))
                    .font(.subheadline)
                    .foregroundStyle(LumapTheme.secondaryInk)
            }

            ArtifactButton(enabled: selectedBranch != nil && inquiry.trimmed.count >= 8, label: store.learningText("Save curiosity trail", "保存好奇心轨迹")) {
                let branch = branches[selectedBranch ?? 0]
                complete(store.learningText(
                    "Curiosity branch for \(topic) · \(branch.title) · Question trail: \(inquiry.trimmed)",
                    "\(topic) 好奇心分岔 · \(branch.title) · 追问轨迹：\(inquiry.trimmed)"
                ))
            }
        }
    }
}

private struct CounterfactualLabModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var assumption = 0
    @State private var prediction = 0
    @State private var hasRun = false
    @State private var revision = ""

    private var assumptions: [String] {
        [
            store.learningText("Remove the time delay", "移除时间延迟"),
            store.learningText("Reverse the feedback sign", "反转反馈方向"),
            store.learningText("Double the outside disturbance", "把外部扰动加倍")
        ]
    }

    private var observations: [String] {
        [
            store.learningText("The response settles sooner and overshoots less because correction arrives immediately.", "由于修正立即发生，响应更快稳定，过冲也更小。"),
            store.learningText("A stabilising loop becomes reinforcing: each correction now pushes the system farther away.", "稳定回路变成增强回路：每次修正都会把系统推得更远。"),
            store.learningText("The same rule still acts, but the system needs more time or capacity to recover.", "同一规则仍然有效，但系统需要更多时间或能力才能恢复。")
        ]
    }

    var body: some View {
        MethodCard(
            icon: "arrow.uturn.backward.circle.fill",
            title: store.learningText("Change one rule, then predict", "改变一条规则，再做预测"),
            detail: store.learningText("Case: \(topic) behaves like a feedback system. Alter one assumption, commit to a prediction and run the counterfactual.", "案例：\(topic) 像一个反馈系统。改变一项假设，先提交预测，再运行反事实推演。")
        ) {
            Picker(store.learningText("Counterfactual", "反事实条件"), selection: $assumption) {
                ForEach(assumptions.indices, id: \.self) { index in
                    Text(assumptions[index]).tag(index)
                }
            }
            .onChange(of: assumption) { _, _ in
                hasRun = false
                revision = ""
            }

            Picker(store.learningText("My prediction", "我的预测"), selection: $prediction) {
                Text(store.learningText("More stable", "更加稳定")).tag(0)
                Text(store.learningText("Less stable", "更不稳定")).tag(1)
                Text(store.learningText("No meaningful change", "没有明显变化")).tag(2)
            }
            .pickerStyle(.segmented)

            Button {
                withAnimation(.snappy) { hasRun = true }
            } label: {
                Label(store.learningText("Run counterfactual", "运行反事实推演"), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)

            if hasRun {
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.learningText("Simulated observation", "模拟观察"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LumapTheme.accent)
                    Text(observations[assumption])
                    Text(store.learningText("Your prediction: \(["more stable", "less stable", "no meaningful change"][prediction]).", "你的预测：\(["更加稳定", "更不稳定", "没有明显变化"][prediction])。"))
                        .font(.caption)
                        .foregroundStyle(LumapTheme.secondaryInk)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LumapTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                TextField(store.learningText("Revise the causal rule after seeing the result…", "看到结果后，修正你的因果规则……"), text: $revision, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
            }

            ArtifactButton(enabled: hasRun && revision.trimmed.count >= 8, label: store.learningText("Save counterfactual", "保存反事实推演")) {
                complete(store.learningText(
                    "Counterfactual lab for \(topic) · Change: \(assumptions[assumption]) · Prediction index: \(prediction) · Observation: \(observations[assumption]) · Revised rule: \(revision.trimmed)",
                    "\(topic) 反事实推演 · 改变：\(assumptions[assumption]) · 预测序号：\(prediction) · 观察：\(observations[assumption]) · 修正规则：\(revision.trimmed)"
                ))
            }
        }
    }
}

private struct TransferChallengeModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let complete: (String) -> Void
    @State private var context = 0
    @State private var selectedPrinciple: Int?
    @State private var mapping = ""

    private var contexts: [(name: String, caseText: String, expected: Int)] {
        [
            (store.learningText("Urban garden", "城市花园"), store.learningText("More shade lowers evaporation, which preserves water and supports more leaf cover.", "更多遮阴降低蒸发，保留的水分又支持更多叶片覆盖。"), 0),
            (store.learningText("Study team", "学习小组"), store.learningText("When workload rises, the team shortens meetings to pull workload back toward a target.", "工作量上升时，小组缩短会议，把工作量拉回目标水平。"), 1),
            (store.learningText("Personal budget", "个人预算"), store.learningText("Interest increases savings; the larger balance then earns more interest.", "利息增加储蓄，较大的余额又会产生更多利息。"), 0)
        ]
    }

    var body: some View {
        MethodCard(
            icon: "arrow.up.right.square.fill",
            title: store.learningText("Move the principle into a new world", "把原理迁移到新世界"),
            detail: store.learningText("Case: transfer the structure behind \(topic) into a garden, a team or a budget. Surface details change; the causal pattern should remain.", "案例：把 \(topic) 背后的结构迁移到花园、团队或预算中。表面细节会改变，因果模式应保持一致。")
        ) {
            Picker(store.learningText("New context", "新情境"), selection: $context) {
                ForEach(contexts.indices, id: \.self) { index in
                    Text(contexts[index].name).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: context) { _, _ in
                selectedPrinciple = nil
                mapping = ""
            }

            Text(contexts[context].caseText)
                .font(.headline)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LumapTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                transferChoice(store.learningText("Reinforcing pattern", "增强模式"), index: 0)
                transferChoice(store.learningText("Balancing pattern", "平衡模式"), index: 1)
            }

            if let selectedPrinciple {
                Label(
                    selectedPrinciple == contexts[context].expected
                        ? store.learningText("The structural match holds. Now map the roles and its limit.", "结构匹配成立。现在映射各部分角色，并指出边界。")
                        : store.learningText("Look again: does the next change amplify or resist the first one?", "再看一次：下一次变化是在放大还是抵消第一次变化？"),
                    systemImage: selectedPrinciple == contexts[context].expected ? "checkmark.circle.fill" : "arrow.counterclockwise"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selectedPrinciple == contexts[context].expected ? LumapTheme.mint : LumapTheme.coral)
            }

            TextField(store.learningText("Map the original roles to this case, then name one limit…", "把原情境中的角色映射到这个案例，再指出一个迁移边界……"), text: $mapping, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            ArtifactButton(enabled: selectedPrinciple == contexts[context].expected && mapping.trimmed.count >= 10, label: store.learningText("Save transfer map", "保存迁移映射")) {
                complete(store.learningText(
                    "Transfer challenge for \(topic) · Context: \(contexts[context].name) · Pattern: \(selectedPrinciple == 0 ? "reinforcing" : "balancing") · Mapping and limit: \(mapping.trimmed)",
                    "\(topic) 迁移挑战 · 情境：\(contexts[context].name) · 模式：\(selectedPrinciple == 0 ? "增强" : "平衡") · 映射与边界：\(mapping.trimmed)"
                ))
            }
        }
    }

    private func transferChoice(_ title: String, index: Int) -> some View {
        Button {
            selectedPrinciple = index
        } label: {
            Label(title, systemImage: selectedPrinciple == index ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedPrinciple == index ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selectedPrinciple == index ? LumapTheme.accent : LumapTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct NarratedDeckModule: View {
    @EnvironmentObject private var store: LumapStore
    let topic: String
    let sourceExcerpt: String?
    let sourceLabel: String?
    let complete: (String) -> Void

    @StateObject private var narration = NarrationSession.makeDefault()
    @State private var deck: NarratedLearningDeck?
    @State private var slideIndex = 0
    @State private var narratedSlides: Set<Int> = []
    @State private var quizResults: [String: NarratedDeckQuizResult] = [:]
    @State private var presentedQuiz: NarratedDeckQuiz?
    @State private var selectedQuizOptionID: String?
    @State private var generationError: String?
    @State private var quizTask: Task<Void, Never>?
    @State private var narrationEvidenceTask: Task<Void, Never>?
    @State private var didSave = false
    @State private var generationOrigin: NarratedDeckGenerationOrigin = .localDemo
    @State private var activeGenerationID: UUID?

    var body: some View {
        MethodCard(
            icon: "rectangle.on.rectangle.angled",
            title: store.learningText("A lesson that watches back", "一堂会回应你的课"),
            detail: store.learningText(
                "A visual deck, page-by-page narration timeline and surprise retrieval checks generated from the current topic and source.",
                "根据当前主题和资料生成视觉课件、逐页讲解时间轴，并穿插随机回忆小测。"
            )
        ) {
            if let deck {
                deckHeader(deck)
                generationBoundary
                slideStage(deck)
                playerControls(deck)
                narrationBoundary
                DisclosureGroup(store.learningText("Read this slide's narration", "查看本页讲解稿")) {
                    Text(deck.slides[slideIndex].narration)
                        .font(.subheadline)
                        .foregroundStyle(LumapTheme.secondaryInk)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    ArtifactButton(
                        enabled: !narratedSlides.isEmpty && !quizResults.isEmpty && !didSave,
                        label: didSave
                            ? store.learningText("Session saved", "学习记录已保存")
                            : store.learningText("Save deck session", "保存课件学习记录")
                    ) {
                        saveSession(deck)
                    }
                    if !didSave {
                        Text(store.learningText(
                            "Play one Kokoro-narrated slide and answer a quiz to save evidence.",
                            "实际播放至少一页 Kokoro 讲解并回答一次小测后，即可保存学习证据。"
                        ))
                        .font(.caption)
                        .foregroundStyle(LumapTheme.secondaryInk)
                    }
                }
            } else if let generationError {
                Label(generationError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(LumapTheme.coral)
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(store.learningText("Building a five-slide lesson…", "正在生成五页课件……"))
                        .foregroundStyle(LumapTheme.secondaryInk)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .task(id: generationKey) {
            await generateDeck()
        }
        .onDisappear {
            activeGenerationID = nil
            quizTask?.cancel()
            narrationEvidenceTask?.cancel()
            narration.stop()
        }
    }

    private var generationKey: String {
        [topic, sourceLabel ?? "", String(sourceExcerpt?.prefix(40) ?? ""), store.learningLanguage.rawValue]
            .joined(separator: "|")
    }

    private func deckHeader(_ deck: NarratedLearningDeck) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.title)
                    .font(.headline)
                Text(deck.subtitle)
                    .font(.caption)
                    .foregroundStyle(LumapTheme.secondaryInk)
                if let sourceLabel = deck.sourceLabel, !sourceLabel.isEmpty {
                    Label(sourceLabel, systemImage: "doc.text.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LumapTheme.cyan)
                }
            }
            Spacer()
            PrototypeBadge(label: "DECK · \(deck.slides.count) SLIDES")
        }
    }

    private var generationBoundary: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: generationOrigin.usesRemoteModel ? "sparkles" : "arrow.triangle.2.circlepath")
                .foregroundStyle(generationOrigin.usesRemoteModel ? LumapTheme.mint : LumapTheme.gold)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                switch generationOrigin {
                case .remote(let modelID):
                    Text(store.learningText("Live AI lesson · \(modelID)", "实时 AI 课件 · \(modelID)"))
                        .font(.caption.weight(.bold))
                    Text(store.learningText(
                        "Generated now through your saved provider configuration.",
                        "刚刚通过你保存的模型供应商配置生成。"
                    ))
                    .font(.caption2)
                    .foregroundStyle(LumapTheme.secondaryInk)

                case .localDemo:
                    Text(store.learningText("Deterministic local demo", "确定性本地演示"))
                        .font(.caption.weight(.bold))
                    Text(store.learningText(
                        "Save or unlock a provider key in Settings to enable live lesson generation.",
                        "在设置中保存或解锁供应商密钥，即可启用实时课件生成。"
                    ))
                    .font(.caption2)
                    .foregroundStyle(LumapTheme.secondaryInk)

                case .localFallback(let modelID, let reason):
                    Text(store.learningText("Live model unavailable · local demo restored", "实时模型不可用 · 已恢复本地演示"))
                        .font(.caption.weight(.bold))
                    Text("\(modelID) · \(reason)")
                        .font(.caption2)
                        .foregroundStyle(LumapTheme.secondaryInk)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(10)
        .background(LumapTheme.mutedSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func slideStage(_ deck: NarratedLearningDeck) -> some View {
        let slide = deck.slides[slideIndex]
        return ZStack(alignment: .topTrailing) {
            NarratedDeckMacSlide(slide: slide, progress: narration.progress)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)

            Text("\(slideIndex + 1) / \(deck.slides.count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.22), in: Capsule())
                .padding(14)

            if let quiz = presentedQuiz {
                NarratedDeckQuizOverlay(
                    quiz: quiz,
                    selectedOptionID: $selectedQuizOptionID,
                    onContinue: finishQuiz
                )
                .padding(22)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: LumapTheme.accent.opacity(0.14), radius: 20, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.learningText("Slide \(slide.index) of \(deck.slides.count): \(slide.title)", "第 \(slide.index) 页，共 \(deck.slides.count) 页：\(slide.title)"))
    }

    private func playerControls(_ deck: NarratedLearningDeck) -> some View {
        VStack(spacing: 10) {
            ProgressView(value: narration.progress)
                .tint(LumapTheme.accent)
                .accessibilityLabel(store.learningText("Narration progress", "讲解进度"))
                .accessibilityValue(Text(narration.progress, format: .percent.precision(.fractionLength(0))))

            HStack(spacing: 8) {
                controlButton(
                    title: store.learningText("Previous slide", "上一页"),
                    icon: "backward.end.fill",
                    disabled: slideIndex == 0
                ) { changeSlide(by: -1, in: deck) }

                Button {
                    togglePlayback(deck.slides[slideIndex])
                } label: {
                    Label(
                        playbackActionTitle,
                        systemImage: narration.playbackState == .failed
                            ? "arrow.clockwise"
                            : (isActivelyPlaying ? "pause.fill" : "play.fill")
                    )
                    .frame(minWidth: 118, minHeight: 28)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
                .help(store.learningText("Play or pause this slide's narration", "播放或暂停本页讲解"))

                controlButton(
                    title: store.learningText("Next slide", "下一页"),
                    icon: "forward.end.fill",
                    disabled: slideIndex == deck.slides.count - 1
                ) { changeSlide(by: 1, in: deck) }

                controlButton(title: store.learningText("Stop narration", "停止讲解"), icon: "stop.fill") {
                    quizTask?.cancel()
                    narrationEvidenceTask?.cancel()
                    narration.stop()
                }

                controlButton(
                    title: narration.isMuted ? store.learningText("Unmute", "取消静音") : store.learningText("Mute", "静音"),
                    icon: narration.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
                ) {
                    narration.setMuted(!narration.isMuted)
                }

                Spacer(minLength: 4)
                Text(playbackStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(narration.playbackState == .failed
                        ? LumapTheme.coral
                        : (isActivelyPlaying ? LumapTheme.accent : LumapTheme.secondaryInk))
            }
        }
    }

    private func controlButton(title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
        .help(title)
        .accessibilityLabel(title)
    }

    private var narrationBoundary: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: narrationIsReady ? "waveform.circle.fill" : "waveform.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(narrationIsReady ? LumapTheme.cyan : LumapTheme.gold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(narrationIsReady
                    ? store.learningText("Private on-device voice ready", "本地私密语音已就绪")
                    : store.learningText("Open-source voice pack required", "需要开源语音包"))
                    .font(.subheadline.weight(.semibold))
                Text(narrationIsReady
                    ? store.learningText(
                        "Kokoro narration runs locally through sherpa-onnx. Slide text and audio stay on this device.",
                        "Kokoro 讲解通过 sherpa-onnx 在本地运行，幻灯片文本和音频均保留在设备上。"
                    )
                    : store.learningText(
                        "Silent timing preview is active. Install the verified Kokoro pack in Lumap/Application Support to enable human-like audio; no system voice fallback is used.",
                        "当前为静音时间轴预览。请将经过校验的 Kokoro 语音包安装到 Lumap/Application Support 以启用拟人讲解；不会回退到系统音色。"
                    ))
                .font(.caption)
                .foregroundStyle(LumapTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text("SHERPA · KOKORO")
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(LumapTheme.gold)
        }
        .padding(12)
        .background((narrationIsReady ? LumapTheme.cyan : LumapTheme.gold).opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke((narrationIsReady ? LumapTheme.cyan : LumapTheme.gold).opacity(0.20), lineWidth: 0.75)
        }
    }

    private var narrationIsReady: Bool {
        if case .ready = narration.availability { return true }
        return false
    }

    private var isActivelyPlaying: Bool {
        narration.playbackState == .playing || narration.playbackState == .silentPreview || narration.playbackState == .preparing
    }

    private var playbackActionTitle: String {
        switch narration.playbackState {
        case .playing: store.learningText("Pause narration", "暂停讲解")
        case .preparing: store.learningText("Cancel generation", "取消生成")
        case .silentPreview: store.learningText("Pause preview", "暂停预览")
        case .paused: store.learningText("Resume narration", "继续讲解")
        case .failed: store.learningText("Retry narration", "重试讲解")
        default: narrationIsReady
            ? store.learningText("Play narration", "播放讲解")
            : store.learningText("Preview narration", "预览讲解")
        }
    }

    private var playbackStatus: String {
        switch narration.playbackState {
        case .preparing: store.learningText("Generating Kokoro audio…", "正在生成 Kokoro 音频……")
        case .playing: store.learningText("Kokoro narration playing", "Kokoro 讲解播放中")
        case .silentPreview: store.learningText("Silent timeline preview", "静音时间轴预览")
        case .paused: store.learningText("Paused", "已暂停")
        case .completed: store.learningText("Slide preview complete", "本页预览完成")
        case .stopped: store.learningText("Stopped", "已停止")
        case .failed: store.learningText("Kokoro generation failed · retry", "Kokoro 生成失败 · 请重试")
        default: store.learningText("Ready", "就绪")
        }
    }

    private func generateDeck() async {
        let requestID = UUID()
        activeGenerationID = requestID
        generationError = nil
        didSave = false
        quizTask?.cancel()
        narrationEvidenceTask?.cancel()
        narration.stop()
        deck = nil
        generationOrigin = .localDemo
        slideIndex = 0
        narratedSlides = []
        quizResults = [:]
        presentedQuiz = nil
        selectedQuizOptionID = nil
        do {
            let outcome = try await NarratedDeckGenerationCoordinator(
                configuration: store.providerConfigurationForGeneration()
            ).generate(.init(
                topic: topic,
                sourceMaterial: sourceExcerpt,
                sourceLabel: sourceLabel,
                languageCode: store.learningLanguage.rawValue,
                learnerContext: store.profile?.background,
                maximumSlideCount: 5
            ))
            guard activeGenerationID == requestID, !Task.isCancelled else { return }
            let response = outcome.response
            guard !response.deck.slides.isEmpty else {
                throw NarratedDeckGenerationError.malformedProviderResponse
            }
            deck = response.deck
            generationOrigin = outcome.origin
            slideIndex = 0
            narratedSlides = []
            quizResults = [:]
        } catch is CancellationError {
            return
        } catch {
            guard activeGenerationID == requestID, !Task.isCancelled else { return }
            generationError = error.localizedDescription
        }
    }

    private func togglePlayback(_ slide: NarratedDeckSlide) {
        if narration.playbackState == .preparing {
            narrationEvidenceTask?.cancel()
            narration.stop()
            quizTask?.cancel()
        } else if narration.playbackState == .silentPreview || narration.playbackState == .playing {
            narration.pause()
            quizTask?.cancel()
        } else if narration.playbackState == .paused {
            narration.resume()
            scheduleQuizIfNeeded()
        } else {
            narration.play(.init(
                text: slide.narration,
                languageCode: store.learningLanguage.rawValue,
                voiceID: store.learningLanguage == .simplifiedChinese ? "zf_001" : "af_maple",
                speakingRate: 1
            ))
            monitorNarrationEvidence(for: slide.index)
            scheduleQuizIfNeeded()
        }
    }

    private func changeSlide(by offset: Int, in deck: NarratedLearningDeck) {
        quizTask?.cancel()
        narrationEvidenceTask?.cancel()
        presentedQuiz = nil
        selectedQuizOptionID = nil
        narration.stop()
        slideIndex = min(deck.slides.count - 1, max(0, slideIndex + offset))
    }

    private func monitorNarrationEvidence(for slideNumber: Int) {
        narrationEvidenceTask?.cancel()
        narrationEvidenceTask = Task { @MainActor in
            while !Task.isCancelled {
                switch narration.playbackState {
                case .playing, .completed:
                    narratedSlides.insert(slideNumber)
                    return
                case .failed, .stopped, .silentPreview:
                    return
                default:
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        }
    }

    private func scheduleQuizIfNeeded() {
        quizTask?.cancel()
        guard let deck else { return }
        let available = deck.slides.compactMap(\.quiz).filter { quizResults[$0.id] == nil }
        guard let quiz = available.randomElement() else { return }
        quizTask = Task { @MainActor in
            var preparationChecks = 0
            while !Task.isCancelled, narration.playbackState == .preparing, preparationChecks < 150 {
                preparationChecks += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard !Task.isCancelled,
                  narration.playbackState == .silentPreview || narration.playbackState == .playing else { return }
            let delay = Int.random(in: 1500...2600)
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled,
                  narration.playbackState == .silentPreview || narration.playbackState == .playing else { return }
            narration.pause()
            withAnimation(.snappy(duration: 0.24)) {
                presentedQuiz = quiz
                selectedQuizOptionID = nil
            }
        }
    }

    private func finishQuiz() {
        guard let quiz = presentedQuiz, let selectedQuizOptionID else { return }
        quizResults[quiz.id] = .init(
            quizID: quiz.id,
            selectedOptionID: selectedQuizOptionID,
            wasCorrect: selectedQuizOptionID == quiz.correctOptionID
        )
        withAnimation(.snappy(duration: 0.2)) {
            presentedQuiz = nil
            self.selectedQuizOptionID = nil
        }
        narration.resume()
    }

    private func saveSession(_ deck: NarratedLearningDeck) {
        let artifact = NarratedDeckSessionArtifact(
            deckTitle: deck.title,
            slideSummaries: deck.slides.map(\.summary),
            narratedSlideNumbers: narratedSlides.sorted(),
            narrationStatus: narration.playbackState,
            quizResults: quizResults.values.sorted { $0.quizID < $1.quizID }
        )
        complete(artifact.activityText(languageCode: store.learningLanguage.rawValue))
        didSave = true
    }
}

private struct NarratedDeckMacSlide: View {
    let slide: NarratedDeckSlide
    let progress: Double

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.055, green: 0.06, blue: 0.12), Color(red: 0.18, green: 0.11, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            slideVisual
                .opacity(0.82)

            HStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(slide.eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(Color(red: 0.62, green: 0.89, blue: 1))
                    Text(slide.title)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(slide.bullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                Circle()
                                    .fill(Color(red: 0.65, green: 0.58, blue: 1))
                                    .frame(width: 6, height: 6)
                                Text(bullet)
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.86))
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 13) {
                    visualGlyph
                    Text(slide.visual.primaryLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(slide.visual.secondaryLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.58))
                }
                .frame(width: 190)
            }
            .padding(34)
        }
    }

    @ViewBuilder
    private var slideVisual: some View {
        GeometryReader { proxy in
            Circle()
                .fill(Color.purple.opacity(0.22))
                .frame(width: proxy.size.width * 0.5)
                .blur(radius: 45)
                .offset(x: proxy.size.width * 0.60, y: -proxy.size.height * 0.24)
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: proxy.size.width * 0.34)
                .blur(radius: 38)
                .offset(x: -proxy.size.width * 0.10, y: proxy.size.height * 0.62)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var visualGlyph: some View {
        switch slide.visual.kind {
        case .constellation:
            ZStack {
                Circle().stroke(.white.opacity(0.22), lineWidth: 1).frame(width: 132, height: 132)
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? Color.cyan : Color.white.opacity(0.8))
                        .frame(width: index == 0 ? 22 : 9, height: index == 0 ? 22 : 9)
                        .offset(x: cos(Double(index) * .pi / 3) * 60, y: sin(Double(index) * .pi / 3) * 60)
                }
                Image(systemName: "sparkles").font(.title2).foregroundStyle(.white)
            }
            .frame(height: 140)
        case .feedbackLoop:
            ZStack {
                Circle().trim(from: 0.05, to: 0.88).stroke(Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-80))
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.white)
            }
            .frame(width: 132, height: 132)
        case .evidencePulse:
            HStack(alignment: .bottom, spacing: 9) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(index < Int(progress * 7) ? Color.cyan : Color.white.opacity(0.24))
                        .frame(width: 12, height: CGFloat(34 + (index % 4) * 18))
                }
            }
            .frame(height: 140, alignment: .bottom)
        case .transferBridge:
            ZStack {
                Capsule().fill(.white.opacity(0.20)).frame(width: 150, height: 8)
                HStack {
                    Image(systemName: "circle.hexagongrid.fill")
                    Spacer()
                    Image(systemName: "square.grid.3x3.fill")
                }
                .font(.system(size: 34))
                .foregroundStyle(Color.cyan)
                .frame(width: 170)
            }
            .frame(height: 140)
        case .horizon:
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 138, height: 138)
                Circle().trim(from: 0, to: max(0.08, progress)).stroke(Color.cyan, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 112, height: 112)
                Image(systemName: "questionmark.bubble.fill").font(.system(size: 48)).foregroundStyle(.white)
            }
            .frame(height: 140)
        }
    }
}

private struct NarratedDeckQuizOverlay: View {
    @EnvironmentObject private var store: LumapStore
    let quiz: NarratedDeckQuiz
    @Binding var selectedOptionID: String?
    let onContinue: () -> Void

    private var hasAnswered: Bool { selectedOptionID != nil }
    private var isCorrect: Bool { selectedOptionID == quiz.correctOptionID }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(store.learningText("Quick retrieval check", "随机小测"), systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LumapTheme.gold)
                Spacer()
                Text(store.learningText("Narration paused", "讲解已暂停"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(quiz.prompt)
                .font(.headline)

            ForEach(quiz.options) { option in
                Button {
                    guard selectedOptionID == nil else { return }
                    selectedOptionID = option.id
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: optionIcon(option))
                            .foregroundStyle(optionTint(option))
                        Text(option.text)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                    .background(optionBackground(option), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(hasAnswered)
            }

            if hasAnswered {
                Label(quiz.explanation, systemImage: isCorrect ? "checkmark.circle.fill" : "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(isCorrect ? LumapTheme.mint : LumapTheme.gold)
                Button(store.learningText("Continue narration", "继续讲解"), action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: 430)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
    }

    private func optionIcon(_ option: NarratedDeckQuizOption) -> String {
        guard let selectedOptionID else { return "circle" }
        if option.id == quiz.correctOptionID { return "checkmark.circle.fill" }
        return option.id == selectedOptionID ? "xmark.circle.fill" : "circle"
    }

    private func optionTint(_ option: NarratedDeckQuizOption) -> Color {
        guard let selectedOptionID else { return LumapTheme.secondaryInk }
        if option.id == quiz.correctOptionID { return LumapTheme.mint }
        return option.id == selectedOptionID ? LumapTheme.coral : LumapTheme.secondaryInk
    }

    private func optionBackground(_ option: NarratedDeckQuizOption) -> Color {
        guard let selectedOptionID else { return LumapTheme.mutedSurface }
        if option.id == quiz.correctOptionID { return LumapTheme.mint.opacity(0.12) }
        return option.id == selectedOptionID ? LumapTheme.coral.opacity(0.10) : LumapTheme.mutedSurface.opacity(0.62)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
