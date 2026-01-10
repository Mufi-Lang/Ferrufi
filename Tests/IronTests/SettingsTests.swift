/*
 SettingsTests.swift
 IronTests

 Basic tests for default general settings and configuration behavior.
*/

import XCTest
@testable import Ferrufi

@MainActor
final class SettingsTests: XCTestCase {

    func testDefaultGeneralSettings() {
        let cm = ConfigurationManager()

        // Verify defaults
        XCTAssertFalse(cm.general.launchAtLogin, "Launch at login should be disabled by default")
        XCTAssertTrue(cm.general.confirmBeforeQuit, "Confirm-before-quit should be enabled by default")
        XCTAssertTrue(cm.general.autoUpdateEnabled, "Auto-update should be enabled by default")
        XCTAssertEqual(cm.general.startupBehavior, StartupBehavior.restore, "Default startup behavior should be 'restore'")
        XCTAssertNil(cm.general.startupNoteId, "No startup note should be selected by default")
    }

    func testResetToDefaultsRestoresGeneral() {
        let cm = ConfigurationManager()

        // Mutate values away from defaults
        cm.updateConfiguration { config in
            config.general.launchAtLogin = true
            config.general.confirmBeforeQuit = false
            config.general.autoUpdateEnabled = false
            config.general.startupBehavior = .specific
            config.general.startupNoteId = UUID()
        }

        // Sanity check that changes took effect
        XCTAssertTrue(cm.general.launchAtLogin)
        XCTAssertFalse(cm.general.confirmBeforeQuit)
        XCTAssertFalse(cm.general.autoUpdateEnabled)
        XCTAssertEqual(cm.general.startupBehavior, .specific)
        XCTAssertNotNil(cm.general.startupNoteId)

        // Reset to defaults and verify values are restored
        cm.resetToDefaults()
        XCTAssertFalse(cm.general.launchAtLogin)
        XCTAssertTrue(cm.general.confirmBeforeQuit)
        XCTAssertTrue(cm.general.autoUpdateEnabled)
        XCTAssertEqual(cm.general.startupBehavior, StartupBehavior.restore)
        XCTAssertNil(cm.general.startupNoteId)
    }

    func testRecentNoteIdsSetAndClear() {
        let cm = ConfigurationManager()

        let u1 = UUID()
        let u2 = UUID()

        cm.recentNoteIds = [u1, u2]
        XCTAssertEqual(cm.recentNoteIds, [u1, u2], "recentNoteIds should reflect values that were set")

        cm.recentNoteIds = nil
        XCTAssertNil(cm.recentNoteIds, "recentNoteIds should be nil after clearing")
    }
}
