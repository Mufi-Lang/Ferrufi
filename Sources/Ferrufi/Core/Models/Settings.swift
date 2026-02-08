//
//  Settings.swift
//  Ferrufi
//
//  Global Settings class that handles all user preferences and integrates with
//  ConfigurationManager and ThemeManager.
//

import Foundation
#if os(macOS)
import SwiftUI
#endif
import Combine

/// A global, centralized settings object that provides a unified API for all user preferences.
/// It acts as a facade over `ConfigurationManager` and `ThemeManager`.
@MainActor
public final class Settings {
    /// The shared singleton instance
    public static let shared = Settings()
    
    /// Reference to the underlying configuration manager
    private let configManager: ConfigurationManager
    
    /// Reference to the theme manager
    public let themeManager: ThemeManager
    
    /// Sink for keeping the local @Published properties in sync with the config manager
    private var cancellables = Set<AnyCancellable>()
    
    /// Expose the underlying configuration for fine-grained access
    @Published public var config: FerrufiConfiguration
    
    private init() {
        // Initialize managers
        // In a real app, these might be passed in or resolved from a container
        self.configManager = FerrufiApp.shared?.configuration ?? ConfigurationManager()
        self.themeManager = ThemeManager.shared
        self.config = self.configManager.configuration
        
        // Setup synchronization
        setupBindings()
    }
    
    private func setupBindings() {
        // Use the $configuration publisher to get updates AFTER they happen
        configManager.$configuration
            .receive(on: RunLoop.main)
            .sink { [weak self] newConfig in
                guard let self = self else { return }
                self.config = newConfig
                // Force an objectWillChange to ensure SwiftUI views refresh
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - General
    
    public var launchAtLogin: Bool {
        get { config.general.launchAtLogin }
        set { update { $0.general.launchAtLogin = newValue } }
    }
    
    public var confirmBeforeQuit: Bool {
        get { config.general.confirmBeforeQuit }
        set { update { $0.general.confirmBeforeQuit = newValue } }
    }
    
    public var autoUpdateEnabled: Bool {
        get { config.general.autoUpdateEnabled }
        set { update { $0.general.autoUpdateEnabled = newValue } }
    }

    public var startupBehavior: StartupBehavior {
        get { config.general.startupBehavior }
        set { update { $0.general.startupBehavior = newValue } }
    }

    public var startupNoteId: UUID? {
        get { config.general.startupNoteId }
        set { update { $0.general.startupNoteId = newValue } }
    }
    
    // MARK: - Workspace

    public var autoSaveInterval: Double {
        get { config.workspace.autoSaveInterval }
        set { update { $0.workspace.autoSaveInterval = newValue } }
    }

    public var fileWatchingEnabled: Bool {
        get { config.workspace.fileWatchingEnabled }
        set { update { $0.workspace.fileWatchingEnabled = newValue } }
    }

    // MARK: - Editor
    
    public var fontSize: Double {
        get { config.editor.fontSize }
        set { 
            update { $0.editor.fontSize = newValue }
            themeManager.editorFontSize = newValue
        }
    }
    
    public var fontFamily: String {
        get { config.editor.fontFamily }
        set { 
            update { $0.editor.fontFamily = newValue }
            themeManager.editorFontName = newValue
        }
    }

    public var lineHeight: Double {
        get { config.editor.lineHeight }
        set { update { $0.editor.lineHeight = newValue } }
    }
    
    public var showLineNumbers: Bool {
        get { config.editor.showLineNumbers }
        set { update { $0.editor.showLineNumbers = newValue } }
    }
    
    public var wordWrap: Bool {
        get { config.editor.wordWrap }
        set { update { $0.editor.wordWrap = newValue } }
    }

    public var syntaxHighlighting: Bool {
        get { config.editor.syntaxHighlighting }
        set { update { $0.editor.syntaxHighlighting = newValue } }
    }

    public var autoComplete: Bool {
        get { config.editor.autoComplete }
        set { update { $0.editor.autoComplete = newValue } }
    }
    
    // MARK: - Search

    public var indexingEnabled: Bool {
        get { config.search.indexingEnabled }
        set { update { $0.search.indexingEnabled = newValue } }
    }

    public var fuzzySearchThreshold: Double {
        get { config.search.fuzzySearchThreshold }
        set { update { $0.search.fuzzySearchThreshold = newValue } }
    }

    public var searchInContent: Bool {
        get { config.search.searchInContent }
        set { update { $0.search.searchInContent = newValue } }
    }

    public var searchInTitles: Bool {
        get { config.search.searchInTitles }
        set { update { $0.search.searchInTitles = newValue } }
    }

    public var caseSensitive: Bool {
        get { config.search.caseSensitive }
        set { update { $0.search.caseSensitive = newValue } }
    }

    // MARK: - UI & Theme
    
    public var currentTheme: Theme {
        get { config.ui.theme }
        set {
            update { $0.ui.theme = newValue }
            // Ensure the theme manager is also updated
            if let ironTheme = IronTheme(rawValue: newValue.rawValue) {
                themeManager.setTheme(ironTheme)
            }
        }
    }
    
    public var animationsEnabled: Bool {
        get { config.ui.animationsEnabled }
        set { 
            update { $0.ui.animationsEnabled = newValue }
            themeManager.setAnimationSpeed(newValue ? .normal : .none)
        }
    }

    public var metalAccelerationEnabled: Bool {
        get { config.ui.metalAccelerationEnabled }
        set { update { $0.ui.metalAccelerationEnabled = newValue } }
    }

    public var vsyncEnabled: Bool {
        get { config.ui.vsyncEnabled }
        set { update { $0.ui.vsyncEnabled = newValue } }
    }

    public var maxFPS: Int {
        get { config.ui.maxFPS }
        set { update { $0.ui.maxFPS = newValue } }
    }
    
    // MARK: - Helper Methods
    
    /// Perform an update on the configuration and persist changes
    public func update(_ updater: (inout FerrufiConfiguration) -> Void) {
        configManager.updateConfiguration(updater)
    }
    
    /// Reset all settings to defaults
    public func resetToDefaults() {
        configManager.resetToDefaults()
    }
}

#if os(macOS)
extension Settings: ObservableObject {}
#endif
