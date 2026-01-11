//
//  SecurityScopedBookmarkManager.swift
//  Ferrufi
//
//  Created by Ferrufi Team
//

import AppKit
import Foundation

/// Manages security-scoped bookmarks for persistent file access across app launches
/// This is crucial for apps installed in /Applications to access user-selected folders
@MainActor
public class SecurityScopedBookmarkManager: ObservableObject {

    private let userDefaults = UserDefaults.standard
    private let bookmarkKey = "com.ferrufi.securityScopedBookmarks"

    /// Active security-scoped resources that need to be stopped on cleanup
    private var activeResources: [URL: Bool] = [:]

    public init() {}

    // MARK: - Bookmark Management

    /// Creates and stores a security-scoped bookmark for a URL
    /// - Parameter url: The URL to bookmark (must be user-selected via NSOpenPanel)
    /// - Returns: True if bookmark was successfully created and stored
    @discardableResult
    public func createBookmark(for url: URL) -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            var bookmarks = loadBookmarks()
            bookmarks[url.path] = bookmarkData
            saveBookmarks(bookmarks)

            print("✅ Created security-scoped bookmark for: \(url.path)")
            return true
        } catch {
            print("❌ Failed to create bookmark for \(url.path): \(error)")
            return false
        }
    }

    /// Resolves a bookmark and starts accessing the security-scoped resource
    /// - Parameter path: The file path that was bookmarked
    /// - Returns: The resolved URL with active security scope, or nil if failed
    public func resolveBookmark(forPath path: String) -> URL? {
        let bookmarks = loadBookmarks()

        guard let bookmarkData = bookmarks[path] else {
            print("⚠️ No bookmark found for path: \(path)")
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Start accessing the security-scoped resource
            let accessed = url.startAccessingSecurityScopedResource()
            if accessed {
                activeResources[url] = true
                print("✅ Resolved and accessing bookmark for: \(path)")
            } else {
                print("⚠️ Failed to start accessing security-scoped resource: \(path)")
            }

            // If bookmark is stale, recreate it
            if isStale {
                print("⚠️ Bookmark is stale, recreating for: \(path)")
                createBookmark(for: url)
            }

            return url
        } catch {
            print("❌ Failed to resolve bookmark for \(path): \(error)")
            return nil
        }
    }

    /// Removes a bookmark for a given path
    /// - Parameter path: The file path to remove bookmark for
    public func removeBookmark(forPath path: String) {
        var bookmarks = loadBookmarks()
        bookmarks.removeValue(forKey: path)
        saveBookmarks(bookmarks)
        print("🗑️ Removed bookmark for: \(path)")
    }

    /// Checks if a bookmark exists for the given path
    /// - Parameter path: The file path to check
    /// - Returns: True if a bookmark exists
    public func hasBookmark(forPath path: String) -> Bool {
        let bookmarks = loadBookmarks()
        return bookmarks[path] != nil
    }

    /// Gets all bookmarked paths
    /// - Returns: Array of all bookmarked file paths
    public func allBookmarkedPaths() -> [String] {
        return Array(loadBookmarks().keys)
    }

    /// Clears all stored bookmarks
    public func clearAllBookmarks() {
        userDefaults.removeObject(forKey: bookmarkKey)
        print("🗑️ Cleared all security-scoped bookmarks")
    }

    // MARK: - Resource Access Management

    /// Stops accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    public func stopAccessing(_ url: URL) {
        if activeResources[url] == true {
            url.stopAccessingSecurityScopedResource()
            activeResources.removeValue(forKey: url)
            print("🛑 Stopped accessing security-scoped resource: \(url.path)")
        }
    }

    /// Stops accessing all active security-scoped resources
    /// Call this when app is terminating or cleaning up
    public func stopAccessingAll() {
        for (url, _) in activeResources {
            url.stopAccessingSecurityScopedResource()
        }
        activeResources.removeAll()
        print("🛑 Stopped accessing all security-scoped resources")
    }

    // MARK: - Persistence

    private func loadBookmarks() -> [String: Data] {
        guard let data = userDefaults.data(forKey: bookmarkKey),
            let bookmarks = try? JSONDecoder().decode([String: Data].self, from: data)
        else {
            return [:]
        }
        return bookmarks
    }

    private func saveBookmarks(_ bookmarks: [String: Data]) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            userDefaults.set(data, forKey: bookmarkKey)
        }
    }

    // MARK: - Helper Methods

    /// Requests user to select a folder and creates a bookmark for it
    /// - Parameter completion: Called with the selected URL and whether bookmark was created
    public func requestFolderAccess(
        message: String = "Select a folder to grant Ferrufi access",
        completion: @escaping (URL?, Bool) -> Void
    ) {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Grant Access"
            panel.message = message

            panel.begin { [weak self] response in
                guard let self = self else { return }

                if response == .OK, let url = panel.url {
                    let bookmarkCreated = self.createBookmark(for: url)
                    completion(url, bookmarkCreated)
                } else {
                    completion(nil, false)
                }
            }
        #else
            completion(nil, false)
        #endif
    }

    /// Ensures access to a folder path, requesting if needed
    /// - Parameters:
    ///   - path: The folder path to access
    ///   - requestIfNeeded: If true, shows folder picker if no bookmark exists
    ///   - completion: Called with the URL (with active security scope) or nil
    public func ensureAccess(
        toPath path: String,
        requestIfNeeded: Bool = true,
        completion: @escaping (URL?) -> Void
    ) {
        // First try to resolve existing bookmark
        if let url = resolveBookmark(forPath: path) {
            completion(url)
            return
        }

        // If no bookmark and we should request, show folder picker
        if requestIfNeeded {
            requestFolderAccess(
                message:
                    "Ferrufi needs access to: \(path)\n\nPlease select this folder to grant access."
            ) { [weak self] url, bookmarkCreated in
                if let url = url, bookmarkCreated {
                    // Resolve the newly created bookmark to start accessing
                    let resolvedURL = self?.resolveBookmark(forPath: url.path)
                    completion(resolvedURL)
                } else {
                    completion(nil)
                }
            }
        } else {
            completion(nil)
        }
    }

    // MARK: - Migration Helper

    /// Migrates existing vault path to use security-scoped bookmarks
    /// Call this once on app startup to ensure existing users get prompted
    /// - Parameter vaultPath: The current vault path
    /// - Returns: True if bookmark exists or was created, false if user denied
    public func migrateVaultPath(_ vaultPath: String, completion: @escaping (Bool) -> Void) {
        // Check if we already have a bookmark
        if hasBookmark(forPath: vaultPath) {
            completion(true)
            return
        }

        // Check if the path exists
        guard FileManager.default.fileExists(atPath: vaultPath) else {
            completion(false)
            return
        }

        // Request access to the folder
        ensureAccess(toPath: vaultPath, requestIfNeeded: true) { url in
            completion(url != nil)
        }
    }
}

// MARK: - Convenience Extensions

extension SecurityScopedBookmarkManager {

    /// Performs an operation with automatic security scope management
    /// - Parameters:
    ///   - path: The file path to access
    ///   - operation: The operation to perform with the URL
    /// - Returns: The result of the operation, or nil if access failed
    public func withAccess<T>(
        toPath path: String,
        operation: (URL) throws -> T
    ) rethrows -> T? {
        guard let url = resolveBookmark(forPath: path) else {
            return nil
        }

        defer {
            stopAccessing(url)
        }

        return try operation(url)
    }

    /// Performs an async operation with automatic security scope management
    /// - Parameters:
    ///   - path: The file path to access
    ///   - operation: The async operation to perform with the URL
    /// - Returns: The result of the operation, or nil if access failed
    public func withAccess<T>(
        toPath path: String,
        operation: (URL) async throws -> T
    ) async rethrows -> T? {
        guard let url = resolveBookmark(forPath: path) else {
            return nil
        }

        defer {
            stopAccessing(url)
        }

        return try await operation(url)
    }
}
