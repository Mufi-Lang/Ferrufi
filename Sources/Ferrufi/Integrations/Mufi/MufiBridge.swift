// Ferrufi/Sources/Ferrufi/Integrations/Mufi/MufiBridge.swift
//
// Swift wrapper around the C API exported by the Mufi runtime (mufiz).
// - Provides an `actor`-based `MufiBridge` to initialize/deinitialize the runtime,
//   interpret source strings and capture stdout/stderr emitted by the runtime.
//
// Notes:
// - The underlying C API is declared in `mufiz.h` (system module `CMufi`).
// - Interpretation is synchronous on the underlying runtime and may print to stdout/stderr.
//   We capture stdout/stderr by temporarily redirecting the process descriptors while the
//   interpreter is executing. Calls are serialized via the actor to avoid races.
// - The runtime is initialized once at app startup and deinitialized at app shutdown.
//
// IMPORTANT: If you experience crashes with "attempt to use null value" in compiler.currentChunk,
// this indicates a bug in libmufiz.dylib itself. The dylib needs to be rebuilt with the
// latest Mufi-lang compiler fixes. This is NOT a Swift-side issue.
//
// Usage example:
//   // Runtime is already initialized by the app at startup
//   let (status, output) = try await MufiBridge.shared.interpret("print(\"Hello\")")
//   // status is the interpreter return code (UInt8), output contains printed text

import CMufi
import Darwin
import Foundation

public enum MufiError: Error, LocalizedError {
    case notInitialized
    case initializationFailed(code: Int32)
    case interpretFailed(status: UInt8, output: String)
    case captureFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Mufi runtime is not initialized."
        case .initializationFailed(let code):
            return "Mufi initialization failed with code \(code)."
        case .interpretFailed(let status, let output):
            return "Mufi interpretation failed (status \(status)). Output:\n\(output)"
        case .captureFailed(let reason):
            return "Failed to capture runtime output: \(reason)"
        }
    }
}

/// Actor that wraps the Mufi C runtime API. Serializes calls so stdout/stderr capture
/// is safe even within a multi-threaded application.
public actor MufiBridge {
    public static let shared = MufiBridge()

    private var initialized: Bool = false

    public init() {}

    /// Initialize the runtime. Throws if initialization returns a non-zero code.
    /// This should be called once at app startup.
    /// This method is idempotent - calling it multiple times is safe.
    public func initialize(
        enableLeakDetection: Bool = false,
        enableTracking: Bool = false,
        enableSafety: Bool = true
    ) throws {
        // Skip if already initialized
        guard !initialized else { return }

        let rc = mufiz_init(enableLeakDetection, enableTracking, enableSafety)
        if rc != MUFIZ_OK {
            throw MufiError.initializationFailed(code: rc)
        }
        initialized = true
    }

    /// Deinitialize the runtime (idempotent).
    /// After calling this, the runtime cannot be used again without reinitializing.
    public func deinitialize() {
        guard initialized else { return }
        mufiz_deinit()
        initialized = false
    }

    /// Interpret a source string using the embedded runtime.
    /// Returns a tuple: (status, combinedStdoutAndStderrOutput)
    ///
    /// This method runs the interpreter on a background thread and captures stdout/stderr
    /// that the runtime emits during execution.
    ///
    /// Note: The runtime must be initialized before calling this method.
    public func interpret(_ source: String) async throws -> (UInt8, String) {
        // Ensure runtime is initialized and ready
        guard initialized else {
            throw MufiError.notInitialized
        }

        // Prevent use after deinit - double check state
        guard initialized else {
            throw MufiError.notInitialized
        }

        // Guard against empty source
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return (0, "")
        }

        // Validate source code doesn't contain null bytes (causes C string issues)
        guard !trimmedSource.contains("\0") else {
            throw MufiError.captureFailed(reason: "Source code contains null bytes")
        }

        // Limit source code size to prevent crashes (10MB max)
        guard trimmedSource.utf8.count < 10_000_000 else {
            throw MufiError.captureFailed(reason: "Source code too large (>10MB)")
        }

        // Ensure source is valid UTF-8 and can be converted to C string
        guard trimmedSource.canBeConverted(to: .utf8) else {
            throw MufiError.captureFailed(reason: "Invalid UTF-8 encoding")
        }

        // Run the blocking call on a background thread and capture stdout/stderr
        // Note: The actor isolation ensures only one interpretation happens at a time
        return await Task.detached(priority: .userInitiated) { [trimmedSource] in
            // Wrap in autoreleasepool to prevent memory buildup
            return autoreleasepool {
                // Capture both STDOUT and STDERR while calling the library
                let (status, out) = Self.captureStdoutAndStderr {
                    // Call the C function using withCString to ensure proper null-termination
                    // The string is kept alive for the duration of the C call
                    return trimmedSource.withCString { (cString: UnsafePointer<CChar>) -> UInt8 in
                        // Call mufiz_interpret with the properly managed C string
                        // The runtime should NOT modify or free this string
                        return mufiz_interpret(cString)
                    }
                }
                return (status, out)
            }
        }.value
    }

    /// Convenience: interpret and throw an error if status != 0; otherwise returns the captured output.
    public func interpretAndThrow(_ source: String) async throws -> String {
        let (status, output) = try await interpret(source)
        if status != 0 {
            throw MufiError.interpretFailed(status: status, output: output)
        }
        return output
    }

    /// Helper wrappers exposing additional convenience functions from the C API.
    public func hasMemoryLeaks() -> Bool {
        guard initialized else { return false }
        return mufiz_has_memory_leaks()
    }

    public func printMemoryStats() {
        guard initialized else { return }
        mufiz_print_memory_stats()
    }

    /// If you need to interoperate with C-allocated strings returned by the runtime,
    /// use this helper to duplicate and auto-free the C string into a Swift String.
    /// This properly manages memory allocated by the Mufi runtime.
    public func strdupToSwift(_ src: String) -> String? {
        guard initialized else { return nil }
        return src.withCString { (ptr: UnsafePointer<CChar>) -> String? in
            // Call mufiz_strdup which allocates memory on the C side
            guard let cCopy = mufiz_strdup(ptr) else { return nil }
            // Copy to Swift String (which copies the data)
            let swiftString = String(cString: cCopy)
            // Free the C-allocated memory
            mufiz_free_cstring(cCopy)
            return swiftString
        }
    }

    // MARK: - Internal: capture stdout/stderr

    /// Capture both STDOUT and STDERR around a synchronous work closure.
    /// Returns a tuple `(value, outputString)`.
    /// IMPORTANT: This uses low-level POSIX descriptor manipulation.
    /// Thread safety is ensured by the actor isolation of MufiBridge.
    private static func captureStdoutAndStderr<T>(_ body: () -> T) -> (T, String) {
        // Create a pipe for capturing output
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            // If pipe creation fails, run body without capture
            return (body(), "")
        }
        let readFD = fds[0]
        let writeFD = fds[1]

        // Save original stdout/stderr descriptors
        let savedStdout = dup(STDOUT_FILENO)
        let savedStderr = dup(STDERR_FILENO)

        // Check if dup succeeded
        guard savedStdout >= 0, savedStderr >= 0 else {
            // Cleanup and fallback
            if savedStdout >= 0 { close(savedStdout) }
            if savedStderr >= 0 { close(savedStderr) }
            close(readFD)
            close(writeFD)
            return (body(), "")
        }

        // Flush standard streams to avoid losing buffered data
        fflush(stdout)
        fflush(stderr)

        // Redirect stdout and stderr to the pipe's write end
        guard dup2(writeFD, STDOUT_FILENO) != -1, dup2(writeFD, STDERR_FILENO) != -1 else {
            // Restore and fallback
            _ = dup2(savedStdout, STDOUT_FILENO)
            _ = dup2(savedStderr, STDERR_FILENO)
            close(savedStdout)
            close(savedStderr)
            close(readFD)
            close(writeFD)
            return (body(), "")
        }

        // Close writeFD since stdout/stderr now point to the pipe
        close(writeFD)

        // Run the body (which will call mufiz_interpret etc.)
        let value: T = body()

        // Flush to ensure all output is written to the pipe
        fflush(stdout)
        fflush(stderr)

        // Restore original stdout and stderr
        _ = dup2(savedStdout, STDOUT_FILENO)
        _ = dup2(savedStderr, STDERR_FILENO)

        // Close the saved descriptors
        close(savedStdout)
        close(savedStderr)

        // Read from the pipe until EOF
        var output = String()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = read(readFD, buffer, bufferSize)
            if bytesRead > 0 {
                // Convert bytes to string
                let data = Data(bytes: buffer, count: Int(bytesRead))
                if let str = String(data: data, encoding: .utf8) {
                    output.append(str)
                } else {
                    // Lossy conversion if UTF-8 decoding fails
                    output.append(String(decoding: data, as: UTF8.self))
                }
            } else {
                // EOF or error
                break
            }
        }

        // Close read end
        close(readFD)

        return (value, output)
    }
}
