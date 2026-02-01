/*
 EditorCore.swift
 Ferrufi

 Adapter that exposes a small editor core surface and a SwiftUI view wrapper
 around the existing `UnifiedEditor` component.

 Phase 2: this adapter will be expanded to directly drive `UnifiedTextView`
 Coordinator methods where necessary (selection, hidden backing editor, etc).
 For now this file provides a safe, compile-time adapter that:
  - conforms to `EditorHost` so callers can migrate,
  - owns the document binding and text content,
  - exposes simple selection/formatting helpers,
  - provides `EditorCoreView` which embeds `UnifiedEditor`.
*/

import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public final class EditorCore: ObservableObject, EditorHost {

    // MARK: - Published state

    @Published public var document: EditorDocument?
    @Published public var content: String = ""
    @Published public var isEditing: Bool = false

    // Editor host properties
    // Preview/split mode removed; editor surfaces are editor-only.

    // Selection is tracked as an NSRange (UTF-16) when available.
    // In the Phase 2 full implementation this will be kept in sync with the NSTextView.
    private var selectionRange: NSRange? = nil

    // Subjects for Publisher requirements on EditorHost
    private let documentDidChangeSubject = PassthroughSubject<Void, Never>()
    private let selectionDidChangeSubject = CurrentValueSubject<NSRange?, Never>(nil)

    // Toolbar target (placeholder; Phase 5 will provide a hidden NSTextView here)
    public var toolbarTarget: AnyObject? = nil

    // MARK: - Initialization

    public init() {}

    // MARK: - EditorHost: Document lifecycle

    public func open(document: EditorDocument) {
        self.document = document
        self.content = document.text
        // Preview/split mode removed; no mode mutation performed.
        documentDidChangeSubject.send(())
    }

    public func save() throws {
        // Minimal stub: update the backing document's text if present.
        // Full save to disk is performed by higher-level services (FileStorage / FolderManager).
        guard let doc = document else { return }
        doc.text = content
    }

    public func close() {
        self.document = nil
        documentDidChangeSubject.send(())
    }

    // MARK: - Selection & editing helpers

    public func getSelection() -> NSRange? {
        return selectionRange
    }

    public func setSelection(_ range: NSRange) {
        selectionRange = range
        selectionDidChangeSubject.send(range)
    }

    /// Apply a formatting command in a best-effort way by manipulating the raw text.
    /// This is intentionally conservative: it updates `content` and not the native text view.
    public func applyFormattingCommand(_ command: EditorCommand) {
        switch command {
        case .bold:
            applyWrap(prefix: "**", suffix: "**", placeholder: "bold text")
        case .italic:
            applyWrap(prefix: "*", suffix: "*", placeholder: "italic text")
        case .codeInline:
            applyWrap(prefix: "`", suffix: "`", placeholder: "code")
        case .codeBlock(let language):
            let fence = "```" + (language ?? "")
            applyBlockWrapper(prefix: fence + "\n", suffix: "\n```", placeholder: "code")
        case .heading(let level):
            applyLinePrefix(prefix: String(repeating: "#", count: max(1, min(6, level))) + " ")
        case .unorderedList:
            applyLinePrefix(prefix: "- ")
        case .orderedList:
            applyLinePrefix(prefix: "1. ")
        case .blockquote:
            applyLinePrefix(prefix: "> ")
        case .insertLink(let url, let title):
            let t = title ?? "link text"
            let u = url?.absoluteString ?? "https://example.com"
            insertText("[\(t)](\(u))")
        case .custom(_, _):
            // No-op for unknown custom commands in the stub.
            break
        }
    }

    // MARK: - Execution

    public func runCell(id: String?) async -> ExecutionResult {
        // Stub: no runner available in the adapter. Return a placeholder result.
        await Task.yield()
        return ExecutionResult(
            success: false, output: "Execution not implemented in EditorCore adapter",
            mime: "text/plain", execCount: nil, metadata: nil)
    }

    // MARK: - EditorHost publishers

    public var documentDidChangePublisher: AnyPublisher<Void, Never> {
        documentDidChangeSubject.eraseToAnyPublisher()
    }

    public var selectionDidChangePublisher: AnyPublisher<NSRange?, Never> {
        selectionDidChangeSubject.eraseToAnyPublisher()
    }

    // MARK: - Small text helpers (string-aware, UTF-16 safe)

    private func applyWrap(prefix: String, suffix: String, placeholder: String) {
        // If selection exists, wrap it; otherwise insert prefix + placeholder + suffix at end.
        if let sel = selectionRange, let r = Range(sel, in: content) {
            let selected = String(content[r])
            let newSelected = selected.isEmpty ? placeholder : selected
            content.replaceSubrange(r, with: prefix + newSelected + suffix)
            // update selection to encompass the new inserted content
            let nsLocation = (content as NSString).range(of: prefix + newSelected + suffix).location
            setSelection(
                NSRange(location: nsLocation, length: (prefix + newSelected + suffix).utf16.count))
        } else {
            // append at end
            let insertion = prefix + placeholder + suffix
            content.append(insertion)
            let nsLocation = (content as NSString).length - (insertion as NSString).length
            setSelection(NSRange(location: nsLocation, length: (placeholder as NSString).length))
        }
        documentDidChangeSubject.send(())
    }

    private func applyBlockWrapper(prefix: String, suffix: String, placeholder: String) {
        // Similar to applyWrap but preserves line boundaries.
        if let sel = selectionRange, let r = Range(sel, in: content) {
            let selected = String(content[r])
            let body = selected.isEmpty ? placeholder : selected
            content.replaceSubrange(r, with: prefix + body + suffix)
            let nsLocation = (content as NSString).range(of: prefix + body + suffix).location
            setSelection(NSRange(location: nsLocation, length: (body as NSString).length))
        } else {
            let insertion = prefix + placeholder + suffix
            if !content.hasSuffix("\n") && !content.isEmpty {
                content.append("\n")
            }
            content.append(insertion)
            let nsLocation =
                (content as NSString).length - (insertion as NSString).length
                + (prefix as NSString).length
            setSelection(NSRange(location: nsLocation, length: (placeholder as NSString).length))
        }
        documentDidChangeSubject.send(())
    }

    private func applyLinePrefix(prefix: String) {
        // Prepend the prefix to the current line(s) containing the selection or caret.
        if let sel = selectionRange, let r = Range(sel, in: content) {
            // Find line range
            let ns = content as NSString
            let startIndex = ns.lineRange(
                for: NSRange(location: r.lowerBound.utf16Offset(in: content), length: 0)
            ).location
            let endInfo = ns.lineRange(
                for: NSRange(location: r.upperBound.utf16Offset(in: content), length: 0))
            let fullRange = NSRange(
                location: startIndex, length: endInfo.location + endInfo.length - startIndex)
            if let swiftRange = Range(fullRange, in: content) {
                let original = String(content[swiftRange])
                let transformed = original.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { prefix + $0 }.joined(separator: "\n")
                content.replaceSubrange(swiftRange, with: transformed)
                setSelection(NSRange(location: fullRange.location, length: transformed.utf16.count))
            }
        } else {
            // No selection: apply to last line
            if content.isEmpty {
                content = prefix
                setSelection(NSRange(location: (content as NSString).length, length: 0))
            } else {
                // apply to last line
                let ns = content as NSString
                let lines = ns.components(separatedBy: "\n")
                guard let last = lines.last else { return }
                let base = lines.dropLast().joined(separator: "\n")
                let newText = base + (base.isEmpty ? "" : "\n") + prefix + last
                content = newText
                setSelection(
                    NSRange(
                        location: (content as NSString).length - (last as NSString).length,
                        length: 0))
            }
        }
        documentDidChangeSubject.send(())
    }

    private func insertText(_ textToInsert: String) {
        if let sel = selectionRange, let r = Range(sel, in: content) {
            content.replaceSubrange(r, with: textToInsert)
            let start = (content as NSString).range(of: textToInsert).location
            setSelection(NSRange(location: start + (textToInsert as NSString).length, length: 0))
        } else {
            content.append(textToInsert)
            setSelection(NSRange(location: (content as NSString).length, length: 0))
        }
        documentDidChangeSubject.send(())
    }
}

// MARK: - EditorCoreView: SwiftUI wrapper around UnifiedEditor

public struct EditorCoreView: View {
    @StateObject private var core: EditorCore

    public init(core: EditorCore) {
        _core = StateObject(wrappedValue: core)
    }

    public var body: some View {
        // Force all files to be treated as Mufi (legacy note-format support removed)
        let fileType: EditorFileType = .mufi

        // UnifiedEditor is the existing SwiftUI wrapper around the NSTextView implementation.
        UnifiedEditor(
            text: Binding(
                get: { core.content },
                set: { new in core.content = new }
            ),
            isEditing: Binding(
                get: { core.isEditing },
                set: { new in core.isEditing = new }
            ),
            fileType: fileType,
            placeholder: "Start writing...",
            highlightingEnabled: true,
            onTextChange: { new in
                // propagate changes back to the core and document
                core.content = new
                if let doc = core.document {
                    doc.text = new
                }
            },
            onSave: {
                do {
                    try core.save()
                } catch {
                    // swallow for now; higher level UI should report save errors
                }
            }
        )
        // Ensure monospaced font usage for editor as discussed in the consolidation plan.
        .environmentObject(ThemeManager.shared)
        .environmentObject(Settings.shared)
    }
}
