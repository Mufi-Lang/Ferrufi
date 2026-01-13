//
//  FerrufiCommands.swift
//  Ferrufi
//
//  Menu bar commands for the Ferrufi knowledge management application
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct FerrufiCommands: Commands {
    public init() {}

    // Convenience accessors to the shared app and navigation model.
    private var ferrufiApp: FerrufiApp? { FerrufiApp.shared }
    private var nav: NavigationModel? { FerrufiApp.sharedNavigationModel }
    @ObservedObject private var shortcuts = ShortcutsManager.shared

    public var body: some Commands {
        // File Menu
        CommandGroup(replacing: .newItem) {
            Button("New Script") {
                newNoteAction()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "newNote") ?? KeyboardShortcut(KeyEquivalent("n")))

            Button("New Folder") {
                newFolderAction()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "newFolder")
                    ?? KeyboardShortcut(KeyEquivalent("n"), modifiers: [.command, .shift]))

            Divider()

            Button("Import Scripts...") {
                importNotesAction()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "importNotes")
                    ?? KeyboardShortcut(KeyEquivalent("i")))

            Button("Export Scripts...") {
                exportVaultAction()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "exportVault")
                    ?? KeyboardShortcut(KeyEquivalent("e"), modifiers: [.command, .shift]))

            Divider()

            Button("Change Workspace Folder...") {
                changeVaultFolderAction()
            }
            .keyboardShortcut(KeyboardShortcut(KeyEquivalent("v"), modifiers: [.command, .shift]))
        }

        // Edit Menu
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Find in Scripts") {
                findInNotesAction()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "find") ?? KeyboardShortcut(KeyEquivalent("f")))

            Button("Find and Replace") {
                findAndReplaceAction()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "findAndReplace")
                    ?? KeyboardShortcut(KeyEquivalent("f"), modifiers: [.command, .option]))
        }

        // View Menu
        CommandMenu("View") {
            Button("Toggle Sidebar") {
                nav?.toggleSidebar()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "toggleSidebar")
                    ?? KeyboardShortcut(KeyEquivalent("s"), modifiers: [.command, .control]))

            Button("Toggle Preview") {
                nav?.togglePreview()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "togglePreview")
                    ?? KeyboardShortcut(KeyEquivalent("p"), modifiers: [.command, .control]))

            Divider()

            Button("Show Graph View") {
                showGraphView()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "showGraph")
                    ?? KeyboardShortcut(KeyEquivalent("g"), modifiers: [.command, .shift]))

            Button("Focus Mode") {
                enterFocusMode()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "focusMode")
                    ?? KeyboardShortcut(KeyEquivalent("f"), modifiers: [.command, .shift]))

            Divider()

            Button("Zoom In") {
                zoomIn()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "zoomIn") ?? KeyboardShortcut(KeyEquivalent("+")))

            Button("Zoom Out") {
                zoomOut()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "zoomOut") ?? KeyboardShortcut(KeyEquivalent("-")))

            Button("Reset Zoom") {
                resetZoom()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "resetZoom") ?? KeyboardShortcut(KeyEquivalent("0"))
            )
        }

        // Navigate Menu
        CommandMenu("Navigate") {
            Button("Go Back") {
                nav?.navigateBack()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "goBack")
                    ?? KeyboardShortcut(KeyEquivalent("["), modifiers: [.command]))

            Button("Go Forward") {
                // Forward navigation not implemented yet
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "goForward")
                    ?? KeyboardShortcut(KeyEquivalent("]"), modifiers: [.command]))

            Divider()

            Button("Quick Open") {
                quickOpen()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "quickOpen") ?? KeyboardShortcut(KeyEquivalent("p"))
            )

            Button("Go to File") {
                goToFile()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "goToFile") ?? KeyboardShortcut(KeyEquivalent("g")))

            Divider()

            Button("Random Note") {
                goToRandomNote()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "randomNote")
                    ?? KeyboardShortcut(KeyEquivalent("r"), modifiers: [.command, .shift]))
        }

        // Tools Menu
        CommandMenu("Tools") {
            Button("Rebuild Search Index") {
                rebuildSearchIndex()
            }

            Button("Check Links") {
                checkLinks()
            }

            Button("Statistics") {
                showStatistics()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "stats")
                    ?? KeyboardShortcut(KeyEquivalent("i"), modifiers: [.command, .shift]))

            Divider()

            Button("Toggle Mufi REPL") {
                toggleMufiREPL()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "toggleREPL")
                    ?? KeyboardShortcut(KeyEquivalent("r"), modifiers: [.command, .control]))

            Button("Run Mufi Script") {
                runMufiScript()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "runScript")
                    ?? KeyboardShortcut(KeyEquivalent("r"), modifiers: [.command]))

            Button("Trust Current Workspace") {
                trustCurrentWorkspaceAction()
            }

            Divider()

            Button("Export as PDF") {
                exportCurrentNoteAsPDF()
            }

            Button("Print Note") {
                printCurrentNote()
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "printNote") ?? KeyboardShortcut(KeyEquivalent("p"))
            )
        }

        // Help / Support
        CommandGroup(replacing: .help) {
            Button("Ferrufi Help") {
                openHelp()
            }

            Button("Keyboard Shortcuts") {
                openSettings(to: .shortcuts)
            }
            .keyboardShortcut(
                shortcuts.keyboardShortcut(for: "shortcutsReference")
                    ?? KeyboardShortcut(KeyEquivalent("/"), modifiers: [.command]))

            Divider()

            Button("Report Bug") {
                openURL("https://github.com/your-repo/issues/new?labels=bug")
            }

            Button("Feature Request") {
                openURL("https://github.com/your-repo/issues/new?labels=enhancement")
            }
        }
    }

    // MARK: - Actions

    private func newNoteAction() {
        nav?.showingNoteCreation = true
    }

    /// Ask the user to trust the current vault (workspace) and persist a trusted entry.
    /// This will:
    ///  - Use an existing bookmarked parent if present (no further prompt required),
    ///  - Otherwise present the folder picker so the user can select the folder to trust,
    ///  - Resolve and activate a security-scoped bookmark for the chosen folder,
    ///  - Persist the trusted path in configuration.
    private func trustCurrentWorkspaceAction() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        guard let app = ferrufiApp else { return }

        // Resolve the actual workspace path (use currently initialized path if available)
        let rawWorkspacePath =
            app.currentWorkspacePath ?? app.configuration.workspace.defaultWorkspacePath
        let workspacePath = (rawWorkspacePath as NSString).expandingTildeInPath

        // If there's already a bookmarked parent that covers the workspace, trust it directly
        if let existingParent = SecurityScopedBookmarkManager.shared
            .allBookmarkedPaths()
            .first(where: { workspacePath.hasPrefix($0) })
        {
            app.configuration.updateConfiguration { config in
                var arr = config.trustedWorkspacePaths ?? []
                if !arr.contains(existingParent) {
                    arr.append(existingParent)
                    config.trustedWorkspacePaths = arr
                }
            }
            FerrufiApp.sharedNavigationModel?.showInfo("Workspace trusted: \(existingParent)")
            return
        }

        // Otherwise ask the user to select a folder to trust
        SecurityScopedBookmarkManager.shared.requestFolderAccess(
            message:
                "Select a folder to trust for Ferrufi workspace (select Home to use ~/.ferrufi/)",
            defaultDirectory: homeURL,
            showHidden: true
        ) { url in
            guard let selectedURL = url else { return }

            // Resolve and activate the bookmark; persist the selected path as trusted
            if SecurityScopedBookmarkManager.shared.resolveBookmark(forPath: selectedURL.path)
                != nil
            {
                // Persist a canonicalized path so later prefix checks are robust
                let canonicalSelected = URL(
                    fileURLWithPath: (selectedURL.path as NSString).expandingTildeInPath
                ).standardizedFileURL.path

                app.configuration.updateConfiguration { config in
                    var arr = config.trustedWorkspacePaths ?? []
                    if !arr.contains(canonicalSelected) {
                        arr.append(canonicalSelected)
                        config.trustedWorkspacePaths = arr
                    }
                }
                FerrufiApp.sharedNavigationModel?.showInfo(
                    "Workspace trusted: \(canonicalSelected)")
            } else {
                // Show an error if we couldn't activate the bookmark
                let err = NSError(
                    domain: "com.ferrufi", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Failed to activate bookmark for the selected folder. Please try again."
                    ])
                FerrufiApp.sharedNavigationModel?.showError(err)
            }
        }
    }

    private func newFolderAction() {
        nav?.showingFolderCreation = true
    }

    private func importNotesAction() {
        guard let rootPath = ferrufiApp?.folderManager.rootFolder.path else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType.plainText,
        ]

        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                let destination = URL(fileURLWithPath: rootPath).appendingPathComponent(
                    url.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                } catch {
                    print("Import failed for \(url): \(error)")
                }
            }
            ferrufiApp?.folderManager.refreshNotes()
        }
    }

    private func exportVaultAction() {
        guard let rootPath = ferrufiApp?.folderManager.rootFolder.path else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select destination folder for workspace export"

        panel.begin { response in
            guard response == .OK, let destURL = panel.url else { return }

            do {
                let rootURL = URL(fileURLWithPath: rootPath)
                let contents = try FileManager.default.contentsOfDirectory(
                    at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                for item in contents {
                    let target = destURL.appendingPathComponent(item.lastPathComponent)
                    if FileManager.default.fileExists(atPath: target.path) {
                        try FileManager.default.removeItem(at: target)
                    }
                    try FileManager.default.copyItem(at: item, to: target)
                }
                showAlert(
                    title: "Export Completed", message: "Workspace exported to \(destURL.path)")
            } catch {
                print("Export failed: \(error)")
                showAlert(title: "Export Failed", message: "\(error.localizedDescription)")
            }
        }
    }

    private func changeVaultFolderAction() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser

        SecurityScopedBookmarkManager.shared.requestFolderAccess(
            message:
                "Select a folder to contain your Ferrufi workspace (select Home to use ~/.ferrufi/)",
            defaultDirectory: homeURL,
            showHidden: true
        ) { url in
            guard let selectedURL = url else { return }
            Task {
                do {
                    // Resolve and activate persistent access to the selected folder
                    guard
                        let parentURL = SecurityScopedBookmarkManager.shared.resolveBookmark(
                            forPath: selectedURL.path)
                    else {
                        print("Failed to activate bookmark for selected folder.")
                        return
                    }

                    // If the user picked Home, create ~/.ferrufi inside it
                    let ferrufiDir: URL
                    if parentURL.path == homeURL.path {
                        ferrufiDir = parentURL.appendingPathComponent(".ferrufi")
                    } else {
                        ferrufiDir = parentURL
                    }

                    // Create the necessary directory under the active security scope
                    try FileManager.default.createDirectory(
                        at: ferrufiDir, withIntermediateDirectories: true, attributes: nil)

                    // Reinitialize Ferrufi with the new vault location (use the selected folder directly)
                    if let app = ferrufiApp {
                        try await app.initialize(workspacePath: ferrufiDir.path)
                    }

                    // Show a confirmation message via the shared navigation model (if available)
                    await MainActor.run {
                        FerrufiApp.sharedNavigationModel?.showInfo(
                            "Workspace folder updated: \(ferrufiDir.path)")
                    }
                } catch {
                    print("Failed to change vault folder: \(error)")
                    // Non-fatal: attempt to surface to user via an alert in the UI if appropriate
                }
            }
        }

    }

    private func findInNotesAction() {
        nav?.isSearching = true
    }

    private func findAndReplaceAction() {
        // placeholder - enable search UI for now
        nav?.isSearching = true
    }

    private func showGraphView() {
        // Use search destination as a lightweight way to indicate graph intent for now
        nav?.navigate(to: .search("graph"))
    }

    private func enterFocusMode() {
        nav?.sidebarVisible = false
        nav?.previewVisible = false
    }

    private func zoomIn() {
        ferrufiApp?.configuration.updateConfiguration {
            $0.editor.fontSize = min(32.0, $0.editor.fontSize + 1.0)
        }
    }

    private func zoomOut() {
        ferrufiApp?.configuration.updateConfiguration {
            $0.editor.fontSize = max(8.0, $0.editor.fontSize - 1.0)
        }
    }

    private func resetZoom() {
        ferrufiApp?.configuration.updateConfiguration {
            $0.editor.fontSize = 14.0
        }
    }

    private func quickOpen() {
        nav?.isSearching = true
    }

    private func goToFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType.plainText,
        ]

        panel.begin { response in
            guard response == .OK, let url = panel.url, let app = ferrufiApp else { return }

            if let note = app.folderManager.notes.first(where: { $0.filePath == url.path }) {
                nav?.selectNote(note, ferrufiApp: app)
                return
            }

            if let note = app.notes.first(where: {
                $0.title == url.deletingPathExtension().lastPathComponent
            }) {
                nav?.selectNote(note, ferrufiApp: app)
                return
            }

            // If the file is outside the vault, import it into the vault
            let dest = URL(fileURLWithPath: app.folderManager.rootFolder.path)
                .appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                app.folderManager.refreshNotes()
            } catch {
                print("Failed to import selected file: \(error)")
            }
        }
    }

    private func goToRandomNote() {
        guard let app = ferrufiApp, !app.notes.isEmpty else { return }
        if let note = app.notes.randomElement() {
            nav?.selectNote(note, ferrufiApp: app)
        }
    }

    private func rebuildSearchIndex() {
        Task {
            do {
                try await ferrufiApp?.rebuildSearchIndex()
                showAlert(title: "Search Index", message: "Rebuild completed")
            } catch {
                print("Rebuild search index failed: \(error)")
                showAlert(
                    title: "Search Index", message: "Rebuild failed: \(error.localizedDescription)")
            }
        }
    }

    private func checkLinks() {
        guard let storage = ferrufiApp?.fileStorage else { return }

        Task {
            let manager = LinkManager(storage: storage as any UnifiedStorageProtocol)
            await manager.rebuildAllLinks()
            showAlert(title: "Link Check", message: "Link validation completed")
        }
    }

    private func showStatistics() {
        guard let app = ferrufiApp else { return }
        let message = """
            Notes: \(app.workspaceStats.totalNotes)
            Words: \(app.workspaceStats.totalWords)
            Tags: \(app.workspaceStats.totalTags)
            Indexing: \(app.isIndexing ? "in progress" : "idle")
            """
        showAlert(title: "Workspace Statistics", message: message)
    }

    private func exportCurrentNoteAsPDF() {
        showAlert(title: "Export", message: "Export to PDF is not implemented yet")
    }

    private func printCurrentNote() {
        showAlert(title: "Print", message: "Print is not implemented yet")
    }

    private func openHelp() {
        openURL("https://github.com/your-repo/wiki")
    }

    private func showShortcutsReference() {
        SettingsWindow.shared.showShortcuts()
    }

    private func openSettings(to tab: SettingsTab = .general) {
        SettingsWindow.shared.show(tab: tab)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func toggleMufiREPL() {
        // Post notification to toggle REPL in the editor
        NotificationCenter.default.post(name: .toggleMufiREPL, object: nil)
    }

    private func runMufiScript() {
        // Post notification to run Mufi script in the editor
        NotificationCenter.default.post(name: .runMufiScript, object: nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

// MARK: - Notification Extensions for Mufi

extension Notification.Name {
    static let toggleMufiREPL = Notification.Name("toggleMufiREPL")
    static let runMufiScript = Notification.Name("runMufiScript")
}
