import AppKit
import Combine
import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @StateObject private var navigationModel = NavigationModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingFolderPermissionRequest = false
    @State private var vaultFolderURL: URL?
    @State private var showingVaultOnboarding = false

    // Pending trust flow: store the selected folder here until user confirms trust
    @State private var pendingVaultURL: URL? = nil
    @State private var showTrustVaultAlert: Bool = false

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
                // If the app was launched with a vault path argument (e.g. `ferrufi /path`),
                // use it to initialize Ferrufi directly and skip the onboarding flow.
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
                        try await ferrufiApp.initialize(vaultPath: vaultURL.path)

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
                                        "Vault initialized at \(vaultURL.path). Failed to create Welcome note: \(error.localizedDescription)"
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
        .sheet(isPresented: $showingVaultOnboarding) {
            VaultOnboardingView(
                onSelectFolder: {
                    // Dismiss the onboarding sheet before presenting the system picker
                    showingVaultOnboarding = false
                    DispatchQueue.main.async {
                        presentVaultFolderPicker()
                    }
                },
                onSkip: { Task { await createAppSupportVaultAndInitialize() } }
            )
        }
        .alert("Trust this workspace?", isPresented: $showTrustVaultAlert) {
            Button("Trust") {
                Task {
                    await trustSelectedVault()
                }
            }
            Button("Cancel", role: .cancel) {
                if let url = pendingVaultURL {
                    url.stopAccessingSecurityScopedResource()
                }
                pendingVaultURL = nil
            }
        } message: {
            Text(
                "Do you trust this folder to be used as your Ferrufi vault? Trusting it will allow Ferrufi persistent access to files in this folder."
            )
        }
    }

    @MainActor private func trustSelectedVault() async {
        guard let url = pendingVaultURL else { return }

        // Ensure the security scope is active (it should already be active from selection)
        if !url.startAccessingSecurityScopedResource() {
            let err = NSError(
                domain: "com.ferrufi", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to activate folder permission. Please try again."
                ]
            )
            FerrufiApp.sharedNavigationModel?.showError(err)
            pendingVaultURL = nil
            showTrustVaultAlert = false
            return
        }

        // Persist the bookmark
        guard bookmarkManager.createBookmark(for: url) else {
            let err = NSError(
                domain: "com.ferrufi", code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to persist bookmark. Please try again."
                ]
            )
            FerrufiApp.sharedNavigationModel?.showError(err)
            url.stopAccessingSecurityScopedResource()
            pendingVaultURL = nil
            showTrustVaultAlert = false
            return
        }

        // Determine vault directories (if Home was selected, create ~/.ferrufi inside it)
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let ferrufiDir: URL
        if url.path == homeURL.path {
            ferrufiDir = url.appendingPathComponent(".ferrufi")
        } else {
            ferrufiDir = url
        }
        let scriptsDir = ferrufiDir.appendingPathComponent("scripts")

        do {
            try FileManager.default.createDirectory(
                at: ferrufiDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(
                at: scriptsDir, withIntermediateDirectories: true, attributes: nil)

            // Continue initialization now that bookmark is stored and folders exist
            await initializeApp()

            await MainActor.run {
                navigationModel.showInfo("Vault ready — storing data at \(scriptsDir.path)")
            }
        } catch {
            await MainActor.run {
                FerrufiApp.sharedNavigationModel?.showError(
                    NSError(
                        domain: "com.ferrufi", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]))
            }
            url.stopAccessingSecurityScopedResource()
        }

        pendingVaultURL = nil
        showTrustVaultAlert = false
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
            // Show a friendly onboarding sheet and prompt the user to select a folder (one-time)
            await MainActor.run {
                showingVaultOnboarding = true
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

            // Resolve the bookmarked parent and keep the security scope active
            guard let parentURL = bookmarkManager.resolveBookmark(forPath: parentPath) else {
                // The stored bookmark is invalid or access could not be started.
                // Remove the invalid bookmark and show onboarding so the user can re-select a folder.
                bookmarkManager.removeBookmark(forPath: parentPath)
                await MainActor.run {
                    showingVaultOnboarding = true
                }
                return
            }

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

    private func presentVaultFolderPicker() {
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
                        // Immediately dismiss any onboarding/permission UI so the menu and sheets go away
                        showingVaultOnboarding = false
                        showingFolderPermissionRequest = false
                        // Bring Ferrufi to the front to ensure the app is visible after selection
                        NSApp.activate(ignoringOtherApps: true)

                        // Start security-scoped access and prompt the user to confirm trust before persisting
                        // (fail-fast pattern: if access cannot be started, inform user and re-prompt)
                        if selectedURL.startAccessingSecurityScopedResource() {
                            // Hold the selected URL until the user confirms trust
                            pendingVaultURL = selectedURL
                            showTrustVaultAlert = true
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
                                presentVaultFolderPicker()
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
        let scriptsDir = ferrufiAppSupport.appendingPathComponent("scripts")

        do {
            try FileManager.default.createDirectory(
                at: scriptsDir, withIntermediateDirectories: true, attributes: nil)
            try await ferrufiApp.initialize(vaultPath: scriptsDir.path)
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
