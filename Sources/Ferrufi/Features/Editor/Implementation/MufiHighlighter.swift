//
//  MufiHighlighter.swift
//  Ferrufi
//
//  Syntax highlighter for the Mufi programming language.
//

import AppKit
import Foundation

/// A fast, regex-based syntax highlighter for the Mufi programming language.
@MainActor
public final class MufiHighlighter {
    
    // MARK: - Token Types
    
    private enum TokenType {
        case keyword
        case type
        case string
        case comment
        case number
        case function
        case constant
    }
    
    // MARK: - Properties
    
    private let theme: IronTheme
    private var attributes: [TokenType: [NSAttributedString.Key: Any]] = [: ]
    
    // MARK: - Initialization
    
    public init(theme: IronTheme, baseFontName: String?, baseSize: Double) {
        self.theme = theme
        setupAttributes(baseFontName: baseFontName, baseSize: baseSize)
    }
    
    // MARK: - Public Interface
    
    /// Update highlighter configuration when theme or font changes
    public func updateConfig(theme: IronTheme, baseFontName: String?, baseSize: Double) {
        setupAttributes(baseFontName: baseFontName, baseSize: baseSize)
    }
    
    /// Apply syntax highlighting to the provided text storage
    @MainActor
    public func highlight(in storage: NSTextStorage, range: NSRange? = nil) {
        let highlightRange = range ?? NSRange(location: 0, length: storage.length)
        guard highlightRange.length > 0 else { return }
        
        // 1. Reset all attributes to theme default in the target range
        storage.removeAttribute(.foregroundColor, range: highlightRange)
        storage.addAttribute(.foregroundColor, value: NSColor(theme.colors.foreground), range: highlightRange)
        
        let text = storage.string
        
        // 3. Apply highlighting patterns
        // Keywords
        apply(pattern: #"\b(var|let|fn|func|if|else|while|for|return|break|continue|in|import|import_dynamic|extern|as|is|nil|true|false|class|new|print|self|super|type|interface|impl|match|case|pub|priv|mut)\b"#, 
              type: .keyword, in: storage, text: text, range: highlightRange)
        
        // Built-in Types
        apply(pattern: #"\b(Int|Float|String|Bool|Array|Dict|Map|Any|Void|Vector|Matrix|Complex)\b"#, 
              type: .type, in: storage, text: text, range: highlightRange)
        
        // Numbers
        apply(pattern: #"\b([0-9]+(\.[0-9]+)?)\b"#,
              type: .number, in: storage, text: text, range: highlightRange)
        
        // Constants (UPPER_CASE)
        apply(pattern: #"\b([A-Z_][A-Z0-9_]*)\b"#,
              type: .constant, in: storage, text: text, range: highlightRange)
        
        // Function calls
        apply(pattern: #"([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()"#,
              type: .function, in: storage, text: text, range: highlightRange)
        
        // Strings (double quotes)
        apply(pattern: #""[^"\\]*(\\.[^"\\]*)*""#,
              type: .string, in: storage, text: text, range: highlightRange)
        
        // Comments (single line)
        apply(pattern: #"//.*$"#,
              type: .comment, in: storage, text: text, range: highlightRange)
        
        // Comments (block)
        apply(pattern: #"/\*[^*]*\*+(?:[^/*][^*]*\*+)*/"#,
              type: .comment, in: storage, text: text, range: highlightRange)
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func setupAttributes(baseFontName: String?, baseSize: Double) {
        let fontName = baseFontName ?? NSFont.monospacedSystemFont(ofSize: CGFloat(baseSize), weight: .regular).fontName
        let baseFont = NSFont(name: fontName, size: CGFloat(baseSize)) ?? NSFont.monospacedSystemFont(ofSize: CGFloat(baseSize), weight: .regular)
        
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        
        attributes = [
            .keyword: [
                .foregroundColor: NSColor(theme.colors.accent),
                .font: boldFont
            ],
            .type: [
                .foregroundColor: NSColor(theme.colors.accentSecondary),
                .font: baseFont
            ],
            .string: [
                .foregroundColor: NSColor(theme.colors.success),
                .font: baseFont
            ],
            .comment: [
                .foregroundColor: NSColor(theme.colors.foregroundTertiary),
                .font: italicFont
            ],
            .number: [
                .foregroundColor: NSColor(theme.colors.warning),
                .font: baseFont
            ],
            .function: [
                .foregroundColor: NSColor(theme.colors.accentSecondary),
                .font: baseFont
            ],
            .constant: [
                .foregroundColor: NSColor(theme.colors.warning),
                .font: boldFont
            ]
        ]
    }
    
    private func apply(pattern: String, type: TokenType, in storage: NSTextStorage, text: String, range: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        guard let attrs = attributes[type] else { return }
        
        let matches = regex.matches(in: text, options: [], range: range)
        for match in matches {
            storage.addAttributes(attrs, range: match.range)
        }
    }
}
