//
//  MufiTerminalView.swift
//  Ferrufi
//
//  Terminal-style output view for Mufi script execution results
//

import SwiftUI

/// Terminal-style output view for displaying Mufi script execution results
public struct MufiTerminalView: View {
    let output: String
    let exitStatus: UInt8
    let executionTime: TimeInterval?
    let onClear: (() -> Void)?
    let onClose: (() -> Void)?

    @State private var isExpanded = true
    @EnvironmentObject var themeManager: ThemeManager

    public init(
        output: String,
        exitStatus: UInt8 = 0,
        executionTime: TimeInterval? = nil,
        onClear: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.output = output
        self.exitStatus = exitStatus
        self.executionTime = executionTime
        self.onClear = onClear
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            terminalHeader

            if isExpanded {
                Divider()

                // Terminal output area
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 0) {
                            if output.isEmpty {
                                emptyOutputView
                            } else {
                                terminalOutputText
                                    .id("bottom")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .onAppear {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                        .onChange(of: output) { _ in
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(terminalBackgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(terminalBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Terminal Header

    private var terminalHeader: some View {
        HStack(spacing: 12) {
            // Terminal indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(exitStatus == 0 ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text("Terminal")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(terminalForegroundColor)
            }

            // Status badge
            statusBadge

            Spacer()

            // Execution time
            if let time = executionTime {
                Text(String(format: "%.3fs", time))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(terminalForegroundColor.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }

            // Action buttons
            HStack(spacing: 8) {
                if onClear != nil {
                    Button(action: { onClear?() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(terminalForegroundColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Clear output")
                }

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(terminalForegroundColor.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse" : "Expand")

                if onClose != nil {
                    Button(action: { onClose?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundColor(terminalForegroundColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Close terminal")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(terminalHeaderBackground)
    }

    private var statusBadge: some View {
        Group {
            if exitStatus == 0 {
                Text("SUCCESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(3)
            } else {
                Text("ERROR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(3)
            }
        }
    }

    // MARK: - Terminal Output

    private var terminalOutputText: some View {
        Text(formatOutput(output))
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(terminalForegroundColor)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyOutputView: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundColor(terminalForegroundColor.opacity(0.3))

            Text("No output")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(terminalForegroundColor.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Formatting

    private func formatOutput(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let formattedLines = lines.map { line -> String in
            if let match = line.range(of: #"^\d+:\s"#, options: .regularExpression) {
                return String(line[match.upperBound...])
            }
            return line
        }
        return formattedLines.joined(separator: "\n")
    }

    // MARK: - Colors

    private var terminalBackgroundColor: Color {
        Color(NSColor.controlBackgroundColor).opacity(0.5)
    }

    private var terminalHeaderBackground: Color {
        Color.black.opacity(0.2)
    }

    private var terminalForegroundColor: Color {
        themeManager.currentTheme.colors.foreground
    }

    private var terminalBorderColor: Color {
        Color.gray.opacity(0.3)
    }
}

/// Compact inline terminal output view
public struct InlineMufiTerminalView: View {
    let output: String
    let exitStatus: UInt8
    let executionTime: TimeInterval?
    let onRun: () -> Void
    let onClear: () -> Void

    @State private var isExpanded = false
    @EnvironmentObject var themeManager: ThemeManager

    public var body: some View {
        VStack(spacing: 0) {
            // Compact header
            HStack(spacing: 8) {
                Circle()
                    .fill(exitStatus == 0 ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text("Output")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                if let time = executionTime {
                    Text(String(format: "%.2fs", time))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onRun) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Run again")

                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Clear")

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            if isExpanded {
                Divider()

                ScrollView {
                    Text(output.isEmpty ? "No output" : output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(output.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 150)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct MufiTerminalView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Success output
            MufiTerminalView(
                output: """
                    Hello, World!
                    5 + 3 = 8
                    Count: 0
                    Count: 1
                    Count: 2
                    Count: 3
                    Count: 4
                    """,
                exitStatus: 0,
                executionTime: 0.045,
                onClear: {},
                onClose: {}
            )
            .frame(height: 300)

            // Error output
            MufiTerminalView(
                output: """
                    Error: undefined function 'undefined_function'
                    at line 2, column 8
                    """,
                exitStatus: 1,
                executionTime: 0.012,
                onClear: {},
                onClose: {}
            )
            .frame(height: 200)

            // Empty output
            MufiTerminalView(
                output: "",
                exitStatus: 0,
                executionTime: 0.001,
                onClear: {},
                onClose: {}
            )
            .frame(height: 200)

            // Inline view
            InlineMufiTerminalView(
                output: "Hello from Mufi!\nResult: 42",
                exitStatus: 0,
                executionTime: 0.023,
                onRun: {},
                onClear: {}
            )
        }
        .padding()
        .environmentObject(ThemeManager())
        .frame(width: 600)
    }
}
