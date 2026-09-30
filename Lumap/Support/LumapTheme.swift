import AppKit
import SwiftUI

enum LumapTheme {
    // System colors adapt to light, dark and increased-contrast appearances.
    // Indigo marks the current learning action; teal marks verified evidence.
    static let ink = Color(nsColor: .labelColor)
    static let secondaryInk = Color(nsColor: .secondaryLabelColor)
    static let tertiaryInk = Color(nsColor: .tertiaryLabelColor)
    static let accent = adaptive(light: 0x5947D7, dark: 0xA89CFF)
    static let cyan = adaptive(light: 0x087D9C, dark: 0x6BD7F5)
    static let mint = adaptive(light: 0x147557, dark: 0x65D6AE)
    static let coral = adaptive(light: 0xB8303B, dark: 0xFF8D94)
    static let gold = adaptive(light: 0x7C5700, dark: 0xFFD37A)

    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor)
    static let mutedSurface = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    static let card = surface
    static let strongCard = mutedSurface
    static let border = Color(nsColor: .separatorColor)
    static let strongBorder = Color.primary.opacity(0.16)

    static let pagePadding: CGFloat = 32
    static let compactPagePadding: CGFloat = 20
    static let contentWidth: CGFloat = 1180
    static let cardRadius: CGFloat = 14
    static let compactRadius: CGFloat = 10

    static let pathGradient = LinearGradient(
        colors: [accent, Color(nsColor: .systemPurple), cyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return nsColor(hex: match == .darkAqua ? dark : light)
        })
    }

    private static func nsColor(hex: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum LumapCardStyle {
    case standard
    case featured
    case quiet
}

struct LumapBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            LumapTheme.canvas
            if !reduceTransparency {
                GeometryReader { proxy in
                    Circle()
                        .fill(LumapTheme.accent.opacity(0.07))
                        .frame(width: min(proxy.size.width * 0.60, 700))
                        .blur(radius: 100)
                        .offset(x: proxy.size.width * 0.58, y: -250)

                    Circle()
                        .fill(LumapTheme.cyan.opacity(0.045))
                        .frame(width: min(proxy.size.width * 0.44, 520))
                        .blur(radius: 110)
                        .offset(x: -190, y: proxy.size.height * 0.66)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

struct LumapCard<Content: View>: View {
    let padding: CGFloat
    let style: LumapCardStyle
    @ViewBuilder var content: Content

    init(
        padding: CGFloat = 18,
        style: LumapCardStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(background, in: RoundedRectangle(cornerRadius: LumapTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LumapTheme.cardRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .featured ? 1.25 : 0.75)
            }
            .shadow(
                color: style == .featured ? LumapTheme.accent.opacity(0.08) : .clear,
                radius: style == .featured ? 18 : 0,
                y: style == .featured ? 8 : 0
            )
    }

    private var background: AnyShapeStyle {
        switch style {
        case .standard:
            AnyShapeStyle(LumapTheme.surface)
        case .featured:
            AnyShapeStyle(
                LinearGradient(
                    colors: [LumapTheme.elevatedSurface, LumapTheme.accent.opacity(0.055)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .quiet:
            AnyShapeStyle(LumapTheme.mutedSurface.opacity(0.72))
        }
    }

    private var borderColor: Color {
        style == .featured ? LumapTheme.accent.opacity(0.28) : LumapTheme.border
    }
}

struct PrototypeBadge: View {
    var label = "PROTOTYPE"

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .tracking(0.55)
            .foregroundStyle(LumapTheme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(LumapTheme.accent.opacity(0.10), in: Capsule())
            .overlay { Capsule().stroke(LumapTheme.accent.opacity(0.16), lineWidth: 0.75) }
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(LumapTheme.accent)
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(LumapTheme.ink)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(LumapTheme.secondaryInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MetricPill: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = LumapTheme.accent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.headline).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(LumapTheme.secondaryInk)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(LumapTheme.surface, in: Capsule())
        .overlay { Capsule().stroke(LumapTheme.border, lineWidth: 0.75) }
    }
}

struct LumapIconTile: View {
    let icon: String
    var tint: Color = LumapTheme.accent
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.38, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 0.75)
            }
    }
}

extension Color {
    static func lumap(named name: String) -> Color {
        switch name {
        case "cyan": LumapTheme.cyan
        case "mint": LumapTheme.mint
        case "coral": LumapTheme.coral
        case "gold": LumapTheme.gold
        default: LumapTheme.accent
        }
    }
}
