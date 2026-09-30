import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import SwiftUI

enum LessonVideoExportError: LocalizedError {
    case rendering, writing, audioUnavailable

    var errorDescription: String? {
        switch self {
        case .rendering: "A lesson slide could not be rendered."
        case .writing: "The teaching video could not be encoded. Please retry."
        case .audioUnavailable: "Install the Kokoro voice pack to export a narrated teaching video."
        }
    }
}

/// A real H.264 + AAC movie. Each slide remains visible for its ENTIRE Kokoro
/// narration, then retrieval cards insert thinking time and reveal feedback.
/// No screen recording, fake progress, system voice or truncated preview audio.
@MainActor
enum LessonVideoExporter {
    static func export(
        deck: NarratedLearningDeck,
        languageCode: String,
        progress: @escaping (Double, String) -> Void
    ) async throws -> URL {
        guard KokoroVoicePackManager.isInstalled() else { throw LessonVideoExportError.audioUnavailable }
        let directory = FileManager.default.temporaryDirectory.appending(path: "LumapLesson-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let silentVideo = directory.appending(path: "slides.mp4")
        let finalVideo = directory.appending(path: "Lumap-lesson.mp4")
        let masterAudio = directory.appending(path: "narration.caf")
        var audioURLs: [URL] = []
        var succeeded = false
        defer {
            audioURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            try? FileManager.default.removeItem(at: silentVideo)
            try? FileManager.default.removeItem(at: masterAudio)
            if !succeeded { try? FileManager.default.removeItem(at: directory) }
        }

        struct Stage {
            let image: CGImage
            let duration: CMTime
            let audioURL: URL?
        }
        var stages: [Stage] = []
        let chinese = languageCode.lowercased().hasPrefix("zh")
        for (offset, slide) in deck.slides.enumerated() {
            try Task.checkCancellation()
            progress(Double(offset) / Double(deck.slides.count) * 0.72,
                     chinese ? "正在生成完整讲解音频 \(offset + 1)/\(deck.slides.count)" : "Synthesising full narration \(offset + 1)/\(deck.slides.count)")
            let audioURL = try await NarrationAudioRenderer.render(.init(
                text: slide.narration, languageCode: languageCode,
                voiceID: chinese ? "zf_001" : "af_maple", speakingRate: 1
            ))
            audioURLs.append(audioURL)
            let audioFile = try AVAudioFile(forReading: audioURL)
            let duration = CMTime(value: audioFile.length, timescale: CMTimeScale(audioFile.processingFormat.sampleRate))
            guard duration.seconds.isFinite, duration.seconds > 0 else { throw LessonVideoExportError.audioUnavailable }
            let renderer = ImageRenderer(content: NarratedSlideStage(slide: slide, total: deck.slides.count, progress: 0)
                .frame(width: 1280, height: 720))
            renderer.scale = 1
            guard let image = renderer.cgImage else { throw LessonVideoExportError.rendering }
            stages.append(Stage(image: image, duration: duration, audioURL: audioURL))
            if let quiz = slide.quiz {
                for reveal in [false, true] {
                    let quizRenderer = ImageRenderer(content: LessonVideoQuizCard(quiz: quiz, reveal: reveal, chinese: chinese)
                        .frame(width: 1280, height: 720))
                    quizRenderer.scale = 1
                    guard let image = quizRenderer.cgImage else { throw LessonVideoExportError.rendering }
                    stages.append(Stage(image: image, duration: CMTime(seconds: reveal ? 7 : 9, preferredTimescale: 600), audioURL: nil))
                }
            }
        }

        progress(0.75, chinese ? "正在编码教学视频" : "Encoding the teaching video")
        let writer = try AVAssetWriter(outputURL: silentVideo, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280, AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_600_000, AVVideoExpectedSourceFrameRateKey: 12, AVVideoMaxKeyFrameIntervalKey: 24]
        ])
        input.expectsMediaDataInRealTime = false
        input.mediaTimeScale = 600
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 1280,
            kCVPixelBufferHeightKey as String: 720,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw LessonVideoExportError.writing }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? LessonVideoExportError.writing }
        writer.startSession(atSourceTime: .zero)
        var position = CMTime.zero
        var frameNumber: Int64 = 0
        do {
            for stage in stages {
                try Task.checkCancellation()
                let pixelBuffer = try makePixelBuffer(stage.image)
                let end = CMTimeAdd(position, stage.duration)
                // Constant-rate samples are portable across AVFoundation
                // decoders; a pair of 30-second still samples is not.
                while CMTime(value: frameNumber, timescale: 12) < end {
                    while !input.isReadyForMoreMediaData {
                        try Task.checkCancellation()
                        guard writer.status == .writing else { throw writer.error ?? LessonVideoExportError.writing }
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: frameNumber, timescale: 12)) else {
                        throw writer.error ?? LessonVideoExportError.writing
                    }
                    frameNumber += 1
                }
                position = end
            }
            writer.endSession(atSourceTime: position)
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? LessonVideoExportError.writing }
        } catch {
            writer.cancelWriting()
            throw error
        }

        progress(0.9, chinese ? "正在合成完整音轨" : "Muxing complete audio tracks")
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: silentVideo)
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first else {
            throw LessonVideoExportError.writing
        }
        let videoTimeRange = try await sourceVideo.load(.timeRange)
        let availableVideoDuration = min(position, videoTimeRange.duration)
        guard availableVideoDuration.seconds > 0 else { throw LessonVideoExportError.writing }
        try videoTrack.insertTimeRange(CMTimeRange(start: videoTimeRange.start, duration: availableVideoDuration), of: sourceVideo, at: .zero)
        // Keep source assets alive while their tracks are inserted and exported.
        defer { withExtendedLifetime(videoAsset) {} }
        // A single PCM master removes cumulative sample/time rounding and
        // WAV edit-list incompatibilities during AVFoundation composition.
        // Thinking/reveal intervals are represented by real silence samples.
        let sampleRate = 24_000.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw LessonVideoExportError.audioUnavailable
        }
        do {
            let output = try AVAudioFile(forWriting: masterAudio, settings: format.settings,
                                         commonFormat: .pcmFormatFloat32, interleaved: false)
            for stage in stages {
                try Task.checkCancellation()
                if let url = stage.audioURL {
                    let source = try AVAudioFile(forReading: url)
                    guard source.processingFormat.sampleRate == sampleRate,
                          source.processingFormat.channelCount == 1,
                          let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 24_000) else {
                        throw LessonVideoExportError.audioUnavailable
                    }
                    while source.framePosition < source.length {
                        try source.read(into: buffer)
                        try output.write(from: buffer)
                    }
                } else {
                    var remaining = AVAudioFrameCount((stage.duration.seconds * sampleRate).rounded())
                    guard let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 24_000),
                          let samples = silence.floatChannelData?[0] else { throw LessonVideoExportError.audioUnavailable }
                    samples.initialize(repeating: 0, count: 24_000)
                    while remaining > 0 {
                        silence.frameLength = min(remaining, silence.frameCapacity)
                        try output.write(from: silence)
                        remaining -= silence.frameLength
                    }
                }
            }
        }
        let audioAsset = AVURLAsset(url: masterAudio)
        guard let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw LessonVideoExportError.audioUnavailable
        }
        let audioTimeRange = try await sourceAudio.load(.timeRange)
        try audioTrack.insertTimeRange(audioTimeRange, of: sourceAudio, at: .zero)
        defer { withExtendedLifetime(audioAsset) {} }
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720) else {
            throw LessonVideoExportError.writing
        }
        exporter.shouldOptimizeForNetworkUse = true
        if #available(macOS 15.0, iOS 18.0, *) {
            try await exporter.export(to: finalVideo, as: .mp4)
        } else {
            exporter.outputURL = finalVideo
            exporter.outputFileType = .mp4
            await exporter.export()
            guard exporter.status == .completed else { throw exporter.error ?? LessonVideoExportError.writing }
        }
        try Task.checkCancellation()
        succeeded = true
        progress(1, chinese ? "视频已就绪" : "Teaching video ready")
        return finalVideo
    }

    private static func makePixelBuffer(_ image: CGImage) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, 1280, 720, kCVPixelFormatType_32ARGB, attributes, &buffer) == kCVReturnSuccess,
              let buffer else { throw LessonVideoExportError.rendering }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 1280, height: 720,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            throw LessonVideoExportError.rendering
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1280, height: 720))
        return buffer
    }
}

private struct LessonVideoQuizCard: View {
    let quiz: NarratedDeckQuiz
    let reveal: Bool
    let chinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(chinese ? "暂停 · 思考 · 回忆" : "PAUSE · THINK · RETRIEVE")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(.mint)
            Text(quiz.prompt).font(.system(size: 37, weight: .semibold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(quiz.options) { option in
                Text("\(option.id.uppercased()).  \(option.text)")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(reveal && option.id == quiz.correctOptionID ? Color.mint : Color.white.opacity(0.84))
            }
            Spacer(minLength: 0)
            Text(reveal ? quiz.explanation : (chinese ? "现在暂停视频，先写下你的答案。" : "Pause the video now and commit to your answer."))
                .font(.system(size: 24)).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Text("LUMAP · CELESTIAL FRONTIER").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(60).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.15), Color(red: 0.10, green: 0.18, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
