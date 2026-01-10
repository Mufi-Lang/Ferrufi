//
//  BeautifulNoteSelector.swift
//  Ferrufi
//
//  Beautiful card-based note selection interface with visual previews
//

import SwiftUI

public struct BeautifulNoteSelector: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedSortOption: SortOption = .modified
    @State private var viewMode: NoteSelectorViewMode = .cards
    @State private var selectedCategories: Set<String> = []
    @State private var hoveredNoteId: UUID?

    private let cardColumns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 16)
    ]

    private let compactColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 12)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerSection

            Divider()
                .background(themeManager.currentTheme.colors.border.opacity(0.3))

            // Main content
            if filteredNotes.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: viewMode == .cards ? cardColumns : compactColumns,
                        spacing: viewMode == .cards ? 20 : 12
                    ) {
                        ForEach(filteredNotes, id: \.id) { note in
                            if viewMode == .cards {
                                NoteSelectorCard(
                                    note: note,
                                    isHovered: hoveredNoteId == note.id,
                                    onTap: { navigationModel.selectNote(note, ferrufiApp: ferrufiApp) }
                                )
                                .environmentObject(themeManager)
                                .onHover { isHovering in
                                    hoveredNoteId = isHovering ? note.id : nil
                                }
                            } else {
                                NoteSelectorCompactCard(
                                    note: note,
                                    isHovered: hoveredNoteId == note.id,
                                    onTap: { navigationModel.selectNote(note, ferrufiApp: ferrufiApp) }
                                )
                                .environmentObject(themeManager)
                                .onHover { isHovering in
                                    hoveredNoteId = isHovering ? note.id : nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
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

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // View controls
            HStack(spacing: 16) {
                // View mode toggle
                HStack(spacing: 4) {
                    ForEach(NoteSelectorViewMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewMode = mode
                            }
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(
                                    viewMode == mode
                                        ? themeManager.currentTheme.colors.accent
                                        : themeManager.currentTheme.colors.foregroundSecondary
                                )
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            viewMode == mode
                                                ? themeManager.currentTheme.colors.accent.opacity(
                                                    0.15)
                                                : Color.clear
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(mode.displayName)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5))
                        .stroke(themeManager.currentTheme.colors.border.opacity(0.2), lineWidth: 1)
                )

                Spacer()
            }

            // Sort and filter options
            HStack {
                // Sort picker
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)

                    Picker("Sort", selection: $selectedSortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5))
                        .stroke(themeManager.currentTheme.colors.border.opacity(0.2), lineWidth: 1)
                )

                Spacer()

                // Notes count
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.accent)

                    Text("\(filteredNotes.count) \(filteredNotes.count == 1 ? "note" : "notes")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(
                    systemName: navigationModel.searchText.isEmpty
                        ? "doc.text.magnifyingglass" : "magnifyingglass"
                )
                .font(.system(size: 32, weight: .light))
                .foregroundColor(themeManager.currentTheme.colors.accent.opacity(0.7))
            }

            VStack(spacing: 8) {
                Text(navigationModel.searchText.isEmpty ? "No Notes Yet" : "No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                Text(
                    navigationModel.searchText.isEmpty
                        ? "Create your first note to get started"
                        : "Try adjusting your search terms"
                )
                .font(.body)
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                .multilineTextAlignment(.center)
            }

            if navigationModel.searchText.isEmpty {
                Button {
                    navigationModel.showingNoteCreation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Create First Note")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent,
                                themeManager.currentTheme.colors.accentSecondary,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: themeManager.currentTheme.colors.accent.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Computed Properties

    private var filteredNotes: [Note] {
        var notes = ferrufiApp.notes

        // Filter by search text
        if !navigationModel.searchText.isEmpty {
            notes = notes.filter { note in
                note.title.localizedCaseInsensitiveContains(navigationModel.searchText)
                    || note.content.localizedCaseInsensitiveContains(navigationModel.searchText)
                    || note.tags.contains {
                        $0.localizedCaseInsensitiveContains(navigationModel.searchText)
                    }
            }
        }

        // Sort notes
        switch selectedSortOption {
        case .title:
            notes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .modified:
            notes.sort { $0.modifiedAt > $1.modifiedAt }
        case .created:
            notes.sort { $0.createdAt > $1.createdAt }
        case .size:
            notes.sort { $0.wordCount > $1.wordCount }
        }

        return notes
    }
}

// MARK: - Beautiful Note Card

struct NoteSelectorCard: View {
    let note: Note
    let isHovered: Bool
    let onTap: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with title and date
                VStack(alignment: .leading, spacing: 8) {
                    Text(note.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(note.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }

                // Content preview
                Text(contentPreview)
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                // Footer with tags and stats
                VStack(alignment: .leading, spacing: 12) {
                    // Tags
                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(note.tags.prefix(3)), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(themeManager.currentTheme.colors.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    themeManager.currentTheme.colors.accent.opacity(
                                                        0.15))
                                        )
                                }

                                if note.tags.count > 3 {
                                    Text("+\(note.tags.count - 3)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(
                                            themeManager.currentTheme.colors.foregroundTertiary
                                        )
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    themeManager.currentTheme.colors
                                                        .backgroundSecondary)
                                        )
                                }
                            }
                        }
                    }

                    // Stats
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "text.word.spacing")
                                .font(.system(size: 10, weight: .medium))
                            Text("\(note.wordCount)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .medium))
                            Text("\(estimatedReadingTime) min read")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                    }
                }
            }
            .padding(20)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        themeManager.currentTheme.colors.backgroundSecondary.opacity(
                            isHovered ? 0.8 : 0.5)
                    )
                    .stroke(
                        themeManager.currentTheme.colors.border.opacity(isHovered ? 0.6 : 0.3),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .shadow(
                color: themeManager.currentTheme.colors.shadow.opacity(isHovered ? 0.15 : 0.05),
                radius: isHovered ? 12 : 6,
                x: 0,
                y: isHovered ? 6 : 3
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                onTap()
            }
        }
    }

    private var contentPreview: String {
        let content = note.content
            .replacingOccurrences(of: #"#+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return content.isEmpty ? "No content" : content
    }

    private var estimatedReadingTime: Int {
        max(1, note.wordCount / 200)  // Average reading speed
    }
}

// MARK: - Compact Note Card

struct NoteSelectorCompactCard: View {
    let note: Note
    let isHovered: Bool
    let onTap: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(contentPreview)
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                HStack {
                    if let firstTag = note.tags.first {
                        Text("#\(firstTag)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.colors.accent.opacity(0.15))
                            )
                    }

                    Spacer()

                    Text(note.modifiedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
            }
            .padding(12)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        themeManager.currentTheme.colors.backgroundSecondary.opacity(
                            isHovered ? 0.7 : 0.4)
                    )
                    .stroke(
                        themeManager.currentTheme.colors.border.opacity(isHovered ? 0.5 : 0.2),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }

    private var contentPreview: String {
        let content = note.content
            .replacingOccurrences(of: #"#+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return content.isEmpty ? "No content" : content
    }
}

// MARK: - Supporting Types

enum NoteSelectorViewMode: String, CaseIterable {
    case cards = "cards"
    case compact = "compact"

    var displayName: String {
        switch self {
        case .cards: return "Cards"
        case .compact: return "Compact"
        }
    }

    var icon: String {
        switch self {
        case .cards: return "rectangle.grid.2x2"
        case .compact: return "rectangle.grid.3x2"
        }
    }
}

enum SortOption: String, CaseIterable {
    case title = "title"
    case modified = "modified"
    case created = "created"
    case size = "size"

    var displayName: String {
        switch self {
        case .title: return "Title"
        case .modified: return "Modified"
        case .created: return "Created"
        case .size: return "Size"
        }
    }
}

// MARK: - Preview

struct BeautifulNoteSelector_Previews: PreviewProvider {
    static var previews: some View {
        BeautifulNoteSelector()
            .environmentObject(FerrufiApp())
            .environmentObject(NavigationModel())
            .environmentObject(ThemeManager())
            .frame(width: 800, height: 600)
    }
}
