#!/usr/bin/env swift

import AppKit
import Foundation

// Diagnostic script to test NotionStyleEditor behaviors and identify issues

class DiagnosticTextView: NSTextView {
    var changeCount = 0
    var renderCount = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        setupDiagnostics()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupDiagnostics()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDiagnostics()
    }

    private func setupDiagnostics() {
        print("🔧 DIAGNOSTIC: Setting up diagnostic text view")

        // Basic text view setup
        isRichText = true
        allowsUndo = true
        font = NSFont.systemFont(ofSize: 16)

        // Set test content with potential problematic elements
        string = """
            # Diagnostic Test Document

            This tests various markdown elements that might cause issues:

            ## Headers work?
            ### Subheaders?

            **Bold text** and *italic text* should work.

            Here's some `inline code` that should be styled.

            ```swift
            // This is a code block
            func testFunction() {
                print("Testing code blocks")
                let array = [1, 2, 3]
                return array.count
            }
            ```

            More text after code block.

            ```python
            # Another code block
            def another_function():
                return "hello world"
            ```

            Final text to test.
            """

        // Start diagnostic rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.runDiagnostics()
        }
    }

    private func runDiagnostics() {
        print("🧪 DIAGNOSTIC: Running diagnostics...")

        guard let textStorage = self.textStorage else {
            print("❌ DIAGNOSTIC: No textStorage available")
            return
        }

        let text = textStorage.string
        print("📊 DIAGNOSTIC: Text length: \(text.count)")
        print("📊 DIAGNOSTIC: TextStorage length: \(textStorage.length)")

        // Test code block detection
        testCodeBlockDetection(text: text)

        // Test range safety
        testRangeSafety(textStorage: textStorage)

        // Test basic formatting
        testBasicFormatting(textStorage: textStorage)

        // Test typing simulation
        simulateTyping()
    }

    private func testCodeBlockDetection(text: String) {
        print("\n🔍 DIAGNOSTIC: Testing code block detection...")

        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("❌ DIAGNOSTIC: Failed to create regex")
            return
        }

        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))
        print("📋 DIAGNOSTIC: Found \(matches.count) code blocks")

        for (index, match) in matches.enumerated() {
            let fullRange = match.range
            let languageRange = match.range(at: 1)
            let contentRange = match.range(at: 2)

            print("   Block \(index + 1):")
            print("     Full range: \(fullRange)")
            print("     Language range: \(languageRange)")
            print("     Content range: \(contentRange)")

            if fullRange.location + fullRange.length > text.count {
                print("     ⚠️  ISSUE: Range exceeds text bounds!")
            }
        }
    }

    private func testRangeSafety(textStorage: NSTextStorage) {
        print("\n🛡️  DIAGNOSTIC: Testing range safety...")

        let testRanges = [
            NSRange(location: 0, length: 10),
            NSRange(location: textStorage.length - 10, length: 10),
            NSRange(location: textStorage.length - 5, length: 3),
            NSRange(location: textStorage.length, length: 0),
        ]

        for (index, range) in testRanges.enumerated() {
            let isValid = range.location + range.length <= textStorage.length
            print("   Test range \(index + 1): \(range) - \(isValid ? "✅ Valid" : "❌ Invalid")")
        }
    }

    private func testBasicFormatting(textStorage: NSTextStorage) {
        print("\n🎨 DIAGNOSTIC: Testing basic formatting...")

        // Try applying a simple format to a safe range
        let safeRange = NSRange(location: 0, length: min(10, textStorage.length))

        do {
            let boldFont = NSFont.boldSystemFont(ofSize: 16)
            textStorage.addAttribute(.font, value: boldFont, range: safeRange)
            print("   ✅ Basic formatting applied successfully")
        } catch {
            print("   ❌ Basic formatting failed: \(error)")
        }
    }

    private func simulateTyping() {
        print("\n⌨️  DIAGNOSTIC: Simulating typing...")

        // Simulate adding text
        let originalLength = string.count
        let testText = "\n\nAdded via simulation"

        // Insert at end
        let insertLocation = string.count
        insertText(testText, replacementRange: NSRange(location: insertLocation, length: 0))

        let newLength = string.count
        print("   Text length: \(originalLength) → \(newLength)")
        print("   Insertion successful: \(newLength == originalLength + testText.count)")

        // Test cursor positioning
        let cursorPos = selectedRange().location
        print("   Cursor position: \(cursorPos)")
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)

        changeCount += 1
        print("📝 DIAGNOSTIC: Text change #\(changeCount)")

        // Check for common issues
        if string.count != textStorage?.length {
            print("⚠️  DIAGNOSTIC: String/TextStorage length mismatch!")
        }

        let cursorPos = selectedRange().location
        if cursorPos > string.count {
            print("⚠️  DIAGNOSTIC: Cursor position out of bounds!")
        }
    }

    // Override insertText to monitor insertions
    override func insertText(_ string: Any, replacementRange: NSRange) {
        print("📥 DIAGNOSTIC: Inserting text at range: \(replacementRange)")
        super.insertText(string, replacementRange: replacementRange)
    }

    // Override to monitor selections
    override func setSelectedRange(_ charRange: NSRange) {
        if charRange.location > string.count {
            print("⚠️  DIAGNOSTIC: Attempting to set cursor out of bounds: \(charRange)")
            let safeRange = NSRange(location: min(charRange.location, string.count), length: 0)
            super.setSelectedRange(safeRange)
        } else {
            super.setSelectedRange(charRange)
        }
    }
}

// Test window controller
class DiagnosticWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window else { return }

        print("🪟 DIAGNOSTIC: Setting up diagnostic window")

        // Create scroll view
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        // Create text system components
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        // Create diagnostic text view
        let textView = DiagnosticTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 20, height: 20)

        scrollView.documentView = textView
        window.contentView?.addSubview(scrollView)

        window.title = "Iron Editor Diagnostics"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()

        print("✅ DIAGNOSTIC: Window setup complete")
    }
}

// Application for running diagnostics
class DiagnosticApp: NSObject, NSApplicationDelegate {
    var windowController: DiagnosticWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 DIAGNOSTIC: Starting Iron Editor Diagnostics")
        print("=====================================")
        print("")
        print("This diagnostic will test:")
        print("• Code block detection")
        print("• Range safety")
        print("• Basic formatting")
        print("• Text insertion")
        print("• Cursor positioning")
        print("")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        windowController = DiagnosticWindowController(window: window)
        windowController?.showWindow(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Run periodic checks
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.periodicDiagnostic()
        }
    }

    func periodicDiagnostic() {
        print("\n⏰ DIAGNOSTIC: Periodic check...")

        if let window = windowController?.window,
            let scrollView = window.contentView?.subviews.first as? NSScrollView,
            let textView = scrollView.documentView as? DiagnosticTextView
        {

            print("   Text length: \(textView.string.count)")
            print("   Change count: \(textView.changeCount)")
            print("   Cursor position: \(textView.selectedRange().location)")

            // Check for memory leaks or issues
            print("   Memory usage: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Run the diagnostic
print("🔧 Iron Editor Diagnostic Tool")
print("==============================")

let app = NSApplication.shared
let delegate = DiagnosticApp()
app.delegate = delegate
app.run()
