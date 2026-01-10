//
//  SidebarView.swift
//  Ferrufi
//
//  Stunning, visually distinctive sidebar with beautiful design
//

import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct SidebarView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var expandedFolders: Set<UUID> = []
    @State private var hoveredItem: String?
    @State private var showingThemeSelector = false
    @State private var searchText = ""
    @State private var showingCreateMenu = false
    @State private var noteCounter = 1
    @State private var showingDirectoryPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Stunning header with gradient
                headerSection

                // Floating search bar
                floatingSearchBar

                // Compact action cards
                actionCardsSection

                // Working directory section
                workingDirectorySection

                // Beautiful file tree explorer
                fileTreeSection
            }
        }
        .frame(minWidth: 280)
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
        .overlay(
            // Subtle border
            Rectangle()
                .frame(width: 0.5)
                .foregroundColor(themeManager.currentTheme.colors.border.opacity(0.3))
                .padding(.vertical, 20),
            alignment: .trailing
        )
        .sheet(isPresented: $showingThemeSelector) {
            ThemeSelector()
                .environmentObject(themeManager)
        }
        .onChange(of: navigationModel.searchText) { _, newValue in
            searchText = newValue
        }

    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeManager.currentTheme.colors.accent)
                    .frame(width: 24, height: 24)

                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Ferrufi")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                Text("An IDE for Mufi-Lang")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
            }
            .contextMenu {
                Button("Test Menu") {
                    print("Context menu works!")
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    showingThemeSelector = true
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .buttonStyle(.plain)

                Button {
                    // Open the settings window directly (Shortcuts tab)
                    SettingsWindow.shared.show(tab: .shortcuts)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Floating Search Bar

    private var floatingSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)

            TextField("Search...", text: $searchText)
                .font(.system(size: 12))
                .foregroundColor(themeManager.currentTheme.colors.foreground)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, newValue in
                    navigationModel.searchText = newValue
                    navigationModel.search(newValue)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    navigationModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5))
                .stroke(themeManager.currentTheme.colors.border.opacity(0.2), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Action Cards Section

    private var actionCardsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                CompactActionCard(
                    icon: "doc.badge.plus",
                    color: Color(red: 0.3, green: 0.6, blue: 1.0)
                ) {
                    createNoteInWorkingDirectory()
                }

                CompactActionCard(
                    icon: "folder.badge.plus",
                    color: Color(red: 0.2, green: 0.8, blue: 0.4)
                ) {
                    navigationModel.showingFolderCreation = true
                }

                CompactActionCard(
                    icon: "folder.badge.gearshape",
                    color: Color(red: 1.0, green: 0.6, blue: 0.2)
                ) {
                    openDirectoryPicker()
                }

            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Working Directory Section

    private var workingDirectorySection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Workspace")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Button {
                    openDirectoryPicker()
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .buttonStyle(.plain)
                .help("Change directory")
            }

            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.currentTheme.colors.accent)
                        .frame(width: 20, height: 20)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(currentDirectoryName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("\(notesInCurrentDirectory) notes")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5))
                    .stroke(themeManager.currentTheme.colors.border.opacity(0.2), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - File Tree Section

    private var fileTreeSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.8, blue: 0.6),
                                        Color(red: 0.1, green: 0.6, blue: 0.4),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                            .shadow(
                                color: Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3),
                                radius: 4,
                                x: 0,
                                y: 2
                            )

                        Image(systemName: "sidebar.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Explorer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                }

                Spacer()

                Button {
                    navigationModel.showingFolderCreation = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Beautiful interactive file tree or search results
            LazyVStack(spacing: 2) {
                if navigationModel.isSearching || !navigationModel.searchResults.isEmpty {
                    // Show search results
                    if navigationModel.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundSecondary)
                        }
                        .padding(.vertical, 8)
                    } else if navigationModel.searchResults.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundTertiary)
                            Text("No results found")
                                .font(.caption)
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundSecondary)
                        }
                        .padding(.vertical, 16)
                    } else {
                        ForEach(navigationModel.searchResults, id: \.id) { result in
                            SearchResultRow(result: result)
                        }
                    }
                } else if ferrufiApp.folderManager.rootFolders.isEmpty {
                    EmptyFoldersView()
                } else {
                    ForEach(Array(ferrufiApp.folderManager.rootFolders.enumerated()), id: \.1.id) {
                        index, folder in
                        let isLast = index == ferrufiApp.folderManager.rootFolders.count - 1
                        EnhancedFileTreeRow(
                            folder: folder,
                            level: 0,
                            isLast: isLast,
                            parentConnections: [],
                            expandedFolders: $expandedFolders,
                            hoveredItem: $hoveredItem
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5),
                                themeManager.currentTheme.colors.backgroundTertiary.opacity(0.3),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3),
                                themeManager.currentTheme.colors.border.opacity(0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .shadow(
                        color: Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Computed Properties

    private var currentDirectoryName: String {
        if let workingDir = navigationModel.currentWorkingDirectory {
            return workingDir.lastPathComponent
        } else if let selectedFolder = navigationModel.selectedFolder {
            return selectedFolder.name
        } else {
            return "All Notes"
        }
    }

    private var notesInCurrentDirectory: Int {
        if let workingDir = navigationModel.currentWorkingDirectory {
            return ferrufiApp.notes.filter { note in
                note.url?.deletingLastPathComponent() == workingDir
            }.count
        } else if let selectedFolder = navigationModel.selectedFolder {
            return ferrufiApp.notes.filter { note in
                ferrufiApp.folderManager.folder(for: note)?.id == selectedFolder.id
            }.count
        }
        return ferrufiApp.notes.count
    }

    private func openDirectoryPicker() {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Select Directory"
            panel.message = "Choose where to create new notes"

            if let currentDir = navigationModel.currentWorkingDirectory {
                panel.directoryURL = currentDir
            }

            panel.begin { result in
                if result == .OK, let url = panel.url {
                    DispatchQueue.main.async {
                        navigationModel.setWorkingDirectory(url)
                    }
                }
            }
        #endif
    }

    private func createNoteInWorkingDirectory() {
        navigationModel.showingNoteCreation = true
    }

}

// MARK: - File Tree View

struct EnhancedFileTreeRow: View {
    let folder: Folder
    let level: Int
    let isLast: Bool
    let parentConnections: [Bool]
    @Binding var expandedFolders: Set<UUID>
    @Binding var hoveredItem: String?

    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    private var isExpanded: Bool {
        expandedFolders.contains(folder.id)
    }

    private var childFolders: [Folder] {
        ferrufiApp.folderManager.childFolders(of: folder.id)
    }

    private var notesInFolder: [Note] {
        ferrufiApp.notes.filter { note in
            ferrufiApp.folderManager.folder(for: note)?.id == folder.id
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var hasChildren: Bool {
        !childFolders.isEmpty || !notesInFolder.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Beautiful enhanced folder row with tree structure
            HStack(spacing: 0) {
                // Elegant tree structure lines
                HStack(spacing: 0) {
                    // Vertical lines from parent levels with subtle glow
                    ForEach(0..<level, id: \.self) { index in
                        ZStack {
                            if parentConnections.count > index && parentConnections[index] {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.6),
                                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3),
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 2)
                                    .padding(.leading, 10)
                                    .shadow(
                                        color: Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3),
                                        radius: 1)
                            }
                            Spacer()
                        }
                        .frame(width: 20)
                    }

                    if level > 0 {
                        ZStack {
                            if !isLast {
                                VStack {
                                    Rectangle()
                                        .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.5))
                                        .frame(width: 2, height: 10)
                                    Spacer()
                                    Rectangle()
                                        .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.5))
                                        .frame(width: 2, height: 10)
                                }
                            } else {
                                VStack {
                                    Rectangle()
                                        .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.5))
                                        .frame(width: 2, height: 10)
                                    Spacer()
                                }
                            }

                            HStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.5))
                                    .frame(width: 10, height: 2)
                                    .padding(.top, -0.5)
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                }

                // Beautiful expand/collapse button with hover effects
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if isExpanded {
                            expandedFolders.remove(folder.id)
                        } else {
                            expandedFolders.insert(folder.id)
                        }
                    }
                } label: {
                    Group {
                        if hasChildren {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.1))
                                    .frame(width: 16, height: 16)

                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                            }
                        } else {
                            Spacer().frame(width: 16)
                        }
                    }
                    .frame(width: 20, height: 28)
                }
                .buttonStyle(.plain)

                // Enhanced folder icon with gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: navigationModel.selectedFolder?.id == folder.id
                                    ? [
                                        themeManager.currentTheme.colors.accent.opacity(0.9),
                                        themeManager.currentTheme.colors.accent,
                                    ]
                                    : [Color.orange.opacity(0.8), Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 20, height: 16)
                        .shadow(
                            color: navigationModel.selectedFolder?.id == folder.id
                                ? themeManager.currentTheme.colors.accent.opacity(0.4)
                                : Color.orange.opacity(0.3),
                            radius: navigationModel.selectedFolder?.id == folder.id ? 3 : 2,
                            x: 0,
                            y: 1
                        )

                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 8)
                .scaleEffect(navigationModel.selectedFolder?.id == folder.id ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 0.15),
                    value: navigationModel.selectedFolder?.id == folder.id)

                // Enhanced folder name
                Text(folder.name)
                    .font(
                        .system(
                            size: 14,
                            weight: navigationModel.selectedFolder?.id == folder.id
                                ? .bold : .semibold,
                            design: .rounded)
                    )
                    .foregroundColor(
                        navigationModel.selectedFolder?.id == folder.id
                            ? themeManager.currentTheme.colors.accent
                            : themeManager.currentTheme.colors.foreground
                    )
                    .lineLimit(1)
                    .shadow(
                        color: navigationModel.selectedFolder?.id == folder.id
                            ? themeManager.currentTheme.colors.accent.opacity(0.3)
                            : Color.clear,
                        radius: 1
                    )
                    .animation(
                        .easeInOut(duration: 0.15),
                        value: navigationModel.selectedFolder?.id == folder.id)

                Spacer()

                // Note count with beautiful badge
                if notesInFolder.count > 0 {
                    Text("\(notesInFolder.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.8, blue: 0.6),
                                            Color(red: 0.1, green: 0.6, blue: 0.4),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3),
                                    radius: 2)
                        )
                }
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        navigationModel.selectedFolder?.id == folder.id
                            ? LinearGradient(
                                colors: [
                                    themeManager.currentTheme.colors.accent.opacity(0.15),
                                    themeManager.currentTheme.colors.accent.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : (hoveredItem == folder.id.uuidString
                                ? LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.colors.backgroundSecondary
                                            .opacity(0.8),
                                        themeManager.currentTheme.colors.backgroundSecondary
                                            .opacity(0.4),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                    )
                    .stroke(
                        navigationModel.selectedFolder?.id == folder.id
                            ? themeManager.currentTheme.colors.accent.opacity(0.3)
                            : Color.clear,
                        lineWidth: 1
                    )
                    .shadow(
                        color: navigationModel.selectedFolder?.id == folder.id
                            ? themeManager.currentTheme.colors.accent.opacity(0.2)
                            : Color.clear,
                        radius: navigationModel.selectedFolder?.id == folder.id ? 4 : 0,
                        x: 0,
                        y: 2
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                navigationModel.selectFolder(folder, ferrufiApp: ferrufiApp)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredItem = hovering ? folder.id.uuidString : nil
                }
            }
            .contextMenu {
                Button {
                    navigationModel.showRenameDialog(for: folder)
                } label: {
                    Label("Rename Folder", systemImage: "pencil")
                }

                Button {
                    navigationModel.showingNoteCreation = true
                    navigationModel.selectFolder(folder, ferrufiApp: ferrufiApp)
                } label: {
                    Label("New Note in Folder", systemImage: "doc.badge.plus")
                }

                Divider()

                Button(role: .destructive) {
                    // TODO: Add folder deletion functionality
                    print("Delete folder: \(folder.name)")
                } label: {
                    Label("Delete Folder", systemImage: "trash")
                }
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    // Notes in this folder
                    ForEach(Array(notesInFolder.enumerated()), id: \.1.id) { index, note in
                        let isLastNote = index == notesInFolder.count - 1 && childFolders.isEmpty
                        EnhancedFileTreeNoteRow(
                            note: note,
                            level: level + 1,
                            isLast: isLastNote,
                            parentConnections: parentConnections + [!isLast],
                            hoveredItem: $hoveredItem
                        )
                    }

                    // Child folders
                    ForEach(Array(childFolders.enumerated()), id: \.1.id) { index, childFolder in
                        let isLastChild = index == childFolders.count - 1
                        EnhancedFileTreeRow(
                            folder: childFolder,
                            level: level + 1,
                            isLast: isLastChild,
                            parentConnections: parentConnections + [!isLast],
                            expandedFolders: $expandedFolders,
                            hoveredItem: $hoveredItem,

                        )
                    }
                }
            }
        }
    }
}

struct EnhancedFileTreeNoteRow: View {
    let note: Note
    let level: Int
    let isLast: Bool
    let parentConnections: [Bool]
    @Binding var hoveredItem: String?

    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    private func iconForNote(_ note: Note) -> String {
        if note.filePath.hasSuffix(".mufi") {
            return "chevron.left.forwardslash.chevron.right"
        } else {
            return "doc.text"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Enhanced tree structure lines
            HStack(spacing: 0) {
                ForEach(0..<level, id: \.self) { index in
                    ZStack {
                        if parentConnections.count > index && parentConnections[index] {
                            Rectangle()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4))
                                .frame(width: 2)
                                .padding(.leading, 10)
                        }
                        Spacer()
                    }
                    .frame(width: 20)
                }

                if level > 0 {
                    ZStack {
                        if !isLast {
                            VStack {
                                Rectangle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4))
                                    .frame(width: 2, height: 8)
                                Spacer()
                                Rectangle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4))
                                    .frame(width: 2, height: 8)
                            }
                        } else {
                            VStack {
                                Rectangle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4))
                                    .frame(width: 2, height: 8)
                                Spacer()
                            }
                        }

                        HStack {
                            Spacer()
                            Rectangle()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.4))
                                .frame(width: 10, height: 2)
                                .padding(.top, -0.5)
                        }
                    }
                    .frame(width: 20, height: 18)
                }
            }

            // Spacer for indent alignment
            Spacer()
                .frame(width: 16)

            // Beautiful note icon
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: navigationModel.selectedNote?.id == note.id
                                ? [
                                    themeManager.currentTheme.colors.accent.opacity(0.9),
                                    themeManager.currentTheme.colors.accent,
                                ]
                                : [
                                    themeManager.currentTheme.colors.foregroundTertiary.opacity(
                                        0.6),
                                    themeManager.currentTheme.colors.foregroundTertiary.opacity(
                                        0.8),
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 18)
                    .shadow(
                        color: navigationModel.selectedNote?.id == note.id
                            ? themeManager.currentTheme.colors.accent.opacity(0.4)
                            : Color.clear,
                        radius: navigationModel.selectedNote?.id == note.id ? 3 : 0,
                        x: 0,
                        y: 1
                    )

                Image(systemName: iconForNote(note))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 8)
            .scaleEffect(navigationModel.selectedNote?.id == note.id ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 0.15), value: navigationModel.selectedNote?.id == note.id)

            // Enhanced note name
            Text(note.title)
                .font(
                    .system(
                        size: 12,
                        weight: navigationModel.selectedNote?.id == note.id ? .semibold : .medium,
                        design: .rounded)
                )
                .foregroundColor(
                    navigationModel.selectedNote?.id == note.id
                        ? themeManager.currentTheme.colors.accent
                        : themeManager.currentTheme.colors.foreground
                )
                .lineLimit(1)
                .animation(
                    .easeInOut(duration: 0.15), value: navigationModel.selectedNote?.id == note.id)

            Spacer()
        }
        .frame(height: 24)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    navigationModel.selectedNote?.id == note.id
                        ? LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent.opacity(0.15),
                                themeManager.currentTheme.colors.accent.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : (hoveredItem == note.id.uuidString
                            ? LinearGradient(
                                colors: [
                                    themeManager.currentTheme.colors.backgroundSecondary.opacity(
                                        0.8),
                                    themeManager.currentTheme.colors.backgroundSecondary.opacity(
                                        0.4),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                )
                .stroke(
                    navigationModel.selectedNote?.id == note.id
                        ? themeManager.currentTheme.colors.accent.opacity(0.3)
                        : Color.clear,
                    lineWidth: navigationModel.selectedNote?.id == note.id ? 1 : 0
                )
                .shadow(
                    color: navigationModel.selectedNote?.id == note.id
                        ? themeManager.currentTheme.colors.accent.opacity(0.2)
                        : Color.clear,
                    radius: navigationModel.selectedNote?.id == note.id ? 4 : 0,
                    x: 0,
                    y: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            navigationModel.selectNote(note, ferrufiApp: ferrufiApp)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredItem = hovering ? note.id.uuidString : nil
            }
        }
        .contextMenu {
            Button {
                navigationModel.showRenameDialog(for: note)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                navigationModel.showMoveDialog(for: note)
            } label: {
                Label("Move to Folder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    do {
                        try await ferrufiApp.deleteNote(note)
                    } catch {
                        navigationModel.showError(error)
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    let result: SearchResult
    @State private var isHovered = false

    private func iconForNote(noteId: UUID) -> String {
        if let note = ferrufiApp.notes.first(where: { $0.id == noteId }) {
            if note.filePath.hasSuffix(".mufi") {
                return "chevron.left.forwardslash.chevron.right"
            }
        }
        return "doc.text"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Note icon with selection highlighting
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: navigationModel.selectedNote?.id == result.noteId
                                ? [
                                    themeManager.currentTheme.colors.accent.opacity(0.9),
                                    themeManager.currentTheme.colors.accent,
                                ]
                                : [
                                    themeManager.currentTheme.colors.foregroundTertiary.opacity(
                                        0.6),
                                    themeManager.currentTheme.colors.foregroundTertiary.opacity(
                                        0.8),
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 18)
                    .shadow(
                        color: navigationModel.selectedNote?.id == result.noteId
                            ? themeManager.currentTheme.colors.accent.opacity(0.4)
                            : Color.clear,
                        radius: navigationModel.selectedNote?.id == result.noteId ? 3 : 0,
                        x: 0,
                        y: 1
                    )

                Image(systemName: iconForNote(noteId: result.noteId))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(navigationModel.selectedNote?.id == result.noteId ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 0.15), value: navigationModel.selectedNote?.id == result.noteId
            )

            VStack(alignment: .leading, spacing: 2) {
                // Note title with selection highlighting
                Text(result.title)
                    .font(
                        .system(
                            size: 12,
                            weight: navigationModel.selectedNote?.id == result.noteId
                                ? .semibold : .medium,
                            design: .rounded
                        )
                    )
                    .foregroundColor(
                        navigationModel.selectedNote?.id == result.noteId
                            ? themeManager.currentTheme.colors.accent
                            : themeManager.currentTheme.colors.foreground
                    )
                    .lineLimit(1)
                    .animation(
                        .easeInOut(duration: 0.15),
                        value: navigationModel.selectedNote?.id == result.noteId)

                // Snippet
                if !result.snippet.isEmpty {
                    Text(result.snippet)
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                        .lineLimit(2)
                }

                // Match type and score
                HStack(spacing: 4) {
                    Text(result.matchType.rawValue.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                        )

                    Spacer()

                    Text("\(Int(result.relevanceScore * 100))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    navigationModel.selectedNote?.id == result.noteId
                        ? LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent.opacity(0.15),
                                themeManager.currentTheme.colors.accent.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : (isHovered
                            ? LinearGradient(
                                colors: [
                                    themeManager.currentTheme.colors.backgroundSecondary.opacity(
                                        0.8),
                                    themeManager.currentTheme.colors.backgroundSecondary.opacity(
                                        0.4),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                )
                .stroke(
                    navigationModel.selectedNote?.id == result.noteId
                        ? themeManager.currentTheme.colors.accent.opacity(0.3)
                        : Color.clear,
                    lineWidth: navigationModel.selectedNote?.id == result.noteId ? 1 : 0
                )
                .shadow(
                    color: navigationModel.selectedNote?.id == result.noteId
                        ? themeManager.currentTheme.colors.accent.opacity(0.2)
                        : Color.clear,
                    radius: navigationModel.selectedNote?.id == result.noteId ? 4 : 0,
                    x: 0,
                    y: 2
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            // Find the note and select it
            if let note = ferrufiApp.notes.first(where: { $0.id == result.noteId }) {
                navigationModel.selectNote(note, ferrufiApp: ferrufiApp)
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
            }

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.colors.backgroundSecondary)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct CompactActionCard: View {
    let icon: String
    let color: Color
    let action: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let action: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Enhanced icon background with glow effect
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(
                            color: gradientColors.first?.opacity(0.4) ?? .clear,
                            radius: isHovered ? 8 : 4,
                            x: 0,
                            y: 2
                        )

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isHovered
                            ? themeManager.currentTheme.colors.backgroundSecondary
                            : themeManager.currentTheme.colors.backgroundTertiary.opacity(0.3)
                    )
                    .stroke(
                        isHovered
                            ? gradientColors.first?.opacity(0.3) ?? Color.clear
                            : themeManager.currentTheme.colors.border.opacity(0.2),
                        lineWidth: 1
                    )
                    .shadow(
                        color: themeManager.currentTheme.colors.shadow.opacity(
                            isHovered ? 0.15 : 0.05),
                        radius: isHovered ? 8 : 3,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

struct BeautifulFolderRow: View {
    let folder: Folder
    let level: Int
    @Binding var expandedFolders: Set<UUID>
    @Binding var hoveredItem: String?

    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    private var isExpanded: Bool {
        expandedFolders.contains(folder.id)
    }

    private var childFolders: [Folder] {
        ferrufiApp.folderManager.childFolders(of: folder.id)
    }

    private var isHovered: Bool {
        hoveredItem == folder.id.uuidString
    }

    private var notesInFolder: [Note] {
        ferrufiApp.notes.filter { note in
            ferrufiApp.folderManager.folder(for: note)?.id == folder.id
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                navigationModel.selectFolder(folder)
            } label: {
                HStack(spacing: 8) {
                    // Indentation
                    if level > 0 {
                        HStack(spacing: 0) {
                            ForEach(0..<level, id: \.self) { _ in
                                Rectangle()
                                    .fill(themeManager.currentTheme.colors.border.opacity(0.2))
                                    .frame(width: 1, height: 16)
                                    .padding(.leading, 16)
                            }
                        }
                    }

                    // Expansion indicator
                    if !childFolders.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isExpanded {
                                    expandedFolders.remove(folder.id)
                                } else {
                                    expandedFolders.insert(folder.id)
                                }
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundTertiary
                                )
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 12)
                    }

                    // Enhanced folder icon with depth
                    ZStack {
                        // Shadow/depth layer
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.1))
                            .frame(width: 26, height: 20)
                            .offset(x: 1, y: 1)

                        // Main folder background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.7, blue: 0.3),
                                        Color(red: 0.9, green: 0.5, blue: 0.1),
                                        Color(red: 0.8, green: 0.4, blue: 0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.black.opacity(0.2),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )

                        Image(systemName: isExpanded ? "folder.fill" : "folder")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                    }

                    Text(folder.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(
                            navigationModel.selectedFolder?.id == folder.id
                                ? themeManager.currentTheme.colors.accent
                                : themeManager.currentTheme.colors.foreground
                        )
                        .lineLimit(1)
                        .shadow(
                            color: themeManager.currentTheme.colors.shadow.opacity(0.1),
                            radius: 0.5,
                            x: 0,
                            y: 0.5
                        )

                    Spacer()

                    // Enhanced note count badge
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.colors.accent)

                        Text("\(notesInFolder.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.colors.backgroundTertiary,
                                        themeManager.currentTheme.colors.backgroundTertiary.opacity(
                                            0.8),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .stroke(
                                themeManager.currentTheme.colors.border.opacity(0.3), lineWidth: 0.5
                            )
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            navigationModel.selectedFolder?.id == folder.id
                                ? LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.colors.accent.opacity(0.15),
                                        themeManager.currentTheme.colors.accent.opacity(0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : (isHovered
                                    ? LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.colors.backgroundSecondary,
                                            themeManager.currentTheme.colors.backgroundSecondary
                                                .opacity(0.7),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.clear, Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                        )
                        .stroke(
                            navigationModel.selectedFolder?.id == folder.id
                                ? themeManager.currentTheme.colors.accent.opacity(0.4)
                                : (isHovered
                                    ? themeManager.currentTheme.colors.border.opacity(0.3)
                                    : Color.clear),
                            lineWidth: 1.5
                        )
                        .shadow(
                            color: navigationModel.selectedFolder?.id == folder.id
                                ? themeManager.currentTheme.colors.accent.opacity(0.2)
                                : themeManager.currentTheme.colors.shadow.opacity(
                                    isHovered ? 0.1 : 0),
                            radius: navigationModel.selectedFolder?.id == folder.id ? 8 : 4,
                            x: 0,
                            y: 2
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredItem = hovering ? folder.id.uuidString : nil
            }

            // Child folders with enhanced animation and visual hierarchy
            if isExpanded && !childFolders.isEmpty {
                VStack(spacing: 6) {
                    ForEach(childFolders, id: \.id) { childFolder in
                        BeautifulFolderRow(
                            folder: childFolder,
                            level: level + 1,
                            expandedFolders: $expandedFolders,
                            hoveredItem: $hoveredItem
                        )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)).combined(
                                    with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .move(edge: .top)).combined(
                                    with: .scale(scale: 0.95))
                            ))
                    }
                }
                .padding(.leading, 20)
                .overlay(
                    Rectangle()
                        .fill(themeManager.currentTheme.colors.border.opacity(0.2))
                        .frame(width: 2)
                        .padding(.leading, 8),
                    alignment: .leading
                )
            }
        }
    }
}

struct BeautifulNoteCard: View {
    let note: Note
    let ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        Button {
            navigationModel.selectNote(note, ferrufiApp: ferrufiApp)
        } label: {
            HStack(spacing: 12) {
                // Note type indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.colors.accent,
                                    themeManager.currentTheme.colors.accentSecondary,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)

                    Image(systemName: "doc.text")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                        .lineLimit(1)

                    Text(note.modifiedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        navigationModel.selectedNote?.id == note.id
                            ? themeManager.currentTheme.colors.accent.opacity(0.1)
                            : (isHovered
                                ? themeManager.currentTheme.colors.backgroundSecondary
                                : Color.clear)
                    )
                    .stroke(
                        navigationModel.selectedNote?.id == note.id
                            ? themeManager.currentTheme.colors.accent.opacity(0.3)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct EmptyFoldersView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)

            Text("No folders yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)

            Text("Create your first folder to organize notes")
                .font(.system(size: 10))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - View Extensions

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(FerrufiApp())
                .environmentObject(NavigationModel())
                .environmentObject(ThemeManager())
        } detail: {
            Text("Detail View")
        }
    }
}
