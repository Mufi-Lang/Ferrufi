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
    private let viewModeDidChangeSubject = CurrentValueSubject<EditorViewMode, Never>(.editorOnly)

    @Published public var viewMode: EditorViewMode = .editorOnly {
        didSet {
            viewModeDidChangeSubject.send(viewMode)
        }
    }

    @Published public var mufiOutput: String = ""
    @Published public var mufiExitStatus: UInt8 = 0
    @Published public var mufiExecutionTime: TimeInterval? = nil
    @Published public var showTerminal: Bool = false

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

    public var viewModeDidChangePublisher: AnyPublisher<EditorViewMode, Never> {
        viewModeDidChangeSubject.eraseToAnyPublisher()
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
        guard let doc = document as? NoteWrapper else { return }
        Task {
            try await doc.persist()
        }
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
    @ObservedObject public var host: EditorContainerHost
    // Core editor adapter that will be bound to the host.document when available.
    @StateObject private var core: EditorCore = EditorCore()
    // Metal background renderer
    @StateObject private var bgRenderer: EditorBackgroundRenderer
    // Metal minimap renderer
    @StateObject private var minimapRenderer: MinimapRenderer
    // Propagate real environment objects into the EditorCoreView (injected by callers)
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ferrufiApp: FerrufiApp
    @State private var internalContent: String = ""
    @State private var selectedTerminalTab: Int = 0 // 0 = Output, 1 = Problems

    // Allow embedding code to optionally provide an initial document
    public init(host: EditorContainerHost) {
        self.host = host
        
        // Initialize Metal renderers if device and library are available
        if let device = MTLCreateSystemDefaultDevice(),
           let queue = device.makeCommandQueue(),
           MetalDeviceManager.shared.isLibraryLoaded {
            _bgRenderer = StateObject(wrappedValue: EditorBackgroundRenderer(device: device, commandQueue: queue))
            _minimapRenderer = StateObject(wrappedValue: MinimapRenderer(device: device, commandQueue: queue))
        } else {
            // Provide dummy renderers to satisfy StateObject requirements without crashing
            let device = MTLCreateSystemDefaultDevice() ?? MetalDeviceManager.shared.device!
            let queue = device.makeCommandQueue() ?? MetalDeviceManager.shared.commandQueue!
            _bgRenderer = StateObject(wrappedValue: EditorBackgroundRenderer(device: device, commandQueue: queue))
            _minimapRenderer = StateObject(wrappedValue: MinimapRenderer(device: device, commandQueue: queue))
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Breadcrumbs (Top)
                breadcrumbBar
                
                mainContent
            }
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 8) {
            if let doc = host.document {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                Text("Vault")
                Text("/")
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                Text(doc.fileExtension.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(themeManager.currentTheme.colors.accent.opacity(0.2))
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .cornerRadius(3)
                Text("/")
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                Text(doc.id.uuidString.prefix(8)) // Placeholder for actual file name logic
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
            }
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(themeManager.currentTheme.colors.background)
        .onReceive(host.documentDidChangePublisher) { _ in
            if let doc = host.document {
                self.internalContent = doc.text
                self.core.open(document: doc)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch host.viewMode {
        case .editorOnly:
            editorPane
        case .previewOnly:
            previewPane
        case .split:
            HStack(spacing: 0) {
                editorPane
                previewPane
            }
        }
    }

    // MARK: - Subviews (placeholders to be replaced by real adapters)

                private var editorPane: some View {

                    VStack(spacing: 0) {

                        // Real editor surface: EditorCoreView bound to the EditorCore adapter.

                        EditorCoreView(core: core)

                            .environmentObject(themeManager)

                            .environmentObject(ferrufiApp)

                            .environmentObject(Settings.shared)

                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            .background(

                                ZStack {

                                    if Settings.shared.metalAccelerationEnabled && MetalDeviceManager.shared.isLibraryLoaded {

                                        MetalView(renderer: bgRenderer)

                                            .onAppear {

                                                bgRenderer.accentColor = themeManager.currentTheme.colors.accent

                                            }

                                            .onChange(of: themeManager.currentTheme.colors.accent) { _, newColor in

                                                bgRenderer.accentColor = newColor

                                            }

                                    }

                                }

                            )

                        

                        // Terminal/Output Area
                        if host.showTerminal {
                            VStack(spacing: 0) {
                                // Mini Tab Bar
                                HStack(spacing: 16) {
                                    TerminalTabButton(title: "Output", isSelected: selectedTerminalTab == 0) {
                                        selectedTerminalTab = 0
                                    }
                                    
                                    TerminalTabButton(title: "Problems", isSelected: selectedTerminalTab == 1) {
                                        selectedTerminalTab = 1
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { withAnimation { host.showTerminal = false } }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(themeManager.currentTheme.colors.backgroundSecondary)
                                
                                Divider()
                                
                                if selectedTerminalTab == 0 {
                                    MufiTerminalView(
                                        output: host.mufiOutput,
                                        exitStatus: host.mufiExitStatus,
                                        executionTime: host.mufiExecutionTime,
                                        onClear: { host.mufiOutput = "" },
                                        onClose: { withAnimation { host.showTerminal = false } }
                                    )
                                } else {
                                    ProblemsListView()
                                        .environmentObject(themeManager)
                                }
                            }
                            .frame(height: 200)
                            .background(themeManager.currentTheme.colors.background)
                            .transition(.move(edge: .bottom))
                        }
                    }
                }

    struct TerminalTabButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        @EnvironmentObject var themeManager: ThemeManager
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 0) {
                    Spacer()
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? themeManager.currentTheme.colors.accent : themeManager.currentTheme.colors.foregroundTertiary)
                    Spacer()
                    // Active indicator
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(isSelected ? themeManager.currentTheme.colors.accent : .clear)
                }
            }
            .buttonStyle(.plain)
        }
    }

            

        
        private var previewPane: some View {
        VStack(spacing: 0) {
            if host.document != nil {
                WebView(htmlContent: MarkdownParser.shared.parse(internalContent, theme: themeManager.currentTheme.colors))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
            }
        }
        .background(themeManager.currentTheme.colors.background)
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
            var fileExtension: String = "mufi"
        }

        static var previews: some View {
            let host = EditorContainerHost()
            host.open(document: DummyDoc())
            return EditorContainer(host: host)
                .environmentObject(FerrufiApp())
                .environmentObject(ThemeManager.shared)
                .environmentObject(Settings.shared)
                .frame(width: 900, height: 600)
        }
    }
#endif
