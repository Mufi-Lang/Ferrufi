import Foundation
import SwiftUI

/// Represents the immutable state required for a single frame of rendering.
/// Decoupled from the live editor state to ensure thread safety and consistency during rendering.
public struct RenderState {
    public let text: String
    public let cursorPosition: Int
    public let selectionRange: Range<Int>?
    public let diagnostics: [Diagnostic]?
    
    public init(
        text: String,
        cursorPosition: Int,
        selectionRange: Range<Int>? = nil,
        diagnostics: [Diagnostic]? = nil
    ) {
        self.text = text
        self.cursorPosition = cursorPosition
        self.selectionRange = selectionRange
        self.diagnostics = diagnostics
    }
}

/// Simplified diagnostic model for the renderer
public struct Diagnostic {
    public let range: Range<Int>
    public let severity: Severity
    public let message: String
    
    public enum Severity {
        case error
        case warning
        case info
    }
}
