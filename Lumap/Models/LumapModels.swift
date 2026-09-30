import Foundation
import SwiftData

enum AppSection: String, CaseIterable, Identifiable {
    case home, studio, groundedStudy, futureLab, assessment, library, profile, progress, rewards, persona, settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "sparkles"
        case .studio: "rectangle.3.group.bubble.left.fill"
        case .groundedStudy: "text.book.closed.fill"
        case .futureLab: "sparkles.rectangle.stack.fill"
        case .assessment: "checkmark.seal.fill"
        case .library: "books.vertical.fill"
        case .profile: "person.crop.circle.fill"
        case .progress: "chart.xyaxis.line"
        case .rewards: "trophy.fill"
        case .persona: "face.smiling.inverse"
        case .settings: "gearshape.fill"
        }
    }
}

enum FutureLabScenario: String, CaseIterable, Identifiable {
    case knowledgeStudio
    case spatialVision
    case adaptivePath
    case learningHandoff
    case interestConstellation

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .knowledgeStudio: "doc.text.magnifyingglass"
        case .spatialVision: "vision.pro"
        case .adaptivePath: "point.3.filled.connected.trianglepath.dotted"
        case .learningHandoff: "rectangle.connected.to.line.below"
        case .interestConstellation: "sparkles"
        }
    }

    func title(language: AppLanguage) -> String {
        let copy: (String, String)
        switch self {
        case .knowledgeStudio: copy = ("Knowledge Studio", "多资料知识空间")
        case .spatialVision: copy = ("Spatial Vision Lab", "空间视觉实验")
        case .adaptivePath: copy = ("Adaptive Path Policy", "自适应路径策略")
        case .learningHandoff: copy = ("Learning Handoff", "跨设备学习接力")
        case .interestConstellation: copy = ("Interest Constellation", "兴趣星图")
        }
        return language == .english ? copy.0 : copy.1
    }

    func subtitle(language: AppLanguage) -> String {
        let copy: (String, String)
        switch self {
        case .knowledgeStudio:
            copy = ("Ask across sources and inspect every citation.", "跨资料提问，并检查每一条引用。")
        case .spatialVision:
            copy = ("Place and manipulate a simulated learning object.", "放置并操作模拟的空间学习对象。")
        case .adaptivePath:
            copy = ("See a demo policy change the next learning step.", "观察演示策略如何改变下一学习步骤。")
        case .learningHandoff:
            copy = ("Move one lesson across phone, Mac and spatial display.", "让同一课程在手机、Mac 与空间显示间接力。")
        case .interestConstellation:
            copy = ("Turn synthetic signals into an editable interest map.", "把合成信号变成可编辑的兴趣地图。")
        }
        return language == .english ? copy.0 : copy.1
    }
}

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
}

enum LearningMethod: String, CaseIterable, Codable, Identifiable {
    case guidedExplanation
    case workedExample
    case socraticDialogue
    case analogy
    case visualMap
    case story
    case flashRecall
    case teachBack
    case simulation
    case spatialAR
    case deliberatePractice
    case reflection
    case misconceptionDiagnosis
    case curiosityBranch
    case counterfactualLab
    case transferChallenge
    case narratedDeck

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .guidedExplanation: "text.book.closed.fill"
        case .workedExample: "list.number"
        case .socraticDialogue: "questionmark.bubble.fill"
        case .analogy: "arrow.triangle.branch"
        case .visualMap: "point.3.connected.trianglepath.dotted"
        case .story: "theatermasks.fill"
        case .flashRecall: "bolt.fill"
        case .teachBack: "person.wave.2.fill"
        case .simulation: "slider.horizontal.3"
        case .spatialAR: "arkit"
        case .deliberatePractice: "scope"
        case .reflection: "brain.head.profile.fill"
        case .misconceptionDiagnosis: "exclamationmark.triangle.fill"
        case .curiosityBranch: "point.3.connected.trianglepath.dotted"
        case .counterfactualLab: "arrow.uturn.backward.circle.fill"
        case .transferChallenge: "arrow.up.right.square.fill"
        case .narratedDeck: "rectangle.on.rectangle.angled"
        }
    }

}

enum AICreditPlan: String, Codable, CaseIterable, Identifiable {
    case demoUnlimited
    case metered

    var id: String { rawValue }
}

enum AssessmentKind: String, Codable, CaseIterable, Identifiable {
    case theoretical
    case practical
    var id: String { rawValue }
}

@Model
final class LearnerProfile {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var ageBand: String
    var background: String
    var availableMinutes: Int
    var interfaceLanguage: String
    var learningLanguage: String
    var rewardBalance: Int
    var aiCreditBalance: Int = 0
    var aiCreditPlanID: String = AICreditPlan.demoUnlimited.rawValue
    var personaStyle: String
    var reducedMotion: Bool
    var largeText: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String = "Learner",
        ageBand: String = "Unknown",
        background: String = "",
        availableMinutes: Int = 20,
        interfaceLanguage: String = AppLanguage.english.rawValue,
        learningLanguage: String = AppLanguage.english.rawValue,
        rewardBalance: Int = 0,
        aiCreditBalance: Int = 0,
        aiCreditPlan: AICreditPlan = .demoUnlimited,
        personaStyle: String = "Aurora",
        reducedMotion: Bool = false,
        largeText: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.ageBand = ageBand
        self.background = background
        self.availableMinutes = availableMinutes
        self.interfaceLanguage = interfaceLanguage
        self.learningLanguage = learningLanguage
        self.rewardBalance = rewardBalance
        self.aiCreditBalance = aiCreditBalance
        self.aiCreditPlanID = aiCreditPlan.rawValue
        self.personaStyle = personaStyle
        self.reducedMotion = reducedMotion
        self.largeText = largeText
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class SourceRecord {
    @Attribute(.unique) var id: UUID
    var kind: String
    var canonicalURL: String
    var displayName: String
    var status: String
    var coverageNote: String
    var isDemo: Bool
    var createdAt: Date

    init(kind: String, canonicalURL: String, displayName: String, status: String, coverageNote: String, isDemo: Bool) {
        self.id = UUID()
        self.kind = kind
        self.canonicalURL = canonicalURL
        self.displayName = displayName
        self.status = status
        self.coverageNote = coverageNote
        self.isDemo = isDemo
        self.createdAt = .now
    }
}

@Model
final class InterestEvidence {
    @Attribute(.unique) var id: UUID
    var topic: String
    var sourceLabel: String
    var explanation: String
    var strength: Double
    var status: String
    var createdAt: Date

    init(topic: String, sourceLabel: String, explanation: String, strength: Double = 0.7, status: String = "suggested") {
        self.id = UUID()
        self.topic = topic
        self.sourceLabel = sourceLabel
        self.explanation = explanation
        self.strength = strength
        self.status = status
        self.createdAt = .now
    }
}

@Model
final class LearningGoal {
    @Attribute(.unique) var id: UUID
    var originalInput: String
    var createdAt: Date
    var updatedAt: Date
    var progress: Double
    var currentStep: Int
    var totalSteps: Int
    var status: String
    var preferredMethodID: String
    var weakAspect: String
    var materialID: UUID?
    // Optional storage preserves existing installations during lightweight migration.
    var agentPlanData: Data? = nil
    var agentSessionData: Data? = nil
    var agentNodeID: String = ""
    var agentLanguageCode: String = ""

    init(originalInput: String, preferredMethodID: String = LearningMethod.guidedExplanation.rawValue, materialID: UUID? = nil) {
        self.id = UUID()
        self.originalInput = originalInput
        self.createdAt = .now
        self.updatedAt = .now
        self.progress = 0
        self.currentStep = 1
        self.totalSteps = 5
        self.status = "active"
        self.preferredMethodID = preferredMethodID
        self.weakAspect = "Connecting ideas to a new situation"
        self.materialID = materialID
    }
}

@Model
final class ActivityRecord {
    @Attribute(.unique) var id: UUID
    var goalID: UUID
    var methodID: String
    var title: String
    var artifactText: String
    var assistance: String
    var completedAt: Date
    var rewardEventKey: String

    init(goalID: UUID, methodID: String, title: String, artifactText: String, assistance: String = "none", rewardEventKey: String) {
        self.id = UUID()
        self.goalID = goalID
        self.methodID = methodID
        self.title = title
        self.artifactText = artifactText
        self.assistance = assistance
        self.completedAt = .now
        self.rewardEventKey = rewardEventKey
    }
}

@Model
final class AssessmentRecord {
    @Attribute(.unique) var id: UUID
    var goalID: UUID?
    var kind: String
    var status: String
    var score: Int?
    var feedback: String
    var evidenceSummary: String
    var createdAt: Date

    init(goalID: UUID?, kind: AssessmentKind, status: String, score: Int?, feedback: String, evidenceSummary: String) {
        self.id = UUID()
        self.goalID = goalID
        self.kind = kind.rawValue
        self.status = status
        self.score = score
        self.feedback = feedback
        self.evidenceSummary = evidenceSummary
        self.createdAt = .now
    }
}

@Model
final class RewardEntry {
    @Attribute(.unique) var eventKey: String
    var delta: Int
    var reason: String
    var createdAt: Date

    init(eventKey: String, delta: Int, reason: String) {
        self.eventKey = eventKey
        self.delta = delta
        self.reason = reason
        self.createdAt = .now
    }
}

@Model
final class MaterialRecord {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var fileType: String
    var excerpt: String
    var citationLabel: String
    var status: String
    var importedAt: Date

    init(fileName: String, fileType: String, excerpt: String, citationLabel: String, status: String = "ready") {
        self.id = UUID()
        self.fileName = fileName
        self.fileType = fileType
        self.excerpt = excerpt
        self.citationLabel = citationLabel
        self.status = status
        self.importedAt = .now
    }
}

@Model
final class AppHealthRecord {
    @Attribute(.unique) var id: UUID
    var lastVerifiedAt: Date
    var verificationCount: Int

    init(id: UUID = UUID()) {
        self.id = id
        self.lastVerifiedAt = .now
        self.verificationCount = 1
    }
}

struct Recommendation: Identifiable, Hashable {
    let id: String
    let title: String
    let reason: String
    let icon: String
    let tint: String
}

struct ModuleCopy {
    let eyebrow: String
    let title: String
    let body: String
    let prompt: String
}
