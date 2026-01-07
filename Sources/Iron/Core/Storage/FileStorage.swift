//
//  FileStorage.swift
//  Iron
//
//  File-based storage system for notes and folders
//

import Combine
import Foundation

/// Protocol for file storage operations
public protocol FileStorageProtocol {
    func saveNote(_ note: Note) async throws
    func loadNote(from path: String) async throws -> Note
    func deleteNote(at path: String) async throws
    func moveNote(from sourcePath: String, to destinationPath: String) async throws
    func listNotes(in directory: String) async throws -> [String]
    func watchForChanges() -> AnyPublisher<FileChangeEvent, Never>
}

/// Events that occur when files change
public struct FileChangeEvent: Sendable {
    public let path: String
    public let changeType: FileChangeType
    public let timestamp: Date

    public init(path: String, changeType: FileChangeType, timestamp: Date = Date()) {
        self.path = path
        self.changeType = changeType
        self.timestamp = timestamp
    }
}

/// Types of file changes
public enum FileChangeType: Sendable {
    case created
    case modified
    case deleted
    case moved(from: String, to: String)
}

/// File-based storage implementation
public final class FileStorage: NSObject, FileStorageProtocol, ObservableObject, @unchecked Sendable
{
    public let vaultPath: String
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var fileWatcher: DispatchSourceFileSystemObject?
    private let changeSubject = PassthroughSubject<FileChangeEvent, Never>()

    // Queue for file operations to ensure thread safety
    private let fileQueue = DispatchQueue(label: "iron.file.operations", qos: .utility)

    public init(vaultPath: String) throws {
        self.vaultPath = vaultPath
        super.init()

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        try createVaultDirectoryIfNeeded()
        setupFileWatcher()
    }

    deinit {
        fileWatcher?.cancel()
    }

    // MARK: - Directory Management

    /// Creates the notes directory if it doesn't exist
    private func createVaultDirectoryIfNeeded() throws {
        let notesURL = URL(fileURLWithPath: vaultPath)
        let metadataURL = notesURL.appendingPathComponent(".metadata")

        if !fileManager.fileExists(atPath: vaultPath) {
            try fileManager.createDirectory(
                at: notesURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Create metadata directory
        if !fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.createDirectory(
                at: metadataURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    // MARK: - Note Operations

    public func saveNote(_ note: Note) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(
                        throwing: FileStorageError.writeError(
                            NSError(domain: "FileStorage", code: -1)))
                    return
                }
                do {
                    let noteURL = URL(fileURLWithPath: self.vaultPath)
                        .appendingPathComponent("\(note.title).md")

                    // Save markdown content
                    try note.content.write(
                        to: noteURL,
                        atomically: true,
                        encoding: .utf8
                    )

                    // Save metadata
                    try self.saveNoteMetadata(note)

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func loadNote(from path: String) async throws -> Note {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(
                        throwing: FileStorageError.readError(
                            NSError(domain: "FileStorage", code: -1)))
                    return
                }
                do {
                    let noteURL = URL(fileURLWithPath: path)
                    let content = try String(contentsOf: noteURL, encoding: .utf8)

                    var note = Note.fromMarkdown(filePath: path, content: content)

                    // Load metadata if it exists
                    if let metadata = try? self.loadNoteMetadata(for: note.id) {
                        note.metadata = metadata.metadata
                        note.tags = metadata.tags
                        note.createdAt = metadata.createdAt
                        note.modifiedAt = metadata.modifiedAt
                    }

                    continuation.resume(returning: note)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func deleteNote(at path: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(
                        throwing: FileStorageError.writeError(
                            NSError(domain: "FileStorage", code: -1)))
                    return
                }
                do {
                    let noteURL = URL(fileURLWithPath: path)
                    try self.fileManager.removeItem(at: noteURL)

                    // Also delete metadata
                    let filename = noteURL.deletingPathExtension().lastPathComponent
                    if let noteId = self.findNoteId(for: filename) {
                        try? self.deleteNoteMetadata(for: noteId)
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func moveNote(from sourcePath: String, to destinationPath: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(
                        throwing: FileStorageError.writeError(
                            NSError(domain: "FileStorage", code: -1)))
                    return
                }
                do {
                    let sourceURL = URL(fileURLWithPath: sourcePath)
                    let destinationURL = URL(fileURLWithPath: destinationPath)

                    try self.fileManager.moveItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func listNotes(in directory: String = "") async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(
                        throwing: FileStorageError.readError(
                            NSError(domain: "FileStorage", code: -1)))
                    return
                }
                do {
                    let notesURL = URL(fileURLWithPath: self.vaultPath)
                        .appendingPathComponent(directory)

                    let contents = try self.fileManager.contentsOfDirectory(
                        at: notesURL,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    )

                    let noteFiles = contents.compactMap { url -> String? in
                        guard url.pathExtension == "md" else { return nil }
                        return url.path
                    }

                    continuation.resume(returning: noteFiles)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Metadata Management

    private struct NoteMetadataFile: Codable {
        let id: UUID
        let metadata: NoteMetadata
        let tags: Set<String>
        let createdAt: Date
        let modifiedAt: Date
    }

    private func saveNoteMetadata(_ note: Note) throws {
        let metadataFile = NoteMetadataFile(
            id: note.id,
            metadata: note.metadata,
            tags: note.tags,
            createdAt: note.createdAt,
            modifiedAt: note.modifiedAt
        )

        let metadataURL = URL(fileURLWithPath: vaultPath)
            .appendingPathComponent(".metadata")
            .appendingPathComponent("\(note.id.uuidString).json")

        // Create metadata directory if it doesn't exist
        let metadataDir = metadataURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: metadataDir.path) {
            try fileManager.createDirectory(
                at: metadataDir, withIntermediateDirectories: true, attributes: nil)
        }

        let data = try encoder.encode(metadataFile)
        try data.write(to: metadataURL)
    }

    private func loadNoteMetadata(for noteId: UUID) throws -> NoteMetadataFile {
        let metadataURL = URL(fileURLWithPath: vaultPath)
            .appendingPathComponent(".metadata")
            .appendingPathComponent("\(noteId.uuidString).json")

        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode(NoteMetadataFile.self, from: data)
    }

    private func deleteNoteMetadata(for noteId: UUID) throws {
        let metadataURL = URL(fileURLWithPath: vaultPath)
            .appendingPathComponent(".metadata")
            .appendingPathComponent("\(noteId.uuidString).json")

        try fileManager.removeItem(at: metadataURL)
    }

    private func findNoteId(for filename: String) -> UUID? {
        // This would need to be implemented with an index or by scanning metadata files
        // For now, returning nil as a placeholder
        return nil
    }

    // MARK: - File Watching

    private func setupFileWatcher() {
        let notesPath = vaultPath
        let fileDescriptor = open(notesPath, O_EVTONLY)

        guard fileDescriptor >= 0 else { return }

        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: fileQueue
        )

        fileWatcher?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }

        fileWatcher?.setCancelHandler {
            close(fileDescriptor)
        }

        fileWatcher?.resume()
    }

    private func handleFileSystemEvent() {
        // For now, we'll emit a generic change event
        // A more sophisticated implementation would determine the specific change
        let event = FileChangeEvent(
            path: vaultPath,
            changeType: .modified
        )
        changeSubject.send(event)
    }

    public func watchForChanges() -> AnyPublisher<FileChangeEvent, Never> {
        return changeSubject.eraseToAnyPublisher()
    }
}

/// Errors that can occur during file storage operations
public enum FileStorageError: LocalizedError, Sendable {
    case vaultNotFound
    case invalidPath
    case fileNotFound
    case writeError(Error)
    case readError(Error)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .vaultNotFound:
            return "Vault directory not found"
        case .invalidPath:
            return "Invalid file path"
        case .fileNotFound:
            return "File not found"
        case .writeError(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .readError(let error):
            return "Failed to read file: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - Convenience Extensions

extension FileStorage {
    /// Creates a new note and saves it to disk
    public func createNote(title: String, content: String = "") async throws -> Note {
        let note = Note(
            title: title,
            content: content,
            filePath: URL(fileURLWithPath: vaultPath)
                .appendingPathComponent("\(title).md")
                .path
        )

        try await saveNote(note)
        return note
    }

    /// Loads all notes from the vault
    public func loadAllNotes() async throws -> [Note] {
        let notePaths = try await listNotes()
        var notes: [Note] = []

        for path in notePaths {
            do {
                let note = try await loadNote(from: path)
                notes.append(note)
            } catch {
                // Log error but continue with other notes
                print("Failed to load note at \(path): \(error)")
            }
        }

        return notes
    }
}
