//
//  NotePickerView.swift
//  Ferrufi
//
//  Created by Gemini on 2026-01-06.
//

import SwiftUI

struct NotePickerView: View {
    @EnvironmentObject var ferrufiApp: FerrufiApp
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var onNoteSelected: (Note) -> Void

    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return ferrufiApp.notes
        } else {
            return ferrufiApp.notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack {
            Text("Select a Note to Link")
                .font(.title2)
                .padding()

            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search notes", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding()
            .background(themeManager.currentTheme.colors.backgroundSecondary)
            .cornerRadius(8)
            .padding(.horizontal)

            List(filteredNotes) { note in
                Button(action: {
                    onNoteSelected(note)
                }) {
                    Text(note.title)
                }
            }

            Button("Cancel") {
                dismiss()
            }
            .padding()
        }
        .frame(minWidth: 300, minHeight: 400)
        .padding()
    }
}
