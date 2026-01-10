//
//  UnifiedStorage.swift
//  Ferrufi
//
//  Unified storage protocol for linking system compatibility
//

import Combine
import Foundation

/// Unified storage protocol that provides both path-based and ID-based access
public protocol UnifiedStorageProtocol: Sendable {
    // Path-based methods (existing FileStorage interface)
    func saveNote(_ note: Note) async throws
    func loadNote(from path: String) async throws -> Note
    func deleteNote(at path: String) async throws
    func moveNote(from sourcePath: String, to destinationPath: String) async throws
    func listNotes(in directory: String) async throws -> [String]
    func watchForChanges() -> AnyPublisher<FileChangeEvent, Never>

    // ID-based methods (needed by linking system)
    func loadNote(id: UUID) async throws -> Note?
    func listAllNotes() async throws -> [Note]
    func findNotePath(id: UUID) async throws -> String?
    func findNoteByTitle(_ title: String) async throws -> Note?
}

/// Extension to FileStorage to support the unified protocol
extension FileStorage: UnifiedStorageProtocol {

    /// Load a note by its UUID
    public func loadNote(id: UUID) async throws -> Note? {
        // First, try to find the note path by ID
        guard let path = try await findNotePath(id: id) else {
            return nil
        }

        return try await loadNote(from: path)
    }

    /// List all notes as Note objects (not just paths)
    public func listAllNotes() async throws -> [Note] {
        let paths = try await listNotes(in: "")
        var notes: [Note] = []

        for path in paths {
            do {
                let note = try await loadNote(from: path)
                notes.append(note)
            } catch {
                // Log error but continue with other notes
                print("Warning: Failed to load note at \(path): \(error)")
                continue
            }
        }

        return notes
    }

    /// Find the file path for a note with the given UUID
    public func findNotePath(id: UUID) async throws -> String? {
        let paths = try await listNotes(in: "")

        for path in paths {
            do {
                let note = try await loadNote(from: path)
                if note.id == id {
                    return path
                }
            } catch {
                // Continue checking other files
                continue
            }
        }

        return nil
    }

    /// Find a note by its title
    public func findNoteByTitle(_ title: String) async throws -> Note? {
        let notes = try await listAllNotes()
        return notes.first { $0.title == title }
    }
}

/// Type alias for easier usage in the linking system
public typealias LinkingStorageProtocol = UnifiedStorageProtocol
