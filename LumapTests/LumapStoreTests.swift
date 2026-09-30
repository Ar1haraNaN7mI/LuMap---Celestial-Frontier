import SwiftData
import XCTest
@testable import Lumap

final class LumapStoreTests: XCTestCase {
    @MainActor
    private func makeStore() throws -> (LumapStore, ModelContext) {
        let schema = Schema([
            LearnerProfile.self,
            SourceRecord.self,
            InterestEvidence.self,
            LearningGoal.self,
            ActivityRecord.self,
            AssessmentRecord.self,
            RewardEntry.self,
            MaterialRecord.self,
            AppHealthRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        let store = LumapStore()
        store.configure(context: context)
        return (store, context)
    }

    @MainActor
    func testEnglishIsDefaultAndTopicIsPreserved() throws {
        let (store, _) = try makeStore()
        XCTAssertEqual(store.language, .english)

        try store.startLearning(topic: "  Hand-cut dovetail joints  ")

        XCTAssertEqual(store.currentGoal?.originalInput, "Hand-cut dovetail joints")
        XCTAssertEqual(store.selectedSection, .studio)
    }

    @MainActor
    func testCompletingSameMethodDoesNotDuplicateReward() throws {
        let (store, context) = try makeStore()
        try store.startLearning(topic: "Feedback loops")

        XCTAssertTrue(try store.completeActivity(method: .guidedExplanation, artifact: "A loop returns part of its output as input."))
        XCTAssertFalse(try store.completeActivity(method: .guidedExplanation, artifact: "Duplicate"))

        let entries = try context.fetch(FetchDescriptor<RewardEntry>())
        XCTAssertEqual(entries.filter { $0.delta == 10 }.count, 1)
        XCTAssertEqual(store.rewardBalance, 10)
    }

    @MainActor
    func testSkippingAssessmentKeepsGoalActiveAndMissingScore() throws {
        let (store, context) = try makeStore()
        try store.startLearning(topic: "Climate systems")

        try store.skipAssessment(kind: .theoretical)

        XCTAssertEqual(store.currentGoal?.status, "active")
        let attempts = try context.fetch(FetchDescriptor<AssessmentRecord>())
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts[0].status, "skipped")
        XCTAssertNil(attempts[0].score)
    }

    @MainActor
    func testRecommendationsReactToConfirmedInterest() throws {
        let (store, _) = try makeStore()
        let interest = InterestEvidence(topic: "Robotics", sourceLabel: "Example", explanation: "Confirmed", status: "confirmed")

        let results = store.recommendations(interests: [interest])

        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results.first?.title, "Explore Robotics")
    }

    @MainActor
    func testAssessmentRequiresActiveGoal() throws {
        let (store, _) = try makeStore()

        XCTAssertThrowsError(try store.submitTheory(answer: "A complete explanation because it includes an example and reasoning.")) { error in
            guard case LumapStoreError.noActiveGoal = error else {
                return XCTFail("Expected noActiveGoal, received \(error)")
            }
        }
        XCTAssertEqual(store.rewardBalance, 0)
    }

    @MainActor
    func testFiveDistinctEvidenceEventsCompleteLearningMap() throws {
        let (store, _) = try makeStore()
        try store.startLearning(topic: "Feedback loops")

        XCTAssertTrue(try store.completeActivity(method: .guidedExplanation, artifact: "Map the system."))
        XCTAssertTrue(try store.completeActivity(method: .simulation, artifact: "Change one variable."))
        XCTAssertTrue(try store.completeActivity(method: .teachBack, artifact: "Explain the causal link."))
        _ = try store.submitTheory(answer: "A feedback loop matters because an output returns as an input. For example, melting ice can increase heat absorption and amplify warming.")
        _ = try store.submitPractical(
            prediction: "The output will increase.",
            observation: "The model output increased.",
            adjustment: "I would test a smaller input next."
        )

        XCTAssertEqual(store.currentGoal?.progress, 1)
        XCTAssertEqual(store.currentGoal?.currentStep, 5)
        XCTAssertEqual(store.currentGoal?.status, "completed")
        XCTAssertEqual(store.rewardBalance, 60)
    }

    @MainActor
    func testMaterialBindingAndTeachingLanguagePersistOnGoal() throws {
        let (store, _) = try makeStore()
        let materialID = UUID()
        try store.updateLearningLanguage(.simplifiedChinese)
        try store.startLearning(topic: "Climate feedback", materialID: materialID)

        XCTAssertEqual(store.currentGoal?.materialID, materialID)
        XCTAssertEqual(store.learningLanguage, .simplifiedChinese)
        XCTAssertEqual(store.moduleCopy(for: .guidedExplanation).title, "Climate feedback")
        XCTAssertEqual(store.moduleCopy(for: .guidedExplanation).eyebrow, "正在编排课程")
    }

    @MainActor
    func testGroundedStudyWorkflowAdvancesInEvidenceOrder() throws {
        let empty = GroundedStudyWorkflow.snapshot(completedStageIDs: [])
        XCTAssertEqual(empty.currentStage, .understand)
        XCTAssertEqual(empty.progress, 0)

        let midway = GroundedStudyWorkflow.snapshot(completedStageIDs: [
            GroundedStudyStage.understand.rawValue,
            GroundedStudyStage.question.rawValue
        ])
        XCTAssertEqual(midway.currentStage, .retrieve)
        XCTAssertEqual(midway.nextStage, .teachBack)
        XCTAssertEqual(midway.progress, 0.5, accuracy: 0.001)

        let complete = GroundedStudyWorkflow.snapshot(
            completedStageIDs: GroundedStudyStage.allCases.map(\.rawValue)
        )
        XCTAssertTrue(complete.isComplete)
        XCTAssertNil(complete.currentStage)
        XCTAssertEqual(complete.progress, 1)
    }

    @MainActor
    func testGroundedStudyPersistsCitationAndRejectsOutOfOrderStage() throws {
        let (store, context) = try makeStore()
        let material = MaterialRecord(
            fileName: "feedback-notes.txt",
            fileType: "TXT",
            excerpt: "A thermostat compares measured temperature with a target. The difference changes the heater output.",
            citationLabel: "Text characters 1–112"
        )
        context.insert(material)
        try context.save()

        try store.startGroundedStudy(from: material)
        XCTAssertEqual(store.selectedSection, .groundedStudy)
        XCTAssertEqual(store.currentGoal?.materialID, material.id)

        XCTAssertThrowsError(try store.completeGroundedStudyStage(
            .retrieve,
            response: "An early answer",
            sourceLabel: material.citationLabel,
            sourceCue: material.excerpt
        )) { error in
            guard case LumapStoreError.groundedStageUnavailable = error else {
                return XCTFail("Expected groundedStageUnavailable, received \(error)")
            }
        }

        XCTAssertTrue(try store.completeGroundedStudyStage(
            .understand,
            response: "The thermostat compares a measurement and target, then uses the difference to change output.",
            sourceLabel: "\(material.fileName) · \(material.citationLabel)",
            sourceCue: GroundedStudyWorkflow.sourceCue(from: material.excerpt, fallbackTopic: "Thermostats")
        ))
        XCTAssertFalse(try store.completeGroundedStudyStage(
            .understand,
            response: "Duplicate response",
            sourceLabel: material.citationLabel,
            sourceCue: material.excerpt
        ))

        let records = try context.fetch(FetchDescriptor<ActivityRecord>())
        let grounded = try XCTUnwrap(records.first { $0.assistance == "groundedStudy:understand" })
        XCTAssertEqual(grounded.methodID, LearningMethod.guidedExplanation.rawValue)
        XCTAssertTrue(grounded.artifactText.contains("feedback-notes.txt"))
        XCTAssertTrue(grounded.artifactText.contains("Text characters 1–112"))
        XCTAssertEqual(store.rewardBalance, 10)
        XCTAssertEqual(try XCTUnwrap(store.currentGoal).progress, 0.2, accuracy: 0.001)
    }

    @MainActor
    func testGroundedStudyCompletesFourDistinctReusableMethods() throws {
        let (store, context) = try makeStore()
        try store.startLearning(topic: "Source evaluation")

        for stage in GroundedStudyStage.allCases {
            XCTAssertTrue(try store.completeGroundedStudyStage(
                stage,
                response: "Evidence response for \(stage.rawValue)",
                sourceLabel: "Learner-stated goal",
                sourceCue: "Source evaluation"
            ))
        }

        let grounded = try context.fetch(FetchDescriptor<ActivityRecord>())
            .filter { $0.assistance.hasPrefix(GroundedStudyWorkflow.assistancePrefix) }
        XCTAssertEqual(grounded.count, 4)
        XCTAssertEqual(Set(grounded.map(\.methodID)), Set([
            LearningMethod.guidedExplanation.rawValue,
            LearningMethod.socraticDialogue.rawValue,
            LearningMethod.flashRecall.rawValue,
            LearningMethod.teachBack.rawValue
        ]))
        XCTAssertEqual(try XCTUnwrap(store.currentGoal).progress, 0.8, accuracy: 0.001)
        XCTAssertEqual(store.rewardBalance, 40)
    }

    @MainActor
    func testGroundedStudyCanFinishAfterGoalProgressReachesOne() throws {
        let (store, context) = try makeStore()
        try store.startLearning(topic: "Feedback systems")
        XCTAssertTrue(try store.completeActivity(method: .simulation, artifact: "Compare two system states."))
        XCTAssertTrue(try store.completeActivity(method: .counterfactualLab, artifact: "Remove one causal link."))

        for stage in GroundedStudyStage.allCases {
            XCTAssertTrue(try store.completeGroundedStudyStage(
                stage,
                response: "Cited response for \(stage.rawValue)",
                sourceLabel: "Learner-stated goal",
                sourceCue: "Feedback systems"
            ))
        }

        let grounded = try context.fetch(FetchDescriptor<ActivityRecord>())
            .filter { $0.assistance.hasPrefix(GroundedStudyWorkflow.assistancePrefix) }
        XCTAssertEqual(grounded.count, 4)
        XCTAssertEqual(try XCTUnwrap(store.currentGoal).progress, 1, accuracy: 0.001)
        XCTAssertEqual(store.currentGoal?.status, "completed")
        XCTAssertEqual(store.rewardBalance, 60)
    }

    @MainActor
    func testCompletedGoalStaysCompletedWhenStartingOrResumingAnotherGoal() throws {
        let (store, _) = try makeStore()
        try store.startLearning(topic: "First map")
        let firstGoal = try XCTUnwrap(store.currentGoal)
        try store.startLearning(topic: "Second map")
        let completedGoal = try XCTUnwrap(store.currentGoal)

        XCTAssertTrue(try store.completeActivity(method: .guidedExplanation, artifact: "Map the system."))
        XCTAssertTrue(try store.completeActivity(method: .simulation, artifact: "Change one variable."))
        XCTAssertTrue(try store.completeActivity(method: .teachBack, artifact: "Explain the causal link."))
        _ = try store.submitTheory(answer: "The idea works because output returns as input. For example, one change can amplify another.")
        _ = try store.submitPractical(
            prediction: "The output will increase.",
            observation: "The model output increased.",
            adjustment: "I would test a smaller input next."
        )

        XCTAssertEqual(completedGoal.status, "completed")
        try store.resumeGoal(firstGoal)
        XCTAssertEqual(completedGoal.status, "completed")
        try store.startLearning(topic: "Third map")
        XCTAssertEqual(completedGoal.status, "completed")
    }

    @MainActor
    func testEmptyActivityArtifactIsRejected() throws {
        let (store, context) = try makeStore()
        try store.startLearning(topic: "Evidence")

        XCTAssertThrowsError(try store.completeActivity(method: .guidedExplanation, artifact: "   ")) { error in
            guard case LumapStoreError.invalidArtifact = error else {
                return XCTFail("Expected invalidArtifact, received \(error)")
            }
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<ActivityRecord>()).isEmpty)
        XCTAssertEqual(store.rewardBalance, 0)
        XCTAssertEqual(store.currentGoal?.progress, 0)
    }

    @MainActor
    func testLumensCanBeExchangedForAILearningCredits() throws {
        let (store, context) = try makeStore()
        try store.updateAICreditPlan(.metered)
        try store.startLearning(topic: "Reward economics")
        XCTAssertTrue(try store.completeActivity(method: .guidedExplanation, artifact: "Map the system."))
        XCTAssertTrue(try store.completeActivity(method: .simulation, artifact: "Change one variable."))
        XCTAssertEqual(store.rewardBalance, 20)

        try store.redeemLearningCredits(credits: 100, cost: 20)

        XCTAssertEqual(store.rewardBalance, 0)
        XCTAssertEqual(store.aiCreditBalance, 100)
        let entries = try context.fetch(FetchDescriptor<RewardEntry>())
        XCTAssertEqual(entries.filter { $0.delta == -20 }.count, 1)
    }

    @MainActor
    func testDemoAccountHasUnlimitedAICreditsWithoutChangingMeteredBalance() throws {
        let (store, _) = try makeStore()

        XCTAssertEqual(store.aiCreditPlan, .demoUnlimited)
        XCTAssertTrue(store.hasUnlimitedAICredits)
        XCTAssertEqual(try store.consumeAICredits(250), .unlimited)
        XCTAssertEqual(store.aiCreditBalance, 0)
        XCTAssertThrowsError(try store.redeemLearningCredits(credits: 100, cost: 20)) { error in
            guard case LumapStoreError.creditsAlreadyUnlimited = error else {
                return XCTFail("Expected creditsAlreadyUnlimited, received \(error)")
            }
        }
    }

    @MainActor
    func testMeteredAICreditPlanChargesAtomicallyAndRejectsOverdraft() throws {
        let (store, _) = try makeStore()
        try store.updateAICreditPlan(.metered)
        store.profile?.aiCreditBalance = 120

        XCTAssertEqual(try store.consumeAICredits(35), .charged(remaining: 85))
        XCTAssertEqual(store.aiCreditBalance, 85)
        XCTAssertThrowsError(try store.consumeAICredits(86)) { error in
            guard case LumapStoreError.insufficientAICredits = error else {
                return XCTFail("Expected insufficientAICredits, received \(error)")
            }
        }
        XCTAssertEqual(store.aiCreditBalance, 85)
    }

    @MainActor
    func testFourHeuristicMethodsHaveCopyAndPersistDistinctEvidence() throws {
        let (store, context) = try makeStore()
        try store.startLearning(topic: "Feedback loops")
        let methods: [LearningMethod] = [
            .misconceptionDiagnosis,
            .curiosityBranch,
            .counterfactualLab,
            .transferChallenge
        ]

        XCTAssertEqual(LearningMethod.allCases.count, 17)
        for method in methods {
            let copy = store.moduleCopy(for: method)
            XCTAssertFalse(copy.title.isEmpty)
            XCTAssertTrue(copy.prompt.isEmpty, "No fabricated task should appear before the model returns a validated activity.")
            XCTAssertTrue(try store.completeActivity(method: method, artifact: "Evidence captured for \(method.rawValue)."))
        }

        let records = try context.fetch(FetchDescriptor<ActivityRecord>())
        XCTAssertEqual(Set(records.map(\.methodID)), Set(methods.map(\.rawValue)))
        XCTAssertEqual(store.rewardBalance, 40)
    }

    @MainActor
    func testNarratedDeckContractGeneratesGroundedSlidesAndPersistsSessionEvidence() async throws {
        let response = try await LocalNarratedDeckGenerator().generate(.init(
            topic: "Feedback loops",
            sourceMaterial: "A thermostat compares the measured temperature with a target before changing the heater.",
            sourceLabel: "thermostat-notes.txt",
            languageCode: AppLanguage.english.rawValue,
            maximumSlideCount: 5
        ))

        XCTAssertEqual(response.schemaVersion, NarratedDeckGenerationResponse.currentSchemaVersion)
        XCTAssertEqual(response.providerID, "lumap.local-deterministic")
        XCTAssertEqual(response.deck.slides.count, 5)
        XCTAssertEqual(response.deck.slides.compactMap(\.quiz).count, 2)
        XCTAssertTrue(response.deck.slides.flatMap(\.bullets).contains { $0.contains("thermostat") })

        let firstQuiz = try XCTUnwrap(response.deck.slides.compactMap(\.quiz).first)
        let artifact = NarratedDeckSessionArtifact(
            deckTitle: response.deck.title,
            slideSummaries: response.deck.slides.map(\.summary),
            narratedSlideNumbers: [1, 2],
            narrationStatus: .silentPreview,
            quizResults: [
                .init(quizID: firstQuiz.id, selectedOptionID: firstQuiz.correctOptionID, wasCorrect: true)
            ]
        ).activityText(languageCode: AppLanguage.english.rawValue)

        XCTAssertTrue(artifact.contains("Slide summaries"))
        XCTAssertTrue(artifact.contains("Narration: silentPreview"))
        XCTAssertTrue(artifact.contains("Quiz: 1/1 correct"))

        let (store, context) = try makeStore()
        try store.startLearning(topic: "Feedback loops")
        XCTAssertTrue(try store.completeActivity(method: .narratedDeck, artifact: artifact))
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<ActivityRecord>()).first)
        XCTAssertEqual(record.methodID, LearningMethod.narratedDeck.rawValue)
        XCTAssertTrue(record.artifactText.contains(response.deck.slides[0].title))
        XCTAssertTrue(record.artifactText.contains("Narration: silentPreview"))
    }

    @MainActor
    func testResponsesEndpointResolutionAcceptsBaseAndFullRoute() throws {
        let baseConfiguration = ProviderConfiguration(
            endpoint: "https://api.ikuncode.cc/v1",
            model: "gpt-5.6-sol",
            style: .openAIResponses,
            apiKey: "fixture-token"
        )
        XCTAssertEqual(
            try LumapAIClient.resolvedEndpoint(for: baseConfiguration).absoluteString,
            "https://api.ikuncode.cc/v1/responses"
        )

        let fullConfiguration = ProviderConfiguration(
            endpoint: "https://api.ikuncode.cc/v1/responses",
            model: "gpt-5.6-sol",
            style: .openAIResponses,
            apiKey: "fixture-token"
        )
        XCTAssertEqual(
            try LumapAIClient.resolvedEndpoint(for: fullConfiguration).absoluteString,
            "https://api.ikuncode.cc/v1/responses"
        )

        let endpointWithQuery = ProviderConfiguration(
            endpoint: "https://api.ikuncode.cc/v1?scope=fixture",
            model: "gpt-5.6-sol",
            style: .openAIResponses,
            apiKey: "fixture-token"
        )
        XCTAssertThrowsError(try LumapAIClient.resolvedEndpoint(for: endpointWithQuery))

        let (store, _) = try makeStore()
        XCTAssertThrowsError(
            try store.saveProvider(
                endpoint: endpointWithQuery.endpoint,
                model: endpointWithQuery.model,
                style: endpointWithQuery.style,
                apiKey: ""
            )
        )
    }

    @MainActor
    func testResponsesRequestKeepsExactModelAndAddsLumapUserAgent() throws {
        let request = try LumapAIClient.makeRequest(
            configuration: .init(
                endpoint: "https://api.ikuncode.cc/v1",
                model: "gpt-5.6-sol",
                style: .openAIResponses,
                apiKey: "fixture-token"
            ),
            prompt: "Build a test lesson",
            instructions: "Return concise JSON.",
            maxOutputTokens: 320
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.ikuncode.cc/v1/responses")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), LumapAIClient.userAgent)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["model"] as? String, "gpt-5.6-sol")
        XCTAssertEqual(object["input"] as? String, "Build a test lesson")
        XCTAssertEqual(object["max_output_tokens"] as? Int, 320)
    }

    @MainActor
    func testResponsesParserSupportsConvenienceAndNestedOutputShapes() throws {
        let convenience = Data(#"{"output_text":"Lumap connected"}"#.utf8)
        XCTAssertEqual(
            try LumapAIClient.parseGeneratedText(from: convenience, style: .openAIResponses),
            "Lumap connected"
        )

        let nested = Data(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"first"},{"type":"output_text","text":"second"}]}]}"#.utf8)
        XCTAssertEqual(
            try LumapAIClient.parseGeneratedText(from: nested, style: .openAIResponses),
            "first\nsecond"
        )
    }

    @MainActor
    func testRemoteDeckParserValidatesContractAndUsesConfiguredModelIdentity() async throws {
        let local = try await LocalNarratedDeckGenerator().generate(.init(
            topic: "Feedback loops",
            languageCode: AppLanguage.english.rawValue,
            maximumSlideCount: 5
        ))
        let spoofed = NarratedDeckGenerationResponse(
            providerID: local.providerID,
            modelID: local.modelID,
            generatedAt: local.generatedAt,
            deck: .init(
                id: local.deck.id,
                title: local.deck.title,
                subtitle: local.deck.subtitle,
                sourceLabel: "model-invented.pdf",
                slides: local.deck.slides
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let fixture = try XCTUnwrap(String(data: encoder.encode(spoofed), encoding: .utf8))

        let parsed = try RemoteNarratedDeckGenerator.decodeAndValidate(
            "```json\n\(fixture)\n```",
            expectedMaximumSlideCount: 5,
            configuredModelID: "gpt-5.6-sol",
            trustedSourceLabel: "trusted-notes.txt"
        )

        XCTAssertEqual(parsed.providerID, "lumap.remote-provider")
        XCTAssertEqual(parsed.modelID, "gpt-5.6-sol")
        XCTAssertEqual(parsed.deck.sourceLabel, "trusted-notes.txt")
        XCTAssertEqual(parsed.deck.slides.count, 5)
    }
}
