import XCTest
import SwiftUI
import AppKit
@testable import Lumap

final class LearningJourneyTests: XCTestCase {
    private func plan() -> LearningCoursePlan {
        .init(id: "journey-plan", title: "Understand plants", summary: "A personalised path", goal: "How do plants grow?",
              nodes: [
                .init(id: "origin", title: "Follow a leaf", objective: "Connect light and growth", prerequisiteIDs: [],
                      estimatedMinutes: 8, methodIDs: ["story", "visualMap", "teachBack"]),
                .init(id: "experiment", title: "Build a light experiment", objective: "Change one variable", prerequisiteIDs: ["origin"],
                      estimatedMinutes: 12, methodIDs: ["simulation", "reflection"]),
                .init(id: "hidden-future", title: "A future title that must remain hidden", objective: "Unopened objective",
                      prerequisiteIDs: ["experiment"], estimatedMinutes: 10, methodIDs: ["transferChallenge"])
              ], sources: [], recommendedMethodID: "story", recommendationReason: "Start with a concrete example",
              diagnosticQuestion: "What does a leaf need?", generatedAt: .distantPast, model: "test-fixture")
    }

    private func attempt(id: UUID = UUID(), node: String = "origin", activity: String = "saved-story",
                         method: String = "story") -> LearningAttemptEvidence {
        .init(id: id, nodeID: node, activityID: activity, methodID: method,
              response: "Light helps the plant make sugars", evaluation: .init(score: 85,
              feedback: "You connected energy to growth", misconceptions: [], nextMethodID: "teachBack",
              nextNodeID: node, reason: "Check transfer"), durationSeconds: 60, createdAt: .distantPast)
    }

    @MainActor func testNewJourneyProjectsOnlyCurrentSectionAndItsOrderedMethods() {
        let snapshot = LearningJourneySnapshot(plan: plan(), evidence: .init(), currentNodeID: "origin")
        XCTAssertEqual(snapshot.sections.map(\.id), ["origin"])
        XCTAssertEqual(snapshot.sections[0].methods.map(\.id), ["story", "visualMap", "teachBack"])
        XCTAssertEqual(snapshot.sections[0].state, .current)
        XCTAssertTrue(snapshot.sections[0].savedEvidence.isEmpty)
        XCTAssertEqual(snapshot.currentSectionID, "origin")
        XCTAssertFalse(snapshot.isComplete)
        XCTAssertFalse(String(describing: snapshot).contains("A future title that must remain hidden"))
        XCTAssertFalse(String(describing: snapshot).contains("transferChallenge"))
    }

    @MainActor func testCompletionDoesNotRevealNextTagUntilItActuallyOpens() {
        var evidence = LearningSessionEvidence()
        evidence.completedNodeIDs = ["origin"]
        evidence.completedSectionMethods = ["origin": ["story", "visualMap", "teachBack"]]
        let beforeContinue = LearningJourneySnapshot(plan: plan(), evidence: evidence, currentNodeID: "origin")
        XCTAssertEqual(beforeContinue.sections.map(\.id), ["origin"])
        XCTAssertTrue(beforeContinue.sections[0].isExplored)
        XCTAssertNil(beforeContinue.currentSectionID, "Completed tags open saved evidence even before the next section is activated")
        let afterContinue = LearningJourneySnapshot(plan: plan(), evidence: evidence, currentNodeID: "experiment")
        XCTAssertEqual(afterContinue.sections.map(\.id), ["origin", "experiment"])
        XCTAssertEqual(afterContinue.sections.last?.state, .current)
        XCTAssertEqual(afterContinue.currentSectionID, "experiment")
    }

    @MainActor func testInvalidLaterCompletionAndStaleCurrentCannotLeakFutureNodes() {
        var evidence = LearningSessionEvidence()
        evidence.completedNodeIDs = ["hidden-future"]
        let snapshot = LearningJourneySnapshot(plan: plan(), evidence: evidence, currentNodeID: "hidden-future")
        XCTAssertEqual(snapshot.sections.map(\.id), ["origin"])
        XCTAssertEqual(snapshot.currentSectionID, "origin")
        XCTAssertFalse(snapshot.isComplete)
        XCTAssertFalse(snapshot.sections[0].isExplored)
        evidence.completedNodeIDs = ["origin", "hidden-future"]
        let missingCursor = LearningJourneySnapshot(plan: plan(), evidence: evidence, currentNodeID: nil)
        XCTAssertEqual(missingCursor.sections.map(\.id), ["origin"], "A missing cursor must not manufacture a visit to the next step")
        let invalidCursor = LearningJourneySnapshot(plan: plan(), evidence: evidence, currentNodeID: "hidden-future")
        XCTAssertEqual(invalidCursor.sections.map(\.id), ["origin"])
    }

    @MainActor func testOnlyMatchingSavedAssignedEvidenceAppearsInHistory() {
        var evidence = LearningSessionEvidence()
        let saved = attempt()
        evidence.savedActivityIDs = ["saved-story", "wrong-node", "optional-check"]
        evidence.attempts = [saved, saved,
                             attempt(activity: "not-saved"),
                             attempt(node: "experiment", activity: "wrong-node"),
                             attempt(activity: "optional-check", method: "deliberatePractice")]
        evidence.completedSectionMethods = ["origin": ["story"]]
        let snapshot = LearningJourneySnapshot(plan: plan(), evidence: evidence, currentNodeID: "origin")
        XCTAssertEqual(snapshot.sections[0].savedEvidence.count, 1)
        XCTAssertEqual(snapshot.sections[0].savedEvidence[0].response, saved.response)
        XCTAssertEqual(snapshot.sections[0].savedEvidence[0].feedback, saved.evaluation.feedback)
        XCTAssertEqual(snapshot.sections[0].methods.map(\.savedEvidenceCount), [1, 0, 0])
        XCTAssertEqual(snapshot.sections[0].methods.map(\.isCompleted), [true, false, false])
        XCTAssertEqual(evidence.attempts.count, 5, "Projecting a journey never mutates its session")
    }

    @MainActor func testFinishedArchiveContainsAllExploredSectionsAndNoCurrentStep() {
        var evidence = LearningSessionEvidence()
        evidence.completedNodeIDs = plan().nodes.map(\.id)
        let snapshot = LearningJourneySnapshot(plan: plan(), evidence: evidence, currentNodeID: "hidden-future")
        XCTAssertTrue(snapshot.isComplete)
        XCTAssertNil(snapshot.currentSectionID)
        XCTAssertEqual(snapshot.sections.map(\.ordinal), [1, 2, 3])
        XCTAssertTrue(snapshot.sections.allSatisfy(\.isExplored))
    }

    @MainActor func testEmptyPlanProducesNoInventedProgressOrCards() {
        let base = plan()
        let empty = LearningCoursePlan(id: base.id, title: base.title, summary: base.summary, goal: base.goal,
            nodes: [], sources: [], recommendedMethodID: base.recommendedMethodID,
            recommendationReason: base.recommendationReason, diagnosticQuestion: base.diagnosticQuestion,
            generatedAt: base.generatedAt, model: base.model)
        let snapshot = LearningJourneySnapshot(plan: empty, evidence: .init(), currentNodeID: "missing")
        XCTAssertTrue(snapshot.sections.isEmpty)
        XCTAssertNil(snapshot.currentSectionID)
        XCTAssertFalse(snapshot.isComplete)
    }

    /// Opt-in native visual capture. The synthetic plant lesson is explicitly a
    /// fixture and never enters SwiftData, the recommendation agent or user state.
    @MainActor func testRenderNativeJourneySnapshots() throws {
        guard let directory = ProcessInfo.processInfo.environment["LUMAP_JOURNEY_SNAPSHOT_OUTPUT"],
              !directory.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_LUMAP_JOURNEY_SNAPSHOT_OUTPUT to an app-container output directory for native snapshots")
        }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let base = plan()
        let nodes = Array(base.nodes.prefix(2)) + [LearningPathNode(id: "current",
            title: "Explain a plant's hidden world", objective: "Turn your experiment into a story you can teach.",
            prerequisiteIDs: ["experiment"], estimatedMinutes: 9, methodIDs: ["narratedDeck", "teachBack"])]
        let fixture = LearningCoursePlan(id: "native-journey-visual-fixture", title: "The secret life of plants",
            summary: "Synthetic visual fixture", goal: "How do plants turn light into life?", nodes: nodes,
            sources: [], recommendedMethodID: "story", recommendationReason: "Synthetic visual fixture",
            diagnosticQuestion: "What changes when a leaf gets less light?", generatedAt: .distantPast, model: "visual-fixture")
        var current = LearningSessionEvidence()
        for node in nodes.prefix(2) {
            current.completedNodeIDs.append(node.id)
            current.completedSectionMethods = (current.completedSectionMethods ?? [:]).merging([node.id: node.methodIDs]) { _, new in new }
            for method in node.methodIDs {
                let activityID = "fixture-\(node.id)-\(method)"
                current.savedActivityIDs.append(activityID)
                current.attempts.append(attempt(node: node.id, activity: activityID, method: method))
            }
        }
        let started = LearningJourneySnapshot(plan: fixture, evidence: .init(), currentNodeID: "origin")
        let progressing = LearningJourneySnapshot(plan: fixture, evidence: current, currentNodeID: "current")
        var archive = current
        archive.completedNodeIDs.append("current")
        archive.completedSectionMethods?["current"] = nodes[2].methodIDs
        for method in nodes[2].methodIDs {
            let activityID = "fixture-current-\(method)"
            archive.savedActivityIDs.append(activityID)
            archive.attempts.append(attempt(node: "current", activity: activityID, method: method))
        }
        let archived = LearningJourneySnapshot(plan: fixture, evidence: archive, currentNodeID: "current")
        try render(started, name: "journey-native-start.png", size: CGSize(width: 1440, height: 900), to: output)
        try render(progressing, name: "journey-native-progress.png", size: CGSize(width: 1440, height: 900), to: output)
        try render(archived, name: "journey-native-archive.png", size: CGSize(width: 1440, height: 900), to: output)
        try render(progressing, name: "journey-native-compact.png", size: CGSize(width: 390, height: 844), to: output)
        try "Native SwiftUI ImageRenderer captures. Synthetic plant lesson fixture; no user state or credentials.\n".write(
            to: output.appendingPathComponent("CAPTURE-NOTES.txt"), atomically: true, encoding: .utf8)
    }

    @MainActor private func render(_ snapshot: LearningJourneySnapshot, name: String, size: CGSize, to directory: URL) throws {
        let view = LearningJourneyChainView(snapshot: snapshot, isChinese: false, animationTime: 4, snapshotScrollOffset: 0,
                                            onSelectSection: { _ in })
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.nsImage)
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertEqual(bitmap.pixelsWide, Int(size.width))
        XCTAssertEqual(bitmap.pixelsHigh, Int(size.height))
        var sampledColors = Set<Int>()
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 16) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 16) {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                    let red = Int(color.redComponent * 255), green = Int(color.greenComponent * 255), blue = Int(color.blueComponent * 255)
                    sampledColors.insert((red << 16) | (green << 8) | blue)
                }
            }
        }
        XCTAssertGreaterThan(sampledColors.count, 12, "Native capture must include cards, text and the beam, not an empty ScrollView surface")
        try png.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
