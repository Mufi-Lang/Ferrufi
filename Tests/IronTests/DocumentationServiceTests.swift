import XCTest
@testable import Ferrufi

@MainActor
final class DocumentationServiceTests: XCTestCase {
    var service: DocumentationService!

    override func setUp() async throws {
        try await super.setUp()
        service = DocumentationService()
    }

    func testSearchSyntaxKeywords() async {
        let results = service.search(query: "keywords")
        XCTAssertFalse(results.isEmpty, "Should find at least one result for 'keywords'")
        XCTAssertEqual(results.first?.title, "Mufi Keywords")
        XCTAssertEqual(results.first?.category, .syntax)
    }

    func testSearchStdLibPrint() async {
        let results = service.search(query: "print")
        XCTAssertFalse(results.isEmpty, "Should find results for 'print'")
        XCTAssertTrue(results.contains { $0.title == "Standard Library: print" })
        XCTAssertEqual(results.first(where: { $0.title == "Standard Library: print" })?.category, .stdLib)
    }

    func testCaseInsensitiveSearch() async {
        let results = service.search(query: "KEYWORDS")
        XCTAssertFalse(results.isEmpty, "Search should be case-insensitive")
    }
}
