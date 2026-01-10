//
//  SearchIndex.swift
//  Ferrufi
//
//  Search indexing system for notes and content
//

import Combine
import Foundation

/// Protocol for search indexing operations
public protocol SearchIndexProtocol {
    func indexNote(_ note: Note) async
    func removeNote(with id: UUID) async
    func search(_ query: String) async -> [SearchResult]
    func searchByTag(_ tag: String) async -> [SearchResult]
    func searchByTitle(_ title: String) async -> [SearchResult]
    func rebuildIndex() async throws
}

/// Represents a search result with relevance scoring
public struct SearchResult: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let noteId: UUID
    public let title: String
    public let snippet: String
    public let relevanceScore: Double
    public let matchType: MatchType
    public let highlights: [TextRange]

    public init(
        id: UUID = UUID(),
        noteId: UUID,
        title: String,
        snippet: String,
        relevanceScore: Double,
        matchType: MatchType,
        highlights: [TextRange] = []
    ) {
        self.id = id
        self.noteId = noteId
        self.title = title
        self.snippet = snippet
        self.relevanceScore = relevanceScore
        self.matchType = matchType
        self.highlights = highlights
    }
}

/// Types of search matches
public enum MatchType: String, Codable, CaseIterable, Sendable {
    case title = "title"
    case content = "content"
    case tag = "tag"
    case exactMatch = "exact_match"
    case fuzzyMatch = "fuzzy_match"
}

/// Represents a text range for highlighting
public struct TextRange: Codable, Hashable, Sendable {
    public let start: Int
    public let length: Int

    public init(start: Int, length: Int) {
        self.start = start
        self.length = length
    }

    public var end: Int {
        return start + length
    }
}

/// In-memory search index implementation
public class SearchIndex: SearchIndexProtocol, ObservableObject, @unchecked Sendable {

    // MARK: - Private Properties

    private var noteIndex: [UUID: IndexedNote] = [:]
    private var wordIndex: [String: Set<UUID>] = [:]
    private var tagIndex: [String: Set<UUID>] = [:]
    private var titleIndex: [String: Set<UUID>] = [:]

    private let indexQueue = DispatchQueue(label: "Ferrufi.search.index", qos: .utility)
    private let stopWords = Set([
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "is", "are", "was", "were", "be", "been", "have",
        "has", "had", "do", "does", "did", "will", "would", "could", "should",
    ])

    public init() {}

    // MARK: - IndexedNote Structure

    private struct IndexedNote {
        let id: UUID
        let title: String
        let content: String
        let tags: Set<String>
        let words: Set<String>
        let titleWords: Set<String>
        let modifiedAt: Date

        init(from note: Note) {
            self.id = note.id
            self.title = note.title
            self.content = note.content
            self.tags = note.tags
            self.modifiedAt = note.modifiedAt

            // Process words for indexing
            self.words = Self.extractWords(from: note.content)
            self.titleWords = Self.extractWords(from: note.title)
        }

        private static func extractWords(from text: String) -> Set<String> {
            let cleanText =
                text
                .lowercased()
                .components(separatedBy: .punctuationCharacters)
                .joined(separator: " ")

            return Set(
                cleanText
                    .components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.count > 2 }
            )
        }
    }

    // MARK: - Public Methods

    public func indexNote(_ note: Note) async {
        await withCheckedContinuation { continuation in
            indexQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                let indexedNote = IndexedNote(from: note)

                // Remove existing index entries for this note
                self.removeNoteFromIndices(noteId: note.id)

                // Add to note index
                self.noteIndex[note.id] = indexedNote

                // Add to word index
                for word in indexedNote.words {
                    if !self.stopWords.contains(word) {
                        if self.wordIndex[word] == nil {
                            self.wordIndex[word] = Set<UUID>()
                        }
                        self.wordIndex[word]?.insert(note.id)
                    }
                }

                // Add to title index
                for word in indexedNote.titleWords {
                    if !self.stopWords.contains(word) {
                        if self.titleIndex[word] == nil {
                            self.titleIndex[word] = Set<UUID>()
                        }
                        self.titleIndex[word]?.insert(note.id)
                    }
                }

                // Add to tag index
                for tag in indexedNote.tags {
                    if self.tagIndex[tag] == nil {
                        self.tagIndex[tag] = Set<UUID>()
                    }
                    self.tagIndex[tag]?.insert(note.id)
                }

                continuation.resume()
            }
        }
    }

    public func removeNote(with id: UUID) async {
        await withCheckedContinuation { continuation in
            indexQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                self.removeNoteFromIndices(noteId: id)
                self.noteIndex.removeValue(forKey: id)
                continuation.resume()
            }
        }
    }

    public func search(_ query: String) async -> [SearchResult] {
        return await withCheckedContinuation { continuation in
            indexQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                let results = self.performSearch(query: query)
                continuation.resume(returning: results)
            }
        }
    }

    public func searchByTag(_ tag: String) async -> [SearchResult] {
        return await withCheckedContinuation { continuation in
            indexQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                let results = self.searchTag(tag)
                continuation.resume(returning: results)
            }
        }
    }

    public func searchByTitle(_ title: String) async -> [SearchResult] {
        return await withCheckedContinuation { continuation in
            indexQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                let results = self.searchTitle(title)
                continuation.resume(returning: results)
            }
        }
    }

    public func rebuildIndex() async throws {
        await withCheckedContinuation { continuation in
            indexQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                self.clearIndex()
                continuation.resume()
            }
        }
    }

    // MARK: - Private Methods

    private func removeNoteFromIndices(noteId: UUID) {
        guard let indexedNote = noteIndex[noteId] else { return }

        // Remove from word index
        for word in indexedNote.words {
            wordIndex[word]?.remove(noteId)
            if wordIndex[word]?.isEmpty == true {
                wordIndex.removeValue(forKey: word)
            }
        }

        // Remove from title index
        for word in indexedNote.titleWords {
            titleIndex[word]?.remove(noteId)
            if titleIndex[word]?.isEmpty == true {
                titleIndex.removeValue(forKey: word)
            }
        }

        // Remove from tag index
        for tag in indexedNote.tags {
            tagIndex[tag]?.remove(noteId)
            if tagIndex[tag]?.isEmpty == true {
                tagIndex.removeValue(forKey: tag)
            }
        }
    }

    private func performSearch(query: String) -> [SearchResult] {
        let queryWords = extractQueryWords(from: query)
        guard !queryWords.isEmpty else { return [] }

        var candidateNotes: Set<UUID> = Set()
        var wordScores: [UUID: Double] = [:]

        // Find candidate notes and calculate initial scores
        for word in queryWords {
            // Exact word matches
            if let noteIds = wordIndex[word] {
                candidateNotes.formUnion(noteIds)
                for noteId in noteIds {
                    wordScores[noteId, default: 0] += 1.0
                }
            }

            // Title matches (higher weight)
            if let noteIds = titleIndex[word] {
                candidateNotes.formUnion(noteIds)
                for noteId in noteIds {
                    wordScores[noteId, default: 0] += 2.0
                }
            }

            // Fuzzy matches
            let fuzzyMatches = findFuzzyMatches(for: word)
            for (matchWord, similarity) in fuzzyMatches {
                if let noteIds = wordIndex[matchWord] {
                    candidateNotes.formUnion(noteIds)
                    for noteId in noteIds {
                        wordScores[noteId, default: 0] += similarity * 0.5
                    }
                }
            }
        }

        // Create search results
        var results: [SearchResult] = []

        for noteId in candidateNotes {
            guard let indexedNote = noteIndex[noteId] else { continue }

            let baseScore = wordScores[noteId] ?? 0
            let matchType = determineMatchType(query: query, note: indexedNote)
            let highlights = findHighlights(query: query, in: indexedNote.content)
            let snippet = generateSnippet(for: indexedNote.content, highlights: highlights)

            let result = SearchResult(
                noteId: noteId,
                title: indexedNote.title,
                snippet: snippet,
                relevanceScore: baseScore,
                matchType: matchType,
                highlights: highlights
            )

            results.append(result)
        }

        // Sort by relevance score
        results.sort { $0.relevanceScore > $1.relevanceScore }

        return results
    }

    private func searchTag(_ tag: String) -> [SearchResult] {
        guard let noteIds = tagIndex[tag.lowercased()] else { return [] }

        return noteIds.compactMap { noteId in
            guard let indexedNote = noteIndex[noteId] else { return nil }

            return SearchResult(
                noteId: noteId,
                title: indexedNote.title,
                snippet: "Tagged with #\(tag)",
                relevanceScore: 1.0,
                matchType: .tag
            )
        }.sorted { $0.title < $1.title }
    }

    private func searchTitle(_ title: String) -> [SearchResult] {
        let titleWords = extractQueryWords(from: title)
        var candidateNotes: Set<UUID> = Set()

        for word in titleWords {
            if let noteIds = titleIndex[word] {
                candidateNotes.formUnion(noteIds)
            }
        }

        return candidateNotes.compactMap { noteId in
            guard let indexedNote = noteIndex[noteId] else { return nil }

            let similarity = calculateTitleSimilarity(query: title, title: indexedNote.title)

            return SearchResult(
                noteId: noteId,
                title: indexedNote.title,
                snippet: "Title match",
                relevanceScore: similarity,
                matchType: .title
            )
        }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func extractQueryWords(from query: String) -> [String] {
        return
            query
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    private func findFuzzyMatches(for word: String, threshold: Double = 0.7) -> [(String, Double)] {
        var matches: [(String, Double)] = []

        for indexedWord in wordIndex.keys {
            let similarity = calculateLevenshteinSimilarity(word, indexedWord)
            if similarity >= threshold {
                matches.append((indexedWord, similarity))
            }
        }

        return matches.sorted { $0.1 > $1.1 }
    }

    private func calculateLevenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        return maxLength > 0 ? 1.0 - Double(distance) / Double(maxLength) : 1.0
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a1 = Array(s1)
        let a2 = Array(s2)

        var dp = Array(repeating: Array(repeating: 0, count: a2.count + 1), count: a1.count + 1)

        for i in 0...a1.count {
            dp[i][0] = i
        }

        for j in 0...a2.count {
            dp[0][j] = j
        }

        for i in 1...a1.count {
            for j in 1...a2.count {
                if a1[i - 1] == a2[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]) + 1
                }
            }
        }

        return dp[a1.count][a2.count]
    }

    private func determineMatchType(query: String, note: IndexedNote) -> MatchType {
        let queryLower = query.lowercased()

        if note.title.lowercased().contains(queryLower) {
            return .title
        }

        if note.content.lowercased().contains(queryLower) {
            return note.content.lowercased() == queryLower ? .exactMatch : .content
        }

        return .fuzzyMatch
    }

    private func findHighlights(query: String, in content: String) -> [TextRange] {
        let queryLower = query.lowercased()
        let contentLower = content.lowercased()

        var highlights: [TextRange] = []
        var searchRange = contentLower.startIndex..<contentLower.endIndex

        while let range = contentLower.range(of: queryLower, range: searchRange) {
            let start = contentLower.distance(from: contentLower.startIndex, to: range.lowerBound)
            let length = queryLower.count

            highlights.append(TextRange(start: start, length: length))

            searchRange = range.upperBound..<contentLower.endIndex
        }

        return highlights
    }

    private func generateSnippet(for content: String, highlights: [TextRange], maxLength: Int = 150)
        -> String
    {
        guard !highlights.isEmpty else {
            return String(content.prefix(maxLength))
        }

        let firstHighlight = highlights[0]
        let snippetStart = max(0, firstHighlight.start - 50)
        let snippetEnd = min(content.count, firstHighlight.start + maxLength)

        let startIndex = content.index(content.startIndex, offsetBy: snippetStart)
        let endIndex = content.index(content.startIndex, offsetBy: snippetEnd)

        var snippet = String(content[startIndex..<endIndex])

        if snippetStart > 0 {
            snippet = "..." + snippet
        }

        if snippetEnd < content.count {
            snippet += "..."
        }

        return snippet
    }

    private func calculateTitleSimilarity(query: String, title: String) -> Double {
        return calculateLevenshteinSimilarity(query.lowercased(), title.lowercased())
    }

    private func clearIndex() {
        noteIndex.removeAll()
        wordIndex.removeAll()
        tagIndex.removeAll()
        titleIndex.removeAll()
    }
}

// MARK: - SearchIndex Extensions

extension SearchIndex {
    /// Returns statistics about the current index
    public var indexStats: IndexStats {
        return IndexStats(
            totalNotes: noteIndex.count,
            totalWords: wordIndex.count,
            totalTags: tagIndex.count,
            indexSizeBytes: estimateIndexSize()
        )
    }

    private func estimateIndexSize() -> Int {
        // Rough estimation of memory usage
        let noteSize = noteIndex.values.reduce(0) { $0 + $1.content.count + $1.title.count }
        let wordIndexSize = wordIndex.keys.reduce(0) { $0 + $1.count }
        let tagIndexSize = tagIndex.keys.reduce(0) { $0 + $1.count }

        return noteSize + wordIndexSize + tagIndexSize
    }
}

/// Statistics about the search index
public struct IndexStats: Sendable {
    public let totalNotes: Int
    public let totalWords: Int
    public let totalTags: Int
    public let indexSizeBytes: Int

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: Int64(indexSizeBytes))
    }
}
