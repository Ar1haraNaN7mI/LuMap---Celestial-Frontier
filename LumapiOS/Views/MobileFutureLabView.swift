import SwiftUI

struct MobileFutureLabView: View {
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("Make learning your own", "让学习属于你"))
                        .font(.largeTitle.bold())
                    Text(store.t(
                        "Work with your actual sources, learning path, session files and confirmed interests. Spatial Vision remains an interactive AR concept preview.",
                        "使用真实资料、学习路径、会话文件和已确认兴趣。空间视觉仍是可交互的 AR 概念预览。"
                    ))
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                ForEach(FutureLabScenario.allCases) { scenario in
                    NavigationLink {
                        MobileFutureLabScenarioView(scenario: scenario)
                    } label: {
                        HStack(spacing: 14) {
                            MobileIconTile(systemImage: scenario.icon, color: scenarioColor(scenario))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scenario.title(language: store.language))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(scenario == .spatialVision ? store.t("Interactive AR concept preview", "可交互 AR 概念预览") : store.t("Your sources, progress and model", "真实资料、进度与模型"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .mobileCard(prominent: scenario == .knowledgeStudio)
                    .accessibilityIdentifier("future-lab-\(scenario.rawValue)")
                }

                Label(store.t(
                    "Model actions use your saved API configuration. Learning progress is stored locally.",
                    "模型操作使用已保存的 API 配置，学习进度保存在本地。"
                ), systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Future Lab", "未来实验室"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scenarioColor(_ scenario: FutureLabScenario) -> Color {
        switch scenario {
        case .knowledgeStudio: MobileTheme.accent
        case .spatialVision: MobileTheme.cyan
        case .adaptivePath: MobileTheme.mint
        case .learningHandoff: MobileTheme.coral
        case .interestConstellation: MobileTheme.gold
        }
    }
}

struct MobileFutureLabScenarioView: View {
    let scenario: FutureLabScenario
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        Group {
            if scenario == .spatialVision {
                MobileSpatialVisionConcept()
            } else {
                ScrollView {
                    LearningWorkspaceView(scenario: scenario).padding(18)
                }
            }
        }
        .background(MobileTheme.background)
        .navigationTitle(scenario.title(language: store.language))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if scenario == .spatialVision { MobilePrototypeFooter() }
        }
        .accessibilityIdentifier("future-lab-scene-\(scenario.rawValue)")
    }
}

private struct MobileConceptBadge: View {
    var body: some View {
        Text("CONCEPT DEMO")
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(MobileTheme.gold)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(MobileTheme.gold.opacity(0.11), in: Capsule())
            .overlay { Capsule().stroke(MobileTheme.gold.opacity(0.22), lineWidth: 0.5) }
    }
}

private struct MobilePrototypeFooter: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(MobileTheme.gold)
            Text("Interactive front-end prototype · Synthetic data · No live service")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct MobileConceptHeader: View {
    @EnvironmentObject private var store: LumapStore
    let scenario: FutureLabScenario
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MobileIconTile(systemImage: scenario.icon, color: MobileTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    MobileConceptBadge()
                    Text(scenario.title(language: store.language))
                        .font(.title2.bold())
                    Text(scenario.subtitle(language: store.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Label(status, systemImage: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MobileTheme.mint)
        }
        .mobileCard(prominent: true)
    }
}

private struct MobileKnowledgeStudioConcept: View {
    @EnvironmentObject private var store: LumapStore
    @State private var sources: Set<Int> = [0, 1]
    @State private var citation = 0
    @State private var revision = 1

    private let sourceCopy = [
        ("Lecture 04.pdf", "pp. 8–9", "Albedo changes how much incoming energy a surface reflects."),
        ("Lab notebook.md", "lines 41–56", "The ice sample crossed the melt threshold after the lamp moved closer."),
        ("Climate dataset.csv", "rows 18–32", "Observed reflectance fell as dark surface area increased.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MobileConceptHeader(scenario: .knowledgeStudio, status: store.t("2 sources · citation inspector open", "2 个资料 · 引用检查器已打开"))

                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("Why can melting ice accelerate further warming?", "为什么融冰会进一步加速变暖？"))
                        .font(.title3.bold())
                    Text(store.t(
                        "Bright ice reflects energy. When it melts, a darker surface absorbs more energy. The lab observation shows the threshold effect, forming a reinforcing loop [1][2].",
                        "明亮的冰面会反射能量。融化后，较暗的表面吸收更多能量。实验记录展示了阈值效应，从而形成增强回路 [1][2]。"
                    ))
                    .font(.body)

                    HStack(spacing: 8) {
                        citationButton(0)
                        citationButton(1)
                        Spacer()
                        Text("SYNTHESIS \(revision)")
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    Label(sourceCopy[citation].2, systemImage: "quote.opening")
                        .font(.callout)
                        .foregroundStyle(MobileTheme.cyan)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MobileTheme.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("knowledge-citation-detail")
                }
                .mobileCard(prominent: true)

                VStack(alignment: .leading, spacing: 9) {
                    Text(store.t("Sources used", "使用的资料"))
                        .font(.headline)
                    ForEach(sourceCopy.indices, id: \.self) { index in
                        Button {
                            if sources.contains(index) { sources.remove(index) } else { sources.insert(index) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: sources.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(sources.contains(index) ? MobileTheme.mint : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sourceCopy[index].0).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(sourceCopy[index].1).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("knowledge-source-\(index)")
                    }
                }
                .mobileCard()

                HStack {
                    Button {
                        revision += 1
                    } label: {
                        Label(store.t("Ask follow-up", "继续追问"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sources.isEmpty)
                    .accessibilityIdentifier("knowledge-follow-up")
                    Button(store.t("Reset", "重置")) {
                        sources = [0, 1]
                        citation = 0
                        revision = 1
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
        }
    }

    private func citationButton(_ index: Int) -> some View {
        Button("[\(index + 1)] \(sourceCopy[index].1)") { citation = index }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(citation == index ? MobileTheme.cyan : MobileTheme.accent)
            .accessibilityIdentifier("knowledge-citation-\(index)")
    }
}

private struct MobileSpatialVisionConcept: View {
    @EnvironmentObject private var store: LumapStore
    @State private var intensity = 0.58
    @State private var layer = 1
    @State private var anchored = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MobileConceptHeader(scenario: .spatialVision, status: store.t("AR + glasses simulation · camera off", "AR + 眼镜模拟 · 相机关闭"))

                ZStack {
                    LinearGradient(colors: [MobileTheme.cyan.opacity(0.24), MobileTheme.accent.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Canvas { context, size in
                        for x in stride(from: 0 as CGFloat, through: size.width, by: 34) {
                            var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(p, with: .color(MobileTheme.cyan.opacity(0.12)), lineWidth: 0.5)
                        }
                        for y in stride(from: 0 as CGFloat, through: size.height, by: 34) {
                            var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(p, with: .color(MobileTheme.cyan.opacity(0.12)), lineWidth: 0.5)
                        }
                    }
                    VStack(spacing: 10) {
                        ZStack {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .stroke(index == layer ? MobileTheme.accent : MobileTheme.cyan.opacity(0.45), lineWidth: index == layer ? 3 : 1.5)
                                    .frame(width: CGFloat(78 + index * 45), height: CGFloat(78 + index * 45))
                            }
                            Circle()
                                .fill(RadialGradient(colors: [MobileTheme.gold, MobileTheme.coral], center: .center, startRadius: 2, endRadius: 38))
                                .frame(width: 68, height: 68)
                                .shadow(color: MobileTheme.gold.opacity(0.42), radius: 20)
                            Circle().fill(MobileTheme.mint).frame(width: 22, height: 22)
                                .offset(x: CGFloat(53 + layer * 20), y: -12)
                        }
                        Text(store.t("Energy transfer model", "能量传递模型"))
                            .font(.headline)
                        Text(store.t("Layer \(layer + 1) · \(Int(intensity * 100))%", "第 \(layer + 1) 层 · \(Int(intensity * 100))%"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .scaleEffect(anchored ? 1 : 0.80)
                    .opacity(anchored ? 1 : 0.55)
                    VStack {
                        HStack {
                            MobileConceptBadge()
                            Spacer()
                            Label(store.t("CAMERA OFF", "相机关闭"), systemImage: "camera.slash.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(MobileTheme.coral)
                        }
                        Spacer()
                    }
                    .padding(14)
                }
                .frame(height: 310)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(MobileTheme.border.opacity(0.5), lineWidth: 0.5) }
                .accessibilityIdentifier("spatial-concept-viewport")

                VStack(alignment: .leading, spacing: 12) {
                    Picker(store.t("Layer", "层级"), selection: $layer) {
                        Text("1").tag(0); Text("2").tag(1); Text("3").tag(2)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text(store.t("Intensity", "强度"))
                        Slider(value: $intensity, in: 0.1...1)
                    }
                    Button {
                        anchored.toggle()
                    } label: {
                        Label(anchored ? store.t("Remove virtual anchor", "移除虚拟锚点") : store.t("Place virtual anchor", "放置虚拟锚点"), systemImage: anchored ? "xmark.circle" : "viewfinder")
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("spatial-place-object")
                    if anchored {
                        Label(store.t("Anchor A1 stable · glasses overlay preview", "锚点 A1 稳定 · 眼镜叠加层预览"), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MobileTheme.mint)
                    }
                    Button(store.t("Reset concept", "重置概念演示")) {
                        intensity = 0.58; layer = 1; anchored = true
                    }
                    .buttonStyle(.bordered)
                }
                .mobileCard()
            }
            .padding(16)
        }
    }
}

private struct MobileAdaptivePathConcept: View {
    @EnvironmentObject private var store: LumapStore
    @State private var intent = 0
    @State private var confidence = 0.44
    @State private var step = 1

    private var weights: [Double] {
        switch intent {
        case 1: return [0.20, min(0.82, 0.54 + Double(step) * 0.04), 0.24]
        case 2: return [0.16, 0.25, min(0.86, 0.59 + Double(step) * 0.04)]
        default: return [min(0.80, 0.50 + Double(step) * 0.04), 0.31, 0.19]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MobileConceptHeader(scenario: .adaptivePath, status: store.t("Simulated policy snapshot \(step)", "模拟策略快照 \(step)"))

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(store.t("Next learning action", "下一个学习行动")).font(.headline)
                        Spacer()
                        Text([store.t("EXPLAIN", "讲解"), store.t("SIMULATE", "模拟"), store.t("CHALLENGE", "挑战")][intent])
                            .font(.caption2.bold()).foregroundStyle(MobileTheme.accent)
                    }
                    HStack(spacing: 7) {
                        policyNode(store.t("Concept", "概念"), icon: "book.closed.fill", active: intent == 0)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        policyNode(store.t("Practice", "练习"), icon: "hammer.fill", active: intent == 1)
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        policyNode(store.t("Transfer", "迁移"), icon: "arrow.up.right.square.fill", active: intent == 2)
                    }
                }
                .mobileCard(prominent: true)

                VStack(alignment: .leading, spacing: 12) {
                    Text(store.t("Action probabilities", "行动概率")).font(.headline)
                    probability(store.t("Explain", "讲解"), weights[0], MobileTheme.accent)
                    probability(store.t("Simulate", "模拟"), weights[1], MobileTheme.cyan)
                    probability(store.t("Challenge", "挑战"), weights[2], MobileTheme.mint)
                }
                .mobileCard()

                VStack(alignment: .leading, spacing: 12) {
                    Picker(store.t("Intent", "意图"), selection: $intent) {
                        Text(store.t("Explore", "探索")).tag(0)
                        Text(store.t("Practise", "练习")).tag(1)
                        Text(store.t("Prove", "验证")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text(store.t("Confidence", "信心"))
                        Slider(value: $confidence, in: 0...1)
                        Text(confidence, format: .percent).monospacedDigit().frame(width: 42)
                    }
                    Button {
                        step += 1
                        intent = confidence > 0.72 ? 2 : (confidence > 0.38 ? 1 : 0)
                    } label: {
                        Label(store.t("Run local policy step", "运行本地策略步骤"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("adaptive-run-policy")
                    Button(store.t("Reset policy", "重置策略")) {
                        intent = 0; confidence = 0.44; step = 1
                    }
                    .buttonStyle(.bordered)
                }
                .mobileCard()
            }
            .padding(16)
        }
    }

    private func policyNode(_ title: String, icon: String, active: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: active ? "checkmark.circle.fill" : icon)
                .font(.headline)
            Text(title).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(active ? MobileTheme.mint : .secondary)
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(active ? MobileTheme.mint.opacity(0.10) : MobileTheme.raisedCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func probability(_ title: String, _ value: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title).font(.caption.weight(.semibold)); Spacer(); Text(value, format: .percent).font(.caption.monospacedDigit()) }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.11))
                    Capsule().fill(tint).frame(width: max(4, proxy.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct MobileLearningHandoffConcept: View {
    @EnvironmentObject private var store: LumapStore
    @State private var device = 1
    @State private var completed = 0
    @State private var checkpoint = 0.63

    private let devices = [("iPhone", "iphone", "Pocket quiz"), ("Mac", "macbook", "Deep work"), ("Glasses", "vision.pro", "Object lab")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MobileConceptHeader(scenario: .learningHandoff, status: store.t("Local relay preview", "本地接力预览"))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.t("Climate feedback loops", "气候反馈回路")).font(.title3.bold())
                            Text(store.t("Checkpoint: explain ice–albedo", "检查点：解释冰–反照率")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(checkpoint, format: .percent.precision(.fractionLength(0)))
                            .font(.title2.monospacedDigit().bold()).foregroundStyle(MobileTheme.accent)
                    }
                    ProgressView(value: checkpoint).tint(MobileTheme.accent)
                    HStack(spacing: 7) {
                        ForEach(devices.indices, id: \.self) { index in
                            Button {
                                device = index
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: devices[index].1).font(.title2)
                                    Text(devices[index].0).font(.caption.weight(.semibold))
                                    Text(devices[index].2).font(.caption2).lineLimit(1)
                                }
                                .foregroundStyle(device == index ? .white : .primary)
                                .frame(maxWidth: .infinity, minHeight: 92)
                                .background(device == index ? AnyShapeStyle(MobileTheme.gradient) : AnyShapeStyle(MobileTheme.raisedCard), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("handoff-device-\(index)")
                        }
                    }
                }
                .mobileCard(prominent: true)

                VStack(alignment: .leading, spacing: 12) {
                    Label(store.t("Continue on \(devices[device].0)", "在 \(devices[device].0) 上继续"), systemImage: devices[device].1)
                        .font(.title3.bold())
                    Text(store.t("Checkpoint, note and preferred method move together in this simulated handoff.", "检查点、笔记和偏好学习方式会在这次模拟接力中一起转移。"))
                        .foregroundStyle(.secondary)
                    Button {
                        completed += 1
                        checkpoint = min(0.95, checkpoint + 0.05)
                    } label: {
                        Label(store.t("Simulate handoff", "模拟接力"), systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("handoff-simulate")
                    if completed > 0 {
                        Label(store.t("Handoff #\(completed) restored on \(devices[device].0)", "接力 #\(completed) 已在 \(devices[device].0) 恢复"), systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(MobileTheme.mint)
                            .accessibilityIdentifier("handoff-success")
                    }
                    Button(store.t("Reset", "重置")) {
                        device = 1; completed = 0; checkpoint = 0.63
                    }
                    .buttonStyle(.bordered)
                }
                .mobileCard()
            }
            .padding(16)
        }
    }
}

private struct MobileInterestConstellationConcept: View {
    @EnvironmentObject private var store: LumapStore
    @State private var signals: Set<Int> = [0, 1, 3]
    @State private var threshold = 0.46
    @State private var mapRevision = 1

    private let signalCopy = [
        ("Astronomy", "play.rectangle.fill"),
        ("Design", "bookmark.fill"),
        ("Audio", "music.note"),
        ("Climate", "magnifyingglass"),
        ("Code", "chevron.left.forwardslash.chevron.right")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MobileConceptHeader(scenario: .interestConstellation, status: store.t("Synthetic profile · editable", "合成画像 · 可编辑"))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(store.t("Possible learning orbit", "可能的学习轨道")).font(.headline)
                        Spacer()
                        Text("MAP \(mapRevision)").font(.caption2.monospaced().bold()).foregroundStyle(.secondary)
                    }
                    ZStack {
                        Circle().stroke(MobileTheme.accent.opacity(0.20), lineWidth: 1).frame(width: 230, height: 230)
                        Circle().stroke(MobileTheme.cyan.opacity(0.20), lineWidth: 1).frame(width: 154, height: 154)
                        Circle().fill(MobileTheme.gradient).frame(width: 64, height: 64)
                            .overlay { Text("YOU").font(.caption.bold()).foregroundStyle(.white) }
                        ForEach(Array(signals.sorted().enumerated()), id: \.element) { order, index in
                            let angle = Double(order) / Double(max(signals.count, 1)) * Double.pi * 2 - Double.pi / 2
                            let radius = 86.0 + Double(index % 2) * 17.0
                            VStack(spacing: 2) {
                                Image(systemName: signalCopy[index].1)
                                Text(signalCopy[index].0).font(.caption2.bold())
                            }
                            .foregroundStyle(index % 2 == 0 ? MobileTheme.cyan : MobileTheme.mint)
                            .frame(width: 66, height: 48)
                            .background(MobileTheme.raisedCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .offset(x: CGFloat(cos(angle) * radius), y: CGFloat(sin(angle) * radius))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    Label(recommendation, systemImage: "lightbulb.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(MobileTheme.gold)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MobileTheme.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("interest-recommendation")
                }
                .mobileCard(prominent: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text(store.t("Synthetic signals", "合成信号")).font(.headline)
                    ForEach(signalCopy.indices, id: \.self) { index in
                        Toggle(isOn: Binding(
                            get: { signals.contains(index) },
                            set: { value in if value { signals.insert(index) } else { signals.remove(index) } }
                        )) {
                            Label(signalCopy[index].0, systemImage: signalCopy[index].1)
                        }
                        .accessibilityIdentifier("interest-signal-\(index)")
                    }
                    HStack {
                        Text(store.t("Relevance", "相关度"))
                        Slider(value: $threshold, in: 0.2...0.8)
                        Text(threshold, format: .percent).monospacedDigit().frame(width: 42)
                    }
                    Button {
                        mapRevision += 1
                    } label: {
                        Label(store.t("Rebuild local map", "重建本地星图"), systemImage: "sparkles")
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("interest-rebuild")
                    Button(store.t("Reset signals", "重置信号")) {
                        signals = [0, 1, 3]; threshold = 0.46; mapRevision = 1
                    }
                    .buttonStyle(.bordered)
                    Text(store.t("All signals and names are invented for this demo.", "所有信号与名称均为此演示虚构。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .mobileCard()
            }
            .padding(16)
        }
    }

    private var recommendation: String {
        if signals.contains(0), signals.contains(3) {
            return store.t("Suggested: model planetary climate feedback as a visual simulation.", "推荐：用视觉模拟建立行星气候反馈模型。")
        } else if signals.contains(1), signals.contains(4) {
            return store.t("Suggested: prototype an accessible generative interface.", "推荐：设计一个无障碍生成式界面原型。")
        } else {
            return store.t("Suggested: explore one selected signal through a short question path.", "推荐：通过短问题路径探索一个已选信号。")
        }
    }
}
