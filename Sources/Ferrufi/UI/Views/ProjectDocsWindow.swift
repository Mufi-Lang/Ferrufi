import AppKit
import SwiftUI

@MainActor
public final class ProjectDocsWindow {
    public static let shared = ProjectDocsWindow()

    private var window: NSWindow?
    private var hosting: NSHostingController<AnyView>?
    private var windowDelegate: WindowDelegate?

    private init() {}

    public func show(docsURL: URL) {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Ideally we'd update the URL if it changed
            return
        }

        guard let app = FerrufiApp.shared else { return }

        let root = AnyView(
            ProjectDocsPreviewView(docsURL: docsURL)
                .environmentObject(app)
                .environmentObject(app.themeManager)
        )
        let host = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: host)

        win.title = "Project Documentation Preview"
        win.identifier = NSUserInterfaceItemIdentifier("Ferrufi.projectDocsWindow")
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 1000, height: 700))

        win.setFrameAutosaveName("Ferrufi.projectDocsWindow")
        if UserDefaults.standard.string(forKey: "NSWindow Frame Ferrufi.projectDocsWindow") == nil {
            win.center()
        }

        let delegate = WindowDelegate(owner: self)
        win.delegate = delegate

        self.window = win
        self.hosting = host
        self.windowDelegate = delegate

        win.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func windowWillClose() {
        window = nil
        hosting = nil
        windowDelegate = nil
    }

    private class WindowDelegate: NSObject, NSWindowDelegate {
        unowned let owner: ProjectDocsWindow

        init(owner: ProjectDocsWindow) {
            self.owner = owner
            super.init()
        }

        func windowWillClose(_ notification: Notification) {
            owner.windowWillClose()
        }
    }
}
