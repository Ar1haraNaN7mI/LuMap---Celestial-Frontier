import Foundation

/// Tests can supply a controlled generator without reading Keychain or making
/// paid requests. Production always uses the configured learning agent.
typealias LearningRecommendationGenerator = @MainActor (
    _ learnerContext: String,
    _ excludedTitles: [String]
) async throws -> [LearningSuggestedTopic]

@MainActor
extension LumapStore {
    /// Retire suggestions derived from an older learner profile. The discovery
    /// view observes the revision and requests a replacement when it is visible.
    /// Explicit "not interested" feedback survives profile and interest edits.
    func invalidatePersonalizedRecommendations() {
        recommendationTask?.cancel()
        recommendationTask = nil
        recommendationRequestID = UUID()
        recommendationContextRevision += 1
        suggestedTopics = []
        recommendationError = nil
        isRefreshingRecommendations = false
    }

    func refreshPersonalizedRecommendations(force: Bool = false) async {
        if !force, !suggestedTopics.isEmpty { return }
        if !force, let task = recommendationTask {
            await task.value
            return
        }

        // An explicit refresh replaces an older request instead of silently
        // discarding the learner's refresh action while that request is pending.
        recommendationTask?.cancel()
        recommendationTask = nil
        let requestID = UUID()
        let revision = recommendationContextRevision
        recommendationRequestID = requestID
        recommendationError = nil

        let generate: LearningRecommendationGenerator
        if let injectedGenerator = recommendationGenerator {
            generate = injectedGenerator
        } else if let configuration = providerConfigurationForGeneration() {
            generate = { context, exclusions in
                try await LearningAgentService.recommendations(
                    learnerContext: context,
                    excluding: exclusions,
                    configuration: configuration
                )
            }
        } else {
            isRefreshingRecommendations = false
            recommendationError = LearningSessionError.providerRequired.localizedDescription
            return
        }

        let learnerContext = learnerContextForGeneration
        let exclusions = Array(dismissedSuggestions.suffix(24))
        isRefreshingRecommendations = true
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.recommendationRequestID == requestID,
                   self.recommendationContextRevision == revision {
                    self.isRefreshingRecommendations = false
                    self.recommendationTask = nil
                }
            }
            do {
                let topics = try await generate(learnerContext, exclusions)
                try Task.checkCancellation()
                guard self.recommendationRequestID == requestID,
                      self.recommendationContextRevision == revision else { return }
                self.suggestedTopics = topics
            } catch is CancellationError {
                // Profile changes and replacement requests are normal lifecycle
                // events. Their old cancellation must not surface as an error.
            } catch {
                guard self.recommendationRequestID == requestID,
                      self.recommendationContextRevision == revision else { return }
                self.recommendationError = error.localizedDescription
            }
        }
        recommendationTask = task
        await task.value
    }
}
