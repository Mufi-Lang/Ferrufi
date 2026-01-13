import AppKit
import Combine
import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @StateObject private var navigationModel = NavigationModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingFolderPermissionRequest = false
    @State private var vaultFolderURL: URL?
    // Onboarding removed: default to Application Support vault on first run

    // Trust selection is now applied immediately when the user selects a folder.

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
                // If the app was launched with a workspace path argument (e.g. `ferrufi /path`),
                // use it to initialize Ferrufi directly and skip the one-time onboarding flow.
                if let rawVaultArg = vaultPathFromCommandLineArgs() {
                    // Normalize tilde and `.` to an absolute path
                    var normalized = (rawVaultArg as NSString).expandingTildeInPath
                    if normalized == "." {
                        normalized = FileManager.default.currentDirectoryPath
                    }
                    var vaultURL = URL(fileURLWithPath: normalized)
                    var isDir: ObjCBool = false

                    // If the path doesn't exist, attempt to create the directory
                    if !FileManager.default.fileExists(atPath: vaultURL.path, isDirectory: &isDir) {
                        do {
                            try FileManager.default.createDirectory(
                                at: vaultURL, withIntermediateDirectories: true)
                        } catch {
                            await MainActor.run {
                                navigationModel.currentError = error
                                navigationModel.showingError = true
                            }
                            return
                        }
                    } else if !isDir.boolValue {
                        // If the path points to a file, use its parent directory
                        vaultURL = vaultURL.deletingLastPathComponent()
                    }

                    do {
                        try await ferrufiApp.initialize(workspacePath: vaultURL.path)

                        // Ensure a welcome note exists when initializing via CLI.
                        // If it does not exist, create it. Failures are non-fatal.
                        let welcomeURL = URL(fileURLWithPath: vaultURL.path).appendingPathComponent(
                            "Welcome.md")
                        if !FileManager.default.fileExists(atPath: welcomeURL.path) {
                            do {
                                try createWelcomeNote(at: welcomeURL)
                            } catch {
                                // Non-fatal: surface an informational message but continue startup.
                                await MainActor.run {
                                    navigationModel.showInfo(
                                        "Workspace initialized at \(vaultURL.path). Failed to create Welcome note: \(error.localizedDescription)"
                                    )
                                }
                            }
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
                                } else if let welcome = ferrufiApp.notes.first(where: {
                                    $0.title == "Welcome"
                                }) {
                                    navigationModel.selectNote(welcome, ferrufiApp: ferrufiApp)
                                }
                            case .welcome:
                                if let welcome = ferrufiApp.notes.first(where: {
                                    $0.title == "Welcome"
                                }) {
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
                        }

                        return
                    } catch {
                        await MainActor.run {
                            navigationModel.currentError = error
                            navigationModel.showingError = true
                        }
                    }
                } else {
                    await initializeApp()
                }
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
        .alert("Success", isPresented: $navigationModel.showingInfoMessage) {
            Button("OK") {
                navigationModel.showingInfoMessage = false
                navigationModel.currentInfoMessage = nil
            }
        } message: {
            if let msg = navigationModel.currentInfoMessage {
                Text(msg)
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
        .onChange(of: navigationModel.showingFolderCreation) { newValue in
            print("ContentView: showingFolderCreation changed to: \(newValue)")
        }
        .alert("Folder Access Required", isPresented: $showingFolderPermissionRequest) {
            Button("Select Folder") {
                // Ask user to select a folder that should contain the workspace.
                // The selected folder will be used as the parent where Ferrufi
                // creates a `.ferrufi` directory (select Home to use ~/.ferrufi).
                presentWorkspaceFolderPicker()
            }
            Button("Cancel", role: .cancel) {
                showingFolderPermissionRequest = false
            }
        } message: {
            Text(
                """
                Ferrufi needs access to a folder to store your workspace (e.g. ~/.ferrufi/).
                Please select the parent folder when prompted. To use the default location
                `~/.ferrufi/`, select your Home folder.
                """)
        }
        // Startup onboarding removed: app now defaults to the Application Support workspace
        // on first run (no interactive startup dialog).
        // Trust confirmation dialog removed: trust is now applied immediately on folder selection.
    }

    private func initializeApp() async {
        // If the app was already initialized (for example via CLI args), skip re-initialization.
        if ferrufiApp.isInitialized { return }

        // Use ~/.ferrufi as the single storage location
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let ironDirectory = homeDirectory.appendingPathComponent(".ferrufi")

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
            // No bookmarked parent found: default to using Application Support instead of showing onboarding.
            // This simplifies first-run behavior and avoids startup prompts.
            await createAppSupportVaultAndInitialize()
            return
        }

        do {
            // Create ~/.ferrufi structure using a bookmarked parent folder
            guard let parentPath = bookmarkedParent else {
                throw NSError(
                    domain: "com.ferrufi", code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "No permitted folder selected for workspace."
                    ]
                )
            }

            // Resolve the bookmarked parent and keep the security scope active
            guard let parentURL = bookmarkManager.resolveBookmark(forPath: parentPath) else {
                // The stored bookmark is invalid or access could not be started.
                // Remove the invalid bookmark and show onboarding so the user can re-select a folder.
                bookmarkManager.removeBookmark(forPath: parentPath)
                // No bookmarked parent found: default to Application Support fallback (no interactive onboarding)
                await createAppSupportVaultAndInitialize()
                return
            }

            let ferrufiDir = parentURL.appendingPathComponent(".ferrufi")

            try FileManager.default.createDirectory(
                at: ferrufiDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Create welcome note if this is first run
            let welcomeScriptPath = ferrufiDir.appendingPathComponent("Welcome.md")
            if !FileManager.default.fileExists(atPath: welcomeScriptPath.path) {
                try createWelcomeNote(at: welcomeScriptPath)
            }

            // Initialize Ferrufi with the workspace directory
            try await ferrufiApp.initialize(workspacePath: ferrufiDir.path)

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

    private func vaultPathFromCommandLineArgs() -> String? {
        // Return the first non-flag argument provided at launch (if any).
        // Examples:
        //   ferrufi /path/to/project
        //   open -a Ferrufi --args /path/to/project
        let args = CommandLine.arguments.dropFirst()
        for arg in args {
            if arg.starts(with: "-") { continue }
            return arg
        }
        return nil
    }

    private func presentWorkspaceFolderPicker() {
        #if os(macOS)
            // Present the open panel asynchronously so any open menus are dismissed first
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = true
                panel.prompt = "Select"
                panel.message =
                    "Select the folder that should contain your Ferrufi workspace. To use ~/.ferrufi/, select your Home folder. Hidden folders (like .ferrufi) will be shown."

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
                        // Dismiss any permission UI so the menu and sheets go away
                        showingFolderPermissionRequest = false
                        NSApp.activate(ignoringOtherApps: true)

                        // Start security-scoped access and persist trust automatically (no confirmation dialog)
                        if selectedURL.startAccessingSecurityScopedResource() {
                            // Persist bookmark (fail-fast)
                            if bookmarkManager.createBookmark(for: selectedURL) {
                                // Determine vault directory (use ~/.ferrufi if Home was selected)
                                let homeURL = FileManager.default.homeDirectoryForCurrentUser
                                let ferrufiDir: URL
                                if selectedURL.path == homeURL.path {
                                    ferrufiDir = selectedURL.appendingPathComponent(".ferrufi")
                                } else {
                                    ferrufiDir = selectedURL
                                }

                                do {
                                    try FileManager.default.createDirectory(
                                        at: ferrufiDir, withIntermediateDirectories: true,
                                        attributes: nil)
                                } catch {
                                    FerrufiApp.sharedNavigationModel?.showError(error as NSError)
                                    DispatchQueue.main.async {
                                        presentWorkspaceFolderPicker()
                                    }
                                    return
                                }

                                // Persist app-level trusted flag
                                let canonicalSelected = URL(
                                    fileURLWithPath: (selectedURL.path as NSString)
                                        .expandingTildeInPath
                                ).standardizedFileURL.path
                                ferrufiApp.configuration.updateConfiguration { config in
                                    var arr = config.trustedVaultPaths ?? []
                                    if !arr.contains(canonicalSelected) {
                                        arr.append(canonicalSelected)
                                        config.trustedVaultPaths = arr
                                    }
                                }

                                // Initialize and refresh UI asynchronously
                                Task {
                                    do {
                                        try await ferrufiApp.initialize(
                                            workspacePath: ferrufiDir.path)
                                        await MainActor.run {
                                            navigationModel.showInfo(
                                                "Workspace ready — storing data at \(ferrufiDir.path)"
                                            )
                                            print(
                                                "✅ Workspace initialized at: \(ferrufiDir.path). notes: \(ferrufiApp.notes.count), root: \(ferrufiApp.folderManager.rootFolder.path)"
                                            )
                                            // Force UI refresh: reload folders/notes and re-select root so explorer updates
                                            ferrufiApp.folderManager.refreshNotes()
                                            FerrufiApp.sharedNavigationModel?.selectFolder(
                                                ferrufiApp.folderManager.rootFolder,
                                                ferrufiApp: ferrufiApp)
                                            if let welcome = ferrufiApp.notes.first(where: {
                                                $0.title == "Welcome"
                                            }) {
                                                FerrufiApp.sharedNavigationModel?.selectNote(
                                                    welcome, ferrufiApp: ferrufiApp)
                                            }
                                        }
                                    } catch {
                                        await MainActor.run {
                                            FerrufiApp.sharedNavigationModel?.showError(
                                                error as NSError)
                                        }
                                    }
                                }
                            } else {
                                let err = NSError(
                                    domain: "com.ferrufi", code: -1,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Failed to create bookmark for the selected folder. Please try again."
                                    ]
                                )
                                FerrufiApp.sharedNavigationModel?.showError(err)
                                DispatchQueue.main.async {
                                    presentWorkspaceFolderPicker()
                                }
                            }
                        } else {
                            let err = NSError(
                                domain: "com.ferrufi", code: -1,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Failed to activate folder permission for the selected path. Please try again."
                                ]
                            )
                            FerrufiApp.sharedNavigationModel?.showError(err)
                            DispatchQueue.main.async {
                                presentWorkspaceFolderPicker()
                            }
                        }
                    } else {
                        // User cancelled or did not select a folder; nothing to do.
                    }
                }
            }
        #endif
    }

    private func openFullDiskAccessSettings() {
        // No-op: Full Disk Access flow is no longer used. Use "Select Folder" to grant access.
    }

    private func createAppSupportVaultAndInitialize() async {
        // Fallback for users who skip selecting a folder: use Application Support
        let appSupportBase = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let ferrufiAppSupport = appSupportBase.appendingPathComponent("Ferrufi")

        do {
            try FileManager.default.createDirectory(
                at: ferrufiAppSupport, withIntermediateDirectories: true, attributes: nil)
            try await ferrufiApp.initialize(workspacePath: ferrufiAppSupport.path)
        } catch {
            await MainActor.run {
                navigationModel.currentError = error
                navigationModel.showingError = true
            }
        }
    }

    private func createWelcomeNote(at url: URL) throws {
        let welcomeContent = """
            # Welcome to Ferrufi - Mufi IDE

            This is your Mufi development environment. Your scripts are stored in `~/.ferrufi/` (or your selected workspace folder).

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
