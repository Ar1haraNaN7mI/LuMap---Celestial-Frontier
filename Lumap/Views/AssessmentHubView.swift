import SwiftData
import SwiftUI

struct AssessmentHubView: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var attempts: [AssessmentRecord]
    @State private var selectedKind: AssessmentKind = .theoretical
    @State private var theoryAnswer = ""
    @State private var theoryResult: AssessmentRecord?
    @State private var prediction = ""
    @State private var observation = ""
    @State private var adjustment = ""
    @State private var practicalResult: AssessmentRecord?
    @State private var theoryActivity: LearningGeneratedActivity?
    @State private var preparing = false
    @State private var practicalActivity: LearningGeneratedActivity?
    @State private var evaluating = false
    @State private var showSpatialMock = false
    @State private var mockValue = 0.45
    @State private var errorMessage: String?

    private var theoryPrompt: String {
        theoryActivity?.prompt ?? ""
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeader(
                        eyebrow: store.t("OPTIONAL EVIDENCE", "可选学习证据"),
                        title: store.t("Check what changed", "检测你学会了什么"),
                        subtitle: store.t("Your tutor checks your reasoning against the researched course material. You can always continue learning without taking a check.", "导师依据课程检索材料评估你的推理。即使不参加检测，也可以继续学习。")
                    )
                    if store.currentGoal == nil {
                        ContentUnavailableView {
                            Label(store.t("Start a learning path first", "请先开始学习路径"), systemImage: "map")
                        } description: {
                            Text(store.t("Choose a topic so the agent can prepare a relevant check.", "选择一个主题，让 Agent 准备对应的检测。"))
                        } actions: {
                            Button(store.t("Go to Discover", "前往探索")) { store.selectedSection = .home }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Text(store.activeTopic).font(.title2.weight(.semibold))
                        Picker("Assessment", selection: $selectedKind) {
                            Label(store.t("Theoretical", "理论检测"), systemImage: "brain.head.profile").tag(AssessmentKind.theoretical)
                            Label(store.t("Practical", "实践检测"), systemImage: "wrench.and.screwdriver").tag(AssessmentKind.practical)
                        }
                        .pickerStyle(.segmented)
                        .disabled(evaluating)
                        if selectedKind == .theoretical { theoryPanel } else { practicalPanel }
                        if evaluating {
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text(store.t("Checking your reasoning and evidence…", "正在检查你的推理和证据……")).foregroundStyle(.secondary)
                            }
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange).textSelection(.enabled)
                        }
                        recentAttempts
                    }
                }
                .padding(LumapTheme.pagePadding)
                .frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if store.currentGoal != nil, showSpatialMock {
                GeometryReader { proxy in
                    let inset: CGFloat = 24
                    let width = min(540, max(300, proxy.size.width - inset * 2))
                    let height = min(470, max(320, proxy.size.height - inset * 2))
                    SpatialARPictureInPicture(value: $mockValue) {
                        withAnimation(spatialAnimation) { showSpatialMock = false }
                    }
                    .frame(width: width, height: height)
                    .position(x: proxy.size.width - width / 2 - inset, y: proxy.size.height - height / 2 - inset)
                }
                .transition(.opacity)
            }
        }
        .task(id: "\(store.currentGoal?.id.uuidString ?? "none")|\(store.currentLearningNode?.id ?? "none")|\(selectedKind.rawValue)") {
            await prepareAssessment()
        }
        .onChange(of: store.currentGoal?.id) { _, _ in
            theoryAnswer = ""; theoryResult = nil; prediction = ""; observation = ""; adjustment = ""
            practicalResult = nil; practicalActivity = nil; errorMessage = nil
        }
    }

    private var theoryPanel: some View {
        LumapCard(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                Label(store.t("Explain and apply", "解释与应用"), systemImage: "text.bubble.fill").font(.headline)
                if theoryPrompt.isEmpty {
                    preparationState
                } else {
                    Text(theoryPrompt).font(.title3.weight(.semibold)).textSelection(.enabled)
                    Text(store.t("Explain the concept, show your reasoning, and test it with an example. The tutor evaluates the meaning of your answer.", "解释概念、展示推理，并用案例检验。导师将评估回答的实际含义。"))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $theoryAnswer)
                        .scrollContentBackground(.hidden).padding(12).frame(minHeight: 170)
                        .background(LumapTheme.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(LumapTheme.border) }
                        .disabled(evaluating)
                    HStack {
                        skipButton(.theoretical)
                        Spacer()
                        Button(store.t("Submit for feedback", "提交并获得反馈")) {
                            Task { await evaluateTheory() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(evaluating || theoryAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let result = theoryResult { ResultCard(record: result) }
                }
            }
        }
    }

    private var practicalPanel: some View {
        LumapCard(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                Label(store.t("Predict · Test · Revise", "预测 · 检验 · 修正"), systemImage: "wrench.and.screwdriver.fill").font(.headline)
                if let activity = practicalActivity {
                    Text(activity.title).font(.title3.weight(.semibold))
                    Text(activity.explanation).foregroundStyle(.secondary)
                    Text(activity.prompt).font(.headline)
                    ForEach(Array(activity.examples.enumerated()), id: \.offset) { _, example in
                        Text(example).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(LumapTheme.card, in: RoundedRectangle(cornerRadius: 12))
                    }
                    assessmentField(title: store.t("1. Your prediction or approach", "1. 你的预测或操作方案"), placeholder: store.t("Describe what you will test and why.", "说明你要检验什么，以及原因。"), text: $prediction)
                    assessmentField(title: store.t("2. Observed or calculated result", "2. 观察或计算的结果"), placeholder: store.t("Give the result, calculation, or evidence from your attempt.", "提供尝试的结果、计算过程或证据。"), text: $observation)
                    assessmentField(title: store.t("3. What you would revise", "3. 你会修正什么"), placeholder: store.t("Compare the evidence with your prediction.", "比较实际证据与最初预测。"), text: $adjustment)
                    HStack {
                        skipButton(.practical)
                        Spacer()
                        Button(store.t("Evaluate practical evidence", "评估实践证据")) {
                            Task { await evaluatePractice(activity) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(evaluating || [prediction, observation, adjustment].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                    }
                    if let result = practicalResult { ResultCard(record: result) }
                } else { preparationState }
                DisclosureGroup(store.t("AR concept preview", "AR 概念展示")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.t("This spatial preview illustrates a future interaction. It does not verify a real experiment or produce assessment scores.", "此空间预览展示未来交互，不会验证真实实验，也不会生成检测分数。"))
                            .font(.callout).foregroundStyle(.secondary)
                        Button(store.t("Open AR preview", "打开 AR 预览"), systemImage: "pip.enter") {
                            withAnimation(spatialAnimation) { showSpatialMock = true }
                        }.buttonStyle(.bordered)
                    }.padding(.top, 10)
                }
            }
        }
    }

    private var preparationState: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isPlanning || store.isGeneratingActivity {
                ProgressView(store.t("Preparing a check for your topic…", "正在为你的主题准备检测……"))
            } else {
                Text(store.learningError ?? store.t("The agent needs to prepare this check.", "Agent 需要先准备这次检测。"))
                    .foregroundStyle(.secondary)
                Button(store.t("Prepare check", "准备检测")) { Task { await prepareAssessment() } }
                    .buttonStyle(.borderedProminent)
            }
        }.padding(.vertical, 12)
    }

    private func skipButton(_ kind: AssessmentKind) -> some View {
        Button(store.t("Skip for now", "暂时跳过")) {
            do { try store.skipAssessment(kind: kind) }
            catch { errorMessage = error.localizedDescription }
        }.buttonStyle(.bordered).disabled(evaluating)
    }

    private var recentAttempts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Recent evidence", "最近的学习证据")).font(.title3.bold())
            if attempts.isEmpty {
                Text(store.t("No assessments yet. Your learning path is still fully available.", "还没有检测记录，你仍然可以完整使用学习路径。"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attempts.prefix(4)) { attempt in
                    HStack(spacing: 12) {
                        Image(systemName: attempt.kind == AssessmentKind.theoretical.rawValue ? "brain.head.profile" : "wrench.and.screwdriver")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attempt.kind.capitalized).font(.subheadline.weight(.semibold))
                            Text(attempt.feedback).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        }
                        Spacer()
                        Text(attempt.status == "skipped" ? store.t("Not assessed", "未检测") : "\(attempt.score ?? 0)/\(attempt.evidenceSummary.contains("AI rubric /100") ? 100 : 6)")
                            .font(.caption.weight(.bold))
                    }
                    .padding(12).background(LumapTheme.card, in: RoundedRectangle(cornerRadius: 13))
                }
            }
        }
    }

    private func assessmentField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(placeholder, text: text, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(3...8).disabled(evaluating)
        }
    }

    @MainActor private func prepareAssessment() async {
        guard store.currentGoal != nil else { return }
        let kind = selectedKind
        let goalID = store.currentGoal?.id
        preparing = true; errorMessage = nil
        defer { preparing = false }
        do {
            let activity = try await store.prepareAssessmentActivity(kind: kind)
            guard !Task.isCancelled, store.currentGoal?.id == goalID,
                  store.currentLearningNode?.id == activity.nodeID, selectedKind == kind else { return }
            if kind == .practical { practicalActivity = activity } else { theoryActivity = activity }
        } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
    }

    @MainActor private func evaluateTheory() async {
        evaluating = true; errorMessage = nil; theoryResult = nil
        defer { evaluating = false }
        do {
            theoryResult = try await store.evaluateAssessment(kind: .theoretical, response: theoryAnswer, displayedActivity: theoryActivity)
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor private func evaluatePractice(_ activity: LearningGeneratedActivity) async {
        evaluating = true; errorMessage = nil; practicalResult = nil
        defer { evaluating = false }
        do {
            practicalResult = try await store.evaluateAssessment(kind: .practical, response: "Context: \(activity.explanation)\nPrediction: \(prediction)\nObservation: \(observation)\nRevision: \(adjustment)", displayedActivity: activity)
        } catch { errorMessage = error.localizedDescription }
    }

    private var spatialAnimation: Animation { reduceMotion ? .easeOut(duration: 0.12) : .snappy }
}

private struct ResultCard: View {
    let record: AssessmentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Feedback", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(LumapTheme.mint)
                Spacer()
                Text("\(record.score ?? 0)/\(record.evidenceSummary.contains("AI rubric /100") ? 100 : 6)")
                    .font(.title3.bold())
            }
            Text(record.feedback)
            Text(record.evidenceSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(LumapTheme.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SpatialARPictureInPicture: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var value: Double
    let close: () -> Void
    @State private var anchorCount = 2
    @State private var selectedAnchor = 0
    @State private var scanProgress = 0.08
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    SpatialCameraScene(
                        value: value,
                        anchorCount: anchorCount,
                        selectedAnchor: $selectedAnchor,
                        scanProgress: scanProgress,
                        pulse: pulse
                    )

                    controlDeck
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
        }
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.18)) }
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .onAppear(perform: startMotion)
        .onChange(of: reduceMotion) { _, _ in startMotion() }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(LumapTheme.coral)
                .frame(width: 7, height: 7)
                .overlay { Circle().stroke(.white.opacity(0.7), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 1) {
                Text(store.t("Spatial lab preview", "空间实验预览"))
                    .font(.caption.weight(.bold))
                Text(store.t("Interactive render · no camera feed", "交互渲染 · 未启用摄像头画面"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            PrototypeBadge(label: "2D FALLBACK")
            Button(action: close) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(store.t("Close spatial preview", "关闭空间预览"))
            .accessibilityLabel(store.t("Close spatial preview", "关闭空间预览"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
    }

    private var controlDeck: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { anchorControls; Spacer(minLength: 6); observationLabel }
                VStack(alignment: .leading, spacing: 6) { anchorControls; observationLabel }
            }

            HStack(spacing: 10) {
                Image(systemName: "thermometer.variable.and.figure")
                    .foregroundStyle(heatColor)
                    .accessibilityHidden(true)
                Slider(value: $value, in: 0...1)
                    .tint(heatColor)
                    .accessibilityLabel(store.t("Energy retention", "能量保留"))
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(width: 38, alignment: .trailing)
            }

            HStack(spacing: 5) {
                SpatialStepPill(number: 1, label: store.t("Scan", "扫描"), state: .complete)
                SpatialStepPill(number: 2, label: store.t("Place", "放置"), state: anchorCount > 0 ? .complete : .current)
                SpatialStepPill(number: 3, label: store.t("Adjust", "调参"), state: .current)
                SpatialStepPill(number: 4, label: store.t("Explain", "解释"), state: .upcoming)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.75)
        }
        .padding(10)
    }

    @ViewBuilder
    private var anchorControls: some View {
        HStack(spacing: 6) {
            Button {
                if anchorCount < 4 {
                    anchorCount += 1
                    selectedAnchor = anchorCount - 1
                }
            } label: {
                Label(store.t("Place", "放置"), systemImage: "plus.viewfinder")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(anchorCount == 4)

            ForEach(0..<anchorCount, id: \.self) { index in
                Button("A\(index + 1)") { selectedAnchor = index }
                    .font(.caption2.weight(.bold).monospaced())
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(index == selectedAnchor ? LumapTheme.cyan : .secondary)
                    .accessibilityLabel(store.t("Select anchor \(index + 1)", "选择锚点 \(index + 1)"))
                    .accessibilityAddTraits(index == selectedAnchor ? .isSelected : [])
            }
        }
    }

    private var observationLabel: some View {
        Label(observationText, systemImage: value > 0.66 ? "flame.fill" : value > 0.33 ? "waveform.path.ecg" : "wind")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(1)
            .accessibilityLabel(store.t("Live observation: \(observationText)", "实时观察：\(observationText)"))
    }

    private var observationText: String {
        if value > 0.66 {
            return store.t("Heat clusters around A\(selectedAnchor + 1)", "热量聚集在 A\(selectedAnchor + 1) 周围")
        }
        if value > 0.33 {
            return store.t("Energy reaches a stable loop", "能量进入稳定循环")
        }
        return store.t("Energy disperses across the surface", "能量向表面扩散")
    }

    private var heatColor: Color {
        value > 0.66 ? LumapTheme.coral : value > 0.33 ? LumapTheme.gold : LumapTheme.cyan
    }

    private func startMotion() {
        if reduceMotion {
            scanProgress = 0.56
            pulse = false
            return
        }
        scanProgress = 0.04
        pulse = false
        withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false)) {
            scanProgress = 0.96
        }
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private struct SpatialCameraScene: View {
    let value: Double
    let anchorCount: Int
    @Binding var selectedAnchor: Int
    let scanProgress: Double
    let pulse: Bool

    private let positions: [CGPoint] = [
        CGPoint(x: 0.31, y: 0.35),
        CGPoint(x: 0.63, y: 0.29),
        CGPoint(x: 0.77, y: 0.49),
        CGPoint(x: 0.43, y: 0.52)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let selectedPosition = positions[min(selectedAnchor, positions.count - 1)]
            let objectPoint = CGPoint(x: size.width * selectedPosition.x, y: size.height * selectedPosition.y)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.055, blue: 0.11), Color(red: 0.02, green: 0.12, blue: 0.16), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [heatColor.opacity(0.34 + value * 0.2), .clear],
                    center: UnitPoint(x: selectedPosition.x, y: selectedPosition.y),
                    startRadius: 4,
                    endRadius: 150 + CGFloat(value) * 60
                )

                SpatialPerspectiveGrid()
                    .opacity(0.72)

                ForEach(0..<anchorCount, id: \.self) { index in
                    let position = positions[index]
                    Button {
                        selectedAnchor = index
                    } label: {
                        SpatialAnchorMarker(index: index, selected: selectedAnchor == index)
                    }
                    .buttonStyle(.plain)
                    .position(x: size.width * position.x, y: size.height * position.y)
                    .accessibilityLabel("Anchor \(index + 1)")
                    .accessibilityAddTraits(selectedAnchor == index ? .isSelected : [])
                }

                SpatialEnergyObject(value: value, pulse: pulse)
                    .frame(width: 118 + CGFloat(value) * 38, height: 118 + CGFloat(value) * 38)
                    .position(objectPoint)
                    .allowsHitTesting(false)

                SpatialParticles(value: value, pulse: pulse)
                    .frame(width: 210, height: 150)
                    .position(objectPoint)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.cyan.opacity(0.48), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                    .shadow(color: .cyan.opacity(0.75), radius: 5)
                    .position(x: size.width / 2, y: max(20, size.height * scanProgress))
                    .allowsHitTesting(false)

                VStack {
                    HStack(spacing: 7) {
                        Label("SURFACE FOUND", systemImage: "viewfinder.circle.fill")
                        Spacer()
                        Label("CAMERA OFF · DEMO", systemImage: "camera.slash.fill")
                    }
                    Spacer()
                }
                .font(.caption2.weight(.bold).monospaced())
                .foregroundStyle(.cyan)
                .padding(12)
                .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Interactive spatial energy model")
    }

    private var heatColor: Color {
        value > 0.66 ? LumapTheme.coral : value > 0.33 ? LumapTheme.gold : LumapTheme.cyan
    }
}

private struct SpatialPerspectiveGrid: View {
    var body: some View {
        Canvas { context, size in
            let horizon = size.height * 0.26
            let vanishingPoint = CGPoint(x: size.width * 0.53, y: horizon)
            var rays = Path()
            for index in -7...7 {
                let bottomX = size.width * 0.5 + CGFloat(index) * size.width * 0.12
                rays.move(to: vanishingPoint)
                rays.addLine(to: CGPoint(x: bottomX, y: size.height))
            }
            context.stroke(rays, with: .color(.cyan.opacity(0.24)), lineWidth: 0.75)

            var depthLines = Path()
            for index in 0...10 {
                let progress = CGFloat(index) / 10
                let eased = progress * progress
                let y = horizon + (size.height - horizon) * eased
                depthLines.move(to: CGPoint(x: 0, y: y))
                depthLines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(depthLines, with: .color(.mint.opacity(0.2)), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

private struct SpatialAnchorMarker: View {
    let index: Int
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.45))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(selected ? Color.white : Color.cyan.opacity(0.75), style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: selected ? [] : [3, 3]))
                .frame(width: selected ? 36 : 30, height: selected ? 36 : 30)
            Image(systemName: selected ? "dot.scope" : "plus")
                .font(.caption.weight(.bold))
            Text("A\(index + 1)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .offset(y: 25)
        }
        .foregroundStyle(selected ? .white : .cyan)
        .frame(width: 48, height: 56)
        .contentShape(Rectangle())
    }
}

private struct SpatialEnergyObject: View {
    let value: Double
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), heatColor.opacity(0.82), heatColor.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 68
                    )
                )
                .scaleEffect(pulse ? 1.05 : 0.94)
            Circle()
                .stroke(.white.opacity(0.72), lineWidth: 1.2)
                .padding(18)
            Ellipse()
                .stroke(heatColor.opacity(0.9), lineWidth: 2)
                .frame(height: 42)
                .rotationEffect(.degrees(24))
            Ellipse()
                .stroke(.cyan.opacity(0.72), lineWidth: 1.5)
                .frame(height: 34)
                .rotationEffect(.degrees(-42))
            VStack(spacing: 1) {
                Text("ENERGY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.headline.weight(.heavy).monospacedDigit())
            }
            .foregroundStyle(.white)
        }
        .shadow(color: heatColor.opacity(0.72), radius: 18 + CGFloat(value) * 10)
    }

    private var heatColor: Color {
        value > 0.66 ? LumapTheme.coral : value > 0.33 ? LumapTheme.gold : LumapTheme.cyan
    }
}

private struct SpatialParticles: View {
    let value: Double
    let pulse: Bool

    var body: some View {
        GeometryReader { proxy in
            let activeCount = max(4, Int(value * 18))
            ForEach(0..<18, id: \.self) { index in
                if index < activeCount {
                    let angle = Double(index) * 2.399
                    let radius = CGFloat(28 + (index % 6) * 11) * (pulse ? 1.04 : 0.96)
                    Circle()
                        .fill(index.isMultiple(of: 3) ? Color.white : heatColor)
                        .frame(width: CGFloat(3 + index % 4), height: CGFloat(3 + index % 4))
                        .shadow(color: heatColor, radius: 4)
                        .position(
                            x: proxy.size.width / 2 + CGFloat(cos(angle)) * radius,
                            y: proxy.size.height / 2 + CGFloat(sin(angle)) * radius * 0.58
                        )
                }
            }
        }
    }

    private var heatColor: Color {
        value > 0.66 ? LumapTheme.coral : value > 0.33 ? LumapTheme.gold : LumapTheme.cyan
    }
}

private struct SpatialStepPill: View {
    enum State { case complete, current, upcoming }
    let number: Int
    let label: String
    let state: State

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state == .complete ? "checkmark.circle.fill" : state == .current ? "circle.inset.filled" : "circle")
                .accessibilityHidden(true)
            Text(label)
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(state == .upcoming ? .secondary : state == .current ? LumapTheme.cyan : LumapTheme.mint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.18), in: Capsule())
        .accessibilityLabel("Step \(number), \(label), \(accessibilityState)")
    }

    private var accessibilityState: String {
        switch state {
        case .complete: "complete"
        case .current: "current"
        case .upcoming: "upcoming"
        }
    }
}
