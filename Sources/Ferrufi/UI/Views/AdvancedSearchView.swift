//
//  AdvancedSearchView.swift
//  Ferrufi
//
//  Advanced search interface with filters, real-time results, and enhanced UX
//

import Combine
import SwiftUI

// MARK: - Advanced Search View

public struct AdvancedSearchView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    @StateObject private var searchEngine: EnhancedSearchEngine
    @State private var searchText = ""
    @State private var activeFilters: [SearchFilter] = []
    @State private var sortOption: SearchSortOption = .relevance
    @State private var sortAscending = false
    @State private var showFilters = false
    @State private var showAdvanced = false
    @State private var searchResults: [EnhancedSearchResult] = []
    @State private var isSearching = false
    @State private var searchStatistics: SearchStatistics?

    // Filter states
    @State private var selectedTags: Set<String> = []
    @State private var dateRangeStart: Date =
        Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var dateRangeEnd: Date = Date()
    @State private var selectedFolder = ""
    @State private var minWordCount = 0
    @State private var maxWordCount = 10000
    @State private var showOrphaned = false
    @State private var showWithBacklinks = false

    private let searchDebouncer = PassthroughSubject<String, Never>()

    public init() {
        // Initialize with a placeholder - will be set up properly in onAppear
        _searchEngine = StateObject(
            wrappedValue: EnhancedSearchEngine(
                baseIndex: SearchIndex(),
                configuration: EnhancedSearchConfiguration()
            ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Header
            searchHeader

            // Filters Bar
            if showFilters {
                filtersSection
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Results Section
            resultsSection
        }
        .background(themeManager.currentTheme.colors.background)
        .onAppear {
            setupSearchEngine()
        }
        .onReceive(
            searchDebouncer
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        ) { query in
            performSearch(query)
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Main Search Bar
            HStack {
                // Search Icon
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .font(.system(size: 16, weight: .medium))

                // Search TextField
                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .onChange(of: searchText) { _, newValue in
                        searchDebouncer.send(newValue)
                    }
                    .onSubmit {
                        performSearch(searchText)
                    }

                // Loading Indicator
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }

                Spacer()

                // Filter Toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showFilters.toggle()
                    }
                } label: {
                    Image(
                        systemName: showFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                    .foregroundColor(
                        activeFilters.isEmpty
                            ? themeManager.currentTheme.colors.foregroundSecondary
                            : themeManager.currentTheme.colors.accent
                    )
                    .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.plain)

                // Advanced Options
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    Image(systemName: showAdvanced ? "gearshape.fill" : "gearshape")
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.colors.backgroundSecondary)
                    .stroke(
                        searchText.isEmpty
                            ? Color.clear : themeManager.currentTheme.colors.accent.opacity(0.3),
                        lineWidth: 2
                    )
            )

            // Active Filters Pills
            if !activeFilters.isEmpty {
                activeFiltersView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Search Statistics
            if let stats = searchStatistics {
                searchStatsView(stats)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    themeManager.currentTheme.colors.background,
                    themeManager.currentTheme.colors.backgroundSecondary.opacity(0.3),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Active Filters

    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(activeFilters.enumerated()), id: \.offset) { index, filter in
                    filterPill(filter: filter) {
                        _ = withAnimation(.easeInOut(duration: 0.2)) {
                            activeFilters.remove(at: index)
                        }
                        performSearch(searchText)
                    }
                }

                // Clear All Button
                if activeFilters.count > 1 {
                    Button("Clear All") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            activeFilters.removeAll()
                        }
                        performSearch(searchText)
                    }
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.currentTheme.colors.accent, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterPill(filter: SearchFilter, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(filter.displayName)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.colors.foreground)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                .stroke(themeManager.currentTheme.colors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Search Statistics

    private func searchStatsView(_ stats: SearchStatistics) -> some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text("\(stats.resultCount) results")
                    .font(.caption)
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(stats.formattedSearchTime)
                    .font(.caption)
            }

            if stats.filtersApplied > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.caption)
                    Text("\(stats.filtersApplied) filters")
                        .font(.caption)
                }
            }

            Spacer()
        }
        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
        .padding(.horizontal, 20)
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(spacing: 16) {
            // Sort Options
            HStack {
                Text("Sort by:")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                Picker("Sort", selection: $sortOption) {
                    ForEach(SearchSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    sortAscending.toggle()
                    performSearch(searchText)
                } label: {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Filter Categories
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 200))
                ], spacing: 16
            ) {
                tagFilterSection
                dateFilterSection
                propertiesFilterSection
            }

            // Apply Filters Button
            HStack {
                Button("Apply Filters") {
                    applyCurrentFilters()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.colors.accent)
                )

                Button("Reset") {
                    resetFilters()
                }
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.backgroundSecondary)
                .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var tagFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.colors.foreground)

            // Available tags (mock data - replace with actual tags)
            let availableTags = ["project", "meeting", "idea", "todo", "draft"]

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 4) {
                ForEach(availableTags, id: \.self) { tag in
                    Button("#\(tag)") {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(
                        selectedTags.contains(tag)
                            ? .white : themeManager.currentTheme.colors.foreground
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                selectedTags.contains(tag)
                                    ? themeManager.currentTheme.colors.accent
                                    : themeManager.currentTheme.colors.backgroundTertiary
                            )
                    )
                }
            }
        }
    }

    private var dateFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Range")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.colors.foreground)

            VStack(spacing: 8) {
                DatePicker("From", selection: $dateRangeStart, displayedComponents: .date)
                    .datePickerStyle(.compact)

                DatePicker("To", selection: $dateRangeEnd, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
    }

    private var propertiesFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Properties")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.currentTheme.colors.foreground)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Has backlinks", isOn: $showWithBacklinks)
                Toggle("Orphaned notes", isOn: $showOrphaned)

                HStack {
                    Text("Words:")
                    TextField("Min", value: $minWordCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("to")
                    TextField("Max", value: $maxWordCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(searchResults, id: \.id) { result in
                    searchResultRow(result)
                        .onTapGesture {
                            selectSearchResult(result)
                        }
                }
            }
        }
        .background(themeManager.currentTheme.colors.background)
    }

    private func searchResultRow(_ result: EnhancedSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and Relevance
            HStack {
                Text(result.title)
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .lineLimit(1)

                Spacer()

                // Relevance Score
                HStack(spacing: 4) {
                    Circle()
                        .fill(relevanceColor(result.relevanceScore))
                        .frame(width: 8, height: 8)
                    Text(String(format: "%.0f%%", result.relevanceScore * 100))
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }
            }

            // Snippet with highlights
            highlightedSnippet(result.snippet, highlights: result.highlights)
                .font(.body)
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                .lineLimit(3)

            // Metadata
            HStack(spacing: 12) {
                Label("\(result.metadata.wordCount) words", systemImage: "doc.text")
                Label(relativeDateString(result.metadata.modifiedAt), systemImage: "clock")

                if !result.metadata.tags.isEmpty {
                    Label("\(result.metadata.tags.count) tags", systemImage: "tag")
                }

                Spacer()

                // Match type badge
                matchTypeBadge(result.matchType)
            }
            .font(.caption)
            .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
        }
        .padding(16)
        .background(themeManager.currentTheme.colors.backgroundSecondary)
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
    }

    private func highlightedSnippet(_ snippet: String, highlights: [TextRange]) -> some View {
        // Simple implementation - in a real app, you'd properly highlight the text
        Text(snippet)
    }

    private func matchTypeBadge(_ matchType: MatchType) -> some View {
        Text(matchType.rawValue.capitalized)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(matchTypeColor(matchType))
            )
    }

    private func matchTypeColor(_ matchType: MatchType) -> Color {
        switch matchType {
        case .exactMatch: return .green
        case .title: return .blue
        case .content: return .orange
        case .tag: return .purple
        case .fuzzyMatch: return .gray
        }
    }

    private func relevanceColor(_ score: Double) -> Color {
        if score > 0.8 {
            return .green
        } else if score > 0.6 {
            return .yellow
        } else if score > 0.4 {
            return .orange
        } else {
            return .red
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Actions

    private func setupSearchEngine() {
        // In a real implementation, you'd get the actual search index from ferrufiApp
    }

    private func performSearch(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            searchStatistics = nil
            return
        }

        isSearching = true

        Task {
            let results = await searchEngine.search(query)

            await MainActor.run {
                self.searchResults = results
                self.searchStatistics = searchEngine.searchStatistics
                self.isSearching = false
            }
        }
    }

    private func applyCurrentFilters() {
        var filters: [SearchFilter] = []

        // Add tag filters
        for tag in selectedTags {
            filters.append(.tag(tag))
        }

        // Add date range filter
        filters.append(.dateRange(from: dateRangeStart, to: dateRangeEnd))

        // Add property filters
        if showWithBacklinks {
            filters.append(.hasBacklinks)
        }

        if showOrphaned {
            filters.append(.isOrphaned)
        }

        if minWordCount > 0 || maxWordCount < 10000 {
            filters.append(.wordCount(min: minWordCount, max: maxWordCount))
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            activeFilters = filters
        }

        performSearch(searchText)
    }

    private func resetFilters() {
        selectedTags.removeAll()
        dateRangeStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        dateRangeEnd = Date()
        selectedFolder = ""
        minWordCount = 0
        maxWordCount = 10000
        showOrphaned = false
        showWithBacklinks = false

        withAnimation(.easeInOut(duration: 0.3)) {
            activeFilters.removeAll()
        }

        performSearch(searchText)
    }

    private func selectSearchResult(_ result: EnhancedSearchResult) {
        // Navigate to the selected note
        if let note = ferrufiApp.notes.first(where: { $0.id == result.noteId }) {
            navigationModel.selectNote(note, ferrufiApp: ferrufiApp)
        }
    }
}

// MARK: - Preview

struct AdvancedSearchView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedSearchView()
            .environmentObject(FerrufiApp())
            .environmentObject(NavigationModel())
            .environmentObject(ThemeManager())
            .frame(width: 800, height: 600)
    }
}
