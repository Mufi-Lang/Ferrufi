//
//  Version.swift
//  Ferrufi
//
//  Created by build system
//  Copyright © 2024 Ferrufi. All rights reserved.
//

import Foundation

/// Application version information
public struct AppVersion {
    /// Major version number
    public static let major = 0

    /// Minor version number
    public static let minor = 0

    /// Patch version number
    public static let patch = 0

    /// Build number (optional, can be set by CI/CD)
    public static let build: String? = nil

    /// Full version string (e.g., "1.0.0" or "1.0.0-123")
    public static var versionString: String {
        var version = "\(major).\(minor).\(patch)"
        if let build = build, !build.isEmpty {
            version += "-\(build)"
        }
        return version
    }

    /// Short version string (e.g., "1.0.0")
    public static var shortVersionString: String {
        return "\(major).\(minor).\(patch)"
    }

    /// Full version with build info (e.g., "Ferrufi 1.0.0 (123)")
    public static var fullVersionString: String {
        if let build = build, !build.isEmpty {
            return "Ferrufi \(shortVersionString) (\(build))"
        }
        return "Ferrufi \(shortVersionString)"
    }

    /// Copyright notice
    public static let copyright = "Copyright © 2024 Ferrufi Contributors"

    /// Minimum supported macOS version
    public static let minimumMacOSVersion = "14.0"
}

// MARK: - Version Comparison

extension AppVersion {
    /// Compare with another version string
    /// - Parameter versionString: Version string to compare (e.g., "1.0.0")
    /// - Returns: true if current version is greater than or equal to the provided version
    public static func isAtLeast(_ versionString: String) -> Bool {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 3 else { return false }

        if major > components[0] { return true }
        if major < components[0] { return false }

        if minor > components[1] { return true }
        if minor < components[1] { return false }

        return patch >= components[2]
    }
}

// MARK: - Build Information

extension AppVersion {
    /// Git commit SHA (set by build system)
    public static var gitCommitSHA: String? {
        // This can be set during build time using build settings
        // For now, return nil - build script can inject this
        return nil
    }

    /// Build date
    public static var buildDate: String {
        // This gets compiled in at build time
        return "\(#file)".contains("Debug") ? "Debug Build" : "Release Build"
    }

    /// All version information as a dictionary
    public static var info: [String: String] {
        var dict: [String: String] = [
            "version": versionString,
            "shortVersion": shortVersionString,
            "major": "\(major)",
            "minor": "\(minor)",
            "patch": "\(patch)",
            "copyright": copyright,
            "minimumMacOS": minimumMacOSVersion,
        ]

        if let build = build {
            dict["build"] = build
        }

        if let sha = gitCommitSHA {
            dict["gitCommit"] = sha
        }

        return dict
    }
}
