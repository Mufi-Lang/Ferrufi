//
//  DocumentationService.swift
//  Ferrufi
//

import Foundation

public enum DocumentationCategory: String, Codable, CaseIterable {
    case syntax = "Syntax"
    case stdLib = "StdLib"
    
    public var displayName: String {
        switch self {
        case .syntax: return "Syntax"
        case .stdLib: return "Standard Library"
        }
    }
}

public struct DocumentationEntry: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let category: DocumentationCategory
    public let content: String
    public let fileName: String
    
    public init(id: UUID = UUID(), title: String, category: DocumentationCategory, content: String, fileName: String) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.fileName = fileName
    }
}

@MainActor
public final class DocumentationService {
    public static let shared = DocumentationService()
    
    private var entries: [DocumentationEntry] = []
    
    public init() {
        loadDocumentation()
    }
    
    private func loadDocumentation() {
        var loadedEntries: [DocumentationEntry] = []
        
        for category in DocumentationCategory.allCases {
            let resourcePath = "Resources/Documentation/\(category.rawValue)"
            guard let url = Bundle.module.url(forResource: resourcePath, withExtension: nil) else {
                continue
            }
            
            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for fileURL in files where fileURL.pathExtension == "md" {
                if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                    let title = extractTitle(from: content) ?? fileURL.deletingPathExtension().lastPathComponent
                    let entry = DocumentationEntry(
                        title: title,
                        category: category,
                        content: content,
                        fileName: fileURL.lastPathComponent
                    )
                    loadedEntries.append(entry)
                }
            }
        }
        
        self.entries = loadedEntries
    }
    
    private func extractTitle(from markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("# ") {
                return line.replacingOccurrences(of: "# ", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    public func search(query: String) -> [DocumentationEntry] {
        if query.isEmpty {
            return entries.sorted { $0.title < $1.title }
        }
        
        let lowerQuery = query.lowercased()
        return entries.filter { entry in
            entry.title.lowercased().contains(lowerQuery) ||
            entry.content.lowercased().contains(lowerQuery) ||
            entry.category.displayName.lowercased().contains(lowerQuery)
        }.sorted { $0.title < $1.title }
    }
    
    public func allEntries() -> [DocumentationEntry] {
        return entries.sorted { $0.title < $1.title }
    }
}
