//
//  NoteListView.swift
//  Iron
//
//  Note list view for displaying and managing notes
//

import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var ironApp: IronApp
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var sortOrder: SortOrder = .modifiedDate
    @State private var sortDirection: SortDirection = .descending
    @State private var selectedNotes: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            Group {
                if navigationModel.isSearching {
                    searchResultsView
                } else if filteredNotes.isEmpty {
                    emptyStateView
                } else {
                    switch navigationModel.viewMode {
                    case .list:
                        listView
                    case .grid:
                        gridView
                    }
                }
            }
        }
        .frame(minWidth: 250)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section("Sort by") {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Label(order.displayName, systemImage: order.systemImage)
                                    .tag(order)
                            }
                        }
                    }

                    Section("Direction") {
                        Picker("Direction", selection: $sortDirection) {
                            ForEach(SortDirection.allCases, id: \.self) { direction in
                                Label(direction.displayName, systemImage: direction.systemImage)
                                    .tag(direction)
                            }
                        }
                    }

                    Divider()

                    Button("Select All", systemImage: "checkmark.circle") {
                        selectedNotes = Set(filteredNotes.map(\.id))
                    }

                    Button("Select None", systemImage: "circle") {
                        selectedNotes.removeAll()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    navigationModel.toggleViewMode()
                } label: {
                    Image(systemName: navigationModel.viewMode.systemImage)
                }
            }
        }
        .navigationTitle(navigationModel.currentTitle)
        .searchable(text: $navigationModel.searchText, prompt: "Search notes...")
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(headerTitle)
                    .font(.headline)

                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !selectedNotes.isEmpty {
                Button("Delete Selected") {
                    deleteSelectedNotes()
                }
                .foregroundColor(.red)
            }

            Button {
                navigationModel.showingNoteCreation = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(sortedNotes, id: \.id) { note in
                Button(action: {
                    navigationModel.selectNote(note)
                }) {
                    NoteListRowView(note: note)
                }
                .buttonStyle(.plain)
                .background(
                    navigationModel.selectedNote?.id == note.id
                        ? Color.accentColor.opacity(0.1)
                        : Color.clear
                )
                .contextMenu {
                    noteContextMenu(for: note)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(sortedNotes, id: \.id) { note in
                    NoteGridItemView(note: note)
                        .onTapGesture {
                            navigationModel.selectNote(note)
                        }
                        .contextMenu {
                            noteContextMenu(for: note)
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        List {
            ForEach(navigationModel.searchResults, id: \.id) { result in
                SearchResultRowView(result: result)
                    .onTapGesture {
                        if let note = ironApp.loadNote(id: result.noteId) {
                            navigationModel.selectNote(note)
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Notes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first note to get started")
                .foregroundColor(.secondary)

            Button("Create Note") {
                navigationModel.showingNoteCreation = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Context Menu

    private func noteContextMenu(for note: Note) -> some View {
        Group {
            Button("Open") {
                navigationModel.selectNote(note)
            }

            Divider()

            Button("Duplicate") {
                duplicateNote(note)
            }

            Button("Share") {
                shareNote(note)
            }

            Divider()

            Button("Delete") {
                deleteNote(note)
            }
            .foregroundColor(.red)
        }
    }

    // MARK: - Computed Properties

    private var headerTitle: String {
        if navigationModel.isSearching {
            return "Search Results"
        } else if let folder = navigationModel.selectedFolder {
            return folder.name
        } else {
            return "All Notes"
        }
    }

    private var headerSubtitle: String {
        let count = filteredNotes.count
        return "\(count) \(count == 1 ? "note" : "notes")"
    }

    private var filteredNotes: [Note] {
        let notes = ironApp.notes

        // Filter by selected folder
        if navigationModel.selectedFolder != nil {
            // TODO: Implement folder-based filtering
            // For now, return all notes
        }

        return notes
    }

    private var sortedNotes: [Note] {
        let notes = filteredNotes

        switch sortOrder {
        case .title:
            return notes.sorted {
                sortDirection == .ascending ? $0.title < $1.title : $0.title > $1.title
            }
        case .modifiedDate:
            return notes.sorted {
                sortDirection == .ascending
                    ? $0.modifiedAt < $1.modifiedAt : $0.modifiedAt > $1.modifiedAt
            }
        case .createdDate:
            return notes.sorted {
                sortDirection == .ascending
                    ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt
            }
        case .wordCount:
            return notes.sorted {
                sortDirection == .ascending
                    ? $0.wordCount < $1.wordCount : $0.wordCount > $1.wordCount
            }
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
        ]
    }

    // MARK: - Actions

    private func deleteNote(_ note: Note) {
        Task {
            do {
                try await ironApp.deleteNote(id: note.id)
            } catch {
                navigationModel.showError(error)
            }
        }
    }

    private func deleteSelectedNotes() {
        // Remove this functionality for now since we're not using multi-selection
    }

    private func duplicateNote(_ note: Note) {
        Task {
            do {
                _ = try await ironApp.createNote(
                    title: "\(note.title) Copy",
                    content: note.content
                )
            } catch {
                navigationModel.showError(error)
            }
        }
    }

    private func shareNote(_ note: Note) {
        // TODO: Implement note sharing
    }
}

// MARK: - Note List Row View

struct NoteListRowView: View {
    let note: Note

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(contentPreview)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(note.tags.prefix(3)), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2), in: Capsule())
                                }
                            }
                        }
                    }

                    Spacer()

                    Text(note.modifiedAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
            }

            Spacer()

            VStack {
                Text("\(note.wordCount)")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("words")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var contentPreview: String {
        let content = note.content
            .replacingOccurrences(of: #"\[([^\]]+)\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return content.isEmpty ? "No content" : content
    }
}

// MARK: - Note Grid Item View

struct NoteGridItemView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(contentPreview)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack {
                if !note.tags.isEmpty {
                    Text("#\(note.tags.first!)")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2), in: Capsule())

                    if note.tags.count > 1 {
                        Text("+\(note.tags.count - 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("\(note.wordCount)w")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.7))
            }

            Text(note.modifiedAt, style: .relative)
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.7))
        }
        .padding()
        .frame(height: 150)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var contentPreview: String {
        let content = note.content
            .replacingOccurrences(of: #"\[([^\]]+)\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return content.isEmpty ? "No content" : content
    }
}

// MARK: - Search Result Row View

struct SearchResultRowView: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.title)
                    .font(.headline)

                Spacer()

                Text(result.matchType.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2), in: Capsule())
            }

            Text(result.snippet)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack {
                Text("Relevance: \(Int(result.relevanceScore * 100))%")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.7))

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Types

enum SortOrder: CaseIterable, Sendable {
    case title
    case modifiedDate
    case createdDate
    case wordCount

    var displayName: String {
        switch self {
        case .title: return "Title"
        case .modifiedDate: return "Modified"
        case .createdDate: return "Created"
        case .wordCount: return "Length"
        }
    }

    var systemImage: String {
        switch self {
        case .title: return "textformat"
        case .modifiedDate: return "clock"
        case .createdDate: return "calendar"
        case .wordCount: return "text.word.spacing"
        }
    }
}

enum SortDirection: CaseIterable, Sendable {
    case ascending
    case descending

    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }

    var systemImage: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

struct NoteListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(IronApp())
                .environmentObject(NavigationModel())
        } content: {
            NoteListView()
                .environmentObject(IronApp())
                .environmentObject(NavigationModel())
        } detail: {
            Text("Detail")
        }
    }
}
