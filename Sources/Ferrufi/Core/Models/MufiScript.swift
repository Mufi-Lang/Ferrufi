//
//  MufiScript.swift
//  Ferrufi
//
//  Core data model for Mufi scripts
//

import Foundation

/// Represents a single Mufi script file in the Ferrufi editor
public struct MufiScript: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var code: String
    public var tags: Set<String>
    public var createdAt: Date
    public var modifiedAt: Date
    public var filePath: String
    public var metadata: MufiScriptMetadata

    /// Computed URL property from filePath
    public var url: URL? {
        return URL(fileURLWithPath: filePath)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        code: String = "",
        tags: Set<String> = [],
        filePath: String,
        metadata: MufiScriptMetadata = MufiScriptMetadata()
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.tags = tags
        self.filePath = filePath
        self.metadata = metadata

        let now = Date()
        self.createdAt = now
        self.modifiedAt = now
    }

    /// Convenience initializer with URL
    public init(
        id: UUID = UUID(),
        name: String,
        code: String = "",
        tags: Set<String> = [],
        url: URL,
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        metadata: MufiScriptMetadata = MufiScriptMetadata()
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.tags = tags
        self.filePath = url.path
        self.metadata = metadata

        let now = Date()
        self.createdAt = createdAt ?? now
        self.modifiedAt = modifiedAt ?? now
    }

    /// Updates the script's modification time
    public mutating func updateModifiedTime() {
        self.modifiedAt = Date()
    }

    /// Adds a tag to the script
    public mutating func addTag(_ tag: String) {
        tags.insert(tag.lowercased())
        updateModifiedTime()
    }

    /// Removes a tag from the script
    public mutating func removeTag(_ tag: String) {
        tags.remove(tag.lowercased())
        updateModifiedTime()
    }

    /// Returns the script's line count
    public var lineCount: Int {
        return code.components(separatedBy: .newlines).count
    }

    /// Returns the script's character count (excluding whitespace)
    public var characterCount: Int {
        return code.filter { !$0.isWhitespace }.count
    }

    /// Returns the file size in bytes
    public var fileSizeBytes: Int {
        return code.utf8.count
    }
}

/// Additional metadata for Mufi scripts
public struct MufiScriptMetadata: Codable, Hashable, Sendable {
    public var isFavorite: Bool
    public var isArchived: Bool
    public var isPinned: Bool
    public var lastRunDate: Date?
    public var lastRunStatus: RunStatus?
    public var customProperties: [String: String]

    /// Convenience properties for compatibility
    public var modifiedAt: Date {
        get {
            if let dateString = customProperties["modifiedAt"],
                let date = ISO8601DateFormatter().date(from: dateString)
            {
                return date
            }
            return Date()
        }
        set {
            customProperties["modifiedAt"] = ISO8601DateFormatter().string(from: newValue)
        }
    }

    public var lineCount: Int {
        get {
            return Int(customProperties["lineCount"] ?? "0") ?? 0
        }
        set {
            customProperties["lineCount"] = String(newValue)
        }
    }

    public init(
        isFavorite: Bool = false,
        isArchived: Bool = false,
        isPinned: Bool = false,
        lastRunDate: Date? = nil,
        lastRunStatus: RunStatus? = nil,
        customProperties: [String: String] = [:]
    ) {
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.isPinned = isPinned
        self.lastRunDate = lastRunDate
        self.lastRunStatus = lastRunStatus
        self.customProperties = customProperties
    }
}

/// Status of the last script run
public enum RunStatus: String, Codable, CaseIterable, Sendable {
    case success = "success"
    case error = "error"
    case timeout = "timeout"
    case cancelled = "cancelled"
}

/// Utility for parsing Mufi code
public struct MufiCodeParser: Sendable {
    /// Extracts function definitions from Mufi code
    public static func extractFunctions(from code: String) -> [String] {
        let pattern = #"fn\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        let matches = regex.matches(in: code, options: [], range: range)

        var functions: [String] = []
        for match in matches {
            if let functionRange = Range(match.range(at: 1), in: code) {
                let functionName = String(code[functionRange])
                functions.append(functionName)
            }
        }
        return functions
    }

    /// Extracts variable declarations from Mufi code
    public static func extractVariables(from code: String) -> [String] {
        let pattern = #"(?:var|val)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*="#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        let matches = regex.matches(in: code, options: [], range: range)

        var variables: [String] = []
        for match in matches {
            if let variableRange = Range(match.range(at: 1), in: code) {
                let variableName = String(code[variableRange])
                variables.append(variableName)
            }
        }
        return variables
    }

    /// Extracts comments from Mufi code
    public static func extractComments(from code: String) -> [String] {
        let pattern = #"//(.*)$"#
        let regex = try! NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        let matches = regex.matches(in: code, options: [], range: range)

        var comments: [String] = []
        for match in matches {
            if let commentRange = Range(match.range(at: 1), in: code) {
                let comment = String(code[commentRange]).trimmingCharacters(
                    in: .whitespaces)
                comments.append(comment)
            }
        }
        return comments
    }
}

extension MufiScript {
    /// Creates a script from a Mufi file
    public static func fromFile(
        filePath: String,
        code: String
    ) -> MufiScript {
        let name = URL(fileURLWithPath: filePath)
            .deletingPathExtension()
            .lastPathComponent

        var script = MufiScript(
            name: name,
            code: code,
            filePath: filePath
        )

        // Update metadata
        script.metadata.lineCount = script.lineCount

        return script
    }

    /// Sample script for previews and testing
    public static var sample: MufiScript {
        return MufiScript(
            name: "hello_world",
            code: """
                // Hello World in Mufi
                var greeting = "Hello, World!"
                print(greeting)

                // Function example
                fn add(a, b) {
                    return a + b
                }

                var result = add(5, 3)
                print("5 + 3 = " + str(result))

                // Loop example
                var i = 0
                while i < 5 {
                    print("Count: " + str(i))
                    i = i + 1
                }
                """,
            filePath: "/tmp/hello_world.mufi"
        )
    }

    /// Sample script with error
    public static var sampleWithError: MufiScript {
        return MufiScript(
            name: "error_example",
            code: """
                // This will cause an error
                var x = undefined_function()
                print(x)
                """,
            filePath: "/tmp/error_example.mufi"
        )
    }

    /// Empty script template
    public static var empty: MufiScript {
        return MufiScript(
            name: "untitled",
            code: "// Start writing your Mufi code here\n\n",
            filePath: "/tmp/untitled.mufi"
        )
    }
}
