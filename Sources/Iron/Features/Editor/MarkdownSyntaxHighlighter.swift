//
//  MarkdownSyntaxHighlighter.swift
//  Iron
//
//  Created on 2024-12-19.
//

import AppKit
import Foundation

/// Provides real-time syntax highlighting for markdown text
class MarkdownSyntaxHighlighter {

    // MARK: - Color Scheme

    private struct ColorScheme {
        let header: NSColor
        let bold: NSColor
        let italic: NSColor
        let code: NSColor
        let codeBackground: NSColor
        let link: NSColor
        let linkUrl: NSColor
        let blockquote: NSColor
        let listMarker: NSColor
        let strikethrough: NSColor
        let tag: NSColor
        let wikiLink: NSColor

        static let `default` = ColorScheme(
            header: NSColor.systemBlue,
            bold: NSColor.labelColor,
            italic: NSColor.secondaryLabelColor,
            code: NSColor.systemRed,
            codeBackground: NSColor.controlBackgroundColor,
            link: NSColor.systemBlue,
            linkUrl: NSColor.systemGray,
            blockquote: NSColor.systemGray,
            listMarker: NSColor.systemOrange,
            strikethrough: NSColor.systemGray,
            tag: NSColor.systemPurple,
            wikiLink: NSColor.systemGreen
        )

        static let dark = ColorScheme(
            header: NSColor.systemBlue,
            bold: NSColor.labelColor,
            italic: NSColor.secondaryLabelColor,
            code: NSColor.systemRed,
            codeBackground: NSColor.controlBackgroundColor,
            link: NSColor.systemBlue,
            linkUrl: NSColor.systemGray,
            blockquote: NSColor.systemGray,
            listMarker: NSColor.systemOrange,
            strikethrough: NSColor.systemGray,
            tag: NSColor.systemPurple,
            wikiLink: NSColor.systemGreen
        )
    }

    private let colorScheme: ColorScheme

    // MARK: - Font Styles

    private struct FontStyles {
        let base: NSFont
        let bold: NSFont
        let italic: NSFont
        let boldItalic: NSFont
        let code: NSFont
        let header1: NSFont
        let header2: NSFont
        let header3: NSFont
        let header4: NSFont
        let header5: NSFont
        let header6: NSFont

        init(baseSize: CGFloat = 14) {
            base = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
            bold = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .bold)
            italic = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
            boldItalic = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .bold)
            code = NSFont.monospacedSystemFont(ofSize: baseSize * 0.9, weight: .medium)
            header1 = NSFont.monospacedSystemFont(ofSize: baseSize * 1.8, weight: .bold)
            header2 = NSFont.monospacedSystemFont(ofSize: baseSize * 1.6, weight: .bold)
            header3 = NSFont.monospacedSystemFont(ofSize: baseSize * 1.4, weight: .bold)
            header4 = NSFont.monospacedSystemFont(ofSize: baseSize * 1.2, weight: .bold)
            header5 = NSFont.monospacedSystemFont(ofSize: baseSize * 1.1, weight: .bold)
            header6 = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .bold)
        }
    }

    private let fonts: FontStyles

    // MARK: - Regex Patterns

    private struct Patterns {
        // Headers
        static let header = try! NSRegularExpression(
            pattern: #"^(#{1,6})\s+(.*)$"#, options: [.anchorsMatchLines])

        // Text formatting
        static let bold = try! NSRegularExpression(pattern: #"\*\*(.*?)\*\*"#, options: [])
        static let italic = try! NSRegularExpression(pattern: #"\*(.*?)\*"#, options: [])
        static let strikethrough = try! NSRegularExpression(pattern: #"~~(.*?)~~"#, options: [])

        // Code
        static let inlineCode = try! NSRegularExpression(pattern: #"`([^`]+)`"#, options: [])
        static let codeBlock = try! NSRegularExpression(pattern: #"```[\s\S]*?```"#, options: [])
        static let indentedCodeBlock = try! NSRegularExpression(
            pattern: #"^(    |\t).*$"#, options: [.anchorsMatchLines])

        // Links
        static let markdownLink = try! NSRegularExpression(
            pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, options: [])
        static let wikiLink = try! NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#, options: [])
        static let autoLink = try! NSRegularExpression(
            pattern: #"https?://[^\s)]+(?=\s|$|[)])"#, options: [])

        // Lists
        static let unorderedList = try! NSRegularExpression(
            pattern: #"^(\s*)[-*+]\s"#, options: [.anchorsMatchLines])
        static let orderedList = try! NSRegularExpression(
            pattern: #"^(\s*)\d+\.\s"#, options: [.anchorsMatchLines])

        // Blockquotes
        static let blockquote = try! NSRegularExpression(
            pattern: #"^>\s*"#, options: [.anchorsMatchLines])

        // Tags
        static let tag = try! NSRegularExpression(pattern: #"#[\w-]+"#, options: [])

        // Tables
        static let tableRow = try! NSRegularExpression(
            pattern: #"^\|.*\|$"#, options: [.anchorsMatchLines])
        static let tableSeparator = try! NSRegularExpression(
            pattern: #"^\|[\s:|-]+\|$"#, options: [.anchorsMatchLines])
    }

    // MARK: - Initialization

    init() {
        self.colorScheme = .default
        self.fonts = FontStyles()
    }

    // MARK: - Public Interface

    /// Apply markdown syntax highlighting to the given text storage
    func highlight(textStorage: NSTextStorage, in range: NSRange) {
        let text = textStorage.string

        // Apply highlighting in order of precedence
        highlightCodeBlocks(textStorage: textStorage, text: text, range: range)
        highlightHeaders(textStorage: textStorage, text: text, range: range)
        highlightInlineCode(textStorage: textStorage, text: text, range: range)
        highlightLinks(textStorage: textStorage, text: text, range: range)
        highlightWikiLinks(textStorage: textStorage, text: text, range: range)
        highlightAutoLinks(textStorage: textStorage, text: text, range: range)
        highlightTextFormatting(textStorage: textStorage, text: text, range: range)
        highlightLists(textStorage: textStorage, text: text, range: range)
        highlightBlockquotes(textStorage: textStorage, text: text, range: range)
        highlightTags(textStorage: textStorage, text: text, range: range)
        highlightTables(textStorage: textStorage, text: text, range: range)
    }

    // MARK: - Individual Highlighting Methods

    private func highlightCodeBlocks(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.codeBlock.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(.font, value: fonts.code, range: matchRange)
            textStorage.addAttribute(.foregroundColor, value: colorScheme.code, range: matchRange)
            textStorage.addAttribute(
                .backgroundColor, value: colorScheme.codeBackground, range: matchRange)
        }

        Patterns.indentedCodeBlock.enumerateMatches(in: text, options: [], range: range) {
            match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(.font, value: fonts.code, range: matchRange)
            textStorage.addAttribute(.foregroundColor, value: colorScheme.code, range: matchRange)
            textStorage.addAttribute(
                .backgroundColor, value: colorScheme.codeBackground, range: matchRange)
        }
    }

    private func highlightHeaders(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.header.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match = match else { return }

            let headerLevelRange = match.range(at: 1)
            let headerTextRange = match.range(at: 2)

            if headerLevelRange.location != NSNotFound && headerTextRange.location != NSNotFound {
                let headerLevel = (text as NSString).substring(with: headerLevelRange).count

                let font: NSFont
                switch headerLevel {
                case 1: font = fonts.header1
                case 2: font = fonts.header2
                case 3: font = fonts.header3
                case 4: font = fonts.header4
                case 5: font = fonts.header5
                case 6: font = fonts.header6
                default: font = fonts.header6
                }

                // Style the entire line
                textStorage.addAttribute(.font, value: font, range: match.range)
                textStorage.addAttribute(
                    .foregroundColor, value: colorScheme.header, range: match.range)
            }
        }
    }

    private func highlightInlineCode(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.inlineCode.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(.font, value: fonts.code, range: matchRange)
            textStorage.addAttribute(.foregroundColor, value: colorScheme.code, range: matchRange)
            textStorage.addAttribute(
                .backgroundColor, value: colorScheme.codeBackground, range: matchRange)
        }
    }

    private func highlightLinks(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.markdownLink.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match = match else { return }

            let linkTextRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            if linkTextRange.location != NSNotFound {
                textStorage.addAttribute(
                    .foregroundColor, value: colorScheme.link, range: linkTextRange)
                textStorage.addAttribute(
                    .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkTextRange)
            }

            if urlRange.location != NSNotFound {
                textStorage.addAttribute(
                    .foregroundColor, value: colorScheme.linkUrl, range: urlRange)
            }
        }
    }

    private func highlightWikiLinks(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.wikiLink.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(
                .foregroundColor, value: colorScheme.wikiLink, range: matchRange)
            textStorage.addAttribute(
                .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
        }
    }

    private func highlightAutoLinks(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.autoLink.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(.foregroundColor, value: colorScheme.link, range: matchRange)
            textStorage.addAttribute(
                .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
        }
    }

    private func highlightTextFormatting(textStorage: NSTextStorage, text: String, range: NSRange) {
        // Bold (handle before italic to avoid conflicts)
        Patterns.bold.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match = match else { return }

            let contentRange = match.range(at: 1)
            if contentRange.location != NSNotFound {
                textStorage.addAttribute(.font, value: fonts.bold, range: contentRange)
                textStorage.addAttribute(
                    .foregroundColor, value: colorScheme.bold, range: contentRange)
            }
        }

        // Italic (check that it's not part of bold)
        Patterns.italic.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match = match else { return }

            let matchRange = match.range
            let contentRange = match.range(at: 1)

            // Skip if this is part of a bold formatting
            let boldMatches = Patterns.bold.matches(in: text, options: [], range: range)
            let isPartOfBold = boldMatches.contains { boldMatch in
                NSLocationInRange(matchRange.location, boldMatch.range)
                    && NSLocationInRange(NSMaxRange(matchRange) - 1, boldMatch.range)
            }

            if !isPartOfBold && contentRange.location != NSNotFound {
                var currentFont =
                    textStorage.attribute(.font, at: contentRange.location, effectiveRange: nil)
                    as? NSFont ?? fonts.base

                if currentFont.fontDescriptor.symbolicTraits.contains(.bold) {
                    currentFont = fonts.boldItalic
                } else {
                    currentFont = fonts.italic
                }

                textStorage.addAttribute(.font, value: currentFont, range: contentRange)
                textStorage.addAttribute(
                    .foregroundColor, value: colorScheme.italic, range: contentRange)
            }
        }

        // Strikethrough
        Patterns.strikethrough.enumerateMatches(in: text, options: [], range: range) {
            match, _, _ in
            guard let match = match else { return }

            let contentRange = match.range(at: 1)
            if contentRange.location != NSNotFound {
                textStorage.addAttribute(
                    .strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                    range: contentRange)
                textStorage.addAttribute(
                    .foregroundColor, value: colorScheme.strikethrough, range: contentRange)
            }
        }
    }

    private func highlightLists(textStorage: NSTextStorage, text: String, range: NSRange) {
        // Unordered lists
        Patterns.unorderedList.enumerateMatches(in: text, options: [], range: range) {
            match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(
                .foregroundColor, value: colorScheme.listMarker, range: matchRange)
        }

        // Ordered lists
        Patterns.orderedList.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(
                .foregroundColor, value: colorScheme.listMarker, range: matchRange)
        }
    }

    private func highlightBlockquotes(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.blockquote.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            // Highlight the entire line for blockquotes
            let lineRange = (text as NSString).lineRange(for: matchRange)
            textStorage.addAttribute(
                .foregroundColor, value: colorScheme.blockquote, range: lineRange)
        }
    }

    private func highlightTags(textStorage: NSTextStorage, text: String, range: NSRange) {
        Patterns.tag.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(.foregroundColor, value: colorScheme.tag, range: matchRange)
            textStorage.addAttribute(.font, value: fonts.bold, range: matchRange)
        }
    }

    private func highlightTables(textStorage: NSTextStorage, text: String, range: NSRange) {
        // Table rows
        Patterns.tableRow.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(.font, value: fonts.code, range: matchRange)
        }

        // Table separators
        Patterns.tableSeparator.enumerateMatches(in: text, options: [], range: range) {
            match, _, _ in
            guard let matchRange = match?.range else { return }

            textStorage.addAttribute(
                .foregroundColor, value: colorScheme.blockquote, range: matchRange)
        }
    }
}
