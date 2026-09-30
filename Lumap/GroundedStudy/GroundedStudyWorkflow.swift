import Foundation

enum GroundedStudyStage: String, CaseIterable, Codable, Identifiable {
    case understand
    case question
    case retrieve
    case teachBack

    var id: String { rawValue }

    var method: LearningMethod {
        switch self {
        case .understand: .guidedExplanation
        case .question: .socraticDialogue
        case .retrieve: .flashRecall
        case .teachBack: .teachBack
        }
    }

    var icon: String {
        switch self {
        case .understand: "doc.text.magnifyingglass"
        case .question: "questionmark.bubble.fill"
        case .retrieve: "bolt.fill"
        case .teachBack: "person.wave.2.fill"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .understand:
            LumapLocalization.text("Understand", "理解资料", language: language)
        case .question:
            LumapLocalization.text("Question", "追问假设", language: language)
        case .retrieve:
            LumapLocalization.text("Retrieve", "主动回忆", language: language)
        case .teachBack:
            LumapLocalization.text("Teach back", "讲解复盘", language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .understand:
            LumapLocalization.text("Find the claim and its support", "找出主张与支持证据", language: language)
        case .question:
            LumapLocalization.text("Test an assumption with evidence", "用证据检验一个假设", language: language)
        case .retrieve:
            LumapLocalization.text("Recall first, then check the source", "先回忆，再核对资料", language: language)
        case .teachBack:
            LumapLocalization.text("Explain, cite and name uncertainty", "讲清、引用并标出不确定性", language: language)
        }
    }
}

struct GroundedStudySnapshot: Equatable {
    let completedStages: Set<GroundedStudyStage>

    var currentStage: GroundedStudyStage? {
        GroundedStudyStage.allCases.first { !completedStages.contains($0) }
    }

    var nextStage: GroundedStudyStage? {
        guard let currentStage,
              let index = GroundedStudyStage.allCases.firstIndex(of: currentStage),
              index + 1 < GroundedStudyStage.allCases.count else { return nil }
        return GroundedStudyStage.allCases[index + 1]
    }

    var progress: Double {
        Double(completedStages.count) / Double(GroundedStudyStage.allCases.count)
    }

    var isComplete: Bool { currentStage == nil }
}

enum GroundedStudyWorkflow {
    static let assistancePrefix = "groundedStudy:"

    static func assistanceID(for stage: GroundedStudyStage) -> String {
        assistancePrefix + stage.rawValue
    }

    static func stage(fromAssistance value: String) -> GroundedStudyStage? {
        guard value.hasPrefix(assistancePrefix) else { return nil }
        return GroundedStudyStage(rawValue: String(value.dropFirst(assistancePrefix.count)))
    }

    static func snapshot(completedStageIDs: [String]) -> GroundedStudySnapshot {
        let stages = Set(completedStageIDs.compactMap(GroundedStudyStage.init(rawValue:)))
        return GroundedStudySnapshot(completedStages: stages)
    }

    static func sourceCue(from excerpt: String?, fallbackTopic: String) -> String {
        let cleaned = excerpt?
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cleaned.isEmpty else { return fallbackTopic }

        let firstSentence = cleaned.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { ".!?。！？".contains($0) }
        ).first.map(String.init) ?? cleaned
        return String(firstSentence.prefix(220))
    }

    static func prompt(
        for stage: GroundedStudyStage,
        topic: String,
        sourceCue: String,
        language: AppLanguage
    ) -> String {
        switch stage {
        case .understand:
            return LumapLocalization.text(
                "Using the source cue below, state the central claim, two supporting details and one point the source leaves uncertain.\n\nSource cue: \(sourceCue)",
                "只依据下面的资料线索，写出核心主张、两条支持细节，以及资料仍未说明的一点。\n\n资料线索：\(sourceCue)",
                language: language
            )
        case .question:
            return LumapLocalization.text(
                "What assumption connects the source to your current understanding of \(topic)? Ask one question that could disprove it, then cite the phrase that led you there.\n\nSource cue: \(sourceCue)",
                "资料与当前对 \(topic) 的理解之间依赖了什么假设？提出一个可能推翻该假设的问题，并引用触发这个问题的原文。\n\n资料线索：\(sourceCue)",
                language: language
            )
        case .retrieve:
            return LumapLocalization.text(
                "Hide the source. Recall three claims from memory. Reopen it, mark each claim Supported or Corrected, and quote the evidence for one correction.",
                "先隐藏资料，凭记忆写出三条观点。重新打开资料后，为每条标注“有支持”或“需修正”，并为一处修正引用证据。",
                language: language
            )
        case .teachBack:
            return LumapLocalization.text(
                "Teach \(topic) to a first-time learner in four sentences: the idea, why it works, one source-backed example, and one uncertainty you would investigate next.",
                "用四句话把 \(topic) 教给第一次接触它的人：核心概念、作用原因、一个有资料依据的例子，以及下一步要查证的不确定点。",
                language: language
            )
        }
    }

    static func evidenceArtifact(
        stage: GroundedStudyStage,
        topic: String,
        sourceLabel: String,
        sourceCue: String,
        response: String,
        language: AppLanguage
    ) -> String {
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let stageTitle = stage.title(language: language)
        return [
            "Guided Study evidence",
            "Stage: \(stageTitle)",
            "Method: \(stage.method.rawValue)",
            "Topic: \(topic)",
            "Source: \(sourceLabel)",
            "Source cue: \(sourceCue)",
            "Learner response: \(cleanResponse)"
        ].joined(separator: "\n")
    }
}
