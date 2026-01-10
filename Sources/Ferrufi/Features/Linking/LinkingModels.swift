//
//  LinkingModels.swift
//  Ferrufi
//
//  Core models for note linking system with wiki-style links, backlinks, and tags
//

import Foundation

// MARK: - Link Types

/// Represents a wiki-style link in a note
public struct WikiLink: Codable, Hashable, Sendable {
    /// The target note title or path
    public let target: String

    /// The display text (if different from target)
    public let displayText: String?

    /// The range in the source text where this link appears
    public let range: NSRange

    /// Whether this link is currently valid (target exists)
    public var isValid: Bool

    /// Optional section/heading anchor
    public let anchor: String?

    public init(
        target: String,
        displayText: String? = nil,
        range: NSRange,
        isValid: Bool = false,
        anchor: String? = nil
    ) {
        self.target = target
        self.displayText = displayText
        self.range = range
        self.isValid = isValid
        self.anchor = anchor
    }

    /// The text that should be displayed for this link
    public var effectiveDisplayText: String {
        return displayText ?? target
    }

    /// Full link text including anchor if present
    public var fullTarget: String {
        if let anchor = anchor {
            return "\(target)#\(anchor)"
        }
        return target
    }
}

/// Represents a backlink from one note to another
public struct Backlink: Codable, Hashable, Sendable {
    /// The note that contains the link
    public let sourceNoteID: String

    /// The note being linked to
    public let targetNoteID: String

    /// The wiki link that created this backlink
    public let wikiLink: WikiLink

    /// Surrounding context where the link appears
    public let context: String

    /// When this backlink was created/last updated
    public let lastUpdated: Date

    public init(
        sourceNoteID: String,
        targetNoteID: String,
        wikiLink: WikiLink,
        context: String,
        lastUpdated: Date = Date()
    ) {
        self.sourceNoteID = sourceNoteID
        self.targetNoteID = targetNoteID
        self.wikiLink = wikiLink
        self.context = context
        self.lastUpdated = lastUpdated
    }
}

/// Represents a tag in a note
public struct NoteTag: Codable, Hashable, Sendable {
    /// The tag name (without # prefix)
    public let name: String

    /// The range in the source text where this tag appears
    public let range: NSRange

    /// Whether this is a nested tag (e.g., #work/projects)
    public var isNested: Bool {
        return name.contains("/")
    }

    /// Parent tag if this is nested
    public var parentTag: String? {
        guard isNested else { return nil }
        let components = name.split(separator: "/")
        guard components.count > 1 else { return nil }
        return String(components.dropLast().joined(separator: "/"))
    }

    /// Child tags if this is a parent
    public var childTag: String? {
        guard isNested else { return nil }
        let components = name.split(separator: "/")
        return components.last.map(String.init)
    }

    public init(name: String, range: NSRange) {
        self.name = name
        self.range = range
    }
}

// MARK: - Link Analysis Results

/// Result of parsing links and tags from a note's content
public struct LinkAnalysis: Codable, Sendable {
    /// Wiki-style links found in the note
    public let wikiLinks: [WikiLink]

    /// Tags found in the note
    public let tags: [NoteTag]

    /// Outgoing links (notes this note links to)
    public let outgoingLinks: Set<String>

    /// Referenced but non-existent notes
    public let brokenLinks: Set<String>

    /// When this analysis was performed
    public let analyzedAt: Date

    public init(
        wikiLinks: [WikiLink],
        tags: [NoteTag],
        outgoingLinks: Set<String>,
        brokenLinks: Set<String>,
        analyzedAt: Date = Date()
    ) {
        self.wikiLinks = wikiLinks
        self.tags = tags
        self.outgoingLinks = outgoingLinks
        self.brokenLinks = brokenLinks
        self.analyzedAt = analyzedAt
    }
}

/// Graph relationship between two notes
public struct NoteConnection: Codable, Hashable, Sendable {
    /// Source note identifier
    public let sourceID: String

    /// Target note identifier
    public let targetID: String

    /// Type of connection
    public let connectionType: ConnectionType

    /// Strength of the connection (0.0 to 1.0)
    public let strength: Double

    /// Number of links between these notes
    public let linkCount: Int

    /// Shared tags between the notes
    public let sharedTags: Set<String>

    public init(
        sourceID: String,
        targetID: String,
        connectionType: ConnectionType,
        strength: Double,
        linkCount: Int,
        sharedTags: Set<String> = []
    ) {
        self.sourceID = sourceID
        self.targetID = targetID
        self.connectionType = connectionType
        self.strength = strength
        self.linkCount = linkCount
        self.sharedTags = sharedTags
    }
}

/// Types of connections between notes
public enum ConnectionType: String, Codable, CaseIterable, Sendable {
    case directLink = "direct"  // Direct wiki link
    case backlink = "backlink"  // Reverse link
    case tagConnection = "tag"  // Connected via shared tags
    case contextual = "contextual"  // Connected via content similarity
}

// MARK: - Graph Data Structures

/// Represents the complete knowledge graph
public struct KnowledgeGraph: Codable, Sendable {
    /// All notes in the graph
    public let notes: [String: GraphNode]

    /// All connections between notes
    public let connections: [NoteConnection]

    /// Tag hierarchy and usage statistics
    public let tagHierarchy: TagHierarchy

    /// When this graph was last updated
    public let lastUpdated: Date

    /// Graph statistics
    public let statistics: GraphStatistics

    public init(
        notes: [String: GraphNode],
        connections: [NoteConnection],
        tagHierarchy: TagHierarchy,
        lastUpdated: Date = Date(),
        statistics: GraphStatistics
    ) {
        self.notes = notes
        self.connections = connections
        self.tagHierarchy = tagHierarchy
        self.lastUpdated = lastUpdated
        self.statistics = statistics
    }
}

/// Represents a note in the knowledge graph
public struct GraphNode: Codable, Hashable, Sendable {
    /// Note identifier
    public let id: String

    /// Note title
    public let title: String

    /// Note creation date
    public let createdAt: Date

    /// Note last modified date
    public let modifiedAt: Date

    /// Number of outgoing links
    public let outgoingLinkCount: Int

    /// Number of incoming links (backlinks)
    public let incomingLinkCount: Int

    /// Tags associated with this note
    public let tags: Set<String>

    /// Calculated importance score (0.0 to 1.0)
    public let importance: Double

    /// Whether this is an orphaned note (no connections)
    public var isOrphan: Bool {
        return outgoingLinkCount == 0 && incomingLinkCount == 0
    }

    /// Total connection count
    public var totalConnections: Int {
        return outgoingLinkCount + incomingLinkCount
    }

    public init(
        id: String,
        title: String,
        createdAt: Date,
        modifiedAt: Date,
        outgoingLinkCount: Int,
        incomingLinkCount: Int,
        tags: Set<String>,
        importance: Double
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.outgoingLinkCount = outgoingLinkCount
        self.incomingLinkCount = incomingLinkCount
        self.tags = tags
        self.importance = importance
    }
}

/// Tag hierarchy and usage information
public struct TagHierarchy: Codable, Sendable {
    /// All tags and their usage counts
    public let tagUsage: [String: Int]

    /// Parent-child relationships between tags
    public let hierarchy: [String: Set<String>]

    /// Tags with the most connections
    public let popularTags: [String]

    public init(
        tagUsage: [String: Int],
        hierarchy: [String: Set<String>],
        popularTags: [String]
    ) {
        self.tagUsage = tagUsage
        self.hierarchy = hierarchy
        self.popularTags = popularTags
    }
}

/// Graph statistics and metrics
public struct GraphStatistics: Codable, Sendable {
    /// Total number of notes
    public let noteCount: Int

    /// Total number of connections
    public let connectionCount: Int

    /// Total number of unique tags
    public let tagCount: Int

    /// Number of orphaned notes
    public let orphanCount: Int

    /// Number of broken links
    public let brokenLinkCount: Int

    /// Average connections per note
    public var averageConnections: Double {
        guard noteCount > 0 else { return 0.0 }
        return Double(connectionCount) / Double(noteCount)
    }

    /// Graph density (0.0 to 1.0)
    public var density: Double {
        guard noteCount > 1 else { return 0.0 }
        let maxPossibleConnections = noteCount * (noteCount - 1)
        return Double(connectionCount) / Double(maxPossibleConnections)
    }

    public init(
        noteCount: Int,
        connectionCount: Int,
        tagCount: Int,
        orphanCount: Int,
        brokenLinkCount: Int
    ) {
        self.noteCount = noteCount
        self.connectionCount = connectionCount
        self.tagCount = tagCount
        self.orphanCount = orphanCount
        self.brokenLinkCount = brokenLinkCount
    }
}

// MARK: - Link Validation

/// Result of validating links in a note
public struct LinkValidationResult: Sendable {
    /// Valid links found
    public let validLinks: [WikiLink]

    /// Broken links found
    public let brokenLinks: [WikiLink]

    /// Suggested fixes for broken links
    public let suggestions: [LinkSuggestion]

    public init(
        validLinks: [WikiLink],
        brokenLinks: [WikiLink],
        suggestions: [LinkSuggestion]
    ) {
        self.validLinks = validLinks
        self.brokenLinks = brokenLinks
        self.suggestions = suggestions
    }
}

/// Suggestion for fixing a broken link
public struct LinkSuggestion: Sendable {
    /// The broken link
    public let brokenLink: WikiLink

    /// Suggested target note
    public let suggestedTarget: String

    /// Confidence score (0.0 to 1.0)
    public let confidence: Double

    /// Reason for the suggestion
    public let reason: String

    public init(
        brokenLink: WikiLink,
        suggestedTarget: String,
        confidence: Double,
        reason: String
    ) {
        self.brokenLink = brokenLink
        self.suggestedTarget = suggestedTarget
        self.confidence = confidence
        self.reason = reason
    }
}

// MARK: - Extensions for NSRange Codable Support
// Note: NSRange already conforms to Codable in Foundation, so no extension needed
