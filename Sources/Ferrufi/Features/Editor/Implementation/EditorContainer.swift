//
//  EditorContainer.swift
// Ferrufi
//
// Minimal EditorContainer stub and host that conform to the EditorHost protocol.
// This file provides:
//  - `EditorContainerHost`: a class conforming to `EditorHost` (for migration and toolbar routing).
//  - `EditorContainer`: a lightweight SwiftUI view that composes the host and renders
//    a simple editor UI for prototyping.
//
// Notes:
//  - This is a stub implementation intended for Phase 1 scaffolding. It preserves the
//    public EditorHost surface and publishes basic events so callers can compile and
//    migrate incrementally. Concrete wiring to `UnifiedTextView` will be implemented in later phases.
//
// Decision points already applied:
//  - Fonts: keep monospaced styling for the editor (as part of consolidation decisions).
//  - Toolbar strategy: hidden backing editor (B1) will be provided by the host (placeholder here).
//

import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - EditorContainerHost
@MainActor
public final class EditorContainerHost: NSObject, ObservableObject, EditorHost {

    // MARK: Published state

    @Published public var document: EditorDocument?

    // Internal subjects backing the public publishers
    private let documentDidChangeSubject = PassthroughSubject<Void, Never>()
    private let selectionDidChangeSubject = CurrentValueSubject<NSRange?, Never>(nil)

    // Toolbar target (hidden backing NSTextView used for toolbar/responder routing).
    // We keep a lightweight, non-visible NSTextView instance that toolbars and responder
    // actions can target when the visible editor is not the first responder.
    private lazy var hiddenTextView: NSTextView = {
        // Build a minimal text system (NSTextStorage + NSLayoutManager + NSTextContainer)
        // so the NSTextView is functional for responder-based formatting actions.
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let tv = NSTextView(frame: .zero, textContainer: textContainer)
        tv.isEditable = true
        tv.isSelectable = true
        tv.isHidden = true  // never add to view hierarchy; keep hidden
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        // Use a sensible monospaced fallback while ThemeManager is injected at runtime.
        tv.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        return tv
    }()

    // The toolbarTarget returns the hiddenTextView so toolbars that target `toolbarTarget`
    // can send responder-style actions to this object even when the visible editor isn't mounted.
    public var toolbarTarget: AnyObject? { hiddenTextView }

    // MARK: - Public publishers (EditorHost conformance)
    public var documentDidChangePublisher: AnyPublisher<Void, Never> {
        documentDidChangeSubject.eraseToAnyPublisher()
    }

    public var selectionDidChangePublisher: AnyPublisher<NSRange?, Never> {
        selectionDidChangeSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization
    public override init() {
        super.init()
        // Default configuration if needed

        // Formatting observers removed — toolbar formatting no longer supported.

        // Listen for the UnifiedEditor coordinator to attach/detach the active NSTextView.
        // When the active editor attaches we copy its content/selection into our hiddenTextView
        // so toolbar actions target the correct location. When it detaches we persist any
        // changes made via the hiddenTextView back into the document model.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnifiedEditorTextViewChanged(_:)),
            name: .unifiedEditorTextViewChanged,
            object: nil)

        // Observe the hidden text view so changes made by toolbar actions are persisted
        // immediately to the document model and selection updates can be propagated.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hiddenTextDidChange(_:)),
            name: NSText.didChangeNotification,
            object: hiddenTextView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hiddenTextSelectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: hiddenTextView)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Toolbar notification handlers

    // Formatting handler removed.

    // List insertion handler removed.

    // Header insertion handler removed.

    // MARK: - Unified editor attachment sync

    /// Called when the UnifiedEditor coordinator attaches/detaches its active NSTextView.
    /// The notification object is the NSTextView instance when attached, or nil when detached.
    @objc private func handleUnifiedEditorTextViewChanged(_ notification: Notification) {
        // The coordinator posts the live editor instance (a NSTextView subclass) or nil.
        if let attachedTextView = notification.object as? NSTextView {
            // Sync visible editor into hidden backing text view so toolbar/responder actions
            // operate on the correct content/selection.
            hiddenTextView.string = attachedTextView.string
            hiddenTextView.setSelectedRange(attachedTextView.selectedRange())
            if let f = attachedTextView.font {
                hiddenTextView.font = f
            }
            // Also update selection publisher so callers observe the visible selection immediately.
            selectionDidChangeSubject.send(hiddenTextView.selectedRange())
        } else {
            // Editor detached: persist any changes made through hiddenTextView back to the document
            if let existing = self.document {
                let updated = existing
                updated.text = hiddenTextView.string
                self.document = updated
                documentDidChangeSubject.send(())
            }
        }
    }

    /// Called whenever the hidden backing NSTextView's text changes (e.g. due to toolbar actions).
    /// Persist the new text back into the document and notify observers.
    @objc private func hiddenTextDidChange(_ notification: Notification) {
        guard let obj = notification.object as? NSTextView, obj === hiddenTextView else { return }
        if let existing = self.document {
            let updated = existing
            updated.text = hiddenTextView.string
            self.document = updated
            documentDidChangeSubject.send(())
        }
    }

    /// Called whenever the hidden backing NSTextView's selection changes.
    /// Propagate selection state via the selection publisher so other components can respond.
    @objc private func hiddenTextSelectionDidChange(_ notification: Notification) {
        guard let obj = notification.object as? NSTextView, obj === hiddenTextView else { return }
        selectionDidChangeSubject.send(hiddenTextView.selectedRange())
    }

    // MARK: - EditorHost: Document lifecycle

    public func open(document: EditorDocument) {
        self.document = document
        // Note: view mode handling (split/preview) removed — editor is editor-only.
        // Notify observers that the document changed
        documentDidChangeSubject.send(())
        // In a real implementation we would parse/prepare AST, attach highlighter, etc.
    }

    public func save() throws {
        // Stub: no-op save. Concrete implementation should write to disk and update state.
        // Throwing behavior can be implemented when integrating FileStorage.
    }

    public func close() {
        // Release resources and clear document binding.
        self.document = nil
        documentDidChangeSubject.send(())
    }

    // MARK: - Selection & editing helpers

    public func getSelection() -> NSRange? {
        // Stub: return nil (selection unknown). Implementors should query the editor view.
        return selectionDidChangeSubject.value
    }

    public func setSelection(_ range: NSRange) {
        // Stub: update the selection subject; concrete editors should move caret/selection.
        selectionDidChangeSubject.send(range)
    }

    public func applyFormattingCommand(_ command: EditorCommand) {
        // Stub: basic demonstration that we received a command. A real implementation
        // should transform `document.text` and update selection accordingly.
        guard let existing = document else { return }
        let d = existing
        // No-op: just annotate for now (do not mutate production content).
        // Example: insert a marker at start if no content (purely illustrative).
        if d.text.isEmpty {
            d.text = "<formatted content placeholder>"
            self.document = d
            documentDidChangeSubject.send(())
        }
    }

    // MARK: - Execution / REPL features

    public func runCell(id: String?) async -> ExecutionResult {
        // Stubbed execution: return a placeholder result. Real runner will execute,
        // capture stdout/stderr, and return rich metadata (mime, execCount, etc).
        await Task.yield()
        return ExecutionResult(
            success: true, output: "Execution not implemented in stub", mime: "text/plain",
            execCount: nil, metadata: nil)
    }
}

// MARK: - EditorContainer SwiftUI view
/// A small SwiftUI wrapper that owns an `EditorContainerHost` and renders a simple
/// editor split UI. This view is a convenience for migrating callers that
/// previously embedded `NativeSplitEditor`, `EnhancedEditorView`, etc.
public struct EditorContainer: View {

    // Host drives behavior and implements EditorHost
    @StateObject private var host: EditorContainerHost
    // Core editor adapter that will be bound to the host.document when available.
    @StateObject private var core: EditorCore = EditorCore()
    // Propagate real environment objects into the EditorCoreView (injected by callers)
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ferrufiApp: FerrufiApp

    // Allow embedding code to optionally provide an initial document
    public init(document: EditorDocument? = nil) {
        let h = EditorContainerHost()
        if let doc = document {
            h.open(document: doc)
            // Note: we intentionally do not call core.open here because @StateObject
            // initialization isn't guaranteed within init; we bind core in onAppear/onChange.
        }
        _host = StateObject(wrappedValue: h)
    }

    public var body: some View {
        GeometryReader { proxy in
            Group {
                // Secondary pane removed — always show the editor pane
                editorPane
            }
            .onReceive(host.documentDidChangePublisher) { _ in
                // Bind EditorCore whenever host document changes (publisher-driven).
                if let doc = host.document {
                    core.open(document: doc)
                } else {
                    core.document = nil
                }
            }
            .onAppear {
                // Ensure the core is bound to any pre-existing document when the view appears.
                if let doc = host.document {
                    core.open(document: doc)
                }
            }
        }
    }

    // MARK: - Subviews (placeholders to be replaced by real adapters)

    private var editorPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Editor")
                    .font(themeManager.monospacedCaption)
                    .foregroundColor(.secondary)
                Spacer()
                // Mode controls could be added here
            }
            .padding(8)
            Divider()
            // Real editor surface: EditorCoreView bound to the EditorCore adapter.
            EditorCoreView(core: core)
                .environmentObject(themeManager)
                .environmentObject(ferrufiApp)
                .environmentObject(Settings.shared)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // Secondary pane removed

    // Render helper removed (secondary rendering functionality removed)
}

// MARK: - Convenience helpers (samples)
#if DEBUG
    struct EditorContainer_Samples: PreviewProvider {
        class DummyDoc: EditorDocument {
            var id: UUID = UUID()
            var text: String = "# Hello\n\nSample content"
            var fileURL: URL? = nil
            var fileExtension: String = ".mufi"
        }

        static var previews: some View {
            EditorContainer(document: DummyDoc())
                .frame(width: 900, height: 600)
        }
    }
#endif
