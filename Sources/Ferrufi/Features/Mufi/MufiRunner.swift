/*
 Ferrufi/Sources/Ferrufi/Features/Mufi/MufiRunner.swift

 Utilities for running Mufi scripts and an in-app REPL view.

 - MufiRunner: helpers to find the `mufiz` executable and run scripts (sync/async).
 - MufiREPL: ObservableObject that manages a long-running `mufiz --repl` process and exposes streaming output.
 - MufiREPLView: Small SwiftUI view that shows REPL output and provides an input line.

 Notes:
 - This implementation launches the `mufiz` command-line executable (searches PATH and common locations).
 - If you prefer to link a library directly (e.g. a dynamic or static library with a C API), we'll need a header/module to call into and a bridging/system library target - ask me and I can help integrate that as a follow-up.
 */

import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - Errors

public enum MufiRunnerError: LocalizedError {
    case executableNotFound
    case processFailed(exitCode: Int32, stdout: String, stderr: String)
    case ioError(Error)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return
                "Could not locate the `mufiz` executable. Ensure it is installed and on your PATH, or set a custom path in preferences."
        case .processFailed(let code, let out, let err):
            return "Process exited with code \(code).\n\nSTDOUT:\n\(out)\n\nSTDERR:\n\(err)"
        case .ioError(let err):
            return "I/O error: \(err.localizedDescription)"
        }
    }
}

// MARK: - MufiRunner

/// Lightweight utility that runs `mufiz` to execute files or code.
public struct MufiRunner {
    /// Searches for a `mufiz` executable. It checks:
    ///  - PATH environment
    ///  - common locations (/opt/homebrew/bin, /usr/local/bin, /usr/bin)
    ///  - a `mufiz` next to the tool's include/ or project directory (useful during development)
    public static func findExecutable() -> URL? {
        let fileManager = FileManager.default

        // Helper
        func isExecutable(_ path: String) -> Bool {
            return fileManager.isExecutableFile(atPath: path)
        }

        // 1) PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for component in pathEnv.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(component)).appendingPathComponent(
                    "mufiz")
                if isExecutable(candidate.path) {
                    return candidate
                }
            }
        }

        // 2) Common Homebrew or /usr locations
        let common = [
            "/opt/homebrew/bin/mufiz",
            "/usr/local/bin/mufiz",
            "/usr/bin/mufiz",
            "/bin/mufiz",
            "/sbin/mufiz",
        ]
        for c in common where isExecutable(c) {
            return URL(fileURLWithPath: c)
        }

        // 3) Check project include/build places (development)
        // If Ferrufi is run from project root, check relative paths
        let relativeCandidates = [
            "include/mufiz",
            "include/mufiz/mufiz",
            "bin/mufiz",
            "./mufiz",
        ]
        for rel in relativeCandidates {
            let p = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(rel).path
            if isExecutable(p) {
                return URL(fileURLWithPath: p)
            }
        }

        return nil
    }

    /// Runs code by writing to a temporary file then executing `mufiz --run <file>`.
    /// Returns combined stdout+stderr on success, or throws MufiRunnerError on failure.
    public static func run(code: String, timeout: TimeInterval? = nil) async throws -> String {
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mufi")

        do {
            try code.write(to: tempFileURL, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: tempFileURL) }
            return try await runFile(tempFileURL, timeout: timeout)
        } catch {
            throw MufiRunnerError.ioError(error)
        }
    }

    /// Runs an existing file with `mufiz --run <path>`.
    public static func runFile(_ fileURL: URL, timeout: TimeInterval? = nil) async throws -> String
    {
        guard let exe = findExecutable() else {
            throw MufiRunnerError.executableNotFound
        }

        let process = Process()
        process.executableURL = exe
        process.arguments = ["--run", fileURL.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // We use a continuation to await the process exit asynchronously
        return try await withCheckedThrowingContinuation { cont in
            process.terminationHandler = { proc in
                // Read remaining data (safe to call after termination)
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let outStr = String(decoding: outData, as: UTF8.self)
                let errStr = String(decoding: errData, as: UTF8.self)

                if proc.terminationStatus == 0 {
                    cont.resume(
                        returning: (outStr.isEmpty && errStr.isEmpty)
                            ? "" : [outStr, errStr].joined(separator: errStr.isEmpty ? "" : "\n"))
                } else {
                    cont.resume(
                        throwing: MufiRunnerError.processFailed(
                            exitCode: proc.terminationStatus, stdout: outStr, stderr: errStr))
                }
            }

            do {
                try process.run()
            } catch {
                cont.resume(throwing: MufiRunnerError.ioError(error))
            }
        }
    }
}

// MARK: - Mufi REPL

/// Observable object that manages an interactive `mufiz --repl` process and exposes streaming output.
@MainActor
public final class MufiREPL: ObservableObject {
    @Published public var output: String = ""
    @Published public private(set) var isRunning: Bool = false

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stdinPipe: Pipe?
    private var stdoutHandle: FileHandle?

    public init() {}

    /// Starts the REPL process. If already running, this is a no-op.
    public func start() throws {
        guard !isRunning else { return }
        guard let exe = MufiRunner.findExecutable() else {
            throw MufiRunnerError.executableNotFound
        }

        let process = Process()
        process.executableURL = exe
        process.arguments = ["--repl"]

        let outPipe = Pipe()
        let inPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = outPipe  // combine stderr into same stream for usability
        process.standardInput = inPipe

        // Read streaming output
        let handle = outPipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            if data.count > 0, let s = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    // Append with preserving existing text
                    self?.output.append(s)
                }
            } else {
                // EOF reached - stop reading
                fh.readabilityHandler = nil
            }
        }

        try process.run()

        // Save state
        self.process = process
        self.stdoutPipe = outPipe
        self.stdinPipe = inPipe
        self.stdoutHandle = handle
        self.isRunning = true

        // Watch for exit - when process exits, we mark as stopped and append exit info
        process.terminationHandler = { [weak self] p in
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.stdoutHandle?.readabilityHandler = nil
                self?.stdoutHandle = nil
                let exitMsg = "\n\n[REPL exited with code \(p.terminationStatus)]\n"
                self?.output.append(exitMsg)
            }
        }
    }

    /// Sends a line of input to the REPL (a newline will be appended automatically).
    public func send(_ line: String) {
        guard isRunning, let w = stdinPipe?.fileHandleForWriting else { return }
        // Mufi REPL usually expects newline-terminated commands
        if let data = (line + "\n").data(using: .utf8) {
            do {
                try w.write(contentsOf: data)
            } catch {
                // In practice FileHandle write rarely throws, but handle gracefully
                Task { @MainActor in
                    output.append(
                        "\n[Failed to write to REPL stdin: \(error.localizedDescription)]\n")
                }
            }
        }
    }

    /// Stops the REPL process gracefully (sends EOF/terminates).
    public func stop() {
        guard let proc = process else { return }
        // Attempt a gentle termination
        proc.terminate()
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutHandle?.readabilityHandler = nil
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stdoutHandle = nil
        isRunning = false
    }

    deinit {
        // Best-effort synchronous cleanup to avoid capturing 'self' in an escaping closure from deinit
        if let proc = process {
            proc.terminate()
        }
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutHandle?.readabilityHandler = nil
    }
}

// MARK: - REPL View

/// A simple REPL view you can present as a sheet/window in the IDE.
/// - Shows streamed output in a monospaced text view and provides an input field.
public struct MufiREPLView: View {
    @StateObject private var repl = MufiREPL()
    @State private var inputText: String = ""
    @FocusState private var inputFocused: Bool
    // Simple autoscroll anchor
    private let bottomId = UUID()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Mufi REPL")
                    .font(.headline)
                Spacer()
                Button(action: toggleStartStop) {
                    Image(systemName: repl.isRunning ? "stop.circle" : "play.circle")
                }
                .help(repl.isRunning ? "Stop REPL" : "Start REPL")
                .buttonStyle(PlainButtonStyle())

                Button(action: { repl.output = "" }) {
                    Image(systemName: "trash")
                }
                .help("Clear output")
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color(NSColor.separatorColor), width: 0.5)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    // Use a monospaced text for console output
                    Text(repl.output)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id(bottomId)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: repl.output) { _ in
                    // Auto-scroll to bottom when new output arrives
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(bottomId, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack {
                TextField("Enter expression or command", text: $inputText, onCommit: sendInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .disableAutocorrection(true)

                Button("Send", action: sendInput)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 360)
        .onAppear {
            // Attempt to start automatically (fail silently - callers can start manually)
            do {
                try repl.start()
                inputFocused = true
            } catch {
                // Append useful error to output (so the user sees what happened)
                Task { @MainActor in
                    repl.output.append("\n[Failed to start REPL: \(error.localizedDescription)]\n")
                }
            }
        }
        .onDisappear {
            repl.stop()
        }
    }

    private func sendInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        repl.send(trimmed)
        inputText = ""
    }

    private func toggleStartStop() {
        if repl.isRunning {
            repl.stop()
        } else {
            do {
                try repl.start()
            } catch {
                Task { @MainActor in
                    repl.output.append("\n[Failed to start REPL: \(error.localizedDescription)]\n")
                }
            }
        }
    }
}

// MARK: - Basic Output Sheet / Console view for run() results

/// Simple view to show execution output (useful after running a script).
public struct MufiOutputView: View {
    public let output: String
    public var body: some View {
        ScrollView {
            Text(output)
                .font(.system(size: 13, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Usage Note (README-style)
//
// To wire these into the editor UI:
//
// 1) Add a "Run" button in your editor toolbar that calls:
//      Task {
//          do {
//              let out = try await MufiRunner.run(code: currentEditorText)
//              // present out in a sheet / console view
//          } catch {
//              // show error
//          }
//      }
//
// 2) For an interactive REPL window, present `MufiREPLView()` as a sheet/modal or dedicated panel.
//
// If you'd like direct linking into `libmufiz` (e.g. calling into the compiler runtime directly), provide the C header(s) and a stable API surface and I can help add a system library target and lightweight Swift wrapper so you can call it without spawning a process.
