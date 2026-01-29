//
// FileService.swift
// Ferrufi
//
// Unified FileService actor that centralizes file I/O and security-scoped handling.
//
// Provides a simple async API for reading/writing/listing/moving/deleting files while
// ensuring security-scoped access is used consistently. Publishes file change events
// so higher-level systems (UI, watchers) can subscribe.
//
// Design goals:
// - Single place to handle security-scoped access via `SecurityScopedFileAccess`.
// - Keep calling code simple: pass path strings, get results or thrown errors.
// - Emit lightweight change events via Combine for UI synchronization.
// - Non-invasive: preserves existing helpers (bookmarks, SecurityScopedFileAccess).
//

import Combine
import Files
import Foundation

/// Public actor that exposes unified file operations and handles security-scoped access.
public actor FileService {

    // MARK: - Public types

    public enum FileServiceError: Error {
        case invalidPath(String)
        case notAFile(String)
        case notADirectory(String)
        case operationFailed(String, underlying: Error)
    }

    // MARK: - Shared instance

    /// Shared singleton for convenient use across the app
    public static let shared = FileService()

    // MARK: - Synchronous helper APIs
    //
    // These static helpers provide synchronous semantics for legacy or synchronous
    // call sites. They use the existing URL.withSecurityScope / FileManager helpers
    // so they respect macOS security-scoped access. Prefer the async `FileService.shared`
    // methods for new code, but these helpers make it easy to call file operations
    // from synchronous contexts.
    //
    // Added: convenience helpers useful for createWorkspaceDirectoryIfNeeded or other
    // synchronous initialization paths that cannot yet `await` actor methods.

    /// Read text file synchronously (UTF-8). Uses security-scoped access.
    public static func readTextFileSync(atPath path: String) throws -> String {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return try url.withSecurityScope { u in
            try Files.File(path: u.path).readAsString()
        }
    }

    /// Write text file synchronously (UTF-8). Ensures parent directory exists and uses security-scoped access.
    public static func writeTextFileSync(atPath path: String, contents: String) throws {
        let fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let parentURL = fileURL.deletingLastPathComponent()
        
        try parentURL.withSecurityScope { p in
             // Ensure parent exists using FileManager (Files requires existing folder to init Folder)
             try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
             
             let folder = try Files.Folder(path: p.path)
             let file = try folder.createFileIfNeeded(at: fileURL.lastPathComponent)
             try file.write(contents)
        }
    }

    /// Read binary data synchronously. Uses security-scoped access.
    public static func readDataSync(atPath path: String) throws -> Data {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return try url.withSecurityScope { u in
            try Files.File(path: u.path).read()
        }
    }

    /// Write binary data synchronously. Ensures parent directory exists and uses security-scoped access.
    public static func writeDataSync(atPath path: String, data: Data) throws {
        let fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let parentURL = fileURL.deletingLastPathComponent()
        
        try parentURL.withSecurityScope { p in
            try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
            
            let folder = try Files.Folder(path: p.path)
            let file = try folder.createFileIfNeeded(at: fileURL.lastPathComponent)
            try file.write(data)
        }
    }

    /// Create directory synchronously (recursive). Uses security-scoped access.
    public static func createDirectorySync(atPath path: String) throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try url.withSecurityScope { u in
            try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        }
    }

    /// Ensure directory exists and is writable. Returns true when directory exists and is writable.
    /// Uses a small write test to verify writability.
    public static func ensureDirectoryExistsAndWritableSync(atPath path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        do {
            try url.withSecurityScope { u in
                let fm = FileManager.default
                if !fm.fileExists(atPath: u.path) {
                    try fm.createDirectory(at: u, withIntermediateDirectories: true)
                }
                // test file using Files package
                let folder = try Files.Folder(path: u.path)
                let testName = ".ferrufi_write_test_\(UUID().uuidString)"
                let file = try folder.createFile(named: testName)
                try file.delete()
            }
            return true
        } catch {
            return false
        }
    }

    /// Check whether a directory is writable synchronously using a temp file test.
    public static func isDirectoryWritableSync(atPath path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        do {
            return try url.withSecurityScope { u in
                let fm = FileManager.default
                if !fm.fileExists(atPath: u.path) {
                    try fm.createDirectory(at: u, withIntermediateDirectories: true)
                }
                
                let folder = try Files.Folder(path: u.path)
                let testName = ".ferrufi_write_test_\(UUID().uuidString)"
                let file = try folder.createFile(named: testName)
                try file.delete()
                return true
            }
        } catch {
            return false
        }
    }

    /// Delete item synchronously (file or directory). Uses security-scoped access.
    public static func deleteItemSync(atPath path: String) throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try url.withSecurityScope { u in
            if let file = try? Files.File(path: u.path) {
                try file.delete()
            } else if let folder = try? Files.Folder(path: u.path) {
                try folder.delete()
            }
        }
    }

    /// Move item synchronously. Uses security-scoped access for both source and destination.
    public static func moveItemSync(from srcPath: String, to dstPath: String) throws {
        let srcURL = URL(fileURLWithPath: (srcPath as NSString).expandingTildeInPath)
        let dstURL = URL(fileURLWithPath: (dstPath as NSString).expandingTildeInPath)
        let dstParent = dstURL.deletingLastPathComponent()
        
        try dstParent.withSecurityScope { p in
            try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        }
        
        try srcURL.withSecurityScope { s in
            try dstURL.withSecurityScope { d in
                // Files package move requires target folder instance
                if let file = try? Files.File(path: s.path) {
                    let parentFolder = try Files.Folder(path: dstURL.deletingLastPathComponent().path)
                    try file.move(to: parentFolder)
                    if file.name != dstURL.lastPathComponent {
                        try file.rename(to: dstURL.lastPathComponent)
                    }
                } else if let folder = try? Files.Folder(path: s.path) {
                    let parentFolder = try Files.Folder(path: dstURL.deletingLastPathComponent().path)
                    try folder.move(to: parentFolder)
                     if folder.name != dstURL.lastPathComponent {
                        try folder.rename(to: dstURL.lastPathComponent)
                    }
                }
            }
        }
    }

    /// List directory entries synchronously. Returns names (not full paths). Uses security-scoped access.
    public static func listDirectorySync(atPath path: String) throws -> [String] {
        let dirURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return try dirURL.withSecurityScope { u in
            let folder = try Files.Folder(path: u.path)
            let fileNames = folder.files.map { $0.name }
            let folderNames = folder.subfolders.map { $0.name }
            return fileNames + folderNames
        }
    }

    // MARK: - Internals

    private let fileManager = FileManager.default
    private let ssAccess = SecurityScopedFileAccess()  // actor; use `await` when calling
    private let changeSubject = PassthroughSubject<FileChangeEvent, Never>()

    // Expose a Combine publisher for file change events
    public func watchForChanges() -> AnyPublisher<FileChangeEvent, Never> {
        changeSubject.eraseToAnyPublisher()
    }

    // Actor-local helper to manage security-scoped access without sending closures across actors.
    // This ensures we start/stop access on the SecurityScopedFileAccess actor and perform
    // the file-manager work locally inside the FileService actor (avoids sending non-Sendable
    // closures to another actor).
    private func withLocalAccess<T>(_ url: URL, operation: () throws -> T) async throws -> T {
        let accessed = await ssAccess.startAccessing(url)
        do {
            let result = try operation()
            if accessed {
                await ssAccess.stopAccessing(url)
            }
            return result
        } catch {
            if accessed {
                await ssAccess.stopAccessing(url)
            }
            throw error
        }
    }

    // MARK: - High-level helpers

    /// Read text file contents as UTF-8 string.
    public func readTextFile(atPath path: String) async throws -> String {
        let fileURL = URL(fileURLWithPath: path)
        do {
            return try await withLocalAccess(fileURL) {
                try Files.File(path: fileURL.path).readAsString()
            }
        } catch {
            throw FileServiceError.operationFailed("readTextFile(\(path))", underlying: error)
        }
    }

    /// Write text file (UTF-8). Creates parent directory if necessary.
    public func writeTextFile(atPath path: String, contents: String) async throws {
        let fileURL = URL(fileURLWithPath: path)
        let parent = fileURL.deletingLastPathComponent()
        do {
            // Ensure parent directory exists under an appropriate scope.
            try await withLocalAccess(parent) {
                try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                let folder = try Files.Folder(path: parent.path)
                let file = try folder.createFileIfNeeded(at: fileURL.lastPathComponent)
                try file.write(contents)
            }
            
            publishChange(path: path, changeType: .modified)
        } catch {
            throw FileServiceError.operationFailed("writeTextFile(\(path))", underlying: error)
        }
    }

    /// Create directory at path (recursive by default)
    public func createDirectory(atPath path: String, recursive: Bool = true) async throws {
        let dirURL = URL(fileURLWithPath: path)
        do {
            try await withLocalAccess(dirURL) {
                // Files doesn't have a "createDirectory" on bare path easily without a parent folder object
                // Fallback to FileManager for directory creation as it's cleaner than traversing to parent
                try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: recursive)
            }
            publishChange(path: path, changeType: .created)
        } catch {
            throw FileServiceError.operationFailed("createDirectory(\(path))", underlying: error)
        }
    }

    /// Delete file or directory
    public func deleteItem(atPath path: String) async throws {
        let url = URL(fileURLWithPath: path)
        do {
            try await withLocalAccess(url) {
                if let file = try? Files.File(path: url.path) {
                    try file.delete()
                } else if let folder = try? Files.Folder(path: url.path) {
                    try folder.delete()
                }
            }
            publishChange(path: path, changeType: .deleted)
        } catch {
            throw FileServiceError.operationFailed("deleteItem(\(path))", underlying: error)
        }
    }

    /// Move (rename) item
    public func moveItem(from srcPath: String, to dstPath: String) async throws {
        let srcURL = URL(fileURLWithPath: srcPath)
        let dstURL = URL(fileURLWithPath: dstPath)

        // Ensure destination parent exists
        let dstParent = dstURL.deletingLastPathComponent()
        do {
            try await withLocalAccess(dstParent) {
                try fileManager.createDirectory(at: dstParent, withIntermediateDirectories: true)
            }

            // For the move we need active security scope on both src and dst.
            // Start access on both, perform the move locally, then stop access.
            let srcAccessed = await ssAccess.startAccessing(srcURL)
            let dstAccessed = await ssAccess.startAccessing(dstURL)
            do {
                 if let file = try? Files.File(path: srcURL.path) {
                    let parentFolder = try Files.Folder(path: dstURL.deletingLastPathComponent().path)
                    try file.move(to: parentFolder)
                    if file.name != dstURL.lastPathComponent {
                        try file.rename(to: dstURL.lastPathComponent)
                    }
                } else if let folder = try? Files.Folder(path: srcURL.path) {
                    let parentFolder = try Files.Folder(path: dstURL.deletingLastPathComponent().path)
                    try folder.move(to: parentFolder)
                     if folder.name != dstURL.lastPathComponent {
                        try folder.rename(to: dstURL.lastPathComponent)
                    }
                }
            } catch {
                if dstAccessed { await ssAccess.stopAccessing(dstURL) }
                if srcAccessed { await ssAccess.stopAccessing(srcURL) }
                throw error
            }
            if dstAccessed { await ssAccess.stopAccessing(dstURL) }
            if srcAccessed { await ssAccess.stopAccessing(srcURL) }

            publishChange(path: srcPath, changeType: .moved(from: srcPath, to: dstPath))
            publishChange(path: dstPath, changeType: .created)
        } catch {
            throw FileServiceError.operationFailed(
                "moveItem(\(srcPath) -> \(dstPath))", underlying: error)
        }
    }

    /// List directory entries (relative names) at given path. Returns [] for empty directories.
    public func listDirectory(atPath path: String) async throws -> [String] {
        let dirURL = URL(fileURLWithPath: path)
        do {
            return try await withLocalAccess(dirURL) {
                let folder = try Files.Folder(path: dirURL.path)
                let files = folder.files.map { $0.name }
                let subfolders = folder.subfolders.map { $0.name }
                return files + subfolders
            }
        } catch {
            throw FileServiceError.operationFailed("listDirectory(\(path))", underlying: error)
        }
    }

    /// Check existence
    public func exists(atPath path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }

    /// Returns file attributes if available
    public func attributes(atPath path: String) async throws -> [FileAttributeKey: Any] {
        let url = URL(fileURLWithPath: path)
        do {
            return try await withLocalAccess(url) {
                try fileManager.attributesOfItem(atPath: url.path)
            }
        } catch {
            throw FileServiceError.operationFailed("attributes(\(path))", underlying: error)
        }
    }

    // MARK: - Utilities & Notifications

    /// Public API to publish a file change event to subscribers.
    /// This allows external components (for example `FileStorage`) to notify the centralized
    /// file-change publisher rather than sending events directly.
    public func publishFileChange(path: String, changeType: FileChangeType) {
        let ev = FileChangeEvent(path: path, changeType: changeType, timestamp: Date())
        changeSubject.send(ev)
    }

    /// Internal convenience alias retained for backward compatibility within this actor.
    private func publishChange(path: String, changeType: FileChangeType) {
        publishFileChange(path: path, changeType: changeType)
    }

    /// Attempt a safe write test to determine writability. Returns true if the path is writable.
    public func isWritableDirectory(atPath path: String) async -> Bool {
        let dirURL = URL(fileURLWithPath: path)
        let fm = fileManager
        do {
            try await withLocalAccess(dirURL) {
                if !fm.fileExists(atPath: dirURL.path) {
                    try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
                }
            }

            // Create a small temp file and remove it to verify write permissions.
            // Using Files package
            return try await withLocalAccess(dirURL) {
                let folder = try Files.Folder(path: dirURL.path)
                let testName = ".ferrufi_write_test_\(UUID().uuidString)"
                let file = try folder.createFile(named: testName)
                try file.delete()
                return true
            }
        } catch {
            return false
        }
    }

    // Convenience: read binary data
    public func readData(atPath path: String) async throws -> Data {
        let url = URL(fileURLWithPath: path)
        do {
            return try await withLocalAccess(url) {
                try Files.File(path: url.path).read()
            }
        } catch {
            throw FileServiceError.operationFailed("readData(\(path))", underlying: error)
        }
    }

    // Convenience: write binary data
    public func writeData(atPath path: String, data: Data) async throws {
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent()
        do {
            try await withLocalAccess(parent) {
                try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
                let folder = try Files.Folder(path: parent.path)
                let file = try folder.createFileIfNeeded(at: url.lastPathComponent)
                try file.write(data)
            }
            publishChange(path: path, changeType: .modified)
        } catch {
            throw FileServiceError.operationFailed("writeData(\(path))", underlying: error)
        }
    }
}
