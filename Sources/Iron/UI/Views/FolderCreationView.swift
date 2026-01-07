//
//  FolderCreationView.swift
//  Iron
//
//  Folder creation view with full implementation
//

import SwiftUI

struct FolderCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ironApp: IronApp
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var folderName: String = ""
    @State private var selectedParentFolder: Folder?
    @State private var createError: Error?
    @State private var showingError = false
    @State private var isCreating = false

    // Available parent folders (excluding selected folder to prevent circular reference)
    private var availableParentFolders: [Folder] {
        var folders = [ironApp.folderManager.rootFolder]
        folders.append(
            contentsOf: ironApp.folderManager.folders.values.sorted { $0.name < $1.name })
        return folders
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.blue)

                        Text("Create New Folder")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    Text("Organize your notes by creating a new folder")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Form
                VStack(alignment: .leading, spacing: 16) {
                    // Folder Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Folder Name")
                            .font(.headline)

                        TextField("Enter folder name", text: $folderName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                if canCreateFolder {
                                    createFolder()
                                }
                            }

                        if folderName.isEmpty {
                            Text("Folder name is required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Parent Folder Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parent Folder")
                            .font(.headline)

                        Picker("Parent Folder", selection: $selectedParentFolder) {
                            Text("Root (No Parent)")
                                .tag(Optional<Folder>.none)

                            ForEach(availableParentFolders, id: \.id) { folder in
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.accentColor)
                                    Text(folder.name)
                                }
                                .tag(Optional(folder))
                            }
                        }
                        .pickerStyle(.menu)

                        if let parent = selectedParentFolder {
                            Text("Will be created in: \(parent.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Will be created in root directory")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.headline)

                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)

                            Text(folderName.isEmpty ? "New Folder" : folderName)
                                .fontWeight(.medium)

                            Spacer()
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)

                        Text("Full path: \(previewPath)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(action: createFolder) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                            }
                            Text("Create Folder")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateFolder || isCreating)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 400, height: 500)
            .toolbar(.hidden)
        }
        .alert("Error Creating Folder", isPresented: $showingError) {
            Button("OK") {
                createError = nil
            }
        } message: {
            if let error = createError {
                Text(error.localizedDescription)
            }
        }
        .onAppear {
            selectedParentFolder = navigationModel.selectedFolder
        }
    }

    // MARK: - Computed Properties

    private var canCreateFolder: Bool {
        !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    private var previewPath: String {
        let cleanName = folderName.isEmpty ? "New Folder" : folderName
        if let parent = selectedParentFolder {
            return "\(ironApp.folderManager.fullPath(for: parent.id))/\(cleanName)"
        } else {
            return cleanName
        }
    }

    // MARK: - Actions

    private func createFolder() {
        guard canCreateFolder else { return }

        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)

        isCreating = true

        Task {
            do {
                // Determine the file system path
                let parentPath: String
                if let parent = selectedParentFolder {
                    parentPath = parent.path
                } else {
                    parentPath = ironApp.folderManager.rootFolder.path
                }

                let folderPath = URL(fileURLWithPath: parentPath)
                    .appendingPathComponent(trimmedName)
                    .path

                // Check if folder already exists
                if FileManager.default.fileExists(atPath: folderPath) {
                    throw FolderError.folderAlreadyExists
                }

                // Create the directory on the file system
                try FileManager.default.createDirectory(
                    atPath: folderPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                await MainActor.run {
                    // Create the folder in the manager
                    let newFolder = ironApp.folderManager.createFolder(
                        name: trimmedName,
                        path: folderPath,
                        parentId: selectedParentFolder?.id
                    )

                    // Select the newly created folder
                    navigationModel.selectFolder(newFolder)

                    // Close the sheet
                    navigationModel.showingFolderCreation = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.createError = error
                    self.showingError = true
                    self.isCreating = false
                }
            }
        }
    }
}

struct FolderCreationView_Previews: PreviewProvider {
    static var previews: some View {
        FolderCreationView()
            .environmentObject(IronApp())
            .environmentObject(NavigationModel())
    }
}
