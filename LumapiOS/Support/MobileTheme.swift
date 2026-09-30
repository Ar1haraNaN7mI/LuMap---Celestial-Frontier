import SwiftUI
import UIKit

enum MobileTheme {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.66, green: 0.61, blue: 1.0, alpha: 1)
            : UIColor(red: 0.35, green: 0.28, blue: 0.84, alpha: 1)
    })
    static let cyan = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.84, blue: 0.96, alpha: 1)
            : UIColor(red: 0.03, green: 0.49, blue: 0.61, alpha: 1)
    })
    static let mint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.84, blue: 0.68, alpha: 1)
            : UIColor(red: 0.08, green: 0.46, blue: 0.34, alpha: 1)
    })
    static let coral = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.55, blue: 0.58, alpha: 1)
            : UIColor(red: 0.72, green: 0.19, blue: 0.23, alpha: 1)
    })
    static let gold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.83, blue: 0.48, alpha: 1)
            : UIColor(red: 0.49, green: 0.34, blue: 0.0, alpha: 1)
    })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let raisedCard = Color(uiColor: .tertiarySystemGroupedBackground)
    static let border = Color(uiColor: .separator)
    static let gradient = LinearGradient(
        colors: [accent, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func color(named name: String) -> Color {
        switch name {
        case "cyan": cyan
        case "mint": mint
        case "coral": coral
        case "gold": gold
        default: accent
        }
    }
}

struct MobileCardModifier: ViewModifier {
    var prominent = false

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(prominent ? AnyShapeStyle(MobileTheme.gradient.opacity(0.14)) : AnyShapeStyle(MobileTheme.card))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MobileTheme.border.opacity(prominent ? 0.7 : 0.45), lineWidth: 0.5)
            }
    }
}

extension View {
    func mobileCard(prominent: Bool = false) -> some View {
        modifier(MobileCardModifier(prominent: prominent))
    }
}

struct MobileIconTile: View {
    let systemImage: String
    var color: Color = MobileTheme.accent

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}
