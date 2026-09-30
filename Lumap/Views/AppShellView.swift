import SwiftData
import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var bannerTask: Task<Void, Never>?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { LumapBackdrop() }
                .overlay(alignment: .top) {
                    if let message = store.bannerMessage {
                        banner(message)
                            .padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .background(MainWindowBridge(store: store).frame(width: 0, height: 0))
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.locale, store.language.locale)
        .modifier(LumapTextScaleModifier(isLarge: store.profile?.largeText == true))
        .transaction { transaction in
            if store.profile?.reducedMotion == true {
                transaction.disablesAnimations = true
            }
        }
        .overlay {
            if let bootstrapError = store.bootstrapError {
                ZStack {
                    LumapTheme.canvas.opacity(0.97)
                    ContentUnavailableView {
                        Label(store.t("Local data needs attention", "本地数据需要处理"), systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(bootstrapError)
                    } actions: {
                        Button(store.t("Retry local database", "重试本地数据库")) {
                            store.configure(context: modelContext)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: 520)
                }
            }
        }
        .task {
            store.configure(context: modelContext)
        }
        .onReceive(ticker) { _ in
            store.tickPersona()
        }
        .onChange(of: store.bannerMessage) { _, value in
            bannerTask?.cancel()
            guard value != nil else { return }
            guard !voiceOverEnabled else { return }
            bannerTask = Task {
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                withAnimation { store.bannerMessage = nil }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LumapTheme.pathGradient)
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lumap")
                        .font(.headline)
                    Text(store.t("Your adaptive learning map", "你的自适应学习地图"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            List(selection: $store.selectedSection) {
                Section(store.t("Learn", "学习")) {
                    navigationRow(.home)
                    navigationRow(.studio)
                    navigationRow(.groundedStudy)
                    navigationRow(.futureLab)
                    navigationRow(.assessment)
                }
                Section(store.t("Your space", "你的空间")) {
                    navigationRow(.profile)
                    navigationRow(.library)
                }
                Section(store.t("Companion", "学习伙伴")) {
                    navigationRow(.persona)
                }
                Section {
                    navigationRow(.settings)
                }
            }
            .listStyle(.sidebar)

            HStack(spacing: 9) {
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(store.personaMode == .learning ? LumapTheme.mint : .secondary)
                    Text(store.personaMode == .learning ? store.t("Learning mode", "学习模式") : store.t("Local mode", "本地模式"))
                        .font(.caption.weight(.medium))
                }
                Spacer()
                Label("\(store.rewardBalance)", systemImage: "sparkle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LumapTheme.gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Divider() }
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 232, max: 260)
    }

    private func navigationRow(_ section: AppSection) -> some View {
        Label(LumapLocalization.sectionName(section, language: store.language), systemImage: section.icon)
            .tag(section)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private var detail: some View {
        switch store.selectedSection {
        case .home: HomeView()
        case .studio: LearningStudioView()
        case .groundedStudy: GroundedStudyView()
        case .futureLab: FutureLabView()
        case .assessment: AssessmentHubView()
        case .library: LibraryView()
        case .profile: PersonalHubView()
        case .progress: ProgressViewScreen()
        case .rewards: RewardsView()
        case .persona: PersonaView()
        case .settings: SettingsView()
        }
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LumapTheme.mint)
            Text(text)
                .font(.subheadline.weight(.semibold))
            Button {
                withAnimation { store.bannerMessage = nil }
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.t("Dismiss notification", "关闭通知"))
            .help(store.t("Dismiss", "关闭"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}

private struct LumapTextScaleModifier: ViewModifier {
    let isLarge: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isLarge {
            content.dynamicTypeSize(.xLarge)
        } else {
            content
        }
    }
}
