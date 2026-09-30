import SwiftData
import XCTest
@testable import Lumap

final class LearningRecommendationTests: XCTestCase {
    @MainActor private func makeStore() throws -> (LumapStore, ModelContext) {
        let schema = Schema([LearnerProfile.self, SourceRecord.self, InterestEvidence.self, LearningGoal.self,
                             ActivityRecord.self, AssessmentRecord.self, RewardEntry.self, MaterialRecord.self,
                             AppHealthRecord.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ])
        let context = ModelContext(container)
        let store = LumapStore()
        store.configure(context: context)
        return (store, context)
    }

    private func topic(_ title: String) -> LearningSuggestedTopic {
        .init(id: title, title: title, reason: "A fixture based on the learner's confirmed interests.",
              methodID: "guidedExplanation")
    }

    @MainActor
    func testConfirmedInterestReplacesCachedSuggestionsUsingCurrentContext() async throws {
        let (store, context) = try makeStore()
        let interest = InterestEvidence(topic: "Robotics", sourceLabel: "Fixture", explanation: "Learner selected")
        context.insert(interest)
        try context.save()
        store.suggestedTopics = [topic("Old cached suggestion")]
        store.dismissedSuggestions = ["Ancient pottery"]
        let revision = store.recommendationContextRevision

        try store.confirmInterest(interest)

        XCTAssertTrue(store.suggestedTopics.isEmpty)
        XCTAssertGreaterThan(store.recommendationContextRevision, revision)
        XCTAssertEqual(store.dismissedSuggestions, ["Ancient pottery"])
        var receivedContext = ""
        var receivedExclusions: [String] = []
        let replacement = topic("Robot motion")
        store.recommendationGenerator = { context, exclusions in
            receivedContext = context
            receivedExclusions = exclusions
            return [replacement]
        }
        await store.refreshPersonalizedRecommendations()

        XCTAssertTrue(receivedContext.contains("Confirmed interests: Robotics"))
        XCTAssertEqual(receivedExclusions, ["Ancient pottery"])
        XCTAssertEqual(store.suggestedTopics, [replacement])
        XCTAssertFalse(store.isRefreshingRecommendations)
    }

    @MainActor
    func testRemovingInterestInvalidatesCacheAndExcludesRemovedInterestFromContext() async throws {
        let (store, context) = try makeStore()
        let interest = InterestEvidence(topic: "Robotics", sourceLabel: "Fixture", explanation: "Confirmed",
                                        status: "confirmed")
        context.insert(interest)
        try context.save()
        store.suggestedTopics = [topic("Robot motion")]
        try store.removeInterest(interest)
        XCTAssertTrue(store.suggestedTopics.isEmpty)
        var receivedContext = ""
        let replacement = topic("Explore a fresh question")
        store.recommendationGenerator = { context, _ in
            receivedContext = context
            return [replacement]
        }
        await store.refreshPersonalizedRecommendations()
        XCTAssertFalse(receivedContext.contains("Robotics"))
        XCTAssertEqual(store.suggestedTopics, [replacement])
    }

    @MainActor
    func testProfileChangesInvalidateSuggestionsWithoutMakingRequests() throws {
        let (store, _) = try makeStore()
        store.suggestedTopics = [topic("Old recommendation")]
        store.recommendationError = "A previous error"
        var requestCount = 0
        store.recommendationGenerator = { _, _ in
            requestCount += 1
            return []
        }

        try store.saveProfile(displayName: "Learner", ageBand: "adult", background: "Beginner gardener",
                              availableMinutes: 10)

        XCTAssertTrue(store.suggestedTopics.isEmpty)
        XCTAssertNil(store.recommendationError)
        XCTAssertFalse(store.isRefreshingRecommendations)
        XCTAssertEqual(requestCount, 0)
        XCTAssertTrue(store.learnerContextForGeneration.contains("Beginner gardener"))
    }

    @MainActor
    func testForcedRefreshSupersedesPendingRequestAndRejectsItsLateResponse() async throws {
        let (store, _) = try makeStore()
        let gate = RecommendationRequestGate()
        store.recommendationGenerator = { context, exclusions in
            try await gate.request(context: context, exclusions: exclusions)
        }
        let first = Task { await store.refreshPersonalizedRecommendations() }
        await gate.waitForRequests(1)
        let firstID = store.recommendationRequestID
        let second = Task { await store.refreshPersonalizedRecommendations(force: true) }
        await gate.waitForRequests(2)
        XCTAssertNotEqual(store.recommendationRequestID, firstID)
        let fresh = topic("Fresh suggestion")
        gate.succeed(1, with: [fresh])
        await second.value
        XCTAssertEqual(store.suggestedTopics, [fresh])
        XCTAssertFalse(store.isRefreshingRecommendations)

        // This fixture deliberately ignores task cancellation to model a late
        // network response. It must never replace the newer visible result.
        gate.succeed(0, with: [topic("Stale suggestion")])
        await first.value
        XCTAssertEqual(store.suggestedTopics, [fresh])
        XCTAssertNil(store.recommendationError)
    }

    @MainActor
    func testInvalidatedRequestCannotStopNewSpinnerOrPublishAnOldError() async throws {
        let (store, _) = try makeStore()
        let gate = RecommendationRequestGate()
        store.recommendationGenerator = { context, exclusions in
            try await gate.request(context: context, exclusions: exclusions)
        }
        let old = Task { await store.refreshPersonalizedRecommendations() }
        await gate.waitForRequests(1)
        store.dismissedSuggestions = ["Keep this dismissal"]
        store.invalidatePersonalizedRecommendations()
        XCTAssertFalse(store.isRefreshingRecommendations)
        XCTAssertTrue(store.suggestedTopics.isEmpty)
        XCTAssertEqual(store.dismissedSuggestions, ["Keep this dismissal"])

        let fresh = Task { await store.refreshPersonalizedRecommendations() }
        await gate.waitForRequests(2)
        gate.fail(0, with: RecommendationFixtureError.unavailable)
        await old.value
        XCTAssertTrue(store.isRefreshingRecommendations)
        XCTAssertNil(store.recommendationError)
        let result = topic("Current profile suggestion")
        gate.succeed(1, with: [result])
        await fresh.value
        XCTAssertEqual(store.suggestedTopics, [result])
        XCTAssertFalse(store.isRefreshingRecommendations)
    }

    @MainActor
    func testProviderFailureEndsLoadingAndSupportsRetryWithoutFabricatedSuggestions() async throws {
        let (store, _) = try makeStore()
        store.recommendationGenerator = { _, _ in throw RecommendationFixtureError.unavailable }
        await store.refreshPersonalizedRecommendations()
        XCTAssertFalse(store.isRefreshingRecommendations)
        XCTAssertNil(store.recommendationTask)
        XCTAssertTrue(store.suggestedTopics.isEmpty)
        XCTAssertEqual(store.recommendationError, RecommendationFixtureError.unavailable.localizedDescription)

        let result = topic("Recovered suggestion")
        store.recommendationGenerator = { _, _ in [result] }
        await store.refreshPersonalizedRecommendations(force: true)
        XCTAssertEqual(store.suggestedTopics, [result])
        XCTAssertNil(store.recommendationError)
        XCTAssertFalse(store.isRefreshingRecommendations)
    }
}

private enum RecommendationFixtureError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Fixture provider is temporarily unavailable. Retry the request." }
}

/// A deterministic async fixture: tests choose response order without sleeping,
/// loading a provider key, or relying on a remote model.
@MainActor
private final class RecommendationRequestGate {
    private var requestCount = 0
    private var pending: [Int: CheckedContinuation<[LearningSuggestedTopic], any Error>] = [:]
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func request(context: String, exclusions: [String]) async throws -> [LearningSuggestedTopic] {
        try await withCheckedThrowingContinuation { continuation in
            pending[requestCount] = continuation
            requestCount += 1
            let ready = waiters.filter { $0.0 <= requestCount }
            waiters.removeAll { $0.0 <= requestCount }
            for (_, waiter) in ready { waiter.resume() }
        }
    }

    func waitForRequests(_ count: Int) async {
        if requestCount >= count { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func succeed(_ index: Int, with topics: [LearningSuggestedTopic]) {
        pending.removeValue(forKey: index)?.resume(returning: topics)
    }

    func fail(_ index: Int, with error: any Error) {
        pending.removeValue(forKey: index)?.resume(throwing: error)
    }
}
