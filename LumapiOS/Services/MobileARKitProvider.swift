import ARKit
import Foundation

@MainActor
final class MobileARKitProvider: ObservableObject, SpatialLearningProviding {
    @Published private(set) var availability: SpatialLearningAvailability = .checking
    let scenario: SpatialLearningScenario

    init(scenario: SpatialLearningScenario = .feedbackLab) {
        self.scenario = scenario
    }

    func prepare() async {
        availability = .checking

        #if targetEnvironment(simulator)
        availability = .previewOnly
        #else
        availability = ARWorldTrackingConfiguration.isSupported ? .ready : .previewOnly
        #endif
    }

    func reset() {
        availability = .checking
    }
}
