import SwiftData
import SwiftUI

struct MobileNarratedDeckExperienceView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \MaterialRecord.importedAt, order: .reverse) private var materials: [MaterialRecord]
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            NarratedLessonPlayerView(
                topic: store.activeTopic,
                sourceExcerpt: currentMaterial?.excerpt,
                sourceLabel: currentMaterial?.fileName
            ) { artifact in
                do { _ = try store.completeActivity(method: .narratedDeck, artifact: artifact) }
                catch { saveError = error.localizedDescription }
            }
            .padding(18)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
            if let saveError { Text(saveError).foregroundStyle(.red).padding() }
        }
        .background(MobileTheme.background)
        .navigationTitle(store.t("Teaching video", "教学视频"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { try? store.setMethod(.narratedDeck) }
    }

    private var currentMaterial: MaterialRecord? {
        guard let materialID = store.currentGoal?.materialID else { return nil }
        return materials.first { $0.id == materialID }
    }
}
