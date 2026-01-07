//
//  SettingsView.swift
//  Iron
//
//  Settings view for configuring the Iron application
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var ironApp: IronApp
    @State private var selectedTab: SettingsTab = .general

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .environmentObject(ironApp)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            EditorSettingsView()
                .environmentObject(ironApp)
                .tabItem {
                    Label("Editor", systemImage: "pencil")
                }
                .tag(SettingsTab.editor)

            SearchSettingsView()
                .environmentObject(ironApp)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(SettingsTab.search)

            AppearanceSettingsView()
                .environmentObject(ironApp)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(SettingsTab.appearance)

            GraphSettingsView()
                .environmentObject(ironApp)
                .tabItem {
                    Label("Graph", systemImage: "circle.hexagongrid")
                }
                .tag(SettingsTab.graph)

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var ironApp: IronApp

    var body: some View {
        Form {
            Section("Vault") {
                HStack {
                    Text("Vault Location:")
                    Spacer()
                    Text(ironApp.configuration.vault.defaultVaultPath)
                        .foregroundColor(.secondary)
                        .truncationMode(.middle)
                    Button("Change") {
                        // TODO: Implement vault location picker
                    }
                }

                Toggle(
                    "Watch for external changes",
                    isOn: Binding(
                        get: { ironApp.configuration.vault.fileWatchingEnabled },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.vault.fileWatchingEnabled = newValue
                            }
                        }
                    ))

                HStack {
                    Text("Auto-save interval:")
                    Spacer()
                    TextField(
                        "Seconds",
                        value: Binding(
                            get: { ironApp.configuration.vault.autoSaveInterval },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.vault.autoSaveInterval = newValue
                                }
                            }
                        ), format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
            }

            Section("Backup") {
                Toggle(
                    "Enable backups",
                    isOn: Binding(
                        get: { ironApp.configuration.vault.backupEnabled },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.vault.backupEnabled = newValue
                            }
                        }
                    ))

                if ironApp.configuration.vault.backupEnabled {
                    HStack {
                        Text("Backup interval:")
                        Spacer()
                        TextField(
                            "Hours",
                            value: Binding(
                                get: { ironApp.configuration.vault.backupInterval / 3600 },
                                set: { newValue in
                                    ironApp.configuration.updateConfiguration { config in
                                        config.vault.backupInterval = newValue * 3600
                                    }
                                }
                            ), format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        Text("hours")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Keep backups:")
                        Spacer()
                        TextField(
                            "Count",
                            value: Binding(
                                get: { ironApp.configuration.vault.maxBackups },
                                set: { newValue in
                                    ironApp.configuration.updateConfiguration { config in
                                        config.vault.maxBackups = newValue
                                    }
                                }
                            ), format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        Text("files")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Performance") {
                Toggle(
                    "Enable Metal acceleration",
                    isOn: Binding(
                        get: { ironApp.configuration.ui.metalAccelerationEnabled },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.ui.metalAccelerationEnabled = newValue
                            }
                        }
                    )
                )
                .help("Use Metal graphics acceleration for better performance")

                Toggle(
                    "Enable animations",
                    isOn: Binding(
                        get: { ironApp.configuration.ui.animationsEnabled },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.ui.animationsEnabled = newValue
                            }
                        }
                    ))
            }
        }
        .padding()
    }
}

// MARK: - Editor Settings

struct EditorSettingsView: View {
    @EnvironmentObject var ironApp: IronApp

    var body: some View {
        Form {
            Section("Text Editing") {
                HStack {
                    Text("Font size:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.editor.fontSize },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.editor.fontSize = newValue
                                }
                            }
                        ),
                        in: 10...24,
                        step: 1
                    )
                    .frame(width: 150)
                    Text("\(Int(ironApp.configuration.editor.fontSize))pt")
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Font family:")
                    Spacer()
                    Picker(
                        "Font",
                        selection: Binding(
                            get: { ironApp.configuration.editor.fontFamily },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
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
                    .frame(width: 120)
                }

                HStack {
                    Text("Line height:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.editor.lineHeight },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.editor.lineHeight = newValue
                                }
                            }
                        ),
                        in: 1.0...2.0,
                        step: 0.1
                    )
                    .frame(width: 150)
                    Text(String(format: "%.1f", ironApp.configuration.editor.lineHeight))
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Tab size:")
                    Spacer()
                    TextField(
                        "Tab size",
                        value: Binding(
                            get: { ironApp.configuration.editor.tabSize },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.editor.tabSize = newValue
                                }
                            }
                        ), format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    Text("spaces")
                        .foregroundColor(.secondary)
                }
            }

            Section("Features") {
                Toggle(
                    "Word wrap",
                    isOn: Binding(
                        get: { ironApp.configuration.editor.wordWrap },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.editor.wordWrap = newValue
                            }
                        }
                    ))

                Toggle(
                    "Show line numbers",
                    isOn: Binding(
                        get: { ironApp.configuration.editor.showLineNumbers },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.editor.showLineNumbers = newValue
                            }
                        }
                    ))

                Toggle(
                    "Syntax highlighting",
                    isOn: Binding(
                        get: { ironApp.configuration.editor.syntaxHighlighting },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.editor.syntaxHighlighting = newValue
                            }
                        }
                    ))

                Toggle(
                    "Auto-complete",
                    isOn: Binding(
                        get: { ironApp.configuration.editor.autoComplete },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.editor.autoComplete = newValue
                            }
                        }
                    ))

                Toggle(
                    "Live preview",
                    isOn: Binding(
                        get: { ironApp.configuration.editor.livePreview },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.editor.livePreview = newValue
                            }
                        }
                    ))

                Toggle(
                    "Spell check",
                    isOn: Binding(
                        get: { ironApp.configuration.editor.spellCheck },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.editor.spellCheck = newValue
                            }
                        }
                    ))
            }
        }
        .padding()
    }
}

// MARK: - Search Settings

struct SearchSettingsView: View {
    @EnvironmentObject var ironApp: IronApp

    var body: some View {
        Form {
            Section("Search Behavior") {
                Toggle(
                    "Enable search indexing",
                    isOn: Binding(
                        get: { ironApp.configuration.search.indexingEnabled },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.search.indexingEnabled = newValue
                            }
                        }
                    )
                )
                .help("Enables fast search across all notes")

                HStack {
                    Text("Fuzzy search threshold:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.search.fuzzySearchThreshold },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.search.fuzzySearchThreshold = newValue
                                }
                            }
                        ),
                        in: 0.1...1.0,
                        step: 0.1
                    )
                    .frame(width: 150)
                    Text(String(format: "%.1f", ironApp.configuration.search.fuzzySearchThreshold))
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                }
                .help("Lower values allow more fuzzy matching")

                HStack {
                    Text("Max search results:")
                    Spacer()
                    TextField(
                        "Results",
                        value: Binding(
                            get: { ironApp.configuration.search.maxSearchResults },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
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
                        get: { ironApp.configuration.search.searchInContent },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.search.searchInContent = newValue
                            }
                        }
                    ))

                Toggle(
                    "Search in titles",
                    isOn: Binding(
                        get: { ironApp.configuration.search.searchInTitles },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.search.searchInTitles = newValue
                            }
                        }
                    ))

                Toggle(
                    "Search in tags",
                    isOn: Binding(
                        get: { ironApp.configuration.search.searchInTags },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.search.searchInTags = newValue
                            }
                        }
                    ))
            }

            Section("Advanced") {
                Toggle(
                    "Case sensitive",
                    isOn: Binding(
                        get: { ironApp.configuration.search.caseSensitive },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.search.caseSensitive = newValue
                            }
                        }
                    ))

                Toggle(
                    "Whole words only",
                    isOn: Binding(
                        get: { ironApp.configuration.search.wholeWordOnly },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.search.wholeWordOnly = newValue
                            }
                        }
                    ))

                Button("Rebuild Search Index") {
                    Task {
                        try await ironApp.rebuildSearchIndex()
                    }
                }
                .help("Recreates the search index from scratch")
            }
        }
        .padding()
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @EnvironmentObject var ironApp: IronApp

    var body: some View {
        Form {
            Section("Theme") {
                Picker(
                    "Appearance:",
                    selection: Binding(
                        get: { ironApp.configuration.ui.theme },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.ui.theme = newValue
                            }
                        }
                    )
                ) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Layout") {
                Toggle(
                    "Show sidebar",
                    isOn: Binding(
                        get: { ironApp.configuration.ui.showSidebar },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.ui.showSidebar = newValue
                            }
                        }
                    ))

                Toggle(
                    "Show preview",
                    isOn: Binding(
                        get: { ironApp.configuration.ui.showPreview },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.ui.showPreview = newValue
                            }
                        }
                    ))

                Picker(
                    "Preview position:",
                    selection: Binding(
                        get: { ironApp.configuration.ui.previewPosition },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.ui.previewPosition = newValue
                            }
                        }
                    )
                ) {
                    ForEach(PreviewPosition.allCases, id: \.self) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .pickerStyle(.radioGroup)

                HStack {
                    Text("Sidebar width:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.ui.sidebarWidth },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.ui.sidebarWidth = newValue
                                }
                            }
                        ),
                        in: 200...400,
                        step: 10
                    )
                    .frame(width: 150)
                    Text("\(Int(ironApp.configuration.ui.sidebarWidth))pt")
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Graph Settings

struct GraphSettingsView: View {
    @EnvironmentObject var ironApp: IronApp

    var body: some View {
        Form {
            Section("Layout") {
                Picker(
                    "Algorithm:",
                    selection: Binding(
                        get: { ironApp.configuration.graph.layoutAlgorithm },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.graph.layoutAlgorithm = newValue
                            }
                        }
                    )
                ) {
                    ForEach(GraphLayoutAlgorithm.allCases, id: \.self) { algorithm in
                        Text(algorithm.displayName).tag(algorithm)
                    }
                }
                .pickerStyle(.radioGroup)

                HStack {
                    Text("Node size:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.graph.nodeSize },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.graph.nodeSize = newValue
                                }
                            }
                        ),
                        in: 4...20,
                        step: 1
                    )
                    .frame(width: 150)
                    Text("\(Int(ironApp.configuration.graph.nodeSize))pt")
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Max nodes:")
                    Spacer()
                    TextField(
                        "Max nodes",
                        value: Binding(
                            get: { ironApp.configuration.graph.maxNodes },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.graph.maxNodes = newValue
                                }
                            }
                        ), format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
            }

            Section("Physics") {
                HStack {
                    Text("Link strength:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.graph.linkStrength },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.graph.linkStrength = newValue
                                }
                            }
                        ),
                        in: 0.1...2.0,
                        step: 0.1
                    )
                    .frame(width: 150)
                    Text(String(format: "%.1f", ironApp.configuration.graph.linkStrength))
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Repulsion force:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.graph.repulsionForce },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.graph.repulsionForce = newValue
                                }
                            }
                        ),
                        in: 10...100,
                        step: 5
                    )
                    .frame(width: 150)
                    Text("\(Int(ironApp.configuration.graph.repulsionForce))")
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Centering force:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.graph.centeringForce },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.graph.centeringForce = newValue
                                }
                            }
                        ),
                        in: 0.01...0.5,
                        step: 0.01
                    )
                    .frame(width: 150)
                    Text(String(format: "%.2f", ironApp.configuration.graph.centeringForce))
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                }
            }

            Section("Appearance") {
                Picker(
                    "Color scheme:",
                    selection: Binding(
                        get: { ironApp.configuration.graph.colorScheme },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.graph.colorScheme = newValue
                            }
                        }
                    )
                ) {
                    ForEach(GraphColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayName).tag(scheme)
                    }
                }
                .pickerStyle(.radioGroup)

                Toggle(
                    "Show orphaned nodes",
                    isOn: Binding(
                        get: { ironApp.configuration.graph.showOrphanedNodes },
                        set: { newValue in
                            ironApp.configuration.updateConfiguration { config in
                                config.graph.showOrphanedNodes = newValue
                            }
                        }
                    )
                )
                .help("Show notes with no connections")

                HStack {
                    Text("Animation duration:")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { ironApp.configuration.graph.animationDuration },
                            set: { newValue in
                                ironApp.configuration.updateConfiguration { config in
                                    config.graph.animationDuration = newValue
                                }
                            }
                        ),
                        in: 0.1...1.0,
                        step: 0.1
                    )
                    .frame(width: 150)
                    Text(String(format: "%.1fs", ironApp.configuration.graph.animationDuration))
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Iron")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Knowledge Management System")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Version 1.0.0")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Built with:")
                    .font(.headline)

                Text("• SwiftUI for native macOS experience")
                Text("• Metal for hardware-accelerated graphics")
                Text("• Swift 6.2 with modern concurrency")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 16) {
                Button("GitHub") {
                    // TODO: Open GitHub repository
                }

                Button("Documentation") {
                    // TODO: Open documentation
                }

                Button("Report Bug") {
                    // TODO: Open issue tracker
                }
            }
        }
        .padding()
    }
}

// MARK: - Supporting Types

enum SettingsTab: String, CaseIterable {
    case general = "general"
    case editor = "editor"
    case search = "search"
    case appearance = "appearance"
    case graph = "graph"
    case about = "about"
}

struct SettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        SettingsView()
            .environmentObject(IronApp())
    }
}
