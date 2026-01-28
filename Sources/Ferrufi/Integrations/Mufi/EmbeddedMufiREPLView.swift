// EmbeddedMufiREPLView.swift
// Ferrufi
//
// Embedded REPL that uses the in-process Mufi runtime via `MufiBridge`.
// Provides a simple interactive console (input line + scrollable output).
//
// Usage:
// - The view will attempt to initialize the embedded runtime on appear.
// - Type an expression or statement and press Enter (or click Send) to evaluate.
// - Output printed by the runtime (stdout/stderr) will be captured and displayed.
//
// Notes:
// - This REPL uses `MufiBridge.shared` which manages initialization and interpretation.
// - Calls to the runtime are serialized and run off the main thread; UI updates happen on the main actor.

import SwiftUI

private struct VariableEntry: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var value: String
    var typeName: String?
}

public struct EmbeddedMufiREPLView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var output: String = ""
    @State private var inputText: String = ""
    @State private var isBusy: Bool = false

    // Command window state: history, navigation, counters
    @State private var history: [String] = []
    @State private var historyIndex: Int? = nil
    @State private var draftInput: String = ""
    @State private var commandCounter: Int = 0
    @State private var showHistoryPopover: Bool = false
    @State private var historyQuery: String = ""
    @State private var workspaceVariables: [VariableEntry] = []
    @State private var workspaceBusy: Bool = false

    @FocusState private var inputFocused: Bool

    // Anchor ID for autoscroll to bottom
    private let bottomAnchor = UUID()

    public init() {}

    public var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                // Toolbar (Command Window)
                HStack {
                    Text("Command Window")
                        .font(themeManager.monospacedHeadline)

                    Spacer()

                    Button(action: { showHistoryPopover.toggle() }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .help("Show command history")
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showHistoryPopover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Commands")
                                .font(.headline)
                                .padding(.top, 8)
                                .padding(.horizontal)

                            // Search history
                            TextField("Search history", text: $historyQuery)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)

                            Divider()

                            // Filtered results
                            let filtered =
                                historyQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? history
                                : history.filter {
                                    $0.lowercased().contains(historyQuery.lowercased())
                                }

                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(filtered.enumerated()), id: \.offset) {
                                        idx, cmd in
                                        Button(action: {
                                            inputText = cmd
                                            // Align historyIndex with canonical history array if possible
                                            if let found = history.firstIndex(of: cmd) {
                                                historyIndex = found
                                            } else {
                                                historyIndex = nil
                                            }
                                            showHistoryPopover = false
                                        }) {
                                            Text(cmd)
                                                .font(themeManager.monospacedFont(ofSize: 12))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal)
                                                .padding(.vertical, 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(width: 520, height: 280)
                            .padding(.bottom, 8)

                            HStack {
                                Spacer()
                                Text("Tip: Option+↑ / Option+↓ to jump to oldest/newest")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                        .frame(minWidth: 420)
                    }

                    Button(action: { clearOutput() }) {
                        Image(systemName: "trash")
                    }
                    .help("Clear output")
                    .buttonStyle(PlainButtonStyle())

                    if isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .border(Color(NSColor.separatorColor), width: 0.5)

                Divider()

                // Output area
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(output.isEmpty ? "(no output yet)" : output)
                            .font(themeManager.monospacedFont(ofSize: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id(bottomAnchor)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .onChange(of: output) {
                        // Auto-scroll to bottom when output changes (updated API)
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(bottomAnchor, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input area (command prompt style)
                HStack(alignment: .top, spacing: 10) {
                    Text("mufi>")
                        .font(themeManager.monospacedFont(ofSize: 13))
                        .padding(.leading, 8)
                        .padding(.top, 8)

                    ZStack(alignment: .topLeading) {
                        REPLInputView(
                            text: $inputText,
                            placeholder: "Type Mufi code (Shift+Enter for newline)",
                            onCommit: { _ in sendInput() },
                            onHistoryUp: { historyUp() },
                            onHistoryDown: { historyDown() },
                            onHistoryJumpTop: { historyJumpToOldest() },
                            onHistoryJumpBottom: { historyJumpToNewest() },
                            onClear: { clearInput() },
                            autofocus: true,
                            minHeight: 28
                        )
                        .environmentObject(themeManager)
                        .frame(minHeight: 28)

                        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Type Mufi code (Shift+Enter for newline)")
                                .foregroundColor(.secondary)
                                .font(themeManager.monospacedFont(ofSize: 12))
                                .padding(.leading, 12)
                                .padding(.top, 10)
                                .allowsHitTesting(false)
                        }
                    }

                    Button(action: sendInput) {
                        Image(systemName: "play.fill")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            MufiWorkspaceView(
                variables: $workspaceVariables,
                onInsert: { name in inputText = name },
                onRefresh: { name in Task { await refreshVariable(name) } },
                onRemove: { name in removeWorkspaceVariable(name) },
                onRefreshAll: { refreshWorkspaceAll() }
            )
            .environmentObject(themeManager)
            .frame(minWidth: 260)
        }
        .frame(minWidth: 920, minHeight: 360)
        .onAppear {
            // Initialize display and load history
            output.append("[Mufi REPL ready - runtime initialized at app startup]\n")
            inputFocused = true

            Task {
                history = await REPLHistory.shared.getRecent(limit: 500)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .replHistoryDidChange)) { _ in
            Task {
                history = await REPLHistory.shared.getRecent(limit: 500)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .executeInREPL)) { notification in
            // Receive code from the editor to execute
            if let code = notification.object as? String {
                executeCode(code)
            }
        }
    }

    // MARK: - Actions

    private func clearOutput() {
        output = ""
    }

    private func sendInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isBusy else { return }

        // Update counters/history and echo the input using a command-window prompt
        commandCounter += 1
        appendOutput("\nmufi> [\(commandCounter)] \(trimmed)\n")

        // Persist the command to history (background) and refresh our local cache
        Task {
            await REPLHistory.shared.addCommand(trimmed)
            history = await REPLHistory.shared.getRecent(limit: 500)
        }

        // Reset input and history navigation state
        inputText = ""
        draftInput = ""
        historyIndex = nil
        inputFocused = true

        isBusy = true

        Task {
            do {
                // Add timeout to prevent hanging
                let result = try await withThrowingTaskGroup(of: (UInt8, String).self) { group in
                    group.addTask {
                        try await MufiBridge.shared.interpret(trimmed)
                    }

                    // 30 second timeout
                    group.addTask {
                        try await Task.sleep(nanoseconds: 30_000_000_000)
                        throw MufiError.captureFailed(reason: "Interpretation timeout")
                    }

                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }

                let (status, captured) = result

                await MainActor.run {
                    if !captured.isEmpty {
                        appendOutput(captured)
                    }

                    // Update workspace vars by parsing any lines like 'name: value'
                    let parsedVars = parseNameValueLines(captured)
                    for (name, value) in parsedVars {
                        if let i = workspaceVariables.firstIndex(where: { $0.name == name }) {
                            workspaceVariables[i].value = value
                        } else {
                            workspaceVariables.insert(
                                VariableEntry(name: name, value: value, typeName: nil), at: 0)
                        }
                    }

                    // Only show non-zero status to reduce noise (no timing info)
                    if status != 0 {
                        appendOutput("\n[Status: \(status)]\n")
                    }
                    isBusy = false
                }

                // Track assignments in the executed code and refresh those variables in workspace
                let assigned = extractAssignedNames(from: trimmed)
                for name in assigned {
                    addOrRefreshVariable(name)
                }

                // Assignment tracking already handled above (duplicate removed)
            } catch {
                await MainActor.run {
                    appendOutput("\n[Error: \(error.localizedDescription)]\n")
                    appendOutput("\nTip: Avoid infinite loops or very long computations\n")
                    isBusy = false
                }
            }
        }
    }

    // Navigate to the previous (older) command in history
    private func historyUp() {
        Task {
            if history.isEmpty {
                history = await REPLHistory.shared.getRecent(limit: 200)
            }
            guard !history.isEmpty else { return }

            if historyIndex == nil {
                draftInput = inputText
                historyIndex = 0
            } else if let idx = historyIndex, idx + 1 < history.count {
                historyIndex = idx + 1
            }

            if let idx = historyIndex, idx < history.count {
                inputText = history[idx]
            }
        }
    }

    // Navigate to the next (more recent) command in history
    private func historyDown() {
        Task {
            if history.isEmpty {
                history = await REPLHistory.shared.getRecent(limit: 200)
            }
            guard !history.isEmpty else { return }

            if let idx = historyIndex {
                if idx == 0 {
                    inputText = draftInput
                    historyIndex = nil
                } else {
                    historyIndex = idx - 1
                    if let i = historyIndex { inputText = history[i] }
                }
            }
        }
    }

    private func historyJumpToOldest() {
        Task {
            if history.isEmpty {
                history = await REPLHistory.shared.getRecent(limit: 200)
            }
            guard !history.isEmpty else { return }
            historyIndex = history.count - 1
            inputText = history[historyIndex!]
        }
    }

    private func historyJumpToNewest() {
        Task {
            if history.isEmpty {
                history = await REPLHistory.shared.getRecent(limit: 200)
            }
            guard !history.isEmpty else { return }
            historyIndex = 0
            inputText = history[0]
        }
    }

    private func clearInput() {
        inputText = ""
        draftInput = ""
    }

    // MARK: - Helpers

    @MainActor
    private func appendOutput(_ str: String) {
        output.append(str)
    }

    /// Parse lines of the form `name: value` or `name = value` from captured output
    private func parseNameValueLines(_ s: String) -> [(String, String)] {
        var out: [(String, String)] = []
        let ns = s as NSString
        let pattern = #"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:[:=])\s*(.+)$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        else { return [] }
        let matches = re.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
        for m in matches {
            if m.numberOfRanges >= 3 {
                let name = ns.substring(with: m.range(at: 1))
                let value = ns.substring(with: m.range(at: 2))
                out.append((name, value))
            }
        }
        return out
    }

    /// Extract simple variable assignment targets from source code.
    /// Heuristics: `var NAME =` and `NAME =` lines (top-level)
    private func extractAssignedNames(from source: String) -> [String] {
        var set = Set<String>()
        let ns = source as NSString

        do {
            // Match `var NAME = ...`
            let reVar = try NSRegularExpression(
                pattern: #"(?m)\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*="#, options: [])
            let matchesVar = reVar.matches(
                in: source, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matchesVar {
                if m.numberOfRanges >= 2 {
                    let name = ns.substring(with: m.range(at: 1))
                    set.insert(name)
                }
            }

            // Match simple assignments at the start of lines: `NAME = ...`
            let reAssign = try NSRegularExpression(
                pattern: #"(?m)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*="#, options: [])
            let matchesAssign = reAssign.matches(
                in: source, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matchesAssign {
                if m.numberOfRanges >= 2 {
                    let name = ns.substring(with: m.range(at: 1))
                    set.insert(name)
                }
            }
        } catch {
            // Ignore regex errors — we'll simply return whatever we've found so far.
        }

        return Array(set)
    }

    /// Ensure a variable is tracked and refresh its value from the runtime.
    private func addOrRefreshVariable(_ name: String) {
        // add placeholder if not present
        if let i = workspaceVariables.firstIndex(where: { $0.name == name }) {
            workspaceVariables[i].value = "(fetching...)"
        } else {
            workspaceVariables.insert(
                VariableEntry(name: name, value: "(fetching...)", typeName: nil), at: 0)
        }

        // fire off an async refresh
        Task {
            await refreshVariable(name)
        }
    }

    /// Refresh a single variable by issuing a print(NAME) in the runtime and capturing result.
    private func refreshVariable(_ name: String) async {
        do {
            let result = try await withThrowingTaskGroup(of: (UInt8, String).self) { group in
                group.addTask {
                    try await MufiBridge.shared.interpret("print(\(name))")
                }
                // small per-variable timeout (1s) so a hung print doesn't block the UI
                group.addTask {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    throw MufiError.captureFailed(reason: "Timeout")
                }
                let res = try await group.next()!
                group.cancelAll()
                return res
            }
            let (_, captured) = result
            await MainActor.run {
                if let i = workspaceVariables.firstIndex(where: { $0.name == name }) {
                    workspaceVariables[i].value = captured.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                } else {
                    workspaceVariables.insert(
                        VariableEntry(
                            name: name,
                            value: captured.trimmingCharacters(in: .whitespacesAndNewlines),
                            typeName: nil), at: 0)
                }
            }
        } catch {
            await MainActor.run {
                let errMsg = "[error: \(error.localizedDescription)]"
                if let i = workspaceVariables.firstIndex(where: { $0.name == name }) {
                    workspaceVariables[i].value = errMsg
                } else {
                    workspaceVariables.insert(
                        VariableEntry(name: name, value: errMsg, typeName: nil), at: 0)
                }
            }
        }
    }

    /// Refresh all tracked variables (non-blocking).
    private func refreshWorkspaceAll() {
        for v in workspaceVariables {
            Task {
                await refreshVariable(v.name)
            }
        }
    }

    private func removeWorkspaceVariable(_ name: String) {
        if let i = workspaceVariables.firstIndex(where: { $0.name == name }) {
            workspaceVariables.remove(at: i)
        }
    }

    private func executeCode(_ code: String) {
        guard !isBusy else { return }

        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Echo the code being executed (command-window style) and add it to history
        commandCounter += 1
        appendOutput("\nmufi> [\(commandCounter)] // Executing from editor:\n")

        // Limit display to first 500 chars for very long code
        if trimmed.count > 500 {
            appendOutput(String(trimmed.prefix(500)))
            appendOutput("\n... (\(trimmed.count - 500) more characters)\n")
        } else {
            appendOutput(trimmed)
            appendOutput("\n")
        }

        // Optionally add editor-executed code to history
        Task {
            await REPLHistory.shared.addCommand(trimmed)
            history = await REPLHistory.shared.getRecent(limit: 200)
        }

        isBusy = true
        Task {
            do {
                // Add timeout for safety
                let result = try await withThrowingTaskGroup(of: (UInt8, String).self) { group in
                    group.addTask {
                        try await MufiBridge.shared.interpret(trimmed)
                    }

                    // 60 second timeout for full scripts
                    group.addTask {
                        try await Task.sleep(nanoseconds: 60_000_000_000)
                        throw MufiError.captureFailed(reason: "Execution timeout (60s)")
                    }

                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }

                let (status, captured) = result
                await MainActor.run {
                    if !captured.isEmpty {
                        appendOutput(captured)
                    }

                    // Update workspace vars by parsing any lines like 'name: value'
                    let parsedVars = parseNameValueLines(captured)
                    for (name, value) in parsedVars {
                        if let i = workspaceVariables.firstIndex(where: { $0.name == name }) {
                            workspaceVariables[i].value = value
                        } else {
                            workspaceVariables.insert(
                                VariableEntry(name: name, value: value, typeName: nil), at: 0)
                        }
                    }

                    if status != 0 {
                        appendOutput("\n[Status: \(status)]\n")
                    }
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    appendOutput("\n[Error: \(error.localizedDescription)]\n")
                    isBusy = false
                }
            }
        }
    }

}

private struct MufiWorkspaceView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var variables: [VariableEntry]
    var onInsert: ((String) -> Void)? = nil
    var onRefresh: ((String) -> Void)? = nil
    var onRemove: ((String) -> Void)? = nil
    var onRefreshAll: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Spacer()
                    Text("Workspace")
                        .font(themeManager.monospacedHeadline)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: { onRefreshAll?() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Refresh all tracked variables")
                        Button("Clear") {
                            variables.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            Divider()
            // Table-style display for variables (MATLAB-like)
            Table(variables) {
                TableColumn("Name") { entry in
                    Text(entry.name)
                        .font(themeManager.monospacedFont(ofSize: 12))
                }
                TableColumn("Value") { entry in
                    HStack {
                        Text(entry.value)
                            .font(themeManager.monospacedFont(ofSize: 12))
                            .lineLimit(1)
                        Spacer()
                        Button("Insert") {
                            onInsert?(entry.name)
                            NotificationCenter.default.post(name: .replFocusInput, object: nil)
                        }
                        .buttonStyle(.plain)
                        Button("Refresh") {
                            onRefresh?(entry.name)
                        }
                        .buttonStyle(.plain)
                        Button("Remove") {
                            onRemove?(entry.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minWidth: 260, maxHeight: .infinity)
        }
    }
}
