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

public struct EmbeddedMufiREPLView: View {
    @State private var output: String = ""
    @State private var inputText: String = ""
    @State private var isBusy: Bool = false

    @FocusState private var inputFocused: Bool

    // Anchor ID for autoscroll to bottom
    private let bottomAnchor = UUID()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Mufi REPL (Embedded)")
                    .font(.headline)

                Spacer()

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
                        .font(.system(size: 13, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id(bottomAnchor)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: output) {
                    // Auto-scroll to bottom when there's new output
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(bottomAnchor, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input area
            HStack {
                TextField("Enter Mufi code or expression", text: $inputText, onCommit: sendInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .disableAutocorrection(true)

                Button("Send", action: sendInput)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 360)
        .onAppear {
            output.append("[Mufi REPL ready - runtime initialized at app startup]\n")
            inputFocused = true
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

        // Echo the input
        appendOutput("\n> \(trimmed)\n")
        inputText = ""
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
                    if status != 0 {
                        appendOutput("\n[Status: \(status)]\n")
                    }
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    appendOutput("\n[Error: \(error.localizedDescription)]\n")
                    appendOutput("\nTip: Avoid infinite loops or very long computations\n")
                    isBusy = false
                }
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func appendOutput(_ str: String) {
        output.append(str)
    }

    private func executeCode(_ code: String) {
        guard !isBusy else { return }

        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Echo the code being executed
        appendOutput("\n> // Executing from editor:\n")

        // Limit display to first 500 chars for very long code
        if trimmed.count > 500 {
            appendOutput(String(trimmed.prefix(500)))
            appendOutput("\n... (\(trimmed.count - 500) more characters)\n")
        } else {
            appendOutput(trimmed)
            appendOutput("\n")
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
