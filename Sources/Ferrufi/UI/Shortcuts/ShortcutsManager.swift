/*
 ShortcutsManager.swift
 Ferrufi

 Manages customizable keyboard shortcuts and persists them via the app configuration.
*/

import Foundation
import SwiftUI

@MainActor
public final class ShortcutsManager: ObservableObject {
    public static let shared = ShortcutsManager()

    /// Published bindings: actionId -> KeyBinding
    @Published public private(set) var bindings: [String: KeyBinding]

    /// A human-readable list of known actions (used by the settings UI).
    /// Keys correspond to action identifiers used in `FerrufiCommands` and defaults.
    public let actionLabels: [String: String] = [
        "newNote": "New Note",
        "newFolder": "New Folder",
        "importNotes": "Import Notes",
        "exportVault": "Export Vault",
        "find": "Find in Notes",
        "findAndReplace": "Find and Replace",
        "toggleSidebar": "Toggle Sidebar",
        "togglePreview": "Toggle Preview",
        "showGraph": "Show Graph View",
        "focusMode": "Focus Mode",
        "zoomIn": "Zoom In",
        "zoomOut": "Zoom Out",
        "resetZoom": "Reset Zoom",
        "goBack": "Go Back",
        "goForward": "Go Forward",
        "quickOpen": "Quick Open",
        "goToFile": "Go to File",
        "randomNote": "Random Note",
        "rebuildIndex": "Rebuild Search Index",
        "checkLinks": "Check Links",
        "stats": "Show Statistics",
    ]

    private init() {
        // Load persisted bindings from configuration if available; fallback to defaults
        if let appBindings = FerrufiApp.shared?.configuration.shortcuts.bindings {
            self.bindings = appBindings
        } else {
            self.bindings = ShortcutsConfiguration.defaultBindings
        }
    }

    // MARK: - Query helpers

    /// Returns the `KeyBinding` for the given action id (if any)
    public func binding(for actionId: String) -> KeyBinding? {
        return bindings[actionId]
    }

    /// Returns a SwiftUI `KeyboardShortcut` for the given action id, if a valid binding exists
    public func keyboardShortcut(for actionId: String) -> KeyboardShortcut? {
        guard let binding = binding(for: actionId),
            let char = binding.key.first
        else { return nil }

        let key = KeyEquivalent(char)
        let mods = eventModifiers(from: binding.modifiers)
        return KeyboardShortcut(key, modifiers: mods)
    }

    /// Convenience to get display string for UI (e.g., "⌘⇧N" or "cmd+shift+n" depending on binding)
    public func displayString(for actionId: String) -> String {
        return binding(for: actionId)?.displayString ?? ""
    }

    // MARK: - Update & Persistence

    /// Update a binding for `actionId`. Validates duplicates by default (see `allowDuplicate`).
    /// The change is persisted to `ConfigurationManager`.
    public func updateBinding(
        _ actionId: String, to binding: KeyBinding, allowDuplicate: Bool = false
    ) throws {
        // Basic validation
        guard !binding.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShortcutError.invalidKey
        }

        if !allowDuplicate && isDuplicate(binding, excluding: actionId) {
            throw ShortcutError.duplicateBinding(conflicts(with: binding))
        }

        // Update in-memory
        bindings[actionId] = binding

        // Persist immediately
        if let app = FerrufiApp.shared {
            app.configuration.updateConfiguration { config in
                config.shortcuts.bindings[actionId] = KeyBinding(
                    key: binding.key, modifiers: binding.modifiers)
            }
        }
        // Notify observers
        objectWillChange.send()
    }

    /// Reset all bindings to the application defaults and persist
    public func resetToDefaults() {
        bindings = ShortcutsConfiguration.defaultBindings
        if let app = FerrufiApp.shared {
            app.configuration.updateConfiguration { config in
                config.shortcuts.bindings = ShortcutsConfiguration.defaultBindings
            }
        }
        self.objectWillChange.send()
    }

    /// Reload shortcut bindings from the persisted configuration.
    /// Call this if the configuration may have been updated externally.
    public func reload() {
        if let appBindings = FerrufiApp.shared?.configuration.shortcuts.bindings {
            self.bindings = appBindings
        } else {
            self.bindings = ShortcutsConfiguration.defaultBindings
        }
        // Notify observers that bindings have changed
        self.objectWillChange.send()
    }

    // MARK: - Import / Export (shortcut profiles)

    /// Export the current shortcuts bindings as JSON data.
    /// The returned data is JSON-encoded `[String: KeyBinding]`.
    public func exportProfile() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self.bindings)
    }

    /// Write the current shortcuts profile as a JSON file to `url`.
    public func exportProfile(to url: URL) throws {
        let data = try exportProfile()
        try data.write(to: url, options: .atomic)
    }

    /// Import a shortcuts profile from JSON data.
    /// If `merge` is true, imported bindings overwrite only the keys present in the payload; otherwise the imported profile replaces all bindings.
    public func importProfile(from data: Data, merge: Bool = false) throws {
        let decoder = JSONDecoder()
        let imported = try decoder.decode([String: KeyBinding].self, from: data)
        if merge {
            for (action, binding) in imported {
                self.bindings[action] = binding
            }
        } else {
            self.bindings = imported
        }
        if let app = FerrufiApp.shared {
            app.configuration.updateConfiguration { config in
                config.shortcuts.bindings = self.bindings
            }
        }
        self.objectWillChange.send()
    }

    /// Import a shortcuts profile from a file URL.
    public func importProfile(from url: URL, merge: Bool = false) throws {
        // Read with security-scoped access
        let data = try url.withSecurityScope { url in
            try Data(contentsOf: url)
        }
        try importProfile(from: data, merge: merge)
    }

    // MARK: - Conflict detection

    /// Returns `true` if `binding` is already used by a different action (excluding `excluding`).
    public func isDuplicate(_ binding: KeyBinding, excluding actionToExclude: String? = nil) -> Bool
    {
        for (actionId, existing) in bindings {
            if let exclude = actionToExclude, actionId == exclude { continue }
            if existing.key.lowercased() == binding.key.lowercased()
                && normalizedModifiers(existing.modifiers) == normalizedModifiers(binding.modifiers)
            {
                return true
            }
        }
        return false
    }

    /// Returns the list of actionIds that conflict with the provided binding.
    public func conflicts(with binding: KeyBinding, excluding actionToExclude: String? = nil)
        -> [String]
    {
        var results: [String] = []
        for (actionId, existing) in bindings {
            if let exclude = actionToExclude, actionId == exclude { continue }
            if existing.key.lowercased() == binding.key.lowercased()
                && normalizedModifiers(existing.modifiers) == normalizedModifiers(binding.modifiers)
            {
                results.append(actionId)
            }
        }
        return results
    }

    // MARK: - Utilities

    /// Convert an array of modifier identifier strings into EventModifiers
    private func eventModifiers(from modifiers: [String]) -> EventModifiers {
        var m: EventModifiers = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "cmd", "command":
                m.insert(.command)
            case "option", "opt", "alt":
                m.insert(.option)
            case "shift":
                m.insert(.shift)
            case "control", "ctrl":
                m.insert(.control)
            default:
                continue
            }
        }
        return m
    }

    /// Normalizes modifiers into a canonical form used for comparisons
    private func normalizedModifiers(_ modifiers: [String]) -> [String] {
        return modifiers.map { $0.lowercased() }.sorted()
    }

    // MARK: - Error types

    public enum ShortcutError: LocalizedError {
        case invalidKey
        case duplicateBinding([String])  // conflicting action ids

        public var errorDescription: String? {
            switch self {
            case .invalidKey: return "Please provide a valid key for the shortcut."
            case .duplicateBinding(let actions):
                let joined = actions.joined(separator: ", ")
                return "This shortcut conflicts with existing bindings for: \(joined)"
            }
        }
    }
}
