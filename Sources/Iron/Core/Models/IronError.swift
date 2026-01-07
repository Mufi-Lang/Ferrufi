//
//  IronError.swift
//  Iron
//
//  Core error handling system for Iron app
//

import Foundation

/// Main error type for Iron application
public enum IronError: Error, LocalizedError, CustomStringConvertible, Sendable {
    // File system errors
    case fileNotFound(String)
    case fileAccessDenied(String)
    case fileCorrupted(String)
    case vaultNotFound(String)
    case invalidVaultStructure(String)
    case fileSystem(FileSystemError)

    // Note errors
    case noteNotFound(UUID)
    case noteAlreadyExists(String)
    case invalidNoteFormat(String)
    case noteParsingFailed(String, Error)

    // Search errors
    case searchIndexCorrupted
    case searchQueryInvalid(String)
    case indexingFailed(Error)

    // Configuration errors
    case configurationInvalid(String)
    case configurationSaveFailed(Error)
    case configurationLoadFailed(Error)

    // Graph errors
    case graphRenderingFailed(Error)
    case metalInitializationFailed(String)
    case graphDataInvalid(String)

    // Network/Sync errors (for future use)
    case networkUnavailable
    case syncFailed(Error)
    case authenticationFailed

    // General errors
    case unknown(Error)
    case operationCancelled
    case insufficientMemory
    case diskSpaceFull

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied for file: \(path)"
        case .fileCorrupted(let path):
            return "File is corrupted: \(path)"
        case .vaultNotFound(let path):
            return "Vault not found at: \(path)"
        case .invalidVaultStructure(let reason):
            return "Invalid vault structure: \(reason)"
        case .fileSystem(let error):
            return "File system error: \(error.localizedDescription)"

        case .noteNotFound(let id):
            return "Note not found with ID: \(id)"
        case .noteAlreadyExists(let title):
            return "Note already exists: \(title)"
        case .invalidNoteFormat(let reason):
            return "Invalid note format: \(reason)"
        case .noteParsingFailed(let path, let error):
            return "Failed to parse note at \(path): \(error.localizedDescription)"

        case .searchIndexCorrupted:
            return "Search index is corrupted and needs to be rebuilt"
        case .searchQueryInvalid(let query):
            return "Invalid search query: \(query)"
        case .indexingFailed(let error):
            return "Failed to index content: \(error.localizedDescription)"

        case .configurationInvalid(let reason):
            return "Invalid configuration: \(reason)"
        case .configurationSaveFailed(let error):
            return "Failed to save configuration: \(error.localizedDescription)"
        case .configurationLoadFailed(let error):
            return "Failed to load configuration: \(error.localizedDescription)"

        case .graphRenderingFailed(let error):
            return "Graph rendering failed: \(error.localizedDescription)"
        case .metalInitializationFailed(let reason):
            return "Metal initialization failed: \(reason)"
        case .graphDataInvalid(let reason):
            return "Invalid graph data: \(reason)"

        case .networkUnavailable:
            return "Network is unavailable"
        case .syncFailed(let error):
            return "Synchronization failed: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed"

        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .insufficientMemory:
            return "Insufficient memory to complete operation"
        case .diskSpaceFull:
            return "Insufficient disk space"
        }
    }

    public var description: String {
        return errorDescription ?? "Unknown error"
    }

    /// The underlying error if available
    public var underlyingError: Error? {
        switch self {
        case .noteParsingFailed(_, let error),
            .indexingFailed(let error),
            .configurationSaveFailed(let error),
            .configurationLoadFailed(let error),
            .graphRenderingFailed(let error),
            .syncFailed(let error),
            .unknown(let error):
            return error
        default:
            return nil
        }
    }

    /// Error severity level
    public var severity: ErrorSeverity {
        switch self {
        case .fileNotFound, .noteNotFound, .searchQueryInvalid:
            return .low
        case .fileCorrupted, .invalidNoteFormat, .noteParsingFailed, .configurationInvalid:
            return .medium
        case .vaultNotFound, .invalidVaultStructure, .searchIndexCorrupted,
            .metalInitializationFailed, .insufficientMemory, .diskSpaceFull:
            return .high
        case .unknown:
            return .critical
        default:
            return .medium
        }
    }

    /// Whether this error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .operationCancelled, .networkUnavailable, .searchQueryInvalid:
            return true
        case .insufficientMemory, .diskSpaceFull, .metalInitializationFailed:
            return false
        case .searchIndexCorrupted, .configurationInvalid:
            return true  // Can be fixed by rebuilding/resetting
        default:
            return true
        }
    }
}

/// Error severity levels
public enum ErrorSeverity: Int, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    public var emoji: String {
        switch self {
        case .low: return "ℹ️"
        case .medium: return "⚠️"
        case .high: return "❌"
        case .critical: return "🚨"
        }
    }
}

/// Error context for better debugging
public struct ErrorContext: Sendable {
    public let timestamp: Date
    public let component: String
    public let operation: String
    public let additionalInfo: [String: String]

    public init(
        component: String,
        operation: String,
        additionalInfo: [String: String] = [:]
    ) {
        self.timestamp = Date()
        self.component = component
        self.operation = operation
        self.additionalInfo = additionalInfo
    }
}

/// Result type for Iron operations
public typealias IronResult<T> = Result<T, IronError>

/// Protocol for error handling
public protocol ErrorHandler {
    func handle(_ error: IronError, context: ErrorContext?)
    func canRecover(from error: IronError) -> Bool
    func suggestRecovery(for error: IronError) -> RecoveryAction?
}

/// Recovery actions that can be suggested to users
public enum RecoveryAction: Sendable {
    case retry
    case rebuildIndex
    case resetConfiguration
    case restartApp
    case contactSupport
    case freeUpSpace
    case checkPermissions
    case custom(String)

    public var displayName: String {
        switch self {
        case .retry: return "Try Again"
        case .rebuildIndex: return "Rebuild Search Index"
        case .resetConfiguration: return "Reset Configuration"
        case .restartApp: return "Restart Application"
        case .contactSupport: return "Contact Support"
        case .freeUpSpace: return "Free Up Disk Space"
        case .checkPermissions: return "Check File Permissions"
        case .custom(let action): return action
        }
    }
}

/// Default error handler implementation
public class DefaultErrorHandler: ErrorHandler {
    public init() {}

    public func handle(_ error: IronError, context: ErrorContext? = nil) {
        let severity = error.severity
        let timestamp = context?.timestamp ?? Date()
        let component = context?.component ?? "Unknown"
        let operation = context?.operation ?? "Unknown"

        // Log the error
        print("\(severity.emoji) [\(severity.displayName)] \(timestamp): \(component).\(operation)")
        print("   Error: \(error.description)")

        if let underlyingError = error.underlyingError {
            print("   Underlying: \(underlyingError)")
        }

        if let additionalInfo = context?.additionalInfo, !additionalInfo.isEmpty {
            print("   Context: \(additionalInfo)")
        }

        // Suggest recovery if available
        if let recovery = suggestRecovery(for: error) {
            print("   Suggested action: \(recovery.displayName)")
        }
    }

    public func canRecover(from error: IronError) -> Bool {
        return error.isRecoverable
    }

    public func suggestRecovery(for error: IronError) -> RecoveryAction? {
        switch error {
        case .searchIndexCorrupted:
            return .rebuildIndex
        case .configurationInvalid, .configurationLoadFailed:
            return .resetConfiguration
        case .diskSpaceFull:
            return .freeUpSpace
        case .fileAccessDenied:
            return .checkPermissions
        case .networkUnavailable, .operationCancelled:
            return .retry
        case .metalInitializationFailed, .insufficientMemory:
            return .restartApp
        case .unknown:
            return .contactSupport
        default:
            return error.isRecoverable ? .retry : nil
        }
    }
}

// MARK: - Convenience Extensions

extension IronError {
    /// Creates an error with context
    public static func withContext(
        _ error: IronError,
        component: String,
        operation: String,
        additionalInfo: [String: String] = [:]
    ) -> (error: IronError, context: ErrorContext) {
        let context = ErrorContext(
            component: component,
            operation: operation,
            additionalInfo: additionalInfo
        )
        return (error, context)
    }
}

extension Result where Failure == IronError {
    /// Maps an error to include context
    public func mapErrorWithContext(
        component: String,
        operation: String,
        additionalInfo: [String: String] = [:]
    ) -> (result: Result<Success, IronError>, context: ErrorContext?) {
        switch self {
        case .success(let value):
            return (.success(value), nil)
        case .failure(let error):
            let context = ErrorContext(
                component: component,
                operation: operation,
                additionalInfo: additionalInfo
            )
            return (.failure(error), context)
        }
    }
}

/// File system specific errors
public enum FileSystemError: Error, LocalizedError, Sendable {
    case invalidPath(String)
    case readError(String)
    case writeError(String)
    case permissionDenied(String)
    case fileExists(String)
    case directoryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .readError(let message):
            return "Read error: \(message)"
        case .writeError(let message):
            return "Write error: \(message)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .fileExists(let path):
            return "File already exists: \(path)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        }
    }
}
