/*
 TreeSitterHighlighter.swift
 Ferrufi

 Small Swift wrapper around a (future) Tree-sitter Mufi parser.

 This file provides:
  - a runtime probe for whether a compiled Tree-sitter Mufi parser is available
  - a function to request highlight ranges from the parser (if present)
  - a safe fallback behavior (returns nil when no parser is available)

 Notes:
 - The C API is intentionally minimal and lives in the `CTreeSitterMufi` system target.
   That C target currently contains a placeholder implementation that reports "not
   available". When a generated Tree-sitter parser is added to the `CTreeSitterMufi`
   target (via the generation script), this Swift wrapper will begin returning real
   highlight ranges.
 - The callback-based C API uses byte offsets into a UTF-8 buffer. The Swift wrapper
   converts those byte offsets into Foundation `NSRange` (UTF-16) ranges.
*/

import AppKit
import Foundation

// Import the C shim that will either be a placeholder (parser not present)
// or the real generated parser+runtime wrappers (once generated & compiled).
#if canImport(CTreeSitterMufi)
    import CTreeSitterMufi
#endif

/// Token kinds returned by the Tree-sitter highlighter (small, semantic set).
public enum MufiTokenKind: Int32 {
    case unknown = 0
    case comment = 1
    case string = 2
    case number = 3
    case keyword = 4
    case function = 5
    case type = 6
    case op = 7
    case punctuation = 8
    case identifier = 9

    init(fromInt v: Int32) {
        switch v {
        case 1: self = .comment
        case 2: self = .string
        case 3: self = .number
        case 4: self = .keyword
        case 5: self = .function
        case 6: self = .type
        case 7: self = .op
        case 8: self = .punctuation
        case 9: self = .identifier
        default: self = .unknown
        }
    }
}

/// Highlighter wrapper (singleton).
/// - When a compiled Tree-sitter parser exists (CTS reports available), this will call
///   into the native code to obtain token ranges.
/// - Otherwise it returns `nil` to indicate the caller should fall back.
@MainActor
public final class TreeSitterHighlighter {
    public static let shared = TreeSitterHighlighter()

    private init() {}

    /// Returns `true` if the compiled parser is present and available at runtime.
    public var isParserAvailable: Bool {
        #if canImport(CTreeSitterMufi)
            return cts_mufi_parser_available() != 0
        #else
            return false
        #endif
    }

    /// Query highlight ranges for `text`.
    ///
    /// Returns:
    ///  - an array of `(range, kind)` on success (parser present and produced tokens)
    ///  - `nil` if the parser is not present / not available (caller should fallback)
    ///
    /// This method is synchronous and intended to be called from the editor's main thread.
    public func highlightRanges(in text: String) -> [(NSRange, MufiTokenKind)]? {
        // If the parser is not available, indicate fallback required
        guard isParserAvailable else { return nil }

        // Prepare a collector to receive token tuples from the C callback
        final class Collector {
            var entries: [(start: Int, length: Int, type: Int32)] = []
        }
        let collector = Collector()

        // C callback - collect raw token tuples (start/length are byte offsets)
        let cCallback: @convention(c) (Int32, Int32, Int32, UnsafeMutableRawPointer?) -> Void = {
            start, length, tokenType, ctx in
            guard let ctx = ctx else { return }
            let coll = Unmanaged<Collector>.fromOpaque(ctx).takeUnretainedValue()
            coll.entries.append((start: Int(start), length: Int(length), type: tokenType))
        }

        // Call the C API. The C placeholder returns 0 and does not invoke the callback.
        let resultCount: Int32 = cts_mufi_highlight_ranges(
            text.utf8CString.withUnsafeBufferPointer { ptr in
                // Pass the data pointer as a C string (null-terminated)
                return ptr.baseAddress
            }, cCallback, Unmanaged.passUnretained(collector).toOpaque())

        // On error (<0) we consider it a failure (fall back)
        if resultCount < 0 {
            return nil
        }

        // Convert collected UTF-8 byte offset ranges to NSRange (UTF-16)
        var out: [(NSRange, MufiTokenKind)] = []
        for entry in collector.entries {
            if let nsr = Self.nsRangeFromUTF8Offsets(
                text: text, start: entry.start, length: entry.length)
            {
                let kind = MufiTokenKind(fromInt: entry.type)
                out.append((nsr, kind))
            }
        }

        return out
    }

    // MARK: - Helpers

    /// Convert a UTF-8 byte-offset + byte-length pair into an `NSRange`
    /// suitable for use with `NSString`/`NSAttributedString` (UTF-16 indices).
    ///
    /// Returns `nil` when conversion is not possible.
    private static func nsRangeFromUTF8Offsets(text: String, start: Int, length: Int) -> NSRange? {
        guard start >= 0, length >= 0 else { return nil }
        let utf8View = text.utf8
        guard start <= utf8View.count, (start + length) <= utf8View.count else { return nil }

        var startUTF8Index = utf8View.startIndex
        if start > 0 {
            startUTF8Index = utf8View.index(utf8View.startIndex, offsetBy: start)
        }
        var endUTF8Index = startUTF8Index
        if length > 0 {
            endUTF8Index = utf8View.index(startUTF8Index, offsetBy: length)
        }

        // Convert to String.Index if possible
        guard let startIndex = String.Index(startUTF8Index, within: text),
            let endIndex = String.Index(endUTF8Index, within: text)
        else {
            return nil
        }

        let nsStart = text.utf16.distance(from: text.startIndex, to: startIndex)
        let nsEnd = text.utf16.distance(from: text.startIndex, to: endIndex)
        return NSRange(location: nsStart, length: nsEnd - nsStart)
    }
}
