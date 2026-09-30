import SwiftUI
import UniformTypeIdentifiers

/// One production player shared by macOS and iOS. Playback completion, rather
/// than a wall-clock timer, advances slides and opens relevant retrieval checks.
struct NarratedLessonPlayerView: View {
    @EnvironmentObject private var store: LumapStore
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    let topic: String
    let sourceExcerpt: String?
    let sourceLabel: String?
    let complete: (String) -> Void

    @StateObject private var narration = NarrationSession.makeDefault()
    @State private var deck: NarratedLearningDeck?
    @State private var modelID = ""
    @State private var slideIndex = 0
    @State private var narratedSlides: Set<Int> = []
    @State private var quizResults: [String: NarratedDeckQuizResult] = [:]
    @State private var pendingQuiz: NarratedDeckQuiz?
    @State private var selectedOption: String?
    @State private var autoplay = false
    @State private var generationError: String?
    @State private var retryNonce = 0
    @State private var didSave = false
    @State private var completionError: String?
    @State private var exportTask: Task<Void, Never>?
    @State private var exportRequestID = UUID()
    @State private var exportProgress: Double = 0
    @State private var exportStatus: String?
    @State private var exportError: String?
    @State private var exportedVideo: URL?
    @State private var exportDocument: LessonExportDocument?
    @State private var exportType: UTType = .plainText
    @State private var showExport = false
    private var exportFilename: String {
        if exportType == .mpeg4Movie { return "Lumap-teaching-video.mp4" }
        if exportType == LessonExportDocument.powerPoint { return "Lumap-learning-slides.pptx" }
        return "Lumap-teaching-script.txt"
    }

    private var chinese: Bool { store.learningLanguage == .simplifiedChinese }
    private func text(_ english: String, _ chinese: String) -> String { store.learningText(english, chinese) }
    private var generationKey: String {
        "\(store.activePlan?.id ?? "")|\(store.currentLearningNode?.id ?? "")|\(topic)|\(sourceLabel ?? "")|\((store.lessonSourceText ?? sourceExcerpt)?.hashValue ?? 0)|\(store.learningLanguage.rawValue)|\(retryNonce)"
    }
    private var slideAspectRatio: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? 0.78 : 1.6
        #else
        return 1.6
        #endif
    }
    private var trustedSourceLabel: String? {
        let sources = store.activePlan?.sources.map { "[\($0.id)] \($0.title) — \($0.url)" }.joined(separator: "\n")
        return (sources?.isEmpty == false ? sources : nil) ?? sourceLabel
    }
    private var voiceReady: Bool {
        if case .ready = narration.availability { return true }
        return false
    }
    private var activePlayback: Bool { [.preparing, .playing].contains(narration.playbackState) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let deck {
                header(deck)
                NarratedSlideStage(slide: deck.slides[slideIndex], total: deck.slides.count, progress: narration.progress)
                    .aspectRatio(slideAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel("\(slideIndex + 1) / \(deck.slides.count): \(deck.slides[slideIndex].title)")
                chapterPicker(deck)
                playerControls(deck)
                if let quiz = pendingQuiz { quizCard(quiz) }
                if !voiceReady {
                    Label(text("Install the Kokoro voice pack in Settings to play or export full narration. The complete script is available below.", "请在设置中安装 Kokoro 语音包，以播放或导出完整讲解。完整教学稿可在下方查看。"), systemImage: "waveform.badge.exclamationmark")
                        .font(.callout).foregroundStyle(.orange)
                }
                DisclosureGroup(text("Complete teaching script · all \(deck.slides.count) slides", "完整教学稿 · 共 \(deck.slides.count) 页")) {
                    Text(deck.teachingScript).font(.callout).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                }
                exportControls(deck)
                if let exportError { Text(exportError).font(.caption).foregroundStyle(.red) }
                if let completionError { Text(completionError).font(.caption).foregroundStyle(.red) }
                HStack {
                    Button(didSave ? text("Learning evidence saved", "学习证据已保存") : text("Save completed lesson", "保存完成的课程")) {
                        let artifact = NarratedDeckSessionArtifact(
                            deckTitle: deck.title, slideSummaries: deck.slides.map(\.summary),
                            narratedSlideNumbers: narratedSlides.sorted(), narrationStatus: .completed,
                            quizResults: quizResults.values.sorted { $0.quizID < $1.quizID }
                        )
                        do {
                            try store.recordNarratedLessonOutcome(deck: deck, narratedSlideNumbers: narratedSlides.sorted(),
                                                                  quizResults: quizResults.values.sorted { $0.quizID < $1.quizID })
                            complete(artifact.activityText(languageCode: store.learningLanguage.rawValue))
                            didSave = true
                            completionError = nil
                        } catch { completionError = error.localizedDescription }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(didSave || narratedSlides.count != deck.slides.count || quizResults.count < deck.slides.compactMap(\.quiz).count)
                    Spacer()
                    Text(text("\(narratedSlides.count)/\(deck.slides.count) listened · \(quizResults.count) checks", "已完整听取 \(narratedSlides.count)/\(deck.slides.count) 页 · \(quizResults.count) 次检测"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if let generationError {
                VStack(alignment: .leading, spacing: 12) {
                    Label(text("The lesson needs another attempt", "课程生成需要重试"), systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    Text(generationError).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    Button(text("Retry real AI generation", "重试 AI 实时生成")) { retryNonce += 1 }.buttonStyle(.borderedProminent)
                }.padding(24).frame(maxWidth: .infinity, minHeight: 240, alignment: .leading)
            } else {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large)
                    Text(text("Writing your complete lesson", "正在编排完整课程")).font(.title3.weight(.semibold))
                    Text(text("The AI is turning your research and learner profile into six teaching slides, complete narration and topic-specific quizzes. This may take a few minutes.", "AI 正在依据检索资料和你的学习画像编排六页课件、完整教学讲稿及主题专属小测，可能需要几分钟。"))
                        .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 510)
                }.padding(24).frame(maxWidth: .infinity, minHeight: 260)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if store.currentMethod != .narratedDeck { try? store.setMethod(.narratedDeck) }
        }
        .task(id: generationKey) { await generate() }
        .onChange(of: narration.playbackState) { _, state in playbackChanged(state) }
        .onDisappear {
            autoplay = false
            narration.stop()
            cancelExport()
        }
        .fileExporter(isPresented: $showExport, document: exportDocument, contentType: exportType,
                      defaultFilename: exportFilename) { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
    }

    private func header(_ deck: NarratedLearningDeck) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(text("AI LESSON · \(deck.slides.count) CHAPTERS", "AI 课程 · \(deck.slides.count) 个章节"), systemImage: "play.rectangle.fill")
                .font(.caption.weight(.bold)).foregroundStyle(.indigo)
            Text(deck.title).font(.title2.weight(.semibold))
            Text(deck.subtitle).font(.callout).foregroundStyle(.secondary)
            Text("\(modelID) · Kokoro · \(deck.slides.compactMap(\.quiz).count) quizzes")
                .font(.caption).foregroundStyle(.secondary)
            if let sourceLabel = deck.sourceLabel, !sourceLabel.isEmpty {
                Text(sourceLabel).font(.caption2).foregroundStyle(.secondary).lineLimit(3).textSelection(.enabled)
            }
        }
    }

    private func chapterPicker(_ deck: NarratedLearningDeck) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(deck.slides.enumerated()), id: \.element.id) { index, slide in
                    Button { seek(index) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: narratedSlides.contains(slide.index) ? "checkmark.circle.fill" : "circle")
                            Text("\(slide.index). \(slide.title)").lineLimit(1)
                        }
                        .font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 10)
                        .foregroundStyle(slideIndex == index ? Color.white : Color.primary)
                        .background(slideIndex == index ? Color.indigo : Color.secondary.opacity(0.10), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func playerControls(_ deck: NarratedLearningDeck) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: narration.progress).tint(.indigo)
            HStack(spacing: 12) {
                Button { seek(slideIndex - 1) } label: { Image(systemName: "backward.end.fill") }
                    .disabled(slideIndex == 0).accessibilityLabel(text("Previous chapter", "上一章"))
                Button { togglePlayback() } label: {
                    Label(activePlayback ? text("Pause", "暂停") : text("Play lesson", "播放课程"), systemImage: activePlayback ? "pause.fill" : "play.fill")
                        .frame(minHeight: 26)
                }.buttonStyle(.borderedProminent).disabled(!voiceReady || pendingQuiz != nil)
                Button { seek(slideIndex + 1) } label: { Image(systemName: "forward.end.fill") }
                    .disabled(slideIndex + 1 == deck.slides.count).accessibilityLabel(text("Next chapter", "下一章"))
                Button { autoplay = false; narration.stop() } label: { Image(systemName: "stop.fill") }
                    .accessibilityLabel(text("Stop", "停止"))
                Spacer(minLength: 0)
                Button { narration.setMuted(!narration.isMuted) } label: {
                    Image(systemName: narration.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }.accessibilityLabel(text("Toggle mute", "切换静音"))
            }.buttonStyle(.bordered)
            Text(playbackStatus).font(.caption).foregroundStyle(narration.playbackState == .failed ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var playbackStatus: String {
        if pendingQuiz != nil { return text("Checkpoint: finish the question to continue.", "检测点：完成问题后继续。") }
        switch narration.playbackState {
        case .preparing: return text("Generating the complete Kokoro narration for this chapter…", "正在生成本章完整 Kokoro 讲解音频……")
        case .playing: return text("Playing full narration · the next chapter starts automatically", "正在播放完整讲解 · 完成后自动进入下一章")
        case .paused: return text("Paused · resumes from the same position", "已暂停 · 将从原位置继续")
        case .failed: return text("Audio generation failed. Press play to retry; the script is preserved.", "音频生成失败。点击播放重试；教学稿已保留。")
        case .completed: return text("Chapter complete", "本章播放完成")
        default: return text("Play the entire lesson with retrieval checks between chapters.", "连续播放完整课程，并在章节间进行回忆检测。")
        }
    }

    private func quizCard(_ quiz: NarratedDeckQuiz) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text("Pause & retrieve", "暂停，回忆一下"), systemImage: "brain.head.profile").font(.headline)
            Text(quiz.prompt).font(.body.weight(.medium))
            ForEach(quiz.options) { option in
                Button {
                    guard selectedOption == nil else { return }
                    selectedOption = option.id
                    quizResults[quiz.id] = .init(quizID: quiz.id, selectedOptionID: option.id, wasCorrect: option.id == quiz.correctOptionID)
                } label: {
                    HStack {
                        Image(systemName: selectedOption == option.id ? "checkmark.circle.fill" : "circle")
                        Text(option.text).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if selectedOption != nil, option.id == quiz.correctOptionID { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.bordered).disabled(selectedOption != nil)
            }
            if let selectedOption {
                Text(selectedOption == quiz.correctOptionID ? text("Correct — \(quiz.explanation)", "正确 — \(quiz.explanation)") : quiz.explanation)
                    .font(.callout).foregroundStyle(.secondary)
                Button(text("Continue the lesson", "继续课程")) {
                    pendingQuiz = nil
                    self.selectedOption = nil
                    advance()
                }.buttonStyle(.borderedProminent)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func exportControls(_ deck: NarratedLearningDeck) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack { presentationButton(deck); scriptButton(deck); videoButton(deck) }
                VStack(alignment: .leading) { presentationButton(deck); scriptButton(deck); videoButton(deck) }
            }
            if exportTask != nil {
                ProgressView(value: exportProgress)
                HStack {
                    Text(exportStatus ?? "").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(text("Cancel", "取消")) { cancelExport() }.font(.caption)
                }
            }
            if let exportedVideo {
                HStack {
                    Button {
                        do {
                            exportDocument = LessonExportDocument(data: try Data(contentsOf: exportedVideo))
                            exportType = .mpeg4Movie
                            showExport = true
                        } catch { exportError = error.localizedDescription }
                    } label: { Label(text("Save MP4", "保存 MP4"), systemImage: "square.and.arrow.down") }
                    ShareLink(item: exportedVideo) { Label(text("Share video", "分享视频"), systemImage: "square.and.arrow.up") }
                }.buttonStyle(.borderedProminent)
            }
        }
    }

    private func presentationButton(_ deck: NarratedLearningDeck) -> some View {
        Button {
            do {
                exportDocument = LessonExportDocument(data: try LessonPresentationExporter.data(deck: deck))
                exportType = LessonExportDocument.powerPoint
                showExport = true
            } catch { exportError = error.localizedDescription }
        } label: { Label(text("Export editable PPTX", "导出可编辑 PPTX"), systemImage: "rectangle.on.rectangle") }
            .buttonStyle(.bordered)
    }

    private func scriptButton(_ deck: NarratedLearningDeck) -> some View {
        Button {
            exportDocument = LessonExportDocument(data: Data(deck.teachingScript.utf8))
            exportType = .plainText
            showExport = true
        } label: { Label(text("Export teaching script", "导出完整教学稿"), systemImage: "doc.text") }.buttonStyle(.bordered)
    }

    private func videoButton(_ deck: NarratedLearningDeck) -> some View {
        Button {
            autoplay = false
            narration.stop()
            exportError = nil
            exportedVideo = nil
            exportProgress = 0
            exportStatus = text("Preparing full audio…", "正在准备完整音频……")
            let requestID = UUID()
            exportRequestID = requestID
            exportTask = Task { @MainActor in
                defer { if exportRequestID == requestID { exportTask = nil } }
                do {
                    let url = try await LessonVideoExporter.export(deck: deck, languageCode: store.learningLanguage.rawValue) { value, status in
                        guard exportRequestID == requestID else { return }
                        exportProgress = value; exportStatus = status
                    }
                    guard !Task.isCancelled, exportRequestID == requestID else { return }
                    exportedVideo = url
                } catch is CancellationError {
                    return
                } catch { if exportRequestID == requestID { exportError = error.localizedDescription } }
            }
        } label: { Label(text("Create narrated MP4", "生成完整讲解视频 MP4"), systemImage: "film") }
            .buttonStyle(.bordered).disabled(!voiceReady || exportTask != nil)
    }

    private func cancelExport() {
        exportRequestID = UUID()
        exportTask?.cancel()
        exportTask = nil
        exportStatus = nil
    }

    private func generate() async {
        cancelExport()
        exportedVideo = nil
        exportError = nil
        autoplay = false
        narration.stop()
        deck = nil
        pendingQuiz = nil
        selectedOption = nil
        quizResults = [:]
        narratedSlides = []
        didSave = false
        completionError = nil
        generationError = nil
        do {
            let outcome = try await NarratedDeckGenerationCoordinator(configuration: store.providerConfigurationForGeneration())
                .generate(.init(topic: store.currentLearningNode?.title ?? topic, sourceMaterial: store.lessonSourceText ?? sourceExcerpt, sourceLabel: trustedSourceLabel,
                                languageCode: store.learningLanguage.rawValue,
                                learnerContext: store.learnerContextForGeneration + "\nOverall goal (context only): " + topic + "\nTeach only this section. Lesson objective: " + (store.currentLearningNode?.objective ?? topic), maximumSlideCount: 6,
                                courseID: store.activePlan?.id, nodeID: store.currentLearningNode?.id), useCache: retryNonce == 0)
            try Task.checkCancellation()
            slideIndex = 0
            modelID = outcome.response.modelID
            deck = outcome.response.deck
        } catch is CancellationError { return }
        catch { if !Task.isCancelled { generationError = error.localizedDescription } }
    }

    private func togglePlayback() {
        guard voiceReady else { return }
        if activePlayback { autoplay = false; narration.pause(); return }
        autoplay = true
        if narration.playbackState == .paused { narration.resume() } else { playCurrentSlide() }
    }

    private func playCurrentSlide() {
        guard let deck, pendingQuiz == nil, deck.slides.indices.contains(slideIndex) else { return }
        narration.play(.init(text: deck.slides[slideIndex].narration, languageCode: store.learningLanguage.rawValue,
                             voiceID: chinese ? "zf_001" : "af_maple", speakingRate: 1))
    }

    private func seek(_ index: Int) {
        guard let deck, deck.slides.indices.contains(index) else { return }
        let continuePlaying = autoplay && pendingQuiz == nil
        narration.stop()
        slideIndex = index
        pendingQuiz = nil
        selectedOption = nil
        autoplay = continuePlaying
        if continuePlaying { playCurrentSlide() }
    }

    private func playbackChanged(_ state: NarrationPlaybackState) {
        guard state == .completed, autoplay, voiceReady, let deck else { return }
        let slide = deck.slides[slideIndex]
        narratedSlides.insert(slide.index)
        if let quiz = slide.quiz, quizResults[quiz.id] == nil {
            pendingQuiz = quiz
            selectedOption = nil
        } else { advance() }
    }

    private func advance() {
        guard let deck else { return }
        if slideIndex + 1 < deck.slides.count {
            slideIndex += 1
            if autoplay { playCurrentSlide() }
        } else { autoplay = false }
    }
}

struct LessonExportDocument: FileDocument {
    static let powerPoint = UTType(filenameExtension: "pptx") ?? UTType("org.openxmlformats.presentationml.presentation")!
    static var readableContentTypes: [UTType] { [.plainText, .mpeg4Movie, powerPoint] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// Scales from a phone card to a 720p export with the same content and hierarchy.
struct NarratedSlideStage: View {
    let slide: NarratedDeckSlide
    let total: Int
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 600
            let scale = geometry.size.width / 1280
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.035, green: 0.05, blue: 0.12), Color(red: 0.19, green: 0.12, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.indigo.opacity(0.30)).frame(width: 650 * scale, height: 650 * scale)
                    .blur(radius: 80 * scale).offset(x: 900 * scale, y: -280 * scale)
                VStack(alignment: .leading, spacing: compact ? 15 : 24 * scale) {
                    HStack {
                        Text(slide.eyebrow.uppercased()).font(.system(size: compact ? 10 : 19 * scale, weight: .bold)).tracking(2 * scale)
                        Spacer()
                        Text("\(slide.index) / \(total)").font(.system(size: compact ? 11 : 18 * scale, weight: .medium, design: .monospaced))
                    }.foregroundStyle(.white.opacity(0.6))
                    Text(slide.title).font(.system(size: compact ? 25 : 48 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white).lineLimit(3).minimumScaleFactor(0.65)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: compact ? 14 : 20 * scale) {
                        ForEach(Array(slide.bullets.enumerated()), id: \.offset) { offset, bullet in
                            HStack(alignment: .top, spacing: compact ? 10 : 16 * scale) {
                                Text(String(format: "%02d", offset + 1)).font(.system(size: compact ? 11 : 18 * scale, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.mint).padding(.top, 5 * scale)
                                Text(bullet).font(.system(size: compact ? 15 : 28 * scale, weight: .medium)).foregroundStyle(.white.opacity(0.88))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 14 * scale) {
                        Image(systemName: symbol).font(.system(size: compact ? 20 : 27 * scale)).foregroundStyle(.mint)
                        Text(slide.visual.primaryLabel).font(.system(size: compact ? 12 : 20 * scale, weight: .semibold)).foregroundStyle(.white)
                        Image(systemName: "arrow.right").foregroundStyle(.white.opacity(0.35))
                        Text(slide.visual.secondaryLabel).font(.system(size: compact ? 12 : 20 * scale)).foregroundStyle(.white.opacity(0.65))
                        Spacer(minLength: 0)
                    }.lineLimit(2)
                    HStack {
                        Text("LUMAP · CELESTIAL FRONTIER").font(.system(size: compact ? 8 : 12 * scale, weight: .medium)).foregroundStyle(.white.opacity(0.35))
                        Spacer()
                        Image(systemName: "waveform").foregroundStyle(.mint.opacity(0.6))
                    }
                }.padding(compact ? 23 : 54 * scale).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.mint).frame(width: geometry.size.width * min(1, max(0, progress)))
                        Spacer(minLength: 0)
                    }.frame(height: 3).opacity(progress > 0 ? 1 : 0)
                }
            }
        }
    }

    private var symbol: String {
        switch slide.visual.kind {
        case .constellation: "point.3.connected.trianglepath.dotted"
        case .feedbackLoop: "arrow.triangle.2.circlepath"
        case .evidencePulse: "waveform.path.ecg"
        case .transferBridge: "arrow.triangle.branch"
        case .horizon: "sun.horizon.fill"
        }
    }
}
