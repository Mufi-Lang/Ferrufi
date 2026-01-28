/*
 * Tree-sitter grammar for Mufi (initial, lightweight)
 *
 * This grammar is intended as a starting point for Tree-sitter integration.
 * It focuses on lexical constructs and common syntactic shapes used for syntax
 * highlighting and quick structural parsing:
 *  - comments (// ... and C-style block comments)
 *  - strings (double-quoted with escapes)
 *  - integers and floats
 *  - identifiers
 *  - variable and function declarations
 *  - function calls
 *  - simple expressions and binary operators
 *  - arrays and hash tables (hash tables use '#{ ... }', vectors use '{ ... }')
 *
 * The grammar is intentionally conservative and designed to be easy to extend.
 */

module.exports = grammar({
  name: "mufi",

  // Whitespace and comments are 'extras' so tokens/rules don't need to mention them
  extras: ($) => [/\s|\\uFEFF/, $.comment],

  // Top-level
  rules: {
    source_file: ($) => repeat($._statement),

    _statement: ($) =>
      choice(
        $.variable_declaration,
        $.function_declaration,
        $.if_statement,
        $.while_statement,
        $.return_statement,
        $.expression_statement,
        $.block,
      ),

    // Declarations
    variable_declaration: ($) =>
      seq(
        choice("var", "let"),
        field("name", $.identifier),
        optional(seq("=", field("value", $._expression))),
        optional(";"),
      ),

    function_declaration: ($) =>
      seq(
        "fun",
        field("name", $.identifier),
        "(",
        optional($.parameter_list),
        ")",
        field("body", $.block),
      ),

    parameter_list: ($) => commaSep($.identifier),

    // Control flow
    if_statement: ($) =>
      seq(
        "if",
        "(",
        field("condition", $._expression),
        ")",
        field("consequence", $.block),
        optional(
          seq("else", field("alternative", choice($.block, $.if_statement))),
        ),
      ),

    while_statement: ($) =>
      seq("while", "(", field("condition", $._expression), ")", $.block),

    return_statement: ($) =>
      prec.right(seq("return", optional($._expression), optional(";"))),

    expression_statement: ($) => seq($._expression, optional(";")),

    // Blocks
    block: ($) => prec.left(2, seq("{", repeat($._statement), "}")),

    // Expressions (simple set useful for highlighting)
    _expression: ($) =>
      choice(
        $.binary_expression,
        $.call_expression,
        $.array,
        $.hash_table,
        $.vector,
        $.parenthesized,
        $.identifier,
        $.number,
        $.string,
      ),

    parenthesized: ($) => seq("(", $._expression, ")"),

    // Function call: name(...)
    call_expression: ($) =>
      prec.left(
        1,
        seq(
          field("callee", $.identifier),
          "(",
          optional(commaSep($._expression)),
          ")",
        ),
      ),

    // Binary expressions (operator precedence)
    binary_expression: ($) =>
      choice(
        // arithmetic
        prec.left(
          8,
          seq(
            $._expression,
            field("operator", choice("*", "/", "%")),
            $._expression,
          ),
        ),
        prec.left(
          7,
          seq(
            $._expression,
            field("operator", choice("+", "-")),
            $._expression,
          ),
        ),
        // comparison
        prec.left(
          6,
          seq(
            $._expression,
            field("operator", choice("==", "!=", "<=", ">=", "<", ">")),
            $._expression,
          ),
        ),
        // boolean ops (keywords)
        prec.left(
          5,
          seq(
            $._expression,
            field("operator", choice("and", "or")),
            $._expression,
          ),
        ),
        // logical operators (alternate)
        prec.left(
          4,
          seq(
            $._expression,
            field("operator", choice("&&", "||")),
            $._expression,
          ),
        ),
      ),

    // Numbers: prefer float then integer
    number: ($) => token(choice(/\d+\.\d+/, /\d+/)),

    // Strings (basic quoted strings with escapes)
    string: ($) => token(seq('"', repeat(choice(/[^"\\]/, /\\./)), '"')),

    // Identifiers
    identifier: ($) => /[A-Za-z_][A-Za-z0-9_]*/,

    // Arrays
    array: ($) => seq("[", optional(commaSep($._expression)), "]"),

    // Hash tables: #{"key": value, ...}
    hash_table: ($) => seq("#{", optional(commaSep($.hash_pair)), "}"),
    hash_pair: ($) =>
      seq(field("key", $.string), ":", field("value", $._expression)),

    // Float vectors: {1, 2, 3}
    // Give vectors higher precedence than general expressions so `{1}` parses as a vector,
    // but keep them below blocks (which use precedence 2).
    vector: ($) =>
      prec.left(1, seq("{", optional(commaSep($._expression)), "}")),

    // Comments
    comment: ($) => token(choice(seq("//", /.*/), seq("/*", /[\s\S]*?/, "*/"))),
  },
});

// Helper to build comma-separated lists
function commaSep(rule) {
  return seq(rule, repeat(seq(",", rule)));
}
