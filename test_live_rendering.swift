#!/usr/bin/env swift

import AppKit
import Foundation

// Create a simple test to check if the NotionStyleEditor is rendering properly

class TestNotionTextView: NSTextView {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTest()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTest()
    }

    private func setupTest() {
        isRichText = true
        allowsUndo = true
        font = NSFont.systemFont(ofSize: 16)
        backgroundColor = NSColor.textBackgroundColor

        // Set test content
        string = """
            # This is a header
            This is **bold text** and this is *italic text*.

            Here's some `inline code` in the text.

            ```swift
            func testCode() {
                print("Hello world")
            }
            ```

            ## Another header
            - List item 1
            - List item 2

            > This is a quote
            """

        // Apply basic rendering test
        testRenderingLogic()
    }

    private func testRenderingLogic() {
        guard let textStorage = self.textStorage else {
            print("❌ ERROR: textStorage is nil")
            return
        }

        let text = textStorage.string
        print("📝 Text length: \(text.count)")
        print("📝 Text storage length: \(textStorage.length)")

        // Test header detection
        let headerPattern = #"^(#{1,6})\s+(.+)$"#
        let headerRegex = try! NSRegularExpression(
            pattern: headerPattern, options: [.anchorsMatchLines])
        let headerMatches = headerRegex.matches(in: text, range: NSRange(0..<text.count))

        print("🔍 Found \(headerMatches.count) headers")

        for (index, match) in headerMatches.enumerated() {
            let syntaxRange = match.range(at: 1)  // The # symbols
            let contentRange = match.range(at: 2)  // The header text

            print("   Header \(index + 1): syntax=\(syntaxRange), content=\(contentRange)")

            // Apply header formatting
            if syntaxRange.location + syntaxRange.length <= textStorage.length {
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor.lightGray, range: syntaxRange)
                textStorage.addAttribute(
                    .font, value: NSFont.systemFont(ofSize: 8), range: syntaxRange)
                print("   ✅ Applied syntax hiding to header \(index + 1)")
            } else {
                print("   ❌ Header \(index + 1) syntax range out of bounds")
            }

            if contentRange.location + contentRange.length <= textStorage.length {
                let headerLevel = match.range(at: 1).length
                let fontSize: CGFloat = max(32 - CGFloat(headerLevel - 1) * 4, 16)
                let headerFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)

                textStorage.addAttribute(.font, value: headerFont, range: contentRange)
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor.systemBlue, range: contentRange)
                print("   ✅ Applied header styling to header \(index + 1) (size: \(fontSize))")
            } else {
                print("   ❌ Header \(index + 1) content range out of bounds")
            }
        }

        // Test bold detection
        let boldPattern = #"\*\*([^*]+)\*\*"#
        let boldRegex = try! NSRegularExpression(pattern: boldPattern)
        let boldMatches = boldRegex.matches(in: text, range: NSRange(0..<text.count))

        print("🔍 Found \(boldMatches.count) bold patterns")

        for (index, match) in boldMatches.enumerated() {
            let fullRange = match.range(at: 0)
            let contentRange = match.range(at: 1)

            print("   Bold \(index + 1): full=\(fullRange), content=\(contentRange)")

            // Hide syntax (** symbols)
            let beforeSyntax = NSRange(location: fullRange.location, length: 2)
            let afterSyntax = NSRange(
                location: contentRange.location + contentRange.length, length: 2)

            if beforeSyntax.location + beforeSyntax.length <= textStorage.length {
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor.clear, range: beforeSyntax)
                print("   ✅ Hid before syntax for bold \(index + 1)")
            }

            if afterSyntax.location + afterSyntax.length <= textStorage.length {
                textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: afterSyntax)
                print("   ✅ Hid after syntax for bold \(index + 1)")
            }

            // Style content
            if contentRange.location + contentRange.length <= textStorage.length {
                let boldFont = NSFont.boldSystemFont(ofSize: 16)
                textStorage.addAttribute(.font, value: boldFont, range: contentRange)
                print("   ✅ Applied bold styling to bold \(index + 1)")
            }
        }

        print("🎉 Rendering test completed")
    }
}

// Create a window to test
class TestWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window else { return }

        // Create scroll view
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        // Create text container and layout manager
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        // Create test text view
        let textView = TestNotionTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 20, height: 20)

        scrollView.documentView = textView
        window.contentView?.addSubview(scrollView)

        window.title = "NotionStyleEditor Rendering Test"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
    }
}

// Application setup
class TestApp: NSObject, NSApplicationDelegate {
    var windowController: TestWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Starting NotionStyleEditor rendering test...")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        windowController = TestWindowController(window: window)
        windowController?.showWindow(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Run the test
let app = NSApplication.shared
let delegate = TestApp()
app.delegate = delegate
app.run()
