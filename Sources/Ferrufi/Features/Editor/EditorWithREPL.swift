//
//  EditorWithREPL.swift
//  Ferrufi
//
//  Enhanced editor view with inline REPL mode alongside preview
//  Allows users to:
//  - Edit code in the left pane
//  - See preview in the middle pane
//  - Use interactive REPL in the right pane
//

import SwiftUI

/// Display mode for the editor
enum EditorDisplayMode: String, CaseIterable {
    case editorOnly = "Editor Only"
    case editorPreview = "Editor + Preview"
    case editorREPL = "Editor + REPL"
    case editorPreviewREPL = "All Panes"
}

/// Enhanced editor with integrated REPL support
struct EditorWithREPL: View {
    @Binding var note: Note?
    @Binding var content: String

    @State private var isEditing = false
    @State private var displayMode: EditorDisplayMode = .editorPreview
    @State private var showTerminal = false
    @State private var outputText: String = ""
    @State private var exitStatus: UInt8 = 0
    @State private var executionTime: TimeInterval?
    @State private var isRunningScript = false
    @State private var lastSaveTime: Date = Date()
    @State private var autoSaveTimer: Timer?

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var folderManager: FolderManager

    // Auto-save configuration
    private let autoSaveInterval: TimeInterval = 2.0
    private let autoSaveDelay: TimeInterval = 0.5

    var body: some View {
        VStack(spacing: 0) {
            // Main toolbar
            mainToolbar

            Divider()

            // Content area based on display mode
            contentArea

            // Terminal output (if enabled)
            if showTerminal {
                Divider()

                MufiTerminalView(
                    output: outputText,
                    exitStatus: exitStatus,
                    executionTime: executionTime,
                    onClear: {
                        clearTerminal()
                    },
                    onClose: {
                        withAnimation {
                            showTerminal = false
                        }
                    }
                )
                .frame(height: 250)
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            setupAutoSave()
            setupNotificationObservers()
        }
        .onDisappear {
            stopAutoSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWikiLink)) { notification in
            if let noteName = notification.object as? String {
                openWikiLink(noteName)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileLink)) { notification in
            if let url = notification.object as? URL {
                openFileLink(url)
            }
        }
    }

    // MARK: - Main Toolbar

    @ViewBuilder
    private var mainToolbar: some View {
        HStack {
            // Edit mode indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(isEditing ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)

                Text(isEditing ? "Editing" : "Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Formatting buttons
            Group {
                Button(action: { insertFormatting("**", "**", "bold text") }) {
                    Image(systemName: "bold")
                }
                .help("Bold (⌘B)")

                Button(action: { insertFormatting("*", "*", "italic text") }) {
                    Image(systemName: "italic")
                }
                .help("Italic (⌘I)")

                Button(action: { insertFormatting("[", "](url)", "link text") }) {
                    Image(systemName: "link")
                }
                .help("Link (⌘K)")

                Divider()
                    .frame(height: 16)

                Button(action: { insertList() }) {
                    Image(systemName: "list.bullet")
                }
                .help("Insert List")

                Button(action: { insertHeader() }) {
                    Image(systemName: "textformat.size")
                }
                .help("Insert Header")
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.secondary)

            Spacer()

            // Display mode picker
            Picker("", selection: $displayMode) {
                ForEach(EditorDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .help("Change display mode")

            Spacer()

            // Action buttons
            Group {
                // Run script button
                Button(action: { runScript() }) {
                    if isRunningScript {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
                .help("Run Mufi Script (⌘R)")
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                .disabled(isRunningScript)

                // Quick REPL toggle
                if displayMode != .editorREPL && displayMode != .editorPreviewREPL {
                    Button(action: { toggleREPL() }) {
                        Image(systemName: "terminal")
                    }
                    .help("Show REPL")
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                }

                // Save indicator
                if Date().timeIntervalSince(lastSaveTime) < 2.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch displayMode {
        case .editorOnly:
            editorPane
        case .editorPreview:
            HSplitView {
                editorPane
                previewPane
            }
        case .editorREPL:
            HSplitView {
                editorPane
                replPane
            }
        case .editorPreviewREPL:
            HSplitView {
                editorPane
                previewPane
                replPane
            }
        }
    }

    // MARK: - Editor Pane

    @ViewBuilder
    private var editorPane: some View {
        VStack(spacing: 0) {
            // Editor pane header
            HStack {
                Text("Editor")
                    .font(.headline)
                Spacer()
                Text("\(content.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            MarkdownEditor(
                text: $content,
                isEditing: $isEditing,
                onTextChange: { newText in
                    handleTextChange(newText)
                },
                onSave: {
                    saveNote()
                }
            )
        }
        .frame(minWidth: 300)
    }

    // MARK: - Preview Pane

    @ViewBuilder
    private var previewPane: some View {
        VStack(spacing: 0) {
            // Preview pane header
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                if let wordCount = getWordCount() {
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            MarkdownPreview(
                markdown: content,
                baseURL: note?.url?.deletingLastPathComponent()
            )
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 300)
    }

    // MARK: - REPL Pane

    @ViewBuilder
    private var replPane: some View {
        VStack(spacing: 0) {
            // REPL pane header
            HStack {
                Text("Mufi REPL")
                    .font(.headline)
                Spacer()
                Button(action: {
                    // Quick action to send current selection or entire content to REPL
                    sendToREPL(content)
                }) {
                    Image(systemName: "arrow.right.circle")
                }
                .help("Send code to REPL")
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            EmbeddedMufiREPLView()
        }
        .frame(minWidth: 350)
    }

    // MARK: - Actions

    private func toggleREPL() {
        switch displayMode {
        case .editorOnly:
            displayMode = .editorREPL
        case .editorPreview:
            displayMode = .editorPreviewREPL
        case .editorREPL:
            displayMode = .editorOnly
        case .editorPreviewREPL:
            displayMode = .editorPreview
        }
    }

    private func sendToREPL(_ code: String) {
        // Post notification to REPL to execute code
        NotificationCenter.default.post(
            name: .executeInREPL,
            object: code
        )
    }

    // MARK: - Text Handling

    private func handleTextChange(_ newText: String) {
        content = newText
        scheduleAutoSave()
    }

    private func insertFormatting(_ prefix: String, _ suffix: String, _ placeholder: String) {
        NotificationCenter.default.post(
            name: .insertMarkdownFormatting,
            object: MarkdownFormatting(prefix: prefix, suffix: suffix, placeholder: placeholder)
        )
    }

    private func insertList() {
        NotificationCenter.default.post(name: .insertMarkdownList, object: nil)
    }

    private func insertHeader() {
        NotificationCenter.default.post(name: .insertMarkdownHeader, object: nil)
    }

    // MARK: - Auto-save

    private func setupAutoSave() {
        // Auto-save is handled by the text change with a delay
    }

    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveDelay, repeats: false) { _ in
            Task { @MainActor in
                saveNote()
            }
        }
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func saveNote() {
        guard let note = note, !content.isEmpty else { return }

        Task {
            do {
                try await folderManager.updateNoteContent(note, content: content)
                await MainActor.run {
                    lastSaveTime = Date()
                }
            } catch {
                print("Failed to save note: \(error)")
            }
        }
    }

    // MARK: - Mufi Integration

    private func runScript() {
        guard !isRunningScript else { return }
        isRunningScript = true

        let startTime = Date()

        Task {
            do {
                let (status, output) = try await MufiBridge.shared.interpret(content)
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)

                await MainActor.run {
                    outputText = output.isEmpty ? "[No output]" : output
                    exitStatus = status
                    executionTime = duration
                    isRunningScript = false

                    withAnimation {
                        showTerminal = true
                    }
                }
            } catch {
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)

                await MainActor.run {
                    outputText = "Error: \(error.localizedDescription)"
                    exitStatus = 1
                    executionTime = duration
                    isRunningScript = false

                    withAnimation {
                        showTerminal = true
                    }
                }
            }
        }
    }

    private func clearTerminal() {
        outputText = ""
        exitStatus = 0
        executionTime = nil
    }

    // MARK: - Link Handling

    private func openWikiLink(_ noteName: String) {
        Task {
            if let foundNote = await folderManager.findNoteByName(noteName) {
                await MainActor.run {
                    note = foundNote
                    NotificationCenter.default.post(name: .navigateToNote, object: foundNote)
                }
            } else {
                await createNewNote(withName: noteName)
            }
        }
    }

    private func openFileLink(_ url: URL) {
        if url.pathExtension == "md" {
            Task {
                if let foundNote = await folderManager.findNoteByURL(url) {
                    await MainActor.run {
                        note = foundNote
                        NotificationCenter.default.post(name: .navigateToNote, object: foundNote)
                    }
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func createNewNote(withName name: String) async {
        do {
            let newNote = try await folderManager.createNote(
                name: name,
                content:
                    "// \(name)\n// Created on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n",
                folder: folderManager.selectedFolder
            )
            await MainActor.run {
                note = newNote
                NotificationCenter.default.post(name: .navigateToNote, object: newNote)
            }
        } catch {
            print("Failed to create new note: \(error)")
        }
    }

    // MARK: - Utility

    private func getWordCount() -> Int? {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count > 0 ? words.count : nil
    }

    private func setupNotificationObservers() {
        // Set up any additional notification observers if needed
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let executeInREPL = Notification.Name("executeInREPL")
}

// MARK: - Preview

struct EditorWithREPL_Previews: PreviewProvider {
    static var previews: some View {
        EditorWithREPL(
            note: .constant(Note.sample),
            content: .constant(
                """
                # Mufi-Lang Examples in REPL Mode

                ## Basic Mufi Syntax

                // Variables and printing
                var x = 42
                var name = "Mufi"
                print("Hello from Mufi-lang!")
                print("x = " + str(x))

                ## Control Flow

                // Conditionals
                var age = 25
                if age >= 18 {
                    print("Adult")
                } else {
                    print("Minor")
                }

                // Loops
                var i = 0
                while i < 5 {
                    print("Count: " + str(i))
                    i = i + 1
                }

                ## Functions

                fn add(a, b) {
                    return a + b
                }

                fn greet(name) {
                    return "Hello, " + name + "!"
                }

                print(greet("World"))
                print("Sum: " + str(add(10, 20)))

                ## Arrays and Data

                var numbers = [1, 2, 3, 4, 5]
                var fruits = ["apple", "banana", "orange"]

                print("First number: " + str(numbers[0]))
                print("Second fruit: " + fruits[1])

                ## Try these in the REPL!
                // 1. Type expressions and see results immediately
                // 2. Define functions and call them interactively
                // 3. Test Mufi code snippets before saving
                """
            )
        )
        .environmentObject(FolderManager())
        .frame(width: 1200, height: 800)
    }
}
