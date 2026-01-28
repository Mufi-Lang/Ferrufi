#ifndef CTREESITTER_MUFI_H
#define CTREESITTER_MUFI_H

// ctreesitter_mufi.h
// Minimal C header for Tree-sitter Mufi integration (placeholder).
//
// This header defines a small, stable C API that the Swift side can link
// against to detect availability of a compiled Tree-sitter Mufi parser and
// to request syntax highlight ranges produced by that parser.
//
// NOTE:
// - This is intentionally lightweight and meant to be a placeholder when
//   the real generated Tree-sitter parser is not present. The placeholder
//   implementation returns \"not available\" values so the editor can fall
//   back to the regex-based highlighter.
// - When a real Tree-sitter parser is generated (via tree-sitter CLI) and its
//   C sources are placed into the target directory, this header can be
//   replaced/augmented with full bindings to the parser/runtime APIs.
//

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Token types returned by the highlighter callback (small superset).
enum cts_token_type {
    CTS_TOKEN_UNKNOWN = 0,
    CTS_TOKEN_COMMENT,
    CTS_TOKEN_STRING,
    CTS_TOKEN_NUMBER,
    CTS_TOKEN_KEYWORD,
    CTS_TOKEN_FUNCTION,
    CTS_TOKEN_TYPE,
    CTS_TOKEN_OPERATOR,
    CTS_TOKEN_PUNCTUATION,
    CTS_TOKEN_IDENTIFIER
};

/// Returns non-zero if a compiled Tree-sitter Mufi parser is available
/// in this library (i.e. the parser C sources were generated and compiled).
/// When this returns zero, the Swift side should fall back to a regex-based
/// highlighter or other fallback strategy.
int cts_mufi_parser_available(void);

/// Highlight the provided UTF-8 text buffer using the Tree-sitter Mufi parser
/// and invoke the provided callback for each token range discovered.
///
/// Parameters:
///  - text: null-terminated UTF-8 string to parse/highlight
///  - callback: function to be invoked per token: callback(start, length, tokenType, ctx)
///              where start/length are byte offsets in the provided UTF-8 buffer
///              (caller can convert to NSString/NSRange on the Swift side).
///  - ctx: opaque context pointer forwarded to the callback
///
/// Returns:
///   - >= 0 : number of tokens reported via callback
///   - -1   : error (e.g. parse failed)
///
/// Note: The placeholder implementation does nothing and returns 0.
int cts_mufi_highlight_ranges(
    const char *text,
    void (*callback)(int32_t start, int32_t length, int32_t tokenType, void *ctx),
    void *ctx
);

#ifdef __cplusplus
}
#endif

#endif // CTREESITTER_MUFI_H