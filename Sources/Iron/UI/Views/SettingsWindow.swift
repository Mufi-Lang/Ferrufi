import AppKit
import SwiftUI

/// Helper for presenting a single shared Settings window programmatically.
/// - Note: This helper lives inside the `Iron` module so it can construct
///   `SettingsView(initialTab:)` (internal initializer).
@MainActor
public final class SettingsWindow {

    /// Shared singleton instance used by the app to present settings.
    public static let shared = SettingsWindow()

    private var window: NSWindow?
    private var hosting: NSHostingController<AnyView>?
    private var windowDelegate: WindowDelegate?

    private init() {}

    /// Show the settings window and (re)open it to the requested tab.
    /// If the window already exists the content is replaced and it is brought to front.
    ///
    /// - Parameter tab: The initial tab to display (defaults to `.general`).
    func show(tab: SettingsTab = .general) {
        if let window = window, let hosting = hosting {
            // Update the root view so the tab can be changed dynamically
            if let app = IronApp.shared {
                hosting.rootView = AnyView(
                    SettingsView(initialTab: tab)
                        .environmentObject(app)
                        .environmentObject(app.themeManager)
                )
            } else {
                hosting.rootView = AnyView(SettingsView(initialTab: tab))
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // If there's no IronApp available yet, don't attempt to show settings.
        // Most callers will run after IronApp.shared has been set.
        guard let app = IronApp.shared else { return }

        let root = AnyView(
            SettingsView(initialTab: tab)
                .environmentObject(app)
                .environmentObject(app.themeManager)
        )
        let host = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: host)

        // Window configuration
        win.title = "Settings"
        win.identifier = NSUserInterfaceItemIdentifier("iron.settingsWindow")
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 720, height: 520))

        // Persist the window frame between launches and restore it automatically.
        // Only center the window on first open (when no saved frame exists).
        win.setFrameAutosaveName("iron.settingsWindow")
        if UserDefaults.standard.string(forKey: "iron.settingsWindow Frame") == nil {
            win.center()
        }

        // Keep a delegate reference so we can release references when closed
        let delegate = WindowDelegate(owner: self)
        win.delegate = delegate

        // Store references
        self.window = win
        self.hosting = host
        self.windowDelegate = delegate

        // Present window
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Convenience: show the Shortcuts tab specifically.
    func showShortcuts() {
        show(tab: .shortcuts)
    }

    /// Close and release the settings window (if open).
    public func close() {
        window?.close()
        window = nil
        hosting = nil
        windowDelegate = nil
    }

    /// Whether the settings window is currently open.
    public var isOpen: Bool {
        return window != nil
    }

    // MARK: - Internal helpers

    fileprivate func windowWillClose() {
        // Window will close: clear stored references
        window = nil
        hosting = nil
        windowDelegate = nil
    }

    private class WindowDelegate: NSObject, NSWindowDelegate {
        unowned let owner: SettingsWindow

        init(owner: SettingsWindow) {
            self.owner = owner
            super.init()
        }

        func windowWillClose(_ notification: Notification) {
            owner.windowWillClose()
        }
    }
}
