import Foundation

enum KokoroVoicePackImportError: LocalizedError, Sendable {
    case unavailableSource
    case invalidFolder(String)
    case unsafeEntry(String)
    case unexpectedFileSize(file: String, expected: Int64, actual: Int64)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailableSource:
            "Lumap could not access the selected folder. Choose the extracted Kokoro folder again."
        case .invalidFolder(let detail):
            "This is not the verified Kokoro multilingual v1.1 folder. \(detail)"
        case .unsafeEntry(let path):
            "The selected folder contains an unsupported symbolic link or special file: \(path)"
        case .unexpectedFileSize(let file, let expected, let actual):
            "\(file) has an unexpected size (expected \(expected) bytes, found \(actual))."
        case .importFailed(let detail):
            "Lumap could not import the Kokoro voice pack. \(detail)"
        }
    }
}

/// Owns the fixed, sandbox-local location and validation rules for the optional
/// Kokoro pack. External folders are accessed only long enough to copy a small
/// allow-list into Application Support; narration never reads from an arbitrary
/// security-scoped URL after import.
enum KokoroVoicePackManager {
    nonisolated static let packID = "kokoro-int8-multi-lang-v1_1"
    nonisolated static let expectedModelBytes: Int64 = 114_299_010
    nonisolated static let expectedVoicesBytes: Int64 = 53_790_720

    nonisolated private static let requiredFiles = [
        "model.int8.onnx",
        "voices.bin",
        "tokens.txt",
        "lexicon-us-en.txt",
        "lexicon-zh.txt",
        "date-zh.fst",
        "number-zh.fst",
        "phone-zh.fst",
        "LICENSE"
    ]

    nonisolated static func destinationURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return applicationSupport
            .appending(path: "Lumap", directoryHint: .isDirectory)
            .appending(path: "VoicePacks", directoryHint: .isDirectory)
            .appending(path: packID, directoryHint: .isDirectory)
    }

    nonisolated static func isInstalled(fileManager: FileManager = .default) -> Bool {
        (try? validatePack(at: destinationURL(fileManager: fileManager), fileManager: fileManager)) != nil
    }

    nonisolated static func validatePack(at directory: URL, fileManager: FileManager = .default) throws {
        try validateDirectory(directory, fileManager: fileManager)

        for relativePath in requiredFiles {
            let file = directory.appending(path: relativePath, directoryHint: .notDirectory)
            try validateRegularFile(file, relativePath: relativePath, fileManager: fileManager)
        }

        let espeakDirectory = directory.appending(path: "espeak-ng-data", directoryHint: .isDirectory)
        try validateDirectory(espeakDirectory, fileManager: fileManager)
        try rejectUnsafeDescendants(in: espeakDirectory, fileManager: fileManager)

        try requireSize(
            of: directory.appending(path: "model.int8.onnx"),
            relativePath: "model.int8.onnx",
            expected: expectedModelBytes,
            fileManager: fileManager
        )
        try requireSize(
            of: directory.appending(path: "voices.bin"),
            relativePath: "voices.bin",
            expected: expectedVoicesBytes,
            fileManager: fileManager
        )
    }

    /// Copies a previously extracted pack into Lumap's private container. The
    /// caller must keep security-scoped access active until this method returns.
    nonisolated static func importExtractedPack(from sourceDirectory: URL) async throws -> URL {
        let destination = destinationURL()
        return try await Task.detached(priority: .userInitiated) {
            try importSynchronously(from: sourceDirectory, to: destination)
        }.value
    }

    nonisolated private static func importSynchronously(from sourceDirectory: URL, to destination: URL) throws -> URL {
        let manager = FileManager()
        let source = sourceDirectory.standardizedFileURL
        let fixedDestination = destination.standardizedFileURL

        guard source.path != fixedDestination.path else {
            throw KokoroVoicePackImportError.invalidFolder("The selected folder is already Lumap's private installation.")
        }

        try validatePack(at: source, fileManager: manager)

        let parent = fixedDestination.deletingLastPathComponent()
        do {
            try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            throw KokoroVoicePackImportError.importFailed(error.localizedDescription)
        }

        let staging = parent.appending(path: ".importing-\(packID)-\(UUID().uuidString)", directoryHint: .isDirectory)
        let backup = parent.appending(path: ".previous-\(packID)-\(UUID().uuidString)", directoryHint: .isDirectory)
        var movedExistingPack = false

        do {
            try manager.createDirectory(at: staging, withIntermediateDirectories: false)
            for relativePath in requiredFiles {
                try manager.copyItem(
                    at: source.appending(path: relativePath, directoryHint: .notDirectory),
                    to: staging.appending(path: relativePath, directoryHint: .notDirectory)
                )
            }
            try manager.copyItem(
                at: source.appending(path: "espeak-ng-data", directoryHint: .isDirectory),
                to: staging.appending(path: "espeak-ng-data", directoryHint: .isDirectory)
            )

            let metadata: [String: Any] = [
                "id": packID,
                "source": "user-selected-extracted-folder",
                "importedAtUTC": ISO8601DateFormatter().string(from: Date())
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            try metadataData.write(to: staging.appending(path: ".lumap-install.json"), options: .atomic)
            try validatePack(at: staging, fileManager: manager)

            if manager.fileExists(atPath: fixedDestination.path) {
                try manager.moveItem(at: fixedDestination, to: backup)
                movedExistingPack = true
            }

            do {
                try manager.moveItem(at: staging, to: fixedDestination)
            } catch {
                if movedExistingPack, !manager.fileExists(atPath: fixedDestination.path) {
                    try? manager.moveItem(at: backup, to: fixedDestination)
                }
                throw error
            }

            if movedExistingPack {
                try? manager.removeItem(at: backup)
            }
            return fixedDestination
        } catch let error as KokoroVoicePackImportError {
            try? manager.removeItem(at: staging)
            throw error
        } catch {
            try? manager.removeItem(at: staging)
            throw KokoroVoicePackImportError.importFailed(error.localizedDescription)
        }
    }

    nonisolated private static func validateDirectory(_ directory: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw KokoroVoicePackImportError.invalidFolder("Missing directory: \(directory.lastPathComponent).")
        }
        let values = try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else {
            throw KokoroVoicePackImportError.unsafeEntry(directory.lastPathComponent)
        }
    }

    nonisolated private static func validateRegularFile(
        _ file: URL,
        relativePath: String,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: file.path) else {
            throw KokoroVoicePackImportError.invalidFolder("Missing required file: \(relativePath).")
        }
        let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw KokoroVoicePackImportError.unsafeEntry(relativePath)
        }
    }

    nonisolated private static func rejectUnsafeDescendants(in directory: URL, fileManager: FileManager) throws {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey],
            options: []
        ) else {
            throw KokoroVoicePackImportError.invalidFolder("The espeak-ng-data directory cannot be read.")
        }

        for case let item as URL in enumerator {
            let values = try item.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey])
            guard values.isSymbolicLink != true,
                  values.isRegularFile == true || values.isDirectory == true else {
                throw KokoroVoicePackImportError.unsafeEntry(item.lastPathComponent)
            }
        }
    }

    nonisolated private static func requireSize(
        of file: URL,
        relativePath: String,
        expected: Int64,
        fileManager: FileManager
    ) throws {
        let attributes = try fileManager.attributesOfItem(atPath: file.path)
        let actual = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        guard actual == expected else {
            throw KokoroVoicePackImportError.unexpectedFileSize(file: relativePath, expected: expected, actual: actual)
        }
    }
}
