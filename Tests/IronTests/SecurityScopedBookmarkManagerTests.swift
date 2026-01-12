import XCTest

@testable import Ferrufi

/// Manual tests for SecurityScopedBookmarkManager
///
/// These tests are skipped by default. To run them locally, set:
///   SECURITY_BOOKMARK_TEST=1
/// Example:
///   SECURITY_BOOKMARK_TEST=1 swift test
///
/// Note:
/// - Security-scoped bookmarks often require user consent (NSOpenPanel) in sandboxed apps.
/// - This test creates a temporary directory and attempts to create/resolve a bookmark programmatically.
///   It is intended for manual, local validation (not CI).
@MainActor
final class SecurityScopedBookmarkManagerTests: XCTestCase {

    /// Manual: create a bookmark for a temp directory, resolve it, and read/write a file inside it.
    func testManualCreateResolveAndUseBookmark() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SECURITY_BOOKMARK_TEST"] == "1",
            "Manual test skipped by default. Set SECURITY_BOOKMARK_TEST=1 to run."
        )

        let manager = SecurityScopedBookmarkManager.shared

        // Create a temporary directory for the test
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ferrufi-ssb-test-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        // Cleanup (remove bookmark, stop access, delete tmp dir)
        defer {
            manager.removeBookmark(forPath: tmpDir.path)
            manager.stopAccessingAll()
            try? FileManager.default.removeItem(at: tmpDir)
        }

        // Create bookmark
        let created = manager.createBookmark(for: tmpDir)
        XCTAssertTrue(created, "createBookmark(for:) should succeed for a user-visible folder")

        // Resolve and start access
        let resolved = manager.resolveBookmark(forPath: tmpDir.path)
        XCTAssertNotNil(
            resolved,
            "resolveBookmark(forPath:) should return a URL and start access (check entitlements & permission)"
        )

        // Use withAccess to write/read a file inside the bookmarked folder
        let writeResult: Bool? = try manager.withAccess(toPath: tmpDir.path) { url in
            let testFile = url.appendingPathComponent("ssb-test.txt")
            let payload = "ferrufi-security-bookmark-test"
            try payload.write(to: testFile, atomically: true, encoding: .utf8)

            let readBack = try String(contentsOf: testFile, encoding: .utf8)
            XCTAssertEqual(readBack, payload, "File contents should match what was written")
            return true
        }

        XCTAssertEqual(
            writeResult, true, "withAccess should allow read/write inside the bookmarked folder")
    }
}
