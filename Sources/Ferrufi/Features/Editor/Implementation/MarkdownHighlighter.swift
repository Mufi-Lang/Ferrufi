//
//  MarkdownHighlighter.swift
//  Ferrufi
//
//  Syntax highlighter for Markdown files.
//

import AppKit
import Foundation

/// A regex-based syntax highlighter for Markdown.
public final class MarkdownHighlighter {
    
    private enum TokenType {
        case header
        case bold
        case italic
        case list
        case code
        case link
        case wikiLink
    }
    
    private let theme: IronTheme
    private var attributes: [TokenType: [NSAttributedString.Key: Any]] = [:]
    
    public init(theme: IronTheme, baseFontName: String?, baseSize: Double) {
        self.theme = theme
        setupAttributes(baseFontName: baseFontName, baseSize: baseSize)
    }
    
    public func updateConfig(theme: IronTheme, baseFontName: String?, baseSize: Double) {
        setupAttributes(baseFontName: baseFontName, baseSize: baseSize)
    }
    
    public func highlight(in storage: NSTextStorage) {
        let range = NSRange(location: 0, length: storage.length)
        guard range.length > 0 else { return }
        
        // 1. Reset all attributes to theme default
        storage.addAttribute(.foregroundColor, value: NSColor(theme.colors.foreground), range: range)
        
        let text = storage.string
        
        // Headers
        apply(pattern: #"^#{1,6}\s+.+$"#, type: .header, in: storage, text: text, options: .anchorsMatchLines)
        
        // Bold
        apply(pattern: #"\*\*.+?\*\*"#, type: .bold, in: storage, text: text)
        apply(pattern: #"__.+?__"#, type: .bold, in: storage, text: text)
        
        // Italic
        apply(pattern: #"\*.+?\*"#, type: .italic, in: storage, text: text)
        apply(pattern: #"_.+?_"#, type: .italic, in: storage, text: text)
        
        // Lists
        apply(pattern: #"^\s*[\*\-\+]\s+"#, type: .list, in: storage, text: text, options: .anchorsMatchLines)
        apply(pattern: #"^\s*\d+\.\s+"#, type: .list, in: storage, text: text, options: .anchorsMatchLines)
        
        // Code blocks & inline code
        apply(pattern: #"`{3}.*?\n[\s\S]*?\n`{3}"#, type: .code, in: storage, text: text)
        apply(pattern: #"`[^`]+`"#, type: .code, in: storage, text: text)
        
        // Links
        apply(pattern: #"\[.+?\]\(.+?\)"#, type: .link, in: storage, text: text)
        
        // Wiki Links
        apply(pattern: #"\[\[.+?\]\]"#, type: .wikiLink, in: storage, text: text)
    }
    
    private func setupAttributes(baseFontName: String?, baseSize: Double) {
        let fontName = baseFontName ?? NSFont.monospacedSystemFont(ofSize: CGFloat(baseSize), weight: .regular).fontName
        let baseFont = NSFont(name: fontName, size: CGFloat(baseSize)) ?? NSFont.monospacedSystemFont(ofSize: CGFloat(baseSize), weight: .regular)
        
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        
        attributes = [
            .header: [
                .foregroundColor: NSColor(theme.colors.accent),
                .font: boldFont
            ],
            .bold: [
                .font: boldFont
            ],
            .italic: [
                .font: italicFont
            ],
            .list: [
                .foregroundColor: NSColor(theme.colors.accentSecondary)
            ],
            .code: [
                .foregroundColor: NSColor(theme.colors.success),
                .backgroundColor: NSColor(theme.colors.backgroundSecondary).withAlphaComponent(0.5)
            ],
            .link: [
                .foregroundColor: NSColor(theme.colors.accent),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ],
            .wikiLink: [
                .foregroundColor: NSColor(theme.colors.accentSecondary),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        ]
    }
    
    private func apply(pattern: String, type: TokenType, in storage: NSTextStorage, text: String, options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        guard let attrs = attributes[type] else { return }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches {
            storage.addAttributes(attrs, range: match.range)
        }
    }
}
