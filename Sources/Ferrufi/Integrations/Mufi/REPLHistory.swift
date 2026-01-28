// REPLHistory.swift
// Ferrufi
//
// Persistent REPL command history manager used by the embedded Mufi REPL.
// - Stores a bounded list of recent commands (default newest-first in memory)
// - Persists history to disk under Application Support/Ferrufi/repl_history.txt
// - Posts `Notification.Name.replHistoryDidChange` whenever the history mutates
//
// Design notes:
// - Implemented as an `actor` to provide a simple, concurrency-safe API.
// - File I/O uses the centralized `FileService` actor so it respects security-scoped access.
// - In-memory ordering: `entries[0]` is the most-recent command. On disk, lines are written
//   oldest-first to make the file easy to read with a plain editor.
//

import Foundation

extension Notification.Name {
    /// Posted when the REPL history changes. Observers may refresh UI when received.
    public static let replHistoryDidChange = Notification.Name("Ferrufi.REPLHistoryDidChange")
}

/// Actor that manages REPL command history with disk persistence.
public actor REPLHistory {
    /// Shared singleton instance used by the app.
    public static let shared = REPLHistory()

    // MARK: - Configuration

    /// Maximum number of commands to keep in history (default: 500)
    private let maxEntries: Int

    /// File where history is persisted (oldest-first lines)
    private let historyURL: URL

    // MARK: - State (newest-first)
    private var entries: [String] = []

    // MARK: - Init

    /// Create a REPLHistory instance. The initializer schedules an async load from disk.
    /// - Parameters:
    ///   - maxEntries: Maximum number of history entries to keep (default 500).
    ///   - historyURL: Optional custom file URL for history (used in tests). If omitted
    ///                 a sensible Application Support path is chosen automatically.
    public init(maxEntries: Int = 500, historyURL: URL? = nil) {
        self.maxEntries = maxEntries
        self.historyURL = historyURL ?? Self.defaultHistoryURL()
        // Load existing history in background (init cannot be async)
        Task { await self.loadFromDisk() }
    }

    // MARK: - Public API

    /// Add a new command to history and persist it. Consecutive duplicate entries are ignored.
    public func addCommand(_ command: String) async {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Avoid consecutive duplicate entries
        if entries.first == trimmed {
            return
        }

        entries.insert(trimmed, at: 0)

        // Enforce max size
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        await notifyChange()

        do {
            try await saveToDisk()
        } catch {
            // Non-fatal: log for diagnostics and continue
            print("REPLHistory: saveToDisk() failed: \(error)")
        }
    }

    /// Return recent history entries ordered newest-first. Optional `limit` restricts
    /// the number of returned entries.
    public func getRecent(limit: Int? = nil) async -> [String] {
        if let l = limit {
            return Array(entries.prefix(l))
        }
        return entries
    }

    /// Return a specific command by index (newest-first). Returns `nil` for out-of-range indexes.
    public func command(at index: Int) async -> String? {
        guard index >= 0 && index < entries.count else { return nil }
        return entries[index]
    }

    /// Clear all history and remove the persisted file.
    public func clear() async {
        entries.removeAll()
        await notifyChange()

        do {
            try await FileService.shared.deleteItem(atPath: historyURL.path)
        } catch {
            // Ignore deletion errors (file may not exist or deletion may fail; non-fatal)
            // Log for diagnostics
            // print("REPLHistory: failed to delete history file: \(error)")
        }
    }

    /// Return history content as a single string (oldest-first, suitable for export).
    public func exportToString() async -> String {
        return entries.reversed().joined(separator: "\n")
    }

    /// Replace current history with contents from a string (interpreted as newline-delimited,
    /// oldest-first) and persist to disk.
    public func importFromString(_ data: String) async {
        let lines =
            data
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Convert oldest-first -> newest-first (internal representation)
        entries = Array(lines.reversed())
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        await notifyChange()
        do {
            try await saveToDisk()
        } catch {
            print("REPLHistory: import save failed: \(error)")
        }
    }

    /// Simple case-insensitive search of history (returns newest-first results).
    public func search(prefixOrSubstring query: String, limit: Int = 50) async -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            return Array(entries.prefix(limit))
        }

        var results: [String] = []
        for entry in entries {
            if entry.lowercased().contains(q) {
                results.append(entry)
                if results.count >= limit { break }
            }
        }
        return results
    }

    // MARK: - Internal: Persistence

    /// Load history from disk into memory. If the file does not exist the history remains empty.
    private func loadFromDisk() async {
        do {
            let text = try await FileService.shared.readTextFile(atPath: historyURL.path)

            let lines =
                text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // File is oldest-first; convert to newest-first in memory
            entries = Array(lines.reversed())
            if entries.count > maxEntries {
                entries = Array(entries.prefix(maxEntries))
            }

            await notifyChange()
        } catch {
            // File might not exist or read may fail for other non-fatal reasons.
            // We intentionally swallow errors here to avoid blocking REPL startup.
            // print("REPLHistory: loadFromDisk() error: \(error)")
        }
    }

    /// Persist current history to disk (writes oldest-first lines).
    private func saveToDisk() async throws {
        let dirPath = historyURL.deletingLastPathComponent().path

        // Ensure parent directory exists using the FileService (respects security scope)
        try await FileService.shared.createDirectory(atPath: dirPath)

        // Store as oldest-first lines for easier human inspection
        let contents = entries.reversed().joined(separator: "\n")
        try await FileService.shared.writeTextFile(atPath: historyURL.path, contents: contents)
    }

    // MARK: - Utilities

    private func notifyChange() async {
        await MainActor.run {
            NotificationCenter.default.post(name: .replHistoryDidChange, object: nil)
        }
    }

    private static func defaultHistoryURL() -> URL {
        // Use Application Support/Ferrufi/repl_history.txt when available,
        // otherwise fall back to ~/Library/Application Support/Ferrufi/repl_history.txt
        let fm = FileManager.default
        let appSupport: URL
        if let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            appSupport = url
        } else {
            appSupport = URL(
                fileURLWithPath: (NSHomeDirectory() as NSString)
                    .appendingPathComponent("Library/Application Support"))
        }
        return appSupport.appendingPathComponent("Ferrufi").appendingPathComponent(
            "repl_history.txt")
    }
}
