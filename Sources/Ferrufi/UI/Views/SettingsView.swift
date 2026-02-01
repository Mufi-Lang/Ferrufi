//
//  SettingsView.swift
//  Ferrufi
//
//  A beautiful, modern settings view for configuring the Ferrufi application.
//  Uses a sidebar-based navigation for a polished, IDE-like feel.
//

import AppKit
import SwiftUI

public enum SettingsTab: String, CaseIterable {
    case general = "general"
    case editor = "editor"
    case search = "search"
    case shortcuts = "shortcuts"
    case about = "about"
}

public struct SettingsView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @StateObject private var settings = Settings.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab: SettingsTab = .general

    public init() {}

    public init(initialTab: SettingsTab? = nil) {
        self._selectedTab = State(initialValue: initialTab ?? .general)
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Sidebar Navigation
            settingsSidebar
            
            Divider()
                .frame(width: 1)
                .background(themeManager.currentTheme.colors.border.opacity(0.5))

            // Content Area
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(selectedTab.displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                    
                    Spacer()
                    
                    Button(action: { settings.resetToDefaults() }) {
                        Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(themeManager.currentTheme.colors.backgroundSecondary)
                    .cornerRadius(6)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch selectedTab {
                        case .general:
                            GeneralSettingsContent()
                        case .editor:
                            EditorSettingsContent()
                        case .search:
                            SearchSettingsContent()
                        case .shortcuts:
                            ShortcutsSettingsView()
                                .environmentObject(ferrufiApp)
                        case .about:
                            AboutSettingsContent()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.currentTheme.colors.background)
        }
        .frame(minWidth: 850, minHeight: 600)
        .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : .light)
        .environmentObject(settings)
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 32)
                .padding(.bottom, 12)

            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarItem(
                    title: tab.displayName,
                    icon: tab.iconName,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
            
            Spacer()
            
            // Footer Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Ferrufi v\(Version.current)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                Text("Mufi IDE Engine 1.0")
                    .font(.system(size: 9))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary.opacity(0.7))
            }
            .padding(20)
        }
        .frame(width: 200)
        .background(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.5))
    }
}

// MARK: - Sidebar Item

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(themeManager.currentTheme.colors.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? themeManager.currentTheme.colors.accent.opacity(0.1) : Color.clear)
                    .padding(.horizontal, 8)
            )
            .foregroundColor(isSelected ? themeManager.currentTheme.colors.accent : themeManager.currentTheme.colors.foregroundSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pretty Section Components

struct SettingsThemePickerRow: View {
    let title: String
    @Binding var selection: Theme
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foreground)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String?
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .padding(.leading, 4)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.currentTheme.colors.border.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    @EnvironmentObject var themeManager: ThemeManager

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foreground)
                .frame(width: 120, alignment: .leading)
            
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
            
            Text("\(Int(value))\(unit)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.colors.accent)
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SettingsPickerRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let labelProvider: (T) -> String
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme.colors.foreground)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(labelProvider(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Content Views

struct GeneralSettingsContent: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingStartupNotePicker = false

    var body: some View {
        VStack(spacing: 24) {
            SettingsSection(title: "Application") {
                SettingsToggleRow("Launch at Login", subtitle: "Automatically start Ferrufi when you log in", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                Divider().padding(.leading, 16)
                SettingsToggleRow("Confirm Before Quit", subtitle: "Ask for confirmation before closing the app", isOn: Binding(
                    get: { settings.confirmBeforeQuit },
                    set: { settings.confirmBeforeQuit = $0 }
                ))
                Divider().padding(.leading, 16)
                SettingsToggleRow("Automatic Updates", subtitle: "Keep Ferrufi up to date with new features", isOn: Binding(
                    get: { settings.autoUpdateEnabled },
                    set: { settings.autoUpdateEnabled = $0 }
                ))
            }

            SettingsSection(title: "Startup") {
                SettingsPickerRow(title: "At Launch", selection: $settings.startupBehavior, options: StartupBehavior.allCases, labelProvider: { $0.displayName })
                
                if settings.startupBehavior == .specific {
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Startup Note")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Button(action: { showingStartupNotePicker = true }) {
                            if let id = settings.startupNoteId, let note = ferrufiApp.notes.first(where: { $0.id == id }) {
                                Text(note.title)
                            } else {
                                Text("Choose Note...")
                            }
                        }
                        .controlSize(.small)
                    }
                    .padding(16)
                }
            }

            SettingsSection(title: "Workspace") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workspace Location")
                            .font(.system(size: 13, weight: .medium))
                        Text(ferrufiApp.configuration.workspace.defaultWorkspacePath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Change...") {
                        openWorkspacePicker()
                    }
                    .controlSize(.small)
                }
                .padding(16)
                
                Divider().padding(.leading, 16)
                
                SettingsSliderRow(title: "Auto-save", value: $settings.autoSaveInterval, range: 5...300, step: 5, unit: "s")
                
                Divider().padding(.leading, 16)
                
                SettingsToggleRow("Watch for External Changes", isOn: $settings.fileWatchingEnabled)
            }
            
            SettingsSection(title: "Appearance") {
                SettingsThemePickerRow(title: "Color Theme", selection: $settings.currentTheme)
                
                Divider().padding(.leading, 16)
                
                SettingsToggleRow("Enable Animations", isOn: $settings.animationsEnabled)
            }

            SettingsSection(title: "Performance") {
                SettingsToggleRow("Metal Acceleration", subtitle: "Use GPU for faster text rendering", isOn: $settings.metalAccelerationEnabled)
            }
        }
        .sheet(isPresented: $showingStartupNotePicker) {
            NotePickerView(onNoteSelected: { note in
                settings.startupNoteId = note.id
                showingStartupNotePicker = false
            })
            .environmentObject(ferrufiApp)
            .environmentObject(themeManager)
        }
    }

    private func openWorkspacePicker() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let rawWorkspacePath = ferrufiApp.currentWorkspacePath ?? ferrufiApp.configuration.workspace.defaultWorkspacePath
        let defaultDir = URL(fileURLWithPath: (rawWorkspacePath as NSString).expandingTildeInPath)

        SecurityScopedBookmarkManager.shared.requestFolderAccess(
            message: "Select a folder to contain your Ferrufi workspace",
            defaultDirectory: defaultDir,
            showHidden: true
        ) { selectedURL in
            guard let parentURL = selectedURL else { return }
            Task {
                do {
                    // If the user picked Home, create ~/.ferrufi inside it
                    let ferrufiDir: URL
                    if parentURL.path == homeURL.path {
                        ferrufiDir = parentURL.appendingPathComponent(".ferrufi")
                    } else {
                        ferrufiDir = parentURL
                    }

                    try FileManager.default.createDirectory(at: ferrufiDir, withIntermediateDirectories: true, attributes: nil)
                    try await ferrufiApp.initialize(workspacePath: ferrufiDir.path)

                    await MainActor.run {
                        // Persist trust
                        let canonicalParent = URL(fileURLWithPath: (parentURL.path as NSString).expandingTildeInPath).standardizedFileURL.path
                        ferrufiApp.configuration.updateConfiguration { config in
                            var arr = config.trustedWorkspacePaths ?? []
                            if !arr.contains(canonicalParent) {
                                arr.append(canonicalParent)
                                config.trustedWorkspacePaths = arr
                            }
                        }

                        // Refresh explorer
                        FerrufiApp.sharedNavigationModel?.selectFolder(ferrufiApp.folderManager.rootFolder, ferrufiApp: ferrufiApp)
                    }
                } catch {
                    print("Failed to change workspace: \(error)")
                }
            }
        }
    }
}

struct EditorSettingsContent: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 24) {
            SettingsSection(title: "Typography") {
                SettingsSliderRow(title: "Font Size", value: $settings.fontSize, range: 10...32, step: 1, unit: "pt")
                Divider().padding(.leading, 16)
                SettingsSliderRow(title: "Line Height", value: $settings.lineHeight, range: 1.0...2.5, step: 0.1, unit: "x")
                Divider().padding(.leading, 16)
                SettingsPickerRow(title: "Font Family", selection: $settings.fontFamily, options: ["SF Mono", "Menlo", "Monaco", "Courier"], labelProvider: { $0 })
            }

            SettingsSection(title: "Interface") {
                SettingsToggleRow("Show Line Numbers", isOn: $settings.showLineNumbers)
                Divider().padding(.leading, 16)
                SettingsToggleRow("Word Wrap", isOn: $settings.wordWrap)
            }
            
            SettingsSection(title: "Mufi Scripting") {
                SettingsToggleRow("Syntax Highlighting", isOn: Binding(
                    get: { settings.config.editor.syntaxHighlighting },
                    set: { val in settings.update { $0.editor.syntaxHighlighting = val } }
                ))
                Divider().padding(.leading, 16)
                SettingsToggleRow("Auto-complete", isOn: Binding(
                    get: { settings.config.editor.autoComplete },
                    set: { val in settings.update { $0.editor.autoComplete = val } }
                ))
            }
        }
    }
}

struct SearchSettingsContent: View {
    @EnvironmentObject var settings: Settings

    var body: some View {
        VStack(spacing: 24) {
            SettingsSection(title: "Search Engine") {
                SettingsToggleRow("Indexing Enabled", subtitle: "Faster search across all notes", isOn: $settings.indexingEnabled)
                Divider().padding(.leading, 16)
                SettingsSliderRow(title: "Fuzzy Threshold", value: $settings.fuzzySearchThreshold, range: 0.1...1.0, step: 0.1, unit: "")
            }
            
            SettingsSection(title: "Scope") {
                SettingsToggleRow("Search in Content", isOn: $settings.searchInContent)
                Divider().padding(.leading, 16)
                SettingsToggleRow("Search in Titles", isOn: $settings.searchInTitles)
            }

            SettingsSection(title: "Advanced") {
                SettingsToggleRow("Case Sensitive", isOn: $settings.caseSensitive)
            }
        }
    }
}

struct AboutSettingsContent: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
                
                VStack(spacing: 4) {
                    Text("Ferrufi")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Native Mufi-Lang IDE")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }
            }
            
            SettingsSection {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Version.current)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                
                Divider().padding(.leading, 16)
                
                HStack {
                    Text("Build Number")
                    Spacer()
                    Text("2026.01.31")
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            
            Text("© 2026 Mufi-Lang Team. All rights reserved.")
                .font(.system(size: 11))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
        }
        .padding(.top, 20)
    }
}

// MARK: - Tab Extension

extension SettingsTab {
    var displayName: String {
        self.rawValue.capitalized
    }
    
    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .editor: return "pencil.and.outline"
        case .search: return "magnifyingglass"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(FerrufiApp())
            .environmentObject(ThemeManager())
    }
}