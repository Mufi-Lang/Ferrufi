//
//  NoteManager.swift
//  Ferrufi
//
//  Created on 2024-12-19.
//

import Combine
import Foundation

/// Advanced note management functionality including templates, auto-save, and file operations
@MainActor
class NoteManager: ObservableObject {

    // MARK: - Published Properties

    @Published var templates: [NoteTemplate] = []
    @Published var recentNotes: [Note] = []
    @Published var isAutoSaveEnabled: Bool = true

    // MARK: - Private Properties

    private let fileStorage: FileStorage
    private let folderManager: FolderManager
    private let configManager: ConfigurationManager
    private var autoSaveTimer: Timer?
    private var fileWatcher: FileWatcher?
    private var cancellables = Set<AnyCancellable>()

    // Auto-save configuration
    private let autoSaveInterval: TimeInterval = 30.0  // 30 seconds
    private let autoSaveDelay: TimeInterval = 2.0  // 2 second delay after changes

    // MARK: - Initialization

    init(
        fileStorage: FileStorage, folderManager: FolderManager, configManager: ConfigurationManager
    ) {
        self.fileStorage = fileStorage
        self.folderManager = folderManager
        self.configManager = configManager

        setupConfiguration()
        loadTemplates()
        loadRecentNotes()
        setupFileWatcher()
    }

    deinit {
        // Cleanup handled by class deallocation
    }

    // MARK: - Note Creation

    /// Create a new note from template
    func createNote(from template: NoteTemplate, in folder: Folder?, name: String? = nil)
        async throws -> Note
    {
        let noteName = name ?? generateNoteName(from: template)
        let content = processTemplateContent(template.content, noteName: noteName)

        let note = try await folderManager.createNote(
            name: noteName,
            content: content,
            folder: folder
        )

        addToRecentNotes(note)
        return note
    }

    /// Create a new note with default template
    func createNote(name: String, in folder: Folder?, content: String = "") async throws -> Note {
        let note = try await folderManager.createNote(
            name: name,
            content: content.isEmpty ? getDefaultNoteContent(name: name) : content,
            folder: folder
        )

        addToRecentNotes(note)
        return note
    }

    /// Create a daily note
    func createDailyNote() async throws -> Note {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        let noteName = "Daily Note - \(todayString)"
        let content = getDailyNoteContent(for: Date())

        // Check if daily note already exists
        if let existingNote = findNoteByName(noteName) {
            return existingNote
        }

        return try await createNote(name: noteName, in: nil, content: content)
    }

    // MARK: - Note Operations

    /// Duplicate a note
    func duplicateNote(_ note: Note, newName: String? = nil) async throws -> Note {
        let duplicateName = newName ?? "\(note.title) (Copy)"

        let duplicatedNote = try await createNote(
            name: duplicateName,
            in: folderManager.selectedFolder,
            content: note.content
        )

        return duplicatedNote
    }

    /// Move note to different folder
    func moveNote(_ note: Note, to folder: Folder?) async throws {
        guard let sourceURL = note.url else {
            throw FerrufiError.fileSystem(.invalidPath("Note has no URL"))
        }

        let targetFolder = folder ?? folderManager.rootFolder
        let targetURL = targetFolder.url.appendingPathComponent(sourceURL.lastPathComponent)

        // Move the file
        try FileManager.default.moveItem(at: sourceURL, to: targetURL)

        // Update note in folder manager
        folderManager.refreshNotes()
    }

    /// Rename a note
    func renameNote(_ note: Note, to newName: String) async throws {
        guard let sourceURL = note.url else {
            throw FerrufiError.fileSystem(.invalidPath("Note has no URL"))
        }

        let targetURL = sourceURL.deletingLastPathComponent()
            .appendingPathComponent("\(newName).mufi")

        // Rename the file
        try FileManager.default.moveItem(at: sourceURL, to: targetURL)

        // Update note content to reflect new title if it contains the old title
        var updatedContent = note.content
        if updatedContent.hasPrefix("# \(note.title)") {
            updatedContent = updatedContent.replacingOccurrences(
                of: "# \(note.title)",
                with: "# \(newName)",
                options: [.anchored]
            )
            try updatedContent.write(to: targetURL, atomically: true, encoding: .utf8)
        }

        // Refresh folder manager
        folderManager.refreshNotes()
    }

    /// Delete a note
    func deleteNote(_ note: Note) async throws {
        guard let url = note.url else {
            throw FerrufiError.fileSystem(.invalidPath("Note has no URL"))
        }

        // Move to trash
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)

        // Remove from recent notes
        removeFromRecentNotes(note)

        // Refresh folder manager
        folderManager.refreshNotes()
    }

    // MARK: - Auto-Save

    /// Schedule auto-save for a note
    func scheduleAutoSave(for note: Note, content: String) {
        guard isAutoSaveEnabled else { return }

        // Cancel existing timer
        autoSaveTimer?.invalidate()

        // Schedule new save
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveDelay, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                await self?.performAutoSave(note: note, content: content)
            }
        }
    }

    private func performAutoSave(note: Note, content: String) async {
        guard let url = note.url else { return }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)

            // Update metadata
            var updatedNote = note
            updatedNote.content = content
            updatedNote.metadata.modifiedAt = Date()
            updatedNote.metadata.wordCount = countWords(in: content)

            folderManager.updateNote(updatedNote)

        } catch {
            print("Auto-save failed: \(error)")
        }
    }

    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // MARK: - Templates

    /// Load note templates
    private func loadTemplates() {
        // Load built-in templates
        templates = getBuiltInTemplates()

        // TODO: Load custom templates from user templates folder
    }

    /// Get built-in note templates
    private func getBuiltInTemplates() -> [NoteTemplate] {
        return [
            NoteTemplate(
                id: "basic",
                name: "Basic Note",
                description: "A simple note template",
                content: """
                    # {{title}}

                    {{content}}

                    ---
                    Created: {{date}}
                    Tags:
                    """
            ),
            NoteTemplate(
                id: "meeting",
                name: "Meeting Notes",
                description: "Template for meeting notes",
                content: """
                    # Meeting: {{title}}

                    **Date:** {{date}}
                    **Attendees:**

                    ## Agenda

                    -

                    ## Discussion



                    ## Action Items

                    - [ ]

                    ## Next Steps


                    """
            ),
            NoteTemplate(
                id: "daily",
                name: "Daily Note",
                description: "Template for daily notes",
                content: """
                    # Daily Note - {{date}}

                    ## Today's Focus

                    -

                    ## Tasks

                    - [ ]

                    ## Notes



                    ## Reflections


                    """
            ),
            NoteTemplate(
                id: "project",
                name: "Project Note",
                description: "Template for project documentation",
                content: """
                    # Project: {{title}}

                    ## Overview



                    ## Goals

                    -

                    ## Timeline

                    | Phase | Description | Due Date |
                    |-------|-------------|----------|
                    |       |             |          |

                    ## Resources

                    -

                    ## Status

                    **Current Status:**
                    **Last Updated:** {{date}}

                    ## Notes


                    """
            ),
        ]
    }

    // MARK: - Recent Notes

    private func loadRecentNotes() {
        // Load from configuration
        if let recentNoteIds = configManager.configuration.recentNoteIds {
            Task {
                var loadedNotes: [Note] = []
                for noteId in recentNoteIds.prefix(10) {  // Keep last 10
                    if let note = folderManager.findNote(by: noteId) {
                        loadedNotes.append(note)
                    }
                }
                await MainActor.run {
                    self.recentNotes = loadedNotes
                }
            }
        }
    }

    private func addToRecentNotes(_ note: Note) {
        // Remove if already exists
        recentNotes.removeAll { $0.id == note.id }

        // Add to beginning
        recentNotes.insert(note, at: 0)

        // Keep only last 10
        if recentNotes.count > 10 {
            recentNotes.removeLast(recentNotes.count - 10)
        }

        // Save to configuration
        saveRecentNotesToConfiguration()
    }

    private func removeFromRecentNotes(_ note: Note) {
        recentNotes.removeAll { $0.id == note.id }
        saveRecentNotesToConfiguration()
    }

    private func saveRecentNotesToConfiguration() {
        let recentIds = recentNotes.map { $0.id }
        configManager.updateConfiguration { config in
            config.recentNoteIds = recentIds
        }
    }

    // MARK: - File Watching

    private func setupFileWatcher() {
        // Watch for external file changes
        if let vaultURL = configManager.configuration.vaultURL {
            fileWatcher = FileWatcher(url: vaultURL) { [weak self] changedURLs in
                Task { @MainActor in
                    await self?.handleExternalFileChanges(changedURLs)
                }
            }
            fileWatcher?.start()
        }
    }

    private func handleExternalFileChanges(_ urls: [URL]) async {
        // Refresh notes if markdown files changed
        let markdownURLs = urls.filter { $0.pathExtension == "md" }
        if !markdownURLs.isEmpty {
            folderManager.refreshNotes()
        }
    }

    // MARK: - Helper Methods

    private func setupConfiguration() {
        isAutoSaveEnabled = configManager.configuration.autoSaveEnabled ?? true
    }

    private func generateNoteName(from template: NoteTemplate) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = dateFormatter.string(from: Date())

        return "\(template.name) \(timestamp)"
    }

    private func processTemplateContent(_ templateContent: String, noteName: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        return
            templateContent
            .replacingOccurrences(of: "{{title}}", with: noteName)
            .replacingOccurrences(of: "{{date}}", with: today)
            .replacingOccurrences(of: "{{content}}", with: "")
    }

    private func getDefaultNoteContent(name: String) -> String {
        return "# \(name)\n\n"
    }

    private func getDailyNoteContent(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let formattedDate = dateFormatter.string(from: date)

        return """
            # Daily Note - \(formattedDate)

            ## Today's Focus

            -

            ## Tasks

            - [ ]

            ## Notes



            ## Reflections


            """
    }

    private func findNoteByName(_ name: String) -> Note? {
        return folderManager.notes.first { note in
            note.title.lowercased() == name.lowercased()
        }
    }

    private func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
}

// MARK: - Supporting Types

struct NoteTemplate: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let content: String
    let tags: [String]
    let category: String

    init(
        id: String, name: String, description: String, content: String, tags: [String] = [],
        category: String = "General"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.content = content
        self.tags = tags
        self.category = category
    }
}

/// Simple file watcher for external changes
final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let callback: @Sendable ([URL]) -> Void
    private let queue = DispatchQueue(label: "FileWatcher", qos: .utility)
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, callback: @escaping @Sendable ([URL]) -> Void) {
        self.url = url
        self.callback = callback
    }

    func start() {
        queue.sync {
            guard source == nil else { return }

            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor != -1 else { return }

            source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete, .extend],
                queue: queue
            )

            source?.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.callback([self.url])
            }

            source?.setCancelHandler {
                close(descriptor)
            }

            source?.resume()
        }
    }

    func stop() {
        queue.sync {
            source?.cancel()
            source = nil
        }
    }
}

// MARK: - Configuration Extensions
// (Extensions moved to Configuration.swift)
