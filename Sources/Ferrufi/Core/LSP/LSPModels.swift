//
//  LSPModels.swift
//  Ferrufi
//
//  Swift representations of LSP types, mapped from CMufi native structures.
//

import Foundation

public enum MufiDiagnosticSeverity: Int, Codable, Sendable {
    case error = 1
    case warning = 2
}

public struct MufiPosition: Codable, Equatable, Sendable {
    public let line: UInt32
    public let column: UInt32
    
    public init(line: UInt32, column: UInt32) {
        self.line = line
        self.column = column
    }
}

public struct MufiRange: Codable, Equatable, Sendable {
    public let start: MufiPosition
    public let end: MufiPosition
    
    public init(start: MufiPosition, end: MufiPosition) {
        self.start = start
        self.end = end
    }
}

public struct MufiDiagnostic: Codable, Identifiable, Sendable {
    public var id = UUID()
    public let range: MufiRange
    public let severity: MufiDiagnosticSeverity
    public let message: String
    
    public init(range: MufiRange, severity: MufiDiagnosticSeverity, message: String) {
        self.range = range
        self.severity = severity
        self.message = message
    }
}

public enum MufiCompletionKind: UInt8, Codable, Sendable {
    case variable = 1
    case function = 2
    case `struct` = 3
    case keyword = 4
}

public struct MufiCompletionItem: Codable, Identifiable, Sendable {
    public var id = UUID()
    public let name: String
    public let typeName: String?
    public let docString: String?
    public let kind: MufiCompletionKind
    
    public init(name: String, typeName: String?, docString: String?, kind: MufiCompletionKind) {
        self.name = name
        self.typeName = typeName
        self.docString = docString
        self.kind = kind
    }
}
