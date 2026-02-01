//
//  UnifiedEditor.swift
//  Ferrufi
//
//  A single unified editor component that supports Mufi mode and additional modes.
//  This view replaces the multiple editor components by exposing one public API and
//  switching behaviour based on `EditorFileType` while reusing existing utilities such as
//  the editor syntax highlighter and previewer.
//
//  The `UnifiedTextView` subclass implements per-mode editing behavior (syntax highlighting,
//  keyboard handling for formatting shortcuts and list continuation). The SwiftUI `UnifiedEditor`
//  view composes the scroll view and an optional secondary split/pane.
//
//  Created on 2026-01-18.
//

import AppKit
import Combine
import Foundation
import SwiftUI

// Public API: file type / mode
public enum EditorFileType {
    case mufi
    case markdown
}

// Fonts are provided at runtime via ThemeManager. Avoid global NSFont constants so font sizing
// can be configured by users and remain safe with actor isolation. The `EditorContainerView`
// applies the current font from `ThemeManager` to the `UnifiedTextView` instance.

public struct UnifiedEditor: View {
    @Binding public var text: String
    @Binding public var isEditing: Bool

    public var fileType: EditorFileType

    public var placeholder: String = "Start writing..."
    public var onTextChange: ((String) -> Void)?
    public var onSave: (() -> Void)?
    // Enable/disable incremental highlighting (defaults to true)
    public var highlightingEnabled: Bool = true

    // Environment objects commonly used by other editor components
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ferrufiApp: FerrufiApp
    @EnvironmentObject private var settings: Settings

    // Local state for internal synchronization
    @State private var internalText: String = ""
    @State private var editorHeight: CGFloat = 0
    // Secondary rendering functionality removed

    public init(
        text: Binding<String>,
        isEditing: Binding<Bool>,
        fileType: EditorFileType,
        placeholder: String = "Start writing...",
        highlightingEnabled: Bool = true,
        onTextChange: ((String) -> Void)? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self._text = text
        self._isEditing = isEditing
        self.fileType = fileType
        self.placeholder = placeholder
        self.highlightingEnabled = highlightingEnabled
        self.onTextChange = onTextChange
        self.onSave = onSave
        self._internalText = State(initialValue: text.wrappedValue)
    }

    public var body: some View {
        Group {
            VStack(spacing: 0) {
                // Secondary pane removed

                EditorContainerView(
                    text: $internalText,
                    isEditing: $isEditing,
                    fileType: fileType,
                    placeholder: placeholder,
                    highlightingEnabled: highlightingEnabled,
                    onTextChange: { newText in syncText(newText) },
                    onSave: onSave
                )
                .id("\(settings.showLineNumbers)-\(settings.wordWrap)-\(settings.fontFamily)-\(settings.fontSize)-\(settings.lineHeight)")
            }
        }
        .onAppear {
            internalText = text
            // Secondary initialization removed

            // If we opened a Mufi file, lock the enforced editor font and size to the
            // currently resolved monospaced family so the raw editor uses the Mufi editor's
            // exact font & point-size.
            if fileType == .mufi {
                DispatchQueue.main.async {
                    themeManager.forcedMonospacedEditorFontName =
                        themeManager.resolvedMonospacedFontName
                    themeManager.editorFontSize = Double(themeManager.monospacedNSFont.pointSize)
                }
            }
        }
        .onChange(of: fileType) { newMode in
            // When switching into Mufi mode, lock the forced monospaced font and size so
            // the raw editor remains identical to the Mufi script editor. When switching
            // away, clear the forced name so user preferences can take effect.
            if newMode == .mufi {
                DispatchQueue.main.async {
                    themeManager.forcedMonospacedEditorFontName =
                        themeManager.resolvedMonospacedFontName
                    themeManager.editorFontSize = Double(themeManager.monospacedNSFont.pointSize)
                }
            } else {
                DispatchQueue.main.async {
                    themeManager.forcedMonospacedEditorFontName = nil
                }
            }
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
    // When false, the underlying UnifiedTextView will skip incremental highlighting.
    var highlightingEnabled: Bool = true
    var onTextChange: ((String) -> Void)?
    var onSave: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ferrufiApp: FerrufiApp
    @EnvironmentObject private var settings: Settings

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
        // Propagate highlighting preference from the SwiftUI wrapper to the NSTextView subclass
        unifiedTextView.highlightingEnabled = highlightingEnabled

                // Basic appearance & behavior

                unifiedTextView.isEditable = true

                unifiedTextView.isSelectable = true

                unifiedTextView.allowsUndo = true

                unifiedTextView.isRichText = false

                // Use monospaced font so the editor displays like the Mufi script editor

                // (consistent appearance across script and note editing modes).

                let chosenFont: NSFont = themeManager.monospacedNSFont

                unifiedTextView.font = chosenFont

                unifiedTextView.textContainerInset = NSSize(width: 16, height: 16)

                unifiedTextView.isVerticallyResizable = true

                

                // Apply Word Wrap based on settings

                if settings.wordWrap {

                    unifiedTextView.isHorizontallyResizable = false

                    unifiedTextView.textContainer?.widthTracksTextView = true

                } else {

                    unifiedTextView.isHorizontallyResizable = true

                    unifiedTextView.textContainer?.widthTracksTextView = false

                    unifiedTextView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

                    scrollView.hasHorizontalScroller = true

                }

        

                // Apply Line Height

                let paragraphStyle = NSMutableParagraphStyle()

                paragraphStyle.lineHeightMultiple = CGFloat(settings.lineHeight)

                unifiedTextView.defaultParagraphStyle = paragraphStyle

        

                // Initial content

        
        unifiedTextView.string = text

        // Ensure base font is applied to text storage so raw text matches the preview/editor immediately
        if let font = unifiedTextView.font {
            textStorage.addAttribute(
                .font, value: font, range: NSRange(location: 0, length: textStorage.length))
            // Ensure typing attributes inherit the same font so newly typed text matches preview/editor
            unifiedTextView.typingAttributes[.font] = font
        }

        // Theme
        updateTheme(textView: unifiedTextView)

        // Make the highlighter use the same base family so token-derived fonts match.
        // Call this AFTER setting initial string and base font attributes.
        unifiedTextView.configureHighlighter(
            baseFontName: unifiedTextView.font?.fontName, baseSize: themeManager.editorFontSize)

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

        // Use monospaced font so the editor displays like the Mufi script editor -
        // keep parity with Mufi files for visual consistency.
        let chosenFont: NSFont = themeManager.monospacedNSFont
        textView.font = chosenFont
        
        // Ensure base font is applied to the whole storage again to reset any external attribute changes
        if let ts = textView.textStorage, let base = textView.font {
            let full = NSRange(location: 0, length: ts.length)
            ts.addAttribute(.font, value: base, range: full)
        }

        // Re-run highlighting AFTER font/theme updates
        let highlighterFontName: String? = (fileType == .mufi) ? chosenFont.fontName : nil
        textView.configureHighlighter(
            baseFontName: highlighterFontName, baseSize: themeManager.editorFontSize)
        
        // Word wrap handling in update
        if settings.wordWrap {
            if textView.textContainer?.widthTracksTextView == false {
                textView.isHorizontallyResizable = false
                textView.textContainer?.widthTracksTextView = true
                nsView.hasHorizontalScroller = false
            }
        } else {
            if textView.textContainer?.widthTracksTextView == true {
                textView.isHorizontallyResizable = true
                textView.textContainer?.widthTracksTextView = false
                textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                nsView.hasHorizontalScroller = true
            }
        }

        if settings.showLineNumbers {
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
        context.coordinator.themeManager = themeManager
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            text: $text,
            isEditing: $isEditing,
            onTextChange: onTextChange,
            onSave: onSave)
        coordinator.themeManager = themeManager
        return coordinator
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
        var themeManager: ThemeManager?

        weak var textView: UnifiedTextView? {
            didSet {
                // Notify interested parties when the active UnifiedTextView instance changes.
                // Listeners can observe `.unifiedEditorTextViewChanged` to obtain the new text view
                // (object is the UnifiedTextView instance or nil).
                NotificationCenter.default.post(
                    name: .unifiedEditorTextViewChanged,
                    object: textView)

                // Remove any previous selection observer attached to the old text view
                if let old = oldValue {
                    NotificationCenter.default.removeObserver(
                        self,
                        name: NSTextView.didChangeSelectionNotification,
                        object: old)
                }

                // When a new text view attaches, observe its selection changes so we can
                // broadcast selection updates from a single centralized notification.
                if let tv = textView {
                    NotificationCenter.default.addObserver(
                        self,
                        selector: #selector(handleUnifiedTextViewSelectionChanged(_:)),
                        name: NSTextView.didChangeSelectionNotification,
                        object: tv)

                    // Immediately publish the current selection so listeners can initialize.
                    NotificationCenter.default.post(
                        name: .unifiedEditorSelectionChanged,
                        object: tv.selectedRange())
                } else {
                    // Notify listeners that there is no active editor selection
                    NotificationCenter.default.post(
                        name: .unifiedEditorSelectionChanged,
                        object: nil)
                }
            }
        }
        var formatterObserversInstalled = false
        var coordinatorCancellables = Set<AnyCancellable>()
        // Legacy persistent output queue removed; outputs are handled inline by editor components.

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

            // Markdown formatting observers removed — toolbar formatting no longer supported.
            // Previous behavior posted notifications to insert formatting/list/header.
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
            // Legacy persistent output queue removed; nothing to flush here.
        }

        // MARK: - Formatting handlers

        // Markdown formatting handlers were removed when Markdown support was deprecated.

        // Selection change handler forwarded from the live UnifiedTextView instance.
        // Posts `.unifiedEditorSelectionChanged` with the current NSRange selection as the object.
        @objc private func handleUnifiedTextViewSelectionChanged(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else {
                NotificationCenter.default.post(name: .unifiedEditorSelectionChanged, object: nil)
                return
            }
            NotificationCenter.default.post(
                name: .unifiedEditorSelectionChanged, object: tv.selectedRange())
        }

        // MARK: - Output handlers

        // Persistent output handlers removed.
        // Output insertion/clearing is now handled inline by editor components directly
        // without posting notifications. If you need to persist outputs programmatically, use the
        // editor `onTextChange` callback to modify the bound text.
    }
}

// MARK: - UnifiedTextView: single NSTextView subclass that supports multiple modes

private class UnifiedTextView: NSTextView {
    weak var coordinator: EditorContainerView.Coordinator?
    private var mode: EditorFileType = .mufi
    // When false, skip incremental highlighting (useful for performance-sensitive cases)
    var highlightingEnabled: Bool = true
    private var mufiHighlighter: MufiHighlighter?
    private var markdownHighlighter: MarkdownHighlighter?

    override func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            setupCommon()
        }
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupCommon()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Task { @MainActor in
            setupCommon()
        }
    }

    @MainActor private func setupCommon() {
        // Default settings
        isRichText = false
        allowsUndo = true
        isContinuousSpellCheckingEnabled = true
    }

    /// Configure the view for a specific mode.
    func setupForMode(_ fileType: EditorFileType) {
        self.mode = fileType
        
        switch fileType {
        case .mufi:
            // All modes use script/plain editing behavior; preview/highlighting features removed.
            isAutomaticQuoteSubstitutionEnabled = false
            isAutomaticDashSubstitutionEnabled = false
            isAutomaticSpellingCorrectionEnabled = false
            isAutomaticTextReplacementEnabled = false
        case .markdown:
            isAutomaticQuoteSubstitutionEnabled = true
            isAutomaticDashSubstitutionEnabled = true
            isAutomaticSpellingCorrectionEnabled = true
            isAutomaticTextReplacementEnabled = false
        }
        
        // Ensure attributes are cleared (no document highlighting).
        clearAllAttributes()
    }

    // Apply syntax highlighting to the entire document
    private func applyHighlightingWhole() {
        guard let ts = textStorage, highlightingEnabled else { return }
        
        switch mode {
        case .mufi:
            mufiHighlighter?.highlight(in: ts)
        case .markdown:
            markdownHighlighter?.highlight(in: ts)
        }
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

    /// Configure the highlighter fonts to match the provided editor font settings.
    /// This keeps the visual appearance of highlighted text consistent with the editor font.
    func configureHighlighter(baseFontName: String?, baseSize: Double) {
        let theme = coordinator?.themeManager?.currentTheme ?? .ghostWhite
        
        switch mode {
        case .mufi:
            if let highlighter = mufiHighlighter {
                highlighter.updateConfig(theme: theme, baseFontName: baseFontName, baseSize: baseSize)
            } else {
                mufiHighlighter = MufiHighlighter(theme: theme, baseFontName: baseFontName, baseSize: baseSize)
            }
        case .markdown:
            if let highlighter = markdownHighlighter {
                highlighter.updateConfig(theme: theme, baseFontName: baseFontName, baseSize: baseSize)
            } else {
                markdownHighlighter = MarkdownHighlighter(theme: theme, baseFontName: baseFontName, baseSize: baseSize)
            }
        }
        
        if highlightingEnabled {
            applyHighlightingWhole()
        }
    }

    // MARK: - Editing hooks

    override func didChangeText() {
        super.didChangeText()
        if highlightingEnabled {
            applyHighlightingWhole()
        }
    }

    // Toolbar formatting helper removed.

    // Toolbar formatting helper removed.

    // Toolbar formatting helper removed.

    // Override keyDown: markdown-specific behaviors removed; default system handling used.
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
    }

    // Markdown-specific special-key handlers (Enter/Tab/Backspace) have been removed.
    // The editor relies on default system behavior and any higher-level formatting
    // commands driven from toolbars or commands are handled via explicit API calls.
}
