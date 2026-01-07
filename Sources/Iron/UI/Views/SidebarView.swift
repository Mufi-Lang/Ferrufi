//
//  SidebarView.swift
//  Iron
//
//  Stunning, visually distinctive sidebar with beautiful design
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var ironApp: IronApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var expandedFolders: Set<UUID> = []
    @State private var hoveredItem: String?
    @State private var showingThemeSelector = false
    @State private var searchText = ""
    @State private var showingCreateMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // Stunning header with gradient
            headerSection

            // Floating search bar
            floatingSearchBar

            // Beautiful action cards
            actionCardsSection

            // Elegant folders section
            foldersSection

            // Recent notes with beautiful cards
            recentNotesSection

            Spacer()

            // Bottom status
            statusSection
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
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App branding with beautiful icon
            HStack(spacing: 12) {
                ZStack {
                    // Animated gradient background
                    RoundedRectangle(cornerRadius: 12)
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
                        .frame(width: 40, height: 40)
                        .shadow(
                            color: themeManager.currentTheme.colors.accent.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )

                    Image(systemName: "brain")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Iron")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text("Knowledge System")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Spacer()

                // Theme toggle with beautiful design
                Button {
                    showingThemeSelector = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(themeManager.currentTheme.colors.backgroundSecondary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(themeManager.currentTheme.colors.border, lineWidth: 0.5)
                            )

                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.colors.accent)
                    }
                }
                .buttonStyle(.plain)
                .help("Change Theme")
            }

            // Stats with beautiful cards
            HStack(spacing: 12) {
                StatCard(
                    icon: "doc.text",
                    value: "\(ironApp.notes.count)",
                    label: "Notes",
                    color: themeManager.currentTheme.colors.success
                )

                StatCard(
                    icon: "folder",
                    value: "\(ironApp.folderManager.folders.count)",
                    label: "Folders",
                    color: themeManager.currentTheme.colors.warning
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [
                    themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Floating Search Bar

    private var floatingSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)

            TextField("Search your knowledge...", text: $searchText)
                .font(.system(size: 14))
                .foregroundColor(themeManager.currentTheme.colors.foreground)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, newValue in
                    navigationModel.search(newValue)
                    if !newValue.isEmpty {
                        Task {
                            await navigationModel.performSearch(with: ironApp)
                        }
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    navigationModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.colors.backgroundSecondary)
                .stroke(themeManager.currentTheme.colors.border.opacity(0.3), lineWidth: 0.5)
                .shadow(
                    color: themeManager.currentTheme.colors.shadow.opacity(0.1),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Action Cards Section

    private var actionCardsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()
            }
            .padding(.horizontal, 20)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8
            ) {
                ActionCard(
                    icon: "plus.circle.fill",
                    title: "New Note",
                    subtitle: "Create",
                    gradientColors: [
                        themeManager.currentTheme.colors.accent,
                        themeManager.currentTheme.colors.accentSecondary,
                    ]
                ) {
                    navigationModel.showingNoteCreation = true
                }

                ActionCard(
                    icon: "folder.badge.plus",
                    title: "New Folder",
                    subtitle: "Organize",
                    gradientColors: [
                        themeManager.currentTheme.colors.success,
                        themeManager.currentTheme.colors.success.opacity(0.7),
                    ]
                ) {
                    navigationModel.showingFolderCreation = true
                }

                ActionCard(
                    icon: "square.and.arrow.down",
                    title: "Import",
                    subtitle: "Files",
                    gradientColors: [
                        themeManager.currentTheme.colors.warning,
                        themeManager.currentTheme.colors.warning.opacity(0.7),
                    ]
                ) {
                    // TODO: Import functionality
                }

                ActionCard(
                    icon: "circle.hexagongrid",
                    title: "Graph",
                    subtitle: "View",
                    gradientColors: [
                        themeManager.currentTheme.colors.error,
                        themeManager.currentTheme.colors.error.opacity(0.7),
                    ]
                ) {
                    navigationModel.showGraph()
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Folders")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                Button {
                    navigationModel.showingFolderCreation = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if ironApp.folderManager.rootFolders.isEmpty {
                        EmptyFoldersView()
                    } else {
                        ForEach(ironApp.folderManager.rootFolders, id: \.id) { folder in
                            BeautifulFolderRow(
                                folder: folder,
                                level: 0,
                                expandedFolders: $expandedFolders,
                                hoveredItem: $hoveredItem
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Recent Notes Section

    private var recentNotesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Notes")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(recentNotes.prefix(5), id: \.id) { note in
                        BeautifulNoteCard(note: note)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(themeManager.currentTheme.colors.border.opacity(0.3))

            HStack {
                Circle()
                    .fill(themeManager.currentTheme.colors.success)
                    .frame(width: 6, height: 6)

                Text("Connected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)

                Spacer()

                Text(themeManager.currentTheme.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.accent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Computed Properties

    private var recentNotes: [Note] {
        ironApp.notes
            .sorted { $0.modifiedAt > $1.modifiedAt }
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

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let action: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.currentTheme.colors.backgroundSecondary)
                    .stroke(themeManager.currentTheme.colors.border.opacity(0.3), lineWidth: 0.5)
                    .shadow(
                        color: themeManager.currentTheme.colors.shadow.opacity(0.05),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
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

    @EnvironmentObject var ironApp: IronApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    private var isExpanded: Bool {
        expandedFolders.contains(folder.id)
    }

    private var childFolders: [Folder] {
        ironApp.folderManager.childFolders(of: folder.id)
    }

    private var isHovered: Bool {
        hoveredItem == folder.id.uuidString
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

                    // Folder icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.colors.warning,
                                        themeManager.currentTheme.colors.warning.opacity(0.7),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 16)

                        Image(systemName: isExpanded ? "folder.fill" : "folder")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text(folder.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(
                            navigationModel.selectedFolder?.id == folder.id
                                ? themeManager.currentTheme.colors.accent
                                : themeManager.currentTheme.colors.foreground
                        )
                        .lineLimit(1)

                    Spacer()

                    // Note count badge
                    Text("0")  // TODO: Implement note counting
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(themeManager.currentTheme.colors.backgroundTertiary)
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            navigationModel.selectedFolder?.id == folder.id
                                ? themeManager.currentTheme.colors.accent.opacity(0.1)
                                : (isHovered
                                    ? themeManager.currentTheme.colors.backgroundSecondary
                                    : Color.clear)
                        )
                        .stroke(
                            navigationModel.selectedFolder?.id == folder.id
                                ? themeManager.currentTheme.colors.accent.opacity(0.3)
                                : Color.clear,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                hoveredItem = hovering ? folder.id.uuidString : nil
            }

            // Child folders with beautiful animation
            if isExpanded && !childFolders.isEmpty {
                ForEach(childFolders, id: \.id) { childFolder in
                    BeautifulFolderRow(
                        folder: childFolder,
                        level: level + 1,
                        expandedFolders: $expandedFolders,
                        hoveredItem: $hoveredItem
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
            }
        }
    }
}

struct BeautifulNoteCard: View {
    let note: Note
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        Button {
            navigationModel.selectNote(note)
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
                .environmentObject(IronApp())
                .environmentObject(NavigationModel())
                .environmentObject(ThemeManager())
        } detail: {
            Text("Detail View")
        }
    }
}
