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
    // Enable/disable line numbers
    public var lineNumbersEnabled: Bool = true

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
        lineNumbersEnabled: Bool = true,
        onTextChange: ((String) -> Void)? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self._text = text
        self._isEditing = isEditing
        self.fileType = fileType
        self.placeholder = placeholder
        self.highlightingEnabled = highlightingEnabled
        self.lineNumbersEnabled = lineNumbersEnabled
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
                    lineNumbersEnabled: lineNumbersEnabled,
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
        .onChange(of: fileType) { oldMode, newMode in
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
    var lineNumbersEnabled: Bool = true
    var onTextChange: ((String) -> Void)?
    var onSave: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ferrufiApp: FerrufiApp
    @EnvironmentObject private var settings: Settings
    @ObservedObject private var lspService = MufiLSPService.shared

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

        // Line number ruler if enabled
        if lineNumbersEnabled || ferrufiApp.configuration.editor.showLineNumbers {
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

        if lineNumbersEnabled || settings.showLineNumbers {
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
        
        // Apply diagnostics if in Mufi mode
        if fileType == .mufi {
            textView.setDiagnostics(lspService.diagnostics)
        } else {
            textView.setDiagnostics([])
        }
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
        
        private var completionWindow: NSWindow?

        init(
            text: Binding<String>, isEditing: Binding<Bool>, onTextChange: ((String) -> Void)?,
            onSave: (() -> Void)?
        ) {
            self.textBinding = text
            self.isEditingBinding = isEditing
            self.onTextChange = onTextChange
            self.onSave = onSave
            
            super.init()
            setupCompletionObservers()
        }
        
        private func setupCompletionObservers() {
            let lsp = MufiLSPService.shared
            
            lsp.$isCompletionActive
                .receive(on: RunLoop.main)
                .sink { [weak self] active in
                    if active {
                        self?.showCompletionWindow()
                    } else {
                        self?.hideCompletionWindow()
                    }
                }
                .store(in: &coordinatorCancellables)
            
            lsp.$completionItems
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateCompletionWindow()
                }
                .store(in: &coordinatorCancellables)
                
            lsp.$selectedCompletionIndex
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateCompletionWindow()
                }
                .store(in: &coordinatorCancellables)
        }
        
        private func showCompletionWindow() {
            guard let textView = textView, let window = textView.window else { return }
            let lsp = MufiLSPService.shared
            
            if lsp.completionItems.isEmpty {
                hideCompletionWindow()
                return
            }
            
            if completionWindow == nil {
                let win = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
                win.backgroundColor = .clear
                win.hasShadow = true
                win.isOpaque = false
                win.level = .popUpMenu
                completionWindow = win
                window.addChildWindow(win, ordered: .above)
            }
            
            updateCompletionWindow()
            
            // Position precisely at cursor using layoutManager
            let selectedRange = textView.selectedRange()
            guard let layoutManager = textView.layoutManager,
                  let _ = textView.textContainer else { return }
            
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: selectedRange.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let location = layoutManager.location(forGlyphAt: glyphIndex)
            
            // Local rect
            let origin = textView.textContainerOrigin
            let cursorLocalRect = NSRect(
                x: origin.x + location.x,
                y: origin.y + lineRect.origin.y,
                width: 1,
                height: lineRect.height
            )
            
            // Screen coords
            let windowRect = textView.convert(cursorLocalRect, to: nil)
            let screenRect = window.convertToScreen(windowRect)
            
            let winWidth: CGFloat = 320
            let winHeight: CGFloat = min(CGFloat(lsp.completionItems.count * 28 + 8), 240)
            
            // Position exactly below current line
            let winFrame = NSRect(
                x: screenRect.origin.x,
                y: screenRect.origin.y - winHeight,
                width: winWidth,
                height: winHeight
            )
            
            completionWindow?.setFrame(winFrame, display: true)
            completionWindow?.orderFront(nil)
        }
        
        private func updateCompletionWindow() {
            guard let win = completionWindow else { return }
            let lsp = MufiLSPService.shared
            let theme = themeManager ?? ThemeManager.shared
            
            let contentView = MufiCompletionView(
                items: lsp.completionItems,
                selectedIndex: lsp.selectedCompletionIndex,
                onItemSelected: { item in
                    (self.textView as? UnifiedTextView)?.performCompletion(item)
                }
            )
            .environmentObject(theme)
            
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = NSRect(x: 0, y: 0, width: win.frame.width, height: win.frame.height)
            win.contentView = hostingView
        }
        
        private func hideCompletionWindow() {
            if let win = completionWindow {
                win.parent?.removeChildWindow(win)
                win.orderOut(nil)
                completionWindow = nil
            }
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
    private var highlighter: MufiHighlighter? // Placeholder for future use
    private var mufiHighlighter: MufiHighlighter?
    private var markdownHighlighter: MarkdownHighlighter?
    private var computeHighlighter: MufiComputeHighlighter?
    private var shouldHighlightWhole: Bool = true

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
        // Default settings for code editing
        isRichText = false
        allowsUndo = true
        isContinuousSpellCheckingEnabled = false
        
        // Disable aggressive macOS smart features
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        
        // Turn off all smart insertions
        enabledTextCheckingTypes = 0
        
        // Enable mouse tracking for hover hints
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in self.trackingAreas {
            self.removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        let point = self.convert(event.locationInWindow, from: nil)
        
        // Ensure point is within text container
        guard let container = textContainer, let lm = layoutManager else { return }
        let charIndex = lm.characterIndex(for: point, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
        
        guard let ts = textStorage else { return }
        
        // 1. Check diagnostics
        let diagnostics = MufiLSPService.shared.diagnostics
        for diag in diagnostics {
            let range = ts.nsRange(from: diag.range)
            if NSLocationInRange(charIndex, range) {
                if self.toolTip != diag.message {
                    self.toolTip = diag.message
                }
                return
            }
        }
        
        // 2. Check native hover (LSP)
        if mode == .mufi {
            let pos = ts.mufiPosition(from: charIndex)
            Task {
                if let info = await MufiLSPService.shared.getHoverInfo(line: pos.line, column: pos.column) {
                    await MainActor.run {
                        let tip = "\(info.name): \(info.typeName ?? "unknown")\n\(info.docString ?? "")"
                        if self.toolTip != tip {
                            self.toolTip = tip
                        }
                    }
                } else {
                    await MainActor.run {
                        if self.toolTip != nil {
                            self.toolTip = nil
                        }
                    }
                }
            }
        } else {
            self.toolTip = nil
        }
    }

    /// Configure the view for a specific mode.
    func setupForMode(_ fileType: EditorFileType) {
        if self.mode == fileType { return }
        self.mode = fileType
        
        switch fileType {
        case .mufi:
            // All modes use script/plain editing behavior; preview/highlighting features removed.
            isAutomaticQuoteSubstitutionEnabled = false
            isAutomaticDashSubstitutionEnabled = false
            isAutomaticTextReplacementEnabled = false
            isAutomaticSpellingCorrectionEnabled = false
        case .markdown:
            isAutomaticQuoteSubstitutionEnabled = true
            isAutomaticDashSubstitutionEnabled = true
            isAutomaticTextReplacementEnabled = false
            isAutomaticSpellingCorrectionEnabled = true
        }
        
        // Ensure attributes are cleared only on mode change
        clearAllAttributes()
    }

    /// Update diagnostic squiggles based on LSP results
    @MainActor func setDiagnostics(_ diagnostics: [MufiDiagnostic]) {
        guard let lm = layoutManager, let ts = textStorage else { return }
        
        // Clear existing diagnostic attributes
        let fullRange = NSRange(location: 0, length: ts.length)
        lm.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)
        lm.removeTemporaryAttribute(.underlineColor, forCharacterRange: fullRange)
        
        for diagnostic in diagnostics {
            let range = ts.nsRange(from: diagnostic.range)
            if range.location == NSNotFound || range.location + range.length > ts.length { continue }
            
            let color = (diagnostic.severity == .error) ? NSColor.systemRed : NSColor.systemOrange
            
            // Apply thick wavy/dotted underline for errors
            lm.addTemporaryAttribute(.underlineStyle, 
                                   value: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue, 
                                   forCharacterRange: range)
            lm.addTemporaryAttribute(.underlineColor, value: color, forCharacterRange: range)
        }
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
            
            // GPU highlighter disabled to prevent keyword conflicts
            computeHighlighter = nil
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
            if shouldHighlightWhole {
                applyHighlightingWhole()
                shouldHighlightWhole = false
            }
        } else {
            applyHighlightingIncremental()
        }
    }
    
    private func applyHighlightingIncremental() {
        guard let ts = textStorage, highlightingEnabled else { return }
        
        // Get the edited range
        let editedRange = self.rangeForUserTextChange
        if editedRange.location == NSNotFound {
            applyHighlightingWhole()
            return
        }
        
        // Expand range to include full lines for context
        let nsString = ts.string as NSString
        let lineRange = nsString.lineRange(for: editedRange)
        
        // Dispatch to appropriate highlighter with specific range
        switch mode {
        case .mufi:
            mufiHighlighter?.highlight(in: ts, range: lineRange)
        case .markdown:
            markdownHighlighter?.highlight(in: ts, range: lineRange)
        }
    }

    // Override keyDown: handle Enter and Completion navigation
    override func keyDown(with event: NSEvent) {
        let lsp = MufiLSPService.shared
        
        if lsp.isCompletionActive {
            switch event.keyCode {
            case 125: // Down
                lsp.moveCompletionSelectionDown()
                return
            case 126: // Up
                lsp.moveCompletionSelectionUp()
                return
            case 36, 48: // Enter or Tab
                if let selected = lsp.selectedCompletion {
                    performCompletion(selected)
                }
                return
            case 53: // Escape
                lsp.cancelCompletion()
                return
            default:
                break
            }
        }
        
        // Handle Enter for auto-indentation
        if event.keyCode == 36 {
            handleEnterKey()
            return
        }
        
        super.keyDown(with: event)
        
        // Trigger completion on alpha-numeric or dot
        if mode == .mufi {
            handleCompletionTrigger(event)
        }
    }
    
    private func handleEnterKey() {
        let selectedRange = self.selectedRange()
        let nsString = self.string as NSString
        
        // Find current line
        let lineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let currentLine = nsString.substring(with: lineRange)
        
        // Get indentation
        var indentation = ""
        for char in currentLine {
            if char == " " || char == "\t" {
                indentation.append(char)
            } else {
                break
            }
        }
        
        // Extra indent after block start (detect { or :)
        let trimmed = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
        var extraIndent = ""
        if trimmed.hasSuffix("{}") || trimmed.hasSuffix(":") {
            extraIndent = "    "
        }
        
        let replacement = "\n" + indentation + extraIndent
        if self.shouldChangeText(in: selectedRange, replacementString: replacement) {
            self.insertText(replacement, replacementRange: selectedRange)
            self.didChangeText()
        }
    }
    
    private func handleCompletionTrigger(_ event: NSEvent) {
        guard let chars = event.characters, !chars.isEmpty else { return }
        let char = chars.first!
        
        // Trigger on letters, numbers, underscore, or dot
        if char.isLetter || char.isNumber || char == "_" || char == "." {
            let offset = self.selectedRange().location
            let pos = self.textStorage?.mufiPosition(from: offset) ?? MufiPosition(line: 1, column: 1)
            let prefix = getCurrentWordPrefix()
            MufiLSPService.shared.triggerCompletions(line: pos.line, column: pos.column, prefix: prefix)
        } else if char.isWhitespace || event.keyCode == 51 || event.keyCode == 53 { // Space, Delete, Esc
            MufiLSPService.shared.cancelCompletion()
        }
    }
    
    private func getCurrentWordPrefix() -> String {
        guard let ts = textStorage else { return "" }
        let offset = self.selectedRange().location
        let nsString = ts.string as NSString
        
        var start = offset
        while start > 0 {
            let range = NSRange(location: start - 1, length: 1)
            let char = nsString.substring(with: range)
            if char.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil && char != "." {
                break
            }
            start -= 1
        }
        
        return nsString.substring(with: NSRange(location: start, length: offset - start))
    }
    
    internal func performCompletion(_ item: MufiCompletionItem) {
        let lsp = MufiLSPService.shared
        
        // Find the word prefix to replace
        let currentOffset = self.selectedRange().location
        let nsString = self.string as NSString
        
        // Search backwards for the start of the current word
        var wordStart = currentOffset
        while wordStart > 0 {
            let range = NSRange(location: wordStart - 1, length: 1)
            let char = nsString.substring(with: range)
            if char.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil && char != "." {
                break
            }
            wordStart -= 1
        }
        
        // If we matched a dot, start after the last dot
        let rangeForDotSearch = NSRange(location: wordStart, length: currentOffset - wordStart)
        let wordForDotSearch = nsString.substring(with: rangeForDotSearch)
        if let dotRange = wordForDotSearch.range(of: ".", options: .backwards) {
            let dotIndex = wordForDotSearch.distance(from: wordForDotSearch.startIndex, to: dotRange.lowerBound)
            wordStart += dotIndex + 1
        }
        
        let replacementRange = NSRange(location: wordStart, length: currentOffset - wordStart)
        
        if self.shouldChangeText(in: replacementRange, replacementString: item.name) {
            self.breakUndoCoalescing()
            self.replaceCharacters(in: replacementRange, with: item.name)
            self.didChangeText()
        }
        
        lsp.cancelCompletion()
    }

    // Markdown-specific special-key handlers (Enter/Tab/Backspace) have been removed.
    // The editor relies on default system behavior and any higher-level formatting
    // commands driven from toolbars or commands are handled via explicit API calls.
}

// MARK: - LSP Helpers
extension NSTextStorage {
    func nsRange(from mufiRange: MufiRange) -> NSRange {
        let start = offset(from: mufiRange.start)
        let end = offset(from: mufiRange.end)
        
        guard start != NSNotFound, end != NSNotFound, end >= start else {
            return NSRange(location: NSNotFound, length: 0)
        }
        
        return NSRange(location: start, length: end - start)
    }
    
    private func offset(from pos: MufiPosition) -> Int {
        let string = self.string as NSString
        var currentLine: UInt32 = 1
        var currentOffset = 0
        
        // Iterate through lines to find the correct line
        // Note: This is a simple implementation. For very large files, a line-index map would be better.
        let lines = string.components(separatedBy: "\n")
        
        for line in lines {
            if currentLine == pos.line {
                // Found the line, now add the column offset
                // LSP columns are typically 0-based or 1-based?
                // Assuming libmufiz uses 1-based lines and 1-based columns based on common patterns.
                let columnOffset = Int(pos.column) - 1
                if columnOffset >= 0 && columnOffset <= line.utf16.count {
                    return currentOffset + columnOffset
                } else if columnOffset > line.utf16.count {
                    return currentOffset + line.utf16.count // End of line
                } else {
                    return currentOffset
                }
            }
            
            currentOffset += line.utf16.count + 1 // +1 for the \n
            currentLine += 1
        }
        
        return NSNotFound
    }
    
    func mufiPosition(from offset: Int) -> MufiPosition {
        let string = self.string as NSString
        guard offset <= string.length else { return MufiPosition(line: 1, column: 1) }
        
        var lineCount: UInt32 = 1
        var lastLineOffset = 0
        
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byLines) { substring, range, enclosingRange, stop in
            if offset >= range.location && offset <= range.location + range.length {
                // Found the line
                let _ = UInt32(offset - range.location) + 1
                stop.pointee = true
                lastLineOffset = -1 // Mark as found
            } else if offset > range.location + range.length {
                lineCount += 1
                lastLineOffset = range.location + range.length + 1
            }
        }
        
        // If it's at the very end or after the last newline
        if lastLineOffset != -1 {
            let column = UInt32(offset - lastLineOffset) + 1
            return MufiPosition(line: lineCount, column: column)
        }
        
        return MufiPosition(line: lineCount, column: 1) // Should have been caught in loop
    }
}