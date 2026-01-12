//
//  main.swift
//  FerrufiApp
//
//  Main entry point for the Ferrufi knowledge management application
//

import AppKit
import Ferrufi
import SwiftUI

// App Delegate for better lifecycle management
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app can receive focus and input
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Initialize Mufi runtime once at app startup
        Task {
            do {
                try await MufiBridge.shared.initialize(
                    enableLeakDetection: false,
                    enableTracking: false,
                    enableSafety: true
                )
                print("✓ Mufi runtime initialized successfully")

                // Note: Skip health check for now to avoid crashes
                // The runtime will be tested when the user actually uses the REPL
            } catch {
                print("✗ Failed to initialize Mufi runtime: \(error)")
                print("  REPL features will be disabled")
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If user opted into a confirm-before-quit flow, prompt them here.
        if let confirm = FerrufiApp.shared?.configuration.general.confirmBeforeQuit, confirm {
            let alert = NSAlert()
            alert.messageText = "Quit Ferrufi?"
            alert.informativeText =
                "Are you sure you want to quit? Any unsaved changes may be lost."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop all active security-scoped resources so the system can release them
        SecurityScopedBookmarkManager.shared.stopAccessingAll()

        // Deinitialize Mufi runtime on app shutdown
        Task {
            await MufiBridge.shared.deinitialize()
            print("Mufi runtime deinitialized")
        }
    }
}

@main
struct IronApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var ferrufiApp = FerrufiApp()

    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .environmentObject(ferrufiApp)
                .environmentObject(ferrufiApp.themeManager)
                .onAppear {
                    // Register the shared FerrufiApp instance and make sure window can receive key events
                    FerrufiApp.shared = ferrufiApp
                    // Ensure shortcuts are loaded from persisted configuration now that FerrufiApp.shared is set
                    ShortcutsManager.shared.reload()
                    DispatchQueue.main.async {
                        if let window = NSApp.windows.first {
                            window.makeKeyAndOrderFront(nil)
                            window.title = ""
                            window.titlebarAppearsTransparent = true
                            window.titleVisibility = .hidden
                            window.styleMask.insert(.fullSizeContentView)
                        }
                    }
                }
        }
        .commands {
            FerrufiCommands()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environmentObject(ferrufiApp)
                .environmentObject(ferrufiApp.themeManager)
        }
    }
}
