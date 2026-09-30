import Foundation
import XCTest
@testable import Lumap

/// HTTP fixtures verify orchestration and schema boundaries without spending model
/// tokens. A separate live smoke run exercises real research and provider output.
final class LearningAgentServiceTests: XCTestCase {
    @MainActor
    func testResearchRejectsLocalCredentialAndNonWebURLs() {
        let denied = ["http://127.0.0.1/a", "https://192.168.0.1", "https://10.1.1.1", "https://[::1]", "https://example.local", "https://example.internal", "https://user:pass@example.com", "file:///etc/passwd", "https://example.com:8080/"]
        for raw in denied { XCTAssertFalse(LearningResearchService.isAllowedPublicURL(URL(string: raw)!), raw) }
        XCTAssertTrue(LearningResearchService.isAllowedPublicURL(URL(string: "https://en.wikipedia.org/wiki/Photosynthesis")!))
        XCTAssertEqual(LearningResearchService.normalizedQuery("  想学光合作用  "), "光合作用")
        XCTAssertEqual(LearningResearchService.normalizedQuery("I want to learn linear algebra"), "linear algebra")
    }

    @MainActor
    func testProviderDoesNotAcceptTruncatedLessonAsSuccess() throws {
        let incomplete = Data(#"{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output_text":"partial lesson"}"#.utf8)
        XCTAssertThrowsError(try LumapAIClient.parseGeneratedText(from: incomplete, style: .openAIResponses)) { error in
            guard case LumapAIError.incompleteResponse = error else { return XCTFail("Expected incomplete response") }
        }
        let chat = Data(#"{"choices":[{"finish_reason":"length","message":{"content":"partial"}}]}"#.utf8)
        XCTAssertThrowsError(try LumapAIClient.parseGeneratedText(from: chat, style: .openAIChat))
        let complete = Data(#"{"status":"completed","output_text":"","output":[{"content":[{"type":"output_text","text":"Actual complete text"}]}]}"#.utf8)
        XCTAssertEqual(try LumapAIClient.parseGeneratedText(from: complete, style: .openAIResponses), "Actual complete text")
    }

    @MainActor
    func testDifferentGoalsReachProviderAndKeepDistinctCurricula() async throws {
        let session = fixtureSession(replies: [try planJSON(topic: "Photosynthesis"), try planJSON(topic: "Linear algebra")])
        defer { session.invalidateAndCancel() }
        let first = try await LearningAgentService.plan(goal: "想学光合作用", learnerContext: "English beginner", configuration: provider,
            materialText: "Plants capture light and fix carbon dioxide into sugars.", materialTitle: "Biology notes", session: session)
        let second = try await LearningAgentService.plan(goal: "I want to learn linear algebra", learnerContext: "English beginner", configuration: provider,
            materialText: "Matrices describe linear transformations. Vectors can be added and scaled.", materialTitle: "Math notes", session: session)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.title, second.title)
        XCTAssertNotEqual(first.nodes[0].objective, second.nodes[0].objective)
        XCTAssertEqual(first.sources.first?.title, "Biology notes")
        XCTAssertEqual(second.sources.first?.title, "Math notes")
        XCTAssertEqual(first.sources.first?.url, "")
        let requests = LearningAgentFixtureProtocol.requestSnapshot()
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.url?.host == "localhost" }, "Uploaded private material must never reach a web search host")
        XCTAssertTrue(requests[0].body.contains("想学光合作用"))
        XCTAssertTrue(requests[1].body.contains("linear algebra"))
    }

    @MainActor
    func testMalformedJSONGetsExactlyOneRepairAttempt() async throws {
        let session = fixtureSession(replies: ["{broken", try planJSON(topic: "Photosynthesis")])
        defer { session.invalidateAndCancel() }
        let plan = try await LearningAgentService.plan(goal: "Photosynthesis", learnerContext: "English", configuration: provider,
            materialText: "Plants capture light and fix carbon dioxide into sugars.", session: session)
        XCTAssertEqual(plan.nodes.count, 4)
        XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 2)
        XCTAssertTrue(LearningAgentFixtureProtocol.requestSnapshot()[1].body.contains("failed validation"))
    }

    @MainActor
    func testInvalidJSONNeverFallsBackToTemplateCourse() async throws {
        let session = fixtureSession(replies: ["{}", "{}"])
        defer { session.invalidateAndCancel() }
        do {
            _ = try await LearningAgentService.plan(goal: "Violin technique", learnerContext: "English", configuration: provider,
                materialText: "The bow contacts the string and produces vibration.", session: session)
            XCTFail("Invalid generated course must fail visibly")
        } catch { XCTAssertTrue(error is LearningAgentError) }
        XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 2)
    }

    @MainActor
    func testInsufficientEvidenceIsNotRepairedIntoAnInventedCourse() async throws {
        let session = fixtureSession(replies: [#"{"error":"The supplied notes do not describe violin technique."}"#])
        defer { session.invalidateAndCancel() }
        do {
            _ = try await LearningAgentService.plan(goal: "Violin technique", learnerContext: "English", configuration: provider,
                materialText: "Plants use carbon dioxide during photosynthesis.", session: session)
            XCTFail("An honest evidence failure must be shown to the learner")
        } catch {
            XCTAssertEqual(error as? LearningAgentError, .invalidOutput("The supplied notes do not describe violin technique."))
        }
        XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 1)
    }

    @MainActor
    func testMissingSourcesCannotProduceGeneratedActivity() async throws {
        let session = fixtureSession(replies: [])
        defer { session.invalidateAndCancel() }
        let plan = LearningCoursePlan(id: "course", title: "Test", summary: "Test", goal: "Test", nodes: [], sources: [], recommendedMethodID: "guidedExplanation", recommendationReason: "Test", diagnosticQuestion: "Test", generatedAt: .now, model: "fixture")
        do {
            _ = try await LearningAgentService.activity(plan: plan, nodeID: "n1", methodID: "guidedExplanation", learnerContext: "", configuration: provider, session: session)
            XCTFail("Missing sources must prevent generation")
        } catch { XCTAssertEqual(error as? LearningAgentError, .noSources) }
        XCTAssertTrue(LearningAgentFixtureProtocol.requestSnapshot().isEmpty)
    }

    @MainActor
    func testStrictJSONParserRejectsSurroundingUnstructuredText() throws {
        XCTAssertThrowsError(try LearningAgentService.jsonObjectData("Some intro {\"title\":\"x\"}"))
        XCTAssertThrowsError(try LearningAgentService.jsonObjectData("{\"title\":\"x\""))
        let data = try LearningAgentService.jsonObjectData("```json\n{\"title\":\"x\"}\n```")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as? [String: String], ["title": "x"])
    }

    @MainActor
    func testActivityRejectsInventedInlineCitation() throws {
        let source = LearningSource(id: "S1", title: "Notes", url: "", excerpt: "Plants fix carbon dioxide into organic molecules.", retrievedAt: .now)
        let plan = LearningCoursePlan(id: "course", title: "Photosynthesis", summary: "Test", goal: "Plants", nodes: [], sources: [source], recommendedMethodID: "guidedExplanation", recommendationReason: "Test", diagnosticQuestion: "Test", generatedAt: .now, model: "fixture")
        let lesson = LearningGeneratedActivity(id: "a", methodID: "guidedExplanation", nodeID: "n1", title: "Carbon", explanation: String(repeating: "Plants use carbon dioxide as a source of carbon for organic molecules. ", count: 3) + "[S99]", prompt: "Where does a plant obtain carbon?", steps: [], examples: [], choices: [], correctChoiceID: nil, answerExplanation: "Carbon dioxide provides the carbon atoms.", cards: [], concepts: [], connections: [], hints: ["Consider which input contains carbon."], sourceIDs: ["S1"])
        XCTAssertThrowsError(try LearningAgentService.validateActivity(lesson, plan: plan, nodeID: "n1", methodID: "guidedExplanation"))
    }

    @MainActor
    func testCuriosityWithoutSelectableBranchesIsRejected() throws {
        let source = LearningSource(id: "S1", title: "Notes", url: "", excerpt: "Plants fix carbon dioxide into organic molecules.", retrievedAt: .now)
        let plan = LearningCoursePlan(id: "course", title: "Photosynthesis", summary: "Test", goal: "Plants", nodes: [], sources: [source], recommendedMethodID: "guidedExplanation", recommendationReason: "Test", diagnosticQuestion: "Test", generatedAt: .now, model: "fixture")
        let lesson = LearningGeneratedActivity(id: "a", methodID: "curiosityBranch", nodeID: "n1", title: "Follow the carbon", explanation: String(repeating: "Plants use carbon dioxide as a source of carbon for organic molecules. ", count: 3), prompt: "Which question do you want to investigate next?", steps: [], examples: [], choices: [], correctChoiceID: nil, answerExplanation: "Choose an adjacent topic and explain its relationship to carbon fixation.", cards: [], concepts: [], connections: [], hints: ["Consider where plant carbon goes after the plant is eaten."], sourceIDs: ["S1"])
        XCTAssertThrowsError(try LearningAgentService.validateActivity(lesson, plan: plan, nodeID: "n1", methodID: "curiosityBranch"))
    }

    @MainActor
    func testRecommendationRefreshRejectsDismissedTitleDespiteCaseAndWhitespace() async throws {
        func reply(_ firstTitle: String) throws -> String {
            let topics = [firstTitle, "Carbon in food webs", "Chloroplast structure", "Measuring plant growth"].enumerated().map { index, title in
                ["id": "t\(index)", "title": title, "reason": "Explore the next question from your gardening interest.", "methodID": "guidedExplanation"]
            }
            return String(data: try JSONSerialization.data(withJSONObject: ["topics": topics]), encoding: .utf8)!
        }
        let session = fixtureSession(replies: [try reply("  PHOTOSYNTHESIS "), try reply("Light and limiting factors")])
        defer { session.invalidateAndCancel() }
        let topics = try await LearningAgentService.recommendations(learnerContext: "Gardening beginner", excluding: ["Photosynthesis"], configuration: provider, session: session)
        XCTAssertEqual(topics.count, 4)
        XCTAssertEqual(topics.first?.title, "Light and limiting factors")
        XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 2)
    }

    @MainActor
    func testPlannerAcceptsLearnerSizedTwoAndTwelveSectionCourses() async throws {
        let session = fixtureSession(replies: [try planJSON(topic: "Short review", nodeCount: 2), try planJSON(topic: "Detailed foundation", nodeCount: 12)])
        defer { session.invalidateAndCancel() }
        let short = try await LearningAgentService.plan(goal: "Review photosynthesis", learnerContext: "English, expert, five minutes", configuration: provider, materialText: "Plants use light energy to fix carbon dioxide into organic molecules.", session: session)
        let longer = try await LearningAgentService.plan(goal: "Learn photosynthesis deeply", learnerContext: "English, beginner, several sessions", configuration: provider, materialText: "Plants use light energy to fix carbon dioxide into organic molecules.", session: session)
        XCTAssertEqual(short.nodes.count, 2)
        XCTAssertEqual(longer.nodes.count, 12)
    }

    @MainActor
    func testSectionAdaptationRepairsChangedIdentityAndKeepsPrerequisites() async throws {
        let plan = adaptationFixturePlan()
        let valid = LearningPathNode(id: "n2", title: "Trace matter before balancing equations", objective: "Distinguish carbon dioxide as a matter input from sunlight as the energy input using a labelled model.", prerequisiteIDs: ["n1"], estimatedMinutes: 8, methodIDs: ["visualMap", "misconceptionDiagnosis"])
        let invalid = LearningPathNode(id: "new-node", title: valid.title, objective: valid.objective, prerequisiteIDs: [], estimatedMinutes: 8, methodIDs: valid.methodIDs)
        let session = fixtureSession(replies: [String(data: try JSONEncoder().encode(invalid), encoding: .utf8)!, String(data: try JSONEncoder().encode(valid), encoding: .utf8)!])
        defer { session.invalidateAndCancel() }
        let node = try await LearningAgentService.adaptSection(plan: plan, nodeID: "n2", learnerContext: "English; score 30; misconception: sunlight supplies plant carbon; visual reasoning is improving", configuration: provider, session: session)
        XCTAssertEqual(node, valid)
        let requests = LearningAgentFixtureProtocol.requestSnapshot()
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].body.contains("sunlight supplies plant carbon"))
    }

    @MainActor
    func testSectionAdaptationRejectsPassiveOnlyMethodSequence() async throws {
        let node = LearningPathNode(id: "n2", title: "Listen to more facts", objective: "Identify carbon dioxide and water as the inputs to photosynthesis.", prerequisiteIDs: ["n1"], estimatedMinutes: 10, methodIDs: ["guidedExplanation", "narratedDeck"])
        let text = String(data: try JSONEncoder().encode(node), encoding: .utf8)!
        let session = fixtureSession(replies: [text, text])
        defer { session.invalidateAndCancel() }
        do {
            _ = try await LearningAgentService.adaptSection(plan: adaptationFixturePlan(), nodeID: "n2", learnerContext: "English", configuration: provider, session: session)
            XCTFail("A section needs an active exercise")
        } catch { XCTAssertTrue(error is LearningAgentError) }
        XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 2)
    }

    @MainActor
    func testGenerationHasWallClockDeadlineForStalledProvider() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LearningAgentHangingProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let start = Date.now
        do {
            _ = try await LumapAIClient.generateText(configuration: provider, prompt: "Prepare one activity", timeoutSeconds: 0.05, session: session)
            XCTFail("A stalled provider must not wait indefinitely")
        } catch {
            XCTAssertTrue(error is LumapAIError || (error as? URLError)?.code == .timedOut)
        }
        XCTAssertLessThan(Date.now.timeIntervalSince(start), 2)
    }

    @MainActor
    func testDemoSolResponsesUsesLowEffortWithoutChangingLessonContract() throws {
        let configuration = ProviderConfiguration(endpoint: "https://api.ikuncode.cc/v1/responses", model: "gpt-5.6-sol", style: .openAIResponses, apiKey: "fixture-key")
        let prompt = "Generate six complete slides. Each narration must be at least one hundred words."
        let request = try LumapAIClient.makeRequest(configuration: configuration, prompt: prompt, instructions: "Return every required field.", maxOutputTokens: 14_000)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(payload["model"] as? String, "gpt-5.6-sol")
        XCTAssertEqual(payload["reasoning"] as? [String: String], ["effort": "low"])
        XCTAssertEqual(payload["text"] as? [String: String], ["verbosity": "low"])
        XCTAssertEqual(payload["input"] as? String, prompt)
        XCTAssertEqual(payload["instructions"] as? String, "Return every required field.")
        XCTAssertEqual(payload["max_output_tokens"] as? Int, 14_000)
        XCTAssertNil(payload["service_tier"])
    }

    @MainActor
    func testLatencyTuningDoesNotChangeOtherProvidersModelsOrProtocols() throws {
        let configurations = [
            ProviderConfiguration(endpoint: "https://custom.example/v1", model: "gpt-5.6-sol", style: .openAIResponses, apiKey: "fixture"),
            ProviderConfiguration(endpoint: "https://api.ikuncode.cc.example/v1", model: "gpt-5.6-sol", style: .openAIResponses, apiKey: "fixture"),
            ProviderConfiguration(endpoint: "https://api.ikuncode.cc/v1", model: "gpt-6-astra", style: .openAIResponses, apiKey: "fixture"),
            ProviderConfiguration(endpoint: "https://api.ikuncode.cc/v1", model: "gpt-5.6-sol", style: .openAIChat, apiKey: "fixture"),
            ProviderConfiguration(endpoint: "https://api.ikuncode.cc/v1", model: "custom-model", style: .anthropicMessages, apiKey: "fixture")
        ]
        for configuration in configurations {
            let request = try LumapAIClient.makeRequest(configuration: configuration, prompt: "Fixture", instructions: nil, maxOutputTokens: 100)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            XCTAssertNil(payload["reasoning"], configuration.endpoint + " " + configuration.model)
            XCTAssertNil(payload["text"])
            XCTAssertEqual(payload["model"] as? String, configuration.model)
        }
    }

    @MainActor
    func testPlanRepairsPassiveOverloadedOrMisorderedMethodSequences() async throws {
        let valid = try planJSON(topic: "Photosynthesis")
        for invalidMethods in [["guidedExplanation", "narratedDeck"],
                               ["guidedExplanation", "workedExample", "flashRecall", "teachBack"],
                               ["workedExample", "guidedExplanation"]] {
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(valid.utf8)) as? [String: Any])
            var nodes = try XCTUnwrap(payload["nodes"] as? [[String: Any]])
            nodes[0]["methodIDs"] = invalidMethods
            payload["nodes"] = nodes
            let invalid = String(data: try JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
            let session = fixtureSession(replies: [invalid, valid])
            defer { session.invalidateAndCancel() }
            let plan = try await LearningAgentService.plan(goal: "Photosynthesis", learnerContext: "English", configuration: provider,
                materialText: "Plants use light energy to fix carbon dioxide into organic molecules.", session: session)
            XCTAssertEqual(plan.nodes[0].methodIDs, ["guidedExplanation", "workedExample"])
            XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 2, "Invalid sequence must be repaired: \(invalidMethods)")
        }
    }

    @MainActor
    func testCompleteActivitiesForEveryModeMeetValidationContract() throws {
        for methodID in LearningAgentService.methodIDs {
            let activity = activityFixture(methodID: methodID)
            XCTAssertNoThrow(try LearningAgentService.validateActivity(activity, plan: adaptationFixturePlan(), nodeID: "n1", methodID: methodID), methodID)
        }
    }

    @MainActor
    func testActivitiesRejectInvisibleTeachingAndDuplicateInteractions() throws {
        let blankHints = try activityFixture(methodID: "guidedExplanation", replacing: ["hints": [" \n\t "]])
        let blankStep = try activityFixture(methodID: "workedExample", replacing: ["steps": ["First", "Second", "Third", " \n "]])
        let blankBack = try activityFixture(methodID: "flashRecall", replacing: ["cards": (1...5).map { ["front": "Question \($0)", "back": " \n "] }])
        let repeatedCard = try activityFixture(methodID: "flashRecall", replacing: ["cards": (1...5).map { ["front": $0 == 1 ? " CARBON " : "carbon", "back": "Carbon comes from carbon dioxide."] }])
        let repeatedChoice = try activityFixture(methodID: "simulation", replacing: ["choices": (1...3).map { ["id": "choice\($0)", "text": $0 == 1 ? " MORE LIGHT " : "more light", "feedback": "Light increases photosynthesis until another input limits growth."] }])
        for activity in [blankHints, blankStep, blankBack, repeatedCard, repeatedChoice] {
            XCTAssertThrowsError(try LearningAgentService.validateActivity(activity, plan: adaptationFixturePlan(), nodeID: "n1", methodID: activity.methodID), activity.methodID)
        }
    }

    @MainActor
    func testIncompleteMethodPayloadsAreRejectedBeforeDisplay() throws {
        let missing: [(String, [String: Any])] = [
            ("guidedExplanation", ["steps": []]),
            ("workedExample", ["steps": ["First", "Second", "Third"]]),
            ("analogy", ["steps": []]),
            ("deliberatePractice", ["examples": []]),
            ("socraticDialogue", ["hints": ["One hint"]]),
            ("flashRecall", ["cards": [["front": "Where does plant carbon originate?", "back": "Carbon dioxide."]]]),
            ("visualMap", ["connections": []]),
            ("story", ["steps": []]),
            ("simulation", ["steps": []]),
            ("misconceptionDiagnosis", ["correctChoiceID": NSNull()]),
            ("narratedDeck", ["steps": ["One scene", "Second scene", "Third scene"]])
        ]
        for (methodID, fields) in missing {
            let activity = try activityFixture(methodID: methodID, replacing: fields)
            XCTAssertThrowsError(try LearningAgentService.validateActivity(activity, plan: adaptationFixturePlan(), nodeID: "n1", methodID: methodID), methodID)
        }
    }

    @MainActor
    func testIncompleteActivityGetsOneRepairAndKeepsRealGeneratedContent() async throws {
        let incomplete = try activityFixture(methodID: "simulation", replacing: ["steps": ["Only one setup step"]])
        let complete = activityFixture(methodID: "simulation")
        let replies = try [incomplete, complete].map { String(data: try JSONEncoder().encode($0), encoding: .utf8)! }
        let session = fixtureSession(replies: replies)
        defer { session.invalidateAndCancel() }
        let activity = try await LearningAgentService.activity(plan: adaptationFixturePlan(), nodeID: "n1", methodID: "simulation", learnerContext: "English", configuration: provider, session: session)
        XCTAssertEqual(activity.steps, complete.steps)
        XCTAssertEqual(activity.choices, complete.choices)
        XCTAssertNotEqual(activity.id, complete.id)
        XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 2)
    }

    @MainActor
    func testWhitespaceEvaluationIsRepairedBeforeBecomingEvidence() async throws {
        let valid = LearningEvaluation(score: 75, feedback: "You correctly traced carbon from carbon dioxide into organic matter.", misconceptions: [], nextMethodID: "workedExample", nextNodeID: "n1", reason: "Apply your carbon tracing to a new example.")
        let blank = LearningEvaluation(score: 75, feedback: " \n ", misconceptions: [], nextMethodID: "workedExample", nextNodeID: "n1", reason: " \t ")
        let replies = try [blank, valid].map { String(data: try JSONEncoder().encode($0), encoding: .utf8)! }
        let session = fixtureSession(replies: replies)
        defer { session.invalidateAndCancel() }
        let evaluation = try await LearningAgentService.evaluate(plan: adaptationFixturePlan(), activity: activityFixture(methodID: "guidedExplanation"), response: "The carbon atoms come from carbon dioxide.", learnerContext: "English", configuration: provider, session: session)
        XCTAssertEqual(evaluation, valid)
        XCTAssertEqual(LearningAgentFixtureProtocol.requestSnapshot().count, 2)
    }

    @MainActor
    private func activityFixture(methodID: String, replacing fields: [String: Any]) throws -> LearningGeneratedActivity {
        let data = try JSONEncoder().encode(activityFixture(methodID: methodID))
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        payload.merge(fields) { _, replacement in replacement }
        return try JSONDecoder().decode(LearningGeneratedActivity.self, from: JSONSerialization.data(withJSONObject: payload))
    }

    @MainActor
    private func activityFixture(methodID: String) -> LearningGeneratedActivity {
        let stepCounts = ["guidedExplanation": 2, "workedExample": 4, "analogy": 3, "deliberatePractice": 3, "simulation": 3, "story": 3, "narratedDeck": 6]
        let hasChoices = ["story", "simulation", "counterfactualLab", "misconceptionDiagnosis", "curiosityBranch"].contains(methodID)
        let concepts: [LearningConcept] = methodID == "visualMap" ? (1...5).map {
            .init(id: "c\($0)", label: "Carbon stage \($0)", detail: "Trace the carbon atoms through stage \($0) of photosynthesis.")
        } : []
        return LearningGeneratedActivity(id: "fixture-activity", methodID: methodID, nodeID: "n1", title: "Trace plant carbon",
            explanation: "Plants use carbon dioxide as a source of carbon for organic molecules. Light supplies the energy for photosynthesis, while matter comes from carbon dioxide and water. The carbon atoms stay identifiable as matter changes form. [S1]",
            prompt: "Explain where the carbon in a growing plant originates.",
            steps: (0..<(stepCounts[methodID] ?? 0)).map { "Stage \($0 + 1): trace carbon atoms from carbon dioxide into the plant's organic molecules." },
            examples: ["A growing plant takes carbon dioxide from the air to build organic matter."],
            choices: hasChoices ? (1...3).map { .init(id: "a\($0)", text: "Investigate carbon input \($0)", feedback: "Trace the carbon atoms through this input to identify whether it supplies matter.") } : [],
            correctChoiceID: methodID == "misconceptionDiagnosis" ? "a1" : nil,
            answerExplanation: "Carbon dioxide supplies the carbon atoms; sunlight supplies energy, not carbon matter.",
            cards: methodID == "flashRecall" ? (1...5).map { .init(front: "Trace carbon at stage \($0).", back: "Carbon dioxide supplies the carbon atoms.") } : [],
            concepts: concepts,
            connections: methodID == "visualMap" ? (1...4).map { .init(from: "c\($0)", to: "c\($0 + 1)", label: "Carbon flows to the next stage") } : [],
            hints: ["Which input contains carbon atoms?", "Distinguish energy from matter.", "Trace the carbon in carbon dioxide."], sourceIDs: ["S1"])
    }

    @MainActor
    private func adaptationFixturePlan() -> LearningCoursePlan {
        let first = LearningPathNode(id: "n1", title: "Inputs and outputs", objective: "Identify inputs and outputs of photosynthesis.", prerequisiteIDs: [], estimatedMinutes: 10, methodIDs: ["guidedExplanation", "workedExample"])
        let second = LearningPathNode(id: "n2", title: "Balance the equation", objective: "Trace carbon atoms through the photosynthesis equation.", prerequisiteIDs: ["n1"], estimatedMinutes: 10, methodIDs: ["guidedExplanation", "workedExample"])
        return LearningCoursePlan(id: "adaptation", title: "Photosynthesis", summary: "Trace matter and energy in plants.", goal: "Learn photosynthesis", nodes: [first, second], sources: [.init(id: "S1", title: "Course notes", url: "", excerpt: "Light supplies energy. Carbon dioxide supplies carbon. Water and carbon dioxide are used to form organic compounds and release oxygen.", retrievedAt: .now)], recommendedMethodID: "workedExample", recommendationReason: "Explore", diagnosticQuestion: "Where does plant carbon originate?", generatedAt: .now, model: "fixture")
    }

    @MainActor
    private var provider: ProviderConfiguration { ProviderConfiguration(endpoint: "http://localhost/v1", model: "fixture-model", style: .openAIResponses, apiKey: "") }

    @MainActor
    private func fixtureSession(replies: [String]) -> URLSession {
        LearningAgentFixtureProtocol.configure(replies: replies)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LearningAgentFixtureProtocol.self]
        return URLSession(configuration: configuration)
    }

    @MainActor
    private func planJSON(topic: String, nodeCount: Int = 4) throws -> String {
        let nodes = (1...nodeCount).map { index in
            LearningPathNode(id: "n\(index)", title: "\(topic): concept \(index)", objective: "Explain and apply \(topic) concept \(index) to a concrete situation.", prerequisiteIDs: index > 1 ? ["n\(index - 1)"] : [], estimatedMinutes: 10, methodIDs: ["guidedExplanation", "workedExample"])
        }
        let object: [String: Any] = ["title": topic, "summary": "Learn the specific foundations and applications of \(topic) using the supplied notes.", "nodes": try JSONSerialization.jsonObject(with: JSONEncoder().encode(nodes)), "recommendedMethodID": "guidedExplanation", "recommendationReason": "Cold start: begin with a diagnostic explanation.", "diagnosticQuestion": "What do you already understand about \(topic)?"]
        return String(data: try JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
    }
}

private final class LearningAgentHangingProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { }
    override func stopLoading() { }
}

private final class LearningAgentFixtureProtocol: URLProtocol, @unchecked Sendable {
    struct CapturedRequest: Sendable { let url: URL?; let body: String }
    nonisolated(unsafe) private static var replies: [String] = []
    nonisolated(unsafe) private static var requests: [CapturedRequest] = []
    nonisolated private static let lock = NSLock()

    nonisolated static func configure(replies: [String]) { lock.lock(); defer { lock.unlock() }; self.replies = replies; requests = [] }
    nonisolated static func requestSnapshot() -> [CapturedRequest] { lock.lock(); defer { lock.unlock() }; return requests }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        Self.lock.lock()
        Self.requests.append(CapturedRequest(url: request.url, body: String(data: body, encoding: .utf8) ?? ""))
        let reply = Self.replies.isEmpty ? nil : Self.replies.removeFirst()
        Self.lock.unlock()
        guard let reply else { client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return }
        let data = try! JSONSerialization.data(withJSONObject: ["status": "completed", "output_text": reply])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
