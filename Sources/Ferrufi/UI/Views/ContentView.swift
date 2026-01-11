import AppKit
import Combine
import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @StateObject private var navigationModel = NavigationModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingFolderPermissionRequest = false
    @State private var vaultFolderURL: URL?
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager()

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $navigationModel.sidebarVisibility) {
            SidebarView()
                .environmentObject(navigationModel)
                .environmentObject(themeManager)
        } detail: {
            DetailView()
                .environmentObject(navigationModel)
                .environmentObject(themeManager)
        }
        .navigationSplitViewStyle(.balanced)
        .themedAccent(themeManager)
        .themedBackground(themeManager)
        .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : .light)
        .onAppear {
            navigationModel.ferrufiApp = ferrufiApp
            FerrufiApp.registerNavigationModel(navigationModel)
            Task {
                await initializeApp()
            }
        }
        .alert("Error", isPresented: $navigationModel.showingError) {
            Button("OK") {
                navigationModel.currentError = nil
            }
        } message: {
            if let error = navigationModel.currentError {
                Text(error.localizedDescription)
            }
        }
        .sheet(isPresented: $navigationModel.showingNoteCreation) {
            NoteCreationSheet()
                .environmentObject(ferrufiApp)
                .environmentObject(navigationModel)
                .environmentObject(themeManager)
        }

        .sheet(isPresented: $navigationModel.showingFolderCreation) {
            FolderCreationView()
                .environmentObject(ferrufiApp)
                .environmentObject(navigationModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $navigationModel.showingRenameNote) {
            if let note = navigationModel.noteForAction {
                RenameNoteDialog(note: note)
                    .environmentObject(ferrufiApp)
                    .environmentObject(navigationModel)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $navigationModel.showingMoveNote) {
            if let note = navigationModel.noteForAction {
                MoveNoteDialog(note: note)
                    .environmentObject(ferrufiApp)
                    .environmentObject(navigationModel)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $navigationModel.showingRenameFolder) {
            if let folder = navigationModel.folderForAction {
                RenameFolderDialog(folder: folder)
                    .environmentObject(ferrufiApp)
                    .environmentObject(navigationModel)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $navigationModel.showingSettings) {
            // Open the app settings and default to the General tab when requested
            SettingsView(initialTab: .general)
                .environmentObject(ferrufiApp)
                .environmentObject(navigationModel)
                .environmentObject(themeManager)
        }
        .onChange(of: navigationModel.showingFolderCreation) { _, newValue in
            print("ContentView: showingFolderCreation changed to: \(newValue)")
        }
        .alert("Folder Access Required", isPresented: $showingFolderPermissionRequest) {
            Button("Select Folder") {
                // Ask user to select a folder that should contain the vault.
                // The selected folder will be used as the parent where Ferrufi
                // creates a `.ferrufi` directory (select Home to use ~/.ferrufi).
                presentVaultFolderPicker()
            }
            Button("Cancel", role: .cancel) {
                showingFolderPermissionRequest = false
            }
        } message: {
            Text(
                """
                Ferrufi needs access to a folder to store your vault (e.g. ~/.ferrufi/).
                Please select the parent folder when prompted. To use the default location
                `~/.ferrufi/`, select your Home folder.
                """)
        }
    }

    private func initializeApp() async {
        // Use ~/.ferrufi as the single storage location
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let ironDirectory = homeDirectory.appendingPathComponent(".ferrufi")
        let scriptsDirectory = ironDirectory.appendingPathComponent("scripts")

        // Ensure we have a user-granted folder selection (security-scoped bookmark)
        let vaultPath = ironDirectory.path

        // Try to find a bookmarked parent folder that covers the vault path
        var bookmarkedParent: String? = nil
        for path in bookmarkManager.allBookmarkedPaths() {
            if vaultPath.hasPrefix(path) {
                bookmarkedParent = path
                break
            }
        }

        if bookmarkedParent == nil {
            // Request the user to select a parent folder (one-time)
            await MainActor.run {
                showingFolderPermissionRequest = true
            }
            return  // Wait for user to pick folder and restart initialization
        }

        do {
            // Create ~/.ferrufi structure using a bookmarked parent folder
            guard let parentPath = bookmarkedParent else {
                throw NSError(
                    domain: "com.ferrufi", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No permitted folder selected for vault."]
                )
            }

            try await bookmarkManager.withAccess(toPath: parentPath) { parentURL in
                let ferrufiDir = parentURL.appendingPathComponent(".ferrufi")
                let scriptsDir = ferrufiDir.appendingPathComponent("scripts")

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

                // Create welcome script if this is first run
                let welcomeScriptPath = scriptsDir.appendingPathComponent("Welcome.md")
                if !FileManager.default.fileExists(atPath: welcomeScriptPath.path) {
                    try createWelcomeNote(at: welcomeScriptPath)
                }

                // Initialize Ferrufi with the scripts directory
                try await ferrufiApp.initialize(vaultPath: scriptsDir.path)
            }

            // Apply configured startup behavior (restore last session, open welcome, or open a specific note)
            await MainActor.run {
                switch ferrufiApp.configuration.general.startupBehavior {
                case .restore:
                    if let ids = ferrufiApp.configuration.recentNoteIds,
                        let first = ids.first,
                        let note = ferrufiApp.notes.first(where: { $0.id == first })
                    {
                        navigationModel.selectNote(note, ferrufiApp: ferrufiApp)
                    } else if let welcome = ferrufiApp.notes.first(where: { $0.title == "Welcome" })
                    {
                        navigationModel.selectNote(welcome, ferrufiApp: ferrufiApp)
                    }
                case .welcome:
                    if let welcome = ferrufiApp.notes.first(where: { $0.title == "Welcome" }) {
                        navigationModel.selectNote(welcome, ferrufiApp: ferrufiApp)
                    }
                case .specific:
                    if let id = ferrufiApp.configuration.general.startupNoteId,
                        let note = ferrufiApp.notes.first(where: { $0.id == id })
                    {
                        navigationModel.selectNote(note, ferrufiApp: ferrufiApp)
                    } else if let ids = ferrufiApp.configuration.recentNoteIds,
                        let first = ids.first,
                        let note = ferrufiApp.notes.first(where: { $0.id == first })
                    {
                        navigationModel.selectNote(note, ferrufiApp: ferrufiApp)
                    }
                }

                // Start/stop auto-update checks according to saved preference
                if ferrufiApp.configuration.general.autoUpdateEnabled {
                    UpdateManager.shared.startAutoCheck()
                } else {
                    UpdateManager.shared.stopAutoCheck()
                }
            }

            // Ensure launch-at-login state is applied (non-blocking) on the MainActor
            Task { @MainActor in
                do {
                    try await LaunchAtLoginManager.shared.setEnabled(
                        ferrufiApp.configuration.general.launchAtLogin)
                } catch {
                    // Non-fatal: log for diagnostics but don't block startup
                    print("Failed to apply launch-at-login: \(error)")
                }
            }

        } catch {
            await MainActor.run {
                navigationModel.currentError = error
                navigationModel.showingError = true
            }
        }
    }

    private func presentVaultFolderPicker() {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Select"
            panel.message =
                "Select the folder that should contain your Ferrufi vault. To use ~/.ferrufi/, select your Home folder. Hidden folders (like .ferrufi) will be shown."

            // Default to ~/.ferrufi if it exists, otherwise default to the Home folder
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let defaultVaultURL = homeURL.appendingPathComponent(".ferrufi")
            if FileManager.default.fileExists(atPath: defaultVaultURL.path) {
                panel.directoryURL = defaultVaultURL
            } else {
                panel.directoryURL = homeURL
            }

            // Ensure hidden files/folders are visible in the panel
            // (uses KVC to enable hidden files in the Open Panel)
            panel.setValue(true, forKey: "showsHiddenFiles")

            panel.begin { response in
                if response == .OK, let selectedURL = panel.url {
                    // Create and persist a security-scoped bookmark for the selected folder
                    if bookmarkManager.createBookmark(for: selectedURL) {
                        // Resolve and use the bookmark to create the vault directories
                        if bookmarkManager.resolveBookmark(forPath: selectedURL.path) != nil {
                            Task {
                                do {
                                    try await bookmarkManager.withAccess(toPath: selectedURL.path) {
                                        parentURL in
                                        // If the user picked Home, create ~/.ferrufi inside it.
                                        // Otherwise, use the selected folder directly as vault root.
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
                                            at: ferrufiDir, withIntermediateDirectories: true,
                                            attributes: nil)
                                        try FileManager.default.createDirectory(
                                            at: scriptsDir, withIntermediateDirectories: true,
                                            attributes: nil)
                                    }
                                    // After creating, restart initialization to proceed
                                    await initializeApp()
                                } catch {
                                    await MainActor.run {
                                        navigationModel.currentError = error
                                        navigationModel.showingError = true
                                    }
                                }
                            }
                        }
                    } else {
                        Task { @MainActor in
                            navigationModel.currentError = NSError(
                                domain: "com.ferrufi", code: -1,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "Failed to store folder permission"
                                ])
                            navigationModel.showingError = true
                        }
                    }
                } else {
                    // User cancelled - no action
                }
                showingFolderPermissionRequest = false
            }
        #endif
    }

    private func openFullDiskAccessSettings() {
        // No-op: Full Disk Access flow is no longer used. Use "Select Folder" to grant access.
    }

    private func createWelcomeNote(at url: URL) throws {
        let welcomeContent = """
            # Welcome to Ferrufi - Mufi IDE

            This is your Mufi development environment. Your scripts are stored in `~/.ferrufi/scripts/`.

            ## Getting Started

            - Create new Mufi scripts with the "New Script" button
            - Write and execute Mufi code with live terminal output
            - Organize your scripts in folders
            - Use the integrated REPL for interactive development

            ## Mufi IDE Features

            - **Code Editor**: Syntax-aware editor with markdown support
            - **Integrated Terminal**: Run scripts and see output inline (⌘R)
            - **Interactive REPL**: Test code snippets interactively (⌃⌘R)
            - **File Explorer**: Browse and organize your scripts
            - **Execution Metrics**: See timing and status for every run

            ## Quick Start

            ```mufi
            // Your first Mufi script
            var greeting = "Hello, Mufi!"
            print(greeting)

            fn add(a, b) {
                return a + b
            }

            print("Result: " + str(add(5, 3)))
            ```

            Press **⌘R** to run this script and see the output in the terminal below!

            ## Keyboard Shortcuts

            - `⌘R` - Run current script
            - `⌃⌘R` - Open interactive REPL
            - `⌘N` - Create new script
            - `⌘S` - Save (auto-saves enabled)

            Happy coding! 🚀

            ---
            *Created on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))*
            """

        try welcomeContent.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(FerrufiApp())
                .previewDisplayName("Ghost White")

            ContentView()
                .environmentObject(FerrufiApp())
                .onAppear {
                    let themeManager = ThemeManager()
                    themeManager.setTheme(.tokyoNight)
                }
                .previewDisplayName("Tokyo Night")

            ContentView()
                .environmentObject(FerrufiApp())
                .onAppear {
                    let themeManager = ThemeManager()
                    themeManager.setTheme(.catppuccinMocha)
                }
                .previewDisplayName("Catppuccin Mocha")
        }
    }

}
