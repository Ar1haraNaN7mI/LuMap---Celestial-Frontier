import SwiftData
import SwiftUI

struct MobileAssessmentView: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AssessmentRecord.createdAt, order: .reverse) private var attempts: [AssessmentRecord]
    @StateObject private var assessment = AssessmentSessionModel()

    private var sessionContext: AssessmentSessionContext { AssessmentSessionContext(store: store) }
    private var currentAttempts: [AssessmentRecord] {
        guard let goalID = store.currentGoal?.id else { return [] }
        return attempts.filter { $0.goalID == goalID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if store.currentGoal == nil {
                    ContentUnavailableView(
                        store.t("Start a learning path first", "请先开始学习路径"),
                        systemImage: "map",
                        description: Text(store.t("Choose a topic so the agent can prepare a relevant check.", "选择一个主题，让 Agent 准备对应的检测。"))
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.activeTopic).font(.title2.bold())
                        Text(store.t("Optional checks help your tutor understand your reasoning. You can keep learning without taking one.", "可选检测帮助导师理解你的推理。你也可以不做检测，继续学习。"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Picker(store.t("Assessment", "检测"), selection: $assessment.selectedKind) {
                        Text(store.t("Theory", "理论")).tag(AssessmentKind.theoretical)
                        Text(store.t("Practice", "实践")).tag(AssessmentKind.practical)
                    }
                    .pickerStyle(.segmented)
                    .disabled(assessment.evaluating)

                    VStack(alignment: .leading, spacing: 16) {
                        if assessment.context == sessionContext, let activity = assessment.activity {
                            activityContent(activity)
                        } else {
                            preparationState
                        }
                        if assessment.evaluating {
                            ProgressView(store.t("Checking your reasoning and evidence…", "正在检查你的推理和证据……"))
                        }
                        if let error = assessment.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout).foregroundStyle(MobileTheme.coral).textSelection(.enabled)
                        }
                        Button(store.t("Skip for now", "暂时跳过")) { skip() }
                            .buttonStyle(.bordered).disabled(assessment.evaluating)
                            .frame(minHeight: 44)
                    }
                    .mobileCard()

                    if assessment.selectedKind == .practical {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(store.t("AR concept preview", "AR 概念展示"), systemImage: "arkit")
                                .font(.headline)
                            Text(store.t("Explore a spatial learning prototype. It does not verify a real experiment or produce assessment scores.", "探索空间学习原型。它不会验证真实实验，也不会生成检测分数。"))
                                .font(.callout).foregroundStyle(.secondary)
                            NavigationLink(store.t("Open AR preview", "打开 AR 预览")) {
                                MobileSpatialLearningView()
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        }
                        .mobileCard()
                    }
                    if !currentAttempts.isEmpty {
                        Text(store.t("Evidence for this path", "当前路径的学习证据")).font(.title3.bold())
                        ForEach(currentAttempts.prefix(4)) { attempt in
                            feedbackCard(attempt, saved: false)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Check understanding", "检测理解"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sessionContext) { prepare() }
        .onChange(of: assessment.selectedKind) { _, _ in prepare() }
        .onDisappear { assessment.cancelRequests() }
    }

    @ViewBuilder private func activityContent(_ activity: LearningGeneratedActivity) -> some View {
        Text(activity.title).font(.title3.bold())
        if assessment.selectedKind == .practical {
            Text(activity.explanation).foregroundStyle(.secondary)
        }
        Text(activity.prompt).font(.headline).textSelection(.enabled)
        if assessment.selectedKind == .theoretical {
            Text(store.t("Explain the concept, show your reasoning, and test it with an example.", "解释概念、展示推理，并用案例检验。"))
                .font(.callout).foregroundStyle(.secondary)
            responseField(store.t("Your explanation", "你的解释"), text: $assessment.theoryAnswer)
        } else {
            ForEach(Array(activity.examples.enumerated()), id: \.offset) { _, example in
                Text(example).font(.callout).foregroundStyle(.secondary)
            }
            responseField(store.t("1. Your prediction or approach", "1. 你的预测或操作方案"), text: $assessment.prediction)
            responseField(store.t("2. Observed or calculated result", "2. 观察或计算的结果"), text: $assessment.observation)
            responseField(store.t("3. What you would revise", "3. 你会修正什么"), text: $assessment.adjustment)
        }
        Button(store.t("Submit for feedback", "提交并获得反馈")) { submit() }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .disabled(!assessment.canSubmit)
        if let result = assessment.result { feedbackCard(result, saved: true) }
    }

    private var preparationState: some View {
        VStack(alignment: .leading, spacing: 12) {
            if assessment.preparing {
                ProgressView(store.t("Preparing a check for your topic…", "正在为你的主题准备检测……"))
                Button(store.t("Cancel preparation", "取消准备")) { assessment.cancelRequests() }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            } else {
                Text(store.t("Prepare a check based on the sources and section you are learning now.", "依据你当前学习的章节与资料，准备一次检测。"))
                    .foregroundStyle(.secondary)
                Button(store.t("Prepare check", "准备检测")) { prepare() }
                    .buttonStyle(.borderedProminent).frame(minHeight: 44)
            }
        }
    }

    private func responseField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(store.t("Write your reasoning…", "写下你的推理……"), text: text, axis: .vertical)
                .lineLimit(4...12)
                .padding(12)
                .background(MobileTheme.raisedCard, in: RoundedRectangle(cornerRadius: 12))
                .disabled(assessment.evaluating)
                .accessibilityLabel(title)
        }
    }

    private func feedbackCard(_ record: AssessmentRecord, saved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(saved ? store.t("Feedback saved", "反馈已保存")
                     : record.kind == AssessmentKind.theoretical.rawValue ? store.t("Theory check", "理论检测") : store.t("Practical check", "实践检测"))
                    .font(.headline)
                Spacer()
                if let score = record.score {
                    Text("\(score)/\(record.evidenceSummary.contains("AI rubric /100") ? 100 : 6)")
                        .font(.subheadline.bold().monospacedDigit())
                } else {
                    Text(store.t("Not assessed", "未检测")).font(.caption)
                }
            }
            Text(record.feedback).font(.callout)
            Text(record.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MobileTheme.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    private func prepare() {
        assessment.prepare(context: sessionContext) { kind in
            try await store.prepareAssessmentActivity(kind: kind)
        }
    }

    private func submit() {
        assessment.submit(context: sessionContext) { kind, response, activity in
            try await store.evaluateAssessment(kind: kind, response: response, displayedActivity: activity)
        }
    }

    private func skip() {
        do {
            try store.skipAssessment(kind: assessment.selectedKind)
            dismiss()
        } catch { assessment.errorMessage = error.localizedDescription }
    }
}
