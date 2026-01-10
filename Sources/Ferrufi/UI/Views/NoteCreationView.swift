//
//  NoteCreationView.swift
//  Ferrufi
//
//  Enhanced note creation with directory selection
//

import SwiftUI

#if os(macOS)
    import AppKit
#endif

public struct NoteCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var noteTitle = ""
    @State private var selectedFolder: Folder?
    @State private var showingDirectoryPicker = false

    var availableFolders: [Folder] {
        var folders = ferrufiApp.folderManager.allFolders

        // Add working directory folder if set
        if let workingDir = navigationModel.currentWorkingDirectory {
            let workingDirFolder = folders.first { folder in
                URL(fileURLWithPath: folder.path) == workingDir
            }
            if workingDirFolder == nil {
                // Create temporary folder representation
                let tempFolder = Folder(
                    name: workingDir.lastPathComponent,
                    path: workingDir.path
                )
                folders.append(tempFolder)
            }
        }

        return folders.sorted { $0.name < $1.name }
    }

    var suggestedFolder: Folder? {
        if let workingDir = navigationModel.currentWorkingDirectory {
            return availableFolders.first { folder in
                URL(fileURLWithPath: folder.path) == workingDir
            }
        }
        return navigationModel.selectedFolder ?? ferrufiApp.folderManager.rootFolder
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
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
                        .frame(width: 60, height: 60)

                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("Create New Script")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
            }

            VStack(spacing: 20) {
                // Script Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Script Name")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    TextField("my_script", text: $noteTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if !noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                            {
                                createNote()
                            }
                        }
                }

                // Directory Selection
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Directory")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.colors.foreground)

                        Spacer()

                        Button("Browse...") {
                            openDirectoryPicker()
                        }
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                    }

                    if !availableFolders.isEmpty {
                        Menu {
                            ForEach(availableFolders, id: \.id) { folder in
                                Button(action: {
                                    selectedFolder = folder
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                        Text(folder.name)
                                        if folder.id == suggestedFolder?.id {
                                            Text("(suggested)")
                                                .foregroundColor(
                                                    themeManager.currentTheme.colors.accent)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(themeManager.currentTheme.colors.accent)

                                Text(
                                    selectedFolder?.name ?? suggestedFolder?.name
                                        ?? "Select Directory"
                                )
                                .foregroundColor(themeManager.currentTheme.colors.foreground)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .foregroundColor(
                                        themeManager.currentTheme.colors.foregroundSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themeManager.currentTheme.colors.backgroundSecondary)
                                    .stroke(
                                        themeManager.currentTheme.colors.border, lineWidth: 1)
                            )
                        }
                    }

                    if let selected = selectedFolder ?? suggestedFolder {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(themeManager.currentTheme.colors.success)

                            Text("Note will be created in: \(selected.name)")
                                .font(.caption)
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundSecondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    noteTitle = ""
                    selectedFolder = nil
                    dismiss()
                }
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
                )

                Button("Create Note") {
                    createNote()
                }
                .disabled(noteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            noteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? themeManager.currentTheme.colors.foregroundTertiary
                                : themeManager.currentTheme.colors.accent
                        )
                )
            }
        }
        .padding(30)
        .frame(width: 450, height: 400)
        .background(themeManager.currentTheme.colors.background)
        .onAppear {
            selectedFolder = suggestedFolder
        }
    }

    private func openDirectoryPicker() {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Select Directory"
            panel.message = "Choose directory for the new note"

            if let currentDir = navigationModel.currentWorkingDirectory {
                panel.directoryURL = currentDir
            }

            panel.begin { result in
                if result == .OK, let url = panel.url {
                    DispatchQueue.main.async {
                        // Find or create folder for this directory
                        let existingFolder = self.ferrufiApp.folderManager.allFolders.first {
                            folder in
                            URL(fileURLWithPath: folder.path) == url
                        }

                        if let folder = existingFolder {
                            self.selectedFolder = folder
                        } else {
                            // Create new folder representation
                            let newFolder = self.ferrufiApp.folderManager.createFolder(
                                name: url.lastPathComponent,
                                path: url.path
                            )
                            self.selectedFolder = newFolder
                        }

                        // Also update working directory
                        self.navigationModel.setWorkingDirectory(url)
                    }
                }
            }
        #endif
    }

    private func createNote() {
        Task {
            do {
                let targetFolder =
                    selectedFolder ?? suggestedFolder ?? ferrufiApp.folderManager.rootFolder

                // Create Mufi script template
                let scriptContent = """
                    // \(noteTitle)
                    // Created on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))

                    """

                let newNote = try await ferrufiApp.createNote(
                    title: noteTitle,
                    content: scriptContent,
                    in: targetFolder
                )

                await MainActor.run {
                    navigationModel.selectNote(newNote, ferrufiApp: ferrufiApp)
                    noteTitle = ""
                    selectedFolder = nil
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    navigationModel.showError(error)
                }
            }
        }
    }
}

struct NoteCreationSheet_Previews: PreviewProvider {
    static var previews: some View {
        NoteCreationSheet()
            .environmentObject(FerrufiApp())
            .environmentObject(NavigationModel())
            .environmentObject(ThemeManager())
    }
}
