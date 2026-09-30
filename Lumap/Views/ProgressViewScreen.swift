import SwiftData
import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \LearningGoal.updatedAt, order: .reverse) private var goals: [LearningGoal]
    @Query(sort: \ActivityRecord.completedAt, order: .reverse) private var activities: [ActivityRecord]
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var assessments: [AssessmentRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    eyebrow: store.t("YOUR EVIDENCE", "你的学习证据"),
                    title: store.t("Progress you can explain", "可解释的学习进度"),
                    subtitle: store.t("Lumap separates practice, theoretical evidence and practical evidence. Missing evidence stays missing—it never becomes a zero.", "Lumap 会区分练习、理论证据和实践证据。缺失证据会保持缺失，不会被记为零分。")
                )

                evidenceJourney

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        goalsPanel.frame(minWidth: 360)
                        evidencePanel.frame(minWidth: 320)
                    }
                    VStack(spacing: 16) {
                        goalsPanel
                        evidencePanel
                    }
                }
                timeline
            }
            .padding(LumapTheme.pagePadding)
            .frame(maxWidth: 1100, alignment: .leading)
        }
    }

    private var currentGoal: LearningGoal? {
        store.currentGoal
            ?? goals.first { $0.status == "active" }
            ?? goals.first { $0.status == "paused" }
            ?? goals.first
    }

    private var currentActivities: [ActivityRecord] {
        guard let goalID = currentGoal?.id else { return [] }
        return activities.filter { $0.goalID == goalID }
    }

    private var currentAssessments: [AssessmentRecord] {
        guard let goalID = currentGoal?.id else { return [] }
        return assessments.filter { $0.goalID == goalID && $0.status == "reviewed" }
    }

    private var evidenceJourney: some View {
        LumapCard(padding: 22, style: .featured) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.t("Explore · Practise · Verify", "探索 · 练习 · 验证"))
                            .font(.title3.weight(.semibold))
                        Text(currentGoal?.originalInput ?? store.t("Start a topic to begin your evidence trail.", "开始一个主题来建立你的证据轨迹。"))
                            .font(.subheadline)
                            .foregroundStyle(LumapTheme.secondaryInk)
                            .lineLimit(2)
                    }
                    Spacer()
                    if let goal = currentGoal {
                        Text("\(Int(goal.progress * 100))%")
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(LumapTheme.accent)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        evidenceMetric(
                            icon: "sparkles",
                            title: store.t("Explored", "已探索"),
                            value: currentGoal == nil ? 0 : 1,
                            target: 1,
                            detail: store.t("Goal chosen", "已选择目标"),
                            tint: LumapTheme.accent
                        )
                        evidenceMetric(
                            icon: "rectangle.3.group.bubble.left",
                            title: store.t("Practised", "已练习"),
                            value: Set(currentActivities.map(\.methodID)).count,
                            target: 3,
                            detail: store.t("Distinct methods", "不同学习方式"),
                            tint: LumapTheme.accent
                        )
                        evidenceMetric(
                            icon: "checkmark.seal",
                            title: store.t("Verified", "已验证"),
                            value: currentAssessments.count,
                            target: 2,
                            detail: store.t("Optional checks", "可选检测"),
                            tint: LumapTheme.cyan
                        )
                    }
                    VStack(spacing: 10) {
                        evidenceMetric(icon: "sparkles", title: store.t("Explored", "已探索"), value: currentGoal == nil ? 0 : 1, target: 1, detail: store.t("Goal chosen", "已选择目标"), tint: LumapTheme.accent)
                        evidenceMetric(icon: "rectangle.3.group.bubble.left", title: store.t("Practised", "已练习"), value: Set(currentActivities.map(\.methodID)).count, target: 3, detail: store.t("Distinct methods", "不同学习方式"), tint: LumapTheme.accent)
                        evidenceMetric(icon: "checkmark.seal", title: store.t("Verified", "已验证"), value: currentAssessments.count, target: 2, detail: store.t("Optional checks", "可选检测"), tint: LumapTheme.cyan)
                    }
                }
            }
        }
    }

    private func evidenceMetric(
        icon: String,
        title: String,
        value: Int,
        target: Int,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                LumapIconTile(icon: icon, tint: tint, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(LumapTheme.secondaryInk)
                }
                Spacer()
                Text("\(value)/\(target)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            ProgressView(value: min(Double(value) / Double(target), 1))
                .tint(tint)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(LumapTheme.surface, in: RoundedRectangle(cornerRadius: LumapTheme.compactRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: LumapTheme.compactRadius, style: .continuous).stroke(LumapTheme.border, lineWidth: 0.75) }
        .accessibilityElement(children: .combine)
    }

    private var goalsPanel: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.t("Learning maps", "学习地图")).font(.title3.bold())
                if goals.isEmpty {
                    Text(store.t("Start a topic to create your first map.", "开始一个主题来创建第一张学习地图。"))
                        .foregroundStyle(.secondary)
                }
                ForEach(goals.prefix(4)) { goal in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(goal.originalInput).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Spacer()
                            Text("\(Int(goal.progress * 100))%").font(.caption.monospacedDigit())
                        }
                        ProgressView(value: goal.progress).tint(LumapTheme.accent)
                        Text(store.t(
                            "Step \(goal.currentStep) of \(goal.totalSteps) · \(statusLabel(goal.status, language: .english))",
                            "第 \(goal.currentStep) / \(goal.totalSteps) 步 · \(statusLabel(goal.status, language: .simplifiedChinese))"
                        ))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if goal.id != goals.prefix(4).last?.id { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var evidencePanel: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.t("Evidence status", "证据状态")).font(.title3.bold())
                evidenceRow(kind: .theoretical, icon: "brain.head.profile", color: LumapTheme.cyan)
                evidenceRow(kind: .practical, icon: "wrench.and.screwdriver", color: LumapTheme.coral)
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(store.t("Method effectiveness", "学习方式效果"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Label(store.t("Preview Data", "预览数据"), systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(LumapTheme.secondaryInk)
                    }
                    Text(store.t("Evidence is still insufficient for your real profile. A separate demo profile can preview long-term trends.", "你的真实档案还没有足够证据。独立演示档案可以预览长期趋势。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var timeline: some View {
        LumapCard {
            VStack(alignment: .leading, spacing: 13) {
                Text(store.t("Learning Timeline", "学习时间线")).font(.title3.weight(.semibold))
                if activities.isEmpty && assessments.isEmpty {
                    Text(store.t("Completed activities and optional checks will appear here.", "完成的学习活动和可选检测会显示在这里。"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(timelineItems.prefix(8).enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.icon)
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(item.tint, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Text(item.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                        }
                        if index < min(timelineItems.count, 8) - 1 { Divider() }
                    }
                }
            }
        }
    }

    private var timelineItems: [ProgressTimelineItem] {
        let activityItems = activities.map { activity in
            ProgressTimelineItem(
                id: "activity-\(activity.id.uuidString)",
                date: activity.completedAt,
                title: activity.title,
                detail: activity.artifactText,
                icon: "checkmark",
                tint: LumapTheme.mint
            )
        }
        let assessmentItems = assessments.map { assessment in
            let theoretical = assessment.kind == AssessmentKind.theoretical.rawValue
            let skipped = assessment.status == "skipped"
            return ProgressTimelineItem(
                id: "assessment-\(assessment.id.uuidString)",
                date: assessment.createdAt,
                title: theoretical
                    ? store.t("Theoretical check", "理论检测")
                    : store.t("Practical check", "实践检测"),
                detail: skipped ? store.t("Not assessed · learning continued", "未检测 · 学习继续") : assessment.feedback,
                icon: skipped ? "arrow.right" : (theoretical ? "brain.head.profile" : "wrench.and.screwdriver"),
                tint: skipped ? Color.secondary : (theoretical ? LumapTheme.cyan : LumapTheme.coral)
            )
        }
        return (activityItems + assessmentItems).sorted { $0.date > $1.date }
    }

    private func evidenceCount(_ kind: AssessmentKind) -> String {
        let count = assessments.filter { $0.kind == kind.rawValue && $0.status == "reviewed" }.count
        return count == 0 ? store.t("Not assessed", "未检测") : "\(count)"
    }

    private func statusLabel(_ status: String, language: AppLanguage) -> String {
        switch (status, language) {
        case ("active", .english): "Active"
        case ("paused", .english): "Paused"
        case ("completed", .english): "Completed"
        case ("active", .simplifiedChinese): "进行中"
        case ("paused", .simplifiedChinese): "已暂停"
        case ("completed", .simplifiedChinese): "已完成"
        default: status
        }
    }

    private func evidenceRow(kind: AssessmentKind, icon: String, color: Color) -> some View {
        let records = assessments.filter { $0.kind == kind.rawValue && $0.status == "reviewed" }
        return HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind == .theoretical ? store.t("Theoretical", "理论") : store.t("Practical", "实践"))
                    .font(.subheadline.weight(.semibold))
                Text(records.isEmpty ? store.t("Not assessed", "未检测") : store.t("\(records.count) valid attempt(s)", "\(records.count) 次有效尝试"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: records.isEmpty ? "circle.dashed" : "checkmark.seal.fill")
                .foregroundStyle(records.isEmpty ? .secondary : color)
        }
    }
}

private struct ProgressTimelineItem: Identifiable {
    let id: String
    let date: Date
    let title: String
    let detail: String
    let icon: String
    let tint: Color
}
