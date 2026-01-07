//
//  test_minimal.swift
//  Iron
//
//  Minimal test app to debug theme manager issues
//

import SwiftUI

@main
struct MinimalIronApp: App {
    @StateObject private var ironApp = IronApp()

    var body: some Scene {
        WindowGroup {
            MinimalContentView()
                .environmentObject(ironApp)
        }
    }
}

struct MinimalContentView: View {
    @EnvironmentObject var ironApp: IronApp
    @State private var isInitialized = false
    @State private var error: Error?

    var body: some View {
        VStack(spacing: 20) {
            if isInitialized {
                Text("Iron Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("\(ironApp.notes.count) notes loaded")
                    .foregroundColor(.secondary)

                Button("Create Test Note") {
                    Task {
                        do {
                            _ = try await ironApp.createNote(
                                title: "Test Note \(Date().timeIntervalSince1970)",
                                content:
                                    "This is a test note created at \(Date()).\n\n## Features Working\n\n- Note creation\n- File storage\n- Basic UI"
                            )
                        } catch {
                            print("Error creating note: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                if !ironApp.notes.isEmpty {
                    List {
                        ForEach(ironApp.notes, id: \.id) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.headline)
                                Text(note.modifiedAt.formatted())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)

                    Text("Initialization Error")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        initializeApp()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Initializing Iron...")
                    .progressViewStyle(.circular)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding(40)
        .onAppear {
            initializeApp()
        }
    }

    private func initializeApp() {
        Task {
            do {
                let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
                let ironDirectory = homeDirectory.appendingPathComponent(".iron")
                let notesDirectory = ironDirectory.appendingPathComponent("notes")

                try FileManager.default.createDirectory(
                    at: ironDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                try FileManager.default.createDirectory(
                    at: notesDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                try await ironApp.initialize(vaultPath: notesDirectory.path)

                await MainActor.run {
                    self.isInitialized = true
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isInitialized = false
                }
            }
        }
    }
}
