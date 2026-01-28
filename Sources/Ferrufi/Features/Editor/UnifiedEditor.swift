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
import TreeSitterMufi

// Public API: file type / mode
public enum EditorFileType {
    case mufi
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
        .onChange(of: fileType) { _, newMode in
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
        // Make the highlighter use the same base family so token-derived fonts match.
        unifiedTextView.configureHighlighter(
            baseFontName: unifiedTextView.font?.fontName,
            baseSize: themeManager.editorFontSize,
            themeColors: themeManager.currentTheme.colors)
        unifiedTextView.textContainerInset = NSSize(width: 16, height: 16)
        unifiedTextView.isVerticallyResizable = true
        unifiedTextView.isHorizontallyResizable = false
        unifiedTextView.textContainer?.widthTracksTextView = true
        unifiedTextView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)

        // Initial content
        unifiedTextView.string = text

        // Ensure base font is applied to text storage so raw text matches the preview/editor immediately
        if let font = unifiedTextView.font {
            textStorage.addAttribute(
                .font, value: font, range: NSRange(location: 0, length: textStorage.length))
            // Ensure typing attributes inherit the same font so newly typed text matches preview/editor
            unifiedTextView.typingAttributes[.font] = font
        }

        // Apply initial highlighting for Mufi scripts
        unifiedTextView.applyHighlightingWhole()

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

        // Use monospaced font so the editor displays like the Mufi script editor -
        // keep parity with Mufi files for visual consistency.
        let chosenFont: NSFont = themeManager.monospacedNSFont
        textView.font = chosenFont
        // Log the actual NSTextView font and size to aid debugging font parity
        if let f = textView.font {
            print("EditorContainerView: textView font: \(f.fontName) @ \(f.pointSize)pt")
        } else {
            print("EditorContainerView: textView font: <none>")
        }
        // Ensure highlighter uses the chosen font family for Mufi files (pass font name) or default for code
        let highlighterFontName: String? = (fileType == .mufi) ? chosenFont.fontName : nil
        textView.configureHighlighter(
            baseFontName: highlighterFontName, baseSize: themeManager.editorFontSize,
            themeColors: themeManager.currentTheme.colors)
        if let ts = textView.textStorage, let base = textView.font {
            let full = NSRange(location: 0, length: ts.length)
            ts.addAttribute(.font, value: base, range: full)
        }

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

    // --- Lightweight syntax highlighter state ---
    private var highlighterBaseFontName: String? = nil
    private var highlighterBaseSize: Double = 14.0
    private var highlightDelaySeconds: TimeInterval = 0.12
    private var highlightWorkItem: DispatchWorkItem? = nil

    // Token color defaults; will be updated from theme via `configureHighlighter(...)`
    private var keywordColor: NSColor = NSColor.systemBlue
    private var stringColor: NSColor = NSColor.systemGreen
    private var numberColor: NSColor = NSColor.systemOrange
    private var commentColor: NSColor = NSColor.secondaryLabelColor
    private var functionColor: NSColor = NSColor.systemPurple

    // Mufi language spec (loaded from grammars/mufi.lang.json or app bundle)
    private struct MufiLangSpec: Codable {
        let keywords: [String]
        let builtin_functions: [String]
        let integer: String?
        let float: String?
        let string: String?
        let comment: String?
    }

    // Runtime-driven patterns / token lists (default fallbacks kept)
    private var mfKeywords: [String] = []
    private var mfBuiltins: [String] = []
    private var mfIntegerPattern: String = "\\b\\d+\\b"
    private var mfFloatPattern: String = "\\b\\d+\\.\\d+\\b"
    private var mfStringPattern: String = "\"(?:\\\\.|[^\"\\\\])*\""
    private var mfCommentPattern: String = "//.*"

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

        // Attempt to load the Mufi language specification (optional)
        loadMufiLanguageSpec()
    }

    /// Configure the view for a specific mode.
    func setupForMode(_ fileType: EditorFileType) {
        self.mode = fileType
        // All modes use script/plain editing behavior; preview/highlighting features removed.
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        // Ensure attributes are cleared (no document highlighting).
        clearAllAttributes()
    }

    // Load Mufi language specification (if available) to drive highlighting
    private func loadMufiLanguageSpec() {
        // Try to find grammar in app bundle first
        if let url = Bundle.main.url(
            forResource: "mufi.lang", withExtension: "json", subdirectory: "grammars")
        {
            if let data = try? Data(contentsOf: url),
                let spec = try? JSONDecoder().decode(MufiLangSpec.self, from: data)
            {
                mfKeywords = spec.keywords
                mfBuiltins = spec.builtin_functions
                if let f = spec.float { mfFloatPattern = f }
                if let i = spec.integer { mfIntegerPattern = i }
                if let s = spec.string { mfStringPattern = s }
                if let c = spec.comment { mfCommentPattern = c }
            }
            return
        }

        // Development fallback: look in repository path
        let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Ferrufi/grammars/mufi.lang.json")
        if FileManager.default.fileExists(atPath: fallback.path) {
            if let data = try? Data(contentsOf: fallback),
                let spec = try? JSONDecoder().decode(MufiLangSpec.self, from: data)
            {
                mfKeywords = spec.keywords
                mfBuiltins = spec.builtin_functions
                if let f = spec.float { mfFloatPattern = f }
                if let i = spec.integer { mfIntegerPattern = i }
                if let s = spec.string { mfStringPattern = s }
                if let c = spec.comment { mfCommentPattern = c }
            }
        }
    }

    // Apply syntax highlighting to the entire document (simple, regex-based for Mufi)
    fileprivate func applyHighlightingWhole() {
        guard highlightingEnabled, let ts = textStorage else { return }
        let textStr = self.string as NSString
        let fullRange = NSRange(location: 0, length: textStr.length)

        // Try Tree-sitter-based highlighting first (preferred). If not available, fallback
        if let tsTokens = TreeSitterHighlighter.shared.highlightRanges(in: self.string) {
            // Reset attributes and apply base font/foreground
            clearAllAttributes()
            if let baseFont = self.font {
                ts.addAttribute(.font, value: baseFont, range: fullRange)
            }
            ts.addAttribute(
                .foregroundColor, value: self.textColor ?? NSColor.labelColor, range: fullRange)

            // Apply tree-sitter produced tokens
            for (range, kind) in tsTokens {
                guard range.location != NSNotFound, range.length > 0 else { continue }
                let color: NSColor
                switch kind {
                case .comment:
                    color = commentColor
                case .string:
                    color = stringColor
                case .number:
                    color = numberColor
                case .keyword:
                    color = keywordColor
                case .function:
                    color = functionColor
                case .type:
                    color = stringColor  // fallback mapping
                default:
                    color = self.textColor ?? NSColor.textColor
                }
                ts.addAttribute(.foregroundColor, value: color, range: range)
            }
            return
        }

        // Start by clearing attributes and reapplying base font/foreground (regex fallback)
        clearAllAttributes()
        if let baseFont = self.font {
            ts.addAttribute(.font, value: baseFont, range: fullRange)
        }
        ts.addAttribute(
            .foregroundColor, value: self.textColor ?? NSColor.labelColor, range: fullRange)

        // Keep track of ranges that should not be re-colored (strings/comments)
        var protected: [NSRange] = []

        ts.beginEditing()
        defer { ts.endEditing() }

        func applyAndProtect(range: NSRange, color: NSColor) {
            guard range.location != NSNotFound, range.length > 0 else { return }
            ts.addAttribute(.foregroundColor, value: color, range: range)
            protected.append(range)
        }

        do {
            // Comments (use language-specified pattern if available)
            do {
                let commentRe = try NSRegularExpression(
                    pattern: mfCommentPattern + "$", options: [.anchorsMatchLines])
                let commentMatches = commentRe.matches(
                    in: self.string, options: [], range: fullRange)
                for m in commentMatches { applyAndProtect(range: m.range, color: commentColor) }
            } catch {
                // ignore malformed pattern
            }

            // Strings (use language-specified pattern if available)
            do {
                let stringRe = try NSRegularExpression(pattern: mfStringPattern, options: [])
                let stringMatches = stringRe.matches(in: self.string, options: [], range: fullRange)
                for m in stringMatches { applyAndProtect(range: m.range, color: stringColor) }
            } catch {
                // ignore malformed pattern
            }

            // Numbers: floats then integers (use language spec if available)
            do {
                let floatRe = try NSRegularExpression(pattern: mfFloatPattern, options: [])
                let floatMatches = floatRe.matches(in: self.string, options: [], range: fullRange)
                for m in floatMatches {
                    if protected.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) {
                        continue
                    }
                    ts.addAttribute(.foregroundColor, value: numberColor, range: m.range)
                }
            } catch {}

            do {
                let intRe = try NSRegularExpression(pattern: mfIntegerPattern, options: [])
                let intMatches = intRe.matches(in: self.string, options: [], range: fullRange)
                for m in intMatches {
                    if protected.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) {
                        continue
                    }
                    ts.addAttribute(.foregroundColor, value: numberColor, range: m.range)
                }
            } catch {}

            // Keywords (dynamically built from loaded spec)
            if !mfKeywords.isEmpty {
                let escaped = mfKeywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(
                    separator: "|")
                let kwPattern = "\\b(?:" + escaped + ")\\b"
                let kwRe = try NSRegularExpression(pattern: kwPattern, options: [])
                let kwMatches = kwRe.matches(in: self.string, options: [], range: fullRange)
                for m in kwMatches {
                    if protected.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) {
                        continue
                    }
                    ts.addAttribute(.foregroundColor, value: keywordColor, range: m.range)
                }
            }

            // Builtin functions (special highlight) — apply before generic function names
            if !mfBuiltins.isEmpty {
                let escapedBuiltins = mfBuiltins.map { NSRegularExpression.escapedPattern(for: $0) }
                    .joined(separator: "|")
                let builtinPattern = "\\b(?:" + escapedBuiltins + ")\\s*(?=\\()"
                let builtinRe = try NSRegularExpression(pattern: builtinPattern, options: [])
                let builtinMatches = builtinRe.matches(
                    in: self.string, options: [], range: fullRange)
                for m in builtinMatches {
                    let r = m.range(at: 0)
                    if protected.contains(where: { NSIntersectionRange($0, r).length > 0 }) {
                        continue
                    }
                    ts.addAttribute(.foregroundColor, value: functionColor, range: r)
                }
            }

            // Function names (identifier followed by '(') — highlight the identifier only
            let funcRe = try NSRegularExpression(
                pattern: #"\b([A-Za-z_][A-Za-z0-9_]*)\s*(?=\()"#, options: [])
            let funcMatches = funcRe.matches(in: self.string, options: [], range: fullRange)
            for m in funcMatches {
                let r = m.range(at: 1)
                if protected.contains(where: { NSIntersectionRange($0, r).length > 0 }) { continue }
                ts.addAttribute(.foregroundColor, value: functionColor, range: r)
            }
        } catch {
            // If regex fails, skip highlighting (safe failure)
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

    /// Configure the highlighter fonts and theme colors for the lightweight syntax highlighter.
    /// This keeps the visual appearance of highlighted text consistent with the editor font/theme.
    func configureHighlighter(
        baseFontName: String?, baseSize: Double, themeColors: ThemeColors? = nil
    ) {
        highlighterBaseFontName = baseFontName
        highlighterBaseSize = baseSize

        if let colors = themeColors {
            // Use per-theme syntax colors (preferred) with sensible fallbacks
            keywordColor = NSColor(colors.syntaxKeyword)
            stringColor = NSColor(colors.syntaxString)
            numberColor = NSColor(colors.syntaxNumber)
            commentColor = NSColor(colors.syntaxComment)
            functionColor = NSColor(colors.syntaxFunction)
        }
    }

    // MARK: - Editing hooks

    override func didChangeText() {
        super.didChangeText()

        // Debounce highlighting to avoid work on every keystroke.
        guard highlightingEnabled else { return }
        highlightWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.applyHighlightingWhole()
            }
        }
        highlightWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + highlightDelaySeconds, execute: work)

        // Notify coordinator via NotificationCenter callback (textDidChange will call delegate)
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
