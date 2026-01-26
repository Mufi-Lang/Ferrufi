//
// DiagnosticsLogger.swift
// Persistent diagnostic logger for permission & bookmark flows
//
// Writes to: ~/Library/Logs/Ferrufi/ferrufi.log
//
// This logger is intentionally simple and synchronous from the caller's POV
// (it performs short file I/O). It is designed to be safe to call from
// AppDelegate and the bookmark manager during permission flows so you have a
// persistent trace even if Console doesn't show process output.
//

import Foundation

@MainActor
public final class DiagnosticsLogger {

    public static let shared = DiagnosticsLogger()

    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let logFile: URL
    private let isoFormatter: ISO8601DateFormatter
    private let queue = DispatchQueue(label: "org.ferrufi.DiagnosticsLogger", qos: .utility)

    private init() {
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let home = fileManager.homeDirectoryForCurrentUser
        let logsDir =
            home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Ferrufi", isDirectory: true)

        self.logDirectory = logsDir
        self.logFile = logsDir.appendingPathComponent("ferrufi.log", isDirectory: false)

        // Ensure directory & file exist (best-effort)
        do {
            if !fileManager.fileExists(atPath: logsDir.path) {
                try fileManager.createDirectory(
                    at: logsDir, withIntermediateDirectories: true, attributes: nil)
            }
            if !fileManager.fileExists(atPath: logFile.path) {
                fileManager.createFile(atPath: logFile.path, contents: nil, attributes: nil)
            }
        } catch {
            // If creating directories fails, we will fallback to printing to stdout.
            // Avoid throwing in init - logger must be resilient.
            print("[DiagnosticsLogger] init: failed to prepare log file: \(error)")
        }
    }

    /// Append a log entry. Level defaults to INFO.
    public func log(_ message: String, level: String = "INFO") {
        let timestamp = isoFormatter.string(from: Date())
        let entry = "\(timestamp) [\(level)] \(sanitize(message))\n"

        // Use serial queue to avoid races when writing
        queue.async { [logFile] in
            guard let data = entry.data(using: .utf8) else { return }
            do {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    let fh = try FileHandle(forWritingTo: logFile)
                    defer {
                        try? fh.close()
                    }
                    try fh.seekToEnd()
                    try fh.write(contentsOf: data)
                } else {
                    try data.write(to: logFile, options: .atomic)
                }
            } catch {
                // Fallback to stdout so logs are not lost entirely
                print("[DiagnosticsLogger] write failed: \(error) — entry: \(entry)")
            }
        }
    }

    /// Convenience for error-level messages
    public func logError(_ message: String) {
        log(message, level: "ERROR")
    }

    /// Log a permission-related event with contextual fields
    public func logPermissionEvent(_ event: String, path: String? = nil, details: String? = nil) {
        var parts = ["event=\(event)"]
        if let p = path { parts.append("path=\(p)") }
        if let d = details { parts.append("details=\(d)") }
        log(parts.joined(separator: " | "), level: "PERM")
    }

    /// Log bookmark creation/resolution events to make debugging easier.
    public func logBookmarkEvent(
        _ action: String, key: String? = nil, success: Bool = true, details: String? = nil
    ) {
        var parts = ["action=\(action)"]
        parts.append("result=\(success ? "ok" : "fail")")
        if let k = key { parts.append("key=\(k)") }
        if let d = details { parts.append("details=\(d)") }
        log(parts.joined(separator: " | "), level: "BOOKMARK")
    }

    /// Rotate log if it exceeds maxSizeMB (simple rotate to .log.1)
    /// NOTE: perform all file I/O on the background queue and avoid referencing
    /// main-actor-isolated properties or calling main-actor methods from the
    /// non-isolated closure. We write a small rotation marker directly to the
    /// new log file to avoid invoking the actor-isolated `log(...)` helper here.
    public func rotateIfNeeded(maxSizeMB: Int = 10) {
        // Snapshot values on the main actor so the background work doesn't touch
        // actor-isolated properties.
        let logPath = logFile.path
        let maxBytes = UInt64(maxSizeMB) * 1024 * 1024

        queue.async {
            do {
                // Use FileManager.default directly to avoid referencing `self.fileManager`
                let attrs = try FileManager.default.attributesOfItem(atPath: logPath)
                if let size = attrs[.size] as? UInt64, size > maxBytes {
                    let logURL = URL(fileURLWithPath: logPath)
                    let rotated = logURL.deletingPathExtension().appendingPathExtension("log.1")
                    try? FileManager.default.removeItem(at: rotated)  // ignore error
                    try FileManager.default.moveItem(at: logURL, to: rotated)
                    FileManager.default.createFile(atPath: logPath, contents: nil, attributes: nil)

                    // Best-effort: append a rotation marker directly into the new log file.
                    let timestamp = ISO8601DateFormatter().string(from: Date())
                    let entry = "\(timestamp) [ROTATE] Rotated log (maxSizeMB=\(maxSizeMB))\n"
                    if let data = entry.data(using: .utf8) {
                        if let fh = try? FileHandle(forWritingTo: logURL) {
                            defer {
                                do {
                                    try fh.close()
                                } catch {
                                    print(
                                        "[DiagnosticsLogger] failed to close rotated log file: \(error)"
                                    )
                                }
                            }
                            do {
                                try fh.seekToEnd()
                                try fh.write(contentsOf: data)
                            } catch {
                                print(
                                    "[DiagnosticsLogger] failed to write rotation marker: \(error)")
                            }
                        } else {
                            // Fallback: atomically write the small marker if FileHandle couldn't open
                            do {
                                try data.write(to: logURL, options: .atomic)
                            } catch {
                                print(
                                    "[DiagnosticsLogger] failed to write rotation marker (atomic): \(error)"
                                )
                            }
                        }
                    }
                }
            } catch {
                // ignore rotation errors
                print("[DiagnosticsLogger] rotateIfNeeded error: \(error)")
            }
        }
    }

    /// Return last N lines of the log file (best-effort). Useful for quick diagnostics.
    /// This reads the whole file for simplicity; logs are expected to be small.
    public func tailLines(_ count: Int = 200) -> [String] {
        var result: [String] = []
        let data: Data?
        do {
            data = try Data(contentsOf: logFile)
        } catch {
            return ["[DiagnosticsLogger] cannot read log: \(error)"]
        }
        guard let d = data, let content = String(data: d, encoding: .utf8) else {
            return ["[DiagnosticsLogger] log empty or not UTF-8"]
        }
        let lines = content.components(separatedBy: .newlines)
        if count <= 0 || lines.isEmpty { return lines }
        let start = max(0, lines.count - count)
        result = Array(lines[start..<lines.count])
        return result
    }

    /// Helper to sanitize newlines / control characters in messages
    private func sanitize(_ s: String) -> String {
        // Replace stray newlines with space to keep entries one-line for easy tailing
        return s.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
    }
}
