import SwiftUI

/// The journey is another entrance to the existing course, not a new learning
/// workflow. Callers decide whether a selected section opens work or its archive.
struct LearningJourneyChainView: View {
    let snapshot: LearningJourneySnapshot
    let isChinese: Bool
    var reducedMotion = false
    /// A fixed phase for native screenshots / video frames. Nil animates normally.
    var animationTime: TimeInterval? = nil
    /// Native ImageRenderer cannot draw an AppKit-backed ScrollView. A non-nil
    /// value renders the identical content through a clipped, read-only viewport.
    var snapshotScrollOffset: CGFloat? = nil
    let onSelectSection: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase
    @State private var animationStart = Date.now

    private var palette: JourneyPalette { JourneyPalette(dark: colorScheme == .dark) }
    private var motionIsPaused: Bool {
        reducedMotion || systemReduceMotion || animationTime != nil || scenePhase != .active
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 760
            Group {
                if let animationTime {
                    // ImageRenderer captures the exact native scene without a
                    // live TimelineView or any dependency on wall-clock time.
                    scrollContent(compact: compact, width: geometry.size.width,
                                  time: reducedMotion || systemReduceMotion ? 0 : animationTime)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: motionIsPaused)) { timeline in
                        let time = (reducedMotion || systemReduceMotion) ? 0 : timeline.date.timeIntervalSince(animationStart)
                        scrollContent(compact: compact, width: geometry.size.width, time: time)
                    }
                }
            }
            .background(palette.stage)
        }
        .accessibilityIdentifier("learning-journey-chain")
    }

    private func scrollContent(compact: Bool, width: CGFloat, time: TimeInterval) -> some View {
        Group {
            if let snapshotScrollOffset {
                journeyContent(compact: compact, width: width, time: time)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -max(0, snapshotScrollOffset))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
            } else {
                ScrollView {
                    journeyContent(compact: compact, width: width, time: time)
                }
                .scrollIndicators(.visible)
            }
        }
    }

    private func journeyContent(compact: Bool, width: CGFloat, time: TimeInterval) -> some View {
        VStack(spacing: 0) {
            heading(compact: compact)
                .padding(.top, compact ? 28 : 36)
                .padding(.bottom, compact ? 20 : 30)
            if snapshot.sections.isEmpty {
                ContentUnavailableView(
                    isChinese ? "你的探索即将开始" : "Your exploration starts here",
                    systemImage: "sparkle",
                    description: Text(isChinese ? "课程准备完成后，第一站会出现在光束上。" : "Your first stop appears when your course is ready.")
                )
                .foregroundStyle(palette.primary)
                .padding(.vertical, 70)
            } else {
                chain(compact: compact, width: min(width, 1120), time: time)
                    .frame(maxWidth: 1120)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func heading(compact: Bool) -> some View {
        VStack(spacing: 10) {
            Label(isChinese ? "你的探索光轨" : "YOUR LEARNING JOURNEY", systemImage: "sparkle")
                .font(.caption.weight(.semibold))
                .tracking(isChinese ? 1 : 2.2)
                .foregroundStyle(palette.gold)
            Text(snapshot.title)
                .font(compact ? .title2.weight(.semibold) : .largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(snapshot.isComplete
                 ? (isChinese ? "每一次探索，都留下一束光。" : "Every discovery leaves a little light.")
                 : (isChinese ? "跟随好奇心，一次探索一站。" : "Follow your curiosity. One discovery at a time."))
                .font(.body)
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, compact ? 24 : 44)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func chain(compact: Bool, width: CGFloat, time: TimeInterval) -> some View {
        VStack(spacing: compact ? 72 : 58) {
            // The origin sits close to the viewer; each new stop reaches further
            // along the light. Reversing visible nodes never exposes future ones.
            ForEach(Array(snapshot.sections.reversed())) { section in
                let rightSide = section.ordinal.isMultiple(of: 2)
                HStack(spacing: 0) {
                    if !compact && rightSide { Spacer(minLength: 0) }
                    JourneySectionCard(section: section, isChinese: isChinese, palette: palette,
                                       increasedContrast: contrast == .increased,
                                       isInteractive: snapshotScrollOffset == nil,
                                       onSelect: { onSelectSection(section.id) })
                        .frame(maxWidth: compact ? 560 : min(390, width * 0.42))
                        .anchorPreference(key: JourneyCardAnchors.self, value: .bounds) {
                            [.section(section.id): $0]
                        }
                        .rotationEffect(.degrees(sway(time, ordinal: section.ordinal) * 0.24), anchor: .top)
                        .offset(y: sway(time, ordinal: section.ordinal) * 1.6)
                    if !compact && !rightSide { Spacer(minLength: 0) }
                }
                .padding(.horizontal, compact ? 24 : 44)
                .id(section.id)
            }
            VStack(spacing: 8) {
                Circle().fill(palette.gold).frame(width: 8, height: 8)
                    .shadow(color: palette.gold.opacity(0.65), radius: 8)
                    .anchorPreference(key: JourneyCardAnchors.self, value: .bounds) { [.origin: $0] }
                    .accessibilityHidden(true)
                Text(isChinese ? "好奇心是起点" : "It began with curiosity")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
            }
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 68)
        .padding(.bottom, 50)
        .backgroundPreferenceValue(JourneyCardAnchors.self) { anchors in
            GeometryReader { geometry in
                JourneyBeam(anchors: anchors.mapValues { geometry[$0] }, compact: compact,
                            time: time, palette: palette, increasedContrast: contrast == .increased)
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    private func sway(_ time: TimeInterval, ordinal: Int) -> Double {
        if systemReduceMotion || reducedMotion { return 0 }
        return sin(time * 0.34 + Double(ordinal) * 1.7)
    }
}

private struct JourneyPalette {
    let dark: Bool
    var stage: Color { dark ? Color(red: 12/255, green: 13/255, blue: 20/255) : Color(red: 245/255, green: 243/255, blue: 236/255) }
    var card: Color { dark ? Color(red: 23/255, green: 26/255, blue: 36/255) : .white }
    var primary: Color { dark ? Color(red: 244/255, green: 245/255, blue: 249/255) : Color(red: 28/255, green: 31/255, blue: 40/255) }
    var secondary: Color { dark ? Color(red: 179/255, green: 183/255, blue: 199/255) : Color(red: 89/255, green: 95/255, blue: 110/255) }
    var gold: Color { dark ? Color(red: 237/255, green: 198/255, blue: 118/255) : Color(red: 121/255, green: 84/255, blue: 7/255) }
    var beam: Color { dark ? Color(red: 237/255, green: 198/255, blue: 118/255) : Color(red: 189/255, green: 134/255, blue: 53/255) }
    var core: Color { dark ? Color(red: 255/255, green: 242/255, blue: 206/255) : Color(red: 255/255, green: 237/255, blue: 186/255) }
}

private enum JourneyAnchorID: Hashable {
    case section(String)
    case origin
}

private struct JourneyCardAnchors: PreferenceKey {
    static var defaultValue: [JourneyAnchorID: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [JourneyAnchorID: Anchor<CGRect>], nextValue: () -> [JourneyAnchorID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct JourneySectionCard: View {
    let section: LearningJourneySnapshot.Section
    let isChinese: Bool
    let palette: JourneyPalette
    let increasedContrast: Bool
    let isInteractive: Bool
    let onSelect: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var methodSize: CGFloat = 14

    var body: some View {
        Group {
            if isInteractive {
                cardButton.focused($focused)
            } else {
                // ImageRenderer has no focus tree. Constructing a focus binding
                // in that context emits a SwiftUI runtime issue in XCTest.
                cardButton
            }
        }
    }

    private var cardButton: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Text(String(format: "%02d", section.ordinal))
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(palette.gold)
                        .padding(9)
                        .background(palette.gold.opacity(palette.dark ? 0.10 : 0.08), in: RoundedRectangle(cornerRadius: 9))
                    Label(section.isExplored ? (isChinese ? "已探索" : "EXPLORED") : (isChinese ? "正在探索" : "YOUR CURRENT STOP"),
                          systemImage: section.isExplored ? "checkmark.seal.fill" : "sparkle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.gold)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: section.isExplored ? "arrow.up.right" : "arrow.right")
                        .foregroundStyle(palette.gold)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(palette.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(section.objective)
                        .font(.system(size: bodySize))
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(section.methods) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Image(systemName: item.method.icon)
                                .frame(width: 19)
                                .foregroundStyle(palette.gold)
                            Text(LumapLocalization.methodName(item.method, language: isChinese ? .simplifiedChinese : .english))
                                .font(.system(size: methodSize))
                                .foregroundStyle(palette.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if item.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(palette.gold)
                                    .accessibilityLabel(isChinese ? "已完成" : "Completed")
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.stage.opacity(palette.dark ? 0.62 : 0.72), in: RoundedRectangle(cornerRadius: 13))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { metadata; Spacer(minLength: 0); actionLabel }
                    VStack(alignment: .leading, spacing: 10) { metadata; actionLabel }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .background(palette.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(palette.gold.opacity((isInteractive && focused) || hovering || increasedContrast ? 0.88 : section.isExplored ? 0.25 : 0.58),
                            lineWidth: isInteractive && focused ? 2.5 : increasedContrast ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(palette.dark ? 0.24 : 0.06), radius: 24, y: 12)
            .shadow(color: palette.beam.opacity(section.isExplored ? 0.025 : 0.08), radius: 22)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityHint(section.isExplored
                           ? (isChinese ? "查看已保存的学习记录" : "Opens your saved learning evidence")
                           : (isChinese ? "进入当前课程" : "Opens your current lesson"))
        .accessibilityIdentifier("journey-section-\(section.id)")
    }

    private var metadata: some View {
        Group {
            if section.isExplored {
                Label(isChinese ? "\(section.savedEvidence.count) 份学习记录" : "\(section.savedEvidence.count) saved learning checks",
                      systemImage: "bookmark")
            } else {
                Label(isChinese ? "约 \(section.estimatedMinutes) 分钟" : "About \(section.estimatedMinutes) min", systemImage: "clock")
            }
        }
        .font(.caption)
        .foregroundStyle(palette.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actionLabel: some View {
        Text(section.isExplored ? (isChinese ? "回顾探索" : "Revisit discovery") : (isChinese ? "继续探索" : "Continue learning"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.gold)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct JourneyBeam: View {
    let anchors: [JourneyAnchorID: CGRect]
    let compact: Bool
    let time: TimeInterval
    let palette: JourneyPalette
    let increasedContrast: Bool

    var body: some View {
        Canvas { context, size in
            let beamSize = CGSize(width: size.width, height: anchors[.origin]?.midY ?? size.height)
            let points = (0...160).map { index in point(CGFloat(index) / 160, size: beamSize) }
            let spine = Path { path in
                path.move(to: points[0])
                for item in points.dropFirst() { path.addLine(to: item) }
            }
            // An opaque card layer keeps text entirely outside the glow surface.
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: increasedContrast ? 5 : 10))
                glow.stroke(spine, with: .color(palette.beam.opacity(palette.dark ? 0.34 : 0.22)), lineWidth: 20)
            }
            // Rounded segments avoid subpixel tessellation seams in a very thin
            // filled ribbon while preserving the near-to-far taper.
            for index in 1..<points.count {
                let segment = Path { path in
                    path.move(to: points[index - 1])
                    path.addLine(to: points[index])
                }
                context.stroke(segment, with: .linearGradient(
                    Gradient(colors: [palette.beam.opacity(0.25), palette.beam, palette.core]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width / 2, y: beamSize.height)),
                    style: StrokeStyle(lineWidth: 1.1 + 8 * CGFloat(index) / CGFloat(points.count - 1),
                                       lineCap: .round, lineJoin: .round))
            }
            context.stroke(spine, with: .color(palette.core.opacity(palette.dark ? 0.95 : 0.80)),
                           style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))

            for (anchorID, bounds) in anchors where anchorID != .origin {
                let anchorY = compact ? bounds.minY - 20 : bounds.minY + 34
                let t = min(1, max(0, anchorY / max(beamSize.height, 1)))
                let junction = point(t, size: beamSize)
                let target = compact ? CGPoint(x: bounds.midX, y: bounds.minY)
                    : CGPoint(x: bounds.midX < size.width / 2 ? bounds.maxX : bounds.minX, y: bounds.minY + 34)
                let connector = Path { path in
                    path.move(to: junction)
                    path.addQuadCurve(to: target, control: CGPoint(x: target.x, y: junction.y))
                }
                context.stroke(connector, with: .color(palette.beam.opacity(increasedContrast ? 0.9 : 0.6)),
                               style: StrokeStyle(lineWidth: 1, lineCap: .round))
                let halo = CGRect(x: junction.x - 7, y: junction.y - 7, width: 14, height: 14)
                context.fill(Path(ellipseIn: halo), with: .color(palette.beam.opacity(0.12)))
                context.fill(Path(ellipseIn: CGRect(x: junction.x - 2.5, y: junction.y - 2.5, width: 5, height: 5)),
                             with: .color(palette.core))
            }

            // Sparse, slow moving glints make the beam feel alive, without flashes.
            for index in 0..<7 {
                let progress = (Double(index) / 7 + time * 0.012).truncatingRemainder(dividingBy: 1)
                let location = point(CGFloat(progress), size: beamSize)
                let radius = 1.2 + progress * 0.9
                context.fill(Path(ellipseIn: CGRect(x: location.x - radius, y: location.y - radius,
                                                    width: radius * 2, height: radius * 2)),
                             with: .color(palette.core.opacity(0.68)))
            }
        }
    }

    private func point(_ fraction: CGFloat, size: CGSize) -> CGPoint {
        let y = fraction * size.height
        let wave = sin(y / 180 + time * 0.18)
        let returnToOrigin = fraction > 0.84 ? pow((1 - fraction) / 0.16, 0.8) : 1
        let amplitude = min(size.width * 0.09, 90) * (0.2 + 0.8 * fraction) * returnToOrigin
        return CGPoint(x: size.width / 2 + wave * amplitude, y: y)
    }

}
