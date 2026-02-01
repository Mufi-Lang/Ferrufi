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
        case stdlib
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
        // Keywords (Updated to match mufiz_keywords.json)
        apply(pattern: #"\b(and|break|case|class|const|continue|each|else|end|false|for|foreach|fun|if|in|item|let|nil|or|print|return|self|super|switch|true|var|while)\b"#, 
              type: .keyword, in: storage, text: text, range: highlightRange)
        
        // Standard Library Functions
        apply(pattern: #"\b(what_is|ln|log2|log10|pi|exp|sin|cos|tan|asin|acos|atan|complex|abs|phase|rand|randn|pow|sqrt|ceil|floor|round|max|min|print|printf|println|input|str|int|double|bool_fn|type_of|is_nil|is_string|is_number|is_bool|assert|exit|panic|format|equals|hash|clone|identity|linked_list|hash_table|fvec|push|pop|push_front|pop_front|len|get|set|contains|clear|range|range_to_array|put|pairs|is_empty|nth|linspace|insert|remove|slice|merge|search|sort|splice|sum|mean|vari|stddev|std_alias|minl|maxl|reverse|eye|ones|zeros|transpose|det|inv|trace|size|norm|matrix_get|matrix_set|flatten|horzcat|vertcat|matrix_create|reshape|rref|rank|json_parse|json_stringify|json_is_valid|json_pretty|json_get|json_set|serde_serialize|serde_deserialize|serde_to_json|serde_from_json|serde_to_toml|serde_from_toml|serde_to_yaml|serde_from_yaml|serde_detect_format|serde_validate|create_file|write_file|read_file|delete_file|create_dir|delete_dir|file_exists|dir_exists|file_size|copy_file|now|now_ns|now_ms|now_us|sleep|sleep_ms|sleep_us|time_diff|http_get|http_post|http_put|http_delete|set_content_type|set_auth|parse_url|url_encode|url_decode|open_url)\b"#,
              type: .stdlib, in: storage, text: text, range: highlightRange)
        
        // Built-in Types
        apply(pattern: #"\b(Int|Float|String|Bool|Array|Dict|Map|Any|Void|Vector|Matrix|Complex)\b"#, 
              type: .type, in: storage, text: text, range: highlightRange)
        
        // Numbers
        apply(pattern: #"\b([0-9]+(\.[0-9]+)?)\b"#,
              type: .number, in: storage, text: text, range: highlightRange)
        
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
            .stdlib: [
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
