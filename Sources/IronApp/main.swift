//
//  main.swift
//  IronApp
//
//  Main entry point for the Iron knowledge management application
//

import AppKit
import Iron
import SwiftUI

// App Delegate for better lifecycle management
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app can receive focus and input
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If user opted into a confirm-before-quit flow, prompt them here.
        if let confirm = IronApp.shared?.configuration.general.confirmBeforeQuit, confirm {
            let alert = NSAlert()
            alert.messageText = "Quit Iron?"
            alert.informativeText = "Are you sure you want to quit? Any unsaved changes may be lost."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Perform cleanup before termination
    }
}

@main
struct IronApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var ironApp = IronApp()

    var body: some Scene {
        WindowGroup("") {
            ContentView()
                .environmentObject(ironApp)
                .environmentObject(ironApp.themeManager)
                .onAppear {
                    // Register the shared IronApp instance and make sure window can receive key events
                    IronApp.shared = ironApp
                    // Ensure shortcuts are loaded from persisted configuration now that IronApp.shared is set
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
            IronCommands()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environmentObject(ironApp)
                .environmentObject(ironApp.themeManager)
        }
    }
}
