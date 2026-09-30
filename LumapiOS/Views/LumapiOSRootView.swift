import SwiftData
import SwiftUI

private enum MobileTab: Hashable {
    case discover
    case learn
    case methods
    case progress
    case settings
}

struct LumapiOSRootView: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var selectedTab: MobileTab = .discover
    @State private var bannerTask: Task<Void, Never>?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MobileDiscoverView()
            }
            .tabItem { Label(store.t("Discover", "探索"), systemImage: "sparkles") }
            .tag(MobileTab.discover)

            NavigationStack {
                MobileStudioView()
            }
            .tabItem { Label(store.t("Learn", "学习"), systemImage: "book.pages.fill") }
            .tag(MobileTab.learn)

            NavigationStack {
                MobileMethodsView()
            }
            .tabItem { Label(store.t("Methods", "方式"), systemImage: "square.grid.2x2.fill") }
            .tag(MobileTab.methods)

            NavigationStack {
                MobileProgressView()
            }
            .tabItem { Label(store.t("Personal", "我的"), systemImage: "person.crop.circle.fill") }
            .tag(MobileTab.progress)

            NavigationStack {
                MobileSettingsView()
            }
            .tabItem { Label(store.t("Settings", "设置"), systemImage: "gearshape.fill") }
            .tag(MobileTab.settings)
        }
        .environment(\.locale, store.language.locale)
        .modifier(MobileTextScaleModifier(usesLargerText: store.profile?.largeText == true))
        .overlay(alignment: .top) {
            if let message = store.bannerMessage {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MobileTheme.mint)
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        store.bannerMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(store.t("Dismiss notification", "关闭通知"))
                }
                .padding(.leading, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            store.configure(context: modelContext)
        }
        .onChange(of: store.selectedSection) { _, section in
            switch section {
            case .home: selectedTab = .discover
            case .studio, .groundedStudy, .futureLab, .assessment, .library: selectedTab = .learn
            case .profile, .progress, .rewards: selectedTab = .progress
            case .settings: selectedTab = .settings
            case .persona: break
            }
        }
        .onChange(of: store.bannerMessage) { _, message in
            bannerTask?.cancel()
            guard message != nil, !voiceOverEnabled else { return }
            bannerTask = Task {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation { store.bannerMessage = nil }
            }
        }
    }
}

private struct MobileTextScaleModifier: ViewModifier {
    let usesLargerText: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if usesLargerText {
            content.dynamicTypeSize(.xLarge)
        } else {
            content
        }
    }
}
