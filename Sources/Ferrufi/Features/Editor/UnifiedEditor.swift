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
                .id(
                    "\(settings.showLineNumbers)-\(settings.wordWrap)-\(settings.fontFamily)-\(settings.fontSize)-\(settings.lineHeight)"
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

            unifiedTextView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

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
                textView.textContainer?.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
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
                    object: textView,
                    userInfo: nil)

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
                        object: tv.selectedRange(),
                        userInfo: nil)
                } else {
                    // Notify listeners that there is no active editor selection
                    NotificationCenter.default.post(
                        name: .unifiedEditorSelectionChanged,
                        object: nil,
                        userInfo: nil)
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
                let win = NSWindow(
                    contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
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
                textView.textContainer != nil
            else { return }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: selectedRange.location)
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex, effectiveRange: nil)
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
                    self.textView?.performCompletion(item)
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

            if textView.mode == .mufi {
                // If the last character was a newline, force analysis
                let force = newText.hasSuffix("\n")
                MufiLSPService.shared.documentChanged(filename: "editor.mufi", source: newText, force: force)
            }
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
                NotificationCenter.default.post(name: .unifiedEditorSelectionChanged, object: nil, userInfo: nil)
                return
            }
            NotificationCenter.default.post(
                name: .unifiedEditorSelectionChanged, object: tv.selectedRange(), userInfo: nil)
        }

        // MARK: - Output handlers

        // Persistent output handlers removed.
        // Output insertion/clearing is now handled inline by editor components directly
        // without posting notifications. If you need to persist outputs programmatically, use the
        // editor `onTextChange` callback to modify the bound text.

        // MARK: - Diagnostic Window

        private var diagnosticWindow: NSWindow?

        func showDiagnosticWindow(
            for diagnostics: [MufiDiagnostic], atDiagnosticRange range: NSRange
        ) {
            guard let textView = textView, let window = textView.window else { return }
            guard let layoutManager = textView.layoutManager,
                let _ = textView.textContainer
            else { return }
            let theme = themeManager ?? ThemeManager.shared

            if diagnosticWindow == nil {
                let win = NSWindow(
                    contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
                win.backgroundColor = .clear
                win.hasShadow = true
                win.isOpaque = false
                win.level = .floating
                diagnosticWindow = win
                window.addChildWindow(win, ordered: .above)
            }

            guard let win = diagnosticWindow else { return }

            // Position at the diagnostic location (similar to autocomplete menu)
            print("🎯 Positioning diagnostic window at NSRange(\(range.location), \(range.length))")

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: range, actualCharacterRange: nil)
            let glyphIndex = glyphRange.location
            print("   Glyph index: \(glyphIndex)")

            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex, effectiveRange: nil)
            let location = layoutManager.location(forGlyphAt: glyphIndex)
            print("   Line rect: \(lineRect)")
            print("   Location in line: \(location)")

            // Local rect
            let origin = textView.textContainerOrigin
            let diagnosticLocalRect = NSRect(
                x: origin.x + location.x,
                y: origin.y + lineRect.origin.y,
                width: 1,
                height: lineRect.height
            )
            print("   Local rect: \(diagnosticLocalRect)")

            // Screen coords
            let windowRect = textView.convert(diagnosticLocalRect, to: nil)
            let screenRect = window.convertToScreen(windowRect)
            print("   Screen rect: \(screenRect)")

            let contentView = VStack(alignment: .leading, spacing: 0) {
                ForEach(diagnostics, id: \.id) { diag in
                    HStack(spacing: 8) {
                        // SF Symbol icon with colored background (matching autocomplete style)
                        Image(
                            systemName: diag.severity == .error
                                ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 16, height: 16)
                        .background(
                            (diag.severity == .error ? Color.red : Color.orange).opacity(0.2)
                        )
                        .foregroundColor(diag.severity == .error ? Color.red : Color.orange)
                        .cornerRadius(0)

                        // Message in monospaced font (matching autocomplete)
                        Text(diag.message)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(theme.currentTheme.colors.foreground)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(theme.currentTheme.colors.backgroundSecondary)
            .padding(0)
            .cornerRadius(0)
            .overlay(
                Rectangle()
                    .stroke(theme.currentTheme.colors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)

            let hostingView = NSHostingView(rootView: contentView.environmentObject(theme))
            let rowHeight: CGFloat = 28  // Match autocomplete row height
            let size = CGSize(
                width: 320, height: min(CGFloat(diagnostics.count) * rowHeight + 8, 240))
            hostingView.frame = NSRect(origin: .zero, size: size)

            // Position below the diagnostic line (like autocomplete)
            let winFrame = NSRect(
                x: screenRect.origin.x,
                y: screenRect.origin.y - size.height,
                width: size.width,
                height: size.height
            )

            win.contentView = hostingView
            win.setFrame(winFrame, display: true)
            win.orderFront(nil)
        }

        func hideDiagnosticWindow() {
            if let win = diagnosticWindow {
                win.parent?.removeChildWindow(win)
                win.orderOut(nil)
                diagnosticWindow = nil
            }
        }

        // MARK: - Hover Window

        private var hoverWindow: NSWindow?

        func showHoverWindow(for item: MufiCompletionItem, at range: NSRange) {
            guard let textView = textView, let window = textView.window else { return }
            guard let layoutManager = textView.layoutManager else { return }
            let theme = themeManager ?? ThemeManager.shared

            if hoverWindow == nil {
                let win = NSWindow(
                    contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
                win.backgroundColor = .clear
                win.hasShadow = true
                win.isOpaque = false
                win.level = .floating
                hoverWindow = win
                window.addChildWindow(win, ordered: .above)
            }

            guard let win = hoverWindow else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let location = layoutManager.location(forGlyphAt: glyphRange.location)

            let origin = textView.textContainerOrigin
            let localRect = NSRect(x: origin.x + location.x, y: origin.y + lineRect.origin.y, width: 1, height: lineRect.height)
            let windowRect = textView.convert(localRect, to: nil)
            let screenRect = window.convertToScreen(windowRect)

            let contentView = VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    if let type = item.typeName {
                        Text(":")
                            .foregroundColor(.secondary)
                        Text(type)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(theme.currentTheme.colors.accent)
                    }
                }
                
                if let docs = item.docString {
                    Divider()
                    Text(docs)
                        .font(.system(size: 11))
                        .foregroundColor(theme.currentTheme.colors.foregroundSecondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(theme.currentTheme.colors.backgroundSecondary)
            .overlay(Rectangle().stroke(theme.currentTheme.colors.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)

            let hostingView = NSHostingView(rootView: contentView.environmentObject(theme))
            let size = hostingView.fittingSize
            hostingView.frame = NSRect(origin: .zero, size: size)

            let winFrame = NSRect(x: screenRect.origin.x, y: screenRect.origin.y + 20, width: size.width, height: size.height)
            win.contentView = hostingView
            win.setFrame(winFrame, display: true)
            win.orderFront(nil)
        }

        func hideHoverWindow() {
            if let win = hoverWindow {
                win.parent?.removeChildWindow(win)
                win.orderOut(nil)
                hoverWindow = nil
            }
        }
    }
}

// MARK: - UnifiedTextView: single NSTextView subclass that supports multiple modes

private class UnifiedTextView: NSTextView {
    weak var coordinator: EditorContainerView.Coordinator?
    var mode: EditorFileType = .mufi
    // When false, skip incremental highlighting (useful for performance-sensitive cases)
    var highlightingEnabled: Bool = true
    private var highlighter: MufiHighlighter?  // Placeholder for future use
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

        // Listen for navigation requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigateToRange(_:)),
            name: .editorNavigateToRange,
            object: nil)

        // Enable mouse tracking for hover hints
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited,
        ]
        let trackingArea = NSTrackingArea(
            rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleNavigateToRange(_ notification: Notification) {
        guard let range = notification.object as? MufiRange, let ts = textStorage else { return }

        let nsRange = ts.nsRange(from: range)
        if nsRange.location != NSNotFound {
            self.setSelectedRange(nsRange)
            self.scrollRangeToVisible(nsRange)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in self.trackingAreas {
            self.removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited,
        ]
        let trackingArea = NSTrackingArea(
            rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        let point = self.convert(event.locationInWindow, from: nil)

        // Ensure point is within text container
        guard let container = textContainer, let lm = layoutManager else { return }

        // Adjust for text container inset (important for accurate hit testing)
        let inset = self.textContainerInset
        let adjustedPoint = NSPoint(x: point.x - inset.width, y: point.y - inset.height)

        let charIndex = lm.characterIndex(
            for: adjustedPoint, in: container, fractionOfDistanceBetweenInsertionPoints: nil)

        guard let ts = textStorage else { return }

        // 1. Check diagnostics - use cached (fixed) diagnostics instead of raw LSP diagnostics
        print(
            "🖱️ Mouse moved to point: \(point), adjusted: \(adjustedPoint), charIndex: \(charIndex)")
        var hoveredDiagnostics: [MufiDiagnostic] = []

        for diag in cachedDiagnostics {
            let range = ts.nsRange(from: diag.range)
            print(
                "   Checking diagnostic range: \(range.location)-\(range.location + range.length)")
            if range.location != NSNotFound && NSLocationInRange(charIndex, range) {
                print("   ✅ Found hovered diagnostic!")
                hoveredDiagnostics.append(diag)
            }
        }

        if !hoveredDiagnostics.isEmpty {
            // Show diagnostic window at the diagnostic's text position (not mouse position)
            let firstDiagRange = ts.nsRange(from: hoveredDiagnostics[0].range)
            print(
                "🖱️ HOVER: Showing diagnostic at range \(firstDiagRange.location)-\(firstDiagRange.location + firstDiagRange.length)"
            )
            print(
                "   Diagnostic: '\(hoveredDiagnostics[0].message)' at line \(hoveredDiagnostics[0].range.start.line)"
            )
            coordinator?.showDiagnosticWindow(
                for: hoveredDiagnostics, atDiagnosticRange: firstDiagRange)
            // Ensure system tooltips don't show
            self.toolTip = nil
            return
        } else {
            coordinator?.hideDiagnosticWindow()
        }

        // 2. Check native hover (LSP)
        if mode == .mufi {
            let pos = ts.mufiPosition(from: charIndex)
            Task {
                if let info = await MufiLSPService.shared.getHoverInfo(
                    line: pos.line, column: pos.column)
                {
                    await MainActor.run {
                        // Find range of word at cursor
                        let ns = ts.string as NSString
                        var wordRange = NSRange(location: charIndex, length: 0)
                        if charIndex < ns.length {
                            // Simple word range detection
                            var start = charIndex
                            while start > 0 {
                                let r = NSRange(location: start - 1, length: 1)
                                if ns.substring(with: r).rangeOfCharacter(from: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "_"))) != nil { break }
                                start -= 1
                            }
                            var end = charIndex
                            while end < ns.length {
                                let r = NSRange(location: end, length: 1)
                                if ns.substring(with: r).rangeOfCharacter(from: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "_"))) != nil { break }
                                end += 1
                            }
                            wordRange = NSRange(location: start, length: end - start)
                        }
                        
                        coordinator?.showHoverWindow(for: info, at: wordRange)
                    }
                } else {
                    await MainActor.run {
                        coordinator?.hideHoverWindow()
                    }
                }
            }
        } else {
            coordinator?.hideHoverWindow()
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

    /// Cache the current diagnostics so we can re-apply them after highlighting
    private var cachedDiagnostics: [MufiDiagnostic] = []

    /// Update diagnostic squiggles based on LSP results
    @MainActor func setDiagnostics(_ diagnostics: [MufiDiagnostic]) {
        // Avoid redundant updates if diagnostics haven't changed
        if diagnostics.count == cachedDiagnostics.count {
            let matches = zip(diagnostics, cachedDiagnostics).allSatisfy { new, old in
                new.range == old.range && new.message == old.message && new.severity == old.severity
            }
            if matches { return }
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("⚡ setDiagnostics CALLED with \(diagnostics.count) diagnostic(s)")

        // Fix diagnostic positions for known C runtime bugs
        let fixedDiagnostics = diagnostics.map { fixDiagnosticPosition($0) }

        // Cache diagnostics so highlighting can re-apply them
        cachedDiagnostics = fixedDiagnostics

        applyDiagnosticUnderlines(fixedDiagnostics)

        if fixedDiagnostics.isEmpty {
            // No diagnostics - hide any existing tooltip
            coordinator?.hideDiagnosticWindow()
        }
    }

    /// Fix diagnostic positions for known C runtime bugs
    /// The C runtime sometimes reports errors at the wrong line (e.g., missing semicolon errors
    /// are reported at the next statement instead of where the semicolon is actually missing)
    @MainActor private func fixDiagnosticPosition(_ diagnostic: MufiDiagnostic) -> MufiDiagnostic {
        guard let ts = textStorage else { return diagnostic }

        // Check if this is a "missing semicolon" error
        if diagnostic.message.contains("Expect ';'") || diagnostic.message.contains("Expected ';'")
        {
            print("🔧 Fixing position for semicolon error: '\(diagnostic.message)'")

            // Get the reported line
            let reportedRange = ts.nsRange(from: diagnostic.range)
            guard reportedRange.location != NSNotFound else { return diagnostic }

            // Search backwards for the actual location (previous non-empty line)
            let string = ts.string as NSString
            let lines = string.components(separatedBy: "\n")
            let reportedLine = Int(diagnostic.range.start.line)

            // Look backwards for a non-empty line
            for lineIndex in stride(
                from: reportedLine - 1, through: max(0, reportedLine - 5), by: -1)
            {
                if lineIndex >= 0 && lineIndex < lines.count {
                    let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
                    // Check if line is non-empty and doesn't end with semicolon
                    if !line.isEmpty && !line.hasSuffix(";") && !line.hasSuffix("{")
                        && !line.hasPrefix("//")
                    {
                        print("   Found likely error location at line \(lineIndex): '\(line)'")

                        // Calculate the position at the end of this line
                        // Extend backwards to cover at least the last word/token for visibility
                        let lineLength = line.utf16.count
                        let startCol = max(0, lineLength - 3)  // Underline last 3 chars or the whole line
                        let newRange = MufiRange(
                            start: MufiPosition(
                                line: UInt32(lineIndex), column: UInt32(startCol)),
                            end: MufiPosition(line: UInt32(lineIndex), column: UInt32(lineLength))
                        )

                        print(
                            "   Fixed: line \(diagnostic.range.start.line) → line \(lineIndex), range: \(startCol)-\(lineLength)"
                        )
                        return MufiDiagnostic(
                            range: newRange, severity: diagnostic.severity,
                            message: diagnostic.message)
                    }
                }
            }
        }

        return diagnostic
    }

    /// Actually apply the diagnostic underlines to the text using PERMANENT attributes
    @MainActor private func applyDiagnosticUnderlines(_ diagnostics: [MufiDiagnostic]) {
        guard let ts = textStorage else {
            print("⚠️ applyDiagnosticUnderlines: textStorage is nil")
            return
        }

        let lineCount = (ts.string as NSString).components(separatedBy: "\n").count
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if diagnostics.count > 0 {
            print("🎨 🎨 🎨 APPLYING \(diagnostics.count) RED SQUIGGLES 🎨 🎨 🎨")
        } else {
            print("🎨 applyDiagnosticUnderlines: Clearing all squiggles (0 diagnostics)")
        }
        print("   Document: \(lineCount) lines, \(ts.length) chars)")

        // Use PERMANENT attributes on textStorage instead of temporary on layoutManager
        ts.beginEditing()

        // Clear existing diagnostic attributes from entire document
        let fullRange = NSRange(location: 0, length: ts.length)
        ts.removeAttribute(.underlineStyle, range: fullRange)
        ts.removeAttribute(.underlineColor, range: fullRange)

        for (index, diagnostic) in diagnostics.enumerated() {
            let range = ts.nsRange(from: diagnostic.range)

            print(
                "  [\(index)] \(diagnostic.severity): '\(diagnostic.message)' at \(diagnostic.range.start.line):\(diagnostic.range.start.column)-\(diagnostic.range.end.line):\(diagnostic.range.end.column)"
            )
            print("    → NSRange(\(range.location), \(range.length))")

            // Skip if location is invalid
            if range.location == NSNotFound {
                print("    ⚠️ Invalid range (NSNotFound), skipping diagnostic")
                continue
            }

            // Skip if document is empty
            if ts.length == 0 {
                print("    ⚠️ Cannot apply diagnostic to empty document")
                continue
            }

            // For zero-length ranges or EOF diagnostics, extend to at least one character
            var displayRange = range
            if range.length == 0 || range.location >= ts.length {
                if range.location >= ts.length {
                    // At or past end of document - underline the last character
                    displayRange = NSRange(location: ts.length - 1, length: 1)
                    print(
                        "    → EOF diagnostic: Extended to last char NSRange(\(displayRange.location), \(displayRange.length))"
                    )
                } else if range.location < ts.length {
                    // Mid-document zero-length - underline the character at this position
                    displayRange = NSRange(location: range.location, length: 1)
                    print(
                        "    → Extended zero-length range to NSRange(\(displayRange.location), \(displayRange.length))"
                    )
                }
            } else if range.location + range.length > ts.length {
                // Range extends past end - clamp to document end
                displayRange = NSRange(location: range.location, length: ts.length - range.location)
                print(
                    "    → Clamped range extending past EOF to NSRange(\(displayRange.location), \(displayRange.length))"
                )
            }

            let color = (diagnostic.severity == .error) ? NSColor.systemRed : NSColor.systemOrange

            // Apply thick wavy/dotted underline using PERMANENT attributes
            let style = NSUnderlineStyle.thick.union(.patternDot)
            ts.addAttribute(
                .underlineStyle, value: NSNumber(value: style.rawValue), range: displayRange)
            ts.addAttribute(.underlineColor, value: color, range: displayRange)

            print("    ✅ ✅ ✅ APPLIED \(color == .systemRed ? "RED" : "ORANGE") SQUIGGLE ✅ ✅ ✅")
        }

        ts.endEditing()

        // Force redisplay
        self.needsDisplay = true
        if diagnostics.count > 0 {
            print("🎨 🎨 🎨 SQUIGGLES APPLIED! FORCED REDISPLAY! 🎨 🎨 🎨")
            print("   YOU SHOULD NOW SEE RED/ORANGE UNDERLINES IN THE EDITOR!")
        } else {
            print("✅ applyDiagnosticUnderlines: Complete, cleared all squiggles")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    // Apply syntax highlighting to the entire document
    private func applyHighlightingWhole() {
        guard let ts = textStorage, highlightingEnabled else { return }

        print("🎨 HIGHLIGHTING: Running applyHighlightingWhole()")

        switch mode {
        case .mufi:
            mufiHighlighter?.highlight(in: ts)
        case .markdown:
            markdownHighlighter?.highlight(in: ts)
        }

        // Re-apply diagnostics AFTER highlighting to ensure underlines stay visible
        if !cachedDiagnostics.isEmpty {
            print(
                "🔄 RE-APPLYING \(cachedDiagnostics.count) DIAGNOSTIC UNDERLINES AFTER HIGHLIGHTING")
            applyDiagnosticUnderlines(cachedDiagnostics)
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
                highlighter.updateConfig(
                    theme: theme, baseFontName: baseFontName, baseSize: baseSize)
            } else {
                mufiHighlighter = MufiHighlighter(
                    theme: theme, baseFontName: baseFontName, baseSize: baseSize)
            }

            // GPU highlighter disabled to prevent keyword conflicts
            computeHighlighter = nil
        case .markdown:
            if let highlighter = markdownHighlighter {
                highlighter.updateConfig(
                    theme: theme, baseFontName: baseFontName, baseSize: baseSize)
            } else {
                markdownHighlighter = MarkdownHighlighter(
                    theme: theme, baseFontName: baseFontName, baseSize: baseSize)
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

        print("🎨 HIGHLIGHTING: Running applyHighlightingIncremental()")

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

        // Re-apply diagnostics AFTER incremental highlighting
        if !cachedDiagnostics.isEmpty {
            print(
                "🔄 RE-APPLYING \(cachedDiagnostics.count) DIAGNOSTIC UNDERLINES AFTER INCREMENTAL HIGHLIGHTING"
            )
            applyDiagnosticUnderlines(cachedDiagnostics)
        }
    }

    // Override menu for Go to Definition
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        
        menu.addItem(.separator())
        let goToDefItem = NSMenuItem(title: "Go to Definition", action: #selector(goToDefinition(_:)), keyEquivalent: "")
        goToDefItem.target = self
        menu.addItem(goToDefItem)
        
        return menu
    }

    @objc private func goToDefinition(_ sender: Any?) {
        let range = self.selectedRange()
        let pos = self.textStorage?.mufiPosition(from: range.location) ?? MufiPosition(line: 0, column: 0)
        
        Task {
            if let defRange = await MufiLSPService.shared.getDefinitionRange(
                line: pos.line, column: pos.column, source: self.string) {
                await MainActor.run {
                    NotificationCenter.default.post(name: .editorNavigateToRange, object: defRange, userInfo: nil)
                }
            }
        }
    }

    // Override keyDown: handle Enter, Completion navigation and F12
    override func keyDown(with event: NSEvent) {
        let lsp = MufiLSPService.shared

        // F12 for Go to Definition (keyCode 111)
        if event.keyCode == 111 {
            goToDefinition(nil)
            return
        }
        
        if lsp.isCompletionActive {
            switch event.keyCode {
            case 125:  // Down
                lsp.moveCompletionSelectionDown()
                return
            case 126:  // Up
                lsp.moveCompletionSelectionUp()
                return
            case 36, 48:  // Enter or Tab
                if let selected = lsp.selectedCompletion {
                    performCompletion(selected)
                }
                return
            case 53:  // Escape
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
        let lineRange = nsString.lineRange(
            for: NSRange(location: selectedRange.location, length: 0))
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
            let pos =
                self.textStorage?.mufiPosition(from: offset) ?? MufiPosition(line: 1, column: 1)
            let prefix = getCurrentWordPrefix()
            MufiLSPService.shared.triggerCompletions(
                line: pos.line, column: pos.column, prefix: prefix)
        } else if char.isWhitespace || event.keyCode == 51 || event.keyCode == 53 {  // Space, Delete, Esc
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
            if char.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
                && char != "."
            {
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
            if char.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil
                && char != "."
            {
                break
            }
            wordStart -= 1
        }

        // If we matched a dot, start after the last dot
        let rangeForDotSearch = NSRange(location: wordStart, length: currentOffset - wordStart)
        let wordForDotSearch = nsString.substring(with: rangeForDotSearch)
        if let dotRange = wordForDotSearch.range(of: ".", options: .backwards) {
            let dotIndex = wordForDotSearch.distance(
                from: wordForDotSearch.startIndex, to: dotRange.lowerBound)
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
        var currentLine: UInt32 = 0
        var currentOffset = 0

        // Iterate through lines to find the correct line
        // Note: This is a simple implementation. For very large files, a line-index map would be better.
        let lines = string.components(separatedBy: "\n")

        print("    🔍 Converting position line:\(pos.line) col:\(pos.column) to offset")
        print("       Document has \(lines.count) lines")

        for (_, line) in lines.enumerated() {
            if currentLine == pos.line {
                // Found the line, now add the column offset
                // LSP columns are typically 0-based.
                // Switching to 0-based indexing to match standard LSP and fix missing indicators.
                let columnOffset = Int(pos.column)
                print("       Found line \(currentLine) at offset \(currentOffset): '\(line)'")
                print("       Requested column: \(columnOffset), line length: \(line.utf16.count)")

                if columnOffset >= 0 && columnOffset <= line.utf16.count {
                    let finalOffset = currentOffset + columnOffset
                    print("       → Final offset: \(finalOffset)")
                    return finalOffset
                } else if columnOffset > line.utf16.count {
                    let finalOffset = currentOffset + line.utf16.count
                    print("       → Column past EOL, clamping to: \(finalOffset)")
                    return finalOffset
                } else {
                    print("       → Invalid column, returning line start: \(currentOffset)")
                    return currentOffset
                }
            }

            currentOffset += line.utf16.count + 1  // +1 for the \n
            currentLine += 1
        }

        // Position is past end of document (EOF diagnostic)
        // Clamp to document end instead of returning NSNotFound
        if pos.line >= currentLine && string.length > 0 {
            print(
                "    📍 EOF diagnostic: line \(pos.line) >= document line count \(currentLine), clamping to doc end (\(string.length))"
            )
            return string.length
        }

        print("       ⚠️ Line \(pos.line) not found, returning NSNotFound")
        return NSNotFound
    }

    func mufiPosition(from offset: Int) -> MufiPosition {
        let string = self.string as NSString
        guard offset <= string.length else { return MufiPosition(line: 1, column: 1) }

        var lineCount: UInt32 = 1
        var lastLineOffset = 0

        string.enumerateSubstrings(
            in: NSRange(location: 0, length: string.length), options: .byLines
        ) { substring, range, enclosingRange, stop in
            if offset >= range.location && offset <= range.location + range.length {
                // Found the line
                let _ = UInt32(offset - range.location) + 1
                stop.pointee = true
                lastLineOffset = -1  // Mark as found
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

        return MufiPosition(line: lineCount, column: 1)  // Should have been caught in loop
    }
}
