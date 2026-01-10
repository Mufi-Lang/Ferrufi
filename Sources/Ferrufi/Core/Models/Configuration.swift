//
//  Configuration.swift
//  Ferrufi
//
//  Configuration management system for Ferrufi app settings
//

import Foundation

/// Main configuration object for Ferrufi app
public struct FerrufiConfiguration: Codable, Sendable {
    public var vault: VaultConfiguration
    public var editor: EditorConfiguration
    public var search: SearchConfiguration
    public var ui: UIConfiguration
    public var graph: GraphConfiguration
    public var shortcuts: ShortcutsConfiguration
    public var general: GeneralConfiguration
    public var additionalSettings: [String: String]

    enum CodingKeys: String, CodingKey {
        case vault
        case editor
        case search
        case ui
        case graph
        case shortcuts
        case general
        case additionalSettings
    }

    /// Currently selected vault URL
    public var vaultURL: URL? {
        get {
            if let path = additionalSettings["vaultURL"] {
                return URL(fileURLWithPath: path)
            }
            return nil
        }
        set {
            additionalSettings["vaultURL"] = newValue?.path
        }
    }

    /// Auto-save enabled setting
    public var autoSaveEnabled: Bool? {
        get {
            if let value = additionalSettings["autoSaveEnabled"] {
                return value == "true"
            }
            return nil
        }
        set {
            additionalSettings["autoSaveEnabled"] = newValue?.description
        }
    }

    /// Recent note IDs
    public var recentNoteIds: [UUID]? {
        get {
            if let data = additionalSettings["recentNoteIds"]?.data(using: .utf8) {
                return try? JSONDecoder().decode([UUID].self, from: data)
            }
            return nil
        }
        set {
            if let noteIds = newValue,
                let data = try? JSONEncoder().encode(noteIds)
            {
                additionalSettings["recentNoteIds"] = String(data: data, encoding: .utf8)
            } else {
                additionalSettings.removeValue(forKey: "recentNoteIds")
            }
        }
    }

    public init(
        vault: VaultConfiguration = VaultConfiguration(),
        editor: EditorConfiguration = EditorConfiguration(),
        search: SearchConfiguration = SearchConfiguration(),
        ui: UIConfiguration = UIConfiguration(),
        graph: GraphConfiguration = GraphConfiguration(),
        shortcuts: ShortcutsConfiguration = ShortcutsConfiguration(),
        general: GeneralConfiguration = GeneralConfiguration(),
        additionalSettings: [String: String] = [:]
    ) {
        self.vault = vault
        self.editor = editor
        self.search = search
        self.ui = ui
        self.graph = graph
        self.shortcuts = shortcuts
        self.general = general
        self.additionalSettings = additionalSettings
    }

    // Codable conformance that tolerates older config files which may not contain `general`
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.vault =
            try container.decodeIfPresent(VaultConfiguration.self, forKey: .vault)
            ?? VaultConfiguration()
        self.editor =
            try container.decodeIfPresent(EditorConfiguration.self, forKey: .editor)
            ?? EditorConfiguration()
        self.search =
            try container.decodeIfPresent(SearchConfiguration.self, forKey: .search)
            ?? SearchConfiguration()
        self.ui =
            try container.decodeIfPresent(UIConfiguration.self, forKey: .ui) ?? UIConfiguration()
        self.graph =
            try container.decodeIfPresent(GraphConfiguration.self, forKey: .graph)
            ?? GraphConfiguration()
        self.shortcuts =
            try container.decodeIfPresent(ShortcutsConfiguration.self, forKey: .shortcuts)
            ?? ShortcutsConfiguration()
        self.general =
            try container.decodeIfPresent(GeneralConfiguration.self, forKey: .general)
            ?? GeneralConfiguration()
        self.additionalSettings =
            try container.decodeIfPresent([String: String].self, forKey: .additionalSettings) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vault, forKey: .vault)
        try container.encode(editor, forKey: .editor)
        try container.encode(search, forKey: .search)
        try container.encode(ui, forKey: .ui)
        try container.encode(graph, forKey: .graph)
        try container.encode(shortcuts, forKey: .shortcuts)
        try container.encode(general, forKey: .general)
        try container.encode(additionalSettings, forKey: .additionalSettings)
    }
}

/// Configuration for vault and file management
public struct VaultConfiguration: Codable, Sendable {
    public var defaultVaultPath: String
    public var autoSaveInterval: TimeInterval
    public var fileWatchingEnabled: Bool
    public var backupEnabled: Bool
    public var backupInterval: TimeInterval
    public var maxBackups: Int

    public init(
        defaultVaultPath: String = "~/.ferrufi/notes",
        autoSaveInterval: TimeInterval = 30.0,
        fileWatchingEnabled: Bool = true,
        backupEnabled: Bool = true,
        backupInterval: TimeInterval = 3600.0,  // 1 hour
        maxBackups: Int = 10
    ) {
        self.defaultVaultPath = defaultVaultPath
        self.autoSaveInterval = autoSaveInterval
        self.fileWatchingEnabled = fileWatchingEnabled
        self.backupEnabled = backupEnabled
        self.backupInterval = backupInterval
        self.maxBackups = maxBackups
    }
}

/// Configuration for text editor behavior
public struct EditorConfiguration: Codable, Sendable {
    public var fontSize: Double
    public var fontFamily: String
    public var lineHeight: Double
    public var tabSize: Int
    public var wordWrap: Bool
    public var showLineNumbers: Bool
    public var syntaxHighlighting: Bool
    public var autoComplete: Bool
    public var livePreview: Bool
    public var spellCheck: Bool

    public init(
        fontSize: Double = 14.0,
        fontFamily: String = "SF Mono",
        lineHeight: Double = 1.5,
        tabSize: Int = 4,
        wordWrap: Bool = true,
        showLineNumbers: Bool = true,
        syntaxHighlighting: Bool = true,
        autoComplete: Bool = true,
        livePreview: Bool = true,
        spellCheck: Bool = true
    ) {
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.lineHeight = lineHeight
        self.tabSize = tabSize
        self.wordWrap = wordWrap
        self.showLineNumbers = showLineNumbers
        self.syntaxHighlighting = syntaxHighlighting
        self.autoComplete = autoComplete
        self.livePreview = livePreview
        self.spellCheck = spellCheck
    }
}

/// Configuration for search functionality
public struct SearchConfiguration: Codable, Sendable {
    public var indexingEnabled: Bool
    public var fuzzySearchThreshold: Double
    public var maxSearchResults: Int
    public var searchInContent: Bool
    public var searchInTitles: Bool
    public var searchInTags: Bool
    public var caseSensitive: Bool
    public var wholeWordOnly: Bool

    public init(
        indexingEnabled: Bool = true,
        fuzzySearchThreshold: Double = 0.7,
        maxSearchResults: Int = 100,
        searchInContent: Bool = true,
        searchInTitles: Bool = true,
        searchInTags: Bool = true,
        caseSensitive: Bool = false,
        wholeWordOnly: Bool = false
    ) {
        self.indexingEnabled = indexingEnabled
        self.fuzzySearchThreshold = fuzzySearchThreshold
        self.maxSearchResults = maxSearchResults
        self.searchInContent = searchInContent
        self.searchInTitles = searchInTitles
        self.searchInTags = searchInTags
        self.caseSensitive = caseSensitive
        self.wholeWordOnly = wholeWordOnly
    }
}

/// Configuration for UI appearance and behavior
public struct UIConfiguration: Codable, Sendable {
    public var theme: Theme
    public var sidebarWidth: Double
    public var showSidebar: Bool
    public var showPreview: Bool
    public var previewPosition: PreviewPosition
    public var animationsEnabled: Bool
    public var metalAccelerationEnabled: Bool

    public init(
        theme: Theme = .system,
        sidebarWidth: Double = 250.0,
        showSidebar: Bool = true,
        showPreview: Bool = true,
        previewPosition: PreviewPosition = .right,
        animationsEnabled: Bool = true,
        metalAccelerationEnabled: Bool = true
    ) {
        self.theme = theme
        self.sidebarWidth = sidebarWidth
        self.showSidebar = showSidebar
        self.showPreview = showPreview
        self.previewPosition = previewPosition
        self.animationsEnabled = animationsEnabled
        self.metalAccelerationEnabled = metalAccelerationEnabled
    }
}

/// Configuration for general application behavior
public struct GeneralConfiguration: Codable, Sendable {
    public var launchAtLogin: Bool
    public var confirmBeforeQuit: Bool
    public var autoUpdateEnabled: Bool
    public var startupBehavior: StartupBehavior
    public var startupNoteId: UUID?

    public init(
        launchAtLogin: Bool = false,
        confirmBeforeQuit: Bool = true,
        autoUpdateEnabled: Bool = true,
        startupBehavior: StartupBehavior = .restore,
        startupNoteId: UUID? = nil
    ) {
        self.launchAtLogin = launchAtLogin
        self.confirmBeforeQuit = confirmBeforeQuit
        self.autoUpdateEnabled = autoUpdateEnabled
        self.startupBehavior = startupBehavior
        self.startupNoteId = startupNoteId
    }
}

public enum StartupBehavior: String, Codable, CaseIterable, Sendable {
    case restore = "restore"
    case welcome = "welcome"
    case specific = "specific"

    public var displayName: String {
        switch self {
        case .restore: return "Restore last session"
        case .welcome: return "Open welcome page"
        case .specific: return "Open specific note"
        }
    }
}

/// Configuration for graph visualization
public struct GraphConfiguration: Codable, Sendable {
    public var layoutAlgorithm: GraphLayoutAlgorithm
    public var nodeSize: Double
    public var linkStrength: Double
    public var repulsionForce: Double
    public var centeringForce: Double
    public var maxNodes: Int
    public var showOrphanedNodes: Bool
    public var colorScheme: GraphColorScheme
    public var animationDuration: TimeInterval

    public init(
        layoutAlgorithm: GraphLayoutAlgorithm = .forceDirected,
        nodeSize: Double = 8.0,
        linkStrength: Double = 1.0,
        repulsionForce: Double = 30.0,
        centeringForce: Double = 0.1,
        maxNodes: Int = 1000,
        showOrphanedNodes: Bool = false,
        colorScheme: GraphColorScheme = .default,
        animationDuration: TimeInterval = 0.3
    ) {
        self.layoutAlgorithm = layoutAlgorithm
        self.nodeSize = nodeSize
        self.linkStrength = linkStrength
        self.repulsionForce = repulsionForce
        self.centeringForce = centeringForce
        self.maxNodes = maxNodes
        self.showOrphanedNodes = showOrphanedNodes
        self.colorScheme = colorScheme
        self.animationDuration = animationDuration
    }
}

/// Represents a single keyboard shortcut key binding
public struct KeyBinding: Codable, Hashable, Sendable {
    public var key: String
    public var modifiers: [String]

    public init(key: String, modifiers: [String] = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Human-friendly display string (e.g. "cmd+shift+n")
    public var displayString: String {
        let mods = modifiers.joined(separator: "+")
        return mods.isEmpty ? key : "\(mods)+\(key)"
    }
}

/// Configuration for customizable keyboard shortcuts
public struct ShortcutsConfiguration: Codable, Sendable {
    public var bindings: [String: KeyBinding]

    public init(bindings: [String: KeyBinding] = ShortcutsConfiguration.defaultBindings) {
        self.bindings = bindings
    }

    /// Default application bindings (can be overridden by user settings)
    public static var defaultBindings: [String: KeyBinding] {
        return [
            "newNote": KeyBinding(key: "n", modifiers: ["cmd"]),
            "newFolder": KeyBinding(key: "n", modifiers: ["cmd", "shift"]),
            "importNotes": KeyBinding(key: "i", modifiers: ["cmd"]),
            "exportVault": KeyBinding(key: "e", modifiers: ["cmd", "shift"]),
            "find": KeyBinding(key: "f", modifiers: ["cmd"]),
            "quickOpen": KeyBinding(key: "p", modifiers: ["cmd"]),
            "toggleSidebar": KeyBinding(key: "s", modifiers: ["ctrl", "cmd"]),
            "togglePreview": KeyBinding(key: "p", modifiers: ["ctrl", "cmd"]),
            "zoomIn": KeyBinding(key: "+", modifiers: ["cmd"]),
            "zoomOut": KeyBinding(key: "-", modifiers: ["cmd"]),
            "resetZoom": KeyBinding(key: "0", modifiers: ["cmd"]),
            "randomNote": KeyBinding(key: "r", modifiers: ["cmd", "shift"]),
            "shortcutsReference": KeyBinding(key: "/", modifiers: ["cmd"]),
        ]
    }
}

// MARK: - Enums

public enum Theme: String, Codable, CaseIterable, Sendable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

public enum PreviewPosition: String, Codable, CaseIterable, Sendable {
    case right = "right"
    case bottom = "bottom"
    case hidden = "hidden"

    public var displayName: String {
        switch self {
        case .right: return "Right"
        case .bottom: return "Bottom"
        case .hidden: return "Hidden"
        }
    }
}

public enum GraphLayoutAlgorithm: String, Codable, CaseIterable, Sendable {
    case forceDirected = "force_directed"
    case hierarchical = "hierarchical"
    case circular = "circular"
    case grid = "grid"

    public var displayName: String {
        switch self {
        case .forceDirected: return "Force Directed"
        case .hierarchical: return "Hierarchical"
        case .circular: return "Circular"
        case .grid: return "Grid"
        }
    }
}

public enum GraphColorScheme: String, Codable, CaseIterable, Sendable {
    case `default` = "default"
    case category = "category"
    case heat = "heat"
    case monochrome = "monochrome"

    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .category: return "Category"
        case .heat: return "Heat"
        case .monochrome: return "Monochrome"
        }
    }
}

// MARK: - Configuration Manager

/// Manages application configuration with persistence
@MainActor
public class ConfigurationManager: ObservableObject {
    @Published public private(set) var configuration: FerrufiConfiguration

    private let configurationURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        // Use ~/.ferrufi for configuration
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let ferrufiDirectory = homeDirectory.appendingPathComponent(".ferrufi")

        try? FileManager.default.createDirectory(
            at: ferrufiDirectory,
            withIntermediateDirectories: true)

        self.configurationURL = ferrufiDirectory.appendingPathComponent("config.json")
        self.configuration = FerrufiConfiguration()

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        loadConfiguration()
    }

    /// Loads configuration from disk
    public func loadConfiguration() {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            // Use defaults if no configuration file exists
            saveConfiguration()
            return
        }

        do {
            let data = try Data(contentsOf: configurationURL)
            configuration = try decoder.decode(FerrufiConfiguration.self, from: data)
        } catch {
            print("Failed to load configuration: \(error)")
            // Keep using defaults if loading fails
        }
    }

    /// Saves current configuration to disk
    public func saveConfiguration() {
        do {
            let data = try encoder.encode(configuration)
            try data.write(to: configurationURL)
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }

    /// Updates configuration and saves automatically
    public func updateConfiguration(_ updater: (inout FerrufiConfiguration) -> Void) {
        updater(&configuration)
        saveConfiguration()
    }

    /// Resets configuration to defaults
    public func resetToDefaults() {
        configuration = FerrufiConfiguration()
        saveConfiguration()
    }

    /// Exports configuration to a file
    public func exportConfiguration(to url: URL) throws {
        let data = try encoder.encode(configuration)
        try data.write(to: url)
    }

    /// Imports configuration from a file
    public func importConfiguration(from url: URL) throws {
        let data = try Data(contentsOf: url)
        configuration = try decoder.decode(FerrufiConfiguration.self, from: data)
        saveConfiguration()
    }
}

// MARK: - Convenience Extensions

extension ConfigurationManager {
    /// Quick access to vault configuration
    public var vault: VaultConfiguration {
        get { configuration.vault }
        set {
            configuration.vault = newValue
            saveConfiguration()
        }
    }

    /// Quick access to editor configuration
    public var editor: EditorConfiguration {
        get { configuration.editor }
        set {
            configuration.editor = newValue
            saveConfiguration()
        }
    }

    /// Quick access to search configuration
    public var search: SearchConfiguration {
        get { configuration.search }
        set {
            configuration.search = newValue
            saveConfiguration()
        }
    }

    /// Quick access to UI configuration
    public var ui: UIConfiguration {
        get { configuration.ui }
        set {
            configuration.ui = newValue
            saveConfiguration()
        }
    }

    /// Quick access to graph configuration
    public var graph: GraphConfiguration {
        get { configuration.graph }
        set {
            configuration.graph = newValue
            saveConfiguration()
        }
    }

    /// Quick access to shortcuts configuration
    public var shortcuts: ShortcutsConfiguration {
        get { configuration.shortcuts }
        set {
            configuration.shortcuts = newValue
            saveConfiguration()
        }
    }

    /// Quick access to additional settings dictionary
    public var additionalSettings: [String: String] {
        get { configuration.additionalSettings }
        set {
            configuration.additionalSettings = newValue
            saveConfiguration()
        }
    }

    /// Quick access to recently-opened note IDs
    public var recentNoteIds: [UUID]? {
        get { configuration.recentNoteIds }
        set {
            configuration.recentNoteIds = newValue
            saveConfiguration()
        }
    }

    /// Quick access to general configuration
    public var general: GeneralConfiguration {
        get { configuration.general }
        set {
            configuration.general = newValue
            saveConfiguration()
        }
    }
}

// MARK: - Error Handling

public enum ConfigurationError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case writePermissionDenied
    case corruptedData

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Configuration file not found"
        case .invalidFormat:
            return "Invalid configuration file format"
        case .writePermissionDenied:
            return "Permission denied while saving configuration"
        case .corruptedData:
            return "Configuration data is corrupted"
        }
    }
}
