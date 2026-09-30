import XCTest
import WebKit
import AppKit
@testable import Lumap

@MainActor
final class Paper2GalgameTests: XCTestCase {
    private func fixtureScript(count: Int = 15) -> Paper2GalgameScript {
        .init(title: "A plant's hidden ingredient", script: (0..<count).map { .init(speaker: "Lumi", text: "Scene \($0 + 1): plants fix carbon dioxide into sugars using light energy. [S1]", emotion: "normal", note: nil) })
    }

    func testScriptContractRejectsIncompleteLinesAndInvalidEmotions() throws {
        XCTAssertEqual(try fixtureScript().validated(minimumLines: 15).script.count, 15)
        XCTAssertThrowsError(try fixtureScript(count: 14).validated(minimumLines: 15))
        var invalid = fixtureScript(); invalid.script[0].emotion = "unrecognized"
        XCTAssertThrowsError(try invalid.validated(minimumLines: 15))
        invalid = fixtureScript(); invalid.script[0].speaker = " "
        XCTAssertThrowsError(try invalid.validated(minimumLines: 15))
        XCTAssertThrowsError(try fixtureScript(count: 15).validated(minimumLines: 25))
    }

    func testSessionStorageRejectsPathTraversal() {
        for id in ["../settings", "a/b", "", "..", "a.json"] { XCTAssertNil(Paper2GalgameService.sessionURL(activityID: id)) }
        XCTAssertNotNil(Paper2GalgameService.sessionURL(activityID: UUID().uuidString))
    }

    func testRuntimeProgressCannotEscapeChapter() {
        let chapter = Paper2GalgameSession(id: "session", activityID: "activity", script: fixtureScript(), position: 0, sourceTitle: nil, referenceText: nil, languageCode: "en", createdAt: .now)
        XCTAssertTrue(Paper2GalgameService.validProgress(position: 14, session: chapter))
        XCTAssertFalse(Paper2GalgameService.validProgress(position: 15, session: chapter))
        XCTAssertFalse(Paper2GalgameService.validProgress(position: -1, session: chapter))
    }

    func testCustomImagesAndSettingsContainNoCredentialFields() throws {
        var settings = Paper2GalgameSettings()
        settings.sprites["happy"] = "data:image/png;base64,owned-image"
        let encoded = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        XCTAssertTrue(encoded.contains("owned-image"))
        XCTAssertFalse(encoded.contains("apiKey"))
        XCTAssertFalse(encoded.contains("endpoint"))
    }

    /// Explicitly enabled by root; never incurs provider calls in the default suite.
    /// The source and learner context below are synthetic and safe for a public video.
    func testLivePaper2GalgameGenerationAndRuntimeSnapshot() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let destination = environment["LUMAP_LIVE_PAPER2GALGAME_OUTPUT"], !destination.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_LUMAP_LIVE_PAPER2GALGAME_OUTPUT to a container output directory for live generation and WebKit screenshots.")
        }
        let output = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let index = try XCTUnwrap(Paper2GalgameWebView.runtimeURL, "Run Paper2Galgame/Scripts/install_runtime.py and rebuild first.")
        let activity = LearningGeneratedActivity(id: UUID().uuidString, methodID: "story", nodeID: "plant-carbon",
            title: "The greenhouse mystery", explanation: "Follow Lumi into a greenhouse to discover where a growing plant gets most of its dry mass.",
            prompt: "A seedling gains dry mass while the soil barely changes. Which input accounts for most new carbon? Explain why.",
            steps: ["Weigh the seedling and soil.", "Trace carbon dioxide from air into leaves.", "Use the evidence to explain the new biomass."],
            examples: ["A small greenhouse tomato plant."],
            choices: [.init(id: "air", text: "Carbon dioxide in air", feedback: "Trace the carbon atoms."),
                      .init(id: "soil", text: "Minerals in soil", feedback: "Compare soil mass loss to plant growth."),
                      .init(id: "water", text: "Water only", feedback: "Water contains no carbon atoms.")],
            correctChoiceID: "air", answerExplanation: "Carbon dioxide supplies carbon fixed into sugars during photosynthesis.",
            cards: [], concepts: [], connections: [], hints: [], sourceIDs: ["S1"])
        let source = LearningSource(id: "S1", title: "Synthetic biology teaching notes", url: "",
            excerpt: "Photosynthesis converts light energy into chemical energy. Chlorophyll in chloroplasts absorbs light. Plants use carbon dioxide and water to build sugars and release oxygen. Carbon dioxide from the air supplies carbon for new organic biomass; roots provide water and mineral nutrients but most new dry mass is not taken from soil. The light-dependent reactions provide energy carriers used in carbon fixation. A greenhouse scenario is a teaching simulation, not a measurement.", retrievedAt: .now)
        let script: Paper2GalgameScript
        if let reuse = environment["LUMAP_REUSE_PAPER2GALGAME_SCRIPT"] {
            script = try JSONDecoder().decode(Paper2GalgameScript.self, from: Data(contentsOf: URL(fileURLWithPath: reuse))).validated(minimumLines: 15)
        } else {
            let key = try XCTUnwrap(LumapKeychainStore.read(account: "active-provider"))
            XCTAssertFalse(key.isEmpty)
            let provider = ProviderConfiguration(endpoint: "https://api.ikuncode.cc/v1", model: "gpt-5.6-sol", style: .openAIResponses, apiKey: key)
            script = try await Paper2GalgameService.generate(activity: activity, sources: [source], supplementalText: nil,
                settings: .init(), learnerContext: "Adult beginner; learning language English; interested in houseplants. Prefer a concrete story and causal prediction.", configuration: provider)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(script).write(to: output.appendingPathComponent("Paper2Galgame-Live-Script.json"), options: .atomic)
        var chapter = Paper2GalgameSession(id: UUID().uuidString, activityID: activity.id, script: script, position: 0,
                                           sourceTitle: source.title, referenceText: nil, languageCode: "en", createdAt: .now)
        let settings = Paper2GalgameSettings()
        var reportedPositions: [Int] = []
        var runtimeErrors: [String] = []
        let host = Paper2GalgameWebView(session: chapter, settings: settings, onPosition: { _, position in reportedPositions.append(position) },
                                       onExit: {}, onError: { runtimeErrors.append($0) })
        let coordinator = host.makeCoordinator()
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        config.userContentController.add(coordinator, name: "paper2galgame")
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720), configuration: config)
        let window = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
        // ARC owns this temporary test window. AppKit's default release-on-close
        // otherwise over-releases it when XCTest drains its autorelease pool.
        window.isReleasedWhenClosed = false
        window.contentView = web
        coordinator.webView = web; coordinator.allowedRoot = index.deletingLastPathComponent(); web.navigationDelegate = coordinator
        defer {
            web.stopLoading()
            web.navigationDelegate = nil
            config.userContentController.removeScriptMessageHandler(forName: "paper2galgame")
            coordinator.webView = nil
            window.contentView = nil
            window.close()
        }
        web.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        let deadline = Date.now.addingTimeInterval(20)
        while !coordinator.ready && Date.now < deadline { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertTrue(coordinator.ready, "The local runtime must finish loading and announce ready.")
        try await Task.sleep(for: .milliseconds(700))
        let count = try await web.evaluateJavaScript("document.querySelectorAll('.stage img').length") as? Int
        XCTAssertGreaterThan(count ?? 0, 0, "The actual upstream game must display its owned/custom guide artwork.")
        // Known upstream dialogue stage click first reveals the complete line.
        _ = try await web.evaluateJavaScript("document.querySelector('.stage > .relative')?.click()")
        try await Task.sleep(for: .milliseconds(150))
        try await saveSnapshot(web, to: output.appendingPathComponent("Paper2Galgame-Opening.png"))
        // Load a later point as a new chapter ID using the same native bridge.
        chapter.position = min(5, script.script.count - 1); chapter.id = UUID().uuidString
        coordinator.parent = Paper2GalgameWebView(session: chapter, settings: settings,
            onPosition: { _, position in reportedPositions.append(position) }, onExit: {}, onError: { runtimeErrors.append($0) })
        coordinator.sendIfReady()
        try await Task.sleep(for: .milliseconds(400))
        _ = try await web.evaluateJavaScript("document.querySelector('.stage > .relative')?.click()")
        try await Task.sleep(for: .milliseconds(150))
        try await saveSnapshot(web, to: output.appendingPathComponent("Paper2Galgame-Teaching.png"))
        // Exercise upstream Log control; its heading is visible only in the actual React module.
        let openedHistory = try await web.evaluateJavaScript("[...document.querySelectorAll('button')].find(b=>b.textContent.trim()==='Log')?.click(); true") as? Bool
        XCTAssertEqual(openedHistory, true)
        try await Task.sleep(for: .milliseconds(150))
        let text = try await web.evaluateJavaScript("document.body.innerText") as? String ?? ""
        XCTAssertTrue(text.contains("Dialogue History"))
        try await saveSnapshot(web, to: output.appendingPathComponent("Paper2Galgame-History.png"))
        XCTAssertTrue(runtimeErrors.isEmpty, runtimeErrors.joined(separator: "; "))
        XCTAssertTrue(reportedPositions.contains(5))
        let report: [String: Any] = ["runtime": "upstream GameScreen.tsx", "revision": "da60826012493b16872add56d6c6d412197e6f1c",
            "lineCount": script.script.count, "ready": coordinator.ready, "historyOpened": text.contains("Dialogue History"),
            "persistedPositionBridgeObserved": reportedPositions.contains(5), "sourceType": "synthetic teaching notes",
            "generationMode": environment["LUMAP_REUSE_PAPER2GALGAME_SCRIPT"] == nil ? "live-provider" : "reused-script-fixture",
            "credentialsSentToWebView": false]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Paper2Galgame-Verification.json"))
    }

    private func saveSnapshot(_ web: WKWebView, to url: URL) async throws {
        let image = try await web.takeSnapshot(configuration: nil)
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url, options: .atomic)
    }
}
