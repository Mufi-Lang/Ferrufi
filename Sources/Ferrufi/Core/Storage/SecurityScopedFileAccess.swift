//
//  SecurityScopedFileAccess.swift
//  Ferrufi
//
//  Created by Ferrufi Team
//

import Foundation

/// Helper for managing security-scoped file access on macOS
/// Required for accessing files outside the app's sandbox, even with entitlements
public actor SecurityScopedFileAccess {

    private var activeResources: [URL: Bool] = [:]

    public init() {}

    /// Start accessing a security-scoped resource
    /// Call this before reading/writing files selected by the user
    /// - Parameter url: The URL to access
    /// - Returns: True if access was granted, false otherwise
    public func startAccessing(_ url: URL) -> Bool {
        let accessed = url.startAccessingSecurityScopedResource()
        if accessed {
            activeResources[url] = true
        }
        return accessed
    }

    /// Stop accessing a security-scoped resource
    /// Call this when done with the file
    /// - Parameter url: The URL to stop accessing
    public func stopAccessing(_ url: URL) {
        if activeResources[url] == true {
            url.stopAccessingSecurityScopedResource()
            activeResources.removeValue(forKey: url)
        }
    }

    /// Perform an operation with security-scoped access
    /// Automatically manages start/stop access
    /// - Parameters:
    ///   - url: The URL to access
    ///   - operation: The operation to perform
    /// - Returns: The result of the operation
    public func withAccess<T>(_ url: URL, operation: () throws -> T) throws -> T {
        let accessed = startAccessing(url)
        defer {
            if accessed {
                stopAccessing(url)
            }
        }
        return try operation()
    }

    /// Perform an async operation with security-scoped access
    /// - Parameters:
    ///   - url: The URL to access
    ///   - operation: The async operation to perform
    /// - Returns: The result of the operation
    public func withAccess<T>(_ url: URL, operation: () async throws -> T) async throws -> T {
        let accessed = startAccessing(url)
        defer {
            if accessed {
                stopAccessing(url)
            }
        }
        return try await operation()
    }

    /// Create a bookmark for persistent access to a file
    /// - Parameter url: The URL to bookmark
    /// - Returns: Bookmark data that can be stored
    public func createBookmark(for url: URL) throws -> Data {
        return try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolve a bookmark to get the URL
    /// - Parameter bookmarkData: The bookmark data
    /// - Returns: The resolved URL with security scope
    public func resolveBookmark(_ bookmarkData: Data) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return url
    }

    /// Stop accessing all active resources
    /// Call this when cleaning up or app is terminating
    public func stopAccessingAll() {
        for (url, _) in activeResources {
            url.stopAccessingSecurityScopedResource()
        }
        activeResources.removeAll()
    }
}

/// Extension to make file operations security-scoped aware
extension URL {

    /// Perform a file read operation with automatic security scope management
    /// - Parameter operation: The operation to perform
    /// - Returns: The result of the operation
    public func withSecurityScope<T>(_ operation: (URL) throws -> T) throws -> T {
        let accessed = self.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try operation(self)
    }

    /// Perform an async file operation with automatic security scope management
    /// - Parameter operation: The async operation to perform
    /// - Returns: The result of the operation
    public func withSecurityScope<T>(_ operation: (URL) async throws -> T) async throws -> T {
        let accessed = self.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation(self)
    }
}

/// Helper extension for FileManager operations with security scope
extension FileManager {

    /// Read file contents with security scope
    /// - Parameter url: The file URL
    /// - Returns: The file contents as Data
    public func securityScopedRead(from url: URL) throws -> Data {
        try url.withSecurityScope { url in
            try Data(contentsOf: url)
        }
    }

    /// Write data to file with security scope
    /// - Parameters:
    ///   - data: The data to write
    ///   - url: The destination URL
    public func securityScopedWrite(_ data: Data, to url: URL) throws {
        try url.withSecurityScope { url in
            try data.write(to: url, options: .atomic)
        }
    }

    /// Read string from file with security scope
    /// - Parameter url: The file URL
    /// - Returns: The file contents as String
    public func securityScopedReadString(from url: URL, encoding: String.Encoding = .utf8) throws
        -> String
    {
        try url.withSecurityScope { url in
            try String(contentsOf: url, encoding: encoding)
        }
    }

    /// Write string to file with security scope
    /// - Parameters:
    ///   - string: The string to write
    ///   - url: The destination URL
    ///   - encoding: The string encoding
    public func securityScopedWriteString(
        _ string: String, to url: URL, encoding: String.Encoding = .utf8
    ) throws {
        try url.withSecurityScope { url in
            try string.write(to: url, atomically: true, encoding: encoding)
        }
    }
}

/// Example usage in FolderManager or FileStorage:
///
/// // When writing a file:
/// let fileURL = URL(fileURLWithPath: note.filePath)
/// try fileURL.withSecurityScope { url in
///     try content.write(to: url, atomically: true, encoding: .utf8)
/// }
///
/// // When reading a file:
/// let fileURL = URL(fileURLWithPath: path)
/// let content = try fileURL.withSecurityScope { url in
///     try String(contentsOf: url, encoding: .utf8)
/// }
///
/// // Or using FileManager extensions:
/// let content = try FileManager.default.securityScopedReadString(from: fileURL)
/// try FileManager.default.securityScopedWriteString(content, to: fileURL)
