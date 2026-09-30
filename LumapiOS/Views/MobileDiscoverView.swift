import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MobileDiscoverView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \InterestEvidence.createdAt, order: .reverse) private var interests: [InterestEvidence]
    @State private var topic = ""
    @State private var errorMessage: String?
    @State private var showingImporter = false
    @State private var isImporting = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 34) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(MobileTheme.gradient)
                            .frame(width: 48, height: 48)
                            .blur(radius: 14)
                            .opacity(0.42)
                        Image(systemName: "sparkles")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(MobileTheme.gradient, in: Circle())
                    }
                    .accessibilityHidden(true)

                    Text(store.t("What do you want to learn today?", "你今天想学什么？"))
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(store.t(
                        "Start anywhere. Lumap will uncover the path with you.",
                        "从任何想法开始，Lumap 会和你一起发现学习路径。"
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField(
                            store.t("Ask about an idea, skill or question…", "输入一个想法、技能或问题……"),
                            text: $topic,
                            axis: .vertical
                        )
                        .textFieldStyle(.plain)
                        .font(.body)
                        .lineLimit(1...4)
                        .submitLabel(.go)
                        .onSubmit(startTopic)
                        .accessibilityLabel(store.t("Learning goal", "学习目标"))

                        Button(action: startTopic) {
                            Image(systemName: "arrow.up")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(
                                    topic.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
                                        ? MobileTheme.accent
                                        : Color.secondary.opacity(0.35),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                        .accessibilityLabel(store.t("Start learning", "开始学习"))
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 9)
                    .padding(.vertical, 10)
                    .frame(minHeight: 60)
                    .background(MobileTheme.raisedCard, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .stroke(MobileTheme.accent.opacity(0.24), lineWidth: 1)
                    }
                    .shadow(color: MobileTheme.accent.opacity(0.09), radius: 18, y: 8)

                    Button {
                        showingImporter = true
                    } label: {
                        if isImporting {
                            HStack { ProgressView(); Text(store.t("Importing…", "正在导入……")) }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        } else {
                            Label(store.t("Learn from Uploaded Text", "从上传资料开始学习"), systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(store.t("Ideas for you", "猜你想学"))
                            .font(.headline)
                        Spacer()
                        Button {
                            withAnimation(.snappy) { store.nextRecommendationBatch() }
                        } label: {
                            Label(store.t("Not interested · refresh", "不感兴趣 · 换一批"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .disabled(store.isRefreshingRecommendations)
                        if store.isRefreshingRecommendations { ProgressView().controlSize(.small) }
                    }
                    if let error = store.recommendationError { Text(error).font(.caption).foregroundStyle(.secondary) }

                    ForEach(store.recommendations(interests: interests)) { recommendation in
                        Button {
                            do { try store.startLearning(topic: recommendation.title) } catch { errorMessage = error.localizedDescription }
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: recommendation.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MobileTheme.color(named: recommendation.tint))
                                    .frame(width: 34, height: 34)
                                    .background(
                                        MobileTheme.color(named: recommendation.tint).opacity(0.11),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recommendation.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(recommendation.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 6)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(11)
                            .background(MobileTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(MobileTheme.border.opacity(0.45), lineWidth: 0.5)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 42)
            .padding(.bottom, 24)
        }
        .background(MobileTheme.background)
        .task(id: store.recommendationContextRevision) { await store.refreshPersonalizedRecommendations() }
        .navigationTitle("Lumap")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .plainText, .json, .commaSeparatedText, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                if case let .failure(error) = result { errorMessage = error.localizedDescription }
                return
            }
            Task { await importMaterial(url) }
        }
        .alert(store.t("Couldn't start this topic", "无法开始这个主题"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startTopic() {
        do {
            try store.startLearning(topic: topic)
            topic = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importMaterial(_ url: URL) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let material = try await store.importMaterial(from: url)
            let fileTopic = url.deletingPathExtension().lastPathComponent
            try store.startLearning(
                topic: fileTopic.isEmpty ? material.fileName : fileTopic,
                materialID: material.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
