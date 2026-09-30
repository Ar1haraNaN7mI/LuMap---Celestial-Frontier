import SwiftUI

struct PersonaView: View {
    @EnvironmentObject private var store: LumapStore
    @State private var minutes = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    SectionHeader(
                        eyebrow: store.t("DESKTOP COMPANION", "桌面学习伙伴"),
                        title: store.t("Meet Lumi", "认识 Lumi"),
                        subtitle: store.t("Lumi appears when the main window is minimised, stays out of your keyboard focus and only uses the scopes you explicitly enable.", "主窗口最小化后，Lumi 会出现，并且不会抢走键盘焦点。它只使用你明确开启的观察范围。")
                    )
                    Spacer()
                    PrototypeBadge(label: "NO EXTERNAL SENSING")
                }

                HStack(alignment: .top, spacing: 24) {
                    personaPreview
                    modeControls
                }

                HStack(alignment: .top, spacing: 18) {
                    capabilityCard(icon: "app.dashed", title: store.t("App activity", "应用活动"), detail: store.t("Not enabled in this build", "当前版本未启用"))
                    capabilityCard(icon: "display", title: store.t("Screen context", "屏幕内容"), detail: store.t("Not enabled in this build", "当前版本未启用"))
                    capabilityCard(icon: "camera", title: store.t("Camera", "摄像头"), detail: store.t("Never requested", "从未请求"))
                }

                LumapCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(store.t("Active interaction preview", "主动互动预览")).font(.headline)
                            Spacer()
                            Text(store.personaMode.rawValue.uppercased()).font(.caption.bold()).foregroundStyle(LumapTheme.accent)
                        }
                        Text(store.personaPrompt)
                            .font(.title3.weight(.medium))
                        HStack {
                            Button(store.t("Show another interaction", "换一个互动")) { store.nextPersonaNudge() }
                                .buttonStyle(.bordered)
                            Button(store.t("Show floating Persona", "显示悬浮桌宠")) {
                                PersonaPanelController.shared.show(store: store, reason: "preview")
                            }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .padding(LumapTheme.pagePadding)
            .frame(maxWidth: 1060, alignment: .leading)
        }
    }

    private var personaPreview: some View {
        LumapCard(padding: 28) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: personaColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: LumapTheme.accent.opacity(0.25), radius: 28, y: 12)
                    Image(systemName: "sparkles")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 150, height: 150)
                VStack(spacing: 4) {
                    Text("Lumi").font(.title.bold())
                    Text(store.profile?.personaStyle ?? "Aurora").font(.caption).foregroundStyle(.secondary)
                }
                Button(store.t("Minimise-window preview", "最小化窗口预览")) {
                    PersonaPanelController.shared.minimizeMainWindow(store: store)
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 260)
        }
    }

    private var modeControls: some View {
        LumapCard(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.t("Limited learning mode", "限时学习模式")).font(.title2.bold())
                Text(store.t("The timer and pause/stop state are real. External observation remains disabled for the Hackathon build.", "计时、暂停和停止状态是真实功能。Hackathon 版本不会启用外部观察。"))
                    .foregroundStyle(.secondary)
                Stepper(store.t("Duration: \(minutes) minutes", "时长：\(minutes) 分钟"), value: $minutes, in: 1...60)
                    .disabled(store.personaMode == .learning || store.personaMode == .paused)

                if store.personaMode == .learning || store.personaMode == .paused {
                    HStack(alignment: .firstTextBaseline) {
                        Text(timeText).font(.system(size: 42, weight: .bold, design: .monospaced))
                        Text(store.personaMode == .paused ? store.t("PAUSED", "已暂停") : store.t("REMAINING", "剩余"))
                            .font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(store.personaSecondsRemaining), total: Double(store.personaSessionDuration))
                        .tint(LumapTheme.accent)
                    HStack {
                        Button(store.personaMode == .paused ? store.t("Resume", "继续") : store.t("Pause", "暂停")) {
                            store.personaMode == .paused ? store.resumeLearningMode() : store.pauseLearningMode()
                        }
                        .buttonStyle(.bordered)
                        Button(store.t("Stop", "停止"), role: .destructive) { store.stopLearningMode() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    Button(store.t("Start learning mode", "开启学习模式")) {
                        store.startLearningMode(minutes: minutes)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Divider()
                Label(store.t("First intervention is quiet; demo interactions are manually triggerable.", "首次提醒保持安静；演示互动可手动触发。"), systemImage: "moon.zzz.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if store.personaMode == .learning || store.personaMode == .paused {
                minutes = store.personaSessionMinutes
            }
        }
    }

    private var timeText: String {
        String(format: "%02d:%02d", store.personaSecondsRemaining / 60, store.personaSecondsRemaining % 60)
    }

    private var personaColors: [Color] {
        switch store.profile?.personaStyle {
        case "Solar": [LumapTheme.gold, LumapTheme.coral]
        case "Forest": [LumapTheme.mint, LumapTheme.cyan]
        case "Midnight": [.indigo, .purple]
        default: [LumapTheme.accent, LumapTheme.cyan]
        }
    }

    private func capabilityCard(icon: String, title: String, detail: String) -> some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Label(store.t("Off", "关闭"), systemImage: "lock.fill")
                    .font(.caption.bold()).foregroundStyle(LumapTheme.mint)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
