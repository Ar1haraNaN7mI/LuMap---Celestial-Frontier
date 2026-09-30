import Foundation

enum LumapLocalization {
    static func sectionName(_ section: AppSection, language: AppLanguage) -> String {
        let english: String
        let chinese: String
        switch section {
        case .home: (english, chinese) = ("Discover", "探索")
        case .studio: (english, chinese) = ("Learning Studio", "学习空间")
        case .groundedStudy: (english, chinese) = ("Guided Study", "引导学习")
        case .futureLab: (english, chinese) = ("Future Lab", "未来实验室")
        case .assessment: (english, chinese) = ("Check learning", "学习检测")
        case .library: (english, chinese) = ("Library", "资料库")
        case .profile: (english, chinese) = ("Personal", "个人")
        case .progress: (english, chinese) = ("Progress", "学习进度")
        case .rewards: (english, chinese) = ("Rewards", "学习奖励")
        case .persona: (english, chinese) = ("Persona", "桌面伙伴")
        case .settings: (english, chinese) = ("Settings", "设置")
        }
        return language == .english ? english : chinese
    }

    static func methodName(_ method: LearningMethod, language: AppLanguage) -> String {
        let english: String
        let chinese: String
        switch method {
        case .guidedExplanation: (english, chinese) = ("Guided explanation", "引导式讲解")
        case .workedExample: (english, chinese) = ("Worked example", "步骤示例")
        case .socraticDialogue: (english, chinese) = ("Socratic dialogue", "苏格拉底对话")
        case .analogy: (english, chinese) = ("Analogy", "类比学习")
        case .visualMap: (english, chinese) = ("Visual map", "视觉图谱")
        case .story: (english, chinese) = ("Story mode", "故事模式")
        case .flashRecall: (english, chinese) = ("Flash recall", "闪记回忆")
        case .teachBack: (english, chinese) = ("Teach it back", "反向教学")
        case .simulation: (english, chinese) = ("Interactive simulation", "互动模拟")
        case .spatialAR: (english, chinese) = ("Spatial AR lab", "空间 AR 实验")
        case .deliberatePractice: (english, chinese) = ("Deliberate practice", "刻意练习")
        case .reflection: (english, chinese) = ("Reflection", "反思复盘")
        case .misconceptionDiagnosis: (english, chinese) = ("Misconception diagnosis", "误区诊断")
        case .curiosityBranch: (english, chinese) = ("Curiosity branch", "好奇心分岔")
        case .counterfactualLab: (english, chinese) = ("Counterfactual lab", "反事实推演")
        case .transferChallenge: (english, chinese) = ("Transfer challenge", "迁移挑战")
        case .narratedDeck: (english, chinese) = ("Narrated lesson deck", "讲解课件")
        }
        return language == .english ? english : chinese
    }

    static func text(_ english: String, _ chinese: String, language: AppLanguage) -> String {
        language == .english ? english : chinese
    }
}
