//
//  NavigationModel.swift
//  Iron
//
//  Navigation state management for the Iron knowledge management application
//

import Combine
import Foundation
import SwiftUI

/// Manages navigation state and user interface flow
@MainActor
public class NavigationModel: ObservableObject {

    // MARK: - Published Properties

    /// Currently selected note
    @Published public var selectedNote: Note?

    /// Currently selected folder
    @Published public var selectedFolder: Folder?

    /// Search query text
    @Published public var searchText: String = ""

    /// Search results
    @Published public var searchResults: [SearchResult] = []

    /// Whether the search is active
    @Published public var isSearching: Bool = false

    /// Current view mode
    @Published public var viewMode: ViewMode = .list

    /// Whether the sidebar is visible
    @Published public var sidebarVisible: Bool = true

    /// Whether the preview pane is visible
    @Published public var previewVisible: Bool = true

    /// Current error to display
    @Published public var currentError: Error?

    /// Whether to show error alert
    @Published public var showingError: Bool = false

    /// Whether to show note creation sheet
    @Published public var showingNoteCreation: Bool = false

    /// Title for new note creation
    @Published public var newNoteTitle: String = ""

    /// Whether to show folder creation sheet
    @Published public var showingFolderCreation: Bool = false

    /// Whether to show settings
    @Published public var showingSettings: Bool = false

    /// Whether to show graph view
    @Published public var showingGraph: Bool = false

    /// Current navigation path for detail view
    @Published public var navigationPath = NavigationPath()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var searchDebouncer: Timer?

    // MARK: - Initialization

    public init() {
        setupBindings()
    }

    // MARK: - Public Methods

    /// Selects a note and navigates to it
    public func selectNote(_ note: Note) {
        selectedNote = note

        // Clear search when selecting a note
        if isSearching {
            clearSearch()
        }
    }

    /// Selects a folder
    public func selectFolder(_ folder: Folder) {
        selectedFolder = folder
        selectedNote = nil
    }

    /// Starts a search with debouncing
    public func search(_ query: String) {
        searchText = query

        // Cancel previous search
        searchDebouncer?.invalidate()

        if query.isEmpty {
            clearSearch()
            return
        }

        // Debounce search by 300ms
        searchDebouncer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                await self?.performSearchInternal()
            }
        }
    }

    /// Clears the current search
    public func clearSearch() {
        searchText = ""
        searchResults = []
        isSearching = false
        searchDebouncer?.invalidate()
    }

    /// Shows error with the given error object
    public func showError(_ error: Error) {
        currentError = error
        showingError = true
    }

    /// Creates a new note
    public func createNote(title: String, content: String = "", ironApp: IronApp) {
        showingNoteCreation = false

        Task {
            do {
                let newNote = try await ironApp.createNote(title: title, content: content)
                await MainActor.run {
                    self.selectNote(newNote)
                }
            } catch {
                await MainActor.run {
                    self.showError(error)
                }
            }
        }
    }

    /// Creates a new folder
    public func createFolder(name: String, parent: Folder? = nil, ironApp: IronApp) {
        showingFolderCreation = false

        Task {
            do {
                // Determine the file system path
                let parentPath: String
                if let parent = parent {
                    parentPath = parent.path
                } else {
                    parentPath = ironApp.folderManager.rootFolder.path
                }

                let folderPath = URL(fileURLWithPath: parentPath)
                    .appendingPathComponent(name)
                    .path

                // Check if folder already exists
                if FileManager.default.fileExists(atPath: folderPath) {
                    throw FolderError.folderAlreadyExists
                }

                // Create the directory on the file system
                try FileManager.default.createDirectory(
                    atPath: folderPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                await MainActor.run {
                    // Create the folder in the manager
                    let newFolder = ironApp.folderManager.createFolder(
                        name: name,
                        path: folderPath,
                        parentId: parent?.id
                    )

                    // Select the newly created folder
                    self.selectFolder(newFolder)
                }
            } catch {
                await MainActor.run {
                    self.showError(error)
                }
            }
        }
    }

    /// Toggles the view mode
    public func toggleViewMode() {
        viewMode = viewMode == .list ? .grid : .list
    }

    /// Toggles sidebar visibility
    public func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarVisible.toggle()
        }
    }

    /// Toggles preview pane visibility
    public func togglePreview() {
        withAnimation(.easeInOut(duration: 0.2)) {
            previewVisible.toggle()
        }
    }

    /// Shows the graph view
    public func showGraph() {
        showingGraph = true
    }

    /// Navigates to a specific view
    public func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }

    /// Goes back in navigation
    public func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Auto-clear error after showing
        $showingError
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.currentError = nil
            }
            .store(in: &cancellables)
    }

    private func performSearchInternal() async {
        guard !searchText.isEmpty else { return }

        isSearching = true

        // This will be implemented when we integrate with IronApp
        // For now, just set empty results
        searchResults = []
    }

    /// Performs search using IronApp
    public func performSearch(with ironApp: IronApp) async {
        guard !searchText.isEmpty else {
            clearSearch()
            return
        }

        isSearching = true

        let results = await ironApp.search(searchText)
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
        }
    }
}

// MARK: - Supporting Types

/// View modes for note display
public enum ViewMode: String, CaseIterable, Sendable {
    case list = "list"
    case grid = "grid"

    public var displayName: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        }
    }

    public var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

/// Navigation destinations
public enum NavigationDestination: Hashable, Sendable {
    case note(UUID)
    case folder(UUID)
    case search(String)
    case settings
    case graph
    case newNote
    case newFolder

    public var title: String {
        switch self {
        case .note: return "Note"
        case .folder: return "Folder"
        case .search: return "Search"
        case .settings: return "Settings"
        case .graph: return "Graph"
        case .newNote: return "New Note"
        case .newFolder: return "New Folder"
        }
    }
}

// MARK: - Extensions

extension NavigationModel {
    /// Gets the current navigation title
    public var currentTitle: String {
        if let note = selectedNote {
            return note.title
        } else if let folder = selectedFolder {
            return folder.name
        } else if isSearching {
            return "Search: \(searchText)"
        } else {
            return "Iron"
        }
    }

    /// Whether there's a current selection
    public var hasSelection: Bool {
        return selectedNote != nil || selectedFolder != nil
    }

    /// Whether navigation can go back
    public var canNavigateBack: Bool {
        return !navigationPath.isEmpty
    }
}
