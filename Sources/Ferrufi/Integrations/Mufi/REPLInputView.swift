/*
 REPLInputView.swift
 Ferrufi

 NSViewRepresentable wrapper around an NSTextView configured as a REPL-style input:
 - Supports multi-line editing
 - Interprets plain Enter as "commit" (execute)
 - Interprets Shift+Enter (and Option+Enter / Control+Enter) as newline insertion
 - Supports Up/Down arrow navigation to signal history traversal when the caret is at
   the beginning (Up) or end (Down) of the text.
 - Exposes callbacks for commit and history navigation so the containing SwiftUI view
   can implement history/state management and execution logic.

 Usage (example):
   REPLInputView(
       text: $inputText,
       placeholder: "Type Mufi code (Shift+Enter for newline)",
       onCommit: { currentText in ... },
       onHistoryUp: { ... },
       onHistoryDown: { ... },
       onClear: { ... }
   )
*/

import AppKit
import SwiftUI

extension Notification.Name {
    /// Request focus for the embedded REPL input control.
    /// Posted by other UI elements (for example: workspace Insert action).
    static let replFocusInput = Notification.Name("replFocusInput")
}

public struct REPLInputView: NSViewRepresentable {
    @Binding public var text: String

    /// Placeholder shown when the input is empty. This is only a hint for consumers;
    /// the actual rendering can be performed by wrapping this view in a ZStack.
    public var placeholder: String

    /// Called when the user commits the current input (presses Enter without modifiers).
    /// The current text is passed as an argument.
    public var onCommit: ((String) -> Void)?

    /// Called when the user presses Up at the start of the input (intended to retrieve
    /// previous history entry).
    public var onHistoryUp: (() -> Void)?

    /// Called when the user presses Down at the end of the input (intended to retrieve
    /// next history entry).
    public var onHistoryDown: (() -> Void)?

    /// Called when the user requests a quick jump to the oldest history entry
    /// (e.g. Option+Up).
    public var onHistoryJumpTop: (() -> Void)?

    /// Called when the user requests a quick jump to the newest history entry
    /// (e.g. Option+Down).
    public var onHistoryJumpBottom: (() -> Void)?

    /// Called to clear the input (e.g. Cmd+K).
    public var onClear: (() -> Void)?

    /// Whether the input should autofocus when the view appears.
    public var autofocus: Bool = false

    /// Minimum height for the input area (useful for single-line compact appearance).
    public var minHeight: CGFloat = 26

    public init(
        text: Binding<String>,
        placeholder: String = "",
        onCommit: ((String) -> Void)? = nil,
        onHistoryUp: (() -> Void)? = nil,
        onHistoryDown: (() -> Void)? = nil,
        onHistoryJumpTop: (() -> Void)? = nil,
        onHistoryJumpBottom: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil,
        autofocus: Bool = false,
        minHeight: CGFloat = 26
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
        self.onHistoryUp = onHistoryUp
        self.onHistoryDown = onHistoryDown
        self.onHistoryJumpTop = onHistoryJumpTop
        self.onHistoryJumpBottom = onHistoryJumpBottom
        self.onClear = onClear
        self.autofocus = autofocus
        self.minHeight = minHeight
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        // Configure the NSTextView inside an NSScrollView
        let contentSize = NSSize(width: 200, height: minHeight)

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: contentSize.width, height: .greatestFiniteMagnitude))
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)

        let textView = REPLTextView(frame: .zero, textContainer: container)
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.delegate = context.coordinator

        // Configure editing behavior appropriate for a code/REPL input
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        textView.replCoordinator = context.coordinator

        // Put initial text (binding may be pre-populated)
        textView.string = text

        let scrollView = NSScrollView(frame: .init(origin: .zero, size: contentSize))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear

        // Make coordinator hold a reference to the NSTextView for operations
        context.coordinator.textView = textView

        // Autoscroll to bottom to keep cursor visible when multi-line
        if autofocus {
            DispatchQueue.main.async {
                scrollView.window?.makeFirstResponder(textView)
            }
        }

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.string != text {
            // Preserve selectedRange if possible; otherwise place cursor at end
            let selected = tv.selectedRange()
            tv.string = text
            if selected.location <= tv.string.utf16.count {
                tv.setSelectedRange(selected)
            } else {
                tv.setSelectedRange(NSRange(location: tv.string.utf16.count, length: 0))
            }
        }

        // Apply small visual adjustments (font could be updated dynamically if needed)
        if let rtv = tv as? REPLTextView {
            rtv.textContainerInset = NSSize(width: 6, height: 6)
        }

        // Maintain focus if requested
        if autofocus {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(tv)
            }
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, NSTextViewDelegate {
        private var parent: REPLInputView
        fileprivate weak var textView: NSTextView?

        init(_ parent: REPLInputView) {
            self.parent = parent
        }

        deinit {
            // Ensure we don't leave observers around if the coordinator is freed
            NotificationCenter.default.removeObserver(self)
        }

        @objc
        @MainActor
        func handleFocusRequest(_ notification: Notification) {
            // Attempt to make the underlying NSTextView first responder so the caret becomes active
            DispatchQueue.main.async { [weak self] in
                guard let tv = self?.textView else { return }
                tv.window?.makeFirstResponder(tv)
            }
        }

        @MainActor
        public func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            // Update binding
            parent.text = tv.string
        }

        @MainActor
        fileprivate func performCommit() {
            // Grab trimmed current text and pass to commit handler
            let current = textView?.string ?? parent.text
            parent.onCommit?(current)
        }

        @MainActor
        fileprivate func goHistoryUp() {
            parent.onHistoryUp?()
        }

        @MainActor
        fileprivate func goHistoryDown() {
            parent.onHistoryDown?()
        }

        @MainActor
        fileprivate func jumpHistoryTop() {
            parent.onHistoryJumpTop?()
        }

        @MainActor
        fileprivate func jumpHistoryBottom() {
            parent.onHistoryJumpBottom?()
        }

        @MainActor
        fileprivate func clearInput() {
            parent.onClear?()
        }
    }
}

// MARK: - NSTextView subclass to intercept key events

private class REPLTextView: NSTextView {
    weak var replCoordinator: REPLInputView.Coordinator?

    override func keyDown(with event: NSEvent) {
        // Characters and normalized flags
        let chars = event.charactersIgnoringModifiers ?? ""
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Handle Enter / Return:
        // - Plain Enter/Return -> commit (execute)
        // - Shift+Enter, Option+Enter, Control+Enter -> insert newline
        if chars == "\r" || chars == "\n" {
            if flags.contains(.shift) || flags.contains(.option) || flags.contains(.control) {
                // Insert newline at current cursor position
                self.insertNewline(nil)
            } else {
                // Commit current input via coordinator
                replCoordinator?.performCommit()
            }
            return
        }

        // Handle arrow keys for history navigation:
        // Key codes: 126 = Up, 125 = Down
        // Option+Up/Option+Down => quick jump to oldest/newest history
        if flags.contains(.option) {
            if event.keyCode == 126 {  // Option + Up -> jump to oldest
                replCoordinator?.jumpHistoryTop()
                return
            } else if event.keyCode == 125 {  // Option + Down -> jump to newest
                replCoordinator?.jumpHistoryBottom()
                return
            }
        }

        // Normal history navigation: Up at start / Down at end
        if event.keyCode == 126 {  // Up
            let sel = self.selectedRange()
            if sel.length == 0 && sel.location == 0 {
                replCoordinator?.goHistoryUp()
                return
            }
        } else if event.keyCode == 125 {  // Down
            let sel = self.selectedRange()
            let utf16Count = self.string.utf16.count
            if sel.length == 0 && sel.location >= utf16Count {
                replCoordinator?.goHistoryDown()
                return
            }
        }

        // Handle Cmd+K -> clear input (common shortcut)
        if flags.contains(.command) {
            let ch = (event.charactersIgnoringModifiers ?? "").lowercased()
            if ch == "k" {
                replCoordinator?.clearInput()
                return
            }
        }

        // Defer to default behavior
        super.keyDown(with: event)
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
    struct REPLInputView_Previews: PreviewProvider {
        @State static var text = ""

        static var previews: some View {
            VStack(spacing: 8) {
                Text("REPL Input Preview")
                    .font(.headline)
                ZStack(alignment: .topLeading) {
                    REPLInputView(
                        text: $text,
                        placeholder: "Type code (Shift+Enter for newline)",
                        onCommit: { txt in
                            print("Commit:", txt)
                            text = ""
                        },
                        onHistoryUp: {
                            print("History Up")
                        },
                        onHistoryDown: {
                            print("History Down")
                        },
                        onClear: {
                            text = ""
                        },
                        autofocus: true
                    )
                    .frame(height: 80)
                    // Placeholder overlay when empty
                    if text.isEmpty {
                        Text("Type code (Shift+Enter for newline)")
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .padding()
            }
            .frame(width: 640, height: 180)
        }
    }
#endif
