import Foundation
import XCTest

@testable import TreeSitterMufi

final class TreeSitterHighlighterTests: XCTestCase {

    func testHighlightRanges_producesExpectedTokens() async throws {
        // Skip the test when the generated parser isn't available (e.g., in environments
        // where the generated sources weren't compiled in).
        try XCTSkipIf(
            !TreeSitterHighlighter.shared.isParserAvailable, "Tree-sitter parser not available")

        let sample = """
            // comment
            let s = "hello"
            let x = 42
            fun foo() { return 1 }
            """

        // TreeSitterHighlighter is @MainActor; run the call on the main actor.
        let maybeTokens = await MainActor.run {
            TreeSitterHighlighter.shared.highlightRanges(in: sample)
        }

        guard let tokens = maybeTokens, !tokens.isEmpty else {
            XCTFail("Expected tokens from highlightRanges")
            return
        }

        // Basic expectations based on the highlights.scm queries:
        XCTAssertTrue(tokens.contains { $0.1 == .comment }, "expected comment token")
        XCTAssertTrue(tokens.contains { $0.1 == .string }, "expected string token")
        XCTAssertTrue(tokens.contains { $0.1 == .number }, "expected number token")
        XCTAssertTrue(tokens.contains { $0.1 == .function }, "expected function token")

        // Ensure ranges look valid
        for (range, _) in tokens {
            XCTAssertNotEqual(range.location, NSNotFound, "token range location should be valid")
            XCTAssertTrue(range.length > 0, "token range length should be > 0")
        }
    }

    func testHighlightRanges_repeatedCalls_areStable() async throws {
        try XCTSkipIf(
            !TreeSitterHighlighter.shared.isParserAvailable, "Tree-sitter parser not available")
        let sample = """
            // comment
            let s = "hello"
            let x = 42
            fun foo() { return 1 }
            """
        for _ in 0..<10 {
            let maybeTokens = await MainActor.run {
                TreeSitterHighlighter.shared.highlightRanges(in: sample)
            }
            guard let tokens = maybeTokens, !tokens.isEmpty else {
                XCTFail("Expected tokens from highlightRanges")
                return
            }
            XCTAssertTrue(tokens.contains { $0.1 == .comment }, "expected comment token")
            XCTAssertTrue(tokens.contains { $0.1 == .string }, "expected string token")
            XCTAssertTrue(tokens.contains { $0.1 == .number }, "expected number token")
        }
    }
}
