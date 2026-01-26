//
//  NativeSplitEditor.swift
//  Ferrufi
//
//  Native SwiftUI editor for Mufi scripts
//

import SwiftUI

struct NativeSplitEditor: View {
    let note: Note?
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager

    let placeholder: String
    let onTextChange: (String) -> Void

    @State private var isEditing = false

    @State private var isREPLVisible = false
    @State private var splitRatio: CGFloat = 0.5
    @State private var isDraggingSplitter = false
    @State private var showingNotePicker = false
    @State private var showTerminal = false
    @State private var runOutputText = ""
    @State private var exitStatus: UInt8 = 0
    @State private var executionTime: TimeInterval?
    @State private var isRunningScript = false
    @EnvironmentObject var ferrufiApp: FerrufiApp

    public init(
        note: Note?,
        text: Binding<String>,
        placeholder: String = "Start writing...",
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.note = note
        self._text = text
        self.placeholder = placeholder
        self.onTextChange = onTextChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            editorToolbar

            // Main split view
            HStack(spacing: 0) {
                // Editor: all files use the Mufi script editor (Markdown support removed)
                UnifiedEditor(
                    text: $text,
                    isEditing: $isEditing,
                    fileType: .mufi,
                    placeholder: placeholder,
                    onTextChange: onTextChange,
                    onSave: {
                        // Ensure any save hooks run when the editor triggers save.
                        onTextChange(text)
                    }
                )
                .environmentObject(themeManager)
                .frame(maxWidth: .infinity)

                if isREPLVisible {
                    // Splitter for REPL
                    Rectangle()
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.3))
                        .frame(width: 2)

                    // Right: Embedded Mufi REPL
                    EmbeddedMufiREPLView()
                        .frame(maxWidth: .infinity)
                }
            }

            // Terminal output (if enabled)
            if showTerminal {
                Divider()

                MufiTerminalView(
                    output: runOutputText,
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
                .environmentObject(themeManager)
            }
        }
        .background(themeManager.currentTheme.colors.background)
        .sheet(isPresented: $showingNotePicker) {
            NotePickerView(onNoteSelected: { note in
                insertText("[[\(note.title)]]")
                showingNotePicker = false
            })
            .environmentObject(ferrufiApp)
            .environmentObject(themeManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleMufiREPL)) { _ in
            isREPLVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .runMufiScript)) { _ in
            runMufiScript()
        }
        .onAppear {
            print(
                "NativeSplitEditor: editor font: \(themeManager.resolvedMonospacedFontName) @ \(themeManager.editorFontSize)pt"
            )
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 6) {
            // Secondary pane removed

            Spacer()

            // Mufi REPL controls
            Divider()
                .frame(height: 16)

            // Run script button
            Button(action: { runMufiScript() }) {
                if isRunningScript {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .help("Run Mufi Script (⌘R)")
            .disabled(isRunningScript)

            // REPL toggle
            Button(action: { isREPLVisible.toggle() }) {
                Image(systemName: isREPLVisible ? "terminal.fill" : "terminal")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help(isREPLVisible ? "Hide Mufi REPL" : "Show Mufi REPL")

            Divider()
                .frame(height: 16)

            // Minimal word count
            if !text.isEmpty {
                Text("\(wordCount(text)) words")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.3))
    }

    private func insertWrapping(prefix: String, suffix: String) {
        let newText = text + prefix + suffix
        text = newText
        onTextChange(newText)
    }

    private func insertAtLineStart(_ prefix: String) {
        let newText = text + "\n" + prefix
        text = newText
        onTextChange(newText)
    }

    private func insertText(_ newText: String) {
        text.append(newText)
        onTextChange(text)
    }

    private func wordCount(_ text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private func runMufiScript() {
        guard !isRunningScript else { return }
        isRunningScript = true

        let startTime = Date()

        Task {
            do {
                let (status, output) = try await MufiBridge.shared.interpret(text)
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)

                await MainActor.run {
                    runOutputText = output.isEmpty ? "[No output]" : output
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
                    runOutputText = "Error: \(error.localizedDescription)"
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
        runOutputText = ""
        exitStatus = 0
        executionTime = nil
    }
}

// Preview removed

// MARK: - Supporting Types

struct ViewWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Reusable Components

struct NativeFormatButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
        }
        .buttonStyle(ToolbarButtonStyle(themeManager: themeManager))
        .help(tooltip)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    let themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
            .font(.system(size: 11))
            .padding(4)
            .background(
                configuration.isPressed
                    ? themeManager.currentTheme.colors.accent.opacity(0.2)
                    : Color.clear
            )
            .cornerRadius(4)
    }
}

// MARK: - SwiftUI Samples

struct NativeSplitEditor_Samples: PreviewProvider {
    @State static var text = """
        // Native Split Editor
        // Sample Mufi script

        print("Hello, Mufi!")

        func hello() {
            print("Hello, World!")
        }

        hello()
        """

    static var previews: some View {
        NativeSplitEditor(note: Note.sample, text: $text)
            .environmentObject(ThemeManager())
            .environmentObject(FerrufiApp())
            .frame(width: 800, height: 600)
    }
}
