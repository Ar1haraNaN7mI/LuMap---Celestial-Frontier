import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import ImageIO

/// Genuine upstream visual-novel playback inside the existing assessed story activity.
/// The host owns choices, response evaluation and saving; playback never awards progress.
struct Paper2GalgameLearningView: View {
    @EnvironmentObject private var store: LumapStore
    let activity: LearningGeneratedActivity
    @State private var settings = Paper2GalgameSettings()
    @State private var session: Paper2GalgameSession?
    @State private var generation: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var importingDocument = false
    @State private var importingPortrait = false
    @State private var portraitSlot = "normal"
    @State private var supplementalText: String?
    @State private var supplementalTitle: String?
    @State private var playing = true

    private var settingsURL: URL { Paper2GalgameService.storageRoot.appendingPathComponent("settings.json") }
    private var isInstalled: Bool { Paper2GalgameWebView.runtimeURL != nil }
    private var sessionKey: String { "\(store.activePlan?.id ?? "")|\(activity.nodeID)|\(activity.id)|\(store.learningLanguage.rawValue)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "theatermasks.fill").foregroundStyle(.tint)
                Text("Paper2Galgame").font(.headline)
                Spacer()
                Text(store.t("Local integration", "本地集成")).font(.caption).foregroundStyle(.secondary)
            }
            if !isInstalled {
                ContentUnavailableView {
                    Label(store.t("Install the local renderer", "安装本地渲染器"), systemImage: "arrow.down.circle")
                } description: {
                    Text(store.t("Run python3 Paper2Galgame/Scripts/install_runtime.py from the Lumap project, then rebuild. The upstream renderer is downloaded locally; it is not bundled with the public source.", "在 Lumap 项目目录运行 python3 Paper2Galgame/Scripts/install_runtime.py 后重新构建。上游渲染器仅安装到本地，不包含在公开源代码中。"))
                }
                .frame(minHeight: 180)
            } else if let session, playing {
                Paper2GalgameWebView(session: session, settings: settings,
                    onPosition: savePosition, onExit: { playing = false }, onError: { errorMessage = $0 })
                    .frame(height: 490)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                HStack {
                    Text(store.t("Chapter \(session.position + 1) of \(session.script.script.count)", "第 \(session.position + 1) / \(session.script.script.count) 段"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(store.t("Restart chapter", "重播章节")) { restart() }
                        .font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(activity.title).font(.title3.weight(.semibold))
                    Text(store.t("Explore this section through a source-grounded visual novel, then make your decision below.", "通过基于资料的视觉小说探索当前章节，然后在下方做出选择。"))
                        .foregroundStyle(.secondary)
                    if let session {
                        Button(store.t("Resume story · \(session.position + 1)/\(session.script.script.count)", "继续剧情 · \(session.position + 1)/\(session.script.script.count)")) { playing = true }
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            }
            if isGenerating {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(store.t("Writing your \(settings.minimumLines)-scene chapter…", "正在编写 \(settings.minimumLines) 段剧情……")).font(.callout)
                    Spacer()
                    Button(store.t("Stop waiting", "停止等待")) { cancel() }
                }
                Text(store.t("The actual model uses this section's sources. Requests stop within 90 seconds; incomplete scripts can be retried.", "真实模型使用当前章节资料生成。请求将在 90 秒内结束；不完整的剧本可以重试。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            DisclosureGroup(store.t("Story, character & source settings", "剧情、角色与资料设置")) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(store.t("Guide name", "导师名称"), text: $settings.guideName).textFieldStyle(.roundedBorder)
                    HStack {
                        Picker(store.t("Depth", "深度"), selection: $settings.detailLevel) {
                            Text(store.t("Brief · 15 scenes", "简略 · 15 段")).tag("brief")
                            Text(store.t("Detailed · 25 scenes", "详细 · 25 段")).tag("detailed")
                            Text(store.t("Academic · 30 scenes", "学术 · 30 段")).tag("academic")
                        }
                        Picker(store.t("Personality", "性格"), selection: $settings.personality) {
                            Text(store.t("Gentle", "温柔")).tag("gentle")
                            Text(store.t("Playful", "傲娇")).tag("tsundere")
                            Text(store.t("Strict", "严谨")).tag("strict")
                        }
                    }
                    HStack {
                        Picker(store.t("Image", "图片"), selection: $portraitSlot) {
                            ForEach(Paper2GalgameScript.emotions, id: \.self) { Text($0.capitalized).tag($0) }
                            Text(store.t("Background", "背景")).tag("background")
                        }.frame(maxWidth: 240)
                        Button(store.t("Import image", "导入图片"), systemImage: "photo") { importingPortrait = true }
                        Button(store.t("Reset", "重置")) {
                            if portraitSlot == "background" { settings.background = nil } else { settings.sprites.removeValue(forKey: portraitSlot) }
                            saveSettings()
                        }
                    }
                    Text(store.t("Six expressions and your background stay on this device. Missing expressions use the normal portrait.", "六种表情立绘与背景仅保存在此设备；缺少的表情使用默认立绘。"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(store.t("Add PDF or text reference", "添加 PDF 或文本资料"), systemImage: "doc.badge.plus") { importingDocument = true }
                    if let title = supplementalTitle {
                        HStack { Label(title, systemImage: "doc.text").font(.caption); Button(store.t("Remove", "移除")) { supplementalText = nil; supplementalTitle = nil } }
                    }
                    Text(store.t("Uses your Lumap model: \(store.providerModel). Custom endpoint, protocol and API key are managed in Settings; the key stays in Keychain.", "使用 Lumap 模型：\(store.providerModel)。自定义接口、协议与密钥在设置中配置；密钥保留在钥匙串中。"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(store.t("Supplemental material stays within the current objective. Upload a new topic from Home to create a new learning path.", "补充资料用于当前学习目标；如要学习新主题，请从首页上传并创建新路径。"))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 10).disabled(isGenerating)
            }
            HStack {
                Button(session == nil ? store.t("Generate visual novel", "生成视觉小说") : store.t("Regenerate chapter", "重新生成章节"), systemImage: "sparkles") { generate() }
                    .buttonStyle(.borderedProminent).disabled(isGenerating || !isInstalled)
                Spacer()
                Link("Upstream ↗", destination: URL(string: "https://github.com/Nova42x/paper2galgame")!).font(.caption)
            }
            Text(store.t("Reading the story does not complete the section. Your decision and explanation below are assessed before progress is saved.", "阅读剧情不会直接完成章节。下方的选择与解释须经评估并保存后才计入进度。"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: settings) { _, _ in saveSettings() }
        .task(id: sessionKey) { restore(); if session == nil && isInstalled { generate() } }
        .onDisappear { cancel() }
        .fileImporter(isPresented: $importingDocument, allowedContentTypes: [.pdf, .plainText, .text]) { importDocument($0) }
        .fileImporter(isPresented: $importingPortrait, allowedContentTypes: [.image]) { importImage($0) }
    }

    private func generate() {
        guard let configuration = store.providerConfigurationForGeneration(), let plan = store.activePlan else {
            errorMessage = store.t("Configure your model in Settings first.", "请先在设置中配置模型。"); return
        }
        cancel()
        let token = UUID(); requestID = token
        let expectedContext = sessionKey
        let capturedSettings = settings
        isGenerating = true; errorMessage = nil
        generation = Task { @MainActor in
            defer { if requestID == token { isGenerating = false; generation = nil } }
            do {
                let script = try await Paper2GalgameService.generate(activity: activity, sources: plan.sources,
                    supplementalText: supplementalText, settings: capturedSettings,
                    learnerContext: store.learnerContextForGeneration, configuration: configuration)
                try Task.checkCancellation()
                guard requestID == token, sessionKey == expectedContext,
                      store.activeActivity?.id == activity.id else { return }
                let next = Paper2GalgameSession(id: UUID().uuidString, activityID: activity.id,
                    script: script, position: 0, sourceTitle: supplementalTitle, referenceText: supplementalText, languageCode: store.learningLanguage.rawValue, createdAt: .now)
                guard let url = Paper2GalgameService.sessionURL(activityID: activity.id) else { throw LumapAIError.invalidResponse }
                try Paper2GalgameService.save(next, at: url)
                session = next; playing = true
            } catch is CancellationError { }
            catch { if requestID == token { errorMessage = error.localizedDescription } }
        }
    }

    private func cancel() { requestID = UUID(); generation?.cancel(); generation = nil; isGenerating = false }
    private func restore() {
        cancel(); session = nil; errorMessage = nil; supplementalText = nil; supplementalTitle = nil
        settings = Paper2GalgameService.load(Paper2GalgameSettings.self, at: settingsURL) ?? .init()
        if let url = Paper2GalgameService.sessionURL(activityID: activity.id),
           let saved = Paper2GalgameService.load(Paper2GalgameSession.self, at: url), saved.activityID == activity.id, saved.languageCode == store.learningLanguage.rawValue,
           (try? saved.script.validated(minimumLines: 15)) != nil,
           Paper2GalgameService.validProgress(position: saved.position, session: saved) { session = saved; supplementalText = saved.referenceText; supplementalTitle = saved.sourceTitle }
        playing = true
    }
    private func saveSettings() {
        do { try Paper2GalgameService.save(settings, at: settingsURL) }
        catch { errorMessage = error.localizedDescription }
    }
    private func savePosition(_ id: String, _ position: Int) {
        guard var next = session, next.id == id, Paper2GalgameService.validProgress(position: position, session: next),
              let url = Paper2GalgameService.sessionURL(activityID: activity.id), next.position != position else { return }
        next.position = position
        do { try Paper2GalgameService.save(next, at: url); session = next }
        catch { errorMessage = error.localizedDescription }
    }
    private func restart() {
        guard var next = session, let url = Paper2GalgameService.sessionURL(activityID: activity.id) else { return }
        next.id = UUID().uuidString; next.position = 0
        do { try Paper2GalgameService.save(next, at: url); session = next; playing = true }
        catch { errorMessage = error.localizedDescription }
    }
    private func importDocument(_ result: Result<URL, Error>) {
        do {
            let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 12_000_000 else { throw LearningAgentError.invalidOutput("Choose a PDF or text file smaller than 12 MB.") }
            let data = try Data(contentsOf: url)
            let text: String
            if url.pathExtension.lowercased() == "pdf" { text = PDFDocument(data: data)?.string ?? "" }
            else { text = String(data: data, encoding: .utf8) ?? "" }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LearningAgentError.invalidOutput("This document has no readable text. Scanned PDFs need text recognition first.")
            }
            supplementalText = String(text.prefix(20_000)); supplementalTitle = url.lastPathComponent; errorMessage = nil
            if isInstalled { generate() }
        } catch { errorMessage = error.localizedDescription }
    }
    private func importImage(_ result: Result<URL, Error>) {
        do {
            let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 16_000_000 else { throw LearningAgentError.invalidOutput("Choose an image smaller than 16 MB.") }
            let data = try Data(contentsOf: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1_400,
                    kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw LumapAIError.invalidResponse }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { throw LumapAIError.invalidResponse }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw LumapAIError.invalidResponse }
            guard output.length <= 1_500_000 else {
                throw LearningAgentError.invalidOutput("This image is too detailed after resizing. Choose a simpler or smaller portrait (up to 1.5 MB after conversion).")
            }
            let imageURL = "data:image/png;base64," + (output as Data).base64EncodedString()
            if portraitSlot == "background" { settings.background = imageURL } else { settings.sprites[portraitSlot] = imageURL }
            saveSettings()
        } catch { errorMessage = error.localizedDescription }
    }
}
