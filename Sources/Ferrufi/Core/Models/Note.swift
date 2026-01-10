//
//  Note.swift
//  Ferrufi
//
//  Core data model for notes with metadata and relationships
//

import Foundation

/// Represents a single note in the Ferrufi knowledge management system
public struct Note: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var content: String
    public var tags: Set<String>
    public var createdAt: Date
    public var modifiedAt: Date
    public var filePath: String
    public var metadata: NoteMetadata

    /// Computed URL property from filePath
    public var url: URL? {
        return URL(fileURLWithPath: filePath)
    }

    public init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        tags: Set<String> = [],
        filePath: String,
        metadata: NoteMetadata = NoteMetadata()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.filePath = filePath
        self.metadata = metadata

        let now = Date()
        self.createdAt = now
        self.modifiedAt = now
    }

    /// Convenience initializer with URL
    public init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        tags: Set<String> = [],
        url: URL,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        metadata: NoteMetadata = NoteMetadata()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.filePath = url.path
        self.metadata = metadata

        let now = Date()
        self.createdAt = createdAt ?? now
        self.modifiedAt = modifiedAt ?? now
    }

    /// Updates the note's modification time
    public mutating func updateModifiedTime() {
        self.modifiedAt = Date()
    }

    /// Adds a tag to the note
    public mutating func addTag(_ tag: String) {
        tags.insert(tag.lowercased())
        updateModifiedTime()
    }

    /// Removes a tag from the note
    public mutating func removeTag(_ tag: String) {
        tags.remove(tag.lowercased())
        updateModifiedTime()
    }

    /// Returns all outgoing links found in the content
    public var outgoingLinks: Set<String> {
        return NoteLinkParser.extractLinks(from: content)
    }

    /// Returns the note's word count
    public var wordCount: Int {
        return content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

/// Additional metadata for notes
public struct NoteMetadata: Codable, Hashable, Sendable {
    public var isFavorite: Bool
    public var isArchived: Bool
    public var isPinned: Bool
    public var customProperties: [String: String]

    /// Convenience properties for compatibility
    public var modifiedAt: Date {
        get {
            if let dateString = customProperties["modifiedAt"],
                let date = ISO8601DateFormatter().date(from: dateString)
            {
                return date
            }
            return Date()
        }
        set {
            customProperties["modifiedAt"] = ISO8601DateFormatter().string(from: newValue)
        }
    }

    public var wordCount: Int {
        get {
            return Int(customProperties["wordCount"] ?? "0") ?? 0
        }
        set {
            customProperties["wordCount"] = String(newValue)
        }
    }

    public init(
        isFavorite: Bool = false,
        isArchived: Bool = false,
        isPinned: Bool = false,
        customProperties: [String: String] = [:]
    ) {
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isPinned = isPinned
        self.customProperties = customProperties
    }
}

/// Represents relationships between notes
public struct NoteRelationship: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let sourceNoteId: UUID
    public let targetNoteId: UUID
    public let relationshipType: RelationshipType
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceNoteId: UUID,
        targetNoteId: UUID,
        relationshipType: RelationshipType
    ) {
        self.id = id
        self.sourceNoteId = sourceNoteId
        self.targetNoteId = targetNoteId
        self.relationshipType = relationshipType
        self.createdAt = Date()
    }
}

/// Types of relationships between notes
public enum RelationshipType: String, Codable, CaseIterable, Sendable {
    case wikiLink = "wiki_link"  // [[Note Title]]
    case reference = "reference"  // Direct reference or mention
    case tag = "tag"  // Shared tag relationship
    case parent = "parent"  // Hierarchical parent
    case child = "child"  // Hierarchical child
}

/// Utility for parsing links from note content
public struct NoteLinkParser: Sendable {
    /// Extracts wiki-style links from text content
    public static func extractLinks(from content: String) -> Set<String> {
        let pattern = #"\[\[([^\]]+)\]\]"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var links = Set<String>()
        for match in matches {
            if let linkRange = Range(match.range(at: 1), in: content) {
                let linkText = String(content[linkRange]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                links.insert(linkText)
            }
        }
        return links
    }

    /// Extracts hashtags from text content
    public static func extractTags(from content: String) -> Set<String> {
        let pattern = #"(?:^|\s)#([a-zA-Z0-9_]+)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var tags = Set<String>()
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: content) {
                let tagText = String(content[tagRange]).lowercased()
                tags.insert(tagText)
            }
        }
        return tags
    }
}

extension Note {
    /// Creates a note from markdown file content
    public static func fromMarkdown(
        filePath: String,
        content: String
    ) -> Note {
        let title =
            extractTitle(from: content)
            ?? URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent

        var note = Note(
            title: title,
            content: content,
            filePath: filePath
        )

        // Extract tags from content
        let extractedTags = NoteLinkParser.extractTags(from: content)
        note.tags = extractedTags

        return note
    }

    /// Extracts title from markdown content (first # header)
    private static func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Sample note for previews and testing
    public static var sample: Note {
        return Note(
            title: "Sample Note",
            content: """
                # Sample Note

                This is a **sample** note with some *italic* text and a [link](https://example.com).

                ## Lists

                - Item 1
                - Item 2
                - Item 3

                ## Code

                ```swift
                let greeting = "Hello, World!"
                print(greeting)
                ```

                #sample #markdown
                """,
            filePath: "/tmp/sample.md"
        )
    }
}
