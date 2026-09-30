import SwiftUI
import WebKit

/// Only our installed, pinned local renderer receives non-secret teaching data.
/// JavaScript cannot make network requests, access Keychain, grade answers or unlock sections.
@MainActor
struct Paper2GalgameWebView {
    var session: Paper2GalgameSession
    var settings: Paper2GalgameSettings
    var onPosition: (String, Int) -> Void
    var onExit: () -> Void
    var onError: (String) -> Void

    static var runtimeURL: URL? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("Paper2Galgame/Runtime/index.html"),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/Runtime/index.html"),
            Bundle.main.resourceURL?.appendingPathComponent("Runtime/index.html")
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "paper2galgame")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        if let index = Self.runtimeURL {
            context.coordinator.allowedRoot = index.deletingLastPathComponent()
            webView.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        }
        return webView
    }

    func update(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.parent = self
        coordinator.sendIfReady()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: Paper2GalgameWebView
        weak var webView: WKWebView?
        var allowedRoot: URL?
        var ready = false
        var deliveredID = ""
        var deliveredSettings: Paper2GalgameSettings?
        init(_ parent: Paper2GalgameWebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  let url = message.frameInfo.request.url, isAllowed(url),
                  let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
            switch action {
            case "ready": ready = true; sendIfReady()
            case "progress":
                guard let payload = body["payload"] as? [String: Any],
                      let id = payload["sessionID"] as? String, id == parent.session.id,
                      let position = payload["position"] as? Int,
                      Paper2GalgameService.validProgress(position: position, session: parent.session) else { return }
                parent.onPosition(id, position)
            case "exit":
                guard let payload = body["payload"] as? [String: Any],
                      let id = payload["sessionID"] as? String, id == parent.session.id else { return }
                parent.onExit()
            default: break
            }
        }

        func sendIfReady() {
            guard ready, deliveredID != parent.session.id || deliveredSettings != parent.settings else { return }
            do {
                let script = try JSONSerialization.jsonObject(with: JSONEncoder().encode(parent.session.script.script))
                var sprites = parent.settings.sprites
                if sprites["normal"] == nil { sprites["normal"] = Self.defaultPortrait }
                let payload: [String: Any] = ["sessionID": parent.session.id, "title": parent.session.script.title,
                    "script": script, "position": parent.session.position, "sprites": sprites,
                    "background": parent.settings.background as Any? ?? NSNull()]
                deliveredID = parent.session.id; deliveredSettings = parent.settings
                webView?.callAsyncJavaScript("window.lumapPaper2GalgameLoad(payload)", arguments: ["payload": payload],
                                              in: nil, in: .page) { [weak self] result in
                    if case .failure(let error) = result { self?.parent.onError(error.localizedDescription) }
                }
            } catch { parent.onError(error.localizedDescription) }
        }

        private func isAllowed(_ url: URL) -> Bool {
            guard url.isFileURL, let root = allowedRoot?.standardizedFileURL.path else { return false }
            return url.standardizedFileURL.path.hasPrefix(root + "/")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, isAllowed(url), navigationAction.targetFrame?.isMainFrame == true else {
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.onError(error.localizedDescription) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.onError(error.localizedDescription) }

        // Original Lumap artwork. No upstream character artwork is distributed or downloaded.
        static var defaultPortrait: String {
            let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" width="500" height="800" viewBox="0 0 500 800"><defs><linearGradient id="coat" x2="1" y2="1"><stop stop-color="#7792b5"/><stop offset="1" stop-color="#283850"/></linearGradient><radialGradient id="halo"><stop stop-color="#e8d8a0" stop-opacity=".7"/><stop offset="1" stop-color="#eedcb3" stop-opacity="0"/></radialGradient></defs><ellipse cx="260" cy="280" rx="240" ry="255" fill="url(#halo)"/><path d="M127 800L145 494Q163 428 246 423Q340 425 359 494L390 800" fill="url(#coat)"/><path d="M216 402L207 455L252 508L286 454L278 401" fill="#ecd1b8"/><ellipse cx="247" cy="286" rx="97" ry="128" fill="#eed8c2"/><path d="M149 334Q92 167 184 147Q272 88 334 169Q372 229 338 344L309 268Q274 264 244 185Q216 257 161 266Z" fill="#273446"/><path d="M136 495L199 453L250 510L197 555L170 518L197 780L145 800Z" fill="#a8bdce"/><path d="M357 495L289 453L250 510L302 555L325 518L302 780L384 800Z" fill="#93a9be"/><ellipse cx="211" cy="290" rx="9" ry="12" fill="#3d526c"/><ellipse cx="282" cy="290" rx="9" ry="12" fill="#3d526c"/><path d="M226 347Q247 360 269 345" stroke="#ae7a67" fill="none" stroke-width="5" stroke-linecap="round"/><circle cx="315" cy="529" r="14" fill="#e4c782"/><path d="M309 529H321M315 523V535" stroke="white" stroke-width="2"/></svg>
            """
            return "data:image/svg+xml;base64," + Data(svg.utf8).base64EncodedString()
        }
    }
}

#if os(macOS)
extension Paper2GalgameWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateNSView(_ nsView: WKWebView, context: Context) { update(nsView, coordinator: context.coordinator) }
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) { nsView.configuration.userContentController.removeScriptMessageHandler(forName: "paper2galgame"); nsView.stopLoading() }
}
#else
extension Paper2GalgameWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView(context: context) }
    func updateUIView(_ uiView: WKWebView, context: Context) { update(uiView, coordinator: context.coordinator) }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) { uiView.configuration.userContentController.removeScriptMessageHandler(forName: "paper2galgame"); uiView.stopLoading() }
}
#endif
