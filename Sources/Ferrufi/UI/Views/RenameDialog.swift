//
//  RenameDialog.swift
//  Ferrufi
//
//  Rename and move dialog components for notes and folders
//

import SwiftUI

#if os(macOS)
    import AppKit
#endif

// MARK: - Rename Note Dialog

public struct RenameNoteDialog: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    let note: Note
    @State private var newName: String
    @State private var isLoading = false

    public init(note: Note) {
        self.note = note
        self._newName = State(initialValue: note.title)
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.currentTheme.colors.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rename Note")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text("Enter a new name for the note")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }

                Spacer()
            }

            // Current name display
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Name")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                Text(note.title)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.currentTheme.colors.backgroundSecondary)
                    .cornerRadius(8)
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
            }

            // New name input
            VStack(alignment: .leading, spacing: 8) {
                Text("New Name")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                TextField("Enter new name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if isValidName {
                            performRename()
                        }
                    }
            }

            // Validation message
            if !isValidName && !newName.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Please enter a valid name")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
                )

                Button("Rename") {
                    performRename()
                }
                .disabled(!isValidName || isLoading)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            (!isValidName || isLoading)
                                ? Color.gray
                                : themeManager.currentTheme.colors.accent
                        )
                )
                .overlay(
                    Group {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                    }
                )
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
        .background(themeManager.currentTheme.colors.background)
    }

    private var isValidName: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != note.title && !trimmed.contains("/")
    }

    private func performRename() {
        guard isValidName else { return }

        isLoading = true

        Task {
            do {
                try await ferrufiApp.renameNote(
                    note, to: newName.trimmingCharacters(in: .whitespacesAndNewlines))

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    navigationModel.showError(error)
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Move Note Dialog

public struct MoveNoteDialog: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    let note: Note
    @State private var selectedFolder: Folder?
    @State private var isLoading = false

    var availableFolders: [Folder] {
        ferrufiApp.folderManager.allFolders.sorted { $0.name < $1.name }
    }

    var currentFolder: Folder? {
        ferrufiApp.folderManager.folder(for: note)
    }

    public init(note: Note) {
        self.note = note
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.currentTheme.colors.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Move Note")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text("Select a destination folder")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }

                Spacer()
            }

            // Note info
            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                    Text(note.title)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                    Spacer()
                }
                .padding(10)
                .background(themeManager.currentTheme.colors.backgroundSecondary)
                .cornerRadius(8)
            }

            // Current location
            if let current = currentFolder {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Location")
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.orange)
                        Text(current.name)
                            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                        Spacer()
                    }
                    .padding(10)
                    .background(themeManager.currentTheme.colors.backgroundSecondary)
                    .cornerRadius(8)
                }
            }

            // Destination selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                if !availableFolders.isEmpty {
                    Menu {
                        ForEach(availableFolders, id: \.id) { folder in
                            Button(action: {
                                selectedFolder = folder
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text(folder.name)
                                    if folder.id == currentFolder?.id {
                                        Text("(current)")
                                            .foregroundColor(
                                                themeManager.currentTheme.colors.foregroundSecondary
                                            )
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedFolder != nil ? "folder.fill" : "folder")
                                .foregroundColor(themeManager.currentTheme.colors.accent)

                            Text(selectedFolder?.name ?? "Select destination folder")
                                .foregroundColor(
                                    selectedFolder != nil
                                        ? themeManager.currentTheme.colors.foreground
                                        : themeManager.currentTheme.colors.foregroundSecondary
                                )

                            Spacer()

                            Image(systemName: "chevron.down")
                                .foregroundColor(
                                    themeManager.currentTheme.colors.foregroundSecondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.currentTheme.colors.backgroundSecondary)
                                .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
                        )
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
                )

                Button("Move") {
                    performMove()
                }
                .disabled(!canMove || isLoading)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            (!canMove || isLoading)
                                ? Color.gray
                                : themeManager.currentTheme.colors.accent
                        )
                )
                .overlay(
                    Group {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                    }
                )
            }
        }
        .padding(24)
        .frame(width: 450, height: 400)
        .background(themeManager.currentTheme.colors.background)
        .onAppear {
            // Pre-select a different folder if available
            selectedFolder = availableFolders.first { $0.id != currentFolder?.id }
        }
    }

    private var canMove: Bool {
        guard let selected = selectedFolder else { return false }
        return selected.id != currentFolder?.id
    }

    private func performMove() {
        guard let destination = selectedFolder, canMove else { return }

        isLoading = true

        Task {
            do {
                try await ferrufiApp.moveNote(note, to: destination)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    navigationModel.showError(error)
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Rename Folder Dialog

public struct RenameFolderDialog: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var themeManager: ThemeManager

    let folder: Folder
    @State private var newName: String
    @State private var isLoading = false

    public init(folder: Folder) {
        self.folder = folder
        self._newName = State(initialValue: folder.name)
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rename Folder")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)

                    Text("Enter a new name for the folder")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                }

                Spacer()
            }

            // Current name display
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Name")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                Text(folder.name)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.currentTheme.colors.backgroundSecondary)
                    .cornerRadius(8)
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
            }

            // New name input
            VStack(alignment: .leading, spacing: 8) {
                Text("New Name")
                    .font(.headline)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)

                TextField("Enter new name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if isValidName {
                            performRename()
                        }
                    }
            }

            // Validation message
            if !isValidName && !newName.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Please enter a valid folder name")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.colors.border, lineWidth: 1)
                )

                Button("Rename") {
                    performRename()
                }
                .disabled(!isValidName || isLoading)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            (!isValidName || isLoading)
                                ? Color.gray
                                : themeManager.currentTheme.colors.accent
                        )
                )
                .overlay(
                    Group {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                    }
                )
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
        .background(themeManager.currentTheme.colors.background)
    }

    private var isValidName: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != folder.name && !trimmed.contains("/")
    }

    private func performRename() {
        guard isValidName else { return }

        isLoading = true

        Task {
            do {
                let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

                // Update folder using FolderManager
                try ferrufiApp.folderManager.renameFolder(folder.id, to: trimmedName)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    navigationModel.showError(error)
                    isLoading = false
                }
            }
        }
    }
}
