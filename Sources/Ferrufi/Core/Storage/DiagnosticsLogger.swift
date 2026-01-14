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
    public func rotateIfNeeded(maxSizeMB: Int = 10) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let attrs = try self.fileManager.attributesOfItem(atPath: self.logFile.path)
                if let size = attrs[.size] as? UInt64 {
                    let limit = UInt64(maxSizeMB) * 1024 * 1024
                    if size > limit {
                        let rotated = self.logFile.deletingPathExtension().appendingPathExtension(
                            "log.1")
                        try? self.fileManager.removeItem(at: rotated)  // ignore error
                        try self.fileManager.moveItem(at: self.logFile, to: rotated)
                        self.fileManager.createFile(
                            atPath: self.logFile.path, contents: nil, attributes: nil)
                        self.log("Rotated log (maxSizeMB=\(maxSizeMB))", level: "ROTATE")
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
