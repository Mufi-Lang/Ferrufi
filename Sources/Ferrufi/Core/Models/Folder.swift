//
//  Folder.swift
//  Ferrufi
//
//  Core data model for organizing notes in a hierarchical structure
//

import Foundation

/// Represents a folder in the Ferrufi knowledge management system
public struct Folder: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var path: String
    public var parentId: UUID?
    public var createdAt: Date
    public var modifiedAt: Date
    public var metadata: FolderMetadata

    /// Computed URL property from path
    public var url: URL {
        return URL(fileURLWithPath: path)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        parentId: UUID? = nil,
        metadata: FolderMetadata = FolderMetadata()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.parentId = parentId
        self.metadata = metadata

        let now = Date()
        self.createdAt = now
        self.modifiedAt = now
    }

    /// Updates the folder's modification time
    public mutating func updateModifiedTime() {
        self.modifiedAt = Date()
    }

    /// Returns true if this folder is a root folder
    public var isRoot: Bool {
        return parentId == nil
    }

    /// Returns the folder's depth in the hierarchy
    @MainActor
    public func depth(in folderManager: FolderManager) -> Int {
        guard let parent = parentId,
            let parentFolder = folderManager.folder(with: parent)
        else {
            return 0
        }
        return parentFolder.depth(in: folderManager) + 1
    }

}

/// Additional metadata for folders
public struct FolderMetadata: Codable, Hashable, Sendable {
    public var isExpanded: Bool
    public var sortOrder: FolderSortOrder
    public var color: String?
    public var icon: String?
    public var customProperties: [String: String]

    public init(
        isExpanded: Bool = true,
        sortOrder: FolderSortOrder = .name,
        color: String? = nil,
        icon: String? = nil,
        customProperties: [String: String] = [:]
    ) {
        self.isExpanded = isExpanded
        self.sortOrder = sortOrder
        self.color = color
        self.icon = icon
        self.customProperties = customProperties
    }
}

/// Sort order options for folder contents
public enum FolderSortOrder: String, Codable, CaseIterable, Sendable {
    case name = "name"
    case dateCreated = "date_created"
    case dateModified = "date_modified"
    case size = "size"
    case custom = "custom"
}

/// Manages folder hierarchy and operations
@MainActor
public class FolderManager: ObservableObject {
    @Published public private(set) var folders: [UUID: Folder] = [:]
    @Published public private(set) var folderHierarchy: [UUID: [UUID]] = [:]
    @Published public var notes: [Note] = []
    @Published public var selectedFolder: Folder?

    private var _rootFolder: Folder?

    public var rootFolder: Folder {
        return _rootFolder ?? rootFolders.first ?? Folder(name: "Root", path: "/")
    }

    /// Returns all folders sorted alphabetically
    public var allFolders: [Folder] {
        return Array(folders.values).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    public init() {}

    /// Sets the root folder for the manager
    public func setRootFolder(path: String) {
        _rootFolder = Folder(name: "Ferrufi", path: path)
        addFolder(_rootFolder!)

        // Discover existing subdirectories as folders
        discoverFoldersFromFilesystem()
    }

    /// Adds a folder to the manager
    public func addFolder(_ folder: Folder) {
        folders[folder.id] = folder
        updateHierarchy()
    }

    /// Removes a folder from the manager
    public func removeFolder(with id: UUID) {
        folders.removeValue(forKey: id)
        updateHierarchy()
    }

    /// Gets a folder by ID
    public func folder(with id: UUID) -> Folder? {
        return folders[id]
    }

    /// Gets all root folders (folders with no parent) sorted alphabetically
    public var rootFolders: [Folder] {
        return folders.values.filter { $0.isRoot }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Gets child folders for a given parent folder sorted alphabetically
    public func childFolders(of parentId: UUID) -> [Folder] {
        return folders.values.filter { $0.parentId == parentId }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Gets all child folders recursively
    public func allChildFolders(of parentId: UUID) -> [Folder] {
        var allChildren: [Folder] = []
        let directChildren = childFolders(of: parentId)

        for child in directChildren {
            allChildren.append(child)
            allChildren.append(contentsOf: allChildFolders(of: child.id))
        }

        return allChildren
    }

    /// Updates the folder hierarchy cache
    private func updateHierarchy() {
        folderHierarchy.removeAll()

        for folder in folders.values {
            if let parentId = folder.parentId {
                if folderHierarchy[parentId] == nil {
                    folderHierarchy[parentId] = []
                }
                folderHierarchy[parentId]?.append(folder.id)
            }
        }
    }

    /// Creates a new folder
    public func createFolder(
        name: String,
        path: String,
        parentId: UUID? = nil
    ) -> Folder {
        let folder = Folder(
            name: name,
            path: path,
            parentId: parentId
        )
        addFolder(folder)
        return folder
    }

    /// Moves a folder to a new parent
    public func moveFolder(
        _ folderId: UUID,
        to newParentId: UUID?
    ) throws {
        guard var folder = folders[folderId] else {
            throw FolderError.folderNotFound
        }

        // Check for circular reference
        if let newParentId = newParentId {
            if wouldCreateCircularReference(
                moving: folderId,
                to: newParentId
            ) {
                throw FolderError.circularReference
            }
        }

        folder.parentId = newParentId
        folder.updateModifiedTime()
        folders[folderId] = folder
        updateHierarchy()
    }

    /// Renames a folder
    public func renameFolder(_ folderId: UUID, to newName: String) throws {
        guard var folder = folders[folderId] else {
            throw FolderError.folderNotFound
        }

        // Update folder name and path
        let oldURL = folder.url
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)

        // Rename directory on disk if it exists
        if FileManager.default.fileExists(atPath: oldURL.path) {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
        }

        folder.name = newName
        folder.path = newURL.path
        folder.updateModifiedTime()
        folders[folderId] = folder
    }

    /// Checks if moving a folder would create a circular reference
    private func wouldCreateCircularReference(
        moving folderId: UUID,
        to parentId: UUID
    ) -> Bool {
        var currentParent = parentId
        while let folder = folders[currentParent] {
            if folder.id == folderId {
                return true
            }
            guard let nextParent = folder.parentId else { break }
            currentParent = nextParent
        }
        return false
    }

    /// Gets the full path for a folder
    public func fullPath(for folderId: UUID) -> String {
        guard let folder = folders[folderId] else { return "" }

        if let parentId = folder.parentId {
            let parentPath = fullPath(for: parentId)
            return parentPath.isEmpty ? folder.name : "\(parentPath)/\(folder.name)"
        }

        return folder.name
    }

    /// Selects a folder as the current active folder
    public func selectFolder(_ folder: Folder) {
        selectedFolder = folder
    }

    /// Selects a folder by ID as the current active folder
    public func selectFolder(withId folderId: UUID) {
        if let folder = folders[folderId] {
            selectedFolder = folder
        }
    }

    public func folder(for note: Note) -> Folder? {
        let noteURL = URL(fileURLWithPath: note.filePath)
        let noteDirectoryURL = noteURL.deletingLastPathComponent()

        return folders.values.first { $0.url == noteDirectoryURL }
    }
}

/// Errors that can occur during folder operations
public enum FolderError: LocalizedError, Sendable {
    case folderNotFound
    case circularReference
    case invalidPath
    case folderAlreadyExists

    public var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "Folder not found"
        case .circularReference:
            return "Cannot move folder: would create circular reference"
        case .invalidPath:
            return "Invalid folder path"
        case .folderAlreadyExists:
            return "Folder already exists at this location"
        }
    }
}

extension Folder {
    /// Creates a folder from file system path
    public static func fromPath(
        _ path: String,
        parentId: UUID? = nil
    ) -> Folder {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent

        return Folder(
            name: name,
            path: path,
            parentId: parentId
        )
    }
}

// MARK: - FolderManager Extensions for Note Management

extension FolderManager {
    /// Creates a new note
    public func createNote(name: String, content: String, folder: Folder?) async throws -> Note {
        let targetFolder = folder ?? rootFolder
        let fileName = name.hasSuffix(".mufi") ? name : "\(name).mufi"
        let fileURL = targetFolder.url.appendingPathComponent(fileName)
        let filePath = fileURL.path

        // Check if file already exists
        if FileManager.default.fileExists(atPath: filePath) {
            throw FerrufiError.fileSystem(.fileExists(filePath))
        }

        // Create any intermediate directories if needed
        let parentDirectory = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDirectory.path) {
            try FileManager.default.createDirectory(
                at: parentDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Write content to file with security-scoped access
        try fileURL.withSecurityScope { url in
            try content.write(to: url, atomically: true, encoding: .utf8)
        }

        // Create note object
        let note = Note(
            title: name,
            content: content,
            filePath: filePath
        )

        // Add to notes array
        notes.append(note)

        return note
    }

    /// Updates a note
    public func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        }
    }

    /// Finds a note by ID
    public func findNote(by id: UUID) -> Note? {
        return notes.first { $0.id == id }
    }

    /// Refreshes the notes list by scanning the filesystem
    public func refreshNotes() {
        notes.removeAll()
        loadNotesFromFilesystem()
    }

    /// Loads all notes from the filesystem
    public func loadNotesFromFilesystem() {
        guard let rootPath = _rootFolder?.path else {
            return
        }

        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)

        // Clear existing notes
        notes.removeAll()

        // Rediscover folders first
        discoverFoldersFromFilesystem()

        // Recursively find all .md files
        if let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if ["md", "mufi"].contains(fileURL.pathExtension.lowercased()) {
                    loadNoteFromFile(at: fileURL)
                }
            }
        }

        // Sort notes alphabetically
        notes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Loads a single note from a file
    private func loadNoteFromFile(at url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let title = url.deletingPathExtension().lastPathComponent

            let note = Note(
                title: title,
                content: content,
                filePath: url.path
            )

            notes.append(note)
        } catch {
            // Silently skip files that can't be loaded
        }
    }

    /// Updates the content of an existing note
    func updateNoteContent(_ note: Note, content: String) throws {
        let fileURL = URL(fileURLWithPath: note.filePath)

        // Write the updated content to file with security-scoped access
        try fileURL.withSecurityScope { url in
            try content.write(to: url, atomically: true, encoding: .utf8)
        }

        // Update the note in memory
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updatedNote = note
            updatedNote.content = content
            updatedNote.modifiedAt = Date()
            notes[index] = updatedNote
        }
    }

    /// Discovers folders from the filesystem
    private func discoverFoldersFromFilesystem() {
        guard let rootPath = _rootFolder?.path else {
            return
        }

        let rootURL = URL(fileURLWithPath: rootPath)

        // Keep only the root folder, clear others
        let rootFolderId = _rootFolder!.id
        folders = folders.filter { $0.key == rootFolderId }

        // Recursively discover subdirectories
        discoverFoldersRecursively(at: rootURL, parentId: rootFolderId)

        updateHierarchy()
    }

    /// Recursively discovers folders in a directory
    private func discoverFoldersRecursively(at url: URL, parentId: UUID?) {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for itemURL in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                    isDirectory.boolValue
                {

                    // Create folder if it doesn't exist
                    let folderName = itemURL.lastPathComponent
                    let existingFolder = folders.values.first { folder in
                        folder.path == itemURL.path
                    }

                    let folder: Folder
                    if let existing = existingFolder {
                        folder = existing
                    } else {
                        folder = Folder(
                            name: folderName,
                            path: itemURL.path,
                            parentId: parentId
                        )
                        folders[folder.id] = folder
                    }

                    // Recursively discover subfolders
                    discoverFoldersRecursively(at: itemURL, parentId: folder.id)
                }
            }
        } catch {
            // Silently skip directories that can't be read
        }
    }
}
