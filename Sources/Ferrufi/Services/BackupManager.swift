/*
 BackupManager.swift
 Ferrufi

 Simple BackupManager using SQLite to store backup metadata and a scheduled
 backup task that will create per-note backups on an interval.

 Notes:
 - DB file: ~/.ferrufi/Ferrufi.db
 - Backups storage: ~/.ferrufi/backups/<uuid>-<timestamp>.bak
 - This implementation is intentionally self-contained and uses the system
   sqlite3 C API (no external dependencies).
 - The manager is MainActor-isolated so callers should use `Task { @MainActor in ... }`
   or `try await` where appropriate.
*/

import Foundation
import SQLite3

// SQLite 'destructor' sentinel used for bindings (equivalent to the C macro SQLITE_TRANSIENT).
// In Swift we construct the same sentinel value using an unsafe bitcast of -1 to
// sqlite3_destructor_type. This can be passed to sqlite3_bind_text so SQLite makes
// its own copy of the text data.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Metadata for a single backup
public struct BackupRecord: Codable, Sendable, Hashable {
    public let id: UUID
    public let noteId: UUID?
    public let originalPath: String
    public let backupPath: String
    public let createdAt: Date
    public let size: Int64

    public init(
        id: UUID,
        noteId: UUID?,
        originalPath: String,
        backupPath: String,
        createdAt: Date,
        size: Int64
    ) {
        self.id = id
        self.noteId = noteId
        self.originalPath = originalPath
        self.backupPath = backupPath
        self.createdAt = createdAt
        self.size = size
    }
}

// MARK: - Backup Errors

public enum BackupError: LocalizedError {
    case sqliteError(String)
    case fileOperationError(String)
    case noteMissingURL
    case alreadyRunning
    case unknown

    public var errorDescription: String? {
        switch self {
        case .sqliteError(let msg): return "Database error: \(msg)"
        case .fileOperationError(let msg): return "File operation failed: \(msg)"
        case .noteMissingURL: return "Note has no file URL"
        case .alreadyRunning: return "Backup already in progress"
        case .unknown: return "Unknown error"
        }
    }
}

// MARK: - BackupManager

@MainActor
public final class BackupManager {

    public static let shared = BackupManager()

    // DB
    private var db: OpaquePointer? = nil
    private var dbURL: URL

    // Backup storage
    private var backupsDir: URL

    // Scheduling
    private var timer: Timer?
    private var isPerformingBackups: Bool = false

    // Configuration
    private var backupInterval: TimeInterval = 60 * 60  // default 1 hour
    private var maxBackupsPerNote: Int = 10
    private var backupsEnabled: Bool = true

    private init() {
        // Setup directories & DB locations
        let home = FileManager.default.homeDirectoryForCurrentUser
        let ironDir = home.appendingPathComponent(".ferrufi", isDirectory: true)
        try? FileManager.default.createDirectory(at: ironDir, withIntermediateDirectories: true)

        self.dbURL = ironDir.appendingPathComponent("Ferrufi.db")
        self.backupsDir = ironDir.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        // Open/create DB and ensure table exists
        do {
            try openDatabase()
            try createTablesIfNeeded()
        } catch {
            print("BackupManager init: failed to open/create db: \(error)")
        }

        // Try to initialize scheduling from config if app is available
        rescheduleFromCurrentConfig()
    }

    deinit {
        // Intentionally empty — avoid accessing non-sendable pointers from deinit.
        // Database resources are cleaned up elsewhere (or by the process at exit).
    }

    // MARK: - Public API

    /// Create a backup for a given note. If note's file does not exist, throws.
    /// This function copies the note file into the backups directory and inserts metadata into the DB.
    public func createBackup(for note: Note) async throws -> BackupRecord {
        guard let sourceURL = note.url else {
            throw BackupError.noteMissingURL
        }

        // Ensure source exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw BackupError.fileOperationError("Original file not found: \(sourceURL.path)")
        }

        // Compose backup destination
        let ts = Int(Date().timeIntervalSince1970)
        let ext = sourceURL.pathExtension.isEmpty ? "bak" : sourceURL.pathExtension + ".bak"
        let backupFileName = "\(note.id.uuidString)-\(ts).\(ext)"
        let destURL = backupsDir.appendingPathComponent(backupFileName, isDirectory: false)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw BackupError.fileOperationError("Copy failed: \(error.localizedDescription)")
        }

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        // Insert into DB
        let id = UUID()
        let createdAt = Date()
        try insertBackupRecord(
            id: id,
            noteId: note.id,
            originalPath: sourceURL.path,
            backupPath: destURL.path,
            createdAt: createdAt,
            size: size
        )

        // Prune old backups for this note according to maxBackupsPerNote
        try pruneBackups(forNoteId: note.id, keep: maxBackupsPerNote)

        return BackupRecord(
            id: id,
            noteId: note.id,
            originalPath: sourceURL.path,
            backupPath: destURL.path,
            createdAt: createdAt,
            size: size
        )
    }

    /// Lists backups. If noteId is nil, returns all backups ordered by createdAt desc.
    public func listBackups(forNoteId noteId: UUID? = nil) throws -> [BackupRecord] {
        var rows: [BackupRecord] = []

        let sql =
            noteId == nil
            ? "SELECT id, note_id, original_path, backup_path, created_at, size FROM backups ORDER BY created_at DESC;"
            : "SELECT id, note_id, original_path, backup_path, created_at, size FROM backups WHERE note_id = ? ORDER BY created_at DESC;"

        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            throw BackupError.sqliteError("prepare failed: \(sqliteErrorMessage())")
        }
        defer { sqlite3_finalize(statement) }

        if let noteId = noteId {
            sqlite3_bind_text(statement, 1, noteId.uuidString, -1, SQLITE_TRANSIENT)
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idCString = sqlite3_column_text(statement, 0),
                let origCString = sqlite3_column_text(statement, 2),
                let backupCString = sqlite3_column_text(statement, 3)
            else {
                continue
            }

            let id = UUID(uuidString: String(cString: idCString)) ?? UUID()
            let noteIdStr = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) }
            let noteUUID = noteIdStr.flatMap { UUID(uuidString: $0) }

            let originalPath = String(cString: origCString)
            let backupPath = String(cString: backupCString)
            let createdAtDouble = sqlite3_column_double(statement, 4)
            let size = sqlite3_column_int64(statement, 5)

            let record = BackupRecord(
                id: id,
                noteId: noteUUID,
                originalPath: originalPath,
                backupPath: backupPath,
                createdAt: Date(timeIntervalSince1970: createdAtDouble),
                size: size
            )
            rows.append(record)
        }

        return rows
    }

    /// Delete a backup record (and the underlying file) by ID
    public func removeBackup(id: UUID) throws {
        // Fetch the backup to get path
        let rows = try listBackups(forNoteId: nil).filter { $0.id == id }
        guard let row = rows.first else { return }

        // Remove file
        do {
            if FileManager.default.fileExists(atPath: row.backupPath) {
                try FileManager.default.removeItem(atPath: row.backupPath)
            }
        } catch {
            throw BackupError.fileOperationError(
                "Failed to remove backup file: \(error.localizedDescription)")
        }

        // Remove DB record
        let sql = "DELETE FROM backups WHERE id = ?;"
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            throw BackupError.sqliteError("prepare failed: \(sqliteErrorMessage())")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) != SQLITE_DONE {
            throw BackupError.sqliteError("delete failed: \(sqliteErrorMessage())")
        }
    }

    /// Prune older backups for a specific note (keeps the most recent `keep` items).
    public func pruneBackups(forNoteId noteId: UUID, keep: Int) throws {
        // Query IDs to remove: SELECT id FROM backups WHERE note_id = ? ORDER BY created_at DESC LIMIT -1 OFFSET keep
        let sql =
            "SELECT id FROM backups WHERE note_id = ? ORDER BY created_at DESC LIMIT -1 OFFSET ?;"
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            throw BackupError.sqliteError("prepare failed: \(sqliteErrorMessage())")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, noteId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(max(keep, 0)))

        var toDelete: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let c = sqlite3_column_text(statement, 0) {
                if let uuid = UUID(uuidString: String(cString: c)) {
                    toDelete.append(uuid)
                }
            }
        }

        for id in toDelete {
            // Remove file & DB record
            do {
                try removeBackup(id: id)
            } catch {
                // continue removing others; surface last error if needed
                print("BackupManager prune: failed to remove backup \(id): \(error)")
            }
        }
    }

    /// Reschedule using the current FerrufiApp configuration (if available)
    public func rescheduleFromCurrentConfig() {
        guard let app = FerrufiApp.shared else { return }
        let enabled = app.configuration.vault.backupEnabled
        let interval = app.configuration.vault.backupInterval  // in seconds
        let max = app.configuration.vault.maxBackups

        reschedule(enabled: enabled, interval: interval, maxBackups: max)
    }

    /// Reschedule behavior (enable/disable, interval in seconds, keep)
    public func reschedule(enabled: Bool, interval: TimeInterval, maxBackups: Int) {
        self.backupsEnabled = enabled
        self.backupInterval = interval
        self.maxBackupsPerNote = maxBackups

        stopTimer()
        if enabled {
            startTimer()
        }
    }

    // MARK: - Timer / Periodic

    private func startTimer() {
        // Fire immediately and then schedule repeating timer
        Task { @MainActor in
            await self.performPeriodicBackup()
        }

        // Invalidate existing timer just in case
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: backupInterval, repeats: true) {
            [weak self] _ in
            Task {
                await self?.performPeriodicBackup()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Iterates notes and creates backups for notes that were modified since the last backup.
    public func performPeriodicBackup() async {
        guard !isPerformingBackups else {
            print("BackupManager: skipping periodic run because a run is already in progress")
            return
        }
        isPerformingBackups = true
        defer { isPerformingBackups = false }

        guard let app = FerrufiApp.shared else { return }

        for note in app.notes {
            // Check last backup timestamp
            do {
                let last = try lastBackupDate(forNoteId: note.id)
                if let last = last, last >= note.modifiedAt {
                    // No changes since last backup
                    continue
                }

                // Create backup
                _ = try await createBackup(for: note)

                // Prune
                try pruneBackups(forNoteId: note.id, keep: maxBackupsPerNote)
            } catch {
                print("BackupManager: periodic backup failed for note \(note.id): \(error)")
            }
        }
    }

    // MARK: - DB Helpers

    private func openDatabase() throws {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            let msg = sqliteErrorMessage()
            throw BackupError.sqliteError("open failed: \(msg)")
        }
    }

    private func sqliteErrorMessage() -> String {
        if let db = db, let c = sqlite3_errmsg(db) {
            return String(cString: c)
        }
        return "unknown sqlite error"
    }

    private func createTablesIfNeeded() throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS backups (
                id TEXT PRIMARY KEY,
                note_id TEXT,
                original_path TEXT,
                backup_path TEXT,
                created_at REAL,
                size INTEGER
            );
            CREATE INDEX IF NOT EXISTS backups_note_created_idx ON backups(note_id, created_at DESC);
            """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw BackupError.sqliteError("create table failed: \(sqliteErrorMessage())")
        }
    }

    private func insertBackupRecord(
        id: UUID,
        noteId: UUID?,
        originalPath: String,
        backupPath: String,
        createdAt: Date,
        size: Int64
    ) throws {
        let sql =
            "INSERT INTO backups (id, note_id, original_path, backup_path, created_at, size) VALUES (?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let statement = stmt else {
            throw BackupError.sqliteError("prepare insert failed: \(sqliteErrorMessage())")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        if let noteId = noteId {
            sqlite3_bind_text(statement, 2, noteId.uuidString, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        sqlite3_bind_text(statement, 3, originalPath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, backupPath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 5, createdAt.timeIntervalSince1970)
        sqlite3_bind_int64(statement, 6, size)

        if sqlite3_step(statement) != SQLITE_DONE {
            throw BackupError.sqliteError("insert failed: \(sqliteErrorMessage())")
        }
    }

    private func lastBackupDate(forNoteId noteId: UUID) throws -> Date? {
        let sql =
            "SELECT created_at FROM backups WHERE note_id = ? ORDER BY created_at DESC LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let statement = stmt else {
            throw BackupError.sqliteError("prepare failed: \(sqliteErrorMessage())")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, noteId.uuidString, -1, SQLITE_TRANSIENT)
        if sqlite3_step(statement) == SQLITE_ROW {
            let ts = sqlite3_column_double(statement, 0)
            return Date(timeIntervalSince1970: ts)
        }
        return nil
    }
}
