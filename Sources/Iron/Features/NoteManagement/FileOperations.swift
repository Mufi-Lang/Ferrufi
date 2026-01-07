//
//  FileOperations.swift
//  Iron
//
//  Created on 2024-12-19.
//

import AppKit
import Foundation

/// Utility class for advanced file operations including import/export and batch operations
class FileOperations {

    // MARK: - Import Operations

    /// Import markdown files from a directory
    static func importMarkdownFiles(from sourceURL: URL, to targetFolder: Folder) throws
        -> [Note]
    {
        let fileManager = FileManager.default
        var importedNotes: [Note] = []

        // Get all markdown files in source directory
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        guard
            let urls = try? fileManager.contentsOfDirectory(
                at: sourceURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
        else {
            throw IronError.fileSystem(.readError("Cannot enumerate source directory"))
        }

        for fileURL in urls {
            guard fileURL.pathExtension == "md" else { continue }

            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let fileName = fileURL.deletingPathExtension().lastPathComponent

                let targetURL = targetFolder.url.appendingPathComponent(fileURL.lastPathComponent)

                // Copy file to target location
                try fileManager.copyItem(at: fileURL, to: targetURL)

                // Create note object
                let note = Note(
                    title: fileName,
                    content: content,
                    filePath: targetURL.path
                )

                importedNotes.append(note)

            } catch {
                print("Failed to import file \(fileURL.lastPathComponent): \(error)")
            }
        }

        return importedNotes
    }

    /// Import Obsidian vault
    static func importObsidianVault(from vaultURL: URL, to targetFolder: Folder) throws
        -> ImportResult
    {
        var importedNotes: [Note] = []
        var importedAttachments: [URL] = []

        let fileManager = FileManager.default

        func processDirectory(at url: URL) throws {
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in urls {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])

                if resourceValues.isDirectory == true {
                    try processDirectory(at: fileURL)
                } else {
                    let pathExtension = fileURL.pathExtension.lowercased()

                    if pathExtension == "md" {
                        // Import markdown file
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        let processedContent = processObsidianContent(content)

                        let targetURL = targetFolder.url.appendingPathComponent(
                            fileURL.lastPathComponent)
                        try processedContent.write(to: targetURL, atomically: true, encoding: .utf8)

                        let note = Note(
                            title: fileURL.deletingPathExtension().lastPathComponent,
                            content: processedContent,
                            filePath: targetURL.path
                        )

                        importedNotes.append(note)

                    } else if ["png", "jpg", "jpeg", "gif", "pdf", "mp4", "mov"].contains(
                        pathExtension)
                    {
                        // Import attachment
                        let attachmentsFolder = targetFolder.url.appendingPathComponent(
                            "attachments", isDirectory: true)
                        try fileManager.createDirectory(
                            at: attachmentsFolder, withIntermediateDirectories: true)

                        let targetURL = attachmentsFolder.appendingPathComponent(
                            fileURL.lastPathComponent)
                        try fileManager.copyItem(at: fileURL, to: targetURL)

                        importedAttachments.append(targetURL)
                    }
                }
            }
        }

        try processDirectory(at: vaultURL)

        return ImportResult(notes: importedNotes, attachments: importedAttachments)
    }

    /// Process Obsidian-specific markdown content
    private static func processObsidianContent(_ content: String) -> String {
        var processedContent = content

        // Convert Obsidian wiki links to standard format if needed
        // Example: [[Note Name]] stays as [[Note Name]]

        // Convert Obsidian tags to standard format
        // Example: #tag stays as #tag

        // Convert attachment links
        processedContent = processedContent.replacingOccurrences(
            of: #"!\[\[([^\]]+)\]\]"#,
            with: "![attachment](attachments/$1)",
            options: .regularExpression
        )

        return processedContent
    }

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
            case .markdown:
                fileName = "\(note.title).md"
                content = note.content

            case .html:
                fileName = "\(note.title).html"
                content = convertMarkdownToHTML(note.content)

            case .pdf:
                // PDF export not implemented yet
                continue

            case .plainText:
                fileName = "\(note.title).txt"
                content = stripMarkdown(note.content)
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
            let newFileName = "\(newTitle).md"
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

    /// Convert markdown to HTML
    private static func convertMarkdownToHTML(_ markdown: String) -> String {
        // This is a basic implementation
        // In production, use a proper markdown library
        let renderer = MarkdownRenderer()
        return renderer.renderToHTML(markdown)
    }

    /// Strip markdown formatting
    private static func stripMarkdown(_ markdown: String) -> String {
        var text = markdown

        // Remove headers
        text = text.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)

        // Remove bold/italic
        text = text.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)

        // Remove links
        text = text.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)

        // Remove code blocks
        text = text.replacingOccurrences(
            of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)

        return text
    }

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
        let ironTempDir = tempDir.appendingPathComponent("iron")

        if FileManager.default.fileExists(atPath: ironTempDir.path) {
            try FileManager.default.removeItem(at: ironTempDir)
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable, Sendable {
    case markdown = "md"
    case html = "html"
    case pdf = "pdf"
    case plainText = "txt"

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .html: return "HTML"
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

extension IronError {
    static func conversion(_ message: String) -> IronError {
        return .fileSystem(.writeError("Conversion Error: \(message)"))
    }
}
