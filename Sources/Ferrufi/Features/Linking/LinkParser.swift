//
//  LinkParser.swift
//  Ferrufi
//
//  Link parser for detecting wiki-style links and tags in markdown content
//

import Foundation
import RegexBuilder

/// Parser for extracting wiki-style links and tags from markdown text
public final class LinkParser: @unchecked Sendable {

    // MARK: - Regular Expressions

    /// Matches wiki-style links: [[Note Title]], [[Note Title|Display Text]], [[Note Title#anchor]]
    private static let wikiLinkRegex = try! NSRegularExpression(
        pattern: #"\[\[([^\]|#]+)(?:#([^\]|]+))?(?:\|([^\]]+))?\]\]"#,
        options: [.caseInsensitive]
    )

    /// Matches hashtags: #tag, #nested/tag
    private static let hashtagRegex = try! NSRegularExpression(
        pattern: #"(?:^|\s)#([a-zA-Z0-9_/-]+)(?=\s|$|[.,!?;:])"#,
        options: [.caseInsensitive]
    )

    /// Matches code blocks to exclude from parsing
    private static let codeBlockRegex = try! NSRegularExpression(
        pattern: #"```[\s\S]*?```|`[^`\n]*`"#,
        options: []
    )

    /// Matches HTML comments to exclude from parsing
    private static let htmlCommentRegex = try! NSRegularExpression(
        pattern: #"<!--[\s\S]*?-->"#,
        options: []
    )

    // MARK: - Parsing Methods

    /// Parse all links and tags from markdown content
    public func parseContent(_ content: String) -> LinkAnalysis {
        let excludedRanges = findExcludedRanges(in: content)

        let wikiLinks = parseWikiLinks(in: content, excluding: excludedRanges)
        let tags = parseTags(in: content, excluding: excludedRanges)

        let outgoingLinks = Set(wikiLinks.map(\.target))
        let brokenLinks: Set<String> = []  // Will be populated by validation

        return LinkAnalysis(
            wikiLinks: wikiLinks,
            tags: tags,
            outgoingLinks: outgoingLinks,
            brokenLinks: brokenLinks
        )
    }

    /// Parse only wiki-style links from content
    public func parseWikiLinks(in content: String, excluding excludedRanges: [NSRange] = [])
        -> [WikiLink]
    {
        let range = NSRange(location: 0, length: content.count)
        var links: [WikiLink] = []

        Self.wikiLinkRegex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            guard let match = match else { return }

            // Skip if this match is in an excluded range (code block, etc.)
            if excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                return
            }

            // Extract components
            let fullRange = match.range
            let targetRange = match.range(at: 1)
            let anchorRange = match.range(at: 2)
            let displayRange = match.range(at: 3)

            guard targetRange.location != NSNotFound else { return }

            let target = String(content[Range(targetRange, in: content)!]).trimmingCharacters(
                in: .whitespacesAndNewlines)

            let anchor: String? = {
                guard anchorRange.location != NSNotFound else { return nil }
                return String(content[Range(anchorRange, in: content)!]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }()

            let displayText: String? = {
                guard displayRange.location != NSNotFound else { return nil }
                return String(content[Range(displayRange, in: content)!]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }()

            let link = WikiLink(
                target: target,
                displayText: displayText,
                range: fullRange,
                isValid: false,  // Will be validated separately
                anchor: anchor
            )

            links.append(link)
        }

        return links
    }

    /// Parse hashtags from content
    public func parseTags(in content: String, excluding excludedRanges: [NSRange] = []) -> [NoteTag]
    {
        let range = NSRange(location: 0, length: content.count)
        var tags: [NoteTag] = []

        Self.hashtagRegex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            guard let match = match else { return }

            // Skip if this match is in an excluded range
            if excludedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                return
            }

            let tagRange = match.range(at: 1)
            guard tagRange.location != NSNotFound else { return }

            let tagName = String(content[Range(tagRange, in: content)!])

            // Adjust range to include the # symbol
            let fullRange = NSRange(
                location: match.range.location + (match.range.length - tagRange.length - 1),
                length: tagRange.length + 1
            )

            let tag = NoteTag(name: tagName, range: fullRange)
            tags.append(tag)
        }

        return tags
    }

    // MARK: - Context Extraction

    /// Extract context around a link for backlink display
    public func extractContext(for link: WikiLink, in content: String, contextLength: Int = 100)
        -> String
    {
        let range = link.range
        let contentLength = content.count

        // Calculate context bounds
        let startLocation = max(0, range.location - contextLength / 2)
        let endLocation = min(contentLength, range.location + range.length + contextLength / 2)

        let contextRange = NSRange(location: startLocation, length: endLocation - startLocation)

        guard let swiftRange = Range(contextRange, in: content) else {
            return String(content[Range(range, in: content)!])
        }

        var context = String(content[swiftRange])

        // Add ellipsis if we truncated
        if startLocation > 0 {
            context = "..." + context
        }
        if endLocation < contentLength {
            context = context + "..."
        }

        return context.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Link Generation

    /// Generate a wiki link string for a given target
    public func generateWikiLink(target: String, displayText: String? = nil, anchor: String? = nil)
        -> String
    {
        var linkText = target

        if let anchor = anchor {
            linkText += "#\(anchor)"
        }

        if let displayText = displayText, displayText != target {
            linkText += "|\(displayText)"
        }

        return "[[\(linkText)]]"
    }

    /// Generate a hashtag string
    public func generateHashtag(_ tagName: String) -> String {
        return "#\(tagName)"
    }

    // MARK: - Text Manipulation

    /// Insert a wiki link at the specified location
    public func insertWikiLink(
        in content: String,
        at location: Int,
        target: String,
        displayText: String? = nil,
        anchor: String? = nil
    ) -> String {
        let linkText = generateWikiLink(target: target, displayText: displayText, anchor: anchor)

        var mutableContent = content
        let insertionPoint = mutableContent.index(mutableContent.startIndex, offsetBy: location)
        mutableContent.insert(contentsOf: linkText, at: insertionPoint)

        return mutableContent
    }

    /// Replace a range of text with a wiki link
    public func replaceWithWikiLink(
        in content: String,
        range: NSRange,
        target: String,
        displayText: String? = nil,
        anchor: String? = nil
    ) -> String {
        guard let swiftRange = Range(range, in: content) else { return content }

        let linkText = generateWikiLink(target: target, displayText: displayText, anchor: anchor)
        var mutableContent = content
        mutableContent.replaceSubrange(swiftRange, with: linkText)

        return mutableContent
    }

    /// Convert selected text to a wiki link
    public func convertSelectionToWikiLink(
        in content: String,
        selectionRange: NSRange,
        target: String? = nil
    ) -> (newContent: String, linkRange: NSRange) {
        guard let swiftRange = Range(selectionRange, in: content) else {
            return (content, selectionRange)
        }

        let selectedText = String(content[swiftRange])
        let linkTarget = target ?? selectedText
        let linkText = generateWikiLink(
            target: linkTarget, displayText: selectedText != linkTarget ? selectedText : nil)

        var mutableContent = content
        mutableContent.replaceSubrange(swiftRange, with: linkText)

        let newRange = NSRange(location: selectionRange.location, length: linkText.count)

        return (mutableContent, newRange)
    }

    // MARK: - Validation Helpers

    /// Check if a string is a valid wiki link target
    public func isValidLinkTarget(_ target: String) -> Bool {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.contains(where: { "[]|#".contains($0) })
    }

    /// Check if a string is a valid tag name
    public func isValidTagName(_ tagName: String) -> Bool {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed.range(of: #"^[a-zA-Z0-9_/-]+$"#, options: .regularExpression) != nil
    }

    // MARK: - Private Helper Methods

    /// Find ranges that should be excluded from link parsing (code blocks, comments, etc.)
    private func findExcludedRanges(in content: String) -> [NSRange] {
        let range = NSRange(location: 0, length: content.count)
        var excludedRanges: [NSRange] = []

        // Code blocks
        Self.codeBlockRegex.enumerateMatches(in: content, options: [], range: range) {
            match, _, _ in
            if let match = match {
                excludedRanges.append(match.range)
            }
        }

        // HTML comments
        Self.htmlCommentRegex.enumerateMatches(in: content, options: [], range: range) {
            match, _, _ in
            if let match = match {
                excludedRanges.append(match.range)
            }
        }

        return excludedRanges.sorted { $0.location < $1.location }
    }
}

// MARK: - Link Parsing Extensions

extension String {
    /// Extract all wiki links from this string
    func extractWikiLinks() -> [WikiLink] {
        let parser = LinkParser()
        return parser.parseWikiLinks(in: self, excluding: [])
    }

    /// Extract all tags from this string
    func extractTags() -> [NoteTag] {
        let parser = LinkParser()
        return parser.parseTags(in: self, excluding: [])
    }

    /// Parse full link analysis from this string
    func analyzeLinkContent() -> LinkAnalysis {
        let parser = LinkParser()
        return parser.parseContent(self)
    }
}

// MARK: - Range Utilities

extension NSRange {
    /// Check if this range intersects with another range
    func intersects(with other: NSRange) -> Bool {
        return NSIntersectionRange(self, other).length > 0
    }
}
