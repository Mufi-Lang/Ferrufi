//
//  Iron.swift
//  Iron
//
//  Main module file for the Iron knowledge management system
//

import Combine
import Foundation

/// Main Iron application class that coordinates all components
@MainActor
public class IronApp: ObservableObject {

    // MARK: - Core Components
    @Published public private(set) var configuration: ConfigurationManager
    @Published public private(set) var fileStorage: FileStorage?
    @Published public private(set) var searchIndex: SearchIndex
    @Published public private(set) var folderManager: FolderManager
    @Published public private(set) var errorHandler: ErrorHandler

    // MARK: - State
    @Published public private(set) var isInitialized = false
    @Published public private(set) var currentVaultPath: String?
    @Published public private(set) var notes: [Note] = []
    @Published public private(set) var isIndexing = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        self.configuration = ConfigurationManager()
        self.searchIndex = SearchIndex()
        self.folderManager = FolderManager()
        self.errorHandler = DefaultErrorHandler()

        setupSubscriptions()
    }

    /// Initializes the Iron app with a vault path
    public func initialize(vaultPath: String) async throws {
        do {
            // Initialize file storage
            self.fileStorage = try FileStorage(vaultPath: vaultPath)
            self.currentVaultPath = vaultPath

            // Initialize folder manager with notes directory
            folderManager.setRootFolder(path: vaultPath)

            // Update configuration
            configuration.updateConfiguration { config in
                config.vault.defaultVaultPath = vaultPath
            }

            // Load existing notes
            await loadNotes()

            // Set up file watching
            setupFileWatching()

            self.isInitialized = true

        } catch {
            let ironError = error as? IronError ?? IronError.unknown(error)
            let (errorWithContext, context) = IronError.withContext(
                ironError,
                component: "IronApp",
                operation: "initialize",
                additionalInfo: ["vaultPath": vaultPath]
            )

            errorHandler.handle(errorWithContext, context: context)
            throw errorWithContext
        }
    }

    // MARK: - Note Management

    /// Creates a new note
    public func createNote(title: String, content: String = "") async throws -> Note {
        guard isInitialized else {
            throw IronError.vaultNotFound("No vault initialized")
        }

        do {
            let note = try await folderManager.createNote(
                name: title,
                content: content.isEmpty ? "# \(title)\n\n" : content,
                folder: folderManager.selectedFolder
            )

            // Add to search index
            await searchIndex.indexNote(note)

            // Update notes array
            await MainActor.run {
                self.notes.append(note)
            }

            return note

        } catch {
            let ironError = error as? IronError ?? IronError.unknown(error)
            let (errorWithContext, context) = IronError.withContext(
                ironError,
                component: "IronApp",
                operation: "createNote",
                additionalInfo: ["title": title]
            )

            errorHandler.handle(errorWithContext, context: context)
            throw errorWithContext
        }
    }

    /// Loads a note by ID
    public func loadNote(id: UUID) -> Note? {
        return notes.first { $0.id == id }
    }

    /// Updates an existing note
    public func updateNote(_ note: Note) async throws {
        guard let storage = fileStorage else {
            throw IronError.vaultNotFound("No vault initialized")
        }

        do {
            // Update the note content on disk using FolderManager
            try await folderManager.updateNoteContent(note, content: note.content)

            // Also save via storage for metadata
            try await storage.saveNote(note)

            // Update search index
            await searchIndex.indexNote(note)

            // Update notes array in main actor
            await MainActor.run {
                if let index = self.notes.firstIndex(where: { $0.id == note.id }) {
                    self.notes[index] = note
                }
            }

        } catch {
            let ironError = error as? IronError ?? IronError.unknown(error)
            let (errorWithContext, context) = IronError.withContext(
                ironError,
                component: "IronApp",
                operation: "updateNote",
                additionalInfo: ["noteId": note.id.uuidString]
            )

            errorHandler.handle(errorWithContext, context: context)
            throw errorWithContext
        }
    }

    /// Deletes a note by ID
    public func deleteNote(id: UUID) async throws {
        guard let storage = fileStorage,
            let note = notes.first(where: { $0.id == id })
        else {
            throw IronError.noteNotFound(id)
        }

        do {
            try await storage.deleteNote(at: note.filePath)

            // Remove from search index
            await searchIndex.removeNote(with: id)

            // Update notes array
            self.notes.removeAll { $0.id == id }

        } catch {
            let ironError = error as? IronError ?? IronError.unknown(error)
            let (errorWithContext, context) = IronError.withContext(
                ironError,
                component: "IronApp",
                operation: "deleteNote",
                additionalInfo: ["noteId": id.uuidString]
            )

            errorHandler.handle(errorWithContext, context: context)
            throw errorWithContext
        }
    }

    /// Deletes a note
    public func deleteNote(_ note: Note) async throws {
        try await deleteNote(id: note.id)
    }

    // MARK: - Search

    /// Performs a search across all notes
    public func search(_ query: String) async -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return await searchIndex.search(query)
    }

    /// Searches notes by tag
    public func searchByTag(_ tag: String) async -> [SearchResult] {
        return await searchIndex.searchByTag(tag)
    }

    /// Rebuilds the search index
    public func rebuildSearchIndex() async throws {
        self.isIndexing = true

        do {
            try await searchIndex.rebuildIndex()

            // Re-index all notes
            for note in notes {
                await searchIndex.indexNote(note)
            }

        } catch {
            let ironError = error as? IronError ?? IronError.indexingFailed(error)
            let (errorWithContext, context) = IronError.withContext(
                ironError,
                component: "IronApp",
                operation: "rebuildSearchIndex"
            )

            errorHandler.handle(errorWithContext, context: context)
            throw errorWithContext
        }

        self.isIndexing = false
    }

    // MARK: - Private Methods

    private func loadNotes() async {
        // Load notes from filesystem using FolderManager
        folderManager.loadNotesFromFilesystem()

        // Copy notes from FolderManager to IronApp
        await MainActor.run {
            self.notes = folderManager.notes
        }

        // Index all notes for search
        self.isIndexing = true

        for note in folderManager.notes {
            await searchIndex.indexNote(note)
        }

        await MainActor.run {
            self.isIndexing = false
        }
    }

    private func setupSubscriptions() {
        // Listen for configuration changes
        configuration.$configuration
            .dropFirst()
            .sink { [weak self] _ in
                // Configuration changed, might need to refresh some components
                self?.handleConfigurationChange()
            }
            .store(in: &cancellables)
    }

    private func setupFileWatching() {
        guard let storage = fileStorage else { return }

        storage.watchForChanges()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleFileChange(event)
            }
            .store(in: &cancellables)
    }

    private func handleConfigurationChange() {
        // Handle configuration changes that might affect the app state
        Task {
            // Might need to restart file watching, update search settings, etc.
        }
    }

    private func handleFileChange(_ event: FileChangeEvent) {
        // Handle external file system changes
        Task { @MainActor in
            switch event.changeType {
            case .created, .modified:
                // Reload the affected note
                await loadNotes()
            case .deleted:
                // Remove from our internal state
                await loadNotes()
            case .moved:
                // Handle file moves
                await loadNotes()
            }
        }
    }
}

// MARK: - Convenience Extensions

extension IronApp {
    /// Gets all tags used across notes
    public var allTags: Set<String> {
        return Set(notes.flatMap { $0.tags })
    }

    /// Gets notes that contain a specific tag
    public func notes(withTag tag: String) -> [Note] {
        return notes.filter { $0.tags.contains(tag.lowercased()) }
    }

    /// Gets the total word count across all notes
    public var totalWordCount: Int {
        return notes.reduce(0) { $0 + $1.wordCount }
    }

    /// Gets statistics about the current vault
    public var vaultStats: VaultStats {
        return VaultStats(
            totalNotes: notes.count,
            totalWords: totalWordCount,
            totalTags: allTags.count,
            searchIndexStats: searchIndex.indexStats
        )
    }
}

/// Statistics about the current vault
public struct VaultStats: Sendable {
    public let totalNotes: Int
    public let totalWords: Int
    public let totalTags: Int
    public let searchIndexStats: IndexStats

    public init(totalNotes: Int, totalWords: Int, totalTags: Int, searchIndexStats: IndexStats) {
        self.totalNotes = totalNotes
        self.totalWords = totalWords
        self.totalTags = totalTags
        self.searchIndexStats = searchIndexStats
    }
}
