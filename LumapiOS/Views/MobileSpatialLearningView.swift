import SwiftUI

struct MobileSpatialLearningView: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var provider = MobileARKitProvider()
    @State private var selectedStep = 1
    @State private var prediction = ""
    @State private var observation = ""
    @State private var adjustment = ""
    @State private var modelValue = 0.45
    @State private var resultMessage: String?
    @State private var previewNotes: String?
    @State private var errorMessage: String?
    @State private var anchorCount = 2
    @State private var selectedAnchor = 0
    @State private var scanProgress = 0.08
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                introduction
                spatialPreview
                availabilityCard
                learningLoop
                evidenceCard

                Text(store.t(
                    "This demo checks ARKit support and renders an interactive 2D spatial fallback. It does not start a camera session or capture the environment.",
                    "此演示会检测 ARKit 支持并渲染可交互的二维空间预览，但不会启动摄像头会话，也不会采集周围环境。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Spatial Practice", "空间实践"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await provider.prepare() }
        .onAppear(perform: startMotion)
        .onChange(of: reduceMotion) { _, _ in startMotion() }
        .onChange(of: modelValue) { _, _ in
            if selectedStep < 2 { selectedStep = 2 }
        }
    }

    private var introduction: some View {
        HStack(alignment: .top, spacing: 12) {
            MobileIconTile(systemImage: "arkit", color: MobileTheme.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.scenario.title)
                    .font(.title2.bold())
                Text(store.t("A recordable spatial learning prototype", "可直接录制演示的空间学习原型"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("2D FALLBACK")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(MobileTheme.cyan)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(MobileTheme.cyan.opacity(0.12), in: Capsule())
        }
    }

    private var spatialPreview: some View {
        VStack(spacing: 0) {
            MobileSpatialViewport(
                value: modelValue,
                anchorCount: anchorCount,
                selectedAnchor: $selectedAnchor,
                scanProgress: scanProgress,
                pulse: pulse
            )
            .frame(height: 338)

            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        placementButtons
                        Spacer(minLength: 8)
                        anchorPicker
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        placementButtons
                        anchorPicker
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    Image(systemName: "thermometer.variable.and.figure")
                        .font(.title3)
                        .foregroundStyle(heatColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("Heat retention", "热量保留"))
                            .font(.subheadline.weight(.semibold))
                        Text(store.t("Move the control and watch the field react", "拖动参数，观察空间场如何变化"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(modelValue, format: .percent.precision(.fractionLength(0)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(heatColor)
                }

                Slider(value: $modelValue, in: 0...1)
                    .tint(heatColor)
                    .accessibilityLabel(store.t("Heat retention", "热量保留"))
                    .accessibilityValue(Text(modelValue, format: .percent))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: observationIcon)
                        .foregroundStyle(heatColor)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.t("Live observation", "实时观察"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(liveObservation)
                            .font(.subheadline.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 6)
                    Button(store.t("Use", "采用")) {
                        observation = liveObservation
                        selectedStep = max(selectedStep, 3)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(store.t("Use the live observation as evidence", "将实时观察作为证据"))
                }
                .padding(12)
                .background(heatColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
            .background(MobileTheme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MobileTheme.cyan.opacity(0.28), lineWidth: 0.75)
        }
        .shadow(color: MobileTheme.cyan.opacity(0.12), radius: 20, y: 10)
    }

    private var placementButtons: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(motionAnimation) {
                    if anchorCount < 4 {
                        anchorCount += 1
                        selectedAnchor = anchorCount - 1
                    }
                    selectedStep = max(selectedStep, 2)
                }
            } label: {
                Label(store.t("Place anchor", "放置锚点"), systemImage: "plus.viewfinder")
                    .frame(minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .disabled(anchorCount == 4)

            Button {
                withAnimation(motionAnimation) {
                    anchorCount = 1
                    selectedAnchor = 0
                    modelValue = 0.45
                    selectedStep = 1
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(store.t("Reset spatial scene", "重置空间场景"))
        }
    }

    private var anchorPicker: some View {
        HStack(spacing: 6) {
            ForEach(0..<anchorCount, id: \.self) { index in
                Button {
                    withAnimation(motionAnimation) { selectedAnchor = index }
                } label: {
                    Text("A\(index + 1)")
                        .font(.caption.weight(.bold).monospaced())
                        .frame(minWidth: 30, minHeight: 30)
                }
                .buttonStyle(.bordered)
                .tint(index == selectedAnchor ? MobileTheme.cyan : .secondary)
                .accessibilityLabel(store.t("Select anchor \(index + 1)", "选择锚点 \(index + 1)"))
                .accessibilityAddTraits(index == selectedAnchor ? .isSelected : [])
            }
        }
    }

    private var availabilityCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: availabilityIcon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(availabilityColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(availabilityText)
                    .font(.subheadline.weight(.semibold))
                Text(store.t("The visual scene remains fully interactive on Simulator and devices without a spatial session.", "在模拟器和未开启空间会话的设备上，视觉场景仍可完整交互。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .mobileCard()
    }

    private var learningLoop: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.t("Spatial learning loop", "空间学习循环"))
                    .font(.headline)
                Spacer()
                Text("\(min(selectedStep + 1, spatialSteps.count))/\(spatialSteps.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(MobileTheme.cyan)
            }

            ForEach(Array(spatialSteps.enumerated()), id: \.offset) { index, step in
                Button {
                    withAnimation(motionAnimation) { selectedStep = index }
                } label: {
                    MobileSpatialStepRow(
                        index: index,
                        title: step.title,
                        detail: step.detail,
                        state: stepState(for: index)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .mobileCard()
    }

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Reflect on the preview", "回顾这次预览"))
                .font(.headline)
            Text(store.t("These notes belong to this preview only. They do not create assessment scores, learning progress or Lumens. Share a copy to keep them.", "这些笔记仅保留在本次预览中，不会产生检测分数、学习进度或光点。你可以分享副本以保存。"))
                .font(.caption).foregroundStyle(.secondary)
            evidenceField(store.t("Prediction", "预测"), text: $prediction)
            evidenceField(store.t("Observation", "观察"), text: $observation)
            evidenceField(store.t("Adjustment", "调整"), text: $adjustment)

            Button {
                submitEvidence()
            } label: {
                Label(store.t("Capture preview notes", "记录预览笔记"), systemImage: "note.text")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled([prediction, observation, adjustment].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

            if let previewNotes {
                ShareLink(item: previewNotes) {
                    Label(store.t("Share preview notes", "分享预览笔记"), systemImage: "square.and.arrow.up")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }

            if let resultMessage {
                Label(resultMessage, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(MobileTheme.mint)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MobileTheme.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(MobileTheme.coral)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MobileTheme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .mobileCard(prominent: true)
    }

    private var spatialSteps: [(title: String, detail: String)] {
        [
            (store.t("Scan the surface", "扫描平面"), store.t("A stable floor plane has been simulated.", "已模拟识别到稳定地面。")),
            (store.t("Place an anchor", "放置锚点"), store.t("Choose where the learning model should live.", "选择学习模型在空间中的位置。")),
            (store.t("Adjust one variable", "调整一个变量"), store.t("Change retention and compare the heat field.", "调整保留率并比较热力场变化。")),
            (store.t("Explain the evidence", "解释证据"), store.t("Connect the observed pattern to your prediction.", "将观察到的模式与预测联系起来。"))
        ]
    }

    private var liveObservation: String {
        if modelValue > 0.66 {
            return store.t(
                "At \(Int(modelValue * 100))%, heat concentrates around anchor A\(selectedAnchor + 1) and escapes slowly.",
                "保留率为 \(Int(modelValue * 100))% 时，热量聚集在锚点 A\(selectedAnchor + 1) 周围并缓慢逸散。"
            )
        }
        if modelValue > 0.33 {
            return store.t(
                "At \(Int(modelValue * 100))%, input and loss form a visibly stable loop around A\(selectedAnchor + 1).",
                "保留率为 \(Int(modelValue * 100))% 时，输入与损耗在 A\(selectedAnchor + 1) 周围形成可见的稳定循环。"
            )
        }
        return store.t(
            "At \(Int(modelValue * 100))%, the field disperses quickly across the simulated surface.",
            "保留率为 \(Int(modelValue * 100))% 时，热力场迅速向模拟表面扩散。"
        )
    }

    private var observationIcon: String {
        modelValue > 0.66 ? "flame.fill" : modelValue > 0.33 ? "waveform.path.ecg" : "wind"
    }

    private var heatColor: Color {
        modelValue > 0.66 ? MobileTheme.coral : modelValue > 0.33 ? MobileTheme.gold : MobileTheme.cyan
    }

    private var availabilityText: String {
        switch provider.availability {
        case .checking: store.t("Checking spatial capabilities…", "正在检测空间能力……")
        case .previewOnly: store.t("Interactive fallback ready · camera remains off", "交互预览已就绪 · 摄像头保持关闭")
        case .ready: store.t("ARKit supported · using the safe demo renderer", "设备支持 ARKit · 当前使用安全演示渲染器")
        case .unavailable: store.t("Spatial session unavailable · fallback remains ready", "空间会话不可用 · 仍可使用交互预览")
        }
    }

    private var availabilityIcon: String {
        switch provider.availability {
        case .checking: "hourglass"
        case .previewOnly: "rectangle.on.rectangle"
        case .ready: "arkit"
        case .unavailable: "exclamationmark.triangle"
        }
    }

    private var availabilityColor: Color {
        switch provider.availability {
        case .checking, .previewOnly: MobileTheme.cyan
        case .ready: MobileTheme.mint
        case .unavailable: MobileTheme.coral
        }
    }

    private var motionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy
    }

    private func stepState(for index: Int) -> MobileSpatialStepRow.State {
        if index < selectedStep { return .complete }
        if index == selectedStep { return .current }
        return .upcoming
    }

    private func evidenceField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(title, text: text, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(MobileTheme.raisedCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
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

    private func submitEvidence() {
        guard ![prediction, observation, adjustment].contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return }
        previewNotes = """
        Lumap · AR concept preview notes (not assessed)
        Simulated value: \(Int(modelValue * 100))%
        Prediction: \(prediction)
        Observation: \(observation)
        Adjustment: \(adjustment)
        """
        resultMessage = store.t("Preview notes captured for this session. Share them to keep a copy; no score was recorded.", "已记录本次预览笔记。分享副本即可保存；未记录检测分数。")
        errorMessage = nil
        selectedStep = spatialSteps.count
    }
}

private struct MobileSpatialViewport: View {
    @EnvironmentObject private var store: LumapStore
    let value: Double
    let anchorCount: Int
    @Binding var selectedAnchor: Int
    let scanProgress: Double
    let pulse: Bool

    private let positions: [CGPoint] = [
        CGPoint(x: 0.28, y: 0.48),
        CGPoint(x: 0.64, y: 0.38),
        CGPoint(x: 0.78, y: 0.62),
        CGPoint(x: 0.42, y: 0.68)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let selectedPosition = positions[min(selectedAnchor, positions.count - 1)]
            let objectPoint = CGPoint(x: size.width * selectedPosition.x, y: size.height * selectedPosition.y)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.05, blue: 0.10), Color(red: 0.02, green: 0.13, blue: 0.17), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [heatColor.opacity(0.38 + value * 0.18), .clear],
                    center: UnitPoint(x: selectedPosition.x, y: selectedPosition.y),
                    startRadius: 4,
                    endRadius: 150 + CGFloat(value) * 70
                )

                MobileSpatialPerspectiveGrid()

                MobileViewfinderCorners()
                    .stroke(.white.opacity(0.42), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .padding(16)

                ForEach(0..<anchorCount, id: \.self) { index in
                    let position = positions[index]
                    Button {
                        selectedAnchor = index
                    } label: {
                        MobileSpatialAnchorMarker(index: index, selected: selectedAnchor == index)
                    }
                    .buttonStyle(.plain)
                    .position(x: size.width * position.x, y: size.height * position.y)
                    .accessibilityLabel(store.t("Anchor \(index + 1)", "锚点 \(index + 1)"))
                    .accessibilityAddTraits(selectedAnchor == index ? .isSelected : [])
                }

                MobileSpatialObject(value: value, pulse: pulse)
                    .frame(width: 150 + CGFloat(value) * 28, height: 150 + CGFloat(value) * 28)
                    .position(objectPoint)
                    .allowsHitTesting(false)

                MobileSpatialParticles(value: value, pulse: pulse)
                    .frame(width: 230, height: 170)
                    .position(objectPoint)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, MobileTheme.cyan.opacity(0.68), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                    .shadow(color: MobileTheme.cyan.opacity(0.9), radius: 5)
                    .position(x: size.width / 2, y: max(24, size.height * scanProgress))
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack(spacing: 7) {
                        Label(store.t("SURFACE FOUND", "已识别平面"), systemImage: "viewfinder.circle.fill")
                        Spacer()
                        Label(store.t("CAMERA OFF", "摄像头关闭"), systemImage: "camera.slash.fill")
                    }
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(MobileTheme.cyan)

                    Spacer()

                    HStack {
                        Label("0.82 m", systemImage: "ruler")
                        Spacer()
                        Text(store.t("\(anchorCount) ANCHORS · A\(selectedAnchor + 1) ACTIVE", "\(anchorCount) 个锚点 · A\(selectedAnchor + 1) 已选"))
                    }
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
                .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.t("Interactive spatial heat model", "可交互空间热力模型"))
        .accessibilityValue(Text(value, format: .percent))
    }

    private var heatColor: Color {
        value > 0.66 ? MobileTheme.coral : value > 0.33 ? MobileTheme.gold : MobileTheme.cyan
    }
}

private struct MobileSpatialPerspectiveGrid: View {
    var body: some View {
        Canvas { context, size in
            let horizon = size.height * 0.30
            let vanishingPoint = CGPoint(x: size.width * 0.52, y: horizon)
            var rays = Path()
            for index in -7...7 {
                rays.move(to: vanishingPoint)
                rays.addLine(to: CGPoint(x: size.width * 0.5 + CGFloat(index) * size.width * 0.13, y: size.height))
            }
            context.stroke(rays, with: .color(MobileTheme.cyan.opacity(0.28)), lineWidth: 0.7)

            var depthLines = Path()
            for index in 0...11 {
                let progress = CGFloat(index) / 11
                let y = horizon + (size.height - horizon) * progress * progress
                depthLines.move(to: CGPoint(x: 0, y: y))
                depthLines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(depthLines, with: .color(MobileTheme.mint.opacity(0.22)), lineWidth: 0.7)

            var horizonLine = Path()
            horizonLine.move(to: CGPoint(x: 0, y: horizon))
            horizonLine.addLine(to: CGPoint(x: size.width, y: horizon))
            context.stroke(horizonLine, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
        }
        .allowsHitTesting(false)
    }
}

private struct MobileViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.11
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

private struct MobileSpatialAnchorMarker: View {
    let index: Int
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.52))
                .frame(width: 44, height: 44)
            Circle()
                .stroke(selected ? Color.white : MobileTheme.cyan.opacity(0.78), style: StrokeStyle(lineWidth: selected ? 2 : 1.2, dash: selected ? [] : [3, 3]))
                .frame(width: selected ? 42 : 34, height: selected ? 42 : 34)
            Image(systemName: selected ? "dot.scope" : "plus")
                .font(.subheadline.weight(.bold))
            Text("A\(index + 1)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .offset(y: 31)
        }
        .foregroundStyle(selected ? .white : MobileTheme.cyan)
        .frame(width: 56, height: 68)
        .contentShape(Rectangle())
    }
}

private struct MobileSpatialObject: View {
    let value: Double
    let pulse: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(heatColor.opacity(0.22))
                .frame(width: 132, height: 52)
                .blur(radius: 7)
                .offset(y: 39)

            MobileWireframeCube()
                .stroke(heatColor.opacity(0.88), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                .frame(width: 104, height: 104)
                .shadow(color: heatColor.opacity(0.8), radius: 7)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), heatColor.opacity(0.9), heatColor.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 48
                    )
                )
                .frame(width: 88, height: 88)
                .scaleEffect(pulse ? 1.06 : 0.94)

            Ellipse()
                .stroke(.white.opacity(0.75), lineWidth: 1.5)
                .frame(width: 105, height: 34)
                .rotationEffect(.degrees(23))
            Ellipse()
                .stroke(MobileTheme.cyan.opacity(0.8), lineWidth: 1.5)
                .frame(width: 98, height: 30)
                .rotationEffect(.degrees(-42))

            VStack(spacing: 1) {
                Text("THERMAL")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.weight(.heavy).monospacedDigit())
            }
            .foregroundStyle(.white)
        }
        .shadow(color: heatColor.opacity(0.72), radius: 18 + CGFloat(value) * 10)
    }

    private var heatColor: Color {
        value > 0.66 ? MobileTheme.coral : value > 0.33 ? MobileTheme.gold : MobileTheme.cyan
    }
}

private struct MobileWireframeCube: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.18
        let shift = CGSize(width: rect.width * 0.16, height: -rect.height * 0.14)
        let front = rect.insetBy(dx: inset, dy: inset)
        let back = front.offsetBy(dx: shift.width, dy: shift.height)
        var path = Path()
        path.addRoundedRect(in: front, cornerSize: CGSize(width: 4, height: 4))
        path.addRoundedRect(in: back, cornerSize: CGSize(width: 4, height: 4))
        for (frontPoint, backPoint) in [
            (CGPoint(x: front.minX, y: front.minY), CGPoint(x: back.minX, y: back.minY)),
            (CGPoint(x: front.maxX, y: front.minY), CGPoint(x: back.maxX, y: back.minY)),
            (CGPoint(x: front.maxX, y: front.maxY), CGPoint(x: back.maxX, y: back.maxY)),
            (CGPoint(x: front.minX, y: front.maxY), CGPoint(x: back.minX, y: back.maxY))
        ] {
            path.move(to: frontPoint)
            path.addLine(to: backPoint)
        }
        return path
    }
}

private struct MobileSpatialParticles: View {
    let value: Double
    let pulse: Bool

    var body: some View {
        GeometryReader { proxy in
            let activeCount = max(5, Int(value * 20))
            ForEach(0..<20, id: \.self) { index in
                if index < activeCount {
                    let angle = Double(index) * 2.399
                    let radius = CGFloat(34 + (index % 7) * 10) * (pulse ? 1.04 : 0.96)
                    Circle()
                        .fill(index.isMultiple(of: 4) ? Color.white : heatColor)
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
        value > 0.66 ? MobileTheme.coral : value > 0.33 ? MobileTheme.gold : MobileTheme.cyan
    }
}

private struct MobileSpatialStepRow: View {
    enum State { case complete, current, upcoming }
    let index: Int
    let title: String
    let detail: String
    let state: State

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(state == .upcoming ? 0.06 : 0.14))
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if state == .current {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            if state == .current {
                Text("NOW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MobileTheme.cyan)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(MobileTheme.cyan.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index + 1), \(title), \(stateText)")
    }

    private var symbol: String {
        switch state {
        case .complete: "checkmark"
        case .current: "circle.inset.filled"
        case .upcoming: "circle"
        }
    }

    private var tint: Color {
        switch state {
        case .complete: MobileTheme.mint
        case .current: MobileTheme.cyan
        case .upcoming: .secondary
        }
    }

    private var stateText: String {
        switch state {
        case .complete: "complete"
        case .current: "current"
        case .upcoming: "upcoming"
        }
    }
}
