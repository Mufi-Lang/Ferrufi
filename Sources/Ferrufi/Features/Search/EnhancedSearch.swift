//
//  EnhancedSearch.swift
//  Ferrufi
//
//  Enhanced search system with fuzzy matching, filters, and performance optimization
//

import Combine
import Foundation

// MARK: - Enhanced Search Configuration

public struct EnhancedSearchConfiguration: Sendable {
    public var fuzzyMatchingEnabled: Bool = true
    public var fuzzyThreshold: Double = 0.6
    public var maxResults: Int = 100
    public var searchTimeout: TimeInterval = 2.0
    public var enableStemming: Bool = true
    public var enableSynonyms: Bool = false
    public var caseSensitive: Bool = false
    public var wholeWordOnly: Bool = false
    public var includeContent: Bool = true
    public var includeTags: Bool = true
    public var includeFilenames: Bool = true
    public var recentSearchWeight: Double = 1.2
    public var frequentSearchWeight: Double = 1.1

    public init() {}
}

// MARK: - Search Filter System

public enum SearchFilter: Codable, Hashable, Sendable {
    case tag(String)
    case dateRange(from: Date, to: Date)
    case fileType(String)
    case modifiedAfter(Date)
    case modifiedBefore(Date)
    case wordCount(min: Int, max: Int)
    case hasBacklinks
    case isOrphaned
    case containsImages
    case containsLinks
    case folder(String)
    case author(String)
    case custom(key: String, value: String)

    public var displayName: String {
        switch self {
        case .tag(let tag): return "Tag: #\(tag)"
        case .dateRange(let from, let to):
            return
                "Date: \(DateFormatter.localizedString(from: from, dateStyle: .short, timeStyle: .none)) - \(DateFormatter.localizedString(from: to, dateStyle: .short, timeStyle: .none))"
        case .fileType(let type): return "Type: .\(type)"
        case .modifiedAfter(let date):
            return
                "Modified after: \(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))"
        case .modifiedBefore(let date):
            return
                "Modified before: \(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))"
        case .wordCount(let min, let max): return "Words: \(min)-\(max)"
        case .hasBacklinks: return "Has backlinks"
        case .isOrphaned: return "Orphaned notes"
        case .containsImages: return "Contains images"
        case .containsLinks: return "Contains links"
        case .folder(let folder): return "Folder: \(folder)"
        case .author(let author): return "Author: \(author)"
        case .custom(let key, let value): return "\(key): \(value)"
        }
    }
}

// MARK: - Search Query Parser

public struct SearchQuery: Sendable {
    public let text: String
    public let filters: [SearchFilter]
    public let sortBy: SearchSortOption
    public let ascending: Bool

    public init(
        text: String, filters: [SearchFilter] = [], sortBy: SearchSortOption = .relevance,
        ascending: Bool = false
    ) {
        self.text = text
        self.filters = filters
        self.sortBy = sortBy
        self.ascending = ascending
    }
}

public enum SearchSortOption: String, CaseIterable, Sendable {
    case relevance = "relevance"
    case title = "title"
    case dateModified = "date_modified"
    case dateCreated = "date_created"
    case wordCount = "word_count"
    case fileSize = "file_size"

    public var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .title: return "Title"
        case .dateModified: return "Date Modified"
        case .dateCreated: return "Date Created"
        case .wordCount: return "Word Count"
        case .fileSize: return "File Size"
        }
    }
}

public class SearchQueryParser: @unchecked Sendable {
    private let operators = ["AND", "OR", "NOT", "+", "-"]
    private let filterPrefixes = ["tag:", "folder:", "type:", "author:", "modified:"]

    public init() {}

    public func parseQuery(_ input: String) -> SearchQuery {
        var text = input
        var filters: [SearchFilter] = []
        var sortBy: SearchSortOption = .relevance
        var ascending = false

        // Extract filters
        let filterMatches = extractFilters(from: text)
        filters.append(contentsOf: filterMatches.filters)
        text = filterMatches.cleanedText

        // Extract sort options
        let sortMatches = extractSortOptions(from: text)
        if let sort = sortMatches.sort {
            sortBy = sort
            ascending = sortMatches.ascending
            text = sortMatches.cleanedText
        }

        // Clean up remaining text
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return SearchQuery(text: text, filters: filters, sortBy: sortBy, ascending: ascending)
    }

    private func extractFilters(from text: String) -> (filters: [SearchFilter], cleanedText: String)
    {
        var filters: [SearchFilter] = []
        var cleanedText = text

        // Tag filters: tag:example or #example
        let tagPattern = #"(?:tag:|#)(\w+)"#
        let tagRegex = try! NSRegularExpression(pattern: tagPattern, options: .caseInsensitive)
        let tagMatches = tagRegex.matches(
            in: text, options: [], range: NSRange(location: 0, length: text.count))

        for match in tagMatches.reversed() {
            if let range = Range(match.range, in: text),
                let tagRange = Range(match.range(at: 1), in: text)
            {
                let tag = String(text[tagRange])
                filters.append(.tag(tag))
                cleanedText = cleanedText.replacingCharacters(in: range, with: "")
            }
        }

        // Folder filters: folder:"path" or folder:path
        let folderPattern = #"folder:(?:"([^"]+)"|(\S+))"#
        let folderRegex = try! NSRegularExpression(
            pattern: folderPattern, options: .caseInsensitive)
        let folderMatches = folderRegex.matches(
            in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count))

        for match in folderMatches.reversed() {
            if let range = Range(match.range, in: cleanedText) {
                let folder = extractQuotedOrUnquotedValue(from: cleanedText, match: match)
                filters.append(.folder(folder))
                cleanedText = cleanedText.replacingCharacters(in: range, with: "")
            }
        }

        // Date filters: modified:>2023-01-01, modified:<2023-12-31
        let datePattern = #"modified:([<>]?)(\d{4}-\d{2}-\d{2})"#
        let dateRegex = try! NSRegularExpression(pattern: datePattern, options: .caseInsensitive)
        let dateMatches = dateRegex.matches(
            in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count))

        for match in dateMatches.reversed() {
            if let range = Range(match.range, in: cleanedText),
                let operatorRange = Range(match.range(at: 1), in: cleanedText),
                let dateRange = Range(match.range(at: 2), in: cleanedText)
            {

                let operatorStr = String(cleanedText[operatorRange])
                let dateStr = String(cleanedText[dateRange])

                if let date = parseDate(dateStr) {
                    if operatorStr == ">" {
                        filters.append(.modifiedAfter(date))
                    } else if operatorStr == "<" {
                        filters.append(.modifiedBefore(date))
                    }
                }
                cleanedText = cleanedText.replacingCharacters(in: range, with: "")
            }
        }

        return (filters: filters, cleanedText: cleanedText)
    }

    private func extractSortOptions(from text: String) -> (
        sort: SearchSortOption?, ascending: Bool, cleanedText: String
    ) {
        let sortPattern = #"sort:(\w+)(?:\s+(asc|desc))?"#
        let sortRegex = try! NSRegularExpression(pattern: sortPattern, options: .caseInsensitive)

        if let match = sortRegex.firstMatch(
            in: text, options: [], range: NSRange(location: 0, length: text.count)),
            let range = Range(match.range, in: text),
            let sortRange = Range(match.range(at: 1), in: text)
        {

            let sortStr = String(text[sortRange])
            let directionRange = match.range(at: 2)
            let ascending =
                directionRange.location != NSNotFound
                ? String(text[Range(directionRange, in: text)!]).lowercased() == "asc" : false

            if let sortOption = SearchSortOption(rawValue: sortStr.lowercased()) {
                let cleanedText = text.replacingCharacters(in: range, with: "")
                return (sort: sortOption, ascending: ascending, cleanedText: cleanedText)
            }
        }

        return (sort: nil, ascending: false, cleanedText: text)
    }

    private func extractQuotedOrUnquotedValue(from text: String, match: NSTextCheckingResult)
        -> String
    {
        if match.range(at: 1).location != NSNotFound,
            let quotedRange = Range(match.range(at: 1), in: text)
        {
            return String(text[quotedRange])
        } else if match.range(at: 2).location != NSNotFound,
            let unquotedRange = Range(match.range(at: 2), in: text)
        {
            return String(text[unquotedRange])
        }
        return ""
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }
}

// MARK: - Enhanced Search Result

public struct EnhancedSearchResult: Identifiable, Sendable {
    public let id = UUID()
    public let noteId: UUID
    public let title: String
    public let snippet: String
    public let relevanceScore: Double
    public let matchType: MatchType
    public let highlights: [TextRange]
    public let metadata: SearchResultMetadata
    public let fuzzyMatches: [FuzzyMatch]

    public init(
        noteId: UUID,
        title: String,
        snippet: String,
        relevanceScore: Double,
        matchType: MatchType,
        highlights: [TextRange] = [],
        metadata: SearchResultMetadata,
        fuzzyMatches: [FuzzyMatch] = []
    ) {
        self.noteId = noteId
        self.title = title
        self.snippet = snippet
        self.relevanceScore = relevanceScore
        self.matchType = matchType
        self.highlights = highlights
        self.metadata = metadata
        self.fuzzyMatches = fuzzyMatches
    }
}

public struct SearchResultMetadata: Sendable {
    public let filePath: String
    public let fileSize: Int
    public let wordCount: Int
    public let createdAt: Date
    public let modifiedAt: Date
    public let tags: [String]
    public let backlinkCount: Int
    public let forwardLinkCount: Int
    public let hasImages: Bool

    public init(
        filePath: String,
        fileSize: Int,
        wordCount: Int,
        createdAt: Date,
        modifiedAt: Date,
        tags: [String],
        backlinkCount: Int,
        forwardLinkCount: Int,
        hasImages: Bool
    ) {
        self.filePath = filePath
        self.fileSize = fileSize
        self.wordCount = wordCount
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.backlinkCount = backlinkCount
        self.forwardLinkCount = forwardLinkCount
        self.hasImages = hasImages
    }
}

public struct FuzzyMatch: Sendable {
    public let term: String
    public let match: String
    public let score: Double
    public let positions: [Int]

    public init(term: String, match: String, score: Double, positions: [Int]) {
        self.term = term
        self.match = match
        self.score = score
        self.positions = positions
    }
}

// MARK: - Enhanced Search Engine

@MainActor
public class EnhancedSearchEngine: ObservableObject {
    @Published public private(set) var isSearching = false
    @Published public private(set) var lastResults: [EnhancedSearchResult] = []
    @Published public private(set) var searchStatistics: SearchStatistics?

    private let baseIndex: SearchIndex
    private let configuration: EnhancedSearchConfiguration
    private let queryParser = SearchQueryParser()
    private let searchHistory = RecentSearchManager()
    private var currentSearchTask: Task<Void, Never>?

    public init(
        baseIndex: SearchIndex,
        configuration: EnhancedSearchConfiguration = EnhancedSearchConfiguration()
    ) {
        self.baseIndex = baseIndex
        self.configuration = configuration
    }

    public func search(_ queryString: String) async -> [EnhancedSearchResult] {
        // Cancel previous search
        currentSearchTask?.cancel()

        guard !queryString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.lastResults = []
                self.isSearching = false
            }
            return []
        }

        let query = queryParser.parseQuery(queryString)

        await MainActor.run {
            self.isSearching = true
        }

        currentSearchTask = Task {
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                let results = try await performEnhancedSearch(query)
                let endTime = CFAbsoluteTimeGetCurrent()

                let statistics = SearchStatistics(
                    query: queryString,
                    resultCount: results.count,
                    searchTime: endTime - startTime,
                    filtersApplied: query.filters.count
                )

                await MainActor.run {
                    self.lastResults = results
                    self.searchStatistics = statistics
                    self.isSearching = false
                }

                // Update search history
                searchHistory.addSearch(queryString, resultCount: results.count)

            } catch {
                await MainActor.run {
                    self.lastResults = []
                    self.isSearching = false
                }
            }
        }

        await currentSearchTask?.value
        return lastResults
    }

    private func performEnhancedSearch(_ query: SearchQuery) async throws -> [EnhancedSearchResult]
    {
        // Get base results from the existing search index
        let baseResults = await baseIndex.search(query.text)

        // Convert to enhanced results with metadata
        let enhancedResults = await withTaskGroup(of: EnhancedSearchResult?.self) { group in
            for result in baseResults {
                group.addTask {
                    await self.enhanceSearchResult(result, query: query)
                }
            }

            var enhanced: [EnhancedSearchResult] = []
            for await result in group {
                if let result = result {
                    enhanced.append(result)
                }
            }
            return enhanced
        }

        // Apply filters
        let filteredResults = applyFilters(enhancedResults, filters: query.filters)

        // Apply fuzzy matching if enabled
        let fuzzyResults =
            configuration.fuzzyMatchingEnabled
            ? await applyFuzzyMatching(filteredResults, query: query.text) : filteredResults

        // Sort results
        let sortedResults = sortResults(fuzzyResults, by: query.sortBy, ascending: query.ascending)

        // Limit results
        let limitedResults = Array(sortedResults.prefix(configuration.maxResults))

        return limitedResults
    }

    private func enhanceSearchResult(_ result: SearchResult, query: SearchQuery) async
        -> EnhancedSearchResult?
    {
        // This would typically fetch additional metadata from the note
        // For now, we'll create basic metadata
        let metadata = SearchResultMetadata(
            filePath: "path/to/note.md",
            fileSize: result.snippet.count * 8,  // Rough estimate
            wordCount: result.snippet.components(separatedBy: .whitespacesAndNewlines).count,
            createdAt: Date(),
            modifiedAt: Date(),
            tags: [],
            backlinkCount: 0,
            forwardLinkCount: 0,
            hasImages: false
        )

        return EnhancedSearchResult(
            noteId: result.noteId,
            title: result.title,
            snippet: result.snippet,
            relevanceScore: result.relevanceScore,
            matchType: result.matchType,
            highlights: result.highlights,
            metadata: metadata
        )
    }

    private func applyFilters(_ results: [EnhancedSearchResult], filters: [SearchFilter])
        -> [EnhancedSearchResult]
    {
        return results.filter { result in
            for filter in filters {
                if !matchesFilter(result, filter: filter) {
                    return false
                }
            }
            return true
        }
    }

    private func matchesFilter(_ result: EnhancedSearchResult, filter: SearchFilter) -> Bool {
        switch filter {
        case .tag(let tag):
            return result.metadata.tags.contains(tag)
        case .dateRange(let from, let to):
            return result.metadata.modifiedAt >= from && result.metadata.modifiedAt <= to
        case .fileType(let type):
            return result.metadata.filePath.hasSuffix(".\(type)")
        case .modifiedAfter(let date):
            return result.metadata.modifiedAt > date
        case .modifiedBefore(let date):
            return result.metadata.modifiedAt < date
        case .wordCount(let min, let max):
            return result.metadata.wordCount >= min && result.metadata.wordCount <= max
        case .hasBacklinks:
            return result.metadata.backlinkCount > 0
        case .isOrphaned:
            return result.metadata.backlinkCount == 0 && result.metadata.forwardLinkCount == 0
        case .containsImages:
            return result.metadata.hasImages
        case .containsLinks:
            return result.metadata.forwardLinkCount > 0
        case .folder(let folder):
            return result.metadata.filePath.contains(folder)
        case .author(_):
            return true  // Not implemented yet
        case .custom(_, _):
            return true  // Not implemented yet
        }
    }

    private func applyFuzzyMatching(_ results: [EnhancedSearchResult], query: String) async
        -> [EnhancedSearchResult]
    {
        let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)

        return results.compactMap { result in
            var fuzzyMatches: [FuzzyMatch] = []
            var totalFuzzyScore = 0.0

            for queryWord in queryWords {
                if let bestMatch = findBestFuzzyMatch(
                    queryWord, in: result.title + " " + result.snippet)
                {
                    fuzzyMatches.append(bestMatch)
                    totalFuzzyScore += bestMatch.score
                }
            }

            // Only include if fuzzy score meets threshold
            let averageFuzzyScore = totalFuzzyScore / Double(max(queryWords.count, 1))
            guard averageFuzzyScore >= configuration.fuzzyThreshold else { return nil }

            // Update relevance score with fuzzy matching
            let enhancedScore = result.relevanceScore * (1.0 + averageFuzzyScore * 0.5)

            return EnhancedSearchResult(
                noteId: result.noteId,
                title: result.title,
                snippet: result.snippet,
                relevanceScore: enhancedScore,
                matchType: result.matchType,
                highlights: result.highlights,
                metadata: result.metadata,
                fuzzyMatches: fuzzyMatches
            )
        }
    }

    private func findBestFuzzyMatch(_ query: String, in text: String) -> FuzzyMatch? {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var bestMatch: FuzzyMatch?
        var bestScore = 0.0

        for word in words {
            let score = calculateFuzzyScore(query, word)
            if score > bestScore {
                bestScore = score
                bestMatch = FuzzyMatch(
                    term: query,
                    match: word,
                    score: score,
                    positions: findMatchPositions(query, in: word)
                )
            }
        }

        return bestMatch
    }

    private func calculateFuzzyScore(_ query: String, _ target: String) -> Double {
        // Simple Jaro-Winkler-like algorithm
        let queryChars = Array(query.lowercased())
        let targetChars = Array(target.lowercased())

        let maxLength = max(queryChars.count, targetChars.count)
        guard maxLength > 0 else { return 0.0 }

        var matches = 0
        let matchWindow = max(maxLength / 2 - 1, 0)

        var queryMatched = Array(repeating: false, count: queryChars.count)
        var targetMatched = Array(repeating: false, count: targetChars.count)

        // Find matches
        for i in 0..<queryChars.count {
            let start = max(0, i - matchWindow)
            let end = min(i + matchWindow + 1, targetChars.count)

            for j in start..<end {
                if !targetMatched[j] && queryChars[i] == targetChars[j] {
                    queryMatched[i] = true
                    targetMatched[j] = true
                    matches += 1
                    break
                }
            }
        }

        guard matches > 0 else { return 0.0 }

        // Calculate transpositions
        var transpositions = 0
        var j = 0
        for i in 0..<queryChars.count {
            if queryMatched[i] {
                while !targetMatched[j] {
                    j += 1
                }
                if queryChars[i] != targetChars[j] {
                    transpositions += 1
                }
                j += 1
            }
        }

        let jaroSimilarity =
            (Double(matches) / Double(queryChars.count) + Double(matches)
                / Double(targetChars.count) + Double(matches - transpositions / 2) / Double(matches))
            / 3.0

        return jaroSimilarity
    }

    private func findMatchPositions(_ query: String, in target: String) -> [Int] {
        let queryChars = Array(query.lowercased())
        let targetChars = Array(target.lowercased())
        var positions: [Int] = []

        var queryIndex = 0
        for (targetIndex, char) in targetChars.enumerated() {
            if queryIndex < queryChars.count && char == queryChars[queryIndex] {
                positions.append(targetIndex)
                queryIndex += 1
            }
        }

        return positions
    }

    private func sortResults(
        _ results: [EnhancedSearchResult], by sortOption: SearchSortOption, ascending: Bool
    ) -> [EnhancedSearchResult] {
        return results.sorted { lhs, rhs in
            let comparison: Bool

            switch sortOption {
            case .relevance:
                comparison = lhs.relevanceScore > rhs.relevanceScore
            case .title:
                comparison =
                    lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .dateModified:
                comparison = lhs.metadata.modifiedAt > rhs.metadata.modifiedAt
            case .dateCreated:
                comparison = lhs.metadata.createdAt > rhs.metadata.createdAt
            case .wordCount:
                comparison = lhs.metadata.wordCount > rhs.metadata.wordCount
            case .fileSize:
                comparison = lhs.metadata.fileSize > rhs.metadata.fileSize
            }

            return ascending ? !comparison : comparison
        }
    }

    public func getRecentSearches() -> [String] {
        return searchHistory.getRecentSearches()
    }

    public func clearSearchHistory() {
        searchHistory.clearHistory()
    }
}

// MARK: - Search Statistics

public struct SearchStatistics: Sendable {
    public let query: String
    public let resultCount: Int
    public let searchTime: TimeInterval
    public let filtersApplied: Int
    public let timestamp: Date

    public init(query: String, resultCount: Int, searchTime: TimeInterval, filtersApplied: Int) {
        self.query = query
        self.resultCount = resultCount
        self.searchTime = searchTime
        self.filtersApplied = filtersApplied
        self.timestamp = Date()
    }

    public var formattedSearchTime: String {
        if searchTime < 0.001 {
            return "<1ms"
        } else if searchTime < 1.0 {
            return String(format: "%.0fms", searchTime * 1000)
        } else {
            return String(format: "%.2fs", searchTime)
        }
    }
}

// MARK: - Recent Search Manager

public class RecentSearchManager: @unchecked Sendable {
    private let maxRecentSearches = 20
    private var recentSearches: [(query: String, count: Int, timestamp: Date)] = []
    private let queue = DispatchQueue(label: "recent-searches", qos: .utility)

    public init() {}

    public func addSearch(_ query: String, resultCount: Int) {
        queue.async {
            // Remove existing entry for this query
            self.recentSearches.removeAll { $0.query == query }

            // Add new entry at the beginning
            self.recentSearches.insert((query: query, count: resultCount, timestamp: Date()), at: 0)

            // Trim to max size
            if self.recentSearches.count > self.maxRecentSearches {
                self.recentSearches.removeLast()
            }
        }
    }

    public func getRecentSearches() -> [String] {
        return queue.sync {
            return recentSearches.map { $0.query }
        }
    }

    public func clearHistory() {
        queue.async {
            self.recentSearches.removeAll()
        }
    }
}
