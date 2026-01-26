//
//  FileStorage.swift
//  Ferrufi
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
    public let workspacePath: String

    /// If the workspace path is covered by a stored security-scoped bookmark,
    /// this will hold the resolved security-scoped URL so file operations use
    /// the canonical, access-granted URL rather than raw path strings.
    private var resolvedWorkspaceURL: URL? = nil

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var fileWatcher: DispatchSourceFileSystemObject?
    private let changeSubject = PassthroughSubject<FileChangeEvent, Never>()

    // Queue for file operations to ensure thread safety
    private let fileQueue = DispatchQueue(label: "Ferrufi.file.operations", qos: .utility)

    public init(workspacePath: String, resolvedWorkspaceURL: URL? = nil) throws {
        self.workspacePath = workspacePath
        self.resolvedWorkspaceURL = resolvedWorkspaceURL
        super.init()

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        if let resolved = resolvedWorkspaceURL {
            print("ℹ️ Using resolved security-scoped URL for workspace: \(resolved.path)")
        }

        try createWorkspaceDirectoryIfNeeded()
        setupFileWatcher()
    }

    deinit {
        fileWatcher?.cancel()
    }

    // MARK: - Directory Management

    /// Creates the notes directory if it doesn't exist, using a security-scoped
    /// URL when available. Falls back to plain filesystem operations if access cannot
    /// be established.
    /// Creates the notes directory if it doesn't exist
    /// If a resolved security-scoped URL is available we assume access has already
    /// been granted and perform direct file operations to avoid starting/stopping
    /// the security scope (which would otherwise interfere with an already active scope).
    private func createWorkspaceDirectoryIfNeeded() throws {
        // Use the resolvedWorkspaceURL path when available as canonical base path,
        // otherwise use the raw workspacePath.
        let basePath = resolvedWorkspaceURL?.path ?? workspacePath
        var notesPath = basePath
        var metadataPath = (notesPath as NSString).appendingPathComponent(".metadata")

        // If we have a resolved bookmark URL, prefer the resolved layout logic
        if let resolvedBase = resolvedWorkspaceURL {
            if workspacePath.hasPrefix(resolvedBase.path) {
                var relative = String(workspacePath.dropFirst(resolvedBase.path.count))
                if relative.hasPrefix("/") { relative.removeFirst() }
                if relative.isEmpty {
                    notesPath = resolvedBase.path
                } else {
                    notesPath =
                        URL(fileURLWithPath: resolvedBase.path).appendingPathComponent(relative)
                        .path
                }
                metadataPath = (notesPath as NSString).appendingPathComponent(".metadata")
            } else {
                // Use the resolved base directly
                notesPath = resolvedBase.path
                metadataPath = (notesPath as NSString).appendingPathComponent(".metadata")
            }

            // Ensure directories exist using FileService synchronous helpers (security-scoped aware)
            if !fileManager.fileExists(atPath: notesPath) {
                try FileService.createDirectorySync(atPath: notesPath)
            }
            if !fileManager.fileExists(atPath: metadataPath) {
                try FileService.createDirectorySync(atPath: metadataPath)
            }
            return
        }

        // No resolved bookmark: attempt to create directories using FileService sync helpers,
        // which use security-scoped access under the hood. If that fails, fall back to direct FileManager ops.
        do {
            try FileService.createDirectorySync(atPath: notesPath)
            try FileService.createDirectorySync(atPath: metadataPath)
        } catch {
            // Final fallback to direct ops (may fail if permissions are restricted)
            if !fileManager.fileExists(atPath: notesPath) {
                try fileManager.createDirectory(
                    at: URL(fileURLWithPath: notesPath), withIntermediateDirectories: true,
                    attributes: nil)
            }
            if !fileManager.fileExists(atPath: metadataPath) {
                try fileManager.createDirectory(
                    at: URL(fileURLWithPath: metadataPath), withIntermediateDirectories: true,
                    attributes: nil)
            }
        }
    }

    // MARK: - Note Operations

    public func saveNote(_ note: Note) async throws {
        // Use FileService to perform the content write and metadata write so security-scoped
        // access is consistently handled in one place. Prefer a resolved workspace URL path
        // when present so the stored configuration remains canonical.
        let basePath = self.resolvedWorkspaceURL?.path ?? self.workspacePath
        let notePath = URL(fileURLWithPath: basePath).appendingPathComponent("\(note.title).mufi")
            .path

        do {
            try await FileService.shared.writeTextFile(atPath: notePath, contents: note.content)
            // Persist metadata (async helper)
            try await saveNoteMetadata(note)
        } catch {
            throw error
        }
    }

    public func loadNote(from path: String) async throws -> Note {
        // Read note contents via FileService (handles security-scoped access).
        do {
            let content = try await FileService.shared.readTextFile(atPath: path)
            var note = Note.fromText(filePath: path, content: content)

            // Load metadata if present (async helper)
            if let metadata = try? await loadNoteMetadata(for: note.id) {
                note.metadata = metadata.metadata
                note.tags = metadata.tags
                note.createdAt = metadata.createdAt
                note.modifiedAt = metadata.modifiedAt
            }

            return note
        } catch {
            throw error
        }
    }

    public func deleteNote(at path: String) async throws {
        do {
            try await FileService.shared.deleteItem(atPath: path)

            // Also delete metadata if we can determine the note id
            let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            if let noteId = findNoteId(for: filename) {
                try? await deleteNoteMetadata(for: noteId)
            }
        } catch {
            throw error
        }
    }

    public func moveNote(from sourcePath: String, to destinationPath: String) async throws {
        do {
            try await FileService.shared.moveItem(from: sourcePath, to: destinationPath)
        } catch {
            throw error
        }
    }

    public func listNotes(in directory: String = "") async throws -> [String] {
        do {
            let basePath = (self.resolvedWorkspaceURL ?? URL(fileURLWithPath: self.workspacePath))
                .path
            let notesDir = (basePath as NSString).appendingPathComponent(directory)
            let entries = try await FileService.shared.listDirectory(atPath: notesDir)

            let noteFiles = entries.compactMap { name -> String? in
                // entries from FileService are directory entries (names). Filter by .mufi extension.
                guard (name as NSString).pathExtension == "mufi" else { return nil }
                // If an entry is absolute, return as-is; otherwise resolve relative to notesDir.
                if name.hasPrefix("/") {
                    return name
                } else {
                    return (notesDir as NSString).appendingPathComponent(name)
                }
            }

            return noteFiles
        } catch {
            throw error
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

    private func saveNoteMetadata(_ note: Note) async throws {
        let metadataFile = NoteMetadataFile(
            id: note.id,
            metadata: note.metadata,
            tags: note.tags,
            createdAt: note.createdAt,
            modifiedAt: note.modifiedAt
        )

        let metadataURL = URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".metadata")
            .appendingPathComponent("\(note.id.uuidString).json")

        let data = try encoder.encode(metadataFile)
        // Use FileService to write metadata (creates parent directory as needed)
        try await FileService.shared.writeData(atPath: metadataURL.path, data: data)
    }

    private func loadNoteMetadata(for noteId: UUID) async throws -> NoteMetadataFile {
        let metadataURL = URL(fileURLWithPath: workspacePath)
            .appendingPathComponent(".metadata")
            .appendingPathComponent("\(noteId.uuidString).json")

        let data = try await FileService.shared.readData(atPath: metadataURL.path)
        return try decoder.decode(NoteMetadataFile.self, from: data)
    }

    private func deleteNoteMetadata(for noteId: UUID) async throws {
        let metadataURL = (self.resolvedWorkspaceURL ?? URL(fileURLWithPath: self.workspacePath))
            .appendingPathComponent(".metadata")
            .appendingPathComponent("\(noteId.uuidString).json")

        try await FileService.shared.deleteItem(atPath: metadataURL.path)
    }

    private func findNoteId(for filename: String) -> UUID? {
        // This would need to be implemented with an index or by scanning metadata files
        // For now, returning nil as a placeholder
        return nil
    }

    // MARK: - File Watching

    private func setupFileWatcher() {
        // Use the resolved security-scoped URL when available so the watcher operates
        // on the access-granted URL instead of a raw path that may lack privileges.
        let notesPath = (resolvedWorkspaceURL ?? URL(fileURLWithPath: workspacePath)).path
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
            path: workspacePath,
            changeType: .modified
        )
        // Notify local subscribers
        changeSubject.send(event)

        // Forward the event into the centralized FileService publisher asynchronously.
        // Use Task to call the actor method from this synchronous callback context.
        Task {
            await FileService.shared.publishFileChange(
                path: event.path, changeType: event.changeType)
        }
    }

    public func watchForChanges() -> AnyPublisher<FileChangeEvent, Never> {
        return changeSubject.eraseToAnyPublisher()
    }
}

/// Errors that can occur during file storage operations
public enum FileStorageError: LocalizedError, Sendable {
    case workspaceNotFound
    case invalidPath
    case fileNotFound
    case writeError(Error)
    case readError(Error)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .workspaceNotFound:
            return "Workspace directory not found"
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
    // Creates a new note and saves it to disk
    public func createNote(title: String, content: String = "") async throws -> Note {
        let note = Note(
            title: title,
            content: content,
            filePath: URL(fileURLWithPath: workspacePath)
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
