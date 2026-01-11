import Combine
import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @StateObject private var navigationModel = NavigationModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager()
    @State private var showingFolderAccessRequest = false

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
        .alert("Folder Access Required", isPresented: $showingFolderAccessRequest) {
            Button("OK") {}
        } message: {
            Text(
                "Ferrufi needs access to your notes folder to function properly. Please select the folder when prompted."
            )
        }
    }

    private func initializeApp() async {
        // Use ~/.ferrufi as the single storage location
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let ironDirectory = homeDirectory.appendingPathComponent(".ferrufi")
        let scriptsDirectory = ironDirectory.appendingPathComponent("scripts")

        do {
            // Create ~/.ferrufi directory structure
            try FileManager.default.createDirectory(
                at: ironDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            try FileManager.default.createDirectory(
                at: scriptsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Create welcome script if this is first run
            let welcomeScriptPath = scriptsDirectory.appendingPathComponent("Welcome.md")
            if !FileManager.default.fileExists(atPath: welcomeScriptPath.path) {
                try createWelcomeNote(at: welcomeScriptPath)
            }

            // Request security-scoped access to the vault folder if not already granted
            await requestVaultAccess(vaultPath: scriptsDirectory.path)

            // Initialize Ferrufi with the scripts directory
            try await ferrufiApp.initialize(vaultPath: scriptsDirectory.path)

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

    private func requestVaultAccess(vaultPath: String) async {
        await MainActor.run {
            // Check if we already have a bookmark for the vault path
            if bookmarkManager.hasBookmark(forPath: vaultPath) {
                // Already have access, just resolve it to activate
                _ = bookmarkManager.resolveBookmark(forPath: vaultPath)
                return
            }

            // Need to request access
            showingFolderAccessRequest = true
        }

        // Request folder access from user
        await withCheckedContinuation { continuation in
            bookmarkManager.migrateVaultPath(vaultPath) { success in
                if success {
                    print("✅ Security-scoped access granted for vault: \(vaultPath)")
                } else {
                    print("⚠️ User denied security-scoped access or vault path doesn't exist")
                }
                continuation.resume()
            }
        }

        await MainActor.run {
            showingFolderAccessRequest = false
        }
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
