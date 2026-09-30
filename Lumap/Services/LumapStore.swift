#if canImport(AppKit)
import AppKit
#endif
import Combine
import Foundation
import PDFKit
import SwiftData

enum PersonaMode: String {
    case idle
    case learning
    case paused
    case stopped
    case expired
}

enum PersonaNudgeKind: Int, CaseIterable {
    case summary
    case anotherWay
    case question
}

enum LumapStoreError: LocalizedError {
    case notConfigured
    case invalidTopic
    case invalidArtifact
    case invalidURL
    case unsupportedFile
    case fileTooLarge
    case unreadableFile
    case noActiveGoal
    case completedGoal
    case insufficientReward
    case insufficientAICredits
    case invalidAICreditAmount
    case creditsAlreadyUnlimited
    case invalidProviderEndpoint
    case groundedStageUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Lumap's local database is not ready yet."
        case .invalidTopic: "Enter a topic you want to learn."
        case .invalidArtifact: "Add a learning note before completing this activity."
        case .invalidURL: "Enter a valid public HTTPS profile link."
        case .unsupportedFile: "Lumap can currently import PDF, TXT, Markdown, CSV and JSON files."
        case .fileTooLarge: "This file is larger than the 25 MiB prototype limit."
        case .unreadableFile: "Lumap could not extract readable text from this file."
        case .noActiveGoal: "Start a learning goal first."
        case .completedGoal: "This learning map is complete. Start a new topic to continue learning."
        case .insufficientReward: "You need more Lumens to unlock this Persona style."
        case .insufficientAICredits: "This account does not have enough AI learning credits."
        case .invalidAICreditAmount: "AI credit usage must be greater than zero."
        case .creditsAlreadyUnlimited: "This demo account already has unlimited AI learning credits."
        case .invalidProviderEndpoint: "Enter an HTTP or HTTPS provider endpoint without credentials, query parameters or fragments."
        case .groundedStageUnavailable: "Complete the current Guided Study stage before moving ahead."
        }
    }
}

enum AICreditChargeResult: Equatable {
    case unlimited
    case charged(remaining: Int)
}

@MainActor
final class LumapStore: ObservableObject {
    @Published var selectedSection: AppSection = .home
    @Published var profile: LearnerProfile?
    @Published var currentGoal: LearningGoal?
    @Published var currentMethod: LearningMethod = .guidedExplanation
    @Published var recommendationBatch = 0
    @Published var sourceStatusMessage: String?
    @Published var isAnalyzingSource = false
    @Published var bannerMessage: String?
    @Published var personaMode: PersonaMode = .idle
    @Published var personaSecondsRemaining = 0
    @Published var personaPrompt = "Ready when you are."
    @Published var personaNudgeIndex = -1
    @Published var providerTestState = "Not tested"
    @Published var providerIsTesting = false
    @Published private(set) var bootstrapError: String?
    @Published var activePlan: LearningCoursePlan?
    @Published var activeActivity: LearningGeneratedActivity?
    @Published var activityFeedback: LearningEvaluation?
    @Published var isPlanning = false
    @Published var isGeneratingActivity = false
    @Published var isEvaluatingActivity = false
    @Published var isAdaptingSection = false
    @Published var activityGenerationStartedAt: Date?
    @Published var learningError: String?
    @Published var planningMessage = ""
    @Published var suggestedTopics: [LearningSuggestedTopic] = []
    @Published var isRefreshingRecommendations = false
    @Published var recommendationError: String?
    @Published var dialogueMessages: [LearningDialogueTurn] = []
    @Published var adaptiveReason = ""
    @Published var sessionEvidence = LearningSessionEvidence()
    var planningTask: Task<Void, Never>?
    var activityTask: Task<Void, Never>?
    var activityWatchdog: Task<Void, Never>?
    var activityRequestID = UUID()
    var planningRequestID = UUID()
    var evaluationRequestID = UUID()
    var activeGenerationKey = ""
    var activityStartedAt = Date.now
    var evaluatedResponse = ""
    var dismissedSuggestions: [String] = []

    private(set) var context: ModelContext?
    private var configured = false
    private var configuring = false
    private let defaults = UserDefaults.standard
    private var personaEndDate: Date?
    private var personaDurationSeconds = 0
    private var lastPersonaNudgeSecond: Int?

    var language: AppLanguage {
        AppLanguage(rawValue: profile?.interfaceLanguage ?? "") ?? .english
    }

    var learningLanguage: AppLanguage {
        AppLanguage(rawValue: profile?.learningLanguage ?? "") ?? .english
    }

    var activeTopic: String {
        currentGoal?.originalInput ?? t("Your next topic", "你的下一个主题")
    }

    var rewardBalance: Int { profile?.rewardBalance ?? 0 }
    var aiCreditBalance: Int { profile?.aiCreditBalance ?? 0 }
    var aiCreditPlan: AICreditPlan {
        AICreditPlan(rawValue: profile?.aiCreditPlanID ?? "") ?? .metered
    }
    var hasUnlimitedAICredits: Bool { aiCreditPlan == .demoUnlimited }
    var personaSessionDuration: Int { max(1, personaDurationSeconds) }
    var personaSessionMinutes: Int { max(1, Int(ceil(Double(personaSessionDuration) / 60))) }

    var providerEndpoint: String {
        get { defaults.string(forKey: "lumap.provider.endpoint") ?? "https://api.ikuncode.cc/v1" }
        set { defaults.set(newValue, forKey: "lumap.provider.endpoint") }
    }

    var providerModel: String {
        get { defaults.string(forKey: "lumap.provider.model") ?? "gpt-5.6-sol" }
        set { defaults.set(newValue, forKey: "lumap.provider.model") }
    }

    var providerStyle: ProviderAPIStyle {
        get { ProviderAPIStyle(rawValue: defaults.string(forKey: "lumap.provider.style") ?? "") ?? .openAIResponses }
        set { defaults.set(newValue.rawValue, forKey: "lumap.provider.style") }
    }

    var hasSavedAPIKey: Bool {
        LumapKeychainStore.read(account: "active-provider")?.isEmpty == false
    }

    /// Returns a complete runtime configuration without exposing the key to the
    /// view. Remote providers require a saved Keychain value; loopback models
    /// may intentionally run without one.
    func providerConfigurationForGeneration() -> ProviderConfiguration? {
        let cleanEndpoint = providerEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = providerModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEndpoint.isEmpty, !cleanModel.isEmpty,
              let url = URL(string: cleanEndpoint), let host = url.host else { return nil }

        let key = LumapKeychainStore.read(account: "active-provider") ?? ""
        let normalizedHost = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let isLoopback = normalizedHost == "localhost"
            || normalizedHost.hasSuffix(".localhost")
            || normalizedHost == "::1"
            || normalizedHost.hasPrefix("127.")
        guard !key.isEmpty || isLoopback else { return nil }

        return ProviderConfiguration(
            endpoint: cleanEndpoint,
            model: cleanModel,
            style: providerStyle,
            apiKey: key
        )
    }

    func t(_ english: String, _ chinese: String) -> String {
        LumapLocalization.text(english, chinese, language: language)
    }

    func learningText(_ english: String, _ chinese: String) -> String {
        LumapLocalization.text(english, chinese, language: learningLanguage)
    }

    func configure(context: ModelContext) {
        guard !configured, !configuring else { return }
        configuring = true
        defer { configuring = false }
        self.context = context

        do {
            var profiles = try context.fetch(FetchDescriptor<LearnerProfile>())
            if profiles.isEmpty {
                let created = LearnerProfile()
                context.insert(created)
                profiles = [created]
            }
            profile = profiles[0]

            var goalDescriptor = FetchDescriptor<LearningGoal>(
                predicate: #Predicate { $0.status == "active" },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            goalDescriptor.fetchLimit = 1
            currentGoal = try context.fetch(goalDescriptor).first

            let records = try context.fetch(FetchDescriptor<AppHealthRecord>())
            if let health = records.first {
                health.lastVerifiedAt = .now
                health.verificationCount += 1
            } else {
                context.insert(AppHealthRecord())
            }
            try commit(context)
            configured = true
            bootstrapError = nil
            restorePersonaState()
            if let goal = currentGoal,
               let method = LearningMethod(rawValue: goal.preferredMethodID) {
                currentMethod = method
            }
            restoreLearningAgentState()
        } catch {
            context.rollback()
            self.context = nil
            profile = nil
            currentGoal = nil
            bootstrapError = "Local database error: \(error.localizedDescription)"
            bannerMessage = bootstrapError
        }
    }

    func saveProfile(
        displayName: String,
        ageBand: String,
        background: String,
        availableMinutes: Int
    ) throws {
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Learner" : displayName
        profile.ageBand = ageBand
        profile.background = background
        profile.availableMinutes = min(240, max(5, availableMinutes))
        profile.updatedAt = .now
        try commit(context)
        objectWillChange.send()
        bannerMessage = t("Profile saved locally", "资料已保存到本地")
    }

    func updateInterfaceLanguage(_ language: AppLanguage) throws {
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        profile.interfaceLanguage = language.rawValue
        profile.updatedAt = .now
        try commit(context)
        objectWillChange.send()
    }

    func updateLearningLanguage(_ language: AppLanguage) throws {
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        profile.learningLanguage = language.rawValue
        profile.updatedAt = .now
        try commit(context)
        resetLearningAgentState()
        restoreLearningAgentState()
        objectWillChange.send()
    }

    func updateAccessibility(reducedMotion: Bool, largeText: Bool) throws {
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        profile.reducedMotion = reducedMotion
        profile.largeText = largeText
        profile.updatedAt = .now
        try commit(context)
        objectWillChange.send()
    }

    func analyzePublicProfile(_ value: String) async throws {
        guard let context else { throw LumapStoreError.notConfigured }
        guard let config = providerConfigurationForGeneration() else { throw LearningSessionError.providerRequired }
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw LumapStoreError.invalidURL }
        isAnalyzingSource = true
        sourceStatusMessage = t("Reading the public page…", "正在读取公开页面…")
        defer { isAnalyzingSource = false }
        do {
            let page = try await LearningResearchService.fetchPage(url: url)
            let topics = try await LearningAgentService.interests(sources: [page], learnerContext: learnerContextForGeneration, configuration: config)
            let existing = try context.fetch(FetchDescriptor<SourceRecord>()).first { $0.canonicalURL == page.url }
            if let existing {
                existing.status = "ready"
                existing.isDemo = false
                existing.coverageNote = "Read public text; interest suggestions require your confirmation."
            } else {
                context.insert(SourceRecord(kind: "personalProfile", canonicalURL: page.url, displayName: page.title,
                    status: "ready", coverageNote: "Read public text; interest suggestions require your confirmation.", isDemo: false))
            }
            let known = try context.fetch(FetchDescriptor<InterestEvidence>()).map(\.topic)
            for topic in topics where !known.contains(topic.title) {
                context.insert(InterestEvidence(topic: topic.title, sourceLabel: page.title, explanation: topic.reason, strength: 0.5))
            }
            try commit(context)
            recommendationBatch += 1
            sourceStatusMessage = t("Public page read. Review the suggested interests before they personalise learning.", "公开页面已读取。请确认兴趣建议后再用于个性化学习。")
        } catch {
            sourceStatusMessage = error.localizedDescription
            throw error
        }
    }

    func confirmInterest(_ interest: InterestEvidence) throws {
        guard let context else { throw LumapStoreError.notConfigured }
        interest.status = "confirmed"
        try commit(context)
        objectWillChange.send()
    }

    func removeInterest(_ interest: InterestEvidence) throws {
        guard let context else { throw LumapStoreError.notConfigured }
        context.delete(interest)
        try commit(context)
        recommendationBatch += 1
    }

    func nextRecommendationBatch() {
        recommendationBatch = (recommendationBatch + 1) % 3
        dismissedSuggestions.append(contentsOf: suggestedTopics.map(\.title))
        Task { await refreshPersonalizedRecommendations(force: true) }
    }

    func importHistoryPreview(from url: URL) async throws -> Int {
        guard let context else { throw LumapStoreError.notConfigured }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let parsed = try await Task.detached(priority: .userInitiated) {
            try Self.parseHistoryFile(at: url)
        }.value
        context.insert(SourceRecord(
            kind: "historyImport",
            canonicalURL: "",
            displayName: parsed.sourceName,
            status: "ready",
            coverageNote: "Imported locally: \(parsed.rowCount) records · \(parsed.domainCount) distinct domains. Raw browsing rows are not used as ability evidence.",
            isDemo: false
        ))
        for topic in parsed.suggestions.prefix(4) {
            context.insert(InterestEvidence(
                topic: topic,
                sourceLabel: "History import",
                explanation: "Suggested from repeated domains in your selected file. Confirm before use.",
                strength: 0.55
            ))
        }
        try commit(context)
        recommendationBatch += 1
        return parsed.rowCount
    }

    func recommendations(interests: [InterestEvidence]) -> [Recommendation] {
        if !suggestedTopics.isEmpty {
            return suggestedTopics.map {
                Recommendation(id: $0.id, title: $0.title, reason: $0.reason,
                               icon: LearningMethod(rawValue: $0.methodID)?.icon ?? "sparkles", tint: "accent")
            }
        }
        let confirmed = interests.filter { $0.status == "confirmed" }.map(\.topic)
        let batches: [[Recommendation]] = [
            [
                .init(id: "climate", title: "Climate systems", reason: "Connect everyday weather to planetary feedback loops", icon: "cloud.sun.rain.fill", tint: "cyan"),
                .init(id: "story-code", title: "Creative coding", reason: "Turn ideas into interactive visual stories", icon: "curlybraces.square.fill", tint: "accent"),
                .init(id: "behavior", title: "Why habits stick", reason: "A practical bridge between psychology and daily routines", icon: "brain.head.profile.fill", tint: "coral"),
                .init(id: "music", title: "Music and mathematics", reason: "See rhythm, ratio and harmony as one system", icon: "waveform", tint: "gold")
            ],
            [
                .init(id: "design", title: "Designing better questions", reason: "Improve how you explore any unfamiliar field", icon: "questionmark.bubble.fill", tint: "accent"),
                .init(id: "biology", title: "Cells as tiny cities", reason: "Use systems thinking to understand living structures", icon: "microbe.fill", tint: "mint"),
                .init(id: "finance", title: "Personal finance foundations", reason: "Build a calm mental model of risk and compounding", icon: "chart.line.uptrend.xyaxis", tint: "gold"),
                .init(id: "history", title: "History through primary sources", reason: "Learn to separate evidence from interpretation", icon: "building.columns.fill", tint: "coral")
            ],
            [
                .init(id: "ai", title: "How language models reason", reason: "Open the black box with small, testable examples", icon: "cpu.fill", tint: "accent"),
                .init(id: "woodwork", title: "Woodworking fundamentals", reason: "Move from safety and grain to your first joint", icon: "hammer.fill", tint: "gold"),
                .init(id: "space", title: "Reading the night sky", reason: "Use patterns and scale to navigate the universe", icon: "moon.stars.fill", tint: "cyan"),
                .init(id: "writing", title: "Writing with structure", reason: "Make complex ideas easier for other people to follow", icon: "pencil.and.outline", tint: "mint")
            ]
        ]
        var result = batches[recommendationBatch % batches.count]
        if let first = confirmed.first {
            result[0] = Recommendation(
                id: "interest-\(first.lowercased())",
                title: "Explore \(first)",
                reason: "Based on an interest you confirmed",
                icon: "sparkles",
                tint: "accent"
            )
        }
        return result
    }

    func startLearning(topic: String, materialID: UUID? = nil) throws {
        guard let context else { throw LumapStoreError.notConfigured }
        let clean = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { throw LumapStoreError.invalidTopic }

        let goal = LearningGoal(originalInput: clean, materialID: materialID)
        do {
            if let currentGoal, currentGoal.status == "active" {
                currentGoal.status = "paused"
                currentGoal.updatedAt = .now
            }
            context.insert(goal)
            try commit(context)
        } catch {
            context.rollback()
            throw error
        }
        currentGoal = goal
        resetLearningAgentState()
        currentMethod = .guidedExplanation
        personaPrompt = learningText("Let's map the first idea in \(clean).", "我们先梳理 \(clean) 的第一个概念。")
        selectedSection = .studio
    }

    func startGroundedStudy(from material: MaterialRecord) throws {
        if currentGoal?.materialID != material.id || currentGoal?.status != "active" {
            let topic = learningText("Study \(material.fileName)", "研读 \(material.fileName)")
            try startLearning(topic: topic, materialID: material.id)
        }
        if activePlan != nil { currentMethod = sectionMethods.first { !completedCurrentSectionMethodIDs.contains($0.rawValue) } ?? sectionMethods.first ?? .guidedExplanation }
        selectedSection = .groundedStudy
        personaPrompt = learningText(
            "Start with the source claim. Keep evidence separate from your interpretation.",
            "先找出资料中的主张，并把证据与自己的解释分开。"
        )
    }

    func openGroundedStudyForCurrentGoal() throws {
        guard currentGoal != nil else { throw LumapStoreError.noActiveGoal }
        selectedSection = .groundedStudy
    }

    func resumeGoal(_ goal: LearningGoal) throws {
        guard let context else { throw LumapStoreError.notConfigured }
        guard goal.status != "completed" else { throw LumapStoreError.completedGoal }
        do {
            if let currentGoal,
               currentGoal.id != goal.id,
               currentGoal.status == "active" {
                currentGoal.status = "paused"
            }
            goal.status = "active"
            goal.updatedAt = .now
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        currentGoal = goal
        resetLearningAgentState()
        currentMethod = LearningMethod(rawValue: goal.preferredMethodID) ?? .guidedExplanation
        restoreLearningAgentState()
        selectedSection = .studio
    }

    func setMethod(_ method: LearningMethod, fixed: Bool = false) throws {
        if currentMethod != method {
            evaluationRequestID = UUID()
            isEvaluatingActivity = false
            activityTask?.cancel()
            activityRequestID = UUID()
            isGeneratingActivity = false
            activeActivity = nil
            activityFeedback = nil
            evaluatedResponse = ""
            dialogueMessages = []
        }
        currentMethod = method
        if fixed, let currentGoal, let context {
            currentGoal.preferredMethodID = method.rawValue
            currentGoal.updatedAt = .now
            try commit(context)
            bannerMessage = t("Method preference saved. Effectiveness is not verified yet.", "学习方式偏好已保存，目前还没有足够证据判断效果。")
        }
    }

    func moduleCopy(for method: LearningMethod) -> ModuleCopy {
        if let activity = activeActivity, activity.methodID == method.rawValue {
            return .init(eyebrow: learningText("YOUR LEARNING ACTIVITY", "你的学习活动"),
                         title: activity.title, body: activePlan?.summary ?? "", prompt: activity.prompt)
        }
        if let plan = activePlan {
            return .init(eyebrow: learningText("SOURCE-GROUNDED COURSE", "基于资料的课程"),
                         title: currentLearningNode?.title ?? plan.title,
                         body: currentLearningNode?.objective ?? plan.summary, prompt: plan.diagnosticQuestion)
        }
        if currentGoal != nil, method != .spatialAR {
            return .init(eyebrow: learningText("PREPARING YOUR COURSE", "正在编排课程"),
                         title: activeTopic, body: learningText("Lumi researches your topic and builds a path around your goal and learning evidence.", "Lumi 正在检索主题，并结合目标与学习证据编排路径。"), prompt: "")
        }
        let topic = activeTopic
        switch method {
        case .guidedExplanation:
            return .init(
                eyebrow: learningText("BUILD A MENTAL MODEL", "建立心智模型"),
                title: learningText("Start wide, then zoom in", "先看全貌，再逐步放大"),
                body: learningText(
                    "Begin by naming the system, its parts and what changes over time. For \(topic), the first pass is about orientation—not memorising every detail.",
                    "先说出这个系统、它的组成部分，以及哪些内容会随时间变化。学习 \(topic) 的第一遍重在建立方向，不必记住每个细节。"
                ),
                prompt: learningText("Which part feels familiar, and which part is still fuzzy?", "哪一部分你已经熟悉，哪一部分仍然模糊？")
            )
        case .simulation:
            return .init(
                eyebrow: learningText("CHANGE ONE VARIABLE", "只改变一个变量"),
                title: learningText("Run a controlled simulation", "运行可控模拟"),
                body: learningText(
                    "Move the control and observe the model. The visual is a deterministic prototype, so you can focus on cause, effect and what evidence would change your conclusion.",
                    "移动控制项并观察模型。这个视觉模型是确定性原型，你可以专注于因果关系，以及哪些证据会改变结论。"
                ),
                prompt: learningText("Predict the result before you move the control.", "移动控制项之前，先预测结果。")
            )
        case .teachBack:
            return .init(
                eyebrow: learningText("EXPLAIN IT IN YOUR WORDS", "用自己的话讲出来"),
                title: learningText("Teach Lumap the core idea", "把核心概念教给 Lumap"),
                body: learningText(
                    "A clear explanation names the idea, gives one causal link and includes a concrete example. You can be incomplete—Lumap will ask for the missing bridge.",
                    "清楚的讲解需要说出概念、给出一条因果联系，并加入具体例子。即使不完整也没关系，Lumap 会追问缺失的连接。"
                ),
                prompt: learningText("Explain \(topic) to someone seeing it for the first time.", "向第一次接触这个主题的人解释 \(topic)。")
            )
        case .workedExample:
            return .init(
                eyebrow: learningText("FOLLOW THE REASONING", "跟随推理过程"),
                title: learningText("Complete a worked example", "完成一个示例推演"),
                body: learningText("Reveal one step at a time, then finish the missing step yourself. The value is in the reasoning between steps, not the final answer.", "逐步查看示例，再亲自完成缺失的一步。重点是步骤之间的推理，而不只是最终答案。"),
                prompt: learningText("What rule connects the last two steps?", "最后两个步骤之间遵循什么规则？")
            )
        case .socraticDialogue:
            return .init(
                eyebrow: learningText("QUESTION THE ASSUMPTION", "追问隐藏假设"),
                title: learningText("Reason through a Socratic dialogue", "通过苏格拉底式对话推理"),
                body: learningText("Choose an answer, inspect the follow-up question and revise your claim. The dialogue exposes assumptions instead of supplying a conclusion.", "先选择回答，再查看追问并修正观点。对话会帮助你发现假设，而不是直接给出结论。"),
                prompt: learningText("What would have to be true for your claim to hold?", "你的观点成立需要满足什么条件？")
            )
        case .analogy:
            return .init(
                eyebrow: learningText("MAP THE SIMILARITY", "建立类比映射"),
                title: learningText("Build and test an analogy", "建立并检验一个类比"),
                body: learningText("Match parts of \(topic) to a familiar system, then name where the comparison breaks. A useful analogy has both a mapping and a limit.", "把 \(topic) 的组成部分映射到熟悉的系统，再指出类比失效的位置。好的类比既有对应关系，也有边界。"),
                prompt: learningText("What is similar, and where does the analogy stop working?", "哪些部分相似，类比从哪里开始失效？")
            )
        case .visualMap:
            return .init(
                eyebrow: learningText("CONNECT THE PARTS", "连接关键部分"),
                title: learningText("Arrange a visual concept map", "排列一张概念关系图"),
                body: learningText("Place the core idea, causes, evidence and outcomes, then connect them into a path you can explain.", "放置核心概念、原因、证据和结果，再把它们连接成一条你能解释的路径。"),
                prompt: learningText("Which connection carries the most explanatory weight?", "哪条连接承担了最重要的解释作用？")
            )
        case .story:
            return .init(
                eyebrow: learningText("LEARN THROUGH A BRANCHING STORY", "通过分支剧情学习"),
                title: learningText("Enter a Paper2Galgame lesson", "进入 Paper2Galgame 剧情课"),
                body: learningText("A local visual-novel scene turns \(topic) into dialogue, choices and a checkpoint question. Your choice changes the next explanation.", "本地视觉小说场景会把 \(topic) 变成对白、选择和检查问题；你的选择会改变下一段讲解。"),
                prompt: learningText("Choose the response that best explains the evidence.", "选择最能解释证据的回应。")
            )
        case .flashRecall:
            return .init(
                eyebrow: learningText("RETRIEVE BEFORE REVIEW", "先回忆，再查看"),
                title: learningText("Run a rapid recall round", "进行一轮快速回忆"),
                body: learningText("Answer a short set from memory, reveal the cues and mark confidence. Retrieval makes gaps visible without turning them into a grade.", "先凭记忆回答一组短题，再查看提示并标记信心。回忆练习会暴露空白，但不会把它变成分数。"),
                prompt: learningText("What can you recall before seeing the hint?", "查看提示前，你能回忆起什么？")
            )
        case .spatialAR:
            return .init(
                eyebrow: learningText("PLACE THE IDEA IN SPACE", "把概念放进空间"),
                title: learningText("Explore a spatial AR lab", "探索空间 AR 实验"),
                body: learningText("Place learning anchors, change one property and describe what you observe. This demo works without a camera and is ready to hand off to an ARKit or visionOS provider.", "放置学习锚点、改变一个属性并描述观察结果。该演示无需摄像头即可运行，并可交给 ARKit 或 visionOS 提供器继续实现。"),
                prompt: learningText("What changed when you moved the spatial control?", "移动空间控制项后，什么发生了变化？")
            )
        case .deliberatePractice:
            return .init(
                eyebrow: learningText("PRACTISE THE WEAK LINK", "练习薄弱环节"),
                title: learningText("Complete a focused practice set", "完成一组针对性练习"),
                body: learningText("Work through one narrowly defined skill with immediate checks, then record the correction you would use next time.", "围绕一个明确的小技能进行即时练习，并记录下一次会采用的修正方法。"),
                prompt: learningText("What precise change improved your second attempt?", "哪一个具体改变改善了你的第二次尝试？")
            )
        case .reflection:
            return .init(
                eyebrow: learningText("NOTICE HOW YOU LEARNED", "观察自己的学习过程"),
                title: learningText("Close the loop with reflection", "通过反思闭合学习循环"),
                body: learningText("Compare what you expected, what changed and what you will try next. Reflection updates the learning strategy, not only the notes.", "比较原先预期、实际变化和下一步尝试。反思会更新学习策略，而不只是增加笔记。"),
                prompt: learningText("What changed in your understanding, and what remains uncertain?", "你的理解发生了什么变化，还有什么不确定？")
            )
        case .misconceptionDiagnosis:
            return .init(
                eyebrow: learningText("FIND THE HIDDEN MODEL", "找到隐藏的错误模型"),
                title: learningText("Diagnose a tempting misconception", "诊断一个看似合理的误区"),
                body: learningText("Compare three believable claims about \(topic), identify the one built on a faulty assumption, then explain what evidence would expose it.", "比较三个关于 \(topic) 的看似合理观点，找出建立在错误假设上的一个，再说明什么证据能揭示问题。"),
                prompt: learningText("Which claim would fail first under observation—and why?", "哪一个观点会最先被观察结果推翻？为什么？")
            )
        case .curiosityBranch:
            return .init(
                eyebrow: learningText("FOLLOW YOUR QUESTION", "沿着你的问题前进"),
                title: learningText("Choose a curiosity branch", "选择一条好奇心分岔"),
                body: learningText("Choose whether to build, break or connect \(topic). Each direction reveals a different question, so the path begins with what genuinely pulls your attention.", "选择构建、拆解或连接 \(topic)。不同方向会揭示不同问题，让学习路径从真正吸引你的地方开始。"),
                prompt: learningText("Which branch creates the question you most want to answer next?", "哪条分岔产生了你最想继续追问的问题？")
            )
        case .counterfactualLab:
            return .init(
                eyebrow: learningText("CHANGE THE RULE", "改变一条规则"),
                title: learningText("Run a counterfactual lab", "进行反事实推演"),
                body: learningText("Remove or reverse one assumption in \(topic), predict the consequence, then compare your prediction with a simulated observation.", "移除或反转 \(topic) 中的一项假设，预测后果，再把预测与模拟观察进行比较。"),
                prompt: learningText("If this rule disappeared, what would change first?", "如果这条规则消失，最先发生变化的会是什么？")
            )
        case .transferChallenge:
            return .init(
                eyebrow: learningText("USE IT SOMEWHERE NEW", "在新情境中使用"),
                title: learningText("Transfer the idea across contexts", "把概念迁移到新情境"),
                body: learningText("Apply the principle behind \(topic) to an unfamiliar case, map the corresponding parts and state where the transfer might break.", "把 \(topic) 背后的原理应用到陌生案例中，映射对应部分，并指出迁移可能失效的位置。"),
                prompt: learningText("What stays structurally the same in the new context?", "在新情境中，哪些结构仍然保持不变？")
            )
        case .narratedDeck:
            return .init(
                eyebrow: learningText("WATCH · LISTEN · RETRIEVE", "观看 · 聆听 · 回忆"),
                title: learningText("Learn through a narrated slide deck", "通过讲解课件学习"),
                body: learningText("Turn \(topic) and the current uploaded source into a five-slide visual lesson. Follow the narration timeline, then answer short quizzes that interrupt passive watching at useful moments.", "把 \(topic) 和当前上传资料转成五页视觉课程。跟随讲解时间轴学习，并在关键时刻回答穿插的小测，避免被动观看。"),
                prompt: learningText("Can you predict the next slide before the narration explains it?", "在讲解揭晓前，你能预测下一页会说什么吗？")
            )
        }
    }

    @discardableResult
    func completeActivity(method: LearningMethod, artifact: String) throws -> Bool {
        if activePlan != nil, method != .spatialAR {
            return try completeGeneratedActivity(method: method, artifact: artifact)
        }
        guard let context else { throw LumapStoreError.notConfigured }
        guard let goal = currentGoal else { throw LumapStoreError.noActiveGoal }
        let cleanArtifact = artifact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanArtifact.isEmpty else { throw LumapStoreError.invalidArtifact }
        let eventKey = "activity:\(goal.id.uuidString):\(method.rawValue)"
        let existing = try rewardExists(eventKey: eventKey, context: context)

        if !existing {
            do {
                context.insert(ActivityRecord(
                    goalID: goal.id,
                    methodID: method.rawValue,
                    title: LumapLocalization.methodName(method, language: language),
                    artifactText: cleanArtifact,
                    rewardEventKey: eventKey
                ))
                if try award(delta: 10, reason: "Completed \(LumapLocalization.methodName(method, language: .english))", eventKey: eventKey, context: context) {
                    advance(goal: goal)
                }
                try context.save()
                objectWillChange.send()
                bannerMessage = goal.status == "completed"
                    ? t("Learning map completed · +10 Lumens", "学习地图已完成 · +10 光点")
                    : t("Activity saved · +10 Lumens", "活动已保存 · +10 光点")
                return true
            } catch {
                context.rollback()
                throw error
            }
        }

        bannerMessage = t("Already saved — no duplicate reward", "已经保存，本次不会重复奖励")
        return false
    }

    @discardableResult
    func completeGroundedStudyStage(
        _ stage: GroundedStudyStage,
        response: String,
        sourceLabel: String,
        sourceCue: String
    ) throws -> Bool {
        guard let context else { throw LumapStoreError.notConfigured }
        guard let goal = currentGoal else { throw LumapStoreError.noActiveGoal }

        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanResponse.isEmpty else { throw LumapStoreError.invalidArtifact }

        let goalID = goal.id
        let records = try context.fetch(FetchDescriptor<ActivityRecord>())
            .filter { $0.goalID == goalID }
        let completedIDs = records.compactMap {
            GroundedStudyWorkflow.stage(fromAssistance: $0.assistance)?.rawValue
        }
        let snapshot = GroundedStudyWorkflow.snapshot(completedStageIDs: completedIDs)
        if snapshot.completedStages.contains(stage) {
            bannerMessage = t("Stage already saved — no duplicate reward", "该阶段已经保存，本次不会重复奖励")
            return false
        }
        guard snapshot.currentStage == stage else {
            throw LumapStoreError.groundedStageUnavailable
        }

        let cleanSourceLabel = sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveSourceLabel = cleanSourceLabel.isEmpty
            ? t("Current learning goal", "当前学习目标")
            : cleanSourceLabel
        let artifact = GroundedStudyWorkflow.evidenceArtifact(
            stage: stage,
            topic: goal.originalInput,
            sourceLabel: effectiveSourceLabel,
            sourceCue: sourceCue,
            response: cleanResponse,
            language: learningLanguage
        )
        let eventKey = "grounded-study:\(goal.id.uuidString):\(stage.rawValue)"

        do {
            context.insert(ActivityRecord(
                goalID: goal.id,
                methodID: stage.method.rawValue,
                title: "Guided Study · \(stage.title(language: language))",
                artifactText: artifact,
                assistance: GroundedStudyWorkflow.assistanceID(for: stage),
                rewardEventKey: eventKey
            ))
            if try award(
                delta: 10,
                reason: "Completed Guided Study: \(stage.rawValue)",
                eventKey: eventKey,
                context: context
            ) {
                if activePlan == nil { advance(goal: goal) }

            }
            try context.save()
            currentMethod = stage.method
            objectWillChange.send()

            let nextSnapshot = GroundedStudyWorkflow.snapshot(
                completedStageIDs: completedIDs + [stage.rawValue]
            )
            if let next = nextSnapshot.currentStage {
                personaPrompt = GroundedStudyWorkflow.prompt(
                    for: next,
                    topic: goal.originalInput,
                    sourceCue: sourceCue,
                    language: learningLanguage
                )
                bannerMessage = t("Evidence saved · next stage ready · +10 Lumens", "证据已保存 · 下一阶段已就绪 · +10 光点")
            } else {
                personaPrompt = learningText(
                    "The source-driven route is complete. Check learning or try a transfer method next.",
                    "资料驱动路线已完成。下一步可以检测学习效果，或尝试迁移方法。"
                )
                bannerMessage = t("Guided Study complete · +10 Lumens", "引导学习已完成 · +10 光点")
            }
            return true
        } catch {
            context.rollback()
            throw error
        }
    }

    func skipAssessment(kind: AssessmentKind) throws {
        guard let context else { throw LumapStoreError.notConfigured }
        guard let goal = currentGoal else { throw LumapStoreError.noActiveGoal }
        do {
            context.insert(AssessmentRecord(
                goalID: goal.id,
                kind: kind,
                status: "skipped",
                score: nil,
                feedback: "Assessment skipped. Learning remains available.",
                evidenceSummary: "Not assessed"
            ))
            let eventKey = "assessment-skip:\(goal.id.uuidString):\(kind.rawValue)"
            let rewarded = try award(delta: 3, reason: "Reflected on an optional check", eventKey: eventKey, context: context)
            try context.save()
            objectWillChange.send()
            bannerMessage = rewarded
                ? t("Skipped — your learning path stays open · +3 Lumens", "已跳过，学习路径保持开放 · +3 光点")
                : t("Skipped — your learning path stays open", "已跳过，学习路径保持开放")
        } catch {
            context.rollback()
            throw error
        }
    }

    func submitTheory(answer: String) throws -> AssessmentRecord {
        guard let context else { throw LumapStoreError.notConfigured }
        guard let goal = currentGoal else { throw LumapStoreError.noActiveGoal }
        let clean = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExample = clean.localizedCaseInsensitiveContains("example") || clean.contains("例如") || clean.contains("比如")
        let hasConnection = clean.localizedCaseInsensitiveContains("because") || clean.localizedCaseInsensitiveContains("therefore") || clean.contains("因为") || clean.contains("所以")
        let lengthScore = clean.count >= 140 ? 2 : clean.count >= 60 ? 1 : 0
        let score = lengthScore + (hasExample ? 2 : 0) + (hasConnection ? 2 : 0)
        let feedback: String
        if score >= 5 {
            feedback = t("Clear idea, causal link and example. Try transferring it to a new case next.", "核心概念、因果联系和例子都很清楚。下一步可以迁移到新的情境。")
        } else if score >= 3 {
            feedback = t("The core idea is visible. Add one explicit ‘because’ link or a concrete example.", "核心概念已经出现。再补充一个明确的因果联系或具体例子。")
        } else {
            feedback = t("This is a useful start. Name the core idea, explain why it works and add one example.", "这是一个有用的开头。请说出核心概念、解释原因并加入一个例子。")
        }
        let record = AssessmentRecord(
            goalID: goal.id,
            kind: .theoretical,
            status: "reviewed",
            score: score,
            feedback: feedback,
            evidenceSummary: "Concept \(lengthScore)/2 · Reasoning \(hasConnection ? 2 : 0)/2 · Transfer \(hasExample ? 2 : 0)/2"
        )
        do {
            context.insert(record)
            let eventKey = "assessment:theory:\(goal.id.uuidString)"
            if try award(delta: 15, reason: "Completed a theoretical check", eventKey: eventKey, context: context) {
                advance(goal: goal)
            }
            try context.save()
            objectWillChange.send()
            return record
        } catch {
            context.rollback()
            throw error
        }
    }

    func submitPractical(prediction: String, observation: String, adjustment: String) throws -> AssessmentRecord {
        guard let context else { throw LumapStoreError.notConfigured }
        guard let goal = currentGoal else { throw LumapStoreError.noActiveGoal }
        let fields = [prediction, observation, adjustment]
        let score = fields.reduce(0) { $0 + ($1.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 ? 2 : 1) }
        let feedback = score >= 6
            ? t("You predicted, observed and adjusted the model. The next step is to test a competing explanation.", "你完成了预测、观察和调整。下一步可以测试一个竞争性解释。")
            : t("The process is recorded. Add more detail to the shortest step before comparing results.", "过程已经记录。请在比较结果前补充最简短的那个步骤。")
        let record = AssessmentRecord(
            goalID: goal.id,
            kind: .practical,
            status: "reviewed",
            score: score,
            feedback: feedback,
            evidenceSummary: "Process · Result · Adjustment recorded in Spatial AR simulation"
        )
        do {
            context.insert(record)
            let eventKey = "assessment:practical:\(goal.id.uuidString)"
            if try award(delta: 15, reason: "Completed a practical check", eventKey: eventKey, context: context) {
                advance(goal: goal)
            }
            try context.save()
            objectWillChange.send()
            return record
        } catch {
            context.rollback()
            throw error
        }
    }

    func importMaterial(from url: URL) async throws -> MaterialRecord {
        guard let context else { throw LumapStoreError.notConfigured }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let parsed = try await Task.detached(priority: .userInitiated) {
            try Self.parseMaterialFile(at: url)
        }.value
        let record = MaterialRecord(
            fileName: parsed.fileName,
            fileType: parsed.fileType,
            excerpt: parsed.excerpt,
            citationLabel: parsed.citationLabel
        )
        context.insert(record)
        try commit(context)
        bannerMessage = t("Material imported with a page or text-range label", "资料已导入并保留页码或文本范围标签")
        return record
    }

    func startLearningMode(minutes: Int = 5) {
        personaMode = .learning
        personaDurationSeconds = max(60, minutes * 60)
        personaSecondsRemaining = personaDurationSeconds
        personaEndDate = Date.now.addingTimeInterval(TimeInterval(personaDurationSeconds))
        lastPersonaNudgeSecond = personaSecondsRemaining
        personaPrompt = t("Learning mode is on. I’ll stay quiet for the first moment.", "学习模式已开启，我会先保持安静。")
        persistPersonaState()
    }

    func pauseLearningMode() {
        guard personaMode == .learning else { return }
        tickPersona()
        personaMode = .paused
        personaEndDate = nil
        personaPrompt = t("Paused. Nothing is being observed.", "已暂停，目前不会进行观察。")
        persistPersonaState()
    }

    func resumeLearningMode() {
        guard personaMode == .paused else { return }
        personaMode = .learning
        personaEndDate = Date.now.addingTimeInterval(TimeInterval(personaSecondsRemaining))
        lastPersonaNudgeSecond = personaSecondsRemaining
        personaPrompt = t("Back with you. Let’s keep the next step small.", "我回来了。我们把下一步保持得小一点。")
        persistPersonaState()
    }

    func stopLearningMode() {
        personaMode = .stopped
        personaSecondsRemaining = 0
        personaEndDate = nil
        personaPrompt = t("Learning mode stopped. The timer state is saved locally.", "学习模式已停止，计时状态已保存在本地。")
        persistPersonaState()
    }

    func tickPersona() {
        guard personaMode == .learning else { return }
        if let personaEndDate {
            personaSecondsRemaining = max(0, Int(ceil(personaEndDate.timeIntervalSinceNow)))
        } else {
            personaEndDate = Date.now.addingTimeInterval(TimeInterval(personaSecondsRemaining))
        }
        if personaSecondsRemaining > 0,
           personaSecondsRemaining % 45 == 0,
           lastPersonaNudgeSecond != personaSecondsRemaining {
            lastPersonaNudgeSecond = personaSecondsRemaining
            nextPersonaNudge()
        }
        if personaSecondsRemaining == 0 {
            personaMode = .expired
            personaEndDate = nil
            personaPrompt = t("Time’s up. What’s one idea you want to keep?", "时间到了。你最想记住的一个想法是什么？")
        }
        persistPersonaState()
    }

    func nextPersonaNudge() {
        showPersonaNudge(PersonaNudgeKind.allCases.randomElement() ?? .summary)
    }

    func showPersonaNudge(_ kind: PersonaNudgeKind) {
        personaNudgeIndex = kind.rawValue
        guard let plan = activePlan else {
            personaPrompt = t("Start a researched learning goal and I can help you recall its ideas.", "先开始一个真实检索的学习目标，我就可以帮你回忆其中的知识。")
            persistPersonaState()
            return
        }
        switch kind {
        case .summary:
            personaPrompt = String((activeActivity?.explanation ?? plan.summary).prefix(650))
        case .question:
            personaPrompt = activeActivity?.cards.randomElement()?.front ?? activeActivity?.prompt ?? plan.diagnosticQuestion
        case .anotherWay:
            personaPrompt = t("Finding another way to explain this idea…", "正在换一种方式解释这个概念…")
            let goalID = currentGoal?.id
            Task {
                do {
                    let text = try await askActivityQuestion(learningText("Explain this current concept with a different concrete analogy, then state where that analogy breaks.", "请用一个不同的具体类比解释当前概念，并说明类比在哪里失效。"))
                    guard currentGoal?.id == goalID else { return }
                    personaPrompt = text
                    persistPersonaState()
                } catch { personaPrompt = error.localizedDescription }
            }
        }
        persistPersonaState()
    }

    func redeemPersonaStyle(_ style: String, cost: Int) throws {
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        guard profile.rewardBalance >= cost else { throw LumapStoreError.insufficientReward }
        let eventKey = "redeem:persona:\(style)"
        let existing = try context.fetch(FetchDescriptor<RewardEntry>()).contains { $0.eventKey == eventKey }
        do {
            if !existing {
                profile.rewardBalance -= cost
                profile.personaStyle = style
                context.insert(RewardEntry(eventKey: eventKey, delta: -cost, reason: "Unlocked Persona style: \(style)"))
            } else {
                profile.personaStyle = style
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        objectWillChange.send()
    }

    func redeemLearningCredits(credits: Int, cost: Int) throws {
        guard credits > 0, cost > 0 else { return }
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        guard !hasUnlimitedAICredits else { throw LumapStoreError.creditsAlreadyUnlimited }
        guard profile.rewardBalance >= cost else { throw LumapStoreError.insufficientReward }
        do {
            profile.rewardBalance -= cost
            profile.aiCreditBalance += credits
            context.insert(RewardEntry(
                eventKey: "redeem:learning-credit:\(UUID().uuidString)",
                delta: -cost,
                reason: "Exchanged for \(credits) AI learning credits"
            ))
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        objectWillChange.send()
        bannerMessage = t(
            "\(credits) AI learning credits added.",
            "已添加 \(credits) 个 AI 学习额度。"
        )
    }

    /// The only charging boundary model-powered features should call. Demo
    /// accounts bypass charging; metered accounts persist the debit atomically.
    @discardableResult
    func consumeAICredits(_ amount: Int) throws -> AICreditChargeResult {
        guard amount > 0 else { throw LumapStoreError.invalidAICreditAmount }
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        guard !hasUnlimitedAICredits else { return .unlimited }
        guard profile.aiCreditBalance >= amount else { throw LumapStoreError.insufficientAICredits }

        do {
            profile.aiCreditBalance -= amount
            profile.updatedAt = .now
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        objectWillChange.send()
        return .charged(remaining: profile.aiCreditBalance)
    }

    /// Account-management seam for a future entitlement service.
    func updateAICreditPlan(_ plan: AICreditPlan) throws {
        guard let context, let profile else { throw LumapStoreError.notConfigured }
        profile.aiCreditPlanID = plan.rawValue
        profile.updatedAt = .now
        try commit(context)
        objectWillChange.send()
    }

    func saveProvider(endpoint: String, model: String, style: ProviderAPIStyle, apiKey: String) throws {
        let cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let providerURL = URL(string: cleanEndpoint),
              let scheme = providerURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              providerURL.host?.isEmpty == false,
              providerURL.user == nil,
              providerURL.password == nil,
              providerURL.query == nil,
              providerURL.fragment == nil else {
            throw LumapStoreError.invalidProviderEndpoint
        }
        if !cleanKey.isEmpty {
            try LumapKeychainStore.save(cleanKey, account: "active-provider")
        }
        providerEndpoint = cleanEndpoint
        providerModel = cleanModel
        providerStyle = style
        objectWillChange.send()
        providerTestState = "Configured locally · generation not tested"
    }

    func deleteProviderAPIKey() throws {
        try LumapKeychainStore.delete(account: "active-provider")
        objectWillChange.send()
        providerTestState = "API key removed"
    }

    func testProvider() async {
        providerIsTesting = true
        defer { providerIsTesting = false }
        do {
            let key = LumapKeychainStore.read(account: "active-provider") ?? ""
            let configuration = ProviderConfiguration(
                endpoint: providerEndpoint,
                model: providerModel,
                style: providerStyle,
                apiKey: key
            )
            let result = try await LumapAIClient.test(configuration: configuration)
            providerTestState = "Generation verified · \(result)"
        } catch {
            providerTestState = "Configured · generation unavailable · \(error.localizedDescription)"
        }
    }

    func exportSnapshot() throws -> URL {
        guard let context else { throw LumapStoreError.notConfigured }
        let snapshot = LumapExportSnapshot(
            exportedAt: .now,
            profile: profile.map {
                .init(
                    displayName: $0.displayName,
                    ageBand: $0.ageBand,
                    rewardBalance: $0.rewardBalance,
                    aiCreditBalance: $0.aiCreditBalance,
                    aiCreditPlanID: $0.aiCreditPlanID
                )
            },
            goals: try context.fetch(FetchDescriptor<LearningGoal>()).map { .init(topic: $0.originalInput, progress: $0.progress, status: $0.status) },
            activities: try context.fetch(FetchDescriptor<ActivityRecord>()).map { .init(title: $0.title, method: $0.methodID, completedAt: $0.completedAt) }
        )
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Lumap/Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "Lumap-export-\(Int(Date.now.timeIntervalSince1970)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: url, options: .atomic)
        return url
    }

    private func persistPersonaState() {
        defaults.set(personaMode.rawValue, forKey: "lumap.persona.mode")
        defaults.set(personaSecondsRemaining, forKey: "lumap.persona.remaining")
        defaults.set(personaDurationSeconds, forKey: "lumap.persona.duration")
        defaults.set(personaPrompt, forKey: "lumap.persona.prompt")
        if let personaEndDate {
            defaults.set(personaEndDate.timeIntervalSince1970, forKey: "lumap.persona.endDate")
        } else {
            defaults.removeObject(forKey: "lumap.persona.endDate")
        }
    }

    private func commit(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func restorePersonaState() {
        guard let rawMode = defaults.string(forKey: "lumap.persona.mode"),
              let savedMode = PersonaMode(rawValue: rawMode) else { return }
        personaDurationSeconds = defaults.integer(forKey: "lumap.persona.duration")
        personaSecondsRemaining = defaults.integer(forKey: "lumap.persona.remaining")
        personaPrompt = defaults.string(forKey: "lumap.persona.prompt") ?? personaPrompt
        personaMode = savedMode

        if savedMode == .learning {
            let timestamp = defaults.double(forKey: "lumap.persona.endDate")
            guard timestamp > 0 else {
                personaMode = .paused
                persistPersonaState()
                return
            }
            personaEndDate = Date(timeIntervalSince1970: timestamp)
            personaSecondsRemaining = max(0, Int(ceil(personaEndDate?.timeIntervalSinceNow ?? 0)))
            if personaSecondsRemaining == 0 {
                personaMode = .expired
                personaEndDate = nil
                personaPrompt = t("Time’s up. What’s one idea you want to keep?", "时间到了。你最想记住的一个想法是什么？")
            }
        } else {
            personaEndDate = nil
        }
        lastPersonaNudgeSecond = personaSecondsRemaining
    }

    @discardableResult
    func award(delta: Int, reason: String, eventKey: String, context: ModelContext) throws -> Bool {
        guard try !rewardExists(eventKey: eventKey, context: context) else { return false }
        context.insert(RewardEntry(eventKey: eventKey, delta: delta, reason: reason))
        profile?.rewardBalance += delta
        profile?.updatedAt = .now
        return true
    }

    private func rewardExists(eventKey: String, context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<RewardEntry>(
            predicate: #Predicate { entry in entry.eventKey == eventKey }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).isEmpty == false
    }

    private func advance(goal: LearningGoal) {
        let increment = 1 / Double(max(1, goal.totalSteps))
        goal.progress = min(1, goal.progress + increment)
        if goal.progress >= 0.999 {
            goal.progress = 1
            goal.currentStep = goal.totalSteps
            goal.status = "completed"
        } else {
            goal.currentStep = min(goal.totalSteps, Int((goal.progress * Double(goal.totalSteps)).rounded(.down)) + 1)
        }
        goal.updatedAt = .now
    }

    nonisolated private static func parseMaterialFile(at url: URL) throws -> ParsedMaterialImport {
        try validateImportSize(at: url)
        let values = try url.resourceValues(forKeys: [.nameKey])
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            guard let document = PDFDocument(url: url) else { throw LumapStoreError.unreadableFile }
            var parts: [String] = []
            var includedPages: [Int] = []
            var remainingCharacters = 12_000
            for index in 0..<min(document.pageCount, 40) {
                guard remainingCharacters > 0,
                      let raw = document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty else { continue }
                let pageText = String(raw.prefix(remainingCharacters))
                parts.append("[Page \(index + 1)]\n\(pageText)")
                includedPages.append(index + 1)
                remainingCharacters -= pageText.count
            }
            guard let firstPage = includedPages.first, let lastPage = includedPages.last else {
                throw LumapStoreError.unreadableFile
            }
            let citation = firstPage == lastPage
                ? "Page \(firstPage) excerpt"
                : "Pages \(firstPage)–\(lastPage) excerpt"
            return ParsedMaterialImport(
                fileName: values.name ?? url.lastPathComponent,
                fileType: "PDF",
                excerpt: parts.joined(separator: "\n\n"),
                citationLabel: citation
            )
        }

        guard ["txt", "md", "markdown", "csv", "json"].contains(ext) else {
            throw LumapStoreError.unsupportedFile
        }
        let data = try readCappedData(at: url)
        guard let text = String(data: data, encoding: .utf8) else { throw LumapStoreError.unreadableFile }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw LumapStoreError.unreadableFile }
        let excerpt = String(cleaned.prefix(12_000))
        return ParsedMaterialImport(
            fileName: values.name ?? url.lastPathComponent,
            fileType: ext.uppercased(),
            excerpt: excerpt,
            citationLabel: "Imported text · characters 1–\(excerpt.count)"
        )
    }

    nonisolated private static func parseHistoryFile(at url: URL) throws -> ParsedHistoryImport {
        try validateImportSize(at: url)
        let values = try url.resourceValues(forKeys: [.nameKey])
        let data = try readCappedData(at: url)
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw LumapStoreError.unreadableFile
        }

        let ext = url.pathExtension.lowercased()
        var recordCount = 0
        var searchableStrings: [String] = []
        if ext == "json" {
            let object = try JSONSerialization.jsonObject(with: data)
            collectStrings(from: object, into: &searchableStrings)
            recordCount = max(1, largestArrayCount(in: object))
        } else if ext == "csv" {
            let rows = text.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            recordCount = max(0, rows.count - 1)
            for row in rows.prefix(10_001) {
                searchableStrings.append(contentsOf: parseCSVLine(row))
            }
        } else {
            throw LumapStoreError.unsupportedFile
        }

        var domains = Set<String>()
        for value in searchableStrings {
            let candidate = value.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            if let parsed = URL(string: candidate), let host = parsed.host?.lowercased() {
                domains.insert(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
            }
        }
        let lower = searchableStrings.joined(separator: " ").lowercased()
        let topicMap: [(String, String)] = [
            ("github", "Software making"),
            ("wikipedia", "Open-ended research"),
            ("youtube", "Visual explanation"),
            ("coursera", "Structured courses"),
            ("science", "Science and discovery"),
            ("design", "Design practice")
        ]
        return ParsedHistoryImport(
            sourceName: values.name ?? url.lastPathComponent,
            rowCount: recordCount,
            domainCount: domains.count,
            suggestions: topicMap.filter { lower.contains($0.0) }.map(\.1)
        )
    }

    nonisolated private static func validateImportSize(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values.fileSize, size > 25 * 1024 * 1024 {
            throw LumapStoreError.fileTooLarge
        }
    }

    nonisolated private static func readCappedData(at url: URL) throws -> Data {
        let limit = 25 * 1024 * 1024
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw LumapStoreError.fileTooLarge }
        return data
    }

    nonisolated private static func collectStrings(from value: Any, into result: inout [String]) {
        if let string = value as? String {
            result.append(string)
        } else if let array = value as? [Any] {
            for item in array { collectStrings(from: item, into: &result) }
        } else if let dictionary = value as? [String: Any] {
            for (key, item) in dictionary {
                result.append(key)
                collectStrings(from: item, into: &result)
            }
        }
    }

    nonisolated private static func largestArrayCount(in value: Any) -> Int {
        if let array = value as? [Any] {
            return max(array.count, array.map(largestArrayCount).max() ?? 0)
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.values.map(largestArrayCount).max() ?? 0
        }
        return 0
    }

    nonisolated private static func parseCSVLine(_ line: Substring) -> [String] {
        let characters = Array(line)
        var fields: [String] = []
        var field = ""
        var quoted = false
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }
            } else if character == ",", !quoted {
                fields.append(field)
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }
        fields.append(field)
        return fields
    }

    private static func suggestedInterests(for url: URL) -> [String] {
        let source = ((url.host ?? "") + " " + url.path).lowercased()
        if source.contains("youtube") { return ["Visual storytelling", "Independent learning"] }
        if source.contains("github") { return ["Software making", "Open-source projects"] }
        if source.contains("instagram") { return ["Visual culture", "Creative practice"] }
        if source.contains("tiktok") { return ["Short-form explanation", "Popular culture"] }
        if source.contains("linkedin") { return ["Career development", "Professional communication"] }
        return ["Digital creativity", "Curiosity-driven learning"]
    }
}

private struct ParsedMaterialImport: Sendable {
    let fileName: String
    let fileType: String
    let excerpt: String
    let citationLabel: String
}

private struct ParsedHistoryImport: Sendable {
    let sourceName: String
    let rowCount: Int
    let domainCount: Int
    let suggestions: [String]
}

private struct LumapExportSnapshot: Codable {
    struct Profile: Codable {
        let displayName: String
        let ageBand: String
        let rewardBalance: Int
        let aiCreditBalance: Int
        let aiCreditPlanID: String
    }
    struct Goal: Codable { let topic: String; let progress: Double; let status: String }
    struct Activity: Codable { let title: String; let method: String; let completedAt: Date }
    let exportedAt: Date
    let profile: Profile?
    let goals: [Goal]
    let activities: [Activity]
}
