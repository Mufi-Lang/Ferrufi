//
//  Settings.swift
//  Ferrufi
//
//  Global Settings class that handles all user preferences and integrates with
//  ConfigurationManager and ThemeManager.
//

import Foundation
import SwiftUI
import Combine

/// A global, centralized settings object that provides a unified API for all user preferences.
/// It acts as a facade over `ConfigurationManager` and `ThemeManager`.
@MainActor
public final class Settings: ObservableObject {
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
        // When config manager updates, update our local copy
        configManager.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.objectWillChange.send()
                self.config = self.configManager.configuration
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
    
    // MARK: - Editor
    
    public var fontSize: Double {
        get { config.editor.fontSize }
        set { update { $0.editor.fontSize = newValue } }
    }
    
    public var fontFamily: String {
        get { config.editor.fontFamily }
        set { update { $0.editor.fontFamily = newValue } }
    }
    
    public var showLineNumbers: Bool {
        get { config.editor.showLineNumbers }
        set { update { $0.editor.showLineNumbers = newValue } }
    }
    
    public var wordWrap: Bool {
        get { config.editor.wordWrap }
        set { update { $0.editor.wordWrap = newValue } }
    }
    
    // MARK: - UI & Theme
    
    public var currentTheme: Theme {
        get { config.ui.theme }
        set {
            update { $0.ui.theme = newValue }
            // Sync with ThemeManager if needed
            // themeManager.setTheme(...)
        }
    }
    
    public var animationsEnabled: Bool {
        get { config.ui.animationsEnabled }
        set { update { $0.ui.animationsEnabled = newValue } }
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
