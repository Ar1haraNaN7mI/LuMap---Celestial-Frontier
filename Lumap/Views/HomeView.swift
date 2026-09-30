import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LumapStore
    @Query(sort: \InterestEvidence.createdAt, order: .reverse) private var interests: [InterestEvidence]
    @Query(sort: \SourceRecord.createdAt, order: .reverse) private var sources: [SourceRecord]
    @State private var topic = ""
    @State private var profileURL = ""
    @State private var errorMessage: String?
    @State private var showingProfile = false
    @State private var showsPersonalization = false

    private var recommendations: [Recommendation] {
        store.recommendations(interests: interests)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 44) {
                learningPrompt
                suggestions
                personalization
            }
            .padding(.horizontal, LumapTheme.pagePadding)
            .padding(.top, 68)
            .padding(.bottom, 40)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .task(id: store.recommendationContextRevision) { await store.refreshPersonalizedRecommendations() }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.selectedSection = .profile
                } label: {
                    Label("\(store.rewardBalance) Lumens", systemImage: "sparkles")
                }
                .help(store.t("Open your personal learning space", "打开个人学习空间"))

                Button {
                    showingProfile = true
                } label: {
                    Label(store.profile?.displayName ?? "Profile", systemImage: "person.crop.circle")
                }
                .help(store.t("Edit Profile", "编辑档案"))
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileSheet()
                .environmentObject(store)
        }
    }

    private var learningPrompt: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LumapTheme.pathGradient)
                    .frame(width: 52, height: 52)
                    .blur(radius: 16)
                    .opacity(0.48)
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(LumapTheme.pathGradient, in: Circle())
            }
            .accessibilityHidden(true)

            VStack(spacing: 9) {
                Text(store.t("What do you want to learn today?", "你今天想学什么？"))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LumapTheme.ink)
                Text(store.t(
                    "Start anywhere. Lumap will ask, adapt and uncover the path with you.",
                    "从任何想法开始。Lumap 会通过提问与适应，和你一起找到真正想学的路径。"
                ))
                .font(.body)
                .foregroundStyle(LumapTheme.secondaryInk)
                .multilineTextAlignment(.center)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    store.t("Ask about an idea, skill or question…", "输入一个想法、技能或问题……"),
                    text: $topic,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.title3)
                .lineLimit(1...5)
                .onSubmit(startTopic)
                .accessibilityLabel(store.t("Learning goal", "学习目标"))

                Button(action: startTopic) {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(topic.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 ? LumapTheme.accent : Color.secondary.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(topic.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(store.t("Start learning", "开始学习"))
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 11)
            .frame(maxWidth: 760, minHeight: 62)
            .background(LumapTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LumapTheme.accent.opacity(0.26), lineWidth: 1)
            }
            .shadow(color: LumapTheme.accent.opacity(0.10), radius: 22, y: 10)

            Button {
                store.selectedSection = .library
            } label: {
                Label(store.t("Learn from an uploaded text", "想学习上传的文本"), systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(LumapTheme.coral)
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.t("You might want to learn", "猜你想学"))
                        .font(.headline)
                    Text(store.suggestedTopics.isEmpty
                        ? store.t("Starter ideas. Share interests to personalise your suggestions.", "探索灵感。分享并确认兴趣后，推荐会更加贴近你。")
                        : store.t("Recommended from your confirmed interests and learning evidence.", "根据已确认兴趣与学习证据推荐。"))
                        .font(.caption)
                        .foregroundStyle(LumapTheme.secondaryInk)
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        store.nextRecommendationBatch()
                    }
                } label: {
                    Label(store.t("Not interested · refresh", "不感兴趣 · 换一批"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshingRecommendations)
                if store.isRefreshingRecommendations { ProgressView().controlSize(.small) }
            }
            if let error = store.recommendationError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 10)], spacing: 10) {
                ForEach(recommendations) { recommendation in
                    SuggestionTile(recommendation: recommendation) {
                        topic = recommendation.title
                        startTopic()
                    }
                }
            }
        }
        .frame(maxWidth: 880)
    }

    private var personalization: some View {
        DisclosureGroup(isExpanded: $showsPersonalization) {
            VStack(alignment: .leading, spacing: 14) {
                Text(store.t(
                    "Paste your own public profile link to preview possible interests. This build validates the link and creates a local sample; it does not visit the page.",
                    "粘贴你自己的公开主页链接来预览可能的兴趣。当前版本只校验链接并在本地生成样例，不会访问网页。"
                ))
                .font(.subheadline)
                .foregroundStyle(LumapTheme.secondaryInk)

                ViewThatFits(in: .horizontal) {
                    HStack { profileLinkField; analyzeButton }
                    VStack(alignment: .leading) { profileLinkField; analyzeButton }
                }

                if let message = store.sourceStatusMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(LumapTheme.secondaryInk)
                }

                if !interests.isEmpty {
                    InterestTags(interests: interests) { errorMessage = $0 }
                }

                if !sources.isEmpty {
                    Divider()
                    ForEach(sources.prefix(3)) { source in
                        HStack(spacing: 10) {
                            LumapIconTile(icon: "globe", tint: LumapTheme.cyan, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.displayName).font(.subheadline.weight(.semibold))
                                Text(source.coverageNote).font(.caption).foregroundStyle(LumapTheme.secondaryInk)
                            }
                            Spacer()
                            Text(source.isDemo ? store.t("Local preview", "本地预览") : source.status.capitalized)
                                .font(.caption)
                                .foregroundStyle(LumapTheme.secondaryInk)
                        }
                    }
                }
            }
            .padding(.top, 14)
        } label: {
            HStack {
                Label(store.t("Tune my suggestions", "调整我的推荐"), systemImage: "slider.horizontal.2.square")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(store.t("Optional · local", "可选 · 本地"))
                    .font(.caption)
                    .foregroundStyle(LumapTheme.secondaryInk)
            }
        }
        .padding(15)
        .frame(maxWidth: 880)
        .background(LumapTheme.mutedSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: LumapTheme.cardRadius, style: .continuous))
    }

    private var profileLinkField: some View {
        TextField("https://…", text: $profileURL)
            .textFieldStyle(.roundedBorder)
    }

    private var analyzeButton: some View {
        Button {
            Task {
                do {
                    try await store.analyzePublicProfile(profileURL)
                    profileURL = ""
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            if store.isAnalyzingSource {
                ProgressView().controlSize(.small)
            } else {
                Label(store.t("Preview interests", "预览兴趣"), systemImage: "link.badge.plus")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(store.isAnalyzingSource || profileURL.isEmpty)
    }

    private func startTopic() {
        do {
            try store.startLearning(topic: topic)
            topic = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SuggestionTile: View {
    @State private var isHovered = false
    let recommendation: Recommendation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                LumapIconTile(icon: recommendation.icon, tint: Color.lumap(named: recommendation.tint), size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LumapTheme.ink)
                        .lineLimit(1)
                    Text(recommendation.reason)
                        .font(.caption)
                        .foregroundStyle(LumapTheme.secondaryInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(isHovered ? LumapTheme.accent.opacity(0.07) : LumapTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isHovered ? LumapTheme.accent.opacity(0.30) : LumapTheme.border, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

private struct InterestTags: View {
    @EnvironmentObject private var store: LumapStore
    let interests: [InterestEvidence]
    let onError: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
            ForEach(interests) { interest in
                HStack(spacing: 8) {
                    Image(systemName: interest.status == "confirmed" ? "checkmark.circle.fill" : "sparkles")
                        .foregroundStyle(interest.status == "confirmed" ? LumapTheme.mint : LumapTheme.accent)
                    Text(interest.topic)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    if interest.status != "confirmed" {
                        Button {
                            do { try store.confirmInterest(interest) }
                            catch { onError(error.localizedDescription) }
                        } label: {
                            Image(systemName: "checkmark").frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(store.t("Confirm \(interest.topic)", "确认 \(interest.topic)"))
                    }
                    Button(role: .destructive) {
                        do { try store.removeInterest(interest) }
                        catch { onError(error.localizedDescription) }
                    } label: {
                        Image(systemName: "xmark").frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.t("Remove \(interest.topic)", "移除 \(interest.topic)"))
                }
                .padding(10)
                .background(LumapTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct ProfileSheet: View {
    @EnvironmentObject private var store: LumapStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var ageBand = "Unknown"
    @State private var background = ""
    @State private var minutes = 20
    @State private var errorMessage: String?

    private let ageBands = ["Unknown", "Under 13", "13–17", "18–24", "25–39", "40–59", "60+"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: store.t("Profile", "个人档案"),
                title: store.t("A little context, on your terms", "由你决定提供多少背景"),
                subtitle: store.t("Every field is optional. Age remains context for future content boundaries; it never becomes an ability score.", "所有字段都可以跳过。年龄只为未来内容边界提供背景，不会成为能力分数。")
            )
            Form {
                TextField(store.t("Display Name", "显示名称"), text: $name)
                Picker(store.t("Age Band", "年龄段"), selection: $ageBand) {
                    ForEach(ageBands, id: \.self) { Text($0).tag($0) }
                }
                TextField(store.t("Background or Goals", "背景或目标"), text: $background, axis: .vertical)
                    .lineLimit(3...5)
                Stepper(store.t("Typical session: \(minutes) minutes", "常用学习时长：\(minutes) 分钟"), value: $minutes, in: 5...240, step: 5)
            }
            .formStyle(.grouped)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(LumapTheme.coral).font(.caption)
            }
            HStack {
                Spacer()
                Button(store.t("Cancel", "取消")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(store.t("Save locally", "保存到本地")) {
                    do {
                        try store.saveProfile(displayName: name, ageBand: ageBand, background: background, availableMinutes: minutes)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
        .onAppear {
            name = store.profile?.displayName ?? ""
            ageBand = store.profile?.ageBand ?? "Unknown"
            background = store.profile?.background ?? ""
            minutes = store.profile?.availableMinutes ?? 20
        }
    }
}
