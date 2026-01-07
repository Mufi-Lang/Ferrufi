//
//  NoteCreationView.swift
//  Iron
//
//  Simple note creation view
//

import SwiftUI

public struct NoteCreationView: View {
    @EnvironmentObject var ironApp: IronApp
    @EnvironmentObject var navigationModel: NavigationModel

    @State private var noteTitle: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String = ""

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Text("Create New Note")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.headline)

                TextField("Enter note title", text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        createNote()
                    }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Create") {
                    createNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    noteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating
                )
                .keyboardShortcut(.return)
            }

            if isCreating {
                ProgressView("Creating...")
                    .controlSize(.small)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Text field will be focused
            }
        }
    }

    private func createNote() {
        let title = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }

        isCreating = true
        errorMessage = ""

        Task {
            do {
                let content = "# \(title)\n\n"
                let newNote = try await ironApp.createNote(title: title, content: content)

                await MainActor.run {
                    navigationModel.selectNote(newNote)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create note: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}

struct NoteCreationView_Previews: PreviewProvider {
    static var previews: some View {
        NoteCreationView()
            .environmentObject(IronApp())
            .environmentObject(NavigationModel())
    }
}
