//
//  UnifiedEditor.swift
//  Ferrufi
//
//  A single unified editor component that supports multiple file modes (Markdown, Mufi)
//  and — for Markdown files — an optional split preview pane. This view replaces the
//  multiple editor components by exposing one public API and internally switching
//  behaviour based on `EditorFileType` while reusing existing utilities such as the
//  `MarkdownSyntaxHighlighter` and `MarkdownPreview`.
//
//  The `UnifiedTextView` subclass implements per-mode editing behavior (syntax highlighting,
//  keyboard handling for formatting shortcuts and list continuation). The SwiftUI `UnifiedEditor`
//  view composes the scroll view and (optionally) the preview split for markdown files.
//
//  Created on 2026-01-18.
//

import AppKit
import Combine
import Foundation
import SwiftUI

// Public API: file type / mode
public enum EditorFileType {
    case markdown
    case mufi
    case rich  // reserved for future use (Notion style)
}

public struct UnifiedEditor: View {
    @Binding public var text: String
    @Binding public var isEditing: Bool

    public var fileType: EditorFileType
    public var showPreview: Bool = true  // only used for markdown files
    public var placeholder: String = "Start writing..."
    public var onTextChange: ((String) -> Void)?
    public var onSave: (() -> Void)?

    // Environment objects commonly used by other editor components
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ferrufiApp: FerrufiApp

    // Local state for internal synchronization
    @State private var internalText: String = ""
    @State private var editorHeight: CGFloat = 0

    public init(
        text: Binding<String>,
        isEditing: Binding<Bool>,
        fileType: EditorFileType,
        showPreview: Bool = true,
        placeholder: String = "Start writing...",
        onTextChange: ((String) -> Void)? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self._text = text
        self._isEditing = isEditing
        self.fileType = fileType
        self.showPreview = showPreview
        self.placeholder = placeholder
        self.onTextChange = onTextChange
        self.onSave = onSave
        self._internalText = State(initialValue: text.wrappedValue)
    }

    public var body: some View {
        Group {
            if fileType == .markdown && showPreview {
                // Split editor + preview
                HSplitView {
                    EditorContainerView(
                        text: $internalText,
                        isEditing: $isEditing,
                        fileType: fileType,
                        placeholder: placeholder,
                        onTextChange: { newText in
                            syncText(newText)
                        },
                        onSave: onSave
                    )
                    .frame(minWidth: 300)

                    NativeMarkdownPreview(
                        markdown: internalText,
                        baseURL: nil
                    )
                    .background(Color(NSColor.textBackgroundColor))
                    .frame(minWidth: 300)
                }
            } else {
                // Editor only
                EditorContainerView(
                    text: $internalText,
                    isEditing: $isEditing,
                    fileType: fileType,
                    placeholder: placeholder,
                    onTextChange: { newText in
                        syncText(newText)
                    },
                    onSave: onSave
                )
            }
        }
        .onAppear {
            internalText = text
        }
        .onChange(of: text) { _, newValue in
            // External changes should update the internal editor content
            if newValue != internalText {
                internalText = newValue
            }
        }
    }

    private func syncText(_ newText: String) {
        // Keep both bindings in sync and notify caller
        internalText = newText
        if newText != text {
            text = newText
        }
        onTextChange?(newText)
    }
}

// MARK: - Editor Container (NSViewRepresentable wrapper around UnifiedTextView)

private struct EditorContainerView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool

    var fileType: EditorFileType
    var placeholder: String
    var onTextChange: ((String) -> Void)?
    var onSave: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ferrufiApp: FerrufiApp

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let unifiedTextView = UnifiedTextView(frame: .zero, textContainer: textContainer)
        unifiedTextView.delegate = context.coordinator
        unifiedTextView.coordinator = context.coordinator
        unifiedTextView.setupForMode(fileType)

        // Basic appearance & behavior
        unifiedTextView.isEditable = true
        unifiedTextView.isSelectable = true
        unifiedTextView.allowsUndo = true
        unifiedTextView.isRichText = false
        unifiedTextView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        unifiedTextView.textContainerInset = NSSize(width: 16, height: 16)
        unifiedTextView.isVerticallyResizable = true
        unifiedTextView.isHorizontallyResizable = false
        unifiedTextView.textContainer?.widthTracksTextView = true
        unifiedTextView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)

        // Initial content
        unifiedTextView.string = text

        // Theme
        updateTheme(textView: unifiedTextView)

        // Wire formatting notifications (shared across UI)
        context.coordinator.installFormattingObservers()

        // Place into scroll view
        scrollView.documentView = unifiedTextView

        // Line number ruler if enabled in settings
        if ferrufiApp.configuration.editor.showLineNumbers {
            let ruler = LineNumberRulerView(textView: unifiedTextView)
            scrollView.hasVerticalRuler = true
            scrollView.verticalRulerView = ruler
            scrollView.rulersVisible = true
        } else {
            scrollView.rulersVisible = false
            scrollView.verticalRulerView = nil
            scrollView.hasVerticalRuler = false
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? UnifiedTextView else { return }

        // Update mode if it changed
        textView.setupForMode(fileType)

        // External text changes: preserve cursor where possible
        if textView.string != text {
            let cursor = textView.selectedRange().location
            textView.string = text
            let safe = NSRange(location: min(cursor, text.count), length: 0)
            textView.setSelectedRange(safe)
        }

        // Update theme and ruler visibility
        updateTheme(textView: textView)
        if ferrufiApp.configuration.editor.showLineNumbers {
            if !(nsView.verticalRulerView is LineNumberRulerView) {
                let ruler = LineNumberRulerView(textView: textView)
                nsView.verticalRulerView = ruler
            }
            nsView.hasVerticalRuler = true
            nsView.rulersVisible = true
        } else {
            nsView.rulersVisible = false
            nsView.verticalRulerView = nil
            nsView.hasVerticalRuler = false
        }

        // Update coordinator state
        context.coordinator.textView = textView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isEditing: $isEditing,
            onTextChange: onTextChange,
            onSave: onSave)
    }

    private func updateTheme(textView: NSTextView) {
        // Use the injected ThemeManager environment object directly
        let theme = themeManager.currentTheme

        textView.backgroundColor = NSColor(theme.colors.background)
        textView.textColor = NSColor(theme.colors.foreground)
        textView.insertionPointColor = NSColor(theme.colors.accent)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(theme.colors.accent).withAlphaComponent(0.3),
            .foregroundColor: NSColor(theme.colors.foreground),
        ]
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        // Keep bindings so we can update SwiftUI state directly and safely
        var textBinding: Binding<String>
        var isEditingBinding: Binding<Bool>
        var onTextChange: ((String) -> Void)?
        var onSave: (() -> Void)?

        weak var textView: UnifiedTextView?
        var formatterObserversInstalled = false
        var coordinatorCancellables = Set<AnyCancellable>()

        init(
            text: Binding<String>, isEditing: Binding<Bool>, onTextChange: ((String) -> Void)?,
            onSave: (() -> Void)?
        ) {
            self.textBinding = text
            self.isEditingBinding = isEditing
            self.onTextChange = onTextChange
            self.onSave = onSave
        }

        func installFormattingObservers() {
            guard !formatterObserversInstalled else { return }
            formatterObserversInstalled = true

            // Insert formatting
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertFormatting(_:)),
                name: .insertMarkdownFormatting,
                object: nil)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertList(_:)),
                name: .insertMarkdownList,
                object: nil)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertHeader(_:)),
                name: .insertMarkdownHeader,
                object: nil)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? UnifiedTextView else { return }
            self.textView = textView
            let newText = textView.string
            // Update the binding directly on the main actor
            textBinding.wrappedValue = newText
            onTextChange?(newText)
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditingBinding.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditingBinding.wrappedValue = false
            onSave?()
        }

        // MARK: - Formatting handlers

        @objc private func handleInsertFormatting(_ notification: Notification) {
            guard let payload = notification.object as? MarkdownFormatting,
                let tv = self.textView
            else { return }

            tv.wrapSelectedText(
                prefix: payload.prefix, suffix: payload.suffix, placeholder: payload.placeholder)
        }

        @objc private func handleInsertList(_ notification: Notification) {
            guard let tv = self.textView else { return }
            tv.insertListItem()
        }

        @objc private func handleInsertHeader(_ notification: Notification) {
            guard let tv = self.textView else { return }
            tv.insertHeader()
        }
    }
}

// MARK: - UnifiedTextView: single NSTextView subclass that supports multiple modes

private class UnifiedTextView: NSTextView {
    weak var coordinator: EditorContainerView.Coordinator?
    private var markdownHighlighter: MarkdownSyntaxHighlighter?
    private var mode: EditorFileType = .markdown

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCommon()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupCommon()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCommon()
    }

    private func setupCommon() {
        // Default settings
        isRichText = false
        allowsUndo = true
        isContinuousSpellCheckingEnabled = true
    }

    /// Configure the view for a specific mode.
    func setupForMode(_ fileType: EditorFileType) {
        self.mode = fileType
        switch fileType {
        case .markdown:
            // Use markdown highlighter and markdown-friendly behaviors
            if markdownHighlighter == nil {
                markdownHighlighter = MarkdownSyntaxHighlighter()
            }
            isAutomaticQuoteSubstitutionEnabled = true
            isAutomaticDashSubstitutionEnabled = true
            isAutomaticSpellingCorrectionEnabled = true
            isAutomaticTextReplacementEnabled = false
            // Use monospaced font with slightly larger size for Markdown
            self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        case .mufi:
            // Mufi script mode: simpler editor, no markdown highlighting
            markdownHighlighter = nil
            isAutomaticQuoteSubstitutionEnabled = false
            isAutomaticDashSubstitutionEnabled = false
            isAutomaticSpellingCorrectionEnabled = false
            isAutomaticTextReplacementEnabled = false
            self.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        case .rich:
            // Reserved for Notion-style behaviors; default to markdown-like
            if markdownHighlighter == nil {
                markdownHighlighter = MarkdownSyntaxHighlighter()
            }
            isAutomaticQuoteSubstitutionEnabled = false
            isAutomaticDashSubstitutionEnabled = false
            self.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        }
        // Re-apply highlighting immediately if in markdown
        if mode == .markdown {
            applyMarkdownHighlightingWhole()
        } else {
            // Clear attributes for non-markdown
            clearAllAttributes()
        }
    }

    // Apply markdown highlighting to the entire document
    private func applyMarkdownHighlightingWhole() {
        guard let highlighter = markdownHighlighter, let ts = textStorage else { return }
        let full = NSRange(location: 0, length: ts.length)
        // Reset base attributes
        ts.removeAttribute(.foregroundColor, range: full)
        ts.removeAttribute(.font, range: full)
        // Apply base font and color
        let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ts.addAttribute(.font, value: baseFont, range: full)
        ts.addAttribute(.foregroundColor, value: NSColor.textColor, range: full)

        highlighter.highlight(textStorage: ts, in: full)
    }

    private func clearAllAttributes() {
        guard let ts = textStorage else { return }
        let full = NSRange(location: 0, length: ts.length)
        ts.removeAttribute(.foregroundColor, range: full)
        ts.removeAttribute(.font, range: full)
        // Reapply base font/color
        let baseFont = self.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ts.addAttribute(.font, value: baseFont, range: full)
        ts.addAttribute(.foregroundColor, value: NSColor.textColor, range: full)
    }

    // MARK: - Editing hooks

    override func didChangeText() {
        super.didChangeText()
        // Update markdown highlighting incrementally when in markdown mode
        if mode == .markdown {
            if let ts = textStorage {
                let changedRange = ts.editedRange
                let safeRange = NSUnionRange(changedRange, NSMakeRange(0, 0))
                markdownHighlighter?.highlight(
                    textStorage: ts, in: NSRange(location: 0, length: ts.length))
            }
        }
        // Notify coordinator via NotificationCenter callback (textDidChange will call delegate)
    }

    // Support common formatting commands triggered from toolbar via NotificationCenter
    func wrapSelectedText(prefix: String, suffix: String, placeholder: String) {
        let selectedRange = self.selectedRange()
        let ns = self.string as NSString
        let selectedText = selectedRange.length > 0 ? ns.substring(with: selectedRange) : ""
        let newText: String
        if selectedText.isEmpty {
            newText = "\(prefix)\(placeholder)\(suffix)"
            replaceCharacters(in: selectedRange, with: newText)
            // Select placeholder
            let placeholderRange = NSRange(
                location: selectedRange.location + prefix.count, length: placeholder.count)
            setSelectedRange(placeholderRange)
        } else {
            newText = "\(prefix)\(selectedText)\(suffix)"
            if shouldChangeText(in: selectedRange, replacementString: newText) {
                replaceCharacters(in: selectedRange, with: newText)
                // Restore selection around content
                setSelectedRange(
                    NSRange(
                        location: selectedRange.location + prefix.count, length: selectedText.count)
                )
            }
        }
    }

    func insertListItem() {
        // Insert "- " at the start of the current line or add a new bullet line
        let sel = selectedRange()
        let textNSString = self.string as NSString
        let lineRange = textNSString.lineRange(for: sel)
        // If cursor is at empty line, insert bullet
        if lineRange.length == 0
            || (lineRange.length == 1 && textNSString.substring(with: lineRange) == "\n")
        {
            insertText("- ", replacementRange: NSRange(location: sel.location, length: 0))
        } else {
            // Otherwise, insert "- " at line start
            let insertPos = lineRange.location
            if shouldChangeText(
                in: NSRange(location: insertPos, length: 0), replacementString: "- ")
            {
                replaceCharacters(in: NSRange(location: insertPos, length: 0), with: "- ")
                setSelectedRange(NSRange(location: sel.location + 2, length: 0))
            }
        }
    }

    func insertHeader() {
        // Insert "# " at start of the current line
        let sel = selectedRange()
        let textNSString = self.string as NSString
        let lineRange = textNSString.lineRange(for: sel)
        let insertPos = lineRange.location
        if shouldChangeText(in: NSRange(location: insertPos, length: 0), replacementString: "# ") {
            replaceCharacters(in: NSRange(location: insertPos, length: 0), with: "# ")
            setSelectedRange(NSRange(location: sel.location + 2, length: 0))
        }
    }

    // Override keyDown to provide markdown-specific behaviors for Enter, Tab, Backspace in markdown mode
    override func keyDown(with event: NSEvent) {
        if mode == .markdown {
            if event.modifierFlags.contains(.command) {
                // Basic formatting shortcuts forwarded to default handlers (the wrapper UI triggers via notifications)
                // Let system handle if not intercepted
            } else {
                // Handle newline list continuation & blockquote continuation
                if event.keyCode == 36 {  // Return / Enter
                    if handleEnterKey() { return }
                } else if event.keyCode == 48 {  // Tab
                    if handleTabKey() { return }
                } else if event.keyCode == 51 {  // Backspace
                    if handleBackspaceKey() { return }
                }
            }
        }
        super.keyDown(with: event)
    }

    // Helpers for special key handling
    private func handleEnterKey() -> Bool {
        let sel = selectedRange()
        guard sel.location <= (string as NSString).length else { return false }
        let ns = string as NSString
        let lineRange = ns.lineRange(for: sel)
        let currentLine = ns.substring(with: lineRange)
        // List continuation
        if let match = currentLine.range(of: #"^(\s*)([-*+]|\d+\.)\s"#, options: .regularExpression)
        {
            let prefix = String(currentLine[currentLine.startIndex..<match.upperBound])
            insertText("\n\(prefix)", replacementRange: NSRange(location: sel.location, length: 0))
            return true
        }
        // Blockquote continuation
        if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
            let spaces = String(currentLine.prefix(while: { $0.isWhitespace }))
            insertText(
                "\n\(spaces)> ", replacementRange: NSRange(location: sel.location, length: 0))
            return true
        }
        return false
    }

    private func handleTabKey() -> Bool {
        let sel = selectedRange()
        if sel.length == 0 {
            // Insert two spaces
            insertText("  ", replacementRange: NSRange(location: sel.location, length: 0))
            return true
        } else {
            // Indent selected lines
            indentSelectedLines(indent: true)
            return true
        }
    }

    private func handleBackspaceKey() -> Bool {
        let sel = selectedRange()
        if sel.length == 0 && sel.location > 0 {
            let ns = string as NSString
            let lineRange = ns.lineRange(for: sel)
            let currentLine = ns.substring(with: lineRange)
            if currentLine.hasPrefix("  ") && sel.location == lineRange.location + 2 {
                // Remove the two-space indent
                replaceCharacters(in: NSRange(location: lineRange.location, length: 2), with: "")
                setSelectedRange(NSRange(location: lineRange.location, length: 0))
                return true
            }
        }
        return false
    }

    private func indentSelectedLines(indent: Bool) {
        let sel = selectedRange()
        let ns = string as NSString
        let linesRange = ns.lineRange(for: sel)
        let linesText = ns.substring(with: linesRange)
        let components = linesText.components(separatedBy: .newlines)
        var newText = ""
        for (i, line) in components.enumerated() {
            if indent {
                newText += "  " + line
            } else {
                if line.hasPrefix("  ") {
                    newText += String(line.dropFirst(2))
                } else {
                    newText += line
                }
            }
            if i < components.count - 1 { newText += "\n" }
        }
        if shouldChangeText(in: linesRange, replacementString: newText) {
            replaceCharacters(in: linesRange, with: newText)
            let newLocation = indent ? sel.location + 2 : max(0, sel.location - 2)
            setSelectedRange(NSRange(location: newLocation, length: sel.length))
        }
    }
}
