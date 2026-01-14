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

    /// Shared singleton instance for app-wide access
    public static let shared = SecurityScopedBookmarkManager()

    private let userDefaults = UserDefaults.standard
    private let bookmarkKey = "com.ferrufi.securityScopedBookmarks"

    /// Active security-scoped resources that need to be stopped on cleanup
    private var activeResources: [URL: Bool] = [:]

    public init() {
        #if os(macOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppWillTerminate(_:)),
                name: NSApplication.willTerminateNotification,
                object: nil
            )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleAppWillTerminate(_ notification: Notification) {
        stopAccessingAll()
    }

    // MARK: - Bookmark Management

    /// Creates and stores a security-scoped bookmark for a URL
    /// - Parameter url: The URL to bookmark (must be user-selected via NSOpenPanel)
    /// - Returns: True if bookmark was successfully created and stored
    @discardableResult
    public func createBookmark(for url: URL) -> Bool {
        do {
            // Create a security-scoped bookmark that allows full security scope.
            // Omitting `.securityScopeAllowOnlyReadAccess` ensures the bookmark
            // can be used for write operations when the OS grants the scope.
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            var bookmarks = loadBookmarks()
            let key = canonicalKey(forPath: url.path)
            bookmarks[key] = bookmarkData
            saveBookmarks(bookmarks)

            print("✅ Created security-scoped bookmark for: \(url.path)")
            DiagnosticsLogger.shared.logBookmarkEvent(
                "create", key: key, success: true, details: "created bookmark for \(url.path)")
            return true
        } catch {
            print("❌ Failed to create bookmark for \(url.path): \(error)")
            DiagnosticsLogger.shared.logError("Failed to create bookmark for \(url.path): \(error)")
            return false
        }
    }

    /// Resolves a bookmark and starts accessing the security-scoped resource
    /// - Parameter path: The file path that was bookmarked
    /// - Returns: The resolved URL with active security scope, or nil if failed
    public func resolveBookmark(forPath path: String) -> URL? {
        let bookmarks = loadBookmarks()
        let normalizedKey = canonicalKey(forPath: path)

        // Try normalized key first, then raw path lookup as a fallback
        var bookmarkData = bookmarks[normalizedKey] ?? bookmarks[path]

        // Fallback: try to find any stored key whose normalized form exactly matches the normalizedKey.
        // This handles cases where a bookmark was stored under a previously non-normalized key.
        if bookmarkData == nil {
            for (storedKey, data) in bookmarks {
                let storedNormalized = canonicalKey(forPath: storedKey)
                if storedNormalized == normalizedKey {
                    bookmarkData = data
                    // Migrate the stored key to the normalized key to make future lookups direct
                    var updated = bookmarks
                    updated[normalizedKey] = data
                    updated.removeValue(forKey: storedKey)
                    saveBookmarks(updated)
                    print("ℹ️ Migrated bookmark key '\(storedKey)' -> '\(normalizedKey)'")
                    DiagnosticsLogger.shared.logBookmarkEvent(
                        "migrate", key: storedKey, success: true,
                        details: "migrated -> \(normalizedKey)")
                    break
                }
            }
        }

        // If no exact match found, try to locate a parent bookmark that covers the requested path.
        // Choose the longest storedNormalized that is a prefix of normalizedKey (i.e., the closest parent).
        if bookmarkData == nil {
            var bestMatchData: Data? = nil
            var bestMatchKey: String? = nil
            for (storedKey, data) in bookmarks {
                let storedNormalized = canonicalKey(forPath: storedKey)
                if normalizedKey.hasPrefix(storedNormalized) {
                    if let bestKey = bestMatchKey {
                        if storedNormalized.count > bestKey.count {
                            bestMatchKey = storedNormalized
                            bestMatchData = data
                        }
                    } else {
                        bestMatchKey = storedNormalized
                        bestMatchData = data
                    }
                }
            }
            if let chosen = bestMatchData, let chosenKey = bestMatchKey {
                // We can optionally migrate the chosen parent's bookmark to a normalized mapping
                // for clarity, but keep the original mapping too (avoid deleting parent's original entry).
                var updated = bookmarks
                updated[chosenKey] = chosen
                saveBookmarks(updated)
                bookmarkData = chosen
                print("ℹ️ Using parent bookmark '\(chosenKey)' for path '\(normalizedKey)'")
                DiagnosticsLogger.shared.logBookmarkEvent(
                    "use_parent", key: chosenKey, success: true,
                    details: "used parent for \(normalizedKey)")
            }
        }

        guard let bookmarkDataUnwrapped = bookmarkData else {
            print("⚠️ No bookmark found for path: \(path) (normalized: \(normalizedKey))")
            DiagnosticsLogger.shared.logPermissionEvent(
                "no_bookmark", path: path, details: "normalized=\(normalizedKey)")
            return nil
        }

        do {
            var isStale = false
            let baseURL = try URL(
                resolvingBookmarkData: bookmarkDataUnwrapped,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Start accessing the resolved (base) security-scoped resource
            let accessed = baseURL.startAccessingSecurityScopedResource()
            if accessed {
                activeResources[baseURL] = true
                print(
                    "✅ Resolved and accessing bookmark base: \(baseURL.path) for requested path: \(path)"
                )
                DiagnosticsLogger.shared.logBookmarkEvent(
                    "resolve", key: baseURL.path, success: true, details: "resolved for \(path)")
            } else {
                print("⚠️ Failed to start accessing security-scoped resource base: \(baseURL.path)")
                DiagnosticsLogger.shared.logBookmarkEvent(
                    "resolve", key: baseURL.path, success: false,
                    details: "failed to startAccessing for \(path)")
                return nil
            }

            // If the stored bookmark corresponds to a parent directory of the requested path,
            // return a child URL under the base so callers can operate against the exact
            // workspace path while the active security scope lives on the parent.
            let baseNormalized = canonicalKey(forPath: baseURL.path)
            if normalizedKey.hasPrefix(baseNormalized) {
                // compute relative suffix
                var relative = String(path.dropFirst(baseNormalized.count))
                if relative.hasPrefix("/") { relative.removeFirst() }
                if relative.isEmpty {
                    return baseURL
                } else {
                    let child = baseURL.appendingPathComponent(relative)
                    // Note: we keep the active scope on baseURL; child operations should succeed
                    // while the parent scope is active.
                    return child
                }
            }

            // Otherwise return the base URL directly
            if isStale {
                DiagnosticsLogger.shared.logBookmarkEvent(
                    "stale", key: baseURL.path, success: false,
                    details: "bookmark stale for \(path)")
            }
            return baseURL
        } catch {
            print("❌ Failed to resolve bookmark for \(path): \(error)")
            DiagnosticsLogger.shared.logError("Failed to resolve bookmark for \(path): \(error)")

            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == 259 {
                print("⚠️ Corrupt bookmark detected for path \(path), removing bookmark")
                DiagnosticsLogger.shared.logBookmarkEvent(
                    "corrupt", key: path, success: false, details: "corrupt bookmark")
                removeBookmark(forPath: path)
            }

            return nil
        }
    }

    // validateBookmark removed in minimalist API; use resolveBookmark(forPath:) which returns a URL? when access is active.

    /// Removes a bookmark for a given path
    /// - Parameter path: The file path to remove bookmark for
    public func removeBookmark(forPath path: String) {
        let key = canonicalKey(forPath: path)
        var bookmarks = loadBookmarks()
        if bookmarks.removeValue(forKey: key) != nil {
            saveBookmarks(bookmarks)
            print("🗑️ Removed bookmark for: \(path) (normalized: \(key))")
            return
        }

        if bookmarks.removeValue(forKey: path) != nil {
            saveBookmarks(bookmarks)
            print("🗑️ Removed bookmark for raw path: \(path)")
        } else {
            print("⚠️ No bookmark found to remove for: \(path)")
        }
    }

    /// Checks if a bookmark exists for the given path
    /// - Parameter path: The file path to check
    /// - Returns: True if a bookmark exists
    public func hasBookmark(forPath path: String) -> Bool {
        let key = canonicalKey(forPath: path)
        let bookmarks = loadBookmarks()
        return bookmarks[key] != nil || bookmarks[path] != nil
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

    // debugValidateAllBookmarks removed in minimalist API.

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

    /// Normalize a path to a canonical key used for storing bookmarks.
    /// Expands tilde and returns the standardized file URL path.
    private func canonicalKey(forPath path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        return url.path
    }

    // MARK: - Helper Methods

    /// Requests user to select a folder and creates a bookmark for it
    /// - Parameters:
    ///   - presentingWindow: Optional NSWindow to present the panel as a sheet (preferred)
    ///   - message: The message to show in the open panel
    ///   - defaultDirectory: Optional directory to open the panel in (defaults to nil)
    ///   - showHidden: If true, the open panel will display hidden files/folders
    ///   - completion: Called with the selected URL (with active security scope) or nil on failure
    public func requestFolderAccess(
        presentingWindow: NSWindow? = nil,
        message: String = "Select a folder to grant Ferrufi access",
        defaultDirectory: URL? = nil,
        showHidden: Bool = false,
        completion: @escaping (URL?) -> Void
    ) {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Grant Access"
            panel.message = message

            // Use the provided default directory if available
            if let dir = defaultDirectory {
                panel.directoryURL = dir
            }

            // Optionally show hidden files (e.g. allow selecting `.ferrufi`)
            if showHidden {
                panel.setValue(true, forKey: "showsHiddenFiles")
            }

            // Handler that will be used for sheet or standalone presentation
            // Simplified: start the security scope immediately, then store the bookmark.
            // This follows the \"fail fast\" snippet pattern — if starting access fails,
            // we don't persist anything and return failure to the caller.
            let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
                guard let self = self else { return }

                if response == .OK, let url = panel.url {
                    DiagnosticsLogger.shared.logPermissionEvent(
                        "panel_accept", path: url.path, details: "user approved in NSOpenPanel")
                    // Start security-scoped access immediately (fail fast)
                    if url.startAccessingSecurityScopedResource() {
                        // Persist bookmark using existing helper (keeps canonical keys)
                        let created = self.createBookmark(for: url)
                        if created {
                            // Track the active resource so stopAccessing() can clean it up later
                            self.activeResources[url] = true
                            print("✅ Granted and stored security-scoped bookmark for: \(url.path)")
                            DiagnosticsLogger.shared.logBookmarkEvent(
                                "request_grant", key: url.path, success: true,
                                details: "user granted via panel")
                            completion(url)
                        } else {
                            // Failed to persist bookmark; stop access and report failure
                            DiagnosticsLogger.shared.logError(
                                "Failed to persist bookmark after user approved for \(url.path)")
                            url.stopAccessingSecurityScopedResource()
                            completion(nil)
                        }
                    } else {
                        // Could not start security scope (user denied or OS blocked)
                        DiagnosticsLogger.shared.logPermissionEvent(
                            "start_access_failed", path: url.path,
                            details: "startAccessingSecurityScopedResource failed")
                        completion(nil)
                    }
                } else {
                    DiagnosticsLogger.shared.logPermissionEvent(
                        "panel_cancel", details: "user cancelled NSOpenPanel or no url")
                    completion(nil)
                }
            }

            if let window = presentingWindow {
                panel.beginSheetModal(for: window, completionHandler: handler)
            } else {
                panel.begin(completionHandler: handler)
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
                    "Ferrufi needs access to: \(path)\n\nPlease select this folder to grant access.",
                defaultDirectory: URL(fileURLWithPath: path),
                showHidden: false
            ) { [weak self] url in
                if let url = url {
                    // URL has an active security scope already
                    completion(url)
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
    @available(*, deprecated, message: "Use migrateWorkspacePath instead")
    public func migrateVaultPath(_ vaultPath: String, completion: @escaping (Bool) -> Void) {
        // Deprecated compatibility shim that calls the new API.
        migrateWorkspacePath(vaultPath, completion: completion)
    }

    /// - Parameter workspacePath: The current workspace path
    /// - Returns: True if bookmark exists or was created, false if user denied
    public func migrateWorkspacePath(_ workspacePath: String, completion: @escaping (Bool) -> Void)
    {
        // Check if we already have a bookmark
        if hasBookmark(forPath: workspacePath) {
            completion(true)
            return
        }

        // Check if the path exists
        guard FileManager.default.fileExists(atPath: workspacePath) else {
            completion(false)
            return
        }

        // Request access to the folder
        ensureAccess(toPath: workspacePath, requestIfNeeded: true) { url in
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
