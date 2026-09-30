import AppKit
import SwiftUI

@MainActor
final class PersonaPanelController: NSObject {
    static let shared = PersonaPanelController()

    private weak var mainWindow: NSWindow?
    private var panel: NSPanel?
    private weak var store: LumapStore?

    func bind(mainWindow: NSWindow, store: LumapStore) {
        guard self.mainWindow !== mainWindow else { return }
        if let previous = self.mainWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMiniaturizeNotification, object: previous)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didDeminiaturizeNotification, object: previous)
        }
        self.mainWindow = mainWindow
        self.store = store
        NotificationCenter.default.addObserver(self, selector: #selector(didMiniaturize), name: NSWindow.didMiniaturizeNotification, object: mainWindow)
        NotificationCenter.default.addObserver(self, selector: #selector(didDeminiaturize), name: NSWindow.didDeminiaturizeNotification, object: mainWindow)
    }

    func show(store incomingStore: LumapStore? = nil, reason: String) {
        if let incomingStore {
            store = incomingStore
        }
        guard let store else { return }
        let panel = panel ?? makePanel(store: store)
        self.panel = panel
        if panel.frame.origin == .zero {
            position(panel)
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func minimizeMainWindow(store: LumapStore) {
        self.store = store
        guard let mainWindow = resolvedMainWindow() else {
            show(store: store, reason: "preview")
            return
        }
        bind(mainWindow: mainWindow, store: store)
        mainWindow.miniaturize(nil)
        DispatchQueue.main.async { [weak self] in
            if !mainWindow.isMiniaturized {
                mainWindow.orderOut(nil)
            }
            self?.show(store: store, reason: "preview")
        }
    }

    func restoreMainWindow() {
        guard let mainWindow = resolvedMainWindow() else { return }
        if mainWindow.isMiniaturized { mainWindow.deminiaturize(nil) }
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        hide()
    }

    @objc private func didMiniaturize(_ notification: Notification) {
        show(reason: "minimize")
    }

    @objc private func didDeminiaturize(_ notification: Notification) {
        hide()
    }

    private func makePanel(store: LumapStore) -> NSPanel {
        let content = PersonaFloatingView()
            .environmentObject(store)
        let host = NSHostingView(rootView: content)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 292, height: 184),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let frameName = "LumapPersonaPanel"
        let restoredSavedFrame = panel.setFrameUsingName(frameName)
        panel.setFrameAutosaveName(frameName)
        if !restoredSavedFrame {
            position(panel)
        }
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let visible = (mainWindow?.screen ?? NSScreen.main)?.visibleFrame else { return }
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - 24,
            y: visible.minY + 36
        )
        panel.setFrameOrigin(origin)
    }

    private func resolvedMainWindow() -> NSWindow? {
        if let mainWindow { return mainWindow }
        return NSApp.windows.first { window in
            !(window is NSPanel) && window.isVisible
        }
    }
}

struct MainWindowBridge: NSViewRepresentable {
    @ObservedObject var store: LumapStore

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { bind(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { bind(nsView) }
    }

    private func bind(_ view: NSView) {
        if let window = view.window {
            PersonaPanelController.shared.bind(mainWindow: window, store: store)
        }
    }
}

private struct PersonaFloatingView: View {
    @EnvironmentObject private var store: LumapStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: personaColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Lumi")
                        .font(.headline)
                    Spacer()
                    Button {
                        PersonaPanelController.shared.hide()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                Text(store.personaPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                HStack {
                    Button("Open Lumap") {
                        PersonaPanelController.shared.restoreMainWindow()
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        store.nextPersonaNudge()
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 292, height: 184)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
    }

    private var personaColors: [Color] {
        switch store.profile?.personaStyle {
        case "Solar": [LumapTheme.gold, LumapTheme.coral]
        case "Forest": [LumapTheme.mint, LumapTheme.cyan]
        case "Midnight": [.indigo, .purple]
        default: [LumapTheme.accent, LumapTheme.cyan]
        }
    }
}
