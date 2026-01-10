//
//  LinkManager.swift
//  Ferrufi
//
//  Link manager for backlink tracking, validation, and note connection management
//

import Combine
import Foundation

/// Manages note linking, backlinks, and validation across the vault
@MainActor
public class LinkManager: ObservableObject {

    // MARK: - Published Properties

    /// All backlinks in the vault, keyed by target note ID
    @Published public private(set) var backlinks: [String: [Backlink]] = [:]

    /// All broken links found in the vault
    @Published public private(set) var brokenLinks: [String: [WikiLink]] = [:]

    /// Link validation results for each note
    @Published public private(set) var validationResults: [String: LinkValidationResult] = [:]

    /// Whether the link manager is currently updating
    @Published public private(set) var isUpdating: Bool = false

    // MARK: - Dependencies

    private let linkParser: LinkParser
    private let storage: any UnifiedStorageProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Internal State

    /// Cache of note titles to IDs for fast lookup
    private var titleToIDMap: [String: String] = [:]

    /// Cache of link analysis results for each note
    private var linkAnalysisCache: [String: LinkAnalysis] = [:]

    /// Queue for processing link updates
    private let updateQueue = DispatchQueue(label: "com.ferrufi.linkmanager", qos: .userInitiated)

    // MARK: - Initialization

    public init(storage: any UnifiedStorageProtocol) {
        self.linkParser = LinkParser()
        self.storage = storage

        setupNotificationObservers()

        // Initial full rebuild
        Task {
            await rebuildAllLinks()
        }
    }

    // MARK: - Public Interface

    /// Get backlinks for a specific note
    public func getBacklinks(for noteID: String) -> [Backlink] {
        return backlinks[noteID] ?? []
    }

    /// Get broken links for a specific note
    public func getBrokenLinks(for noteID: String) -> [WikiLink] {
        return brokenLinks[noteID] ?? []
    }

    /// Get all notes that link to the specified note
    public func getNotesLinkingTo(_ noteID: String) -> [String] {
        return getBacklinks(for: noteID).map(\.sourceNoteID)
    }

    /// Get all notes that the specified note links to
    public func getNotesLinkedFrom(_ noteID: String) -> [String] {
        guard let analysis = linkAnalysisCache[noteID] else { return [] }
        return Array(analysis.outgoingLinks)
    }

    /// Get connection strength between two notes
    public func getConnectionStrength(from sourceID: String, to targetID: String) -> Double {
        let directLinks = getBacklinks(for: targetID)
            .filter { $0.sourceNoteID == sourceID }
            .count

        let reverseLinks = getBacklinks(for: sourceID)
            .filter { $0.sourceNoteID == targetID }
            .count

        let sharedTags = getSharedTags(between: sourceID, and: targetID)

        // Calculate strength based on multiple factors
        let linkStrength = Double(directLinks + reverseLinks) * 0.5
        let tagStrength = Double(sharedTags.count) * 0.2

        return min(1.0, linkStrength + tagStrength)
    }

    /// Get tags shared between two notes
    public func getSharedTags(between noteID1: String, and noteID2: String) -> Set<String> {
        guard let analysis1 = linkAnalysisCache[noteID1],
            let analysis2 = linkAnalysisCache[noteID2]
        else {
            return []
        }

        let tags1 = Set(analysis1.tags.map(\.name))
        let tags2 = Set(analysis2.tags.map(\.name))

        return tags1.intersection(tags2)
    }

    /// Update links for a specific note
    public func updateLinks(for noteID: String, content: String) async {
        await updateLinksInternal(for: noteID, content: content)
    }

    /// Validate all links and return suggestions for broken ones
    public func validateAllLinks() async -> [String: LinkValidationResult] {
        isUpdating = true
        defer { isUpdating = false }

        var results: [String: LinkValidationResult] = [:]

        do {
            let notes = try await storage.listAllNotes()

            for note in notes {
                let content = try await storage.loadNote(id: note.id)?.content ?? ""
                let result = await validateLinks(for: note.id.uuidString, content: content)
                results[note.id.uuidString] = result
            }

            validationResults = results
        } catch {
            print("Error validating links: \(error)")
        }

        return results
    }

    /// Find potential link targets for a given text
    public func findLinkSuggestions(for text: String, excludingNoteID: String? = nil) async
        -> [String]
    {
        do {
            let notes = try await storage.listAllNotes()
            let searchText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            var suggestions: [(note: String, score: Double)] = []

            for note in notes {
                if let excludingNoteID = excludingNoteID, note.id.uuidString == excludingNoteID {
                    continue
                }

                let titleScore = calculateSimilarity(searchText, note.title.lowercased())
                if titleScore > 0.3 {
                    suggestions.append((note.title, titleScore))
                }
            }

            // Sort by relevance score
            suggestions.sort { $0.score > $1.score }

            return suggestions.prefix(5).map(\.note)
        } catch {
            print("Error finding link suggestions: \(error)")
            return []
        }
    }

    /// Rebuild all links and backlinks from scratch
    public func rebuildAllLinks() async {
        isUpdating = true
        defer { isUpdating = false }

        // Clear existing state
        backlinks.removeAll()
        brokenLinks.removeAll()
        validationResults.removeAll()
        linkAnalysisCache.removeAll()
        titleToIDMap.removeAll()

        do {
            let notes = try await storage.listAllNotes()

            // Build title to ID mapping
            for note in notes {
                titleToIDMap[note.title] = note.id.uuidString
            }

            // Process each note
            for note in notes {
                let content = try await storage.loadNote(id: note.id)?.content ?? ""
                await updateLinksInternal(for: note.id.uuidString, content: content)
            }

        } catch {
            print("Error rebuilding links: \(error)")
        }
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        // Listen for note changes
        NotificationCenter.default
            .publisher(for: .noteDidChange)
            .compactMap { notification in
                notification.userInfo?["noteID"] as? String
            }
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] noteID in
                Task { @MainActor [weak self] in
                    await self?.handleNoteChanged(noteID)
                }
            }
            .store(in: &cancellables)

        // Listen for note deletions
        NotificationCenter.default
            .publisher(for: .noteDidDelete)
            .compactMap { notification in
                notification.userInfo?["noteID"] as? String
            }
            .sink { [weak self] noteID in
                Task { @MainActor [weak self] in
                    await self?.handleNoteDeleted(noteID)
                }
            }
            .store(in: &cancellables)
    }

    private func handleNoteChanged(_ noteID: String) async {
        do {
            guard let uuid = UUID(uuidString: noteID),
                let note = try await storage.loadNote(id: uuid)
            else { return }
            await updateLinks(for: noteID, content: note.content)
        } catch {
            print("Error handling note change: \(error)")
        }
    }

    private func handleNoteDeleted(_ noteID: String) async {
        // Remove all backlinks to this note
        backlinks.removeValue(forKey: noteID)

        // Remove from broken links
        brokenLinks.removeValue(forKey: noteID)

        // Remove from validation results
        validationResults.removeValue(forKey: noteID)

        // Remove from cache
        linkAnalysisCache.removeValue(forKey: noteID)

        // Update title mapping
        titleToIDMap = titleToIDMap.filter { $0.value != noteID }

        // Update all other notes that might have linked to this deleted note
        await rebuildAllLinks()
    }

    private func updateLinksInternal(for noteID: String, content: String) async {
        // Parse links and tags from content
        let analysis = linkParser.parseContent(content)
        linkAnalysisCache[noteID] = analysis

        // Update backlinks
        await updateBacklinks(for: noteID, analysis: analysis, content: content)

        // Validate links
        let validationResult = await validateLinks(for: noteID, content: content)
        validationResults[noteID] = validationResult

        // Update broken links
        brokenLinks[noteID] = validationResult.brokenLinks
    }

    private func updateBacklinks(for noteID: String, analysis: LinkAnalysis, content: String) async
    {
        // Remove existing backlinks from this note
        for (targetID, existingBacklinks) in backlinks {
            let filteredBacklinks = existingBacklinks.filter { $0.sourceNoteID != noteID }
            if filteredBacklinks.isEmpty {
                backlinks.removeValue(forKey: targetID)
            } else {
                backlinks[targetID] = filteredBacklinks
            }
        }

        // Add new backlinks
        for wikiLink in analysis.wikiLinks {
            guard let targetID = titleToIDMap[wikiLink.target] else { continue }

            let context = linkParser.extractContext(for: wikiLink, in: content)
            let backlink = Backlink(
                sourceNoteID: noteID,
                targetNoteID: targetID,
                wikiLink: wikiLink,
                context: context
            )

            if backlinks[targetID] == nil {
                backlinks[targetID] = []
            }
            backlinks[targetID]?.append(backlink)
        }
    }

    private func validateLinks(for noteID: String, content: String) async -> LinkValidationResult {
        let analysis = linkParser.parseContent(content)
        var validLinks: [WikiLink] = []
        var brokenLinks: [WikiLink] = []
        var suggestions: [LinkSuggestion] = []

        for wikiLink in analysis.wikiLinks {
            if titleToIDMap[wikiLink.target] != nil {
                var validLink = wikiLink
                validLink.isValid = true
                validLinks.append(validLink)
            } else {
                brokenLinks.append(wikiLink)

                // Generate suggestions for broken links
                let linkSuggestions = await findLinkSuggestions(
                    for: wikiLink.target,
                    excludingNoteID: noteID
                )

                for suggestion in linkSuggestions.prefix(3) {
                    let confidence = calculateSimilarity(
                        wikiLink.target.lowercased(),
                        suggestion.lowercased()
                    )

                    let linkSuggestion = LinkSuggestion(
                        brokenLink: wikiLink,
                        suggestedTarget: suggestion,
                        confidence: confidence,
                        reason: "Similar note title"
                    )

                    suggestions.append(linkSuggestion)
                }
            }
        }

        return LinkValidationResult(
            validLinks: validLinks,
            brokenLinks: brokenLinks,
            suggestions: suggestions
        )
    }

    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let string1 = text1.lowercased()
        let string2 = text2.lowercased()

        // Simple Levenshtein distance-based similarity
        let distance = levenshteinDistance(string1, string2)
        let maxLength = max(string1.count, string2.count)

        guard maxLength > 0 else { return 1.0 }

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func levenshteinDistance(_ string1: String, _ string2: String) -> Int {
        let string1Array = Array(string1)
        let string2Array = Array(string2)
        let string1Count = string1Array.count
        let string2Count = string2Array.count

        if string1Count == 0 { return string2Count }
        if string2Count == 0 { return string1Count }

        var matrix = Array(
            repeating: Array(repeating: 0, count: string2Count + 1), count: string1Count + 1)

        for i in 0...string1Count { matrix[i][0] = i }
        for j in 0...string2Count { matrix[0][j] = j }

        for i in 1...string1Count {
            for j in 1...string2Count {
                let cost = string1Array[i - 1] == string2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,  // deletion
                    matrix[i][j - 1] + 1,  // insertion
                    matrix[i - 1][j - 1] + cost  // substitution
                )
            }
        }

        return matrix[string1Count][string2Count]
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let noteDidChange = Notification.Name("noteDidChange")
    static let noteDidDelete = Notification.Name("noteDidDelete")
    static let linksDidUpdate = Notification.Name("linksDidUpdate")
}

// MARK: - LinkManager Statistics

extension LinkManager {
    /// Get comprehensive link statistics
    public func getLinkStatistics() -> LinkStatistics {
        let totalNotes = linkAnalysisCache.count
        let totalLinks = linkAnalysisCache.values.reduce(0) { $0 + $1.wikiLinks.count }
        let totalBacklinks = backlinks.values.reduce(0) { $0 + $1.count }
        let totalBrokenLinks = brokenLinks.values.reduce(0) { $0 + $1.count }
        let orphanNotes = linkAnalysisCache.filter { noteID, analysis in
            analysis.wikiLinks.isEmpty && (backlinks[noteID]?.isEmpty ?? true)
        }.count

        return LinkStatistics(
            totalNotes: totalNotes,
            totalLinks: totalLinks,
            totalBacklinks: totalBacklinks,
            totalBrokenLinks: totalBrokenLinks,
            orphanNotes: orphanNotes
        )
    }
}

// MARK: - Supporting Structures

public struct LinkStatistics: Sendable {
    public let totalNotes: Int
    public let totalLinks: Int
    public let totalBacklinks: Int
    public let totalBrokenLinks: Int
    public let orphanNotes: Int

    public var averageLinksPerNote: Double {
        guard totalNotes > 0 else { return 0.0 }
        return Double(totalLinks) / Double(totalNotes)
    }

    public var linkHealth: Double {
        guard totalLinks > 0 else { return 1.0 }
        return Double(totalLinks - totalBrokenLinks) / Double(totalLinks)
    }
}
