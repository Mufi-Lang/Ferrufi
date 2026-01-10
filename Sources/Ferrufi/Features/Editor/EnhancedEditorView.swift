//
//  EnhancedEditorView.swift
//  Ferrufi
//
//  Created on 2024-12-19.
//

import Combine
import SwiftUI

/// Enhanced editor view with split-pane editing and live preview
struct EnhancedEditorView: View {
    @Binding var note: Note?
    @Binding var content: String

    @State private var isEditing = false
    @State private var showPreview = true
    @State private var showREPL = false
    @State private var showTerminal = false
    @State private var outputText: String = ""
    @State private var exitStatus: UInt8 = 0
    @State private var executionTime: TimeInterval?
    @State private var isRunningScript = false
    @State private var editorSplitRatio: Double = 0.5
    @State private var lastSaveTime: Date = Date()
    @State private var autoSaveTimer: Timer?

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var folderManager: FolderManager

    // Auto-save configuration
    private let autoSaveInterval: TimeInterval = 2.0
    private let autoSaveDelay: TimeInterval = 0.5

    private var isMarkdownFile: Bool {
        guard let note = note else { return false }
        return note.filePath.lowercased().hasSuffix(".md")
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                // Editor pane
                VStack(spacing: 0) {
                    editorToolbar

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

                // Preview pane (if enabled)
                if showPreview && isMarkdownFile {
                    VStack(spacing: 0) {
                        previewToolbar

                        MarkdownPreview(
                            markdown: content,
                            baseURL: note?.url?.deletingLastPathComponent()
                        )
                        .background(Color(NSColor.textBackgroundColor))
                    }
                    .frame(minWidth: 300)
                }
            }

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
        // REPL sheet
        .sheet(isPresented: $showREPL) {
            EmbeddedMufiREPLView()
                .frame(minWidth: 700, minHeight: 500)
        }
    }

    // MARK: - Editor Toolbar

    @ViewBuilder
    private var editorToolbar: some View {
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

            // Preview toggle
            Button(action: { showPreview.toggle() }) {
                Image(systemName: showPreview ? "eye.slash" : "eye")
            }
            .help("Toggle Preview")
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.secondary)

            // Run script
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

            // Open REPL
            Button(action: { showREPL.toggle() }) {
                Image(systemName: "terminal")
            }
            .help("Open Embedded Mufi REPL")
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color(NSColor.separatorColor), width: 0.5)
    }

    // MARK: - Preview Toolbar

    @ViewBuilder
    private var previewToolbar: some View {
        HStack {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Word count
            if let wordCount = getWordCount() {
                Text("\(wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Character count
            Text("\(content.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color(NSColor.separatorColor), width: 0.5)
    }

    // MARK: - Text Handling

    private func handleTextChange(_ newText: String) {
        content = newText
        scheduleAutoSave()
    }

    private func insertFormatting(_ prefix: String, _ suffix: String, _ placeholder: String) {
        // This would need to communicate with the MarkdownEditor to insert text
        // For now, we'll post a notification that the editor can listen to
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
            // Try to find the note by name
            if let foundNote = await folderManager.findNoteByName(noteName) {
                await MainActor.run {
                    note = foundNote
                    // This should trigger navigation in the parent view
                    NotificationCenter.default.post(name: .navigateToNote, object: foundNote)
                }
            } else {
                // Create new note if it doesn't exist
                await createNewNote(withName: noteName)
            }
        }
    }

    private func openFileLink(_ url: URL) {
        // Handle file:// links to other notes or attachments
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
            // Open external file
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

// MARK: - Supporting Types

struct MarkdownFormatting {
    let prefix: String
    let suffix: String
    let placeholder: String
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let insertMarkdownFormatting = Notification.Name("insertMarkdownFormatting")
    static let insertMarkdownList = Notification.Name("insertMarkdownList")
    static let insertMarkdownHeader = Notification.Name("insertMarkdownHeader")
    static let navigateToNote = Notification.Name("navigateToNote")
}

// MARK: - FolderManager Extensions

extension FolderManager {
    func findNoteByName(_ name: String) async -> Note? {
        return await MainActor.run {
            notes.first { note in
                note.title.lowercased() == name.lowercased()
                    || note.url?.deletingPathExtension().lastPathComponent.lowercased()
                        == name.lowercased()
            }
        }
    }

    func findNoteByURL(_ url: URL) async -> Note? {
        return await MainActor.run {
            notes.first { $0.url == url }
        }
    }

    public func updateNoteContent(_ note: Note, content: String) async throws {
        guard let url = note.url else {
            throw FerrufiError.fileSystem(.invalidPath("Note has no URL"))
        }

        try content.write(to: url, atomically: true, encoding: .utf8)

        await MainActor.run {
            // Update the note's content and metadata
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                var updatedNote = note
                updatedNote.content = content
                updatedNote.metadata.modifiedAt = Date()
                updatedNote.metadata.wordCount =
                    content.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }.count
                var mutableNotes = notes
                mutableNotes[index] = updatedNote
                notes = mutableNotes
            }
        }
    }
}

// MARK: - Preview

struct EnhancedEditorView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedEditorView(
            note: .constant(Note.sample),
            content: .constant(
                "# Sample Note\n\nThis is a **sample** note with *italic* text and a [link](https://example.com).\n\n## Code Example\n\n```swift\nprint(\"Hello, World!\")\n```"
            )
        )
        .environmentObject(FolderManager())
    }
}
