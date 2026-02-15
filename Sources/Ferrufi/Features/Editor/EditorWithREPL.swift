//
//  EditorWithREPL.swift
//  Ferrufi
//
//  Enhanced editor view with inline REPL support
//  Allows users to:
//  - Edit code in the left pane
//  - Use interactive REPL in the right pane
//

import SwiftUI

/// Display mode for the editor
enum EditorDisplayMode: String, CaseIterable {
    case editorOnly = "Editor Only"
    case editorREPL = "Editor + REPL"
}

/// Enhanced editor with integrated REPL support
struct EditorWithREPL: View {
    @Binding var note: Note?
    @Binding var content: String

    @State private var isEditing = false
    @State private var displayMode: EditorDisplayMode = .editorOnly
    @State private var showTerminal = false
    @State private var outputText: String = ""
    @State private var exitStatus: UInt8 = 0
    @State private var executionTime: TimeInterval?
    @State private var isRunningScript = false
    @State private var lastSaveTime: Date = Date()
    @State private var autoSaveTimer: Timer?

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var folderManager: FolderManager
    @EnvironmentObject var themeManager: ThemeManager

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
        .environment(\.font, themeManager.monospacedFont)
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
                    .font(themeManager.monospacedCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Formatting toolbar removed

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

                // Secondary pane removed

                // Save indicator
                if Date().timeIntervalSince(lastSaveTime) < 2.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved")
                            .font(themeManager.monospacedCaption)
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
        case .editorREPL:
            HSplitView {
                editorPane
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
                    .font(themeManager.monospacedHeadline)
                Spacer()
                Text("\(content.count) characters")
                    .font(themeManager.monospacedCaption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            UnifiedEditor(
                text: $content,
                isEditing: $isEditing,
                fileType: .mufi,
                placeholder: "Start writing...",
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

    // MARK: - Secondary Pane

    // Secondary pane removed

    // MARK: - REPL Pane

    @ViewBuilder
    private var replPane: some View {
        VStack(spacing: 0) {
            // REPL pane header
            HStack {
                Text("Mufi REPL")
                    .font(themeManager.monospacedHeadline)
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
        case .editorREPL:
            displayMode = .editorOnly
        }
    }

    // Pane toggling removed — secondary pane is no longer part of the editor UI.

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

    // Formatting helpers removed

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
            if let foundNote = folderManager.findNoteByName(noteName) {
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
        Task {
            if let foundNote = folderManager.findNoteByURL(url) {
                await MainActor.run {
                    note = foundNote
                    NotificationCenter.default.post(name: .navigateToNote, object: foundNote)
                }
            } else {
                NSWorkspace.shared.open(url)
            }
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

// MARK: - SwiftUI Samples

struct EditorWithREPL_Samples: PreviewProvider {
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

                fun add(a, b) {
                    return a + b
                }

                fun greet(name) {
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
