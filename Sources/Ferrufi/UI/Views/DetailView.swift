//
//  DetailView.swift
//  Ferrufi
//
//  Beautiful, modern detail view with stunning visual design
//

import SwiftUI

struct DetailView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var editingText = ""
    @State private var isEditorFocused = false
    @State private var showingThemeSelector = false
    @State private var showingExportSheet = false
    @State private var isFullscreen = false

    // Removed DetailViewMode enum - using only Notion-style live editing

    var body: some View {
        Group {
            if let note = navigationModel.selectedNote {
                VStack(spacing: 0) {
                    // Stunning header
                    noteHeader(for: note)

                    // Native split editor (no conflicting toolbars)
                    nativeSplitEditingView

                    // Status bar
                    statusBar(for: note)
                }
                .background(themeManager.currentTheme.colors.background)
                .themedAnimation(themeManager, value: editingText)
            } else {
                // Elegant empty state
                emptyStateView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            if let note = navigationModel.selectedNote {
                editingText = note.content
            }
        }
        .onChange(of: navigationModel.selectedNote) { newNote in
            if let note = newNote {
                editingText = note.content
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(note: navigationModel.selectedNote!)
                .environmentObject(themeManager)
        }
    }

    // MARK: - Header

    private func iconForNote(_ note: Note) -> String {
        if note.filePath.hasSuffix(".mufi") {
            return "chevron.left.forwardslash.chevron.right"
        } else {
            return "doc.text"
        }
    }

    @ViewBuilder
    private func noteHeader(for note: Note) -> some View {
        HStack {
            // Note icon and title
            HStack(spacing: 12) {
                // Beautiful note icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.colors.accent,
                                    themeManager.currentTheme.colors.accentSecondary,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: iconForNote(note))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(
                    color: themeManager.currentTheme.colors.accent.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 2
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label {
                            Text(note.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11))
                        } icon: {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)

                        if !note.content.isEmpty {
                            Text("•")
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundTertiary
                                )
                                .font(.system(size: 11))

                            Text("\(wordCount(note.content)) words")
                                .font(.system(size: 11))
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundSecondary)
                        }
                    }
                }
            }

            Spacer()

            // Action buttons with beautiful styling
            HStack(spacing: 6) {
                // Theme selector
                ThemeToggleButton()
                    .environmentObject(themeManager)

                // Action buttons
                HStack(spacing: 4) {
                    ActionButton(
                        icon: "square.and.arrow.down",
                        tooltip: "Save",
                        action: saveNote
                    )

                    ActionButton(
                        icon: "square.and.arrow.up",
                        tooltip: "Export",
                        action: { showingExportSheet = true }
                    )

                    Menu {
                        Button("Duplicate Note") { duplicateNote() }
                        Button("Move to Folder") { moveNote() }
                        Divider()
                        Button("Delete Note", role: .destructive) { deleteNote() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                            .frame(width: 24, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .help("More Actions")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    themeManager.currentTheme.colors.backgroundSecondary,
                    themeManager.currentTheme.colors.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(themeManager.currentTheme.colors.border)
                .opacity(0.5),
            alignment: .bottom
        )
    }

    // MARK: - Main Content

    private var nativeSplitEditingView: some View {
        // Clean native split editor without extra headers or toolbars
        NativeSplitEditor(
            note: navigationModel.selectedNote,
            text: $editingText,
            placeholder: "Start writing your note...",
            onTextChange: { newText in
                scheduleAutoSave()
            }
        )
        .environmentObject(ferrufiApp)
        .environmentObject(themeManager)
        .background(themeManager.currentTheme.colors.background)
    }

    // Removed splitView and previewView - using only Notion-style editor

    // MARK: - Status Bar

    private func statusBar(for note: Note) -> some View {
        HStack {
            // File info
            HStack(spacing: 8) {
                Circle()
                    .fill(themeManager.currentTheme.colors.success)
                    .frame(width: 6, height: 6)

                Text("Saved")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
            }

            Spacer()

            // Stats including FPS counter
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "textformat")
                        .font(.system(size: 9))
                    Text("\(wordCount(note.content)) words")
                        .font(.system(size: 10))
                }

                HStack(spacing: 4) {
                    Image(systemName: "character")
                        .font(.system(size: 9))
                    Text("\(editingText.count) chars")
                        .font(.system(size: 10))
                }

                HStack(spacing: 4) {
                    Image(systemName: "list.number")
                        .font(.system(size: 9))
                    Text("\(lineCount(editingText)) lines")
                        .font(.system(size: 10))
                }

                // FPS Counter
                FPSCounterView()
            }
            .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    themeManager.currentTheme.colors.background,
                    themeManager.currentTheme.colors.backgroundSecondary,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(themeManager.currentTheme.colors.border)
                .opacity(0.3),
            alignment: .top
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 32) {
            // Beautiful illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent.opacity(0.1),
                                themeManager.currentTheme.colors.accentSecondary.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "doc.text")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent,
                                themeManager.currentTheme.colors.accentSecondary,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("No Note Selected")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                Text("Choose a note from the sidebar or create a new one to start writing")
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    navigationModel.showingNoteCreation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New Note")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.colors.accent,
                                themeManager.currentTheme.colors.accentSecondary,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: themeManager.currentTheme.colors.accent.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
                }
                .buttonStyle(.plain)

                Button {
                    // Import functionality
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .medium))
                        Text("Import")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeManager.currentTheme.colors.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.currentTheme.colors.background)
    }

    // MARK: - Helper Components

    struct ActionButton: View {
        let icon: String
        let tooltip: String
        let action: () -> Void
        @EnvironmentObject var themeManager: ThemeManager

        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(tooltip)
        }
    }

    // MARK: - Helper Methods

    private func wordCount(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    private func lineCount(_ text: String) -> Int {
        return text.components(separatedBy: .newlines).count
    }

    // MARK: - Auto-save

    @State private var autoSaveTimer: Timer?

    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in
                saveNote()
            }
        }
    }

    // MARK: - Actions

    private func saveNote() {
        guard let note = navigationModel.selectedNote else { return }

        Task {
            do {
                var updatedNote = note
                updatedNote.content = editingText
                updatedNote.modifiedAt = Date()

                try await ferrufiApp.updateNote(updatedNote)

                await MainActor.run {
                    navigationModel.selectedNote = updatedNote
                }
            } catch {
                print("Save error: \(error)")
            }
        }
    }

    private func duplicateNote() {
        guard let note = navigationModel.selectedNote else { return }

        Task {
            do {
                let folder = ferrufiApp.folderManager.folder(for: note)
                let duplicatedNote = try await ferrufiApp.createNote(
                    title: "\(note.title) Copy",
                    content: note.content,
                    in: folder
                )

                await MainActor.run {
                    navigationModel.selectNote(duplicatedNote, ferrufiApp: ferrufiApp)
                }
            } catch {
                navigationModel.showError(error)
            }
        }
    }

    private func moveNote() {
        // TODO: Implement move functionality
    }

    private func deleteNote() {
        guard let note = navigationModel.selectedNote else { return }

        Task {
            do {
                try await ferrufiApp.deleteNote(note)

                await MainActor.run {
                    navigationModel.selectedNote = nil
                }
            } catch {
                navigationModel.showError(error)
            }
        }
    }

    // MARK: - Text Formatting

    private func insertFormatting(for type: String) {
        switch type {
        case "bold":
            insertWrapping(prefix: "**", suffix: "**")
        case "italic":
            insertWrapping(prefix: "*", suffix: "*")
        case "code":
            insertWrapping(prefix: "`", suffix: "`")
        default:
            break
        }
    }

    private func insertElement(_ type: String) {
        switch type {
        case "header":
            insertAtLineStart("## ")
        case "list":
            insertAtLineStart("- ")
        case "link":
            insertText("[Link Text](url)")
        case "image":
            insertText("![Alt Text](image-url)")
        default:
            break
        }
    }

    private func insertWrapping(prefix: String, suffix: String) {
        editingText += "\(prefix)text\(suffix)"
    }

    private func insertAtLineStart(_ text: String) {
        if !editingText.isEmpty && !editingText.hasSuffix("\n") {
            editingText += "\n"
        }
        editingText += text
    }

    private func insertText(_ text: String) {
        editingText += text
    }
}

// Export Sheet
struct ExportSheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Note")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Choose export format")
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)

                VStack(spacing: 12) {
                    ExportOption(
                        icon: "doc.text",
                        title: "Markdown",
                        subtitle: "Export as .md file"
                    ) {
                        // Export as markdown
                        dismiss()
                    }

                    ExportOption(
                        icon: "doc.richtext",
                        title: "PDF",
                        subtitle: "Export as PDF document"
                    ) {
                        // Export as PDF
                        dismiss()
                    }

                    ExportOption(
                        icon: "safari",
                        title: "HTML",
                        subtitle: "Export as web page"
                    ) {
                        // Export as HTML
                        dismiss()
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(width: 300, height: 400)
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExportOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.colors.backgroundSecondary)
                    .stroke(themeManager.currentTheme.colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FPS Counter View

private struct FPSCounterView: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isVisible {
                        monitor.stopMonitoring()
                    } else {
                        monitor.startMonitoring()
                    }
                    isVisible.toggle()
                }
            } label: {
                Image(systemName: isVisible ? "speedometer.fill" : "speedometer")
                    .font(.system(size: 9))
                    .foregroundColor(
                        isVisible
                            ? themeManager.currentTheme.colors.accent
                            : themeManager.currentTheme.colors.foregroundTertiary
                    )
            }
            .buttonStyle(.plain)
            .help("Toggle FPS Counter")

            if isVisible {
                Text("\(Int(monitor.fps)) fps")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(fpsColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .onAppear {
            // Start frame recording when view appears
            startFrameRecording()
        }
    }

    private var fpsColor: Color {
        if monitor.fps >= 58 {
            return .green
        } else if monitor.fps >= 30 {
            return .yellow
        } else {
            return .red
        }
    }

    private func startFrameRecording() {
        // Use a timer to simulate frame recording
        Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { _ in
            Task { @MainActor in
                monitor.recordFrame()
            }
        }
    }
}

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        DetailView()
            .environmentObject(FerrufiApp())
            .environmentObject(NavigationModel())
            .environmentObject(ThemeManager())
    }
}
