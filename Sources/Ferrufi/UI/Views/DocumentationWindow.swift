//
//  DocumentationWindow.swift
//  Ferrufi
//

import AppKit
import SwiftUI

@MainActor
public final class DocumentationWindow {
    public static let shared = DocumentationWindow()

    private var window: NSWindow?
    private var hosting: NSHostingController<AnyView>?
    private var windowDelegate: WindowDelegate?

    private init() {}

    public func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let app = FerrufiApp.shared else { return }

        let root = AnyView(
            DocBrowserView()
                .environmentObject(app)
                .environmentObject(app.themeManager)
        )
        let host = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: host)

        win.title = "Mufi Documentation"
        win.identifier = NSUserInterfaceItemIdentifier("Ferrufi.documentationWindow")
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.setContentSize(NSSize(width: 900, height: 600))
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true

        win.setFrameAutosaveName("Ferrufi.documentationWindow")
        if UserDefaults.standard.string(forKey: "NSWindow Frame Ferrufi.documentationWindow") == nil {
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

    public func close() {
        window?.close()
        window = nil
        hosting = nil
        windowDelegate = nil
    }

    fileprivate func windowWillClose() {
        window = nil
        hosting = nil
        windowDelegate = nil
    }

    private class WindowDelegate: NSObject, NSWindowDelegate {
        unowned let owner: DocumentationWindow

        init(owner: DocumentationWindow) {
            self.owner = owner
            super.init()
        }

        func windowWillClose(_ notification: Notification) {
            owner.windowWillClose()
        }
    }
}
