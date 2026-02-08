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
public final class DocumentationService: ObservableObject {
    public static let shared = DocumentationService()
    
    private var entries: [DocumentationEntry] = []
    
    public init() {
        loadDocumentation()
    }
    
    private func loadDocumentation() {
        var loadedEntries: [DocumentationEntry] = []
        
        print("📚 DocumentationService: Starting to load documentation...")
        
        let bundle = Bundle.module
        print("📦 DocumentationService: Bundle URL: \(bundle.bundleURL.path)")
        
        if let resourceURL = bundle.resourceURL {
            print("📂 DocumentationService: Resource URL: \(resourceURL.path)")
            scanDirectory(at: resourceURL, loadedEntries: &loadedEntries)
        }
        
        self.entries = loadedEntries
        print("🏁 DocumentationService: Finished loading \(entries.count) entries.")
    }
    
    private func scanDirectory(at url: URL, loadedEntries: inout [DocumentationEntry]) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        for itemURL in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    scanDirectory(at: itemURL, loadedEntries: &loadedEntries)
                } else if itemURL.pathExtension == "md" {
                    // Determine category based on parent folder
                    let categoryFolder = itemURL.deletingLastPathComponent().lastPathComponent
                    let category: DocumentationCategory
                    if categoryFolder.lowercased() == "syntax" {
                        category = .syntax
                    } else if categoryFolder.lowercased() == "stdlib" {
                        category = .stdLib
                    } else {
                        // Skip if not in a known category folder
                        continue
                    }
                    
                    if let content = try? String(contentsOf: itemURL, encoding: .utf8) {
                        let title = extractTitle(from: content) ?? itemURL.deletingPathExtension().lastPathComponent
                        let entry = DocumentationEntry(
                            title: title,
                            category: category,
                            content: content,
                            fileName: itemURL.lastPathComponent
                        )
                        loadedEntries.append(entry)
                        print("✅ DocumentationService: Loaded \(title) from \(itemURL.path)")
                    }
                }
            }
        }
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
