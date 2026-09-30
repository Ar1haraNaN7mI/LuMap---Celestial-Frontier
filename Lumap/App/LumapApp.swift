import SwiftData
import SwiftUI

@main
struct LumapApp: App {
    @StateObject private var store = LumapStore()
    @StateObject private var database = LumapDatabaseBootstrap()

    // Unit/integration tests construct their own stores. Do not also open the
    // learner's database or start Home's model recommendations in the test host.
    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["LUMAP_TEST_HOST"] == "1"
            || NSClassFromString("XCTestCase") != nil
    }

    var body: some Scene {
        Window("Lumap", id: "main") {
            Group {
                if isTestHost {
                    Color.clear.accessibilityHidden(true)
                } else {
                    LumapLaunchView(database: database)
                        .environmentObject(store)
                        .tint(LumapTheme.accent)
                }
            }
        }
        .defaultSize(width: 1320, height: 820)
        .windowStyle(.titleBar)
        .commands {
            LumapCommands(store: store, database: database)
        }

        MenuBarExtra("Lumap", systemImage: "sparkles") {
            LumapMenuBarView()
                .environmentObject(store)
        }
    }
}

private struct LumapCommands: Commands {
    @ObservedObject var store: LumapStore
    @ObservedObject var database: LumapDatabaseBootstrap
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Learn something new") {
                store.selectedSection = .home
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(!database.isReady)
        }
    }
}

/// Owns the database lifecycle separately from the app scene so a failed open can
/// be retried without terminating Lumap or replacing the user's persistent store.
@MainActor
private final class LumapDatabaseBootstrap: ObservableObject {
    enum Phase {
        case idle
        case opening
        case ready(ModelContainer)
        case failed(LumapDatabaseFailure)
    }

    @Published private(set) var phase: Phase = .idle

    var isReady: Bool {
        if case .ready = phase { return true }
        return false
    }

    func openIfNeeded() {
        guard case .idle = phase else { return }
        open()
    }

    func retry() {
        open()
    }

    private func open() {
        phase = .opening

        do {
            phase = .ready(try LumapPersistence.openCurrentStore())
        } catch {
            phase = .failed(LumapDatabaseFailure(error: error))
        }
    }
}

/// The single persistence entry point. A future versioned schema and migration
/// plan can be introduced here without changing the launch or recovery UI.
private enum LumapPersistence {
    static let storeName = "Lumap"

    static var currentSchema: Schema {
        Schema([
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
    }

    static func openCurrentStore() throws -> ModelContainer {
        let schema = currentSchema
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

private struct LumapDatabaseFailure {
    let summary: String
    let technicalDescription: String

    init(error: Error) {
        summary = (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
        technicalDescription = String(reflecting: error)
    }
}

private struct LumapLaunchView: View {
    @ObservedObject var database: LumapDatabaseBootstrap

    var body: some View {
        Group {
            switch database.phase {
            case .idle, .opening:
                LumapDatabaseOpeningView()
            case let .ready(container):
                AppShellView()
                    .modelContainer(container)
            case let .failed(failure):
                LumapDatabaseRecoveryView(failure: failure) {
                    database.retry()
                }
            }
        }
        .task {
            database.openIfNeeded()
        }
    }
}

private struct LumapDatabaseOpeningView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Opening your learning space…")
                .font(.headline)
            Text("Your learning history stays on this Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumapTheme.canvas)
    }
}

private struct LumapDatabaseRecoveryView: View {
    let failure: LumapDatabaseFailure
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(LumapTheme.accent)

            VStack(spacing: 8) {
                Text("Lumap couldn't open its local database")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Your local learning data remains in place. Lumap did not delete or reset the database.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label(failure.summary, systemImage: "info.circle")
                    .font(.callout)

                DisclosureGroup("Technical details") {
                    Text(failure.technicalDescription)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .font(.callout)
            }
            .padding(18)
            .frame(maxWidth: 620, alignment: .leading)
            .background(LumapTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 12) {
                Button("Quit Lumap") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)

                Button("Retry opening") {
                    retry()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }

            Text("If retrying does not work, close other copies of Lumap and check that this Mac has free storage.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumapTheme.canvas)
    }
}

private struct LumapMenuBarView: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lumap")
                .font(.headline)
            Text(store.personaPrompt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(width: 240, alignment: .leading)
            Divider()
            Button("Open learning space") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Show Persona") {
                PersonaPanelController.shared.show(store: store, reason: "menuBar")
            }
            if store.personaMode == .learning || store.personaMode == .paused {
                Button("Stop learning mode") {
                    store.stopLearningMode()
                }
            }
            Divider()
            Button("Quit Lumap") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
    }
}
