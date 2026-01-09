import XCTest

@testable import Iron

final class ShortcutsTests: XCTestCase {

    func testUpdateBindingAndQuery() throws {
        let sm = ShortcutsManager.shared
        sm.resetToDefaults()

        let binding = KeyBinding(key: "x", modifiers: ["cmd"])
        try sm.updateBinding("newNote", to: binding)

        XCTAssertEqual(sm.binding(for: "newNote")?.key, "x")
        XCTAssertEqual(sm.binding(for: "newNote")?.modifiers.sorted(), ["cmd"])

        sm.resetToDefaults()
    }

    func testDuplicateBindingThrowsError() throws {
        let sm = ShortcutsManager.shared
        sm.resetToDefaults()

        let binding = KeyBinding(key: "y", modifiers: ["cmd"])
        try sm.updateBinding("newNote", to: binding)

        XCTAssertThrowsError(try sm.updateBinding("newFolder", to: binding)) { error in
            if let e = error as? ShortcutsManager.ShortcutError {
                switch e {
                case .duplicateBinding(let conflicts):
                    XCTAssertTrue(conflicts.contains("newNote"))
                default:
                    XCTFail("Unexpected error type: \(e)")
                }
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }

        sm.resetToDefaults()
    }

    func testConflictsList() throws {
        let sm = ShortcutsManager.shared
        sm.resetToDefaults()

        let binding = KeyBinding(key: "z", modifiers: ["cmd"])
        try sm.updateBinding("newNote", to: binding)

        let conflicts = sm.conflicts(with: binding)
        XCTAssertTrue(conflicts.contains("newNote"))

        sm.resetToDefaults()
    }

    func testResetToDefaults() throws {
        let sm = ShortcutsManager.shared
        sm.resetToDefaults()

        let original = sm.binding(for: "newNote")
        let binding = KeyBinding(key: "q", modifiers: ["cmd"])
        try sm.updateBinding("newNote", to: binding, allowDuplicate: true)

        XCTAssertEqual(sm.binding(for: "newNote")?.key, "q")

        sm.resetToDefaults()
        XCTAssertEqual(sm.binding(for: "newNote")?.key, original?.key)
    }
}
