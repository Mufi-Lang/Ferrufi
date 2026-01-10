import XCTest

@testable import Ferrufi

final class MufiTests: XCTestCase {

    /// Tests that the embedded Mufi runtime can be initialized and that interpreting
    /// a simple `print(...)` statement returns a zero status and captures the printed output.
    func testInitializeAndInterpretPrints() async throws {
        // Initialize the runtime (ignore if already initialized).
        _ = try? await MufiBridge.shared.initialize(
            enableLeakDetection: false, enableTracking: false, enableSafety: true)

        // Run a simple print statement and assert we received the printed output.
        let (status, output) = try await MufiBridge.shared.interpret("print(\"Hello, Test!\")")
        XCTAssertEqual(status, 0, "Expected interpret status 0 on successful run, got \(status)")
        XCTAssertTrue(
            output.contains("Hello, Test!"),
            "Expected output to contain printed text; got: \"\(output)\"")

        // Deinitialize to avoid leaving the runtime initialized for other tests.
        await MufiBridge.shared.deinitialize()
    }

    /// Tests that malformed code yields a non-zero status and some error output.
    func testInterpretMalformedCodeReturnsError() async throws {
        _ = try? await MufiBridge.shared.initialize()

        // Deliberately malformed code to provoke a compile/runtime error.
        let (status, output) = try await MufiBridge.shared.interpret("var a = ;")
        XCTAssertNotEqual(status, 0, "Expected non-zero status for malformed code")
        XCTAssertFalse(
            output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Expected non-empty error output when interpreting malformed code")

        await MufiBridge.shared.deinitialize()
    }
}
