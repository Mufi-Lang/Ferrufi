//
//  MufiLSPService.swift
//  Ferrufi
//
//  High-level Language Server Protocol service for Mufi.
//  Manages the analysis context and provides diagnostics and completions.
//

import Combine
import CoreGraphics
import Foundation

@MainActor
public final class MufiLSPService: ObservableObject {
    public static let shared = MufiLSPService()

    private let bridge = MufiBridge.shared

    @Published public private(set) var diagnostics: [MufiDiagnostic] = []
    @Published public private(set) var lastAnalysisSuccess: Bool = false
    @Published public private(set) var lastAnalysisTimestamp: Date?

    // Completion State
    @Published public var isCompletionActive: Bool = false
    @Published public var completionItems: [MufiCompletionItem] = []
    @Published public var selectedCompletionIndex: Int = 0
    public var completionPosition: MufiPosition?
    @Published public var completionUIAnchor: CGRect = .zero

    private var updateSubject = PassthroughSubject<(String, String), Never>()
    private var cancellables = Set<AnyCancellable>()

    private let mufiKeywords = [
        "and", "break", "case", "class", "const", "continue", "each",
        "else", "end", "false", "for", "foreach", "fun", "if", "in",
        "item", "let", "nil", "or", "print", "return", "self", "super",
        "switch", "true", "var", "while",
    ].map { MufiCompletionItem(name: $0, typeName: "keyword", docString: nil, kind: .keyword) }

    private let mufiStdLib = [
        // core
        "what_is",
        // math
        "ln", "log2", "log10", "pi", "exp", "sin", "cos", "tan", "asin", "acos", "atan",
        "complex", "abs", "phase", "rand", "randn", "pow", "sqrt", "ceil", "floor", "round", "max",
        "min",
        // io
        "print", "printf", "println", "input",
        // types
        "str", "int", "double", "bool_fn", "type_of", "is_nil", "is_string", "is_number", "is_bool",
        // utils
        "assert", "exit", "panic", "format", "equals", "hash", "clone", "identity",
        // collections
        "linked_list", "hash_table", "fvec", "push", "pop", "push_front", "pop_front", "len", "get",
        "set",
        "contains", "clear", "range", "range_to_array", "put", "pairs", "is_empty", "nth",
        "linspace",
        "insert", "remove", "slice", "merge", "search", "sort", "splice", "sum", "mean", "vari",
        "stddev",
        "std_alias", "minl", "maxl", "reverse",
        // matrix
        "eye", "ones", "zeros", "transpose", "det", "inv", "trace", "size", "norm", "matrix_get",
        "matrix_set",
        "flatten", "horzcat", "vertcat", "matrix_create", "reshape", "rref", "rank",
        // json
        "json_parse", "json_stringify", "json_is_valid", "json_pretty", "json_get", "json_set",
        // serde
        "serde_serialize", "serde_deserialize", "serde_to_json", "serde_from_json", "serde_to_toml",
        "serde_from_toml", "serde_to_yaml", "serde_from_yaml", "serde_detect_format",
        "serde_validate",
        // filesystem
        "create_file", "write_file", "read_file", "delete_file", "create_dir", "delete_dir",
        "file_exists",
        "dir_exists", "file_size", "copy_file",
        // time
        "now", "now_ns", "now_ms", "now_us", "sleep", "sleep_ms", "sleep_us", "time_diff",
        // network
        "http_get", "http_post", "http_put", "http_delete", "set_content_type", "set_auth",
        "parse_url",
        "url_encode", "url_decode", "open_url",
    ].map {
        MufiCompletionItem(
            name: $0, typeName: "function", docString: "Standard Library", kind: .function)
    }

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        // Debounce updates to avoid excessive re-parsing
        // Increased debounce to 1 second to avoid premature error reports while typing
        updateSubject
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] filename, source in
                self?.performAnalysis(filename: filename, source: source)
            }
            .store(in: &cancellables)
    }

    /// Notify the service that a document has changed.
    public func documentChanged(filename: String, source: String, force: Bool = false) {
        if force {
            // Immediate analysis (e.g. on Enter or Save)
            performAnalysis(filename: filename, source: source)
        } else {
            updateSubject.send((filename, source))
        }
    }

    private func performAnalysis(filename: String, source: String) {
        Task {
            // Attempt lazy initialization if needed (idempotent)
            try? await bridge.initialize()

            let success = await bridge.updateSource(filename: filename, source: source)
            let newDiagnostics = await bridge.getDiagnostics()

            await MainActor.run {
                self.lastAnalysisSuccess = success
                self.lastAnalysisTimestamp = Date()
                self.diagnostics = newDiagnostics
            }
        }
    }

    /// Trigger completions at the specified position.
    public func triggerCompletions(
        line: UInt32, column: UInt32, prefix: String = "", anchor: CGRect = .zero
    ) {
        Task {
            let bridgeItems = await bridge.getCompletions(line: line, column: column)

            // Merge keywords, stdlib, and bridge items
            var allItems = bridgeItems
            let fallbacks = mufiKeywords + mufiStdLib
            for fb in fallbacks {
                if !allItems.contains(where: { $0.name == fb.name }) {
                    allItems.append(fb)
                }
            }

            // Client-side filtering
            let filteredItems: [MufiCompletionItem]
            if prefix.isEmpty || prefix == "." {
                filteredItems = allItems
            } else {
                let searchPrefix = prefix.lowercased()
                filteredItems = allItems.filter { $0.name.lowercased().contains(searchPrefix) }
                    .sorted { (a, b) -> Bool in
                        // Prioritize items starting with the prefix
                        let aStarts = a.name.lowercased().hasPrefix(searchPrefix)
                        let bStarts = b.name.lowercased().hasPrefix(searchPrefix)
                        if aStarts != bStarts { return aStarts }

                        // Then prioritize keywords
                        if a.kind == .keyword && b.kind != .keyword { return true }
                        if b.kind == .keyword && a.kind != .keyword { return false }

                        return a.name < b.name
                    }
            }

            await MainActor.run {
                if !filteredItems.isEmpty {
                    self.completionItems = filteredItems
                    self.selectedCompletionIndex = 0
                    self.completionPosition = MufiPosition(line: line, column: column)
                    self.completionUIAnchor = anchor
                    self.isCompletionActive = true
                } else {
                    self.cancelCompletion()
                }
            }
        }
    }

    public func cancelCompletion() {
        isCompletionActive = false
        completionItems = []
        selectedCompletionIndex = 0
        completionPosition = nil
    }

    public func moveCompletionSelectionUp() {
        guard isCompletionActive && !completionItems.isEmpty else { return }
        selectedCompletionIndex =
            (selectedCompletionIndex - 1 + completionItems.count) % completionItems.count
    }

    public func moveCompletionSelectionDown() {
        guard isCompletionActive && !completionItems.isEmpty else { return }
        selectedCompletionIndex = (selectedCompletionIndex + 1) % completionItems.count
    }

    public var selectedCompletion: MufiCompletionItem? {
        guard isCompletionActive && selectedCompletionIndex < completionItems.count else {
            return nil
        }
        return completionItems[selectedCompletionIndex]
    }

    /// Get completions at the specified position.
    public func getCompletions(line: UInt32, column: UInt32) async -> [MufiCompletionItem] {
        return await bridge.getCompletions(line: line, column: column)
    }

    /// Get hover info at the specified position.
    public func getHoverInfo(line: UInt32, column: UInt32) async -> MufiCompletionItem? {
        return await bridge.getHoverInfo(line: line, column: column)
    }

    /// Get definition range for symbol at specified position.
    public func getDefinitionRange(line: UInt32, column: UInt32, source: String) async -> MufiRange? {
        // 1. Try bridge (placeholder, as bridge doesn't support it yet)
        // let range = await bridge.getDefinition(line: line, column: column)
        
        // 2. Fallback: Simple regex search in current file for 'fun name' or 'let name'
        // First, extract the word at the position
        let lines = source.components(separatedBy: "\n")
        guard line < lines.count else { return nil }
        let lineText = lines[Int(line)]
        
        // Find word under cursor
        let word = extractWord(at: column, in: lineText)
        guard !word.isEmpty else { return nil }
        
        // Search for definition: 'fun word', 'let word', 'var word'
        let patterns = [
            "fun\\s+\(word)\\b",
            "let\\s+\(word)\\b",
            "var\\s+\(word)\\b",
            "class\\s+\(word)\\b"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for (i, l) in lines.enumerated() {
                    let range = NSRange(location: 0, length: l.utf16.count)
                    if let match = regex.firstMatch(in: l, options: [], range: range) {
                        // Found it!
                        let startCol = UInt32(match.range.location)
                        let endCol = UInt32(match.range.location + match.range.length)
                        return MufiRange(
                            start: MufiPosition(line: UInt32(i), column: startCol),
                            end: MufiPosition(line: UInt32(i), column: endCol)
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractWord(at column: UInt32, in text: String) -> String {
        let nsString = text as NSString
        let col = Int(column)
        guard col < nsString.length else { return "" }
        
        var start = col
        while start > 0 {
            let r = NSRange(location: start - 1, length: 1)
            let char = nsString.substring(with: r)
            if char.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "_"))) != nil {
                break
            }
            start -= 1
        }
        
        var end = col
        while end < nsString.length {
            let r = NSRange(location: end, length: 1)
            let char = nsString.substring(with: r)
            if char.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "_"))) != nil {
                break
            }
            end += 1
        }
        
        if start >= end { return "" }
        return nsString.substring(with: NSRange(location: start, length: end - start))
    }
}
