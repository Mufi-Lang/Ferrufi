//
//  LaunchAtLoginManager.swift
//  Iron
//
//  Simple manager to enable/disable launching the app at user login by
//  creating/removing a LaunchAgent plist in ~/Library/LaunchAgents.
//
//  Note:
//  - This approach writes a LaunchAgent plist that uses `/usr/bin/open -a <AppBundle>`
//    so it works for typical macOS app bundles. It intentionally avoids helper
//    app / ServiceManagement complexities for a minimal, cross-build-friendly implementation.
//  - It does not call `launchctl` to immediately bootstrap/unbootstrap the agent;
//    the LaunchAgent will take effect on next login. If immediate activation is required,
//    this can be added later with proper error handling and user consent.
//

import Foundation
import AppKit

public enum LaunchAtLoginError: LocalizedError {
    case unableToCreateDirectory
    case unableToWritePlist(Error)
    case unableToRemovePlist(Error)
    case invalidBundlePath

    public var errorDescription: String? {
        switch self {
        case .unableToCreateDirectory:
            return "Failed to create the LaunchAgents directory"
        case .unableToWritePlist(let err):
            return "Failed to write launch agent plist: \(err.localizedDescription)"
        case .unableToRemovePlist(let err):
            return "Failed to remove launch agent plist: \(err.localizedDescription)"
        case .invalidBundlePath:
            return "Unable to determine the application bundle path"
        }
    }
}

@MainActor
public final class LaunchAtLoginManager {
    public static let shared = LaunchAtLoginManager()

    // Choose a label for the LaunchAgent; prefer the app bundle identifier if available
    private var label: String {
        if let id = Bundle.main.bundleIdentifier, !id.isEmpty {
            return "\(id).launchatlogin"
        }
        return "com.iron.launchatlogin"
    }

    private var plistURL: URL {
        let launchAgentsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)

        return launchAgentsDir.appendingPathComponent("\(label).plist")
    }

    private init() {}

    /// Returns whether a launch agent plist exists for the current app and appears to point
    /// to the current bundle.
    public func isEnabled() -> Bool {
        let url = plistURL
        guard FileManager.default.fileExists(atPath: url.path) else { return false }

        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any]
        else {
            return false
        }

        if let progArgs = dict["ProgramArguments"] as? [String],
           progArgs.contains("/usr/bin/open"),
           progArgs.contains(Bundle.main.bundlePath) {
            return true
        }

        return false
    }

    /// Enables or disables launching at login by creating/removing a LaunchAgent plist.
    /// - Parameter enabled: true to enable, false to disable.
    /// - Throws: `LaunchAtLoginError` on failure.
    public func setEnabled(_ enabled: Bool) async throws {
        // Ensure an actual suspension point exists so callers using `try await` do not emit
        // the \"no async operations occur within 'await' expression\" warning.
        await Task.yield()
        let fm = FileManager.default
        let launchAgentsDir = plistURL.deletingLastPathComponent()

        // Ensure the directory exists
        if !fm.fileExists(atPath: launchAgentsDir.path) {
            do {
                try fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            } catch {
                throw LaunchAtLoginError.unableToCreateDirectory
            }
        }

        guard !Bundle.main.bundlePath.isEmpty else {
            throw LaunchAtLoginError.invalidBundlePath
        }

        if enabled {
            // ProgramArguments: open the app bundle using `open -a <bundlePath>`
            let programArguments: [String] = ["/usr/bin/open", "-a", Bundle.main.bundlePath]

            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": programArguments,
                "RunAtLoad": true,
                "KeepAlive": false
            ]

            do {
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: plistURL, options: .atomic)
            } catch {
                throw LaunchAtLoginError.unableToWritePlist(error)
            }
        } else {
            if fm.fileExists(atPath: plistURL.path) {
                do {
                    try fm.removeItem(at: plistURL)
                } catch {
                    throw LaunchAtLoginError.unableToRemovePlist(error)
                }
            }
        }
    }
}
