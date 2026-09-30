import SwiftUI

struct FutureLabView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var selection: FutureLabScenario = .knowledgeStudio

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 850 {
                HStack(spacing: 0) {
                    scenarioRail
                        .frame(width: 248)
                    Divider()
                    scenarioPage
                }
            } else {
                VStack(spacing: 0) {
                    compactPicker
                    Divider()
                    scenarioPage
                }
            }
        }
        .navigationTitle(store.t("Future Lab", "未来实验室"))
    }

    private var scenarioRail: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.t("FUTURE LAB", "未来实验室"))
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(LumapTheme.accent)
                Text(store.t("Make learning your own", "让学习属于你"))
                    .font(.title2.weight(.semibold))
                Text(store.t("Live learning workspaces and a spatial concept preview.", "真实学习工作空间与空间交互概念预览。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(FutureLabScenario.allCases) { scenario in
                    Button {
                        selection = scenario
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: scenario.icon)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(selection == scenario ? .white : LumapTheme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scenario.title(language: store.language))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selection == scenario ? .white : .primary)
                                Text(scenario == .spatialVision ? store.t("Interactive AR concept preview", "可交互 AR 概念预览") : store.t("Your sources, progress and model", "真实资料、进度与模型"))
                                    .font(.caption2)
                                    .foregroundStyle(selection == scenario ? Color.white.opacity(0.82) : LumapTheme.secondaryInk)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selection == scenario ? AnyShapeStyle(LumapTheme.pathGradient) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("future-lab-\(scenario.rawValue)")
                }
            }

            Spacer()
            Label(store.t("Your configured model · Local progress", "已配置模型 · 本地学习进度"), systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(LumapTheme.surface.opacity(0.62))
    }

    private var compactPicker: some View {
        Picker(store.t("Future Lab scene", "未来实验室场景"), selection: $selection) {
            ForEach(FutureLabScenario.allCases) { scenario in
                Label(scenario.title(language: store.language), systemImage: scenario.icon)
                    .tag(scenario)
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scenarioPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if selection == .spatialVision {
                    FutureLabBoundaryBanner()
                    SpatialVisionConceptView()
                } else {
                    LearningWorkspaceView(scenario: selection)
                }
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background { LumapBackdrop() }
        .id(selection)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selection == .spatialVision { FutureLabPrototypeFooter() }
        }
    }
}

private struct FutureLabBoundaryBanner: View {
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "wand.and.sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(LumapTheme.accent)
                .frame(width: 38, height: 38)
                .background(LumapTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 7) {
                ConceptBadge(text: "CONCEPT DEMO", tint: LumapTheme.gold)
                Text(store.t(
                    "Every control responds using local sample data. Nothing here calls a model, camera, social profile or another device.",
                    "所有控件都使用本地样例数据反馈。本页不会调用模型、相机、社交主页或其他设备。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(LumapTheme.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: LumapTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LumapTheme.cardRadius, style: .continuous)
                .stroke(LumapTheme.accent.opacity(0.20), lineWidth: 0.75)
        }
    }
}

private struct FutureLabPrototypeFooter: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(LumapTheme.gold)
            Text("Interactive front-end prototype · Synthetic data · No live service")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LumapTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

private struct ConceptBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .tracking(0.45)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct ConceptSceneHeader: View {
    @EnvironmentObject private var store: LumapStore
    let scenario: FutureLabScenario
    let status: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            LumapIconTile(icon: scenario.icon, tint: LumapTheme.accent, size: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(scenario.title(language: store.language))
                    .font(.system(size: 30, weight: .semibold))
                Text(scenario.subtitle(language: store.language))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LumapTheme.mint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(LumapTheme.mint.opacity(0.10), in: Capsule())
        }
    }
}

private struct KnowledgeStudioConceptView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var selectedSources: Set<Int> = [0, 1]
    @State private var answerVersion = 0
    @State private var revealedCitation: Int? = 0

    private let sources = [
        ("Lecture 04.pdf", "pp. 8–9", "Albedo changes how much incoming energy a surface reflects."),
        ("Lab notebook.md", "lines 41–56", "The ice sample crossed the melt threshold after the lamp moved closer."),
        ("Climate dataset.csv", "rows 18–32", "Observed reflectance fell as dark surface area increased.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ConceptSceneHeader(scenario: .knowledgeStudio, status: store.t("2 sources active", "2 个资料已启用"))

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { sourcePanel; answerPanel }
                VStack(spacing: 16) { sourcePanel; answerPanel }
            }
        }
    }

    private var sourcePanel: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(store.t("Ground this answer in", "限定回答资料"), systemImage: "tray.full.fill")
                    .font(.headline)
                ForEach(sources.indices, id: \.self) { index in
                    Button {
                        if selectedSources.contains(index) { selectedSources.remove(index) }
                        else { selectedSources.insert(index) }
                        revealedCitation = nil
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedSources.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedSources.contains(index) ? LumapTheme.mint : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sources[index].0).font(.subheadline.weight(.semibold))
                                Text(sources[index].1).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("knowledge-source-\(index)")
                }
                Text(store.t("Selection changes the sample synthesis and its citations.", "选择会改变样例综合内容与引用。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
    }

    private var answerPanel: some View {
        LumapCard(style: .featured) {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.t("Why can melting ice accelerate further warming?", "为什么融冰会进一步加速变暖？"))
                    .font(.title3.weight(.semibold))
                Text(synthesis)
                    .font(.body)
                    .lineSpacing(3)
                HStack(spacing: 8) {
                    ForEach(selectedSources.sorted(), id: \.self) { index in
                        Button("[\(index + 1)] \(sources[index].1)") {
                            revealedCitation = index
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("knowledge-citation-\(index)")
                    }
                }
                if let revealedCitation {
                    Label(sources[revealedCitation].2, systemImage: "quote.opening")
                        .font(.callout)
                        .foregroundStyle(LumapTheme.cyan)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LumapTheme.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("knowledge-citation-detail")
                }
                HStack {
                    Button {
                        answerVersion += 1
                        revealedCitation = nil
                    } label: {
                        Label(store.t("Ask a follow-up", "继续追问"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSources.isEmpty)
                    .accessibilityIdentifier("knowledge-follow-up")
                    Spacer()
                    Button(store.t("Reset", "重置")) {
                        selectedSources = [0, 1]
                        answerVersion = 0
                        revealedCitation = 0
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Label(store.t("Local synthesis #\(answerVersion + 1)", "本地综合 #\(answerVersion + 1)"), systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var synthesis: String {
        guard !selectedSources.isEmpty else {
            return store.t("Select at least one source to form a grounded answer.", "请至少选择一个资料以形成有来源的回答。")
        }
        if selectedSources.contains(0), selectedSources.contains(1) {
            return store.t(
                "Bright ice reflects energy. When it melts, a darker surface absorbs more energy; the lab observation shows the threshold effect. This creates a reinforcing feedback loop [1][2].",
                "明亮的冰面会反射能量。融化后，较暗的表面吸收更多能量；实验记录展示了阈值效应。这会形成增强反馈回路 [1][2]。"
            )
        }
        return store.t(
            "The selected evidence links lower reflectance with greater absorbed energy. Add another source to compare mechanism and observation.",
            "所选证据把反射率下降与能量吸收增加联系起来。再加入一个资料，即可比较机制与观察结果。"
        )
    }
}

private struct SpatialVisionConceptView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var energy = 0.54
    @State private var placed = true
    @State private var layer = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ConceptSceneHeader(scenario: .spatialVision, status: placed ? store.t("Object anchored", "对象已锚定") : store.t("Preview ready", "预览就绪"))
            LumapCard(padding: 0, style: .featured) {
                ZStack {
                    LinearGradient(colors: [LumapTheme.cyan.opacity(0.18), LumapTheme.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Canvas { context, size in
                        let spacing: CGFloat = 42
                        for x in stride(from: 0 as CGFloat, through: size.width, by: spacing) {
                            var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(line, with: .color(LumapTheme.cyan.opacity(0.10)), lineWidth: 0.6)
                        }
                        for y in stride(from: 0 as CGFloat, through: size.height, by: spacing) {
                            var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(line, with: .color(LumapTheme.cyan.opacity(0.10)), lineWidth: 0.6)
                        }
                    }
                    VStack(spacing: 10) {
                        ZStack {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .stroke(index == layer ? LumapTheme.accent : LumapTheme.cyan.opacity(0.38), lineWidth: index == layer ? 3 : 1.5)
                                    .frame(width: CGFloat(88 + index * 48), height: CGFloat(88 + index * 48))
                            }
                            Circle()
                                .fill(RadialGradient(colors: [LumapTheme.gold, LumapTheme.coral], center: .center, startRadius: 2, endRadius: 42))
                                .frame(width: 76, height: 76)
                                .shadow(color: LumapTheme.gold.opacity(0.45), radius: 24)
                            Circle()
                                .fill(LumapTheme.mint)
                                .frame(width: 24, height: 24)
                                .offset(x: CGFloat(58 + layer * 24), y: -16)
                        }
                        Text(store.t("Energy transfer model", "能量传递模型"))
                            .font(.headline)
                        Text(store.t("Layer \(layer + 1) · intensity \(Int(energy * 100))%", "第 \(layer + 1) 层 · 强度 \(Int(energy * 100))%"))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .scaleEffect(placed ? 1 : 0.82)
                    .opacity(placed ? 1 : 0.62)
                    VStack {
                        HStack {
                            ConceptBadge(text: "AR + GLASSES SIMULATION", tint: LumapTheme.gold)
                            Spacer()
                            Label(store.t("CAMERA OFF", "相机关闭"), systemImage: "camera.slash.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(LumapTheme.coral)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .frame(minHeight: 330)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { spatialControls; spatialStatus }
                VStack(spacing: 14) { spatialControls; spatialStatus }
            }
        }
    }

    private var spatialControls: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("Manipulate the model", "操作模型"))
                    .font(.headline)
                Picker(store.t("Layer", "层级"), selection: $layer) {
                    Text("1").tag(0); Text("2").tag(1); Text("3").tag(2)
                }
                .pickerStyle(.segmented)
                Slider(value: $energy, in: 0.1...1) {
                    Text(store.t("Energy", "能量"))
                }
                Button {
                    placed.toggle()
                } label: {
                    Label(placed ? store.t("Remove anchor", "移除锚点") : store.t("Place on desk", "放置到桌面"), systemImage: placed ? "xmark.circle" : "viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("spatial-place-object")
                Button(store.t("Reset concept", "重置概念演示")) {
                    energy = 0.54
                    layer = 1
                    placed = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var spatialStatus: some View {
        LumapCard(style: .quiet) {
            VStack(alignment: .leading, spacing: 10) {
                Label(placed ? store.t("Anchor A1 is stable", "锚点 A1 已稳定") : store.t("Choose a surface to continue", "选择表面以继续"), systemImage: placed ? "checkmark.circle.fill" : "scope")
                    .font(.headline)
                    .foregroundStyle(placed ? LumapTheme.mint : LumapTheme.accent)
                Text(store.t(
                    "This viewport demonstrates placement and manipulation only. It does not open the camera or detect a real room.",
                    "此视窗只演示放置与操作效果，不会打开相机或识别真实房间。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AdaptivePathConceptView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var evidence = 0.42
    @State private var intent = 0
    @State private var policyStep = 0

    private var weights: [Double] {
        let boost = Double(policyStep % 3) * 0.06
        switch intent {
        case 1: return [0.22, min(0.78, 0.54 + boost), 0.24]
        case 2: return [0.18, 0.28, min(0.82, 0.62 + boost)]
        default: return [min(0.76, 0.50 + boost), 0.31, 0.19]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ConceptSceneHeader(scenario: .adaptivePath, status: store.t("Policy snapshot \(policyStep + 1)", "策略快照 \(policyStep + 1)"))
            LumapCard(style: .featured) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(store.t("Next-step policy", "下一步策略"))
                            .font(.title3.weight(.semibold))
                        Spacer()
                        ConceptBadge(text: "SIMULATED RL", tint: LumapTheme.accent)
                    }
                    HStack(spacing: 9) {
                        pathNode(store.t("Concept", "概念"), icon: "book.closed.fill", active: intent == 0)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        pathNode(store.t("Practice", "练习"), icon: "hammer.fill", active: intent == 1)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        pathNode(store.t("Transfer", "迁移"), icon: "arrow.up.right.square.fill", active: intent == 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { policyControls; policyBars }
                VStack(spacing: 16) { policyControls; policyBars }
            }
        }
    }

    private var policyControls: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 13) {
                Text(store.t("Provide learner evidence", "提供学习者证据"))
                    .font(.headline)
                Picker(store.t("Learning intent", "学习意图"), selection: $intent) {
                    Text(store.t("Explore", "探索")).tag(0)
                    Text(store.t("Practise", "练习")).tag(1)
                    Text(store.t("Prove", "验证")).tag(2)
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(store.t("Observed confidence", "观察到的信心"))
                        Spacer()
                        Text(evidence, format: .percent.precision(.fractionLength(0))).monospacedDigit()
                    }
                    Slider(value: $evidence, in: 0...1)
                        .accessibilityIdentifier("adaptive-confidence")
                }
                Button {
                    policyStep += 1
                    intent = evidence > 0.72 ? 2 : (evidence > 0.38 ? 1 : 0)
                } label: {
                    Label(store.t("Run local policy step", "运行本地策略步骤"), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("adaptive-run-policy")
                Button(store.t("Reset policy", "重置策略")) {
                    evidence = 0.42
                    intent = 0
                    policyStep = 0
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var policyBars: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t("Action probabilities", "行动概率"))
                    .font(.headline)
                probabilityBar(store.t("Explain", "讲解"), value: weights[0], tint: LumapTheme.accent)
                probabilityBar(store.t("Simulate", "模拟"), value: weights[1], tint: LumapTheme.cyan)
                probabilityBar(store.t("Challenge", "挑战"), value: weights[2], tint: LumapTheme.mint)
                Label(store.t("Recommendation changed from local demo evidence.", "推荐已根据本地演示证据改变。"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pathNode(_ title: String, icon: String, active: Bool) -> some View {
        VStack(spacing: 7) {
            Image(systemName: active ? "checkmark.circle.fill" : icon)
                .font(.title2)
                .foregroundStyle(active ? LumapTheme.mint : LumapTheme.secondaryInk)
            Text(title).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(active ? LumapTheme.mint.opacity(0.10) : LumapTheme.mutedSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func probabilityBar(_ title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title).font(.caption.weight(.semibold)); Spacer(); Text(value, format: .percent).font(.caption.monospacedDigit()) }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.10))
                    Capsule().fill(tint).frame(width: max(4, proxy.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct LearningHandoffConceptView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var selectedDevice = 0
    @State private var handoffCount = 0
    @State private var checkpoint = 0.63

    private let devices = [
        ("iPhone", "iphone", "Pocket quiz"),
        ("Mac", "macbook", "Deep work"),
        ("Spatial", "vision.pro", "Object lab")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ConceptSceneHeader(scenario: .learningHandoff, status: store.t("Local relay", "本地接力"))
            LumapCard(style: .featured) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.t("Climate feedback loops", "气候反馈回路"))
                                .font(.title2.weight(.semibold))
                            Text(store.t("Checkpoint: explain the ice-albedo loop", "检查点：解释冰反照率回路"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(checkpoint, format: .percent.precision(.fractionLength(0)))
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(LumapTheme.accent)
                    }
                    ProgressView(value: checkpoint).tint(LumapTheme.accent)
                    HStack(spacing: 10) {
                        ForEach(devices.indices, id: \.self) { index in
                            Button {
                                selectedDevice = index
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: devices[index].1)
                                        .font(.title2)
                                    Text(devices[index].0).font(.headline)
                                    Text(devices[index].2).font(.caption).foregroundStyle(selectedDevice == index ? Color.white.opacity(0.82) : .secondary)
                                }
                                .foregroundStyle(selectedDevice == index ? .white : .primary)
                                .frame(maxWidth: .infinity, minHeight: 112)
                                .background(selectedDevice == index ? AnyShapeStyle(LumapTheme.pathGradient) : AnyShapeStyle(LumapTheme.mutedSurface.opacity(0.55)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("handoff-device-\(index)")
                        }
                    }
                }
            }

            LumapCard {
                HStack(alignment: .center, spacing: 14) {
                    LumapIconTile(icon: devices[selectedDevice].1, tint: LumapTheme.cyan)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.t("Continue on \(devices[selectedDevice].0)", "在 \(devices[selectedDevice].0) 上继续"))
                            .font(.headline)
                        Text(store.t("A sample checkpoint, note and preferred method will move together.", "样例检查点、笔记和偏好学习方式将一起转移。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        handoffCount += 1
                        checkpoint = min(0.95, checkpoint + 0.04)
                    } label: {
                        Label(store.t("Simulate handoff", "模拟接力"), systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("handoff-simulate")
                    Button(store.t("Reset", "重置")) {
                        selectedDevice = 0
                        handoffCount = 0
                        checkpoint = 0.63
                    }
                    .buttonStyle(.bordered)
                }
                if handoffCount > 0 {
                    Divider().padding(.vertical, 8)
                    Label(store.t("Handoff #\(handoffCount) complete — demo state restored on \(devices[selectedDevice].0).", "接力 #\(handoffCount) 完成——演示状态已在 \(devices[selectedDevice].0) 恢复。"), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(LumapTheme.mint)
                        .accessibilityIdentifier("handoff-success")
                }
            }
        }
    }
}

private struct InterestConstellationConceptView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var activeSignals: Set<Int> = [0, 1, 3]
    @State private var threshold = 0.46
    @State private var revision = 0

    private let signals = [
        ("Astronomy videos", "play.rectangle.fill", "Space"),
        ("Design bookmarks", "bookmark.fill", "Design"),
        ("Music practice", "music.note", "Audio"),
        ("Climate searches", "magnifyingglass", "Climate"),
        ("Coding projects", "chevron.left.forwardslash.chevron.right", "Code")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ConceptSceneHeader(scenario: .interestConstellation, status: store.t("Synthetic profile", "合成画像"))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { signalControls; constellation }
                VStack(spacing: 16) { signalControls; constellation }
            }
        }
    }

    private var signalControls: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(store.t("Choose demo signals", "选择演示信号"), systemImage: "hand.tap.fill")
                    .font(.headline)
                ForEach(signals.indices, id: \.self) { index in
                    Toggle(isOn: Binding(
                        get: { activeSignals.contains(index) },
                        set: { value in
                            if value { activeSignals.insert(index) } else { activeSignals.remove(index) }
                        }
                    )) {
                        Label(signals[index].0, systemImage: signals[index].1)
                    }
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("interest-signal-\(index)")
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(store.t("Minimum relevance", "最低相关度"))
                        Spacer()
                        Text(threshold, format: .percent).monospacedDigit()
                    }
                    .font(.caption)
                    Slider(value: $threshold, in: 0.2...0.8)
                }
                Button {
                    revision += 1
                } label: {
                    Label(store.t("Rebuild local map", "重建本地星图"), systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("interest-rebuild")
                Button(store.t("Reset signals", "重置信号")) {
                    activeSignals = [0, 1, 3]
                    threshold = 0.46
                    revision = 0
                }
                .buttonStyle(.bordered)
                Text(store.t("All names and activity signals are invented for this demo.", "所有名称和活动信号均为此演示虚构。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 330)
    }

    private var constellation: some View {
        LumapCard(style: .featured) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.t("Your possible learning orbit", "你可能的学习轨道"))
                        .font(.headline)
                    Spacer()
                    Text("MAP \(revision + 1)")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.secondary)
                }
                ZStack {
                    Circle().stroke(LumapTheme.accent.opacity(0.18), lineWidth: 1).frame(width: 250, height: 250)
                    Circle().stroke(LumapTheme.cyan.opacity(0.18), lineWidth: 1).frame(width: 170, height: 170)
                    Circle().fill(LumapTheme.pathGradient).frame(width: 68, height: 68)
                        .overlay { Text("YOU").font(.caption.weight(.bold)).foregroundStyle(.white) }
                    ForEach(Array(activeSignals.sorted().enumerated()), id: \.element) { order, index in
                        let angle = Double(order) / Double(max(activeSignals.count, 1)) * Double.pi * 2 - Double.pi / 2
                        let radius = 92.0 + Double(index % 2) * 24.0
                        VStack(spacing: 3) {
                            Image(systemName: signals[index].1)
                                .font(.headline)
                            Text(signals[index].2).font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(index % 2 == 0 ? LumapTheme.cyan : LumapTheme.mint)
                        .frame(width: 68, height: 52)
                        .background(LumapTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .offset(x: CGFloat(cos(angle) * radius), y: CGFloat(sin(angle) * radius))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 290)
                Label(recommendation, systemImage: "lightbulb.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(LumapTheme.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .background(LumapTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("interest-recommendation")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recommendation: String {
        if activeSignals.contains(0), activeSignals.contains(3) {
            return store.t("Suggested spark: model planetary climate feedback with a visual simulation.", "推荐灵感：用视觉模拟建立行星气候反馈模型。")
        }
        if activeSignals.contains(1), activeSignals.contains(4) {
            return store.t("Suggested spark: build an accessible generative interface prototype.", "推荐灵感：构建一个无障碍生成式界面原型。")
        }
        return store.t("Suggested spark: explore one selected signal through a short question path.", "推荐灵感：通过短问题路径探索一个已选信号。")
    }
}
