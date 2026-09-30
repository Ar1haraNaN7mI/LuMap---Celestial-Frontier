import SwiftData
import SwiftUI

struct RewardsView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \RewardEntry.createdAt, order: .reverse) private var entries: [RewardEntry]
    @State private var errorMessage: String?

    private let styles: [(String, Int, [Color])] = [
        ("Aurora", 0, [LumapTheme.accent, LumapTheme.cyan]),
        ("Solar", 0, [LumapTheme.gold, LumapTheme.coral]),
        ("Forest", 0, [LumapTheme.mint, LumapTheme.cyan]),
        ("Midnight", 0, [.indigo, .purple])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    SectionHeader(
                        eyebrow: store.t("PROCESS, NOT PRESSURE", "奖励过程，不制造压力"),
                        title: store.t("Your Lumens", "你的光点"),
                        subtitle: store.hasUnlimitedAICredits
                            ? store.t("Every visual style is included. This demo account has unlimited AI learning; Lumens remain available for future real-world rewards.", "所有视觉主题均已解锁。此演示账号拥有无限 AI 学习额度，光点仍可用于未来的实物奖励。")
                            : store.t("Every visual style is included. Lumens can fund AI learning credits and future real-world rewards.", "所有视觉主题均已解锁。光点可用于兑换 AI 学习额度和未来的实物奖励。")
                    )
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(store.rewardBalance)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(LumapTheme.gold)
                        Text("LUMENS").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
                    }
                }

                Text(store.t("Persona styles", "桌面伙伴外观"))
                    .font(.title2.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210))], spacing: 14) {
                    ForEach(styles, id: \.0) { style in
                        styleCard(style)
                    }
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(LumapTheme.coral)
                }

                HStack(alignment: .top, spacing: 18) {
                    LumapCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(store.t("How Lumens work", "光点规则")).font(.headline)
                            rule("10", store.t("Complete a learning method", "完成一个学习活动"))
                            rule("15", store.t("Complete an optional check", "完成一次可选检测"))
                            rule("3", store.t("Reflect or consciously skip", "反思或主动跳过"))
                            Divider()
                            Label(store.t("Event-level duplicate guards are active.", "事件级重复保护已经启用。"), systemImage: "lock.shield.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    LumapCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(store.t("Reward ledger", "奖励账本")).font(.headline)
                            if entries.isEmpty {
                                Text(store.t("No entries yet.", "还没有记录。"))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(entries.prefix(6)) { entry in
                                HStack {
                                    Image(systemName: entry.delta >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                                        .foregroundStyle(entry.delta >= 0 ? LumapTheme.mint : LumapTheme.coral)
                                    Text(entry.reason).font(.caption).lineLimit(1)
                                    Spacer()
                                    Text(entry.delta >= 0 ? "+\(entry.delta)" : "\(entry.delta)")
                                        .font(.caption.bold()).monospacedDigit()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(LumapTheme.pagePadding)
            .frame(maxWidth: 1100, alignment: .leading)
        }
    }

    private func styleCard(_ style: (String, Int, [Color])) -> some View {
        let active = store.profile?.personaStyle == style.0
        return VStack(spacing: 13) {
            ZStack {
                Circle().fill(LinearGradient(colors: style.2, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "sparkles").font(.title.bold()).foregroundStyle(.white)
            }
            .frame(width: 74, height: 74)
            Text(style.0).font(.headline)
            Text(style.1 == 0 ? store.t("Included", "已包含") : "\(style.1) Lumens")
                .font(.caption).foregroundStyle(.secondary)
            if active {
                Button(store.t("Active", "使用中")) {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            } else {
                Button(store.t("Use style", "使用外观")) {
                    do { try store.redeemPersonaStyle(style.0, cost: style.1); errorMessage = nil }
                    catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(active ? LumapTheme.accent.opacity(0.10) : LumapTheme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(active ? LumapTheme.accent : LumapTheme.border, lineWidth: active ? 1.5 : 1) }
    }

    private func rule(_ value: String, _ text: String) -> some View {
        HStack {
            Text("+\(value)").font(.caption.bold()).foregroundStyle(LumapTheme.gold).frame(width: 30, alignment: .trailing)
            Text(text).font(.subheadline)
        }
    }
}
