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
                .onAppear {
                    // Make sure window can receive key events
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
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}
