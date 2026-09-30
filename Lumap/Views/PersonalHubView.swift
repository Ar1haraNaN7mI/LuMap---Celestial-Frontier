import SwiftData
import SwiftUI

struct PersonalHubView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \LearningGoal.updatedAt, order: .reverse) private var goals: [LearningGoal]
    @Query(sort: \ActivityRecord.completedAt, order: .reverse) private var activities: [ActivityRecord]
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var assessments: [AssessmentRecord]
    @Query(sort: \RewardEntry.createdAt, order: .reverse) private var rewardEntries: [RewardEntry]

    @State private var projectScope: ProjectScope = .all
    @State private var errorMessage: String?
    @State private var journeyGoal: LearningGoal?

    private let personaLooks: [PersonaLook] = [
        .init(name: "Aurora", colors: [LumapTheme.accent, LumapTheme.cyan]),
        .init(name: "Solar", colors: [LumapTheme.gold, LumapTheme.coral]),
        .init(name: "Forest", colors: [LumapTheme.mint, LumapTheme.cyan]),
        .init(name: "Midnight", colors: [.indigo, .purple])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                personalHeader
                learningConstellation
                learningProjects
                growthFeedback
                methodFootprint
                recentEvidence
                personaLooksSection
                walletSection
            }
            .padding(LumapTheme.pagePadding)
            .frame(maxWidth: LumapTheme.contentWidth, alignment: .leading)
        }
        .background(Color.clear)
        .sheet(item: $journeyGoal) { goal in
            LearningJourneyPresentation(goal: goal) { store.selectedSection = .studio }
        }
    }

    private var personalHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 24) {
                headerCopy
                Spacer(minLength: 24)
                balanceBadge
            }
            VStack(alignment: .leading, spacing: 16) {
                headerCopy
                balanceBadge
            }
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t("YOUR LEARNING UNIVERSE", "你的学习宇宙"))
                .font(.caption2.weight(.semibold))
                .tracking(1.25)
                .foregroundStyle(LumapTheme.accent)
            Text(store.t("Your curiosity, in motion", "让好奇心持续生长"))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Text(store.t(
                "Projects, evidence and rewards come together here—so the next path can fit you better.",
                "项目、学习证据和奖励都会汇聚在这里，让下一条学习路径更贴合你。"
            ))
            .font(.body)
            .foregroundStyle(LumapTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var balanceBadge: some View {
        HStack(spacing: 12) {
            LumapIconTile(icon: "sparkles", tint: LumapTheme.gold, size: 42)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(store.rewardBalance)")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text(store.t("Lumens available", "可用光点"))
                    .font(.caption)
                    .foregroundStyle(LumapTheme.secondaryInk)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(LumapTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: LumapTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LumapTheme.compactRadius, style: .continuous)
                .stroke(LumapTheme.gold.opacity(0.22), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private var learningConstellation: some View {
        LumapCard(padding: 24, style: .featured) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 30) {
                    currentProjectCopy
                    Spacer(minLength: 16)
                    ConstellationMark(
                        progress: currentGoal?.progress ?? 0,
                        activityCount: currentActivities.count,
                        evidenceCount: currentReviewedAssessments.count,
                        title: store.t("Learning signal", "学习信号"),
                        accessibilityValue: constellationAccessibilityValue
                    )
                    .frame(width: 250, height: 180)
                }
                VStack(alignment: .leading, spacing: 22) {
                    currentProjectCopy
                    ConstellationMark(
                        progress: currentGoal?.progress ?? 0,
                        activityCount: currentActivities.count,
                        evidenceCount: currentReviewedAssessments.count,
                        title: store.t("Learning signal", "学习信号"),
                        accessibilityValue: constellationAccessibilityValue
                    )
                    .frame(maxWidth: .infinity, minHeight: 170)
                }
            }
        }
    }

    private var currentProjectCopy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(store.t("Current path", "当前路径"), systemImage: "point.3.connected.trianglepath.dotted")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LumapTheme.accent)

            if let goal = currentGoal {
                VStack(alignment: .leading, spacing: 7) {
                    Text(goal.originalInput)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .lineLimit(3)
                    Text(store.t(
                        "Step \(goal.currentStep) of \(goal.totalSteps) · \(statusLabel(goal.status))",
                        "第 \(goal.currentStep) / \(goal.totalSteps) 步 · \(statusLabel(goal.status))"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(LumapTheme.secondaryInk)
                }

                ProgressView(value: clampedProgress(goal.progress))
                    .tint(LumapTheme.accent)
                    .frame(maxWidth: 480)

                HStack(spacing: 10) {
                    Button {
                        open(goal)
                    } label: {
                        Label(
                            store.t("View learning chain", "查看学习光链"),
                            systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    if goal.status == "completed" {
                        Label(store.t("Path completed", "路径已完成"), systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LumapTheme.mint)
                    }
                }
            } else {
                Text(store.t("No path is active yet", "还没有正在进行的路径"))
                    .font(.title3.weight(.semibold))
                Text(store.t(
                    "Begin with anything you are curious about. Lumap will turn it into a path you can refine as you learn.",
                    "从任何好奇的问题开始，Lumap 会把它变成一条能随着学习持续调整的路径。"
                ))
                .foregroundStyle(LumapTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                Button(store.t("Find something to learn", "寻找想学的内容")) {
                    store.selectedSection = .home
                }
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(LumapTheme.coral)
            }
        }
        .frame(maxWidth: 610, alignment: .leading)
    }

    private var learningProjects: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                store.t("Learning projects", "学习项目"),
                subtitle: store.t("Started, paused and completed paths stay in one place.", "已开始、已暂停和已完成的路径都保留在这里。")
            )

            Picker(store.t("Project status", "项目状态"), selection: $projectScope) {
                ForEach(ProjectScope.allCases) { scope in
                    Text(scope.label(using: store)).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 540)

            if filteredGoals.isEmpty {
                LumapCard(style: .quiet) {
                    Label(emptyProjectMessage, systemImage: "square.stack.3d.up.slash")
                        .foregroundStyle(LumapTheme.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(filteredGoals) { goal in
                        projectCard(goal)
                    }
                }
            }
        }
    }

    private func projectCard(_ goal: LearningGoal) -> some View {
        let isCurrent = goal.id == store.currentGoal?.id
        return LumapCard(padding: 16, style: isCurrent ? .featured : .standard) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    Image(systemName: statusIcon(goal.status))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(statusColor(goal.status))
                    Text(statusLabel(goal.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(goal.status))
                    if isCurrent {
                        Text(store.t("CURRENT", "当前"))
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(LumapTheme.accent)
                    }
                    Spacer()
                    Text("\(Int(clampedProgress(goal.progress) * 100))%")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }

                Text(goal.originalInput)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ProgressView(value: clampedProgress(goal.progress))
                    .tint(statusColor(goal.status))

                HStack {
                    Label(
                        LumapLocalization.methodName(LearningMethod(rawValue: goal.preferredMethodID) ?? .guidedExplanation, language: store.language),
                        systemImage: (LearningMethod(rawValue: goal.preferredMethodID) ?? .guidedExplanation).icon
                    )
                    .font(.caption)
                    .foregroundStyle(LumapTheme.secondaryInk)
                    .lineLimit(1)
                    Spacer()
                    Button(store.t("View chain", "查看光链")) { journeyGoal = goal }
                        .buttonStyle(.bordered)
                        .tint(LumapTheme.gold)
                        .controlSize(.small)
                }
            }
        }
    }

    private var growthFeedback: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                store.t("Growth signals", "成长反馈"),
                subtitle: store.t("Feedback is calculated from your saved activities and checks.", "反馈仅根据已保存的学习活动和检测结果计算。")
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 14)], spacing: 14) {
                ForEach(growthInsights) { insight in
                    LumapCard(padding: 16, style: .quiet) {
                        VStack(alignment: .leading, spacing: 10) {
                            LumapIconTile(icon: insight.icon, tint: insight.tint, size: 38)
                            Text(insight.title)
                                .font(.headline)
                            Text(insight.body)
                                .font(.caption)
                                .foregroundStyle(LumapTheme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private var methodFootprint: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                store.t("How you have been learning", "你使用过的学习方式"),
                subtitle: store.t("Usage shows what you choose. More evidence is needed before calling a method effective.", "使用次数代表你的选择；判断一种方式是否高效，还需要更多学习证据。")
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 215), spacing: 12)], spacing: 12) {
                ForEach(LearningMethod.allCases) { method in
                    methodRow(method)
                }
            }
        }
    }

    private func methodRow(_ method: LearningMethod) -> some View {
        let count = methodCounts[method, default: 0]
        let preferred = currentGoal?.preferredMethodID == method.rawValue
        return HStack(spacing: 12) {
            LumapIconTile(icon: method.icon, tint: preferred ? LumapTheme.accent : LumapTheme.cyan, size: 36)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(LumapLocalization.methodName(method, language: store.language))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if preferred {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(LumapTheme.accent)
                            .accessibilityLabel(store.t("Preferred", "偏好方式"))
                    }
                }
                ProgressView(value: Double(count), total: Double(max(maximumMethodCount, 1)))
                    .tint(count == 0 ? LumapTheme.border : (preferred ? LumapTheme.accent : LumapTheme.cyan))
            }
            Spacer(minLength: 4)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(count == 0 ? LumapTheme.tertiaryInk : LumapTheme.ink)
        }
        .padding(12)
        .background(LumapTheme.surface.opacity(count == 0 ? 0.54 : 1), in: RoundedRectangle(cornerRadius: LumapTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LumapTheme.compactRadius, style: .continuous)
                .stroke(preferred ? LumapTheme.accent.opacity(0.32) : LumapTheme.border, lineWidth: preferred ? 1.25 : 0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(store.t("\(count) saved activities", "\(count) 个已保存活动"))
    }

    private var recentEvidence: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                store.t("Recent evidence", "最近学习证据"),
                subtitle: store.t("A compact trail of activities and optional checks.", "学习活动与可选检测组成的简洁轨迹。")
            )

            LumapCard {
                if timelineItems.isEmpty {
                    Label(store.t("Your first saved activity will appear here.", "完成第一个学习活动后，记录会显示在这里。"), systemImage: "clock")
                        .foregroundStyle(LumapTheme.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(timelineItems.prefix(8).enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: item.icon)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(item.tint)
                                    .frame(width: 30, height: 30)
                                    .background(item.tint.opacity(0.10), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(LumapTheme.secondaryInk)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 12)
                                Text(item.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(LumapTheme.tertiaryInk)
                            }
                            .padding(.vertical, 11)
                            if index < min(timelineItems.count, 8) - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var personaLooksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                store.t("Persona appearance", "桌面伙伴外观"),
                subtitle: store.t("Every appearance is included. Switching never spends Lumens.", "所有外观均已解锁，切换外观不会消耗光点。")
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                ForEach(personaLooks) { look in
                    personaLookCard(look)
                }
            }
        }
    }

    private func personaLookCard(_ look: PersonaLook) -> some View {
        let isSelected = store.profile?.personaStyle == look.name
        return VStack(alignment: .leading, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: look.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .stroke(.white.opacity(0.42), lineWidth: 1)
                    .frame(width: 42, height: 42)
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(height: 78)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(look.name).font(.headline)
                    Text(store.t("Included", "已解锁"))
                        .font(.caption)
                        .foregroundStyle(LumapTheme.secondaryInk)
                }
                Spacer()
                Button {
                    select(look)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? LumapTheme.accent : LumapTheme.secondaryInk)
                .disabled(isSelected)
                .accessibilityLabel(isSelected ? store.t("Selected", "已选择") : store.t("Use \(look.name)", "使用 \(look.name)"))
            }
        }
        .padding(14)
        .background(LumapTheme.surface, in: RoundedRectangle(cornerRadius: LumapTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LumapTheme.cardRadius, style: .continuous)
                .stroke(isSelected ? LumapTheme.accent.opacity(0.58) : LumapTheme.border, lineWidth: isSelected ? 1.5 : 0.75)
        }
    }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                store.t("Lumens wallet", "光点钱包"),
                subtitle: store.t("Lumens are earned from real learning actions and can fund future learning or rewards.", "光点来自真实学习行为，未来可用于学习额度与奖励兑换。")
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    walletBalance.frame(minWidth: 240, maxWidth: .infinity)
                    learningCreditExchange
                        .frame(minWidth: 240, maxWidth: .infinity)
                    redemptionPreview(
                        icon: "shippingbox",
                        title: store.t("Physical rewards", "实物奖励"),
                        body: store.t("Prototype catalog only. Fulfilment and redemption are not connected yet.", "当前仅为目录原型，尚未接入履约与兑换后端。"),
                        badge: store.t("PROTOTYPE", "原型"),
                        tint: LumapTheme.coral
                    )
                    .frame(minWidth: 240, maxWidth: .infinity)
                }
                VStack(spacing: 14) {
                    walletBalance
                    learningCreditExchange
                    redemptionPreview(
                        icon: "shippingbox",
                        title: store.t("Physical rewards", "实物奖励"),
                        body: store.t("Prototype catalog only. Fulfilment and redemption are not connected yet.", "当前仅为目录原型，尚未接入履约与兑换后端。"),
                        badge: store.t("PROTOTYPE", "原型"),
                        tint: LumapTheme.coral
                    )
                }
            }
        }
    }

    private var walletBalance: some View {
        LumapCard(padding: 18, style: .featured) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    LumapIconTile(icon: "sparkles", tint: LumapTheme.gold, size: 40)
                    Spacer()
                    Text("\(store.rewardBalance)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Text(store.t("Available Lumens", "可用光点"))
                    .font(.headline)
                Text(rewardEntries.isEmpty
                     ? store.t("No reward events yet.", "还没有奖励记录。")
                     : store.t("\(rewardEntries.count) recorded reward event(s)", "共 \(rewardEntries.count) 条奖励记录"))
                    .font(.caption)
                    .foregroundStyle(LumapTheme.secondaryInk)
                Button(store.t("View reward history", "查看奖励记录")) {
                    store.selectedSection = .rewards
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        }
    }

    private var learningCreditExchange: some View {
        LumapCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LumapIconTile(icon: "cpu", tint: LumapTheme.accent, size: 40)
                    Spacer()
                    Text(store.hasUnlimitedAICredits
                         ? store.t("∞ · DEMO", "∞ · 演示账号")
                         : store.t("\(store.aiCreditBalance) CREDITS", "\(store.aiCreditBalance) 额度"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LumapTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LumapTheme.accent.opacity(0.10), in: Capsule())
                }
                Text(store.t("AI learning credits", "AI 学习额度"))
                    .font(.headline)
                Text(store.hasUnlimitedAICredits
                     ? store.t(
                        "Your hackathon demo account has unlimited model-powered learning. Metered accounts keep a balance and use the same charging boundary.",
                        "你的 Hackathon 演示账号拥有无限大模型学习额度。普通账号会保留额度余额，并通过同一扣费入口使用。"
                     )
                     : store.t(
                        "Exchange 20 Lumens for 100 credits used by model-powered learning sessions.",
                        "使用 20 光点兑换 100 个额度，用于大模型驱动的学习会话。"
                     ))
                .font(.caption)
                .foregroundStyle(LumapTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if store.hasUnlimitedAICredits {
                    Label(store.t("Unlimited access active", "无限额度已启用"), systemImage: "infinity.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LumapTheme.mint)
                        .accessibilityLabel(store.t("Demo account, unlimited AI learning credits", "演示账号，无限 AI 学习额度"))
                } else {
                    Button(store.t("Exchange · 20 Lumens", "兑换 · 20 光点")) {
                        do {
                            try store.redeemLearningCredits(credits: 100, cost: 20)
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.rewardBalance < 20)
                    .help(store.rewardBalance < 20
                          ? store.t("Earn 20 Lumens to exchange.", "获得 20 光点后即可兑换。")
                          : store.t("Add 100 AI learning credits.", "添加 100 个 AI 学习额度。"))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        }
    }

    private func redemptionPreview(icon: String, title: String, body: String, badge: String, tint: Color) -> some View {
        LumapCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    LumapIconTile(icon: icon, tint: tint, size: 40)
                    Spacer()
                    PrototypeBadge(label: badge)
                }
                Text(title).font(.headline)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(LumapTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(store.t("Unavailable in prototype", "原型暂不可兑换")) {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(LumapTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentGoal: LearningGoal? {
        store.currentGoal
            ?? goals.first { $0.status == "active" }
            ?? goals.first { $0.status == "paused" }
            ?? goals.first
    }

    private var constellationAccessibilityValue: String {
        let percent = Int(clampedProgress(currentGoal?.progress ?? 0) * 100)
        return store.t(
            "\(percent) percent, \(currentActivities.count) activities, \(currentReviewedAssessments.count) checks",
            "进度 \(percent)%，\(currentActivities.count) 个活动，\(currentReviewedAssessments.count) 次检测"
        )
    }

    private var currentActivities: [ActivityRecord] {
        guard let id = currentGoal?.id else { return [] }
        return activities.filter { $0.goalID == id }
    }

    private var currentReviewedAssessments: [AssessmentRecord] {
        guard let id = currentGoal?.id else { return [] }
        return assessments.filter { $0.goalID == id && $0.status == "reviewed" }
    }

    private var filteredGoals: [LearningGoal] {
        let filtered: [LearningGoal]
        switch projectScope {
        case .all:
            filtered = goals
        case .active:
            filtered = goals.filter { $0.status == "active" }
        case .paused:
            filtered = goals.filter { $0.status == "paused" }
        case .completed:
            filtered = goals.filter { $0.status == "completed" }
        }
        guard let currentID = store.currentGoal?.id,
              let index = filtered.firstIndex(where: { $0.id == currentID }),
              index != filtered.startIndex else { return filtered }
        var prioritized = filtered
        prioritized.insert(prioritized.remove(at: index), at: 0)
        return prioritized
    }

    private var emptyProjectMessage: String {
        switch projectScope {
        case .all: store.t("Start a topic to create your first learning project.", "开始一个主题来创建第一个学习项目。")
        case .active: store.t("No project is active right now.", "目前没有进行中的项目。")
        case .paused: store.t("No projects are paused.", "目前没有暂停的项目。")
        case .completed: store.t("Completed projects will collect here.", "完成的项目会汇集在这里。")
        }
    }

    private var methodCounts: [LearningMethod: Int] {
        activities.reduce(into: [:]) { result, activity in
            guard let method = LearningMethod(rawValue: activity.methodID) else { return }
            result[method, default: 0] += 1
        }
    }

    private var maximumMethodCount: Int {
        methodCounts.values.max() ?? 0
    }

    private var growthInsights: [GrowthInsight] {
        var insights: [GrowthInsight] = []

        if let mostUsed = methodCounts.max(by: { $0.value < $1.value }) {
            insights.append(.init(
                id: "method",
                icon: mostUsed.key.icon,
                tint: LumapTheme.accent,
                title: store.t("Most practised", "最常练习"),
                body: store.t(
                    "\(LumapLocalization.methodName(mostUsed.key, language: .english)) appears in \(mostUsed.value) saved activity(s). This reflects use, not proven effectiveness.",
                    "\(LumapLocalization.methodName(mostUsed.key, language: .simplifiedChinese))出现在 \(mostUsed.value) 个已保存活动中；这代表使用偏好，并非已验证的效果。"
                )
            ))
        } else {
            insights.append(.init(
                id: "method-empty",
                icon: "sparkles.rectangle.stack",
                tint: LumapTheme.accent,
                title: store.t("Method signal is waiting", "等待学习方式信号"),
                body: store.t("Complete an activity to begin building a method footprint.", "完成一次学习活动后，这里会开始形成你的方式轨迹。")
            ))
        }

        let reviewed = assessments.filter { $0.status == "reviewed" }
        let theory = reviewed.filter { $0.kind == AssessmentKind.theoretical.rawValue }.count
        let practical = reviewed.filter { $0.kind == AssessmentKind.practical.rawValue }.count
        insights.append(.init(
            id: "evidence",
            icon: "checkmark.seal",
            tint: LumapTheme.cyan,
            title: store.t("Evidence balance", "证据分布"),
            body: reviewed.isEmpty
                ? store.t("No optional checks completed yet. Missing evidence stays unscored.", "尚未完成可选检测；缺失的证据不会被记为零分。")
                : store.t("\(theory) theoretical and \(practical) practical check(s) have been reviewed.", "已复核 \(theory) 次理论检测与 \(practical) 次实践检测。")
        ))

        let recentStart = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        let recentCount = activities.filter { $0.completedAt >= recentStart }.count
        insights.append(.init(
            id: "momentum",
            icon: "waveform.path.ecg",
            tint: LumapTheme.mint,
            title: store.t("Seven-day rhythm", "七日节奏"),
            body: recentCount == 0
                ? store.t("No activity was saved in the last seven days. Your next step can stay small.", "过去七天还没有保存活动，下一步可以从很小的行动开始。")
                : store.t("\(recentCount) learning activity record(s) were saved in the last seven days.", "过去七天保存了 \(recentCount) 条学习活动记录。")
        ))

        if let goal = currentGoal {
            insights.append(.init(
                id: "focus",
                icon: "scope",
                tint: LumapTheme.coral,
                title: store.t("Current focus", "当前关注点"),
                body: goal.weakAspect
            ))
        }

        return insights
    }

    private var timelineItems: [PersonalTimelineItem] {
        let activityItems = activities.map { activity in
            PersonalTimelineItem(
                id: "activity-\(activity.id.uuidString)",
                date: activity.completedAt,
                title: activity.title,
                detail: activity.artifactText,
                icon: "sparkles",
                tint: LumapTheme.mint
            )
        }
        let assessmentItems = assessments.map { assessment in
            let theoretical = assessment.kind == AssessmentKind.theoretical.rawValue
            let skipped = assessment.status == "skipped"
            return PersonalTimelineItem(
                id: "assessment-\(assessment.id.uuidString)",
                date: assessment.createdAt,
                title: theoretical ? store.t("Theoretical check", "理论检测") : store.t("Practical check", "实践检测"),
                detail: skipped ? store.t("Skipped · no score recorded", "已跳过 · 未记录分数") : assessment.feedback,
                icon: skipped ? "arrow.right" : (theoretical ? "brain.head.profile" : "wrench.and.screwdriver"),
                tint: skipped ? LumapTheme.secondaryInk : (theoretical ? LumapTheme.cyan : LumapTheme.coral)
            )
        }
        return (activityItems + assessmentItems).sorted { $0.date > $1.date }
    }

    private func open(_ goal: LearningGoal) {
        journeyGoal = goal
    }

    private func select(_ look: PersonaLook) {
        do {
            try store.redeemPersonaStyle(look.name, cost: 0)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clampedProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "active": store.t("Active", "进行中")
        case "paused": store.t("Paused", "已暂停")
        case "completed": store.t("Completed", "已完成")
        default: status
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "active": "play.circle.fill"
        case "paused": "pause.circle.fill"
        case "completed": "checkmark.circle.fill"
        default: "circle.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "active": LumapTheme.accent
        case "paused": LumapTheme.gold
        case "completed": LumapTheme.mint
        default: LumapTheme.secondaryInk
        }
    }
}

private enum ProjectScope: String, CaseIterable, Identifiable {
    case all, active, paused, completed

    var id: String { rawValue }

    func label(using store: LumapStore) -> String {
        switch self {
        case .all: store.t("All", "全部")
        case .active: store.t("Started", "已开始")
        case .paused: store.t("Paused", "已暂停")
        case .completed: store.t("Completed", "已完成")
        }
    }
}

private struct PersonaLook: Identifiable {
    let name: String
    let colors: [Color]
    var id: String { name }
}

private struct GrowthInsight: Identifiable {
    let id: String
    let icon: String
    let tint: Color
    let title: String
    let body: String
}

private struct PersonalTimelineItem: Identifiable {
    let id: String
    let date: Date
    let title: String
    let detail: String
    let icon: String
    let tint: Color
}

private struct ConstellationMark: View {
    let progress: Double
    let activityCount: Int
    let evidenceCount: Int
    let title: String
    let accessibilityValue: String

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(LumapTheme.accent.opacity(0.10), lineWidth: 1)
                    .frame(width: size * 0.92, height: size * 0.92)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(LumapTheme.pathGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.72, height: size * 0.72)
                Circle()
                    .stroke(LumapTheme.cyan.opacity(0.19), style: StrokeStyle(lineWidth: 1, dash: [4, 7]))
                    .frame(width: size * 0.50, height: size * 0.50)

                orbitPoint(icon: "rectangle.3.group.bubble.left", value: activityCount, tint: LumapTheme.accent)
                    .offset(x: size * 0.35, y: -size * 0.14)
                orbitPoint(icon: "checkmark.seal", value: evidenceCount, tint: LumapTheme.cyan)
                    .offset(x: -size * 0.31, y: size * 0.22)

                VStack(spacing: 2) {
                    Text("\(Int(min(max(progress, 0), 1) * 100))%")
                        .font(.system(size: 27, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(LumapTheme.secondaryInk)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private func orbitPoint(icon: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text("\(value)").monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(LumapTheme.elevatedSurface, in: Capsule())
        .overlay { Capsule().stroke(tint.opacity(0.22), lineWidth: 0.75) }
    }
}
