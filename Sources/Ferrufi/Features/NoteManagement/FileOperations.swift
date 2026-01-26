//
//  FileOperations.swift
//  Ferrufi
//
//  Created on 2024-12-19.
//

import Foundation

/// Utility class for advanced file operations including import/export and batch operations
class FileOperations {

    // MARK: - Import Operations

    // Obsidian import & processing removed.

    // MARK: - Export Operations

    /// Export notes to a directory
    static func exportNotes(_ notes: [Note], to destinationURL: URL, format: ExportFormat)
        throws
    {
        let fileManager = FileManager.default

        // Create destination directory if needed
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        for note in notes {
            let fileName: String
            let content: String

            switch format {
            case .mufi:
                fileName = "\(note.title).mufi"
                content = note.content

            case .pdf:
                // PDF export not implemented yet
                continue

            case .plainText:
                fileName = "\(note.title).txt"
                content = note.content
            }

            let fileURL = destinationURL.appendingPathComponent(fileName)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Batch Operations

    /// Rename multiple files with pattern
    static func batchRename(notes: [Note], pattern: String, replacement: String) throws {
        let fileManager = FileManager.default

        for note in notes {
            guard let sourceURL = note.url else { continue }

            let newTitle = note.title.replacingOccurrences(of: pattern, with: replacement)
            let newFileName = "\(newTitle).mufi"
            let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(
                newFileName)

            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    /// Add tags to multiple notes
    static func batchAddTags(_ tags: [String], to notes: [Note]) throws {
        for note in notes {
            guard let url = note.url else { continue }

            var content = note.content

            // Add tags to front matter or end of content
            let tagString = tags.map { "#\($0)" }.joined(separator: " ")

            if content.hasPrefix("# ") {
                // Insert after title
                let lines = content.components(separatedBy: .newlines)
                if lines.count > 1 {
                    var newLines = lines
                    newLines.insert("\nTags: \(tagString)\n", at: 1)
                    content = newLines.joined(separator: "\n")
                }
            } else {
                // Add at end
                content += "\n\nTags: \(tagString)"
            }

            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Move multiple notes to folder
    static func batchMove(notes: [Note], to targetFolder: Folder) throws {
        let fileManager = FileManager.default

        for note in notes {
            guard let sourceURL = note.url else { continue }

            let destinationURL = targetFolder.url.appendingPathComponent(
                sourceURL.lastPathComponent)
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    // MARK: - Content Processing

    // Content-processing helpers for deprecated Markdown support have been removed.

    // MARK: - File System Utilities

    /// Get file size in bytes
    static func getFileSize(at url: URL) throws -> Int64 {
        let resources = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resources.fileSize ?? 0)
    }

    /// Get creation and modification dates
    static func getFileDates(at url: URL) throws -> (created: Date, modified: Date) {
        let resources = try url.resourceValues(forKeys: [
            .creationDateKey, .contentModificationDateKey,
        ])
        let created = resources.creationDate ?? Date()
        let modified = resources.contentModificationDate ?? Date()
        return (created, modified)
    }

    /// Check if file is writable
    static func isWritable(at url: URL) -> Bool {
        return FileManager.default.isWritableFile(atPath: url.path)
    }

    /// Create backup of file
    static func createBackup(of url: URL) throws -> URL {
        let backupURL = url.appendingPathExtension("backup")
        try FileManager.default.copyItem(at: url, to: backupURL)
        return backupURL
    }

    /// Clean up temporary files
    static func cleanupTemporaryFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let ironTempDir = tempDir.appendingPathComponent("Ferrufi")

        if FileManager.default.fileExists(atPath: ironTempDir.path) {
            try FileManager.default.removeItem(at: ironTempDir)
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable, Sendable {
    case mufi = "mufi"
    case pdf = "pdf"
    case plainText = "txt"

    var displayName: String {
        switch self {
        case .mufi: return "Mufi"
        case .pdf: return "PDF"
        case .plainText: return "Plain Text"
        }
    }

    var fileExtension: String {
        return self.rawValue
    }
}

struct ImportResult: Sendable {
    let notes: [Note]
    let attachments: [URL]

    var totalItems: Int {
        return notes.count + attachments.count
    }
}

// MARK: - Error Extensions

extension FerrufiError {
    static func conversion(_ message: String) -> FerrufiError {
        return .fileSystem(.writeError("Conversion Error: \(message)"))
    }
}
