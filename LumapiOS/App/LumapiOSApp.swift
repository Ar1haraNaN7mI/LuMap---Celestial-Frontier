import SwiftData
import SwiftUI

@main
struct LumapiOSApp: App {
    @StateObject private var store = LumapStore()

    var body: some Scene {
        WindowGroup {
            MobileDatabaseLaunchView()
                .environmentObject(store)
                .tint(MobileTheme.accent)
        }
    }
}

private struct MobileDatabaseLaunchView: View {
    @State private var container: ModelContainer?
    @State private var opening = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let container {
                LumapiOSRootView()
                    .modelContainer(container)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Lumap couldn't open its learning data", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") {
                        Task { await openDatabase() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Opening your learning map…")
                        .font(.headline)
                    Text("Your progress stays on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MobileTheme.background)
            }
        }
        .task { await openDatabase() }
    }

    @MainActor
    private func openDatabase() async {
        guard !opening else { return }
        opening = true
        errorMessage = nil
        defer { opening = false }

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

        do {
            let configuration = ModelConfiguration("Lumap", schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
