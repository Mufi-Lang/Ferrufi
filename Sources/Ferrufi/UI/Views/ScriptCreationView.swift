//
//  ScriptCreationView.swift
//  Ferrufi
//
//  Enhanced script creation with directory selection
//

import SwiftUI
import Files

#if os(macOS)
    import AppKit
#endif

public struct ScriptCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var scriptName = ""
    @State private var selectedFolder: Folder?
    @State private var showingDirectoryPicker = false
    
    private typealias FerrufiFolder = Ferrufi.Folder

    private var availableFolders: [FerrufiFolder] {
        var folders = ferrufiApp.folderManager.allFolders

        // Add working directory folder if set
        if let workingDir = navigationModel.currentWorkingDirectory {
            let workingDirFolder = folders.first { folder in
                URL(fileURLWithPath: folder.path) == workingDir
            }
            if workingDirFolder == nil {
                // Create temporary folder representation
                let tempFolder = FerrufiFolder(
                    name: workingDir.lastPathComponent,
                    path: workingDir.path
                )
                folders.append(tempFolder)
            }
        }

        return folders.sorted { $0.name < $1.name }
    }

    private var suggestedFolder: FerrufiFolder? {
        if let workingDir = navigationModel.currentWorkingDirectory {
            return availableFolders.first { folder in
                URL(fileURLWithPath: folder.path) == workingDir
            }
        }
        return navigationModel.selectedFolder ?? ferrufiApp.folderManager.rootFolder
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Script")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(themeManager.currentTheme.colors.backgroundSecondary)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Script Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.colors.foreground)

                        TextField("script_name", text: $scriptName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if isValid { createScript() }
                            }
                        
                        Text("File will be saved as \(scriptName).mufi")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    }

                    // Directory Selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Location")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.colors.foreground)

                            Spacer()

                            Button("Browse...") {
                                openDirectoryPicker()
                            }
                            .foregroundColor(themeManager.currentTheme.colors.accent)
                        }

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
                                .lineLimit(1)
                                .truncationMode(.middle)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .foregroundColor(
                                        themeManager.currentTheme.colors.foregroundSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(themeManager.currentTheme.colors.background)
                                    .stroke(
                                        themeManager.currentTheme.colors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Actions
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(SecondaryButtonStyle(themeManager: themeManager))

                Button("Create Script") {
                    createScript()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(PrimaryButtonStyle(themeManager: themeManager, disabled: !isValid))
            }
            .padding(20)
            .background(themeManager.currentTheme.colors.backgroundSecondary)
        }
        .frame(width: 450, height: 380)
        .background(themeManager.currentTheme.colors.background)
        .onAppear {
            selectedFolder = suggestedFolder
        }
    }
    
    private var isValid: Bool {
        !scriptName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func openDirectoryPicker() {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Select Directory"
            panel.message = "Choose directory for the new script"

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
                    }
                }
            }
        #endif
    }

    private func createScript() {
        Task {
            do {
                let targetFolder =
                    selectedFolder ?? suggestedFolder ?? ferrufiApp.folderManager.rootFolder

                let scriptContent = """
                // \(scriptName)
                // Created on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))

                """

                let newNote = try await ferrufiApp.createNote(
                    title: scriptName,
                    content: scriptContent,
                    in: targetFolder,
                    fileExtension: ".mufi"
                )

                await MainActor.run {
                    navigationModel.selectNote(newNote, ferrufiApp: ferrufiApp)
                    scriptName = ""
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

struct PrimaryButtonStyle: ButtonStyle {
    let themeManager: ThemeManager
    let disabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(disabled ? themeManager.currentTheme.colors.foregroundTertiary : themeManager.currentTheme.colors.accent)
            )
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let themeManager: ThemeManager
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
            )
            .foregroundColor(themeManager.currentTheme.colors.foreground)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}