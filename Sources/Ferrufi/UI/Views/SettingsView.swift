//
//  SettingsView.swift
//  Ferrufi
//
//  Settings view for configuring the Ferrufi application
//

import AppKit
import SwiftUI

// Compact layout constants used across the settings UI
private let settingsLabelWidth: CGFloat = 140
private let settingsCompactPadding: CGFloat = 10

// A small helper that ensures consistent label alignment for rows in the settings UI.
// Usage:
// SettingsRow("Label:") {
//     // controls go here (TextField, Toggle, Button, etc.)
// }
private struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .frame(width: settingsLabelWidth, alignment: .leading)
            Spacer()
            content
        }
        .padding(.vertical, settingsCompactPadding / 2)
    }
}

public struct SettingsView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab: SettingsTab

    public init() {
        self._selectedTab = State(initialValue: .general)
    }

    init(initialTab: SettingsTab? = nil) {
        self._selectedTab = State(initialValue: initialTab ?? .general)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .environmentObject(ferrufiApp)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            EditorSettingsView()
                .environmentObject(ferrufiApp)
                .tabItem {
                    Label("Editor", systemImage: "pencil")
                }
                .tag(SettingsTab.editor)

            // Graph settings removed (feature deprecated)
            // Appearance tab removed per product direction — theme-related controls remain available via theme selector UI

            ShortcutsSettingsView()
                .environmentObject(ferrufiApp)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(SettingsTab.shortcuts)

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 740, minHeight: 520)
        // Use a slightly more compact control size by default for settings
        .environment(\.controlSize, .small)
        .themedAccent(themeManager)
        .themedBackground(themeManager)
        .themedForeground(themeManager)
        .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : .light)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingStartupNotePicker: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var lastBackupAt: Date? = nil
    @State private var isBackingUpNow: Bool = false

    // Vault management states
    @State private var showVaultInfoAlert: Bool = false
    @State private var vaultInfoMessage: String = ""

    public init() {}

    var body: some View {
        VStack(alignment: .leading) {
            // Header with reset action (styled consistently with Shortcuts tab)
            HStack {
                Text("General")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("Reset to Defaults") {
                    // Reset configuration and ensure services reflect defaults
                    ferrufiApp.configuration.resetToDefaults()

                    if ferrufiApp.configuration.general.autoUpdateEnabled {
                        UpdateManager.shared.startAutoCheck()
                    } else {
                        UpdateManager.shared.stopAutoCheck()
                    }

                    Task { @MainActor in
                        do {
                            try await LaunchAtLoginManager.shared.setEnabled(
                                ferrufiApp.configuration.general.launchAtLogin)
                        } catch {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
                .help("Reset all preferences to their defaults")
                .controlSize(.small)
            }
            .padding(.bottom, 6)

            // Debug banner to confirm General tab is visible
            Text("DEBUG: General tab is visible")
                .font(.caption)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.12))
                .foregroundColor(.red)
                .cornerRadius(6)

            GroupBox(label: Label("Vault", systemImage: "folder")) {
                VStack(alignment: .leading, spacing: 8) {
                    // Compute commonly used paths
                    let homeURL = FileManager.default.homeDirectoryForCurrentUser
                    let vaultPath = homeURL.appendingPathComponent(".ferrufi/scripts")
                    let bookmarkedParent = SecurityScopedBookmarkManager.shared
                        .allBookmarkedPaths()
                        .first { vaultPath.path.hasPrefix($0) }

                    HStack(alignment: .center) {
                        Text("Vault location:")
                            .frame(width: settingsLabelWidth, alignment: .leading)
                        Spacer()
                        Text(bookmarkedParent ?? "No folder selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button("Change Vault Folder") {
                            SecurityScopedBookmarkManager.shared.requestFolderAccess(
                                message:
                                    "Select a folder to contain your Ferrufi vault (select Home to use ~/.ferrufi/)",
                                defaultDirectory: homeURL,
                                showHidden: true
                            ) { url, created in
                                // Ensure the user actually granted permission and a bookmark was created
                                guard let selectedURL = url, created else {
                                    errorMessage = "Folder not selected or permission not granted."
                                    showErrorAlert = true
                                    return
                                }

                                Task {
                                    do {
                                        // The withAccess call returns nil if access could not be started.
                                        let accessed =
                                            try await SecurityScopedBookmarkManager.shared
                                            .withAccess(
                                                toPath: selectedURL.path
                                            ) { parentURL in
                                                let ferrufiDir: URL
                                                if parentURL.path == homeURL.path {
                                                    ferrufiDir = parentURL.appendingPathComponent(
                                                        ".ferrufi")
                                                } else {
                                                    ferrufiDir = parentURL
                                                }
                                                let scriptsDir = ferrufiDir.appendingPathComponent(
                                                    "scripts")

                                                try FileManager.default.createDirectory(
                                                    at: ferrufiDir,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil
                                                )
                                                try FileManager.default.createDirectory(
                                                    at: scriptsDir,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil
                                                )

                                                // Reinitialize Ferrufi storage to point at the new vault
                                                try await ferrufiApp.initialize(
                                                    vaultPath: scriptsDir.path)
                                            }

                                        if accessed == nil {
                                            errorMessage =
                                                "Failed to access the selected folder. Permission may not have been granted."
                                            showErrorAlert = true
                                        } else {
                                            vaultInfoMessage = "Vault folder updated."
                                            showVaultInfoAlert = true
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                                }
                            }
                        }
                        .controlSize(.small)

                        Button("Repair Permission") {
                            SecurityScopedBookmarkManager.shared.requestFolderAccess(
                                message: "Select the folder again to repair permissions",
                                defaultDirectory: homeURL,
                                showHidden: true
                            ) { url, created in
                                // Ensure user selected and we successfully created a bookmark
                                if let selectedURL = url, created {
                                    // Verify we can actually resolve and start access for the bookmark
                                    if SecurityScopedBookmarkManager.shared.resolveBookmark(
                                        forPath: selectedURL.path) != nil
                                    {
                                        vaultInfoMessage = "Permission repaired."
                                        showVaultInfoAlert = true
                                    } else {
                                        errorMessage =
                                            "Failed to repair permission (couldn't access folder)."
                                        showErrorAlert = true
                                    }
                                } else {
                                    errorMessage = "Repair cancelled or permission not granted."
                                    showErrorAlert = true
                                }
                            }
                        }
                        .controlSize(.small)

                        Button("Revoke Permission") {
                            let vaultPath = homeURL.appendingPathComponent(".ferrufi/scripts")
                            if let parent = SecurityScopedBookmarkManager.shared
                                .allBookmarkedPaths()
                                .first(where: { vaultPath.path.hasPrefix($0) })
                            {
                                SecurityScopedBookmarkManager.shared.removeBookmark(forPath: parent)
                                vaultInfoMessage =
                                    "Permission revoked. App will prompt again on next initialization."
                                showVaultInfoAlert = true
                            } else {
                                errorMessage = "No vault permission found to revoke."
                                showErrorAlert = true
                            }
                        }
                        .controlSize(.small)

                        Button("Open in Finder") {
                            let target = homeURL.appendingPathComponent(".ferrufi/scripts")
                            NSWorkspace.shared.open(target)
                        }
                        .controlSize(.small)
                    }  // HStack
                }  // VStack
            }  // GroupBox
            .padding(.vertical, 8)
            .alert("Vault", isPresented: $showVaultInfoAlert) {
                Button("OK") {}
            } message: {
                Text(vaultInfoMessage)
            }

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    GroupBox(label: Label("Application", systemImage: "gearshape")) {
                        VStack(spacing: 12) {
                            Toggle(
                                "Launch at login",
                                isOn: Binding(
                                    get: { ferrufiApp.configuration.general.launchAtLogin },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.general.launchAtLogin = newValue
                                        }
                                        // Perform the main-actor operation asynchronously and handle failures by reverting
                                        Task { @MainActor in
                                            do {
                                                try await LaunchAtLoginManager.shared.setEnabled(
                                                    newValue)
                                            } catch {
                                                ferrufiApp.configuration.updateConfiguration {
                                                    config in
                                                    config.general.launchAtLogin = !newValue
                                                }
                                                errorMessage = error.localizedDescription
                                                showErrorAlert = true
                                            }
                                        }
                                    }
                                )
                            )
                            .controlSize(.small)

                            Toggle(
                                "Confirm before quit",
                                isOn: Binding(
                                    get: { ferrufiApp.configuration.general.confirmBeforeQuit },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.general.confirmBeforeQuit = newValue
                                        }
                                    }
                                )
                            )
                            .controlSize(.small)

                            HStack(alignment: .center) {
                                Text("Startup behavior:")
                                    .frame(width: settingsLabelWidth, alignment: .leading)

                                Picker(
                                    "",
                                    selection: Binding(
                                        get: { ferrufiApp.configuration.general.startupBehavior },
                                        set: { newValue in
                                            ferrufiApp.configuration.updateConfiguration { config in
                                                config.general.startupBehavior = newValue
                                            }
                                        }
                                    )
                                ) {
                                    ForEach(StartupBehavior.allCases, id: \.self) { behavior in
                                        Text(behavior.displayName).tag(behavior)
                                    }
                                }
                                .pickerStyle(.menu)

                                if ferrufiApp.configuration.general.startupBehavior == .specific {
                                    Spacer()
                                    HStack(spacing: 8) {
                                        if let id = ferrufiApp.configuration.general.startupNoteId,
                                            let note = ferrufiApp.notes.first(where: { $0.id == id }
                                            )
                                        {
                                            Text(note.title)
                                                .foregroundColor(.secondary)
                                                .truncationMode(.tail)
                                        } else {
                                            Text("No note selected")
                                                .foregroundColor(.secondary)
                                        }

                                        Button("Choose…") {
                                            showingStartupNotePicker = true
                                        }
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }

                    GroupBox(label: Label("Updates", systemImage: "arrow.triangle.2.circlepath")) {
                        VStack(spacing: 10) {
                            Toggle(
                                "Check for updates automatically",
                                isOn: Binding(
                                    get: { ferrufiApp.configuration.general.autoUpdateEnabled },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.general.autoUpdateEnabled = newValue
                                        }
                                        if newValue {
                                            UpdateManager.shared.startAutoCheck()
                                        } else {
                                            UpdateManager.shared.stopAutoCheck()
                                        }
                                    }
                                )
                            )
                            .controlSize(.small)

                            HStack {
                                Spacer()
                                Button("Check now") {
                                    UpdateManager.shared.checkForUpdatesAndNotify()
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(8)
                    }

                    GroupBox(label: Label("Vault", systemImage: "folder")) {
                        VStack(spacing: 12) {
                            SettingsRow("Vault Location:") {
                                HStack(spacing: 8) {
                                    Text(ferrufiApp.configuration.vault.defaultVaultPath)
                                        .foregroundColor(.secondary)
                                        .truncationMode(.middle)
                                    Button("Change") {
                                        // TODO: Implement vault location picker
                                    }
                                }
                            }

                            Toggle(
                                "Watch for external changes",
                                isOn: Binding(
                                    get: { ferrufiApp.configuration.vault.fileWatchingEnabled },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.vault.fileWatchingEnabled = newValue
                                        }
                                    }
                                )
                            )
                            .controlSize(.small)

                            SettingsRow("Auto-save interval:") {
                                HStack {
                                    TextField(
                                        "Seconds",
                                        value: Binding(
                                            get: {
                                                ferrufiApp.configuration.vault.autoSaveInterval
                                            },
                                            set: { newValue in
                                                ferrufiApp.configuration.updateConfiguration {
                                                    config in
                                                    config.vault.autoSaveInterval = newValue
                                                }
                                            }
                                        ), format: .number
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .controlSize(.small)
                                    Text("seconds").foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(8)
                    }

                    GroupBox(label: Label("Backup", systemImage: "archivebox")) {
                        VStack(spacing: 12) {
                            Toggle(
                                "Enable backups",
                                isOn: Binding(
                                    get: { ferrufiApp.configuration.vault.backupEnabled },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.vault.backupEnabled = newValue
                                        }
                                    }
                                )
                            )
                            .controlSize(.small)
                            .controlSize(.small)

                            if ferrufiApp.configuration.vault.backupEnabled {
                                SettingsRow("Backup interval:") {
                                    HStack {
                                        TextField(
                                            "Hours",
                                            value: Binding(
                                                get: {
                                                    ferrufiApp.configuration.vault.backupInterval
                                                        / 3600
                                                },
                                                set: { newValue in
                                                    ferrufiApp.configuration.updateConfiguration {
                                                        config in
                                                        config.vault.backupInterval =
                                                            newValue * 3600
                                                    }
                                                }
                                            ), format: .number
                                        )
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .controlSize(.small)
                                        Text("hours").foregroundColor(.secondary)
                                    }
                                }

                                SettingsRow("Keep backups:") {
                                    HStack {
                                        TextField(
                                            "Count",
                                            value: Binding(
                                                get: { ferrufiApp.configuration.vault.maxBackups },
                                                set: { newValue in
                                                    ferrufiApp.configuration.updateConfiguration {
                                                        config in
                                                        config.vault.maxBackups = newValue
                                                    }
                                                }
                                            ), format: .number
                                        )
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .controlSize(.small)
                                        Text("files").foregroundColor(.secondary)
                                    }
                                }

                                SettingsRow("Last backup:") {
                                    if let last = lastBackupAt {
                                        Text(
                                            DateFormatter.localizedString(
                                                from: last, dateStyle: .medium, timeStyle: .short)
                                        )
                                        .foregroundColor(.secondary)
                                    } else {
                                        Text("Never").foregroundColor(.secondary)
                                    }
                                }

                                SettingsRow("") {
                                    Button(action: {
                                        isBackingUpNow = true
                                        Task { @MainActor in
                                            await BackupManager.shared.performPeriodicBackup()
                                            if let recs = try? BackupManager.shared.listBackups(
                                                forNoteId: nil), let rec = recs.first
                                            {
                                                lastBackupAt = rec.createdAt
                                            } else {
                                                lastBackupAt = nil
                                            }
                                            isBackingUpNow = false
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            if isBackingUpNow {
                                                ProgressView()
                                                    .scaleEffect(0.75, anchor: .center)
                                            }
                                            Text(isBackingUpNow ? "Running..." : "Run backup now")
                                        }
                                    }
                                    .controlSize(.small)
                                }
                                .task {
                                    Task { @MainActor in
                                        if let recs = try? BackupManager.shared.listBackups(
                                            forNoteId: nil), let rec = recs.first
                                        {
                                            lastBackupAt = rec.createdAt
                                        } else {
                                            lastBackupAt = nil
                                        }
                                    }
                                }
                            }

                            // Explanatory footnote to inform the user about backups and how the interval works
                            Text(
                                "Backups are stored under `~/.ferrufi/backups` and tracked in `Ferrufi.db`. The interval above is specified in hours; the manager will back up notes that have changed since their last backup. 'Keep backups' limits how many backups are retained per note."
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                    }

                    GroupBox(label: Label("Performance", systemImage: "speedometer")) {
                        VStack(spacing: 12) {
                            Toggle(
                                "Enable Metal acceleration",
                                isOn: Binding(
                                    get: { ferrufiApp.configuration.ui.metalAccelerationEnabled },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.ui.metalAccelerationEnabled = newValue
                                        }
                                    }
                                )
                            )
                            .controlSize(.small)
                            .help("Use Metal graphics acceleration for better performance")

                            Toggle(
                                "Enable animations",
                                isOn: Binding(
                                    get: { ferrufiApp.configuration.ui.animationsEnabled },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.ui.animationsEnabled = newValue
                                        }
                                    }
                                )
                            )
                            .controlSize(.small)
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
            .scrollIndicators(.visible)
        }
        .sheet(isPresented: $showingStartupNotePicker) {
            NotePickerView(onNoteSelected: { note in
                ferrufiApp.configuration.updateConfiguration { config in
                    config.general.startupNoteId = note.id
                }
                showingStartupNotePicker = false
            })
            .environmentObject(ferrufiApp)
            .environmentObject(themeManager)
        }
        .alert("Reset all settings?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                // Perform the global reset when the user confirms
                ferrufiApp.configuration.resetToDefaults()

                // Apply auto-update preference immediately
                if ferrufiApp.configuration.general.autoUpdateEnabled {
                    UpdateManager.shared.startAutoCheck()
                } else {
                    UpdateManager.shared.stopAutoCheck()
                }

                // Apply launch-at-login state; handle errors gracefully
                Task { @MainActor in
                    do {
                        try await LaunchAtLoginManager.shared.setEnabled(
                            ferrufiApp.configuration.general.launchAtLogin)
                    } catch {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all preferences to their default values and cannot be undone.")
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"), message: Text(errorMessage),
                dismissButton: .default(Text("OK")))
        }
    }
}

// MARK: - Editor Settings

struct EditorSettingsView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp

    var body: some View {
        VStack {
            Text(
                "DEBUG: Editor settings view is visible. Line numbers: \(ferrufiApp.configuration.editor.showLineNumbers ? "On" : "Off")"
            )
            .font(.caption)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.12))
            .foregroundColor(.green)
            .cornerRadius(6)

            ScrollView(.vertical) {
                Form {
                    Section("Text Editing") {
                        HStack(spacing: 12) {
                            Text("Font size:")
                                .frame(width: settingsLabelWidth, alignment: .leading)

                            Slider(
                                value: Binding(
                                    get: { ferrufiApp.configuration.editor.fontSize },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.editor.fontSize = newValue
                                        }
                                    }
                                ),
                                in: 10...24,
                                step: 1
                            )
                            .frame(width: 150)

                            Text("\(Int(ferrufiApp.configuration.editor.fontSize))pt")
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                        .padding(.vertical, settingsCompactPadding)

                        HStack(spacing: 12) {
                            Text("Font family:")
                                .frame(width: settingsLabelWidth, alignment: .leading)

                            Picker(
                                "Font",
                                selection: Binding(
                                    get: { ferrufiApp.configuration.editor.fontFamily },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.editor.fontFamily = newValue
                                        }
                                    }
                                )
                            ) {
                                Text("SF Mono").tag("SF Mono")
                                Text("Menlo").tag("Menlo")
                                Text("Monaco").tag("Monaco")
                                Text("Courier New").tag("Courier New")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }
                        .padding(.vertical, settingsCompactPadding)

                        HStack(spacing: 12) {
                            Text("Line height:")
                                .frame(width: settingsLabelWidth, alignment: .leading)

                            Slider(
                                value: Binding(
                                    get: { ferrufiApp.configuration.editor.lineHeight },
                                    set: { newValue in
                                        ferrufiApp.configuration.updateConfiguration { config in
                                            config.editor.lineHeight = newValue
                                        }
                                    }
                                ),
                                in: 1...2.5,
                                step: 0.1
                            )
                            .frame(width: 150)

                            Text(String(format: "%.1f", ferrufiApp.configuration.editor.lineHeight))
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                        .padding(.vertical, settingsCompactPadding)
                    }

                    Section("Features") {
                        Toggle(
                            "Word wrap",
                            isOn: Binding(
                                get: { ferrufiApp.configuration.editor.wordWrap },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.editor.wordWrap = newValue
                                    }
                                }
                            )
                        )

                        Toggle(
                            "Show line numbers",
                            isOn: Binding(
                                get: { ferrufiApp.configuration.editor.showLineNumbers },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.editor.showLineNumbers = newValue
                                    }
                                }
                            )
                        )

                        Toggle(
                            "Syntax highlighting",
                            isOn: Binding(
                                get: { ferrufiApp.configuration.editor.syntaxHighlighting },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.editor.syntaxHighlighting = newValue
                                    }
                                }
                            )
                        )

                        Toggle(
                            "Auto-complete",
                            isOn: Binding(
                                get: { ferrufiApp.configuration.editor.autoComplete },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.editor.autoComplete = newValue
                                    }
                                }
                            )
                        )

                        Toggle(
                            "Live preview",
                            isOn: Binding(
                                get: { ferrufiApp.configuration.editor.livePreview },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.editor.livePreview = newValue
                                    }
                                }
                            )
                        )

                        Toggle(
                            "Spell check",
                            isOn: Binding(
                                get: { ferrufiApp.configuration.editor.spellCheck },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.editor.spellCheck = newValue
                                    }
                                }
                            )
                        )
                    }
                }
                .padding(settingsCompactPadding)
            }
            .scrollIndicators(.visible)
        }
    }
}

// MARK: - Search Settings

struct SearchSettingsView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp

    var body: some View {
        ScrollView(.vertical) {
            Form {
                Section("Search Behavior") {
                    Toggle(
                        "Enable search indexing",
                        isOn: Binding(
                            get: { ferrufiApp.configuration.search.indexingEnabled },
                            set: { newValue in
                                ferrufiApp.configuration.updateConfiguration { config in
                                    config.search.indexingEnabled = newValue
                                }
                            }
                        )
                    )
                    .help("Enables fast search across all notes")

                    HStack {
                        Text("Fuzzy search threshold:")
                            .frame(width: 160, alignment: .leading)
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { ferrufiApp.configuration.search.fuzzySearchThreshold },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.search.fuzzySearchThreshold = newValue
                                    }
                                }
                            ),
                            in: 0.1...1.0,
                            step: 0.1
                        )
                        .frame(width: 150)
                        Text(
                            String(
                                format: "%.1f", ferrufiApp.configuration.search.fuzzySearchThreshold
                            )
                        )
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                    }
                    .help("Lower values allow more fuzzy matching")

                    HStack {
                        Text("Max search results:")
                            .frame(width: 160, alignment: .leading)
                        Spacer()
                        TextField(
                            "Results",
                            value: Binding(
                                get: { ferrufiApp.configuration.search.maxSearchResults },
                                set: { newValue in
                                    ferrufiApp.configuration.updateConfiguration { config in
                                        config.search.maxSearchResults = newValue
                                    }
                                }
                            ), format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    }
                }

                Section("Search Scope") {
                    Toggle(
                        "Search in content",
                        isOn: Binding(
                            get: { ferrufiApp.configuration.search.searchInContent },
                            set: { newValue in
                                ferrufiApp.configuration.updateConfiguration { config in
                                    config.search.searchInContent = newValue
                                }
                            }
                        ))

                    Toggle(
                        "Search in titles",
                        isOn: Binding(
                            get: { ferrufiApp.configuration.search.searchInTitles },
                            set: { newValue in
                                ferrufiApp.configuration.updateConfiguration { config in
                                    config.search.searchInTitles = newValue
                                }
                            }
                        ))

                    Toggle(
                        "Search in tags",
                        isOn: Binding(
                            get: { ferrufiApp.configuration.search.searchInTags },
                            set: { newValue in
                                ferrufiApp.configuration.updateConfiguration { config in
                                    config.search.searchInTags = newValue
                                }
                            }
                        ))
                }

                Section("Advanced") {
                    Toggle(
                        "Case sensitive",
                        isOn: Binding(
                            get: { ferrufiApp.configuration.search.caseSensitive },
                            set: { newValue in
                                ferrufiApp.configuration.updateConfiguration { config in
                                    config.search.caseSensitive = newValue
                                }
                            }
                        ))

                    Toggle(
                        "Whole words only",
                        isOn: Binding(
                            get: { ferrufiApp.configuration.search.wholeWordOnly },
                            set: { newValue in
                                ferrufiApp.configuration.updateConfiguration { config in
                                    config.search.wholeWordOnly = newValue
                                }
                            }
                        ))

                    Button("Rebuild Search Index") {
                        Task {
                            try await ferrufiApp.rebuildSearchIndex()
                        }
                    }
                    .help("Recreates the search index from scratch")
                }

            }
            .padding(settingsCompactPadding)
        }
        .scrollIndicators(.visible)
    }
}

// Appearance settings removed from the Preferences window per product direction.
// Theme and appearance are adjustable via the theme selector elsewhere in the UI.

// MARK: - Graph Settings

// Graph settings removed - feature deprecated. If graph functionality is reintroduced in the future, add a dedicated settings UI back with a focused, minimal configuration set.

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 12) {
                Image(systemName: "brain")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)

                Text("Ferrufi")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Knowledge Management System")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Version 1.0.0")
                    .font(.body)
                    .foregroundColor(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Built with:")
                        .font(.headline)

                    Text("• SwiftUI for native macOS experience")
                    Text("• Metal for hardware-accelerated graphics")
                    Text("• Swift 6.2 with modern concurrency")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 12)

                HStack(spacing: 12) {
                    Button("GitHub") {
                        // TODO: Open GitHub repository
                    }

                    Button("Documentation") {
                        // TODO: Open documentation
                    }
                }
            }
            .padding(settingsCompactPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }
}

// MARK: - Supporting Types

enum SettingsTab: String, CaseIterable {
    case general = "general"
    case editor = "editor"
    case search = "search"
    case shortcuts = "shortcuts"
    case about = "about"
}

struct SettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        SettingsView()
            .environmentObject(FerrufiApp())
    }
}
