import XCTest
@testable import Ferrufi

final class MufiRuntimeServiceTests: XCTestCase {
    
    override func setUp() async throws {
        _ = try? await MufiBridge.shared.initialize()
    }
    
    func testFormatSource() async throws {
        let source = "var x=10+20;"
        let formatted = try await MufiRuntimeService.shared.formatSource(source)
        XCTAssertNotNil(formatted)
        XCTAssertTrue(formatted!.contains("var x = 10 + 20;"))
    }
    
    func testCreateNewProject() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let projectName = "test_project"
        let projectPath = tempDir.path
        
        try await MufiRuntimeService.shared.createNewProject(name: projectName, at: projectPath)
        
        let projectDir = tempDir.appendingPathComponent(projectName)
        let zonFile = projectDir.appendingPathComponent("mufi.zon")
        let mainMufi = projectDir.appendingPathComponent("src/main.mufi")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: zonFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: mainMufi.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
}