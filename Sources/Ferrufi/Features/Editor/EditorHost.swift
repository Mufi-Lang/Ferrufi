//
// EditorHost.swift
// Ferrufi
//
// Scaffold for a single public editor surface API used to host and drive editor UI.
// This file defines a minimal `EditorHost` protocol, supporting enums for view mode
// and editor commands, and a small `EditorDocument` protocol to decouple callers
// from concrete document implementations.
//
// Notes:
// - The repository-wide decision for this migration: keep all fonts monospaced and
//   use a hidden backing editor for toolbar routing (B1). That behavior will be
//   implemented by the `EditorContainer` concrete type that conforms to `EditorHost`.
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// Editor view modes removed; editor surfaces are editor-only.

/// Common editor formatting/structuring commands that toolbars or shortcuts will issue.
///
/// Implementors should map these commands to reasonable transformations on the document.
public enum EditorCommand: Equatable {
    case bold  // wrap/unwrap selection with bold markers
    case italic  // wrap/unwrap selection with italics markers
    case codeInline  // wrap selection with inline code markers
    case codeBlock(language: String?)  // insert or wrap a fenced code block
    case heading(level: Int)  // apply a heading at the given level (1...6)
    case unorderedList
    case orderedList
    case blockquote
    case insertLink(url: URL?, title: String?)
    case custom(identifier: String, payload: [String: String]?)  // extensibility
}

/// Result of running/executing a code cell or code-block in the document.
/// This is intentionally minimal; implementations may add richer metadata.
public struct ExecutionResult: Sendable {
    public var success: Bool
    public var output: String
    public var mime: String?
    public var execCount: Int?
    public var metadata: [String: String]?

    public init(
        success: Bool = true,
        output: String = "",
        mime: String? = nil,
        execCount: Int? = nil,
        metadata: [String: String]? = nil
    ) {
        self.success = success
        self.output = output
        self.mime = mime
        self.execCount = execCount
        self.metadata = metadata
    }
}

/// Minimal protocol for a document that an EditorHost can open / edit.
///
/// Concrete implementations in the app should satisfy this protocol (e.g. the Note model).
public protocol EditorDocument: AnyObject {
    var id: UUID { get }
    var text: String { get set }
    var fileURL: URL? { get }
    var fileExtension: String { get }
}

/// Public API surface for the unified editor host.
///
/// The intention is for a single `EditorContainer` SwiftUI view to implement this
/// protocol and be used across the app as the canonical editor surface.
/// Keep this surface small and stable: callers should not rely on internal views.
///
/// Implementations should guarantee:
/// - Fast updates for text changes (incremental highlighting remains internal).
/// - Toolbar routing works via `toolbarTarget` to receive selection-based commands.
/// - By default editors use monospaced fonts for code editing and parity with Mufi scripts.
///   Non-script editing may instead use a proportional (system) font for improved readability.
@MainActor public protocol EditorHost: AnyObject {
    // MARK: Document lifecycle

    /// Open or attach to a document. Implementations should update the visible editor.
    /// This call should be safe to call from main actor / UI threads.
    func open(document: EditorDocument)

    /// Save current document state to disk (if persistent).
    /// Implementations may throw if saving fails.
    func save() throws

    /// Convenience: close the currently open document and release resources.
    func close()

    // MARK: View mode & layout

    /// Note: split view modes have been removed; the editor surface is editor-only.
    /// Implementations may expose layout preferences via other APIs if needed.

    // MARK: Selection & editing helpers

    /// Get the current selection or caret position as a range of UTF-16 indices.
    /// Returns `nil` when selection is unavailable.
    func getSelection() -> NSRange?

    /// Set the selection/caret programmatically.
    func setSelection(_ range: NSRange)

    /// Apply a toolbar/editor command. Implementations should update document text and selection.
    func applyFormattingCommand(_ command: EditorCommand)

    // MARK: Execution / REPL features

    /// Execute a code cell by id (or nil to execute a default / focused cell).
    /// Returns an `ExecutionResult`.
    func runCell(id: String?) async -> ExecutionResult

    // MARK: Toolbar / responder routing

    /// An object suitable as the toolbar action target.
    /// Implementations may return an object suitable for responder-style actions
    /// (e.g. an `NSTextView`) to receive formatting commands when the visible editor
    /// does not itself accept responder messages.
    var toolbarTarget: AnyObject? { get }

    // MARK: Optional: event publishers (for UI bindings)

    /// Publisher fired when the document text changes (main thread).
    var documentDidChangePublisher: AnyPublisher<Void, Never> { get }

    /// Publisher fired when the selection changes.
    var selectionDidChangePublisher: AnyPublisher<NSRange?, Never> { get }
}

// MARK: - Convenient default implementations

extension EditorHost {
    public func close() {
        // Default behavior: no-op. Concrete hosts can override to release resources.
    }

    public func getSelection() -> NSRange? {
        return nil
    }

    public func setSelection(_ range: NSRange) {
        // Default: no-op
    }

    public func applyFormattingCommand(_ command: EditorCommand) {
        // Default: no-op
    }

    public func runCell(id: String?) async -> ExecutionResult {
        return ExecutionResult(success: false, output: "Not implemented")
    }

    public var toolbarTarget: AnyObject? {
        return nil
    }

    public var documentDidChangePublisher: AnyPublisher<Void, Never> {
        // Provide a simple publisher that never fires by default.
        return Just(()).map { _ in () }.eraseToAnyPublisher()
    }

    public var selectionDidChangePublisher: AnyPublisher<NSRange?, Never> {
        return Just(nil).eraseToAnyPublisher()
    }
}
