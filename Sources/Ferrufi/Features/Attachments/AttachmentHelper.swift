/*
 AttachmentHelper.swift
 Ferrufi

 Helper utilities to persist data: URLs (e.g. `data:image/png;base64,...`) as files
 under a note-local `.ferrufi/attachments/` directory with deterministic filenames.

 Deterministic naming strategy:
   - Compute SHA256(content) when CryptoKit is available (fallback to Swift Hasher).
   - Filename format: `attachment-<hexhash>.<ext>`
   - Returns a relative path string: `.ferrufi/attachments/<filename>`

 Usage:
   if let rel = try? AttachmentHelper.saveDataURL(dataURLString, noteURL: noteURL, suggestedName: "output.png") {
       // rel == ".ferrufi/attachments/attachment-<hash>.png"
   }
*/

import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#endif

public enum AttachmentHelperError: Error {
    case invalidDataURL
    case decodingFailed
    case writeFailed(Error)
}

/// Small helper to persist attachments for notes.
public final class AttachmentHelper {

    private init() {}

    /// Persist a data: URL string next to the given note file.
    ///
    /// - Parameters:
    ///   - dataURL: Full data: URL string (e.g. `data:image/png;base64,<payload>`).
    ///   - noteURL: File URL of the note being processed. Attachments are created in
    ///              `<note-folder>/.ferrufi/attachments/`.
    ///   - suggestedName: Optional suggested filename (may include extension). Used to derive extension if media-type isn't present.
    /// - Returns: Relative path suitable for referencing from the note (e.g. `.ferrufi/attachments/<filename>`), or throws on failure.
    public static func saveDataURL(
        _ dataURL: String,
        noteURL: URL,
        suggestedName: String = "output"
    ) throws -> String {
        // Parse data URL: data:[<mediatype>][;base64],<data>
        guard let commaRange = dataURL.range(of: ",") else {
            throw AttachmentHelperError.invalidDataURL
        }

        let meta = String(dataURL[dataURL.startIndex..<commaRange.lowerBound])
        let payload = String(dataURL[commaRange.upperBound...])

        let isBase64 = meta.contains(";base64")

        // Determine file extension
        var fileExt: String? = nil
        if let mediaTypeSegment = meta.split(separator: ":").last?.split(separator: ";").first {
            let parts = mediaTypeSegment.split(separator: "/")
            if parts.count == 2 {
                // Handle cases like image/svg+xml -> treat special suffixes
                var ext = String(parts[1])
                // common normalization
                if ext.contains("+") {
                    // e.g. svg+xml -> svg
                    ext = ext.split(separator: "+").first.map(String.init) ?? ext
                }
                // jpeg -> jpg
                if ext.lowercased() == "jpeg" { ext = "jpg" }
                fileExt = ext
            }
        }

        if fileExt == nil {
            if let dotIndex = suggestedName.lastIndex(of: ".") {
                let extCandidate = String(suggestedName[suggestedName.index(after: dotIndex)...])
                if !extCandidate.isEmpty { fileExt = extCandidate }
            }
        }

        if fileExt == nil { fileExt = "bin" }

        // Decode payload
        let data: Data?
        if isBase64 {
            data = Data(base64Encoded: payload)
        } else {
            // Percent-decoded or plain text payload
            data = payload.data(using: .utf8)
        }
        guard let actualData = data else {
            throw AttachmentHelperError.decodingFailed
        }

        // Compute deterministic filename
        let hexHash: String
        #if canImport(CryptoKit)
            let digest = SHA256.hash(data: actualData)
            hexHash = digest.map { String(format: "%02x", $0) }.joined()
        #else
            var hasher = Hasher()
            hasher.combine(actualData)
            hexHash = String(abs(hasher.finalize()))
        #endif

        let filename = "attachment-\(hexHash).\(fileExt ?? "bin")"

        // Ensure attachments directory exists: <note-folder>/.ferrufi/attachments
        let noteDir = noteURL.deletingLastPathComponent()
        let attachmentsDir = noteDir.appendingPathComponent(
            ".ferrufi/attachments", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: attachmentsDir, withIntermediateDirectories: true)
            let fileURL = attachmentsDir.appendingPathComponent(filename)

            // If file already exists, do not overwrite (idempotent)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try actualData.write(to: fileURL, options: .atomic)
            }

            // Return relative path for insertion into note content
            return ".ferrufi/attachments/\(filename)"
        } catch {
            throw AttachmentHelperError.writeFailed(error)
        }
    }

    /// Convenience: attempt to save data URL and return nil on failure.
    public static func trySaveDataURL(
        _ dataURL: String,
        noteURL: URL,
        suggestedName: String = "output"
    ) -> String? {
        do {
            return try saveDataURL(dataURL, noteURL: noteURL, suggestedName: suggestedName)
        } catch {
            return nil
        }
    }

    /// Persist arbitrary Data as attachment (deterministic name) next to note.
    /// - Parameters:
    ///   - data: Raw data to persist.
    ///   - noteURL: Parent note URL.
    ///   - suggestedName: Optional suggested filename (for deriving extension).
    ///   - explicitExt: Optional explicit extension to force (overrides suggestedName).
    /// - Returns: Relative path or throws error.
    public static func saveData(
        _ data: Data,
        noteURL: URL,
        suggestedName: String = "output",
        explicitExt: String? = nil
    ) throws -> String {
        let fileExt: String?
        if let explicit = explicitExt, !explicit.isEmpty {
            fileExt = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let dotIndex = suggestedName.lastIndex(of: ".") {
            fileExt = String(suggestedName[suggestedName.index(after: dotIndex)...])
        } else {
            fileExt = "bin"
        }

        let hexHash: String
        #if canImport(CryptoKit)
            let digest = SHA256.hash(data: data)
            hexHash = digest.map { String(format: "%02x", $0) }.joined()
        #else
            var hasher = Hasher()
            hasher.combine(data)
            hexHash = String(abs(hasher.finalize()))
        #endif

        let filename = "attachment-\(hexHash).\(fileExt ?? "bin")"
        let noteDir = noteURL.deletingLastPathComponent()
        let attachmentsDir = noteDir.appendingPathComponent(
            ".ferrufi/attachments", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: attachmentsDir, withIntermediateDirectories: true)
            let fileURL = attachmentsDir.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try data.write(to: fileURL, options: .atomic)
            }
            return ".ferrufi/attachments/\(filename)"
        } catch {
            throw AttachmentHelperError.writeFailed(error)
        }
    }

    /// Helper to sanitize filenames (basic).
    public static func sanitizeFileName(_ name: String) -> String {
        var s = name.replacingOccurrences(of: " ", with: "_")
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        s = s.components(separatedBy: invalid).joined(separator: "")
        return s
    }
}
