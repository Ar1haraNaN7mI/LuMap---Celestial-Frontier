import SwiftData
import SwiftUI

struct MobileProgressView: View {
    var onResumeLearning: () -> Void = {}
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \LearningGoal.updatedAt, order: .reverse) private var goals: [LearningGoal]
    @Query(sort: \ActivityRecord.completedAt, order: .reverse) private var activities: [ActivityRecord]
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var assessments: [AssessmentRecord]
    @State private var actionError: String?

    private let personaStyles: [MobilePersonaStyle] = [
        .init(name: "Aurora", colors: [MobileTheme.accent, MobileTheme.cyan]),
        .init(name: "Solar", colors: [MobileTheme.gold, MobileTheme.coral]),
        .init(name: "Forest", colors: [MobileTheme.mint, MobileTheme.cyan]),
        .init(name: "Midnight", colors: [.indigo, .purple])
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(MobileTheme.gradient)
                        .frame(width: 58, height: 58)
                        .overlay {
                            Text(String((store.profile?.displayName ?? "Learner").prefix(1)).uppercased())
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.profile?.displayName ?? store.t("Learner", "学习者"))
                            .font(.title2.bold())
                        Text(store.t("Your projects, progress and learning feedback", "你的项目、进度与学习反馈"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metric(value: "\(goals.count)", label: store.t("Paths", "路径"), color: MobileTheme.accent)
                    metric(value: "\(activities.count)", label: store.t("Activities", "活动"), color: MobileTheme.cyan)
                    metric(value: "\(store.rewardBalance)", label: "Lumens", color: MobileTheme.gold)
                    metric(value: store.hasUnlimitedAICredits ? "∞" : "\(store.aiCreditBalance)", label: store.t("AI credits", "AI 额度"), color: MobileTheme.mint)
                }

                learningWallet
                personaAppearance

                if store.currentGoal != nil {
                    NavigationLink {
                        MobileAssessmentView()
                    } label: {
                        HStack(spacing: 12) {
                            MobileIconTile(systemImage: "checkmark.bubble.fill", color: MobileTheme.mint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.t("Check your understanding", "检测你的理解")).font(.headline)
                                Text(store.t("Optional theory and practical checks for your current path", "针对当前路径的可选理论与实践检测"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .mobileCard()
                }

                if goals.isEmpty {
                    ContentUnavailableView(
                        store.t("No learning evidence yet", "还没有学习证据"),
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(store.t("Complete an activity and your progress will appear here.", "完成一项活动后，进度会显示在这里。"))
                    )
                    .frame(maxWidth: .infinity)
                    .mobileCard()
                } else {
                    Text(store.t("Started projects", "已开始的项目"))
                        .font(.title2.bold())
                    ForEach(goals) { goal in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(goal.originalInput)
                                    .font(.headline)
                                    .lineLimit(2)
                                Spacer()
                                Text("\(Int(goal.progress * 100))%")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                            }
                            ProgressView(value: goal.progress)
                                .tint(goal.status == "completed" ? MobileTheme.mint : MobileTheme.accent)
                            HStack {
                                Text(goal.status.capitalized)
                                Spacer()
                                Text(goal.status == "completed"
                                     ? store.t("Evidence saved", "证据已保存")
                                     : store.t("Current section \(goal.currentStep)", "当前第 \(goal.currentStep) 节"))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if goal.status == "completed" {
                                Label(store.t("Path completed · review your evidence below", "路径已完成 · 下方可回顾学习证据"), systemImage: "checkmark.seal.fill")
                                    .font(.caption).foregroundStyle(MobileTheme.mint)
                            } else {
                                Button(store.t("Resume learning", "继续学习"), systemImage: "play.fill") {
                                    do {
                                        try store.resumeGoal(goal)
                                        onResumeLearning()
                                    }
                                    catch { actionError = error.localizedDescription }
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(minHeight: 44)
                            }
                        }
                        .mobileCard()
                    }

                    if !activities.isEmpty {
                        Text(store.t("Recent evidence", "最近证据"))
                            .font(.title2.bold())
                            .padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(activities.prefix(8).enumerated()), id: \.element.id) { index, activity in
                                HStack(spacing: 12) {
                                    MobileIconTile(
                                        systemImage: LearningMethod(rawValue: activity.methodID)?.icon ?? "checkmark.circle.fill",
                                        color: MobileTheme.mint
                                    )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(activity.title).font(.headline)
                                        Text(activity.completedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                if index < min(activities.count, 8) - 1 { Divider() }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(MobileTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

                if !assessments.isEmpty {
                    Text(store.t("Learning feedback", "学习反馈"))
                        .font(.title2.bold())
                        .padding(.top, 4)
                    ForEach(assessments.prefix(3)) { assessment in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Label(
                                    assessment.kind == AssessmentKind.practical.rawValue
                                        ? store.t("Practical check", "实践检测")
                                        : store.t("Theory check", "理论检测"),
                                    systemImage: assessment.kind == AssessmentKind.practical.rawValue ? "wrench.and.screwdriver" : "text.bubble.fill"
                                )
                                .font(.headline)
                                Spacer()
                                if let score = assessment.score {
                                    Text("\(score) / \(assessment.evidenceSummary.contains("AI rubric") ? 100 : 6)")
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(MobileTheme.mint)
                                }
                            }
                            Text(assessment.feedback)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(assessment.evidenceSummary)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .mobileCard()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Personal", "个人"))
        .alert(store.t("Couldn't complete that action", "无法完成操作"), isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private var learningWallet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MobileIconTile(systemImage: "cpu", color: MobileTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.t("AI learning credits", "AI 学习额度"))
                        .font(.headline)
                    Text(store.hasUnlimitedAICredits
                         ? store.t(
                            "Hackathon demo access is unlimited. Metered accounts retain a balance for future model calls.",
                            "Hackathon 演示账号已启用无限额度；普通账号会保留用于模型调用的余额。"
                         )
                         : store.t(
                            "Exchange Lumens earned from learning for model-powered study allowance.",
                            "把学习获得的光点兑换为大模型学习额度。"
                         ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if store.hasUnlimitedAICredits {
                Label(store.t("Unlimited access active", "无限额度已启用"), systemImage: "infinity.circle.fill")
                    .font(.headline)
                    .foregroundStyle(MobileTheme.mint)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityLabel(store.t("Demo account, unlimited AI learning credits", "演示账号，无限 AI 学习额度"))
            } else {
                Button(store.t("Exchange 20 Lumens · Get 100 credits", "兑换 20 光点 · 获得 100 额度")) {
                    do {
                        try store.redeemLearningCredits(credits: 100, cost: 20)
                        actionError = nil
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(store.rewardBalance < 20)
            }
        }
        .mobileCard(prominent: true)
    }

    private var personaAppearance: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.t("Persona appearance", "桌面伙伴外观"))
                    .font(.headline)
                Text(store.t("Every style is included and costs 0 Lumens.", "所有外观均已解锁，消耗 0 光点。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(personaStyles) { style in
                    let isSelected = store.profile?.personaStyle == style.name
                    Button {
                        do {
                            try store.redeemPersonaStyle(style.name, cost: 0)
                            actionError = nil
                        } catch {
                            actionError = error.localizedDescription
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                            Text(style.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? MobileTheme.accent : Color.secondary)
                        }
                        .padding(10)
                        .background(MobileTheme.raisedCard, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelected)
                    .accessibilityLabel(
                        isSelected
                            ? store.t("\(style.name), selected", "\(style.name)，已选择")
                            : store.t("Use \(style.name), free", "免费使用 \(style.name)")
                    )
                }
            }
        }
        .mobileCard()
    }

    private func metric(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mobileCard()
    }
}

private struct MobilePersonaStyle: Identifiable {
    let name: String
    let colors: [Color]
    var id: String { name }
}
