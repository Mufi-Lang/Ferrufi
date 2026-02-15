//
//  ZonHighlighter.swift
//  Ferrufi
//
//  Syntax highlighter for the Zig Object Notation (ZON) format.
//

import AppKit
import Foundation

/// A fast, regex-based syntax highlighter for ZON files.
@MainActor
public final class ZonHighlighter {
    
    // MARK: - Token Types
    
    private enum TokenType {
        case key
        case string
        case comment
        case number
        case boolean
        case nilValue
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
        
        // 1. Reset all attributes to theme default
        storage.removeAttribute(.foregroundColor, range: highlightRange)
        storage.addAttribute(.foregroundColor, value: NSColor(theme.colors.foreground), range: highlightRange)
        
        let text = storage.string
        
        // 3. Apply highlighting patterns
        
        // Comments (single line //)
        apply(pattern: #"//.*$"#, type: .comment, in: storage, text: text, range: highlightRange)
        
        // Keys (.name =)
        apply(pattern: #"\.[a-zA-Z_][a-zA-Z0-9_]*"#, type: .key, in: storage, text: text, range: highlightRange)
        
        // Strings ("...")
        apply(pattern: #""[^"\]*(\.[^"\]*)*""#, type: .string, in: storage, text: text, range: highlightRange)
        
        // Numbers
        apply(pattern: #"\b([0-9]+(\.[0-9]+)?)\b"#, type: .number, in: storage, text: text, range: highlightRange)
        
        // Booleans
        apply(pattern: #"\b(true|false)\b"#, type: .boolean, in: storage, text: text, range: highlightRange)
        
        // Nil
        apply(pattern: #"\b(null|nil)\b"#, type: .nilValue, in: storage, text: text, range: highlightRange)
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func setupAttributes(baseFontName: String?, baseSize: Double) {
        let fontName = baseFontName ?? NSFont.monospacedSystemFont(ofSize: CGFloat(baseSize), weight: .regular).fontName
        let baseFont = NSFont(name: fontName, size: CGFloat(baseSize)) ?? NSFont.monospacedSystemFont(ofSize: CGFloat(baseSize), weight: .regular)
        
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        
        attributes = [
            .key: [
                .foregroundColor: NSColor(theme.colors.accent),
                .font: boldFont
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
            .boolean: [
                .foregroundColor: NSColor(theme.colors.accentSecondary),
                .font: boldFont
            ],
            .nilValue: [
                .foregroundColor: NSColor(theme.colors.accentSecondary),
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
