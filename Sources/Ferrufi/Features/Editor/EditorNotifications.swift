/*
 EditorNotifications.swift
 Ferrufi

 Centralized notification name definitions for editor-related events.

 This file collects Notification.Name constants used across editor components
 (EnhancedEditorView, UnifiedEditor, EditorContainer, etc.) so callers use a
 single source of truth instead of hard-coded strings.
*/

import Foundation

extension Notification.Name {
    // Formatting notifications removed.

    /// Navigation / linking notifications
    /// Object: String (note name) when navigating to a wiki/internal note
    static let navigateToNote = Notification.Name("navigateToNote")

    // Note: `openWikiLink` and `openFileLink` are defined centrally in
    // `Ferrufi/Sources/Ferrufi/Core/Notifications+Links.swift` to avoid symbol conflicts.
    // Do not redefine them here.

    /// Posted by the UnifiedEditor Coordinator when the active UnifiedTextView instance
    /// is attached/detached. The object is the `UnifiedTextView` instance (or nil).
    static let unifiedEditorTextViewChanged = Notification.Name("unifiedEditorTextViewChanged")

    /// Posted when the selection/caret inside the active UnifiedTextView changes.
    /// The `object` is the current selection as an `NSRange` (boxed) or the `NSTextView`
    /// instance that emitted the selection change (depending on usage context).
    static let unifiedEditorSelectionChanged = Notification.Name("unifiedEditorSelectionChanged")

    /// Posted to request the editor to navigate to a specific MufiRange.
    /// Object: MufiRange
    static let editorNavigateToRange = Notification.Name("editorNavigateToRange")
}
